# YouTube Shorts - Tech News Automation

## Overview
- **Triggers**: Manual (click to run)
- **Nodes**: 18 | **Connections**: 17
- **Estimated Runtime**: 25-40 minutes per video (cloud AI generation)
- **Monthly Cost**: ~$44/month for 30 Shorts (~$1.47/video: ~$0.78 images + $2.10 video + $0.17 voice + $0.37 music)
- **Import file**: `exports/youtube-shorts-tech-news.json`
- **Version**: v8.10

## Pipeline

```
Manual Trigger
    |
    v
[Fetch Reddit Posts] -- GET old.reddit.com/r/technology/hot.json?limit=15
    |
    v
[Format Reddit Data] -- Code: extracts top 10 non-stickied posts
    |
    v
[Fetch HN Posts] -- GET hn.algolia.com/api/v1/search (front page, 10 results)
    |
    v
[Pick Best Story] -- Code: score+rank all posts, dedupe against 14-day history, output top 3
    |
    v
[Prepare Story Data] -- Code: pass rankedStories + timestamp (no API keys in output)
    |
    v
[Generate Script (Gemini)] -- Code+sandbox: Gemini 3 Flash, HECK-loop script (75-90 words),
    |                          title, 6 tags, 6 beat-tied image prompts. thinkingBudget:0
    v
[Parse Script JSON] -- Code: parse + validate Gemini JSON (≥65 words, ≥3 tags, ≥5 prompts)
    |
    v
[Generate Images (SD3/Flux)] -- Code+sandbox: Stability AI SD3 primary (~78 credits/run,
    |                            base64 → data URIs) / fal.ai Flux Schnell fallback (~$0.09)
    v
[Generate Video Clips (fal.ai Kling)] -- Code+sandbox: Kling v1.6 I2V queue API,
    |                                     6x clips (9:16, 5s each), ~$2.10 total
    v
[Generate Voiceover (ElevenLabs)] -- Code+sandbox: eleven_multilingual_v2, voice Antoni,
    |                                 MP3 128kbps, ~$0.17/run
    v
[Generate Background Music (fal.ai Stable Audio)] -- Code+sandbox: fal.ai Stable Audio,
    |                                          45s WAV→MP3, ~$0.37/run
    v
[Compose Video (FFmpeg)] -- Code: download 6 clips + minterpolate + xfade + voice+music mix,
    |                        1080x1920 MP4, no burned captions (YouTube auto-captions used)
    v
[Export Video Locally] -- Code: save video.mp4 + upload-info.txt to videos/{timestamp}_{title}/
    |
    v
[Prepare YouTube Metadata] -- Code: append #Shorts, category 28, format tags
    |
    v
[Upload to YouTube] -- YouTube node: upload video binary, privacy: public
    |
    v
[Add to Playlist] -- YouTube node: add video to playlist
    |
    v
[Success Output] -- Code: return youtubeUrl, uploadTime
```

## Node Details

### Node 1: Manual Trigger
- **Type**: `n8n-nodes-base.manualTrigger` (v1)
- **ID**: `trigger`
- **Config**: Default (no parameters)

### Node 2: Fetch Reddit Posts
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `fetchReddit`

**Parameters**:
```json
{
  "url": "https://old.reddit.com/r/technology/hot.json?limit=15",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      { "name": "User-Agent", "value": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" },
      { "name": "Accept", "value": "application/json, text/plain, */*" }
    ]
  },
  "options": { "timeout": 10000 }
}
```

**Note**: Must use `old.reddit.com` + Chrome User-Agent. Reddit returns 403 to bot UAs.

### Node 3: Format Reddit Data
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `formatReddit`

Filters out stickied posts, extracts top 10, formats as `[Score: N] Title (N comments)`.

### Node 4: Fetch HN Posts
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `fetchHN`

**Parameters**:
```json
{
  "url": "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=10",
  "options": { "timeout": 10000 }
}
```

### Node 5: Pick Best Story
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `pickStory`

**Logic**:
1. Scores every Reddit + HN post by engagement:
   - Reddit: `score + num_comments × 2 + viralBoost`
   - HN: `points + num_comments × 3 + viralBoost`
   - `viralBoost` = matched viral keywords × 300 (30-word list: ai, robot, ban, billion, hack, breach, leak, secret, first, outrage, lawsuit, fired, ceo, agi, gpt, claude, open source, shutdown, censor, record, largest, biggest, collapse, surge, revolution, milestone, breakthrough)
2. Sorts all posts by score descending
3. **Duplicate detection**: reads `/home/node/videos/last_stories.json` (14-day history). Skips any story where 60%+ of meaningful words (4+ chars) match a previously used title
4. Selects top 3 non-duplicate stories
5. Fallback: if all top stories are duplicates, takes top 3 anyway (never blocks the run)
6. Saves chosen story #1 title to history (keeps last 14 entries)

**Output**: `{ rankedStories }` — numbered list of top 3 stories with source and score

### Node 6: Prepare Story Data
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseAgent`

Passes `rankedStories` as `rawStory` + adds `timestamp`. Does NOT include API keys in output (prevents key leakage into n8n execution logs).

```javascript
return { json: { rawStory: data.rankedStories, timestamp: new Date().toISOString() } };
```

### Node 7: Generate Script (Gemini)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `scriptGen`
- **External service**: Gemini 3 Flash (`gemini-3-flash-preview`)

**Logic**:
1. Reads `geminiApiKey` directly from `/home/node/keys.json` (NOT from input — prevents key appearing in execution logs)
2. Builds Gemini request body with `thinkingBudget: 0` (disables thinking tokens — prevents JSON truncation) and `maxOutputTokens: 8192`
3. Sandbox escape: writes request to `/tmp/n8n_gemini_*/body.json`, spawns `node gemini.js` for https access
4. **Post-generation validation (v8.9)**: parses the SCRIPT field and throws `"Script ends mid-sentence..."` if it doesn't end with terminal punctuation (`.`, `!`, `?` — optionally followed by a closing quote/bracket). n8n's `retryOnFail: true, maxTries: 3, waitBetweenTries: 5s` then re-calls Gemini automatically.
5. Returns raw Gemini API JSON response only if the script is sentence-complete (or after all retries exhausted — parseScript handles that case)

**Prompt target (v8.10 rewrite)**: Exactly 6 complete sentences (Hook-Explain×2-Climax×2-Kicker). Hard rules: every sentence ends with `.`/`!`/`?`; no sentence ends in a conjunction, preposition, article, or comma; "replay loop is THEMATIC, not grammatical" (Kicker is self-contained, does not syntactically trail into Hook). Soft target: 75-95 words (completeness always beats word count). Prompt includes concrete bad examples (`"...realizing that"`, `"...rewritten before"`) and good examples, plus a final self-check instruction. 6 beat-tied image prompts.

**Model**: `gemini-3-flash-preview` (free, via Google AI Studio API key)

### Node 8: Parse Script JSON
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseScript`

**Logic**:
1. Finds non-thought part in `candidates[0].content.parts` (skips parts with `thought: true`)
2. Parses JSON; falls back to regex `{[\s\S]*}` extraction if response has markdown fences
3. `findScriptData()` searches up to 2 levels deep for the SCRIPT key (handles flat and nested Gemini response formats)
4. Normalizes UPPER and lowercase keys
5. **Safety-net truncation (v8.9)**: if the script still ends without terminal punctuation after all scriptGen retries, truncates to the last complete sentence (last `.`/`!`/`?` boundary in the text). Ensures the voiceover never cuts off mid-word even when Gemini repeatedly fails to close its last sentence.

**Validation**: ≥65 words (after truncation), ≥3 tags, ≥5 image prompts. Throws descriptive error if any check fails.

**Output**: `{ script, title, description, tags, imagePrompts, wordCount, timestamp }`

### Node 9: Generate Images (SD3/Flux)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `generateImages`
- **External services**: Stability AI SD3 (primary) / fal.ai Flux Schnell (fallback)

**Logic**:
1. Checks Stability AI balance **once upfront** via `GET api.stability.ai/v1/user/balance`
2. If credits ≥ `prompts.length × 13` (78 for 6 images): uses SD3 for ALL images
3. If credits insufficient: logs `"Stability credits N < 78 needed, using fal.ai Flux"` and uses Flux for ALL images
4. Balance check is atomic — provider never changes mid-run, every image uses the same provider

**SD3 path**:
- Builds multipart form bodies in the n8n Code node (avoids escaping issues in spawned scripts)
- Base64-encodes each body, passes via `cfg.json`
- Spawned script decodes and POSTs to `api.stability.ai/v2beta/stable-image/generate/sd3`
- Response `{image: "<base64>"}` → converted to `data:image/jpeg;base64,...` data URI
- fal.ai Kling confirmed to accept data URIs as `image_url` directly

**Flux fallback path**:
- POST to `fal.run/fal-ai/flux/schnell` with JSON body
- Returns CDN URLs directly

**Specs**:
- SD3: 9:16 aspect ratio, JPEG, ~13 credits/image, ~78 credits/run
- Flux: 768×1344 pixels (9:16), ~$0.015/image, ~$0.09/run

**Output**: `{ imageUrls, imageCount, imageProvider: 'stability-sd3'|'fal-flux', script, title, description, tags, imagePrompts }`

### Node 10: Generate Video Clips (fal.ai Kling)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `generateVideo`
- **External service**: `queue.fal.run/fal-ai/kling-video/v1.6/standard/image-to-video`

**Logic**:
1. Takes 6 image URLs/data URIs from Generate Images node
2. All 6 clips submitted in parallel — each POST returns `request_id`, `status_url`, `response_url`
3. All 6 clips polled in parallel via `Promise.allSettled` — uses `status_url` from fal.ai response directly (never manually constructed)
4. On `COMPLETED`: fetches `response_url` → extracts `video.url`
5. 1 automatic retry per clip on timeout/failure before marking it failed
6. Proceeds with ≥4/6 clips; fails hard if <4 complete
7. Sandbox escape via spawned Node.js script
8. Auth: `Authorization: Key {falApiKey}`

**Video specs**: 9:16 aspect ratio, 5s duration per clip, 6 cinematic motion prompts. ~$0.35/clip, ~$2.10 total.
**Timeout**: 3600s per clip, 9000s total exec (matches `N8N_RUNNERS_TASK_TIMEOUT`). Total wall-clock time = slowest single clip (parallel), not sum of all clips.

**Output**: `{ videoUrls, clipDurations, clipCount, script, title, description, tags }`

### Node 11: Generate Voiceover (ElevenLabs)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `voiceover`
- **External service**: `api.elevenlabs.io/v1/text-to-speech`

**Logic**:
1. POST to `https://api.elevenlabs.io/v1/text-to-speech/ErXwobaYiN019PkySvjV?output_format=mp3_44100_128`
2. Auth: `xi-api-key: {elevenLabsApiKey}`
3. Body: `{ text: script, model_id: 'eleven_multilingual_v2', voice_settings: { stability: 0.5, similarity_boost: 0.75 } }`
4. Response is binary MP3 piped directly to file
5. Sandbox escape via spawned Node.js script

**Voice**: Antoni (`ErXwobaYiN019PkySvjV`), eleven_multilingual_v2.
**Plan**: Starter minimum. `mp3_44100_128` (128kbps) — Creator plan required for 192kbps.
**Cost**: ~$0.17/run (~3,000 chars at $0.30/1k on Starter).

**Output**: Binary `voice` (MP3) + JSON passthrough

### Node 12: Generate Background Music (fal.ai Stable Audio)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `generateMusic`
- **External service**: `fal.run/fal-ai/stable-audio`

**Logic**:
1. POST JSON `{prompt, seconds_total: 45, steps: 100}` to `fal.run/fal-ai/stable-audio`
2. Auth: `Authorization: Key {falApiKey}` (same key as images/video)
3. Response: `{audio_file: {url}}` — downloads WAV from CDN
4. Converts WAV → MP3 via FFmpeg (`-c:a libmp3lame -b:a 128k`)
5. Sandbox escape via spawned Node.js script
6. **Exec timeout**: 300s (generation takes ~70-90s + download time)
7. **Fallback**: if `falApiKey` missing, generates 45s FFmpeg silence

**Note**: Previous Stability AI audio endpoint (`api.stability.ai/v2beta/stable-audio/generate`) returns 404 — removed April 2026. fal.ai is now the only audio provider.

**Output**: Binary `music` (MP3) + passes through `voice` binary

### Node 13: Compose Video (FFmpeg)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `composeVideo`

**Logic**:
1. Writes voice + music binaries from input to `/tmp/n8n_compose_*/`
2. Probes voice duration via `ffmpeg -i voice.mp3 2>&1` + regex (`/Duration: (\d+):(\d+):([\d.]+)/`)
3. Downloads 6 video clips via sandbox-escaped Node.js downloader with:
   - HTTP status code validation
   - `r.on('error')` stream error handling
   - 60s per-request socket timeout
   - 3 retry attempts with 5s delay each
   - 300s total exec timeout
4. **Pass 1** (per clip): scale 1080:1920 (Lanczos) → crop → unsharp → color grade → minterpolate 60fps → setpts slowdown → trim → fps=30 → encode intermediate MP4
5. **Audio mix**: voice (100%) + music (28% volume), trimmed to voice duration, mixed to AAC
6. **Pass 2**: xfade stitch (0.3s fade transitions) → final encode libx264 CRF 18 slow preset, output trimmed to exactly `audioDuration` via `-t`
7. **No burned captions** — YouTube auto-generated captions used instead

**Key FFmpeg details**:
- `minterpolate` runs at native clip fps BEFORE `setpts` slowdown (prevents PTS corruption)
- Save to intermediate `.mp4` between passes resets PTS (required for xfade)
- `fps=30` comes AFTER `trim+setpts` in filter chain
- `targetClipDur` includes a 1s buffer so video is always slightly longer than audio — final output trimmed to `audioDuration` with `-t`, never `-shortest` (which cuts audio if video is a single frame short)

**Output**: Binary `video` (MP4, 1080×1920) + JSON with duration, numClips, title, script

### Node 14: Export Video Locally
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `exportLocal`

Creates `videos/{ISO-timestamp}_{sanitized-title}/` (mounted from `D:\Github Clones\N8nYtAutomation\videos\` on Windows host via Docker volume). Writes:
- `video.mp4` — final 1080×1920 MP4
- `upload-info.txt` — script, YouTube title/description/tags, Instagram caption with 20 hashtags

### Node 15: Prepare YouTube Metadata
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `prepareYT`

Appends `#Shorts` to title, formats description with hashtags, sets category 28 (Science & Technology). Passes binary through.

### Node 16: Upload to YouTube
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `youtubeUpload`
- **Credential**: YouTube OAuth2 API

Resource: `video`, Operation: `upload`. Binary: `video`. Privacy: `public`. Category: 28. `notifySubscribers: true`.

### Node 17: Add to Playlist
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `addToPlaylist`
- **Credential**: YouTube OAuth2 API

Resource: `playlistItem`. `playlistId`: use expression format `=PLxxxxxxx` (avoids dropdown loading error). `videoId`: `={{ $json.uploadId || $json.id }}`.

### Node 18: Success Output
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `successOutput`

Returns `youtubeUrl`, `videoId`, `uploadTime`.

## Connection Map

```
Source Node                              -> Target Node
-----------------------------------------------------------------------
Manual Trigger                           -> Fetch Reddit Posts
Fetch Reddit Posts                       -> Format Reddit Data
Format Reddit Data                       -> Fetch HN Posts
Fetch HN Posts                           -> Pick Best Story
Pick Best Story                          -> Prepare Story Data
Prepare Story Data                       -> Generate Script (Gemini)
Generate Script (Gemini)                 -> Parse Script JSON
Parse Script JSON                        -> Generate Images (SD3/Flux)
Generate Images (SD3/Flux)               -> Generate Video Clips (fal.ai Kling)
Generate Video Clips (fal.ai Kling)      -> Generate Voiceover (ElevenLabs)
Generate Voiceover (ElevenLabs)          -> Generate Background Music (fal.ai Stable Audio)
Generate Background Music (fal.ai Stable Audio) -> Compose Video (FFmpeg)
Compose Video (FFmpeg)                   -> Export Video Locally
Export Video Locally                     -> Prepare YouTube Metadata
Prepare YouTube Metadata                 -> Upload to YouTube
Upload to YouTube                        -> Add to Playlist
Add to Playlist                          -> Success Output
```

## Required Credentials

All cloud API keys are stored in `keys.json` (repo root, mounted read-only at `/home/node/keys.json` in Docker):

| # | keys.json field | Where to Get | Used By | Cost/run |
|---|---|---|---|---|
| 1 | `geminiApiKey` | [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys) — free | Generate Script | $0.00 |
| 2 | `falApiKey` | [fal.ai/dashboard](https://fal.ai/dashboard) | Images (fallback) + Video Clips + Music | ~$2.47 |
| 3 | `elevenLabsApiKey` | [elevenlabs.io/app/settings/api-keys](https://elevenlabs.io/app/settings/api-keys) — Starter+ | Generate Voiceover | ~$0.17 |
| 4 | `stabilityApiKey` | [platform.stability.ai/account/keys](https://platform.stability.ai/account/keys) — optional | Generate Images (primary, ~78 credits/run) | ~$0.78 |
| 5 | `youtubePlaylistId` | YouTube playlist URL after `list=` | Add to Playlist | — |
| 6 | YouTube OAuth2 | Google Cloud Console → YouTube Data API v3 | Upload to YouTube, Add to Playlist | free |

**No GPU or ComfyUI required** — all AI generation uses cloud APIs.

## Troubleshooting

### Script generation issues
- "No JSON object found": Gemini truncated response — `thinkingBudget: 0` + `maxOutputTokens: 8192` should prevent this
- "Script too short": word count below 65 minimum — re-run, Gemini occasionally goes short
- Gemini 3 Flash rate limit: 5 RPM on free tier, sufficient for 1 run per minute

### Image generation issues
- SD3 balance check failed → automatically falls back to fal.ai Flux (logged in stderr)
- "FATAL: SD3 403": Stability AI key expired or revoked — check platform.stability.ai
- Mixed image styles: impossible — provider selected once before loop, all 6 images use same provider

### Video clip issues
- "Clip download failed" + retry messages: fal.ai CDN URL expired (clips expire after ~24h) — re-run
- "Kling timeout after 3600s": fal.ai under extreme load — re-run; clips are retried once automatically before failing
- "Only N/6 clips completed": N clips succeeded after retries; if N≥4 the workflow proceeds; if N<4 re-run
- "Kling submit error 422": `image_url` format issue — data URIs and CDN URLs both confirmed working

### Music generation issues
- Music timeout: generation at `steps: 100` takes ~70-90s + download — 300s exec timeout provides headroom
- "fal.ai Stable Audio error 4xx": check `falApiKey` in keys.json

### Video composition issues
- FFmpeg not found: rebuild Docker image (`docker compose build && docker compose up -d`)
- OOM: `maxBuffer: 500MB` for final encode — only hits on extremely long videos
- minterpolate slow: ~5-10 min for 6 clips is normal at `mi_mode=mci`

### YouTube upload issues
- Re-authorize OAuth2 if token expired
- Quota: 10,000 units/day, upload = 1,600 units (~6 uploads/day max)
- Video must be ≤60s and include `#Shorts` in title

### Runner / infrastructure issues
- `"Task request timed out after 60 seconds. Code node task was not matched to a runner"`: runner-match timeout (separate from execution timeout). Set `N8N_RUNNERS_TASK_REQUEST_TIMEOUT=600` in `D:\N8n\docker-compose.yml` and `docker compose up -d`. Default 60s is too short after long-running Code nodes (composeVideo, generateVideo) because the runner process restarts/reconnects.
- Required docker-compose env vars: `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os`, `N8N_RUNNERS_TASK_TIMEOUT=9000` (execution, **seconds**), `N8N_RUNNERS_TASK_REQUEST_TIMEOUT=600` (match), `N8N_RUNNERS_HEARTBEAT_INTERVAL=600`.

## Modification Guide

| What | How |
|---|---|
| Change script length | Edit `scriptGen` system prompt word count target (currently 75-90 words) |
| Change TTS voice | Edit `voiceover` node voice ID in URL path. Options: ErXwobaYiN019PkySvjV (Antoni), others at elevenlabs.io |
| Change music style | Edit `generateMusic` prompt string |
| Change number of clips | Edit `generateImages` imagePrompts count + `generateVideo` motions array |
| Force fal.ai Flux images | Remove `stabilityApiKey` from keys.json |
| Change privacy | Edit `youtubeUpload` node privacyStatus field (`public`/`unlisted`/`private`) |
| Change playlist | Edit `addToPlaylist` node `playlistId` field (use `=PLxxxxxxx` expression format) |
| Remove playlist step | Delete `addToPlaylist` node, connect `Upload to YouTube` → `Success Output` |
| Add schedule | Replace Manual Trigger with Schedule Trigger (cron: `0 15 * * *` for 8:30 PM IST) |
| Reset duplicate history | Delete `/home/node/videos/last_stories.json` in Docker |

## Version History

- **v8.10** (2026-04-16): Gemini prompt rewrite — root-cause fix for mid-sentence scripts. HECK structure explicit as 6 sentences, hard rules separated from soft word-count target, new "replay loop is THEMATIC not grammatical" rule (removes the ambiguity that caused Gemini to end with conjunctions/prepositions), explicit bad/good Kicker examples, self-check instruction. v8.9's validation + retry + truncation kept as defense-in-depth.
- **v8.9** (2026-04-16): Permanent script mid-sentence fix. `scriptGen`: post-Gemini validation throws if SCRIPT doesn't end with terminal punctuation → n8n retries up to 3x automatically. New explicit prompt rule enforces terminal punctuation requirement. `parseScript`: safety-net truncation to last complete sentence if all retries still fail. Defense-in-depth — v8.8's prompt-only fix wasn't enforceable.
- **v8.8** (2026-04-15): Script mid-sentence cutoff (prompt-only fix). `scriptGen`: word count rule → "always finish the final sentence even if slightly over 90 words, never stop mid-sentence"; Kicker rule → "A complete sentence ending on...". Insufficient — superseded by v8.9.
- **v8.7** (2026-04-14): Voiceover cutoff fix. `composeVideo`: `-shortest` → `-t audioDuration`, +1s buffer to `targetClipDur`.
- **v8.6** (2026-04-14): Kling reliability overhaul. Parallel submit+poll with `Promise.allSettled`, use `status_url`/`response_url` from response directly (manual URL construction was root cause), 1 retry per clip, proceed with ≥4/6 clips.
- **v8.5** (2026-04-14): Kling timeout bump. 1200s→1800s per clip; exec 7800s→9000s.
- **v8.4** (2026-04-11): 10-day test prep. `pickStory`: duplicate detection (word-overlap against 14-day history in `/home/node/videos/last_stories.json`), top stories 6→3. `generateImages`: renamed node to "Generate Images (SD3/Flux)", explicit stderr log on Flux fallback. `scriptGen`: reads `geminiApiKey` directly from keys.json (no longer passed via node output), word target 90-120→75-90 words, `thinkingBudget:0` added. `parseScript`: min word count 80→65. `parseAgent`: removed `geminiApiKey` from output (prevents API key leakage into n8n execution logs). `composeVideo`: removed .ass captions entirely (YouTube auto-captions), download retry logic (3 attempts, 5s delay, HTTP status validation, stream error handling), 300s exec timeout.
- **v8.3** (2026-04-10): Image + music provider changes. `generateImages`: Stability AI SD3 as primary (balance check → data URI output), fal.ai Flux fallback. `generateMusic`: switched from Stability AI (404, endpoint removed) to fal.ai Stable Audio (WAV→MP3 via FFmpeg). `scriptGen`: converted to Code node with sandbox escape (HTTP Request node causing 400s). `parseScript`: updated for Gemini 3 thinking model. `generateVideo`: fixed polling URL (use status_url/response_url from submit response directly).
- **v8.2** (2026-04-08): API fixes. ElevenLabs `mp3_44100_192` → `mp3_44100_128` (Starter plan cap). Stable Audio: added `model: stable-audio-2.5` field. All keys migrated to `keys.json`. All 4 cloud endpoints verified working.
- **v8.1** (2026-04-06): Script improvements. `pickStory` scores Reddit+HN by engagement + viral keyword boost (30 keywords, +300 each). `parseAgent` passes ranked list as `rawStory`. Gemini prompt 90-120 words, HECK beat-tied image prompts. `parseScript` min 80 words, min 3 tags.
- **v8.0** (2026-04-06): Full cloud AI overhaul. Replaced ComfyUI SDXL+HunyuanVideo with fal.ai Flux Schnell (images) + Kling v1.6 I2V (video). Replaced Gemini TTS with ElevenLabs (MP3, no PCM). Added fal.ai Stable Audio background music (45s, 28% mix). HECK-loop script. 17→18 nodes. Runtime 80-110→35-70 min.
- **v7.2** (2026-03-28): Added `exportLocal` node. Saves `video.mp4` + `upload-info.txt` to `videos/{timestamp}_{title}/`. Requires volume mount in `D:\N8n\docker-compose.yml`.
- **v7.1** (2026-03-28): Removed Instagram Reels and Schedule Trigger. Back to 16 nodes, manual trigger only.
- **v7.0** (2026-03-14): Added Instagram Reels cross-posting via Facebook Graph API Resumable Upload. 16→26 nodes. (Reverted in v7.1)
- **v6.9** (2026-03-09): Full end-to-end run confirmed working. `scriptGen` → `gemini-3-flash-preview`.
- **v6.0–v6.8** (2026-03-02–09): Local AI via ComfyUI (SDXL images + HunyuanVideo I2V). Replaced in v8.0.
- **v5.x** (2026-02-23–25): Various cloud image providers (Pollinations, HuggingFace FLUX, Pexels). Replaced in v6.0.
- **v4.0** (2026-02-16): Migrated to free stack (Gemini Flash + FFmpeg). Replaced in v5.0.
- **v1.0–v3.1** (2026-02-07–09): Initial builds with OpenAI + Creatomate.
