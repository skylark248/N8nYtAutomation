# n8n YouTube Shorts Automation

Automated pipeline that creates and publishes YouTube Shorts about trending tech/AI news — fully hands-free, cloud-powered.

**Pipeline:** Fetch news (Reddit + Hacker News) → Pick best story (top 3, 14-day dupe check) → Generate script (Gemini 3 Flash, 75-90 words) → Generate images (Stability AI SD3 primary / fal.ai Flux fallback, 6×) → Animate images (fal.ai Kling I2V, 6×5s clips) → Generate voiceover (ElevenLabs TTS) → Generate background music (fal.ai Stable Audio, 45s) → Compose video (FFmpeg, 1080×1920) → **Save to `videos/` folder** → Upload to YouTube → Add to playlist

**Cost:** ~$2.73/video (~$44/month for 30 Shorts) | **Runtime:** 25-40 minutes per video

---

## How It Works

```
Manual Trigger
    ↓
Fetch trending tech news from Reddit (r/technology) + Hacker News
    ↓
Score and rank posts by engagement — pick top 3 stories (14-day duplicate check)
    ↓
Gemini 3 Flash writes a 75-90 word HECK-loop script + 6 image prompts
    ↓
Stability AI SD3 generates 6 vertical images (9:16) — or fal.ai Flux if credits low
    ↓
fal.ai Kling v1.6 I2V animates each image into a 5-second video clip (9:16, all 6 submitted + polled in parallel)
    ↓
ElevenLabs TTS creates MP3 voiceover narration (Antoni voice)
    ↓
fal.ai Stable Audio generates 45s background music
    ↓
FFmpeg: minterpolate + xfade + audio mix → 1080×1920 MP4 (~38-45s)
    ↓
Saves video.mp4 + upload-info.txt to videos/{timestamp}_{title}/
    ↓
Uploads to YouTube as a Short with full metadata
    ↓
Adds video to your YouTube playlist
```

---

## Prerequisites

Before you start, make sure you have:

- **Windows PC** (no GPU required — all AI runs in the cloud)
- **Docker Desktop** installed ([Get Docker](https://docs.docker.com/get-docker/))
- **Git** installed ([Get Git](https://git-scm.com/downloads))
- **API accounts** for the cloud AI services below (free tiers available for some)

| Service | Required | Cost | Free Tier |
|---|---|---|---|
| Google AI Studio (Gemini) | Yes | Free | Unlimited on free tier |
| fal.ai | Yes | ~$2.19/run | Pay-as-you-go |
| ElevenLabs | Yes | ~$0.17/run | Starter plan ($5/month, 30k chars) |
| Stability AI | No | ~$0.13/image | Falls back to fal.ai Flux if missing |
| YouTube Data API v3 | Yes | Free | 10,000 units/day |

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone --recurse-submodules https://github.com/skylark248/N8nYtAutomation.git
cd N8nYtAutomation
```

> **Already cloned without `--recurse-submodules`?**
> ```bash
> git submodule init && git submodule update
> ```

### Step 2: Configure API Keys

Create `keys.json` in the repo root (it's in `.gitignore` — never committed):

```json
{
  "geminiApiKey": "YOUR_GEMINI_API_KEY",
  "falApiKey": "YOUR_FAL_API_KEY",
  "elevenLabsApiKey": "YOUR_ELEVENLABS_API_KEY",
  "stabilityApiKey": "YOUR_STABILITY_API_KEY",
  "youtubePlaylistId": "PLxxxxxxxxxxxxxxxx"
}
```

This file is mounted read-only into Docker at `/home/node/keys.json`. The workflow reads it at runtime — no API keys are stored inside n8n.

| Key | Where to Get | Required |
|---|---|---|
| `geminiApiKey` | [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys) (free) | Yes |
| `falApiKey` | [fal.ai/dashboard](https://fal.ai/dashboard) | Yes |
| `elevenLabsApiKey` | [elevenlabs.io/app/settings/api-keys](https://elevenlabs.io/app/settings/api-keys) (Starter+) | Yes |
| `stabilityApiKey` | [platform.stability.ai/account/keys](https://platform.stability.ai/account/keys) | No — falls back to fal.ai Flux |
| `youtubePlaylistId` | YouTube playlist URL after `list=` | No — skips playlist step |

### Step 3: Start n8n with Docker Compose

The `D:\N8n\` directory contains a `Dockerfile` and `docker-compose.yml` that build a custom n8n image with FFmpeg baked in.

```bash
cd D:\N8n

# First time only — build the custom image:
docker compose build

# Start n8n:
docker compose up -d
```

This builds an image that:
- Includes FFmpeg + ffprobe for video composition
- Sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os`
- Sets task timeout to 150 min (`N8N_RUNNERS_TASK_TIMEOUT=9000`, value is in **seconds**)
- Sets runner match timeout to 10 min (`N8N_RUNNERS_TASK_REQUEST_TIMEOUT=600`) — prevents "Task request timed out after 60 seconds" errors after long-running Code nodes
- Mounts `D:\Github Clones\N8nYtAutomation\videos` → `/home/node/videos` (local export)
- Mounts `keys.json` → `/home/node/keys.json:ro` (API keys)
- Auto-restarts with Docker Desktop (`restart: always`)

Open [http://localhost:5678](http://localhost:5678) and create an account when prompted.

### Step 4: Import the Workflow

1. In n8n, click **Workflows** → **"Add workflow"** → **"Import from file"**
2. Select `exports/youtube-shorts-tech-news.json` from the cloned repo
3. The full 18-node workflow appears ready to configure

### Step 5: Configure YouTube OAuth2

See [docs/setup-guide.md](docs/setup-guide.md) for the step-by-step YouTube OAuth2 setup. This is the only credential that can't be stored in `keys.json` — it must be configured in the n8n UI.

### Step 6: Configure Playlist (Optional)

1. In YouTube, copy the playlist ID from the URL: `https://www.youtube.com/playlist?list=PLxxxxxxxxxx`
2. In `keys.json`, set `"youtubePlaylistId": "PLxxxxxxxxxx"`
3. In n8n, open the **"Add to Playlist"** node and verify `playlistId` is set to `={{ $('Prepare YouTube Metadata').first().json.playlistId }}`

To skip playlist integration, delete the **"Add to Playlist"** node and connect **"Upload to YouTube"** directly to **"Success Output"**.

### Step 7: First Test Run

1. Open the **"Upload to YouTube"** node — change `privacyStatus` to `unlisted`
2. Click **"Test Workflow"** (play button, top-right)
3. Wait **25-40 minutes** for the full pipeline
4. Watch nodes turn green as they complete
5. Check [YouTube Studio](https://studio.youtube.com) — your Short should appear as unlisted
6. Once verified, change `privacyStatus` back to `public`

---

## Project Structure

```
.
├── README.md                              # You are here
├── CLAUDE.md                              # Claude Code AI assistant config
├── keys.json                              # API keys (gitignored — create manually)
├── .env.example                           # Legacy template (reference only)
├── .gitignore                             # Keeps secrets out of git
├── .gitmodules                            # Git submodule references
│
├── docs/
│   ├── setup-guide.md                     # Step-by-step credential setup
│   ├── workflow-reference.md              # Complete 18-node workflow documentation
│   └── CHANGELOG.md                       # Full version history
│
├── exports/
│   └── youtube-shorts-tech-news.json      # Importable n8n workflow file (v8.10)
│
├── videos/                                # Auto-created by workflow after each run
│   └── {timestamp}_{title}/               #   One folder per video
│       ├── video.mp4                      #     Final composed Short
│       └── upload-info.txt               #     Pre-formatted YouTube + Instagram caption
│
├── comfyui/                               # Legacy local AI setup (not used by main pipeline)
│   ├── README.md                          # ComfyUI setup guide (for reference)
│   ├── workflows/                         # ComfyUI API-format workflow templates
│   └── setup/                             # Installation scripts
│
├── n8n-mcp/                               # MCP server for Claude Code (git submodule)
└── n8n-skills/                            # Claude Code skills (git submodule)

# Parent directory (not in this repo):
D:\N8n\Dockerfile                          # Custom n8n image with FFmpeg baked in
D:\N8n\docker-compose.yml                  # One-command startup: docker compose up -d
```

---

## Manual Instagram Upload

After each run, the workflow saves `upload-info.txt` inside `videos/{timestamp}_{title}/` with a pre-formatted caption for Instagram.

### Steps to Upload as a Reel

1. **Open the video folder** — `D:\Github Clones\N8nYtAutomation\videos\{timestamp}_{title}\`
2. **Open `upload-info.txt`** — copy the Instagram caption block (title + emoji + hashtags)
3. **Open Instagram** (mobile or desktop) → **+** → **Reel**
4. Select `video.mp4` (transfer via AirDrop / USB / cloud sync)
5. Paste the caption
6. Set **Share to Feed** → **ON** → Post

### Recommended Posting Frequency

| Platform | Frequency | Notes |
|---|---|---|
| **YouTube Shorts** | 1/day | Consistency is the #1 growth lever for new Shorts channels |
| **Instagram Reels** | 3–4×/week | Mon/Wed/Fri/Sun — daily posting can hurt reach if engagement drops |

> **Best posting times (IST)**: YouTube — 8:30 PM. Instagram — 7–9 AM or 7–9 PM.

---

## Cost Breakdown

| Service | Per Video | Monthly (30 videos) |
|---|---|---|
| Gemini 3 Flash (script) | $0.00 | $0.00 (free tier) |
| Stability AI SD3 (6 images × ~$0.013) | ~$0.08 | ~$2.40 |
| fal.ai Flux Schnell (fallback, 6×) | ~$0.09 | ~$2.70 |
| fal.ai Kling v1.6 I2V (6 clips) | ~$2.10 | ~$63.00 |
| ElevenLabs TTS (voiceover) | ~$0.17 | ~$5.10 |
| fal.ai Stable Audio (music) | ~$0.38 | ~$11.40 |
| YouTube API | $0.00 | $0.00 |
| **Total (SD3 images)** | **~$2.73** | **~$44/month** |

> Stability AI SD3 images are cheaper than fal.ai Flux. The workflow auto-detects which to use based on your Stability AI credit balance.

---

## Customization

| What | How |
|---|---|
| Change news sources | Edit `fetchReddit` URL or `pickStory` scoring weights |
| Change script style | Edit `scriptGen` node — adjust HECK-loop prompt, word target (75-90 words) |
| Change TTS voice | Edit `voiceover` node — ElevenLabs voice IDs: Antoni, Rachel, Domi, Bella, Josh |
| Change image style | Edit `generateImages` node — modify image prompt suffix in `scriptGen` |
| Change video duration | Adjust word target in `scriptGen` (75-90 words ≈ 38-42s at 2 words/sec) |
| Add scheduled trigger | Replace Manual Trigger with Schedule Trigger (cron: `30 15 * * *` for 8:30 PM IST) |

See [docs/workflow-reference.md](docs/workflow-reference.md) for the full node-by-node breakdown.

---

## Using with Claude Code (Optional)

This repo includes two git submodules for building/modifying n8n workflows with [Claude Code](https://claude.ai/code):

- **`n8n-mcp/`** — MCP server that gives Claude Code direct access to 1,084+ n8n nodes and workflow management tools
- **`n8n-skills/`** — Expert skills for expression syntax, validation, node configuration, and workflow patterns

### Setup

1. Ensure submodules are cloned:
   ```bash
   git submodule init && git submodule update
   ```

2. Get your n8n API key: Open n8n → **Settings** → **API** → **Create API Key**

3. Register the MCP server with Claude Code:
   ```bash
   claude mcp add n8n-mcp \
     -e MCP_MODE=stdio \
     -e LOG_LEVEL=error \
     -e DISABLE_CONSOLE_OUTPUT=true \
     -e N8N_API_URL=http://localhost:5678 \
     -e N8N_API_KEY=YOUR_N8N_API_KEY \
     -s local \
     -- npx n8n-mcp
   ```

4. Start a **new Claude Code conversation** — MCP tools load on conversation start.

---

## Troubleshooting

| Error | Fix |
|---|---|
| "Service unavailable" on Gemini | Transient 503 — wait a minute and retry. Script node auto-retries internally |
| "API key not valid" on Gemini | Verify at aistudio.google.com/apikeys |
| fal.ai 401 Unauthorized | Check `falApiKey` in `keys.json` |
| ElevenLabs 403 | Starter plan required (free tier doesn't support TTS API) |
| ElevenLabs output format error | Only 128kbps MP3 on Starter plan — don't change `output_format` |
| "Access blocked" on YouTube OAuth | Add yourself as test user in Google Cloud Console → OAuth consent screen → Add Users |
| "This app isn't verified" | Click Advanced → "Go to n8n YouTube (unsafe)" — this is your own app |
| "Redirect URI mismatch" | URI must be exactly: `http://localhost:5678/rest/oauth2-credential/callback` |
| "Refresh token invalid" on YouTube | Re-authorize OAuth2 in n8n. If recurring every 7 days, publish your app in Google Cloud Console |
| "Quota exceeded" on YouTube | Max ~6 uploads/day. Quota resets at midnight Pacific Time |
| FFmpeg "command not found" | Rebuild image: `docker compose build && docker compose up -d` from `D:\N8n` |
| "Cannot require 'child_process'" | Use `docker compose up -d` (not `docker run`) — sets the env var automatically |
| "Task execution timed out" | Ensure `N8N_RUNNERS_TASK_TIMEOUT=9000` in docker-compose.yml (value is in **seconds**) |
| "Task request timed out after 60 seconds" | Add `N8N_RUNNERS_TASK_REQUEST_TIMEOUT=600` in docker-compose.yml — runner match timeout (separate from execution timeout); default 60s is too short after long-running Code nodes |
| Local video export not working | Verify volume mount in `D:\N8n\docker-compose.yml`: `"d:/Github Clones/N8nYtAutomation/videos:/home/node/videos"` |
| n8n-mcp or n8n-skills folders empty | Run `git submodule init && git submodule update` |
| keys.json not found in Docker | Verify volume mount includes `keys.json:/home/node/keys.json:ro` in docker-compose.yml |

Full troubleshooting: [docs/setup-guide.md](docs/setup-guide.md#troubleshooting)

---

## Migrating to Another n8n Instance

1. Import `exports/youtube-shorts-tech-news.json` on the new instance
2. Copy `keys.json` to the new repo root (or recreate it)
3. Re-configure YouTube OAuth2 credential in n8n
4. Add volume mounts to the new `docker-compose.yml` (videos + keys.json)
5. Run `docker compose build && docker compose up -d`
6. Test with `privacyStatus: "unlisted"` before going public
