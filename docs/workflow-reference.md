# YouTube Shorts - Tech News Automation

## Overview
- **Trigger**: Manual (click to run)
- **Nodes**: 24 | **Connections**: 23
- **Estimated Runtime**: 8-12 minutes per video
- **Monthly Cost**: ~$7.23 (OpenAI) + $0 (Creatomate free tier, 10 videos)
- **Import file**: `exports/youtube-shorts-tech-news.json`

## Pipeline

```
Manual Trigger
    |
    v
[Fetch Reddit Posts] -- GET reddit.com/r/technology/hot.json
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
[Prepare Story Data] -- Code node: formats combined prompt for GPT-5
    |
    v
[Generate Script (GPT-5)] -- Creates script, title, description, tags, image prompts
    |
    v
[Parse Script JSON] -- Code node: parses GPT-5 JSON response
    |
    v
[Split Image Prompts] -- Splits array into individual items
    |
    v
[Generate Images (DALL-E 3)] -- 4x vertical images via HTTP Request (returns URLs)
    |
    v
[Collect All Images] -- Code node: extracts image URLs into array
    |
    v
[Generate Voiceover (TTS)] -- OpenAI TTS API, voice: onyx, mp3 binary
    |
    v
[Prepare Video Data] -- Code node: sets binary filename, extracts image URLs
    |
    v
[Upload Audio] -- HTTP POST: uploads voiceover mp3 to tmpfiles.org
    |
    v
[Build Video Payload] -- Code node: combines image URLs + audio download URL
    |
    v
[Compose Video (Creatomate)] -- HTTP POST: sends image URLs + audio URL to template
    |
    v
[Wait for Rendering] -- 90 seconds
    |
    v
[Check Render Status] -- GET /renders/{id} to verify completion
    |
    v
[Validate Render] -- Code node: checks status === 'succeeded'
    |
    v
[Download Rendered Video] -- GET rendered MP4
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
  "url": "https://www.reddit.com/r/technology/hot.json?limit=15",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [{ "name": "User-Agent", "value": "n8n-bot/1.0" }]
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

### Node 7: Generate Script (GPT-5)
- **Type**: `n8n-nodes-base.openAi` (v1)
- **ID**: `scriptGen`
- **Credential**: OpenAI API

**Note**: GPT-5 does not support custom `temperature` or `max_tokens` parameters. Use `options: {}`.

### Node 8: Parse Script JSON
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `parseScript`

Parses GPT-5 JSON response, extracts SCRIPT, TITLE, DESCRIPTION, TAGS, IMAGE_PROMPTS. Falls back to regex extraction if response isn't clean JSON.

### Node 9: Split Image Prompts
- **Type**: `n8n-nodes-base.splitOut` (v1)
- **ID**: `splitImages`

Splits `imagePrompts` array into individual items for parallel DALL-E generation.

### Node 10: Generate Images (DALL-E 3)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `generateImages`
- **Credential**: HTTP Header Auth (OpenAI key)

POST to `https://api.openai.com/v1/images/generations` with model `dall-e-3`, size `1024x1792`. Returns image URLs (not binary).

### Node 11: Collect All Images
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `collectImages`

Collects all DALL-E image URLs into a single `imageUrls` array.

### Node 12: Generate Voiceover (TTS)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `voiceover`
- **Credential**: HTTP Header Auth (OpenAI key)

POST to `https://api.openai.com/v1/audio/speech`. Voice: `onyx`. Output: binary MP3 as `voiceover` property.

### Node 13: Prepare Video Data
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `prepareVideoData`

Lightweight node: extracts `imageUrls` from Collect All Images, sets binary filename to `voiceover.mp3`. Does NOT load binary data into memory (avoids OOM).

### Node 14: Upload Audio
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `uploadAudio`

POST multipart form-data to `https://tmpfiles.org/api/v1/upload`. Uploads voiceover binary with proper `.mp3` filename. Creatomate requires real download URLs (no data URIs).

### Node 15: Build Video Payload
- **Type**: `n8n-nodes-base.code` (v2)
- **ID**: `buildVideoPayload`

Combines `imageUrls` from Prepare Video Data with `audioUrl` from tmpfiles.org upload response. Inserts `/dl/` into tmpfiles.org URL for direct download.

### Node 16: Compose Video (Creatomate)
- **Type**: `n8n-nodes-base.httpRequest` (v4.2)
- **ID**: `creatomateRender`
- **Credential**: HTTP Header Auth (Creatomate key)

POST to `https://api.creatomate.com/v1/renders`. Sends template_id + modifications for Image-1 through Image-4 sources and Audio source.

**SETUP REQUIRED**: Replace `YOUR_TEMPLATE_ID`. Template elements must have Provider set to **URL** with **Dynamic Source** checked.

### Node 17: Wait for Rendering
- **Type**: `n8n-nodes-base.wait` (v1.1) — 90 seconds

### Node 18: Check Render Status
- **Type**: `n8n-nodes-base.httpRequest` (v4.2) — GET render by ID

### Node 19: Validate Render
- **Type**: `n8n-nodes-base.code` (v2) — Throws error if status !== 'succeeded'

### Node 20: Download Rendered Video
- **Type**: `n8n-nodes-base.httpRequest` (v4.2) — GET rendered MP4 as binary

### Node 21: Prepare YouTube Metadata
- **Type**: `n8n-nodes-base.code` (v2) — Appends #Shorts to title, sets category 28 (Science & Technology)

### Node 22: Upload to YouTube
- **Type**: `n8n-nodes-base.youTube` (v1) — Uploads video binary with metadata. Privacy: public.

### Node 23: Add to Playlist
- **Type**: `n8n-nodes-base.youTube` (v1)
- **ID**: `addToPlaylist`
- **Credential**: YouTube OAuth2 API (same as Upload to YouTube)

Adds the uploaded video to a specified YouTube playlist. Uses `playlistItem` resource with `add` operation.

**SETUP REQUIRED**: Replace `YOUR_PLAYLIST_ID` with your actual YouTube playlist ID (starts with `PL...`). To find it: YouTube Studio → Playlists → click your playlist → copy the ID from the URL.

### Node 24: Success Output
- **Type**: `n8n-nodes-base.code` (v2) — Returns `videoUrl`, `videoId`, `uploadTime`. Reads `uploadId` from YouTube response.

## Connection Map

```
Source Node                  -> Target Node                  | Type
--------------------------------------------------------------------------------
Manual Trigger               -> Fetch Reddit Posts            | main
Fetch Reddit Posts           -> Format Reddit Data            | main
Format Reddit Data           -> Fetch HN Posts                | main
Fetch HN Posts               -> Pick Best Story               | main
Pick Best Story              -> Prepare Story Data            | main
Prepare Story Data           -> Generate Script (GPT-5)       | main
Generate Script (GPT-5)      -> Parse Script JSON             | main
Parse Script JSON            -> Split Image Prompts           | main
Split Image Prompts          -> Generate Images (DALL-E 3)    | main
Generate Images (DALL-E 3)   -> Collect All Images            | main
Collect All Images           -> Generate Voiceover (TTS)      | main
Generate Voiceover (TTS)     -> Prepare Video Data            | main
Prepare Video Data           -> Upload Audio                  | main
Upload Audio                 -> Build Video Payload           | main
Build Video Payload          -> Compose Video (Creatomate)    | main
Compose Video (Creatomate)   -> Wait for Rendering            | main
Wait for Rendering           -> Check Render Status           | main
Check Render Status          -> Validate Render               | main
Validate Render              -> Download Rendered Video       | main
Download Rendered Video      -> Prepare YouTube Metadata      | main
Prepare YouTube Metadata     -> Upload to YouTube             | main
Upload to YouTube            -> Add to Playlist               | main
Add to Playlist              -> Success Output                | main
```

## Required Credentials

| # | Credential Name | Type | Where to Get | Used By |
|---|---|---|---|---|
| 1 | OpenAI API | API Key | platform.openai.com -> API Keys | Generate Script (GPT-5) |
| 2 | HTTP Header Auth (OpenAI) | Header Auth | Same key as above. Name: `Authorization`, Value: `Bearer sk-...` | DALL-E 3, Voiceover (TTS) |
| 3 | HTTP Header Auth (Creatomate) | Header Auth | creatomate.com -> Dashboard -> API Key. Name: `Authorization`, Value: `Bearer cm-...` | Compose Video, Check Render Status |
| 4 | YouTube OAuth2 API | OAuth2 | Google Cloud Console -> YouTube Data API v3 -> OAuth2 credentials | Upload to YouTube, Add to Playlist |

## Creatomate Template Setup

1. Sign up at creatomate.com (free tier: 10 renders/month)
2. Create new template: 1080 x 1920 (9:16 vertical), 45 seconds
3. Add elements:
   - 4 image elements named `Image-1`, `Image-2`, `Image-3`, `Image-4`
   - Each shows for ~10 seconds with fade transitions
   - Set Provider to **URL**, check **Dynamic Source**
   - 1 audio element named `Audio`
   - Set Provider to **URL**, check **Dynamic Source**
4. Copy the template ID from the URL
5. Replace `YOUR_TEMPLATE_ID` in the Compose Video node

## Troubleshooting

### Audio upload / tmpfiles.org issues
- tmpfiles.org requires proper file extension — Prepare Video Data sets filename to `voiceover.mp3`
- If tmpfiles.org is down, any free file hosting with direct download URLs works
- Creatomate does NOT support data URIs for audio — must be a real URL

### n8n crashes with out-of-memory
- The Prepare Video Data node is intentionally lightweight (no `getBinaryDataBuffer`)
- Audio upload is handled by HTTP Request node which manages memory natively
- If n8n freezes: `docker restart n8n`

### Creatomate render fails
- Verify template_id, element names (`Image-1` through `Image-4`, `Audio`)
- All elements must have Provider = **URL** with **Dynamic Source** checked
- DALL-E image URLs expire after ~1 hour

### YouTube upload fails
- Re-authorize OAuth2 if token expired
- Quota: 10,000 units/day, upload = 1,600 units (~6 uploads/day)
- Video must be under 60 seconds and include `#Shorts`

## Modification Guide

| What | How |
|---|---|
| Change news sources | Edit Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit Generate Script (GPT-5) prompt word count target |
| Change TTS voice | Edit Generate Voiceover jsonBody `voice` field |
| Schedule daily runs | Replace Manual Trigger with Schedule Trigger (cron: `0 9 * * *`) |
| Upgrade to AI video | Replace Creatomate nodes with fal.ai Sora/Veo API |
| Change playlist | Edit Add to Playlist node `playlistId` field |
| Remove playlist | Delete Add to Playlist node, connect Upload to YouTube → Success Output |
| Multi-platform posting | Add Blotato node after YouTube upload |

## Version History
- **v3.1** (2026-02-09): Added Add to Playlist node — videos are automatically added to a YouTube playlist after upload. 24 nodes, 23 connections.
- **v3.0** (2026-02-09): Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs). Split video data prep into 3 lightweight nodes to avoid OOM. Privacy set to public. 23 nodes, 22 connections.
- **v2.0** (2026-02-08): Replaced AI Agent with direct HTTP fetches. DALL-E via HTTP Request for URL output. Added render validation. 21 nodes.
- **v1.0** (2026-02-07): Initial creation. 18 nodes, manual trigger, Creatomate free tier.
