# YouTube Shorts - Tech News Automation

## Overview
- **Trigger**: Manual (click to run)
- **Nodes**: 15 | **Connections**: 14
- **Estimated Runtime**: 3-5 minutes per video
- **Monthly Cost**: $0.00 (all free APIs + local FFmpeg)
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
[Generate Script (Gemini)] -- Gemini 2.5 Flash: script, title, description, tags, 8 image prompts
    |
    v
[Parse Script JSON] -- Code node: parses Gemini JSON response
    |
    v
[Generate Images (FLUX)] -- Code node: Pollinations.ai / Pexels / gradient, 8x images (768x1344)
    |
    v
[Generate Voiceover (Gemini TTS)] -- Gemini 2.5 Flash TTS: PCM audio (base64)
    |
    v
[Compose Video (FFmpeg)] -- Code node: Ken Burns zoom/pan + crossfade + audio overlay
    |
    v
[Prepare YouTube Metadata] -- Adds #Shorts, sets category, formats tags
    |
    v
[Upload to YouTube] -- YouTube Data API v3
    |
    v
[Add to Playlist] -- Adds video to specified YouTube playlist
    |
    v
[Success Output] -- Returns video URL
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
- URL: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=YOUR_GEMINI_API_KEY`
- Body: JSON with `contents`, `systemInstruction`, and `generationConfig`
- `responseMimeType: 'application/json'` forces structured JSON output
- System prompt: "tech news researcher and YouTube Shorts scriptwriter"
- Requests: SCRIPT (80-95 words), TITLE (under 70 chars), DESCRIPTION, TAGS, IMAGE_PROMPTS (8 vertical 9:16 prompts)
- Timeout: 60000ms

### Node 8: Parse Script JSON
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseScript`

Parses Gemini JSON response from `candidates[0].content.parts[0].text`. Uses `findScriptData()` to recursively search for the SCRIPT field up to 2 levels deep — handles flat `{SCRIPT, ...}`, wrapped `{YOUTUBE_SHORT: {SCRIPT, ...}}`, and nested `{story_analysis: {...}, youtube_short_script: {SCRIPT, ...}}` formats. Normalizes both UPPER and lowercase keys. Falls back to regex extraction if response isn't clean JSON. Validates at least 4 image prompts.

### Node 9: Generate Images (FLUX)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `generateImages`
- **External APIs**: 3-provider fallback (all free, API keys hardcoded in Code node)

**Providers** (tried in order):
1. **Pollinations.ai** — `GET gen.pollinations.ai/image/{prompt}?model=flux&width=768&height=1344` with `Bearer` secret key header (no rate limits). 45s timeout, 2 attempts.
2. **Pexels** — Keyword extraction from prompt, `GET api.pexels.com/v1/search?query={keywords}&orientation=portrait`, downloads `src.large2x` (real stock photos). 15s timeout.
3. **FFmpeg gradient** — local solid-color PNG generation using `0x` hex colors (always works, guaranteed fallback)

**Logic**:
1. Takes 8 image prompts from Parse Script JSON
2. API keys hardcoded in Code node jsCode (n8n sandbox blocks env var access; same approach as Gemini API key in URL)
3. Writes a helper Node.js script to `/tmp/` (sandbox escape for `https` module access)
4. Global 780s time budget with per-image budget checks
5. For each prompt, tries providers in order until one succeeds (skips providers with missing keys)
6. 3s delay between images
7. Returns `imageBase64Array`, `providers` array, and `providerSummary` string

**Image specs**: 768x1344 pixels (approximately 9:16), base64-encoded.

**Note**: The workflow **never fails** on image generation — at worst it falls back to gradient backgrounds. The code gracefully skips providers with missing keys.

### Node 10: Generate Voiceover (Gemini TTS)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `voiceover`
- **Auth**: API key in URL query parameter (no n8n credential)

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

### Node 11: Compose Video (FFmpeg)
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `composeVideo`
- **Requires**: `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` and FFmpeg installed

**Logic**:
1. Gets images from `Generate Images (FLUX)` node — `imageBase64Array`
2. Writes 8 base64 images to `/tmp/n8n_video_*/img_0.png` ... `img_7.png`
3. Writes base64 PCM audio → converts to WAV via FFmpeg (`-f s16le -ar 24000 -ac 1`)
4. Probes audio duration to calculate per-image timing
5. Applies Ken Burns effect: alternating zoom-in/zoom-out on each image
6. Crossfade transitions (0.5s) between images
7. Overlays audio track
8. Output: 1080x1920 vertical MP4 (libx264, CRF 23, AAC audio)
9. Returns video as n8n binary data
10. Cleans up temp files

**Estimated render time**: 30-60 seconds for ~45-sec video at 1080x1920.

### Node 12: Prepare YouTube Metadata
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `prepareYT`

Appends `#Shorts` to title, adds hashtags to description, sets category 28 (Science & Technology), truncates title to 100 chars. Passes through binary video data.

### Node 13: Upload to YouTube
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `youtubeUpload`
- **Credential**: YouTube OAuth2 API

Resource: `video`, Operation: `upload`. Binary property: `video`. Privacy: `public` (change to `unlisted` for testing). Category: 28. Tags joined with commas, notifySubscribers: true.

### Node 14: Add to Playlist
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `addToPlaylist`
- **Credential**: YouTube OAuth2 API (same as Upload to YouTube)

Resource: `playlistItem`. `playlistId`: `=YOUR_PLAYLIST_ID` — **SETUP REQUIRED** (use expression format `=PLxxxxxxx` to avoid dropdown loading error). `videoId`: `={{ $json.uploadId || $json.id || $json.videoId }}`.

### Node 15: Success Output
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `successOutput`

Returns `videoUrl`, `videoId`, `uploadTime`. Constructs YouTube Shorts URL from video ID.

## Connection Map

```
Source Node                       -> Target Node                       | Type
---------------------------------------------------------------------------------
Manual Trigger                    -> Fetch Reddit Posts                 | main
Fetch Reddit Posts                -> Format Reddit Data                 | main
Format Reddit Data                -> Fetch HN Posts                     | main
Fetch HN Posts                    -> Pick Best Story                    | main
Pick Best Story                   -> Prepare Story Data                 | main
Prepare Story Data                -> Generate Script (Gemini)           | main
Generate Script (Gemini)          -> Parse Script JSON                  | main
Parse Script JSON                 -> Generate Images (FLUX)             | main
Generate Images (FLUX)            -> Generate Voiceover (Gemini TTS)    | main
Generate Voiceover (Gemini TTS)   -> Compose Video (FFmpeg)             | main
Compose Video (FFmpeg)            -> Prepare YouTube Metadata            | main
Prepare YouTube Metadata          -> Upload to YouTube                  | main
Upload to YouTube                 -> Add to Playlist                    | main
Add to Playlist                   -> Success Output                     | main
```

## Required Credentials

| # | Credential Name | Type | Where to Get | Used By |
|---|---|---|---|---|
| 1 | Google AI Studio (Gemini) | API Key in URL | [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys) — free | Script Gen, Voiceover TTS |
| 2 | Pollinations.ai | Hardcoded in Code node | [auth.pollinations.ai](https://auth.pollinations.ai/) — free | Generate Images |
| 3 | Pexels | Hardcoded in Code node | [pexels.com/api](https://www.pexels.com/api/) — free | Generate Images |
| 4 | YouTube OAuth2 API | OAuth2 | Google Cloud Console → YouTube Data API v3 → OAuth2 credentials | Upload to YouTube, Add to Playlist |

**Note**: Image generation API keys are optional — the code gracefully falls back through providers.

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
- Gemini 2.5 Flash has 5 RPM on free tier — sufficient for 1 script + 1 voiceover per run

### Image generation issues
- The node has 3-provider fallback (Pollinations → Pexels → FFmpeg gradient) — it should never fully fail
- All images are gradients: API keys may be missing from the Code node. Open Generate Images (FLUX) and verify the `pollinationsKey` and `pexelsKey` values in the config object
- Pollinations.ai errors: With secret key, there are no rate limits. The API endpoint is `gen.pollinations.ai/image/` (not the legacy `image.pollinations.ai`)
- Pexels returns irrelevant photos: The keyword extraction from AI prompts isn't perfect — Pexels is a fallback, not primary
- If all external providers fail, gradient backgrounds are used (solid-color images)
- Images are 768x1344 — FFmpeg upscales to 1080x1920 in the video composition step
- Task runner timeout set to 900s via `N8N_RUNNERS_TASK_TIMEOUT=900` in docker-compose.yml
- Global 780s time budget prevents timeout — auto-falls back to faster providers when time is low

### YouTube upload fails
- Re-authorize OAuth2 if token expired
- Quota: 10,000 units/day, upload = 1,600 units (~6 uploads/day)
- Video must be under 60 seconds and include `#Shorts`

## Modification Guide

| What | How |
|---|---|
| Change news sources | Edit Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit Generate Script (Gemini) prompt word count target (currently 80-95 words) |
| Change TTS voice | Edit Generate Voiceover jsonBody `voiceName` field. Options: `Kore`, `Charon`, `Fenrir`, `Aoede`, `Puck`, `Zephyr` |
| Change number of images | Edit Generate Script prompt (currently 8 IMAGE_PROMPTS) |
| Change image providers | Edit Generate Images (FLUX) code — modify provider order or add new providers. API keys are hardcoded in jsCode |
| Schedule daily runs | Replace Manual Trigger with Schedule Trigger (cron: `0 9 * * *`) |
| Change playlist | Edit Add to Playlist node `playlistId` field |
| Remove playlist | Delete Add to Playlist node, connect Upload to YouTube → Success Output |
| Multi-platform posting | Add Blotato node after YouTube upload |

## Version History
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
