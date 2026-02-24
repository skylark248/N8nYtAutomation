# YouTube Shorts Workflow - Complete Setup Guide

## Prerequisites
- n8n running locally in Docker at http://localhost:5678
- Google AI Studio API key (free) — [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
- Google account with a YouTube channel
- Docker with FFmpeg support (see Step 1)

---

## Step 1: Start n8n with Docker Compose

The workflow uses FFmpeg to compose video locally. The parent directory contains a `Dockerfile` and `docker-compose.yml` that build a custom n8n image with FFmpeg baked in.

```bash
cd /path/to/n8n   # parent directory containing Dockerfile + docker-compose.yml
docker compose up -d
```

This automatically:
- Builds a custom image with FFmpeg + ffprobe pre-installed
- Sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` (required for video composition)
- Mounts the current directory as n8n data volume
- Auto-restarts with Docker Desktop

Open [http://localhost:5678](http://localhost:5678) and create an account when prompted.

> **Note**: The official `n8nio/n8n` image uses a hardened Alpine without `apk`. The custom Dockerfile installs FFmpeg via `npm -g ffmpeg-static` instead.

---

## Credential 1: Google AI Studio API Key (Gemini)

**Used by**: Generate Script (Gemini), Generate Voiceover (Gemini TTS)

### Get API Key
1. Go to [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
2. Sign in with your Google account
3. Click **"Create API Key"**
4. Copy the key — you can always view it again from this page

**Cost**: Free. No billing required. Google AI Studio provides generous free tier limits.

### Add to n8n Workflow
The API key is passed directly in the URL query parameter — no n8n credential setup needed.

1. Open your imported workflow in n8n
2. Open each of these 2 nodes and replace `YOUR_GEMINI_API_KEY` in the URL:
   - **"Generate Script (Gemini)"** — URL contains `?key=YOUR_GEMINI_API_KEY`
   - **"Generate Voiceover (Gemini TTS)"** — URL contains `?key=YOUR_GEMINI_API_KEY`
3. Save the workflow

### Verify
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_KEY" | head -20
```
Should return a list of available Gemini models.

### Free Tier Limits (as of Feb 2026)
| Model | Limit |
|---|---|
| Gemini 2.5 Flash (script) | 5 RPM |
| Gemini 2.5 Flash TTS (voiceover) | 10 RPM |

These limits are sufficient for 1 script + 1 voiceover per run. Image generation uses Pollinations.ai / HuggingFace (free, no API key needed).

---

## Credential 2: YouTube OAuth2

**Used by**: Upload to YouTube, Add to Playlist

### Step 1: Create Google Cloud Project
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with the **same Google account** as your YouTube channel
3. Click the project dropdown (top-left) → **"New Project"**
4. Name: `n8n YouTube Automation` → **Create**
5. Make sure this new project is selected in the dropdown

### Step 2: Enable YouTube Data API v3
1. Go to **APIs & Services** → **Library** (left sidebar)
2. Search for **"YouTube Data API v3"**
3. Click it → **"Enable"**

### Step 3: Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **"External"** → **Create**
3. Fill in:
   - App name: `n8n YouTube`
   - User support email: your email
   - Developer contact email: your email
4. Click **"Save and Continue"**
5. **Scopes** page:
   - Click **"Add or Remove Scopes"**
   - Search and add: `youtube.upload`
   - Search and add: `youtube` (or `youtube.force-ssl`)
   - Click **"Update"** → **"Save and Continue"**
6. **Test users** page (CRITICAL — skipping this causes "Access blocked" error):
   - Click **"Add Users"**
   - Add the **exact Google email** you'll use to sign in (e.g., `your-email@gmail.com`)
   - Click **"Save and Continue"**
   - If you already skipped this step and got "Access blocked": Go to **OAuth consent screen** → **Audience** tab → **Add Users** → add your email
7. Click **"Back to Dashboard"**

### Step 4: Create OAuth2 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"OAuth client ID"**
3. Application type: **Web application**
4. Name: `n8n`
5. Under **"Authorized redirect URIs"**:
   - Click **"+ Add URI"**
   - Enter: `http://localhost:5678/rest/oauth2-credential/callback`
6. Click **"Create"**
7. Copy **Client ID** and **Client Secret** from the popup

### Step 5: Add Credential to n8n
1. Open your imported workflow in n8n
2. Click on the **"Upload to YouTube"** node
3. Click **"Credential to connect with"** → **"Create New Credential"**
4. Select **"YouTube OAuth2 API"**
5. Paste:
   - **Client ID**: from step 4
   - **Client Secret**: from step 4
6. Click **"Sign in with Google"**
7. Select your YouTube channel's Google account
8. If you see "This app isn't verified" warning:
   - Click **"Advanced"** → **"Go to n8n YouTube (unsafe)"**
   - This is safe — it's your own app
9. Click **"Allow"** for all requested permissions
10. You should see **"Connected"** in n8n
11. Click **"Save"**

### YouTube API Quotas
- Daily quota: 10,000 units
- Video upload: 1,600 units per upload
- Maximum ~6 uploads per day within free quota
- Quota resets at midnight Pacific Time

### OAuth Token Refresh
- Tokens expire periodically
- n8n auto-refreshes them, but if upload fails with auth error:
  - Go to the YouTube credential in n8n
  - Click **"Sign in with Google"** again to re-authorize
- **Important**: If your Google Cloud app is in "Testing" mode, refresh tokens expire after **7 days**. To prevent this, go to Google Cloud Console → OAuth consent screen → Publishing status → **Publish App**. Published apps don't have the 7-day expiry (you can still restrict to your own account).

---

## Playlist Setup (Optional)

The workflow includes an **"Add to Playlist"** node that automatically adds each uploaded video to a YouTube playlist.

### Get Your Playlist ID
1. Open YouTube and go to the playlist you want videos added to (or create a new one)
2. The URL will look like: `https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxx`
3. Copy the part after `list=` — that's your playlist ID (starts with `PL`)

### Configure in n8n
1. Click on the **"Add to Playlist"** node
2. Replace `YOUR_PLAYLIST_ID` with your actual playlist ID
3. Make sure the **YouTube OAuth2** credential is assigned (same credential as the Upload to YouTube node)
4. Click **"Save"**

### Skip Playlist
If you don't want videos added to a playlist:
- Delete the **"Add to Playlist"** node
- Connect **"Upload to YouTube"** directly to **"Success Output"**

---

## Post-Setup: First Test Run

### Before running, change to unlisted
1. Open workflow
2. Click **"Upload to YouTube"** node
3. Change `privacyStatus` from `public` to `unlisted`
4. Save

### Run the workflow
1. Click **"Test Workflow"** (play button in top-right)
2. Wait 3-5 minutes for full execution
3. Watch the execution progress — each node lights up green when done

### Verify
- [ ] Reddit and HN data were fetched successfully
- [ ] Gemini 2.5 Flash picked a story and generated a script with ~90 words + 8 image prompts
- [ ] 8 vertical images were generated by Pollinations.ai or FLUX.1 (768x1344, base64)
- [ ] Voiceover audio was created by Gemini 2.5 Flash TTS
- [ ] FFmpeg composed video with Ken Burns zoom/pan effect (~45 seconds)
- [ ] Video appeared in your YouTube Studio as unlisted
- [ ] Video was added to your playlist (if configured)

### Switch to public
Once verified, change `privacyStatus` back to `public` for future runs.

---

## Credential Summary

| # | Credential | Type | Nodes Using It | Cost |
|---|---|---|---|---|
| 1 | Google AI Studio (Gemini) | API Key in URL | Script Gen, TTS | $0.00 (free tier) |
| 2 | YouTube OAuth2 | OAuth2 | Upload to YouTube, Add to Playlist | Free |

---

## Troubleshooting

### "API key not valid" on Gemini nodes
- Verify the key at [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
- Make sure it's not expired or deleted
- Check the URL: `?key=YOUR_ACTUAL_KEY` (no quotes, no spaces)

### FFmpeg "command not found"
- Rebuild the custom image: `docker compose build && docker compose up -d`
- The custom Dockerfile installs FFmpeg via `npm -g ffmpeg-static` and symlinks to `/usr/local/bin/`

### "Cannot require 'child_process'"
- Ensure you're using `docker compose up -d` (sets `NODE_FUNCTION_ALLOW_BUILTIN` automatically)
- If running manually: add `-e NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` to your Docker command

### "OAuth token expired" or "refresh token is invalid/expired/revoked" on YouTube
- Go to the credential in n8n → click "Sign in with Google" again to re-authorize
- Make sure you added yourself as a test user in Google Cloud Console
- **If this keeps happening every 7 days**: Your app is in "Testing" mode. Go to Google Cloud Console → OAuth consent screen → Publishing status → **Publish App** to get permanent refresh tokens

### "Redirect URI mismatch" on YouTube OAuth
- In Google Cloud Console → Credentials → edit your OAuth client
- Make sure the redirect URI is exactly: `http://localhost:5678/rest/oauth2-credential/callback`
- No trailing slash, no https (it's localhost)

### "Access blocked: n8n YouTube has not completed Google verification"
- **Most common cause**: You didn't add yourself as a test user
- **Fix**: Google Cloud Console → **APIs & Services** → **OAuth consent screen** → **Audience** tab → **Add Users** → add your exact Google email
- After adding, go back to n8n and click **"Sign in with Google"** again

### "This app isn't verified" warning (different from above)
- This is normal for test/unverified apps — your app works fine
- Click **"Advanced"** → **"Go to n8n YouTube (unsafe)"**
- This is safe — it's your own app, not a third party

### "Quota exceeded" on YouTube
- Free quota: 10,000 units/day, upload = 1,600 units
- Wait until midnight Pacific Time for quota reset
- Or request a quota increase in Google Cloud Console

### Gemini rate limits / 503 errors
- If you see 429 errors, you've hit the free tier rate limit — wait a few minutes and try again
- Limits reset per minute (RPM) and per day (RPD)
- 503 "Service unavailable" errors are transient — the Generate Script node has auto-retry enabled (3 attempts, 5s delay)

---

## Migrating to Another n8n Instance

### Method 1: Export/Import via n8n UI (Easiest)

**Export from current instance:**
1. Open your workflow in n8n
2. Click the **three dots menu** in the top-right → **"Download"**
3. This saves a `.json` file with the complete workflow (nodes, connections, settings)
4. Credentials are **NOT included** in the export (for security)

**Import to new instance:**
1. Open the new n8n instance
2. Click **"Add workflow"** (or **"Import from file"** on the workflows page)
3. Select the downloaded `.json` file
4. The workflow will appear with all nodes and connections intact
5. **Re-configure credentials** on the new instance (see credential setup sections above)

### Method 2: n8n API (Programmatic)

**Export via API:**
```bash
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  http://localhost:5678/api/v1/workflows/YOUR_WORKFLOW_ID \
  -o youtube-shorts-workflow.json
```

**Import via API:**
```bash
curl -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @youtube-shorts-workflow.json \
  http://your-n8n-url:5678/api/v1/workflows
```

### Method 3: n8n Cloud Migration

If migrating from Docker to n8n Cloud:
1. Export the workflow JSON from Docker instance (Method 1 or 2)
2. Sign up at [app.n8n.cloud](https://app.n8n.cloud)
3. Import the workflow JSON
4. Re-configure credentials (Cloud has built-in OAuth handling — easier setup)
5. Replace **Manual Trigger** with **Schedule Trigger** for daily automation:
   - Edit the first node → change type to Schedule Trigger
   - Set cron: `0 9 * * *` (daily at 9 AM)
6. Note: FFmpeg must be available on the cloud instance or replaced with an external video API
7. Activate the workflow

### After Migration Checklist

On the new instance, you must:
- [ ] Replace `YOUR_GEMINI_API_KEY` in 2 nodes (Generate Script, Generate Voiceover)
- [ ] Create and assign **YouTube OAuth2** credential (new OAuth2 client or reuse existing)
- [ ] Update **playlist ID** in the "Add to Playlist" node (or remove the node if not needed)
- [ ] Update the **YouTube OAuth2 redirect URI** to match the new instance URL
  - Docker: `http://localhost:5678/rest/oauth2-credential/callback`
  - Cloud: `https://your-instance.app.n8n.cloud/rest/oauth2-credential/callback`
- [ ] Copy `Dockerfile` and `docker-compose.yml` to the n8n directory, then `docker compose up -d` (or manually install FFmpeg and set env var)
- [ ] Verify FFmpeg works: `docker exec n8n ffmpeg -version`
- [ ] Test with `privacyStatus: "unlisted"` before going public
- [ ] Verify all nodes execute successfully end-to-end
