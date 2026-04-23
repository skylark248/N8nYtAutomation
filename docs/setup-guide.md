# YouTube Shorts Workflow - Complete Setup Guide (v8.10)

## Prerequisites
- n8n running locally in Docker at http://localhost:5678
- Google account with a YouTube channel
- Docker with FFmpeg support (see Step 1)
- API accounts for cloud AI services (fal.ai, ElevenLabs — free tiers available for testing)

---

## Step 1: Start n8n with Docker Compose

The workflow uses FFmpeg to compose video locally. The `D:\N8n\` directory contains a `Dockerfile` and `docker-compose.yml` that build a custom n8n image with FFmpeg baked in.

```bash
cd D:\N8n

# First time only — build the custom image with FFmpeg:
docker compose build

# Start n8n:
docker compose up -d
```

This automatically:
- Builds a custom image with FFmpeg + ffprobe pre-installed
- Sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` (required for video composition and sandbox-escape HTTP calls)
- Sets task timeout to 9000s (150 min) via `N8N_RUNNERS_TASK_TIMEOUT`
- Sets runner match timeout to 600s (10 min) via `N8N_RUNNERS_TASK_REQUEST_TIMEOUT` — prevents `"Task request timed out after 60 seconds"` after long-running Code nodes
- Mounts `D:\Github Clones\N8nYtAutomation\videos` → `/home/node/videos` (for local export)
- Mounts `D:\Github Clones\N8nYtAutomation\keys.json` → `/home/node/keys.json:ro` (API keys)
- Auto-restarts with Docker Desktop (`restart: always`)

Open [http://localhost:5678](http://localhost:5678) and create an account when prompted.

---

## Step 2: Create keys.json

All API keys are stored in `keys.json` at the repo root (gitignored — never committed). This file is mounted read-only into Docker at `/home/node/keys.json`.

Create the file at `D:\Github Clones\N8nYtAutomation\keys.json`:

```json
{
  "geminiApiKey": "YOUR_GEMINI_API_KEY",
  "falApiKey": "YOUR_FAL_API_KEY",
  "elevenLabsApiKey": "YOUR_ELEVENLABS_API_KEY",
  "stabilityApiKey": "YOUR_STABILITY_API_KEY",
  "youtubePlaylistId": "PLxxxxxxxxxxxxxxxx"
}
```

Fill in the keys as you complete the steps below. The workflow reads them at runtime — no API keys are stored inside n8n nodes.

---

## Step 3: Import the Workflow

1. Open [http://localhost:5678](http://localhost:5678)
2. Click **Workflows** in the left sidebar
3. Click **"Add workflow"** → **"Import from file"**
4. Select `exports/youtube-shorts-tech-news.json`
5. The workflow appears with all 18 nodes and 17 connections

---

## Credential 1: Google AI Studio API Key (Gemini — Script Generation)

**Used by**: Generate Script (Gemini) node only

### Get API Key
1. Go to [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
2. Sign in with your Google account
3. Click **"Create API Key"**
4. Copy the key

**Cost**: Free. No billing required.

### Add to keys.json
```json
{
  "geminiApiKey": "AIza..."
}
```

The workflow reads the key from `/home/node/keys.json` — no n8n credential setup needed.

### Verify
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY" | head -5
```

---

## Credential 2: fal.ai API Key (Images Fallback + Video Clips + Music)

**Used by**: Generate Images (SD3/Flux), Generate Video Clips, Generate Background Music nodes

### Get API Key
1. Go to [fal.ai/dashboard](https://fal.ai/dashboard) and sign up
2. Navigate to **API Keys**
3. Click **"Add key"** and copy it

**Cost per run:**
- fal.ai Flux Schnell (fallback images, 6×): ~$0.09
- fal.ai Kling v1.6 I2V (video clips, 6×5s): ~$2.10
- fal.ai Stable Audio (45s music): ~$0.38
- **Total fal.ai per run**: ~$2.57 (with all fal.ai services)

### Add to keys.json
```json
{
  "falApiKey": "YOUR_FAL_KEY"
}
```

### Verify
```bash
curl -H "Authorization: Key YOUR_KEY" https://fal.run/fal-ai/flux/schnell \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","image_size":"landscape_4_3","num_images":1}'
```
Should return JSON with an `images[0].url`.

---

## Credential 3: ElevenLabs API Key (Voiceover)

**Used by**: Generate Voiceover (ElevenLabs) node

### Get API Key
1. Go to [elevenlabs.io/app/settings/api-keys](https://elevenlabs.io/app/settings/api-keys) and sign up
2. Click **"Create API Key"**
3. Copy it

**Cost**: ~$0.17/run (Antoni voice, `eleven_multilingual_v2`, ~500 chars/script).
**Plan required**: Starter ($5/month) or above — Free tier doesn't support the TTS API via REST. Starter includes 30,000 chars/month (~60+ runs).

### Add to keys.json
```json
{
  "elevenLabsApiKey": "YOUR_ELEVENLABS_API_KEY"
}
```

**Note**: The workflow uses `output_format=mp3_44100_128` (128kbps). The 192kbps format requires Creator plan — don't change this unless you upgrade.

### Verify
```bash
curl -H "xi-api-key: YOUR_KEY" https://api.elevenlabs.io/v1/user
```

---

## Credential 4: Stability AI API Key (Images Primary — Optional)

**Used by**: Generate Images (SD3/Flux) node — as primary image provider

When present, the workflow uses Stability AI SD3 for image generation (~13 credits/image = 78 credits for 6 images). If your credit balance drops below 78, it automatically falls back to fal.ai Flux Schnell for the entire run. If the key is missing or left as placeholder, fal.ai Flux is used for all runs.

### Get API Key
1. Go to [platform.stability.ai/account/keys](https://platform.stability.ai/account/keys) and sign up
2. Click **"Create API Key"**
3. Copy it

**Cost**: ~$0.08/run (6 images × 13 credits). Free trial credits available. 1,000 credits ≈ $10 ≈ 77 images ≈ 12 full runs.

### Add to keys.json
```json
{
  "stabilityApiKey": "YOUR_STABILITY_API_KEY"
}
```

Leave as `"YOUR_STABILITY_API_KEY"` (placeholder) to always use fal.ai Flux instead.

---

## Credential 5: YouTube OAuth2

**Used by**: Upload to YouTube, Add to Playlist nodes

### Step 1: Create Google Cloud Project
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with the **same Google account** as your YouTube channel
3. Click the project dropdown (top-left) → **"New Project"**
4. Name: `n8n YouTube Automation` → **Create**
5. Make sure this new project is selected

### Step 2: Enable YouTube Data API v3
1. Go to **APIs & Services** → **Library**
2. Search for **"YouTube Data API v3"**
3. Click it → **"Enable"**

### Step 3: Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **"External"** → **Create**
3. Fill in: App name `n8n YouTube`, your email for support + developer contact
4. Click **"Save and Continue"**
5. **Scopes** page → **"Add or Remove Scopes"** → add `youtube.upload` and `youtube` → **Update** → **Save and Continue**
6. **Test users** page (CRITICAL — skipping causes "Access blocked"):
   - Click **"Add Users"** → add your exact Google email
   - **"Save and Continue"**
7. Click **"Back to Dashboard"**

### Step 4: Create OAuth2 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"OAuth client ID"**
3. Application type: **Web application**
4. Name: `n8n`
5. Under **Authorized redirect URIs** → **"+ Add URI"**:
   `http://localhost:5678/rest/oauth2-credential/callback`
6. **Create** → copy **Client ID** and **Client Secret**

### Step 5: Add Credential to n8n
1. Open the **"Upload to YouTube"** node in n8n
2. Click **"Credential to connect with"** → **"Create New Credential"** → **"YouTube OAuth2 API"**
3. Paste Client ID and Client Secret
4. Click **"Sign in with Google"**
5. If you see "This app isn't verified" → click **"Advanced"** → **"Go to n8n YouTube (unsafe)"** — this is safe, it's your own app
6. Click **"Allow"** → you should see **"Connected"**
7. **Save**
8. Assign the same credential to the **"Add to Playlist"** node

### YouTube API Quotas
- Daily quota: 10,000 units | Video upload: ~1,600 units → max ~6 uploads/day
- Quota resets at midnight Pacific Time
- OAuth tokens auto-refresh. If you get auth errors after 7 days, your app is in "Testing" mode — publish it: Google Cloud Console → OAuth consent screen → **Publish App**

---

## Playlist Setup

### Get Your Playlist ID
1. Open YouTube → go to the playlist you want videos added to (or create one)
2. URL will look like: `https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxx`
3. Copy the part after `list=`

### Configure in keys.json
```json
{
  "youtubePlaylistId": "PLxxxxxxxxxxxxxxxxxx"
}
```

### Configure in n8n
1. Click on the **"Add to Playlist"** node
2. Verify `playlistId` is set to `={{ $('Prepare YouTube Metadata').first().json.playlistId }}`

### Skip Playlist
Delete the **"Add to Playlist"** node and connect **"Upload to YouTube"** directly to **"Success Output"**.

---

## Post-Setup: First Test Run

### Change to unlisted first
1. Open the **"Upload to YouTube"** node
2. Change `privacyStatus` from `public` to `unlisted`
3. Save

### Run the workflow
1. Open the workflow in n8n
2. Click **"Test Workflow"** (play button, top-right)
3. Wait **25-40 minutes** for full execution
4. Watch nodes turn green as they complete

### Verify checklist
- [ ] Reddit and HN data fetched (nodes 2-4 green)
- [ ] Story selected from top 3 candidates — 14-day dupe check passed (node 5 green)
- [ ] Gemini 3 Flash generated 75-90 word HECK-loop script + 6 image prompts (node 7 green)
- [ ] Script validated: ≥65 words, ≥3 tags, ≥5 image prompts (node 8 green)
- [ ] 6 vertical images generated — Stability AI SD3 or fal.ai Flux Schnell (node 9 green)
- [ ] 6 video clips animated by fal.ai Kling v1.6 I2V (5s each, 9:16) (node 10 green)
- [ ] MP3 voiceover generated by ElevenLabs Antoni (node 11 green)
- [ ] 45s background music generated by fal.ai Stable Audio (or silence fallback) (node 12 green)
- [ ] FFmpeg composed 1080×1920 MP4 (~38-45s, no burned captions) (node 13 green)
- [ ] Video saved locally to `videos/{timestamp}_{title}/video.mp4` (node 14 green)
- [ ] Video uploaded to YouTube as unlisted (node 16 green)
- [ ] Video added to playlist (if configured) (node 17 green)

### Switch to public
Once verified, change `privacyStatus` back to `public` for future runs.

---

## Credential Summary

| # | Credential | Where Set | Nodes | Cost/Run |
|---|---|---|---|---|
| 1 | Google AI Studio (Gemini) | `keys.json` → `/home/node/keys.json` | Generate Script | $0.00 (free) |
| 2 | fal.ai | `keys.json` → `/home/node/keys.json` | Generate Images (fallback), Generate Video Clips, Generate Music | ~$2.57 |
| 3 | ElevenLabs | `keys.json` → `/home/node/keys.json` | Generate Voiceover | ~$0.17 |
| 4 | Stability AI | `keys.json` → `/home/node/keys.json` | Generate Images (primary) | ~$0.08 (optional) |
| 5 | YouTube OAuth2 | n8n credential UI | Upload to YouTube, Add to Playlist | Free |

**Total per video**: ~$2.82 (SD3 images + all cloud AI) or ~$2.73 (all fal.ai)
**Monthly (30 Shorts)**: ~$44/month

> **Instagram**: Upload manually using `upload-info.txt` saved in each `videos/{timestamp}_{title}/` folder — pre-written caption + hashtags ready to paste.

---

## Troubleshooting

### "Task request timed out after 60 seconds"
- Full error: `"Your Code node task was not matched to a runner within the timeout period"`
- This is the runner *match* timeout — different from the execution timeout (`N8N_RUNNERS_TASK_TIMEOUT`)
- Cause: after a long-running Code node (composeVideo, generateVideo), the runner process restarts/reconnects and the next Code node fires before it's available
- Fix: ensure `N8N_RUNNERS_TASK_REQUEST_TIMEOUT=600` is in `D:\N8n\docker-compose.yml`, then `docker compose up -d` to recreate the container

### "Cannot require 'child_process'" in any Code node
- Ensure you started n8n via `docker compose up -d` from `D:\N8n`
- The custom docker-compose.yml sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os`

### FFmpeg "command not found"
- Rebuild the custom image: `docker compose build && docker compose up -d` from `D:\N8n`

### keys.json not found
- Verify the volume mount in `D:\N8n\docker-compose.yml` includes: `"d:/Github Clones/N8nYtAutomation/keys.json:/home/node/keys.json:ro"`
- Run `docker compose restart` after adding the mount

### fal.ai 401 Unauthorized
- Verify the API key at fal.ai/dashboard
- The key is read from `keys.json` — ensure `falApiKey` is set correctly

### ElevenLabs 403 or quota exceeded
- Free tier doesn't support TTS API — upgrade to Starter plan ($5/month)
- Starter: 30,000 chars/month. Each script is ~75-90 words (~450 chars) — about 66 runs/month

### ElevenLabs 422 output format error
- The workflow uses `mp3_44100_128` — don't change to `mp3_44100_192` unless on Creator plan

### Stability AI 402 or low credits
- The workflow auto-checks your balance before each run
- If credits < 78 (needed for 6 images), it falls back to fal.ai Flux automatically
- Buy more credits at platform.stability.ai

### Gemini rate limits / 503 errors
- Free tier: 15 RPM on Gemini 3 Flash. Wait a minute and retry
- 503 "Service unavailable" errors are transient — just re-run the workflow

### Gemini JSON truncated / "No JSON object found"
- Fixed in v8.4 via `thinkingConfig: { thinkingBudget: 0 }` + `maxOutputTokens: 8192`
- If it recurs: verify the `scriptGen` node has both config values set

### "OAuth token expired" on YouTube
- Go to the YouTube credential in n8n → click **"Sign in with Google"** again
- If it keeps expiring every 7 days: publish your Google Cloud app (OAuth consent screen → Publish App)

### "Access blocked" on YouTube OAuth
- Add yourself as a test user: Google Cloud Console → APIs & Services → OAuth consent screen → Audience → Add Users → add your Google email

### "Redirect URI mismatch" on YouTube OAuth
- In Google Cloud Console → Credentials → edit OAuth client
- Redirect URI must be exactly: `http://localhost:5678/rest/oauth2-credential/callback` (no trailing slash, http not https)

### Local video export not working
- Verify the volume mount in `D:\N8n\docker-compose.yml`: `"d:/Github Clones/N8nYtAutomation/videos:/home/node/videos"`
- Verify `/home/node/videos` is in `N8N_RESTRICT_FILE_ACCESS_TO`
- Run `docker compose restart` from `D:\N8n` after adding the volume mount

### Video too long (>45s)
- Check `scriptGen` word target — should be 75-90 words
- Check `parseScript` min word count — should be 65

### Duplicate story detected every run
- Delete `/home/node/videos/last_stories.json` inside Docker: `docker exec n8n sh -c "rm /home/node/videos/last_stories.json"`
- This resets the 14-day history

---

## Migrating to Another n8n Instance

### Export/Import via n8n UI
1. Open workflow → three dots menu → **"Download"** (saves `.json` — no credentials included)
2. On new instance: **Import from file** → re-configure all credentials

### After Migration Checklist
- [ ] Copy `keys.json` to the new repo root and verify all API keys
- [ ] Create and assign **YouTube OAuth2** credential in n8n
- [ ] Update `playlistId` in `keys.json` (or remove Add to Playlist node)
- [ ] Update YouTube OAuth2 redirect URI to match the new instance URL
- [ ] Add both volume mounts to `docker-compose.yml` (videos + keys.json)
- [ ] Run `docker compose build && docker compose up -d`
- [ ] Verify FFmpeg: `docker exec n8n ffmpeg -version`
- [ ] Test with `privacyStatus: "unlisted"` before going public
