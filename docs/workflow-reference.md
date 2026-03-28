# YouTube Shorts - Tech News Automation

## Overview
- **Triggers**: Manual (click to run)
- **Nodes**: 16 | **Connections**: 15
- **Estimated Runtime**: 80-110 minutes per video (local AI generation)
- **Monthly Cost**: $0.00 (all local AI + free APIs)
- **Import file**: `exports/youtube-shorts-tech-news.json`

## Pipeline

```
Manual Trigger
    |
    v
[Fetch Reddit Posts] -- GET old.reddit.com/r/technology/hot.json
    |
    v
[Format Reddit Data] -- Code node: extracts top 10 post summaries
    |
    v
[Fetch HN Posts] -- GET hn.algolia.com/api/v1/search (front page)
    |
    v
[Pick Best Story] -- Code node: combines Reddit + HN data into prompt
    |
    v
[Prepare Story Data] -- Code node: formats combined prompt for Gemini
    |
    v
[Generate Script (Gemini)] -- Gemini 3 Flash: script, title, description, tags, 8 image prompts
    |
    v
[Parse Script JSON] -- Code node: parses Gemini JSON response
    |
    v
[Generate Images (ComfyUI SDXL)] -- Code node: SDXL base 1.0 via ComfyUI API, 8x images (768x1344)
    |
    v
[Animate Images (ComfyUI Hunyuan)] -- Code node: HunyuanVideo I2V via ComfyUI API, 8x clips (544x960)
    |
    v
[Generate Voiceover (Gemini TTS)] -- Gemini 2.5 Flash TTS: PCM audio (base64)
    |
    v
[Compose Video (FFmpeg)] -- Code node: stitch + slow-stretch + crossfade + audio, 1080x1920 MP4
    |
    v
[Prepare YouTube Metadata] -- append #Shorts, category 28, format tags
    |
    v
[Upload to YouTube] -- upload video binary, privacy: public
    |
    v
[Add to Playlist] -- add video to YouTube playlist
    |
    v
[Success Output] -- return videoUrl, videoId, uploadTime
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
      { "name": "Accept", "value": "application/json" }
    ]
  },
  "options": { "timeout": 10000 }
}
```

### Node 3: Format Reddit Data
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `formatReddit`

**Code**:
```javascript
const data = $input.first().json;
const posts = data?.data?.children || [];
const topPosts = posts
  .filter(p => !p.data.stickied)
  .slice(0, 10)
  .map((p, i) => {
    const d = p.data;
    return `${i+1}. [Score: ${d.score}] ${d.title} (${d.num_comments} comments)`;
  })
  .join('\n');

return {
  json: {
    redditSummary: topPosts
  }
};
```

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

**Code**:
```javascript
const redditData = $('Format Reddit Data').first().json.redditSummary || 'No Reddit data';

const hnRaw = $input.first().json;
const hnHits = hnRaw.hits || [];
const hnSummary = hnHits.slice(0, 10).map((h, i) => {
  return `${i+1}. [Points: ${h.points}] ${h.title} (${h.num_comments} comments) - ${h.url || 'https://news.ycombinator.com/item?id=' + h.objectID}`;
}).join('\n');

return {
  json: {
    redditSummary: redditData,
    hnSummary: hnSummary,
    combinedPrompt: `REDDIT TOP POSTS (r/technology):\n${redditData}\n\nHACKER NEWS FRONT PAGE:\n${hnSummary}\n\nFrom the stories above, pick the SINGLE most interesting, viral tech/AI story...`
  }
};
```

### Node 6: Prepare Story Data
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseAgent`

**Code**:
```javascript
const data = $input.first().json;

return {
  json: {
    rawStory: data.combinedPrompt,
    redditSummary: data.redditSummary,
    hnSummary: data.hnSummary,
    timestamp: new Date().toISOString()
  }
};
```

### Node 7: Generate Script (Gemini)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `scriptGen`
- **Auth**: API key in URL query parameter (no n8n credential)
- **Retry**: `retryOnFail: true`, `maxTries: 3`, `waitBetweenTries: 5000` (handles transient 503 errors)

**Parameters**:
- Method: POST
- URL: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=YOUR_GEMINI_API_KEY`
- Body: JSON with `contents`, `systemInstruction`, and `generationConfig`
- `responseMimeType: 'application/json'` forces structured JSON output
- System prompt: "tech news researcher and YouTube Shorts scriptwriter"
- Requests: SCRIPT (110-120 words), TITLE (under 70 chars), DESCRIPTION, TAGS, IMAGE_PROMPTS (8 vertical 9:16 prompts)
- Timeout: 60000ms

### Node 8: Parse Script JSON
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseScript`

Parses Gemini JSON response from `candidates[0].content.parts[0].text`. Uses `findScriptData()` to recursively search for the SCRIPT field up to 2 levels deep — handles flat `{SCRIPT, ...}`, wrapped `{YOUTUBE_SHORT: {SCRIPT, ...}}`, and nested `{story_analysis: {...}, youtube_short_script: {SCRIPT, ...}}` formats. Normalizes both UPPER and lowercase keys. Falls back to regex extraction if response isn't clean JSON. Validates at least 4 image prompts.

### Node 9: Generate Images (ComfyUI SDXL)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `generateImages`
- **External service**: ComfyUI on Windows host via `http://host.docker.internal:8188`

**Logic**:
1. Takes 8 image prompts from Parse Script JSON
2. Health check: `GET /system_stats` before starting
3. For each of 8 prompts:
   - Loads embedded SDXL base 1.0 workflow template (ComfyUI API format)
   - Injects prompt text and random seed
   - `POST /prompt` to submit job
   - Polls `GET /history/{prompt_id}` every 3s until complete (180s timeout)
   - Downloads output image via `GET /view?filename=...&type=output`
   - Converts to base64
4. Sequential processing (8GB VRAM — one image at a time)
5. Writes helper Node.js script to `/tmp/` (sandbox escape for `http` module access)

**Image specs**: 768x1344 pixels (9:16), 30 steps, dpmpp_2m sampler, karras scheduler, cfg 7.5. ~35-45s per image.

**Output**: `{ imageBase64Array: [...], imageCount: 8, script, title, description, tags }`

### Node 10: Animate Images (ComfyUI Hunyuan)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `animateImages`
- **External service**: ComfyUI on Windows host via `http://host.docker.internal:8188`

**Logic**:
1. Takes 8 base64 images from Generate Images node
2. For each of 8 images:
   - Writes image to `/tmp/` as PNG
   - Uploads via `POST /upload/image` (multipart form)
   - Loads embedded HunyuanVideo I2V Q4 GGUF workflow template
   - Injects uploaded filename, cinematic motion prompt, and random seed
   - `POST /prompt` to submit job
   - Polls `GET /history/{prompt_id}` every 10s until complete (20 min timeout)
   - Downloads WEBP output via `GET /view`
   - Converts WEBP→MP4 via FFmpeg
   - Converts to base64
3. Global 9000s time budget (150 min) — if exhausted, remaining images get simple 3s static MP4 fallback
4. Motion prompts: prepends cinematic descriptions (zoom, pan, dolly, tilt) to original image prompts

**Video specs**: 544x960 pixels, 49 frames at 24fps (~2s clips), 20 steps, CFG 1.0. ~7-12 min per clip.

**Output**: `{ videoClipBase64Array: [...], clipCount: 8, clipDurations: [...], script, title, description, tags }`

### Node 11: Generate Voiceover (Gemini TTS)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `voiceover`
- **Auth**: API key in URL query parameter (no n8n credential)
- **Note**: Receives data from Animate Images node (not Generate Images)

**Parameters**:
- Method: POST
- URL: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=YOUR_GEMINI_API_KEY`
- Body:
```json
{
  "contents": [{ "parts": [{ "text": "Read this as an engaging, energetic tech news narrator: [SCRIPT]" }] }],
  "generationConfig": {
    "responseModalities": ["AUDIO"],
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": { "voiceName": "Kore" }
      }
    }
  }
}
```
- Returns base64 PCM audio (24kHz, 16-bit, mono) in `candidates[0].content.parts[0].inlineData.data`
- Voice options: `Kore`, `Charon`, `Fenrir`, `Aoede`, `Puck`, `Zephyr`
- Timeout: 30000ms

### Node 12: Compose Video (FFmpeg)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `composeVideo`
- **Requires**: `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` and FFmpeg installed

**Logic**:
1. Gets video clips from `Animate Images (ComfyUI Hunyuan)` node — `videoClipBase64Array`
2. Gets audio from `Generate Voiceover (Gemini TTS)` node — PCM base64
3. Writes 8 base64 MP4 clips to `/tmp/n8n_video_*/clip_0.mp4` ... `clip_7.mp4`
4. Writes base64 PCM audio → converts to WAV via FFmpeg (`-f s16le -ar 24000 -ac 1`)
5. Probes audio duration to calculate speed factor for clip slow-stretching
6. Slow-stretches each clip with `setpts=PTS/speedFactor` to match audio duration (creates dreamy slow-motion effect)
7. Scales all clips from 544x960 → 1080x1920
8. Crossfade transitions (0.3s) between clips
9. Overlays audio track
10. Output: 1080x1920 vertical MP4 (libx264, CRF 23, AAC audio)
11. Returns video as n8n binary data
12. Cleans up temp files

**Estimated render time**: 30-60 seconds for stitching + audio overlay.

### Node 13: Prepare YouTube Metadata
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `prepareYT`

Appends `#Shorts` to title, adds hashtags to description, sets category 28 (Science & Technology), truncates title to 100 chars. Passes through binary video data.

### Node 14: Upload to YouTube
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `youtubeUpload`
- **Credential**: YouTube OAuth2 API

Resource: `video`, Operation: `upload`. Binary property: `video`. Privacy: `public` (change to `unlisted` for testing). Category: 28. Tags joined with commas, notifySubscribers: true.

### Node 15: Add to Playlist
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `addToPlaylist`
- **Credential**: YouTube OAuth2 API (same as Upload to YouTube)

Resource: `playlistItem`. `playlistId`: `=YOUR_PLAYLIST_ID` — **SETUP REQUIRED** (use expression format `=PLxxxxxxx` to avoid dropdown loading error). `videoId`: `={{ $json.uploadId || $json.id || $json.videoId }}`.

### Node 16: Success Output
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `successOutput`

Returns `videoUrl`, `videoId`, `uploadTime`. Constructs YouTube Shorts URL from video ID.

## Connection Map

```
Source Node                            -> Target Node                            | Type
------------------------------------------------------------------------------------
Manual Trigger                         -> Fetch Reddit Posts                      | main
Fetch Reddit Posts                     -> Format Reddit Data                      | main
Format Reddit Data                     -> Fetch HN Posts                          | main
Fetch HN Posts                         -> Pick Best Story                         | main
Pick Best Story                        -> Prepare Story Data                      | main
Prepare Story Data                     -> Generate Script (Gemini)                | main
Generate Script (Gemini)               -> Parse Script JSON                       | main
Parse Script JSON                      -> Generate Images (ComfyUI SDXL)          | main
Generate Images (ComfyUI SDXL)         -> Animate Images (ComfyUI Hunyuan)        | main
Animate Images (ComfyUI Hunyuan)       -> Generate Voiceover (Gemini TTS)         | main
Generate Voiceover (Gemini TTS)        -> Compose Video (FFmpeg)                  | main
Compose Video (FFmpeg)                 -> Prepare YouTube Metadata                 | main
Prepare YouTube Metadata               -> Upload to YouTube                       | main
Upload to YouTube                      -> Add to Playlist                         | main
Add to Playlist                        -> Success Output                          | main
```

## Required Credentials

| # | Credential Name | Type | Where to Get | Used By |
|---|---|---|---|---|
| 1 | Google AI Studio (Gemini) | API Key in URL | [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys) — free | Script Gen, Voiceover TTS |
| 2 | ComfyUI | Local API (no auth) | Local install — see [comfyui/README.md](../comfyui/README.md) | Generate Images, Animate Images |
| 3 | YouTube OAuth2 API | OAuth2 | Google Cloud Console → YouTube Data API v3 → OAuth2 credentials | Upload to YouTube, Add to Playlist |

**Note**: ComfyUI runs locally — no API keys needed. SDXL base 1.0 and HunyuanVideo I2V models must be downloaded (~24GB).

## Troubleshooting

### FFmpeg / Video composition issues
- FFmpeg is baked into the custom Docker image via `docker compose up -d` (see parent directory Dockerfile)
- If FFmpeg is missing, rebuild: `docker compose build && docker compose up -d`
- The Code node requires `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` env var
- Temp files are written to `/tmp/` and cleaned up automatically
- If n8n crashes with OOM, the video may be too large — check image count and duration

### Gemini API issues
- "API key not valid": Verify at [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
- 429 Too Many Requests: Free tier rate limit hit — wait a few minutes
- Gemini 3 Flash has 5 RPM on free tier — sufficient for 1 script + 1 voiceover per run

### Image generation issues (ComfyUI SDXL)
- Verify ComfyUI is running: `curl http://localhost:8188/system_stats`
- "Connection refused": ComfyUI not running or firewall blocking port 8188. Run `comfyui\setup\run_api_server.bat` and check Windows Firewall
- "Model not found": SDXL base 1.0 model not downloaded. Run `comfyui\setup\install-models.ps1`
- OOM errors: Close other GPU applications. SDXL base needs ~5-6GB VRAM
- Images are 768x1344 — FFmpeg upscales to 1080x1920 in the video composition step
- Task runner timeout set to 9000s (150 min) via `N8N_RUNNERS_TASK_TIMEOUT=9000` in docker-compose.yml (value is in seconds)

### Video animation issues (ComfyUI Hunyuan)
- Each clip takes ~7-12 minutes — total for 8 clips is ~60-100 minutes. This is normal
- OOM on HunyuanVideo: Reduce `temporal_size` from 32 to 16 in the workflow template, or reduce frames from 49 to 33
- WEBP output issues: If FFmpeg can't decode, change `SaveAnimatedWEBP` to `SaveAnimatedPNG` in `comfyui/workflows/hunyuan-i2v-gguf-q4.json`
- Time budget exceeded: If total exceeds 9000s budget (150 min), remaining clips get static MP4 fallback
- VRAM: HunyuanVideo I2V needs ~7-8GB VRAM. Cannot run simultaneously with SDXL (ComfyUI auto-swaps models)

### YouTube upload fails
- Re-authorize OAuth2 if token expired
- Quota: 10,000 units/day, upload = 1,600 units (~6 uploads/day)
- Video must be under 60 seconds and include `#Shorts`

## Modification Guide

| What | How |
|---|---|
| Change news sources | Edit Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit Generate Script (Gemini) prompt word count target (currently 110-120 words) |
| Change TTS voice | Edit Generate Voiceover jsonBody `voiceName` field. Options: `Kore`, `Charon`, `Fenrir`, `Aoede`, `Puck`, `Zephyr` |
| Change number of images | Edit Generate Script prompt (currently 8 IMAGE_PROMPTS) |
| Change image model | Edit the FLUX workflow template in `comfyui/workflows/flux-nf4-text-to-image.json` |
| Change video model | Edit the HunyuanVideo workflow template in `comfyui/workflows/hunyuan-i2v-gguf-q4.json` |
| Reduce VRAM usage | Lower `temporal_size` (32→16) or frames (49→33) in the HunyuanVideo template |
| Schedule daily runs | Replace Manual Trigger with Schedule Trigger (cron: `0 9 * * *`) |
| Change playlist | Edit Add to Playlist node `playlistId` field |
| Remove playlist | Delete Add to Playlist node, connect Upload to YouTube → Success Output |
| Multi-platform posting | Add Blotato node after YouTube upload |

## Version History
- **v7.1** (2026-03-28): Removed Instagram Reels cross-posting and Schedule Trigger. Back to 16 nodes, manual trigger only.
- **v7.0** (2026-03-14): Added Instagram Reels cross-posting. 16→26 nodes (+10 new nodes, +10 connections). Fork after `composeVideo` — YouTube branch unchanged; Instagram branch posts 4x/week (Mon/Wed/Fri/Sun) gated by IF node. Uses Facebook Graph API Resumable Upload (no cloud storage). Same video re-used, Instagram-specific captions (emojis, 20 hashtags, no #Shorts). Schedule Trigger (9AM daily) added alongside Manual Trigger. New placeholder values: `YOUR_IG_USER_ID` + `YOUR_IG_ACCESS_TOKEN` in `prepareInsta` node.
- **v6.9** (2026-03-09): scriptGen model updated to `gemini-3-flash-preview` (Gemini 3 Flash). TTS stays on `gemini-2.5-flash-preview-tts`. **Full end-to-end run confirmed successful.**
- **v6.8** (2026-03-09): Script stays 110-120 words (~45s narration). `N8N_RUNNERS_TASK_TIMEOUT` 7200→9000 (150 min). animateImages `GLOBAL_BUDGET_MS` 6000000→9000000ms (150 min), exec timeout 6600000→9600000ms (160 min). Runtime: ~80-110 min.
- **v6.7** (2026-03-09): HunyuanVideo frames 25→49 (2.04s clips). Script 80-95→110-120 words. Word count validation (throws if <90). Poll timeout 1200s→1800s. Fixed successOutput videoId reading `contentDetails.videoId`.
- **v6.6** (2026-03-09): Fixed minterpolate+xfade — two-pass compose: Pass 1 minterpolate at native 24fps→60fps + setpts + save intermediate; Pass 2 xfade on clean PTS. Compose ~8-12 min.
- **v6.5** (2026-03-08): Quality pass: generateImages 20→30 steps, dpmpp_2m+karras+cfg7.5. animateImages KSampler 15→20 steps. composeVideo: Lanczos, unsharp, color grade, slow encoder, 192k audio.
- **v6.4** (2026-03-08): Fixed jittery slow-motion with `minterpolate`. Fixed animated WEBP decode: replaced `SaveAnimatedWEBP` with `SaveImage` (PNG frames), assemble to MP4 at 24fps.
- **v6.3** (2026-03-08): Fixed `fps=30` must come after `trim+setpts`. Fixed `ffprobe` permissions in Docker — replaced with `ffmpeg -i` + regex.
- **v6.2** (2026-03-08): Fixed HunyuanVideo I2V 12-node workflow structure. HunyuanImageToVideo is conditioning node — requires separate KSampler. Fixed model paths and param names.
- **v6.1** (2026-03-07): Replaced FLUX.1 Dev NF4 with SDXL base 1.0. HunyuanVideo 49→25 frames, 20→15 steps. Runtime: 40-60 min.
- **v6.0** (2026-03-02): Local AI generation via ComfyUI. Replaced cloud image APIs (Pollinations/Pexels/gradient) with FLUX.1 Dev NF4 text-to-image (768x1344, ~60s/image). Added HunyuanVideo I2V Q4 GGUF image-to-video animation (544x960, 49 frames, ~7-12min/clip). Replaced FFmpeg Ken Burns zoom/pan with video clip stitching + slow-stretch effect. New node: Animate Images (ComfyUI Hunyuan). Rewritten nodes: Generate Images (ComfyUI FLUX), Compose Video (FFmpeg). Docker timeout increased to 2 hours. 16 nodes, 15 connections. Runtime: 75-115 min. $0.00/month (fully local).
- **v5.8** (2026-02-25): Fixed Pollinations.ai URL — migrated from legacy `image.pollinations.ai/prompt/` (down since Feb 13) to new unified `gen.pollinations.ai/image/` endpoint. API keys now hardcoded in Code node (n8n sandbox blocks env var access). Added provider tracking output (`providers`, `providerSummary`). Reduced inter-image delay from 5s to 3s. 15 nodes, 14 connections. $0/month.
- **v5.7** (2026-02-25): Removed Together.ai (no longer free). Pollinations.ai with secret key is now primary provider, Pexels stock photos fallback, FFmpeg gradient last resort. 3-provider stack. Removed `TOGETHER_API_KEY` env var. 15 nodes, 14 connections. $0/month.
- **v5.6** (2026-02-25): Overhauled image generation with 4-provider fallback. Added Together.ai, Pollinations.ai secret key, Pexels stock photos, FFmpeg gradient. Global 780s time budget prevents timeout. 15 nodes, 14 connections.
- **v5.5** (2026-02-24): Fixed Gemini returning wrong format (STORY_TITLE/KEY_FACTS instead of SCRIPT/TITLE/IMAGE_PROMPTS). Removed conflicting format instructions from Pick Best Story prompt. Added system instruction to Generate Script node enforcing exact output keys. 15 nodes, 14 connections.
- **v5.4** (2026-02-24): Fixed Pollinations.ai rate limiting (6/8 images falling back to gradient). Increased delays and retries. Added `N8N_RUNNERS_HEARTBEAT_INTERVAL=300` to prevent FFmpeg render kill. 15 nodes, 14 connections.
- **v5.3** (2026-02-24): Fixed FFmpeg gradient fallback syntax error (unescaped double quotes). Added auto-retry (3 attempts, 5s delay) to Generate Script node for transient Gemini 503 errors. 15 nodes, 14 connections.
- **v5.2** (2026-02-23): Robust Parse Script JSON — `findScriptData()` recursively searches for SCRIPT field in any nesting structure. Handles flat, wrapped (`YOUTUBE_SHORT`), and nested (`story_analysis` + `youtube_short_script`) Gemini response formats. Case-insensitive key matching.
- **v5.1** (2026-02-23): Triple-provider image fallback: Pollinations.ai → HuggingFace FLUX.1 → FFmpeg gradient. Workflow never fails on image generation. Task runner timeout increased to 900s. Synced export JSON with deployed code.
- **v5.0** (2026-02-23): Switched image generation from Gemini (0 free quota) to HuggingFace Spaces FLUX.1 (free, no API key). Switched script generation from Gemini 2.0 Flash (0 quota) to Gemini 2.5 Flash (5 RPM). Merged Split Image Prompts + Generate Images + Collect All Images into single Code node. 15 nodes, 14 connections. $0.00/video.
- **v4.0** (2026-02-16): Migrated to completely free stack. Replaced OpenAI (GPT-5, DALL-E 3, TTS) with Gemini 2.0 Flash + 2.5 Flash Image + 2.5 Flash TTS (single Google AI Studio API key). Replaced Creatomate with local FFmpeg Ken Burns effect. 8 images instead of 4. 17 nodes, 16 connections. $0.00/video.
- **v3.1** (2026-02-09): Added Add to Playlist node — videos are automatically added to a YouTube playlist after upload. 24 nodes, 23 connections.
- **v3.0** (2026-02-09): Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs). Split video data prep into 3 lightweight nodes to avoid OOM. Privacy set to public. 23 nodes, 22 connections.
- **v2.0** (2026-02-08): Replaced AI Agent with direct HTTP fetches. DALL-E via HTTP Request for URL output. Added render validation. 21 nodes.
- **v1.0** (2026-02-07): Initial creation. 18 nodes, manual trigger, Creatomate free tier.
