# n8n YouTube Shorts Automation

Automated pipeline that creates and publishes YouTube Shorts about trending tech/AI news — fully hands-free, completely free.

**Pipeline:** Fetch news (Reddit + Hacker News) → Generate script (Gemini 3 Flash) → Generate images (ComfyUI SDXL base 1.0) → Animate images (ComfyUI HunyuanVideo I2V) → Generate voiceover (Gemini 2.5 Flash TTS) → Compose video (FFmpeg) → Upload to YouTube → Add to playlist

**Cost:** $0.00 per video (all local AI generation + free APIs)

---

## How It Works

```
Manual Trigger
    ↓
Fetch trending tech news from Reddit + Hacker News (direct HTTP)
    ↓
Gemini 3 Flash picks best story + writes 45-second script + 8 image prompts
    ↓
ComfyUI SDXL base 1.0 generates 8 vertical images (768×1344) — ~5-6 min
    ↓
ComfyUI HunyuanVideo I2V animates each image into a video clip (544×960) — ~60-100 min
    ↓
Gemini 3 Flash TTS creates voiceover narration (PCM audio)
    ↓
FFmpeg stitches clips + slow-stretch + crossfade + audio overlay → 1080×1920 MP4
    ↓
Uploads to YouTube as a Short with full metadata
    ↓
Adds video to your YouTube playlist
```

---

## Prerequisites

Before you start, make sure you have:

- **Windows PC with NVIDIA GPU** (RTX 3070 Ti or similar, 8GB+ VRAM, 32GB+ RAM recommended)
- **ComfyUI** installed with SDXL base 1.0 + HunyuanVideo I2V models (~24GB) — see [comfyui/README.md](comfyui/README.md)
- **Docker** installed ([Get Docker](https://docs.docker.com/get-docker/))
- **Git** installed ([Get Git](https://git-scm.com/downloads))
- **Google AI Studio API key** (free, no billing required) — [aistudio.google.com/apikeys](https://aistudio.google.com/apikeys)
- **Google account** with a YouTube channel

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone --recurse-submodules https://github.com/skylark248/N8nYtAutomation.git
cd N8nYtAutomation
```

> **Already cloned without `--recurse-submodules`?** Run this to fetch the submodules:
> ```bash
> git submodule init && git submodule update
> ```

### Step 2: Set Up Environment

```bash
cp .env.example .env
```

Open `.env` and fill in your API keys (this file is for your reference — credentials are configured inside n8n, not read from `.env`).

### Step 3: Start n8n with Docker Compose

The `D:\N8n\` directory contains a `Dockerfile` and `docker-compose.yml` that build a custom n8n image with FFmpeg baked in — no manual installation needed.

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
- Sets task timeout to 150 min for ComfyUI generation (`N8N_RUNNERS_TASK_TIMEOUT=9000`)
- Adds `host.docker.internal` for Docker→ComfyUI connectivity
- Auto-restarts with Docker Desktop

Open [http://localhost:5678](http://localhost:5678) in your browser. Create an account when prompted.

> **Note**: The official `n8nio/n8n` image uses a hardened Alpine without `apk`. The custom Dockerfile installs FFmpeg via `npm -g ffmpeg-static` instead.

### Step 4: Import the Workflow

1. In n8n, click **"Add workflow"** (or the import icon)
2. Click **"Import from file"**
3. Select `exports/youtube-shorts-tech-news.json` from the cloned repo
4. The full 16-node workflow appears ready to configure

### Step 5: Add Your Gemini API Key

1. Get your API key from [Google AI Studio](https://aistudio.google.com/apikeys) (free)
2. In n8n, open these 2 nodes and replace `YOUR_GEMINI_API_KEY` in the URL:
   - **"Generate Script (Gemini)"**
   - **"Generate Voiceover (Gemini TTS)"**

No n8n credential setup needed — the API key is passed directly in the URL query parameter.

### Step 5b: Set Up ComfyUI (Local AI Generation)

The workflow uses ComfyUI on the Windows host for image and video generation. Follow the full guide in [comfyui/README.md](comfyui/README.md), or the quick version:

1. **Install ComfyUI** — Download portable from [GitHub releases](https://github.com/Comfy-Org/ComfyUI/releases), extract to `C:\ComfyUI`
2. **Install custom nodes** — Run `comfyui\setup\install-custom-nodes.ps1`
3. **Download models** (~24GB) — Run `comfyui\setup\install-models.ps1`
4. **Start ComfyUI** — Run `comfyui\setup\run_api_server.bat`
5. **Allow firewall** — `New-NetFirewallRule -DisplayName "ComfyUI API" -Direction Inbound -Protocol TCP -LocalPort 8188 -Action Allow`
6. **Verify**: `curl http://localhost:8188/system_stats` should return GPU info

> **ComfyUI must be running** whenever you execute the n8n workflow. n8n Docker connects to it via `http://host.docker.internal:8188`.

### Step 6: Configure YouTube OAuth2

| # | Credential | Where to Get | Cost |
|---|---|---|---|
| 1 | **YouTube OAuth2** | [Google Cloud Console](https://console.cloud.google.com) → YouTube Data API v3 | Free |

**Step-by-step instructions:** See [docs/setup-guide.md](docs/setup-guide.md)

### Step 7: Configure Playlist (Optional)

To automatically add uploaded videos to a YouTube playlist:

1. In YouTube, create a playlist (or use an existing one)
2. Copy the **playlist ID** from the URL: `https://www.youtube.com/playlist?list=PLxxxxxxxxxx` — the `PLxxxxxxxxxx` part is the ID
3. In n8n, open the **"Add to Playlist"** node
4. Replace `YOUR_PLAYLIST_ID` with your actual playlist ID
5. Make sure the YouTube OAuth2 credential is assigned to this node

To skip playlist integration, simply delete the "Add to Playlist" node and connect "Upload to YouTube" directly to "Success Output".

### Step 8: First Test Run

1. In n8n, open the **"Upload to YouTube"** node
2. Change `privacyStatus` from `public` to `unlisted` (so it doesn't go live immediately)
3. Make sure **ComfyUI is running** (`curl http://localhost:8188/system_stats`)
4. Click **"Test Workflow"** (play button in top-right)
5. Wait **80-110 minutes** for the full pipeline (most time is HunyuanVideo I2V animation)
6. Check [YouTube Studio](https://studio.youtube.com) — your Short should appear as unlisted
6. Once verified, change `privacyStatus` back to `public` for future runs

---

## Project Structure

```
.
├── README.md                              # You are here
├── .env.example                           # Template for API keys (copy to .env)
├── .gitignore                             # Keeps secrets out of git
├── .gitmodules                            # Git submodule references
│
├── comfyui/                               # Local AI generation setup
│   ├── README.md                          # ComfyUI setup guide
│   ├── workflows/                         # ComfyUI API-format workflow templates
│   │   ├── sdxl-text-to-image.json        #   SDXL base 1.0 (768x1344) — reference
│   │   ├── flux-nf4-text-to-image.json    #   FLUX.1 Dev NF4 (768x1344) — legacy/unused
│   │   └── hunyuan-i2v-gguf-q4.json       #   HunyuanVideo I2V (544x960, 49 frames)
│   └── setup/                             # Installation scripts
│       ├── install-models.ps1             #   Download ~24GB of models
│       ├── install-custom-nodes.ps1       #   Clone NF4 + GGUF custom nodes
│       └── run_api_server.bat             #   Launch ComfyUI API server
│
├── docs/
│   ├── setup-guide.md                     # Step-by-step credential setup
│   └── workflow-reference.md              # Complete node-by-node documentation
│
├── exports/
│   └── youtube-shorts-tech-news.json      # Importable n8n workflow file
│
├── CLAUDE.md                              # Claude Code AI assistant config
├── n8n-mcp/                               # MCP server for Claude Code (git submodule)
└── n8n-skills/                            # Claude Code skills (git submodule)

# Parent directory (not in this repo):
../Dockerfile                              # Custom n8n image with FFmpeg baked in
../docker-compose.yml                      # One-command startup: docker compose up -d
```

---

## Cost Breakdown

| Service | Per Video | Monthly (30 videos) |
|---|---|---|
| Gemini 3 Flash (script) | $0.00 | $0.00 (free tier) |
| ComfyUI SDXL base 1.0 (8 images) | $0.00 | $0.00 (local GPU) |
| ComfyUI HunyuanVideo I2V (8 clips) | $0.00 | $0.00 (local GPU) |
| Gemini 3 Flash TTS (voiceover) | $0.00 | $0.00 (free tier) |
| FFmpeg (video stitch) | $0.00 | $0.00 (local) |
| YouTube API | $0.00 | $0.00 |
| Electricity (~80-110 min GPU) | ~$0.06 | ~$1.80 |
| **Total** | **~$0.06** | **~$1.80** |

---

## Customization

| What | How |
|---|---|
| Change news sources | Edit the Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit "Generate Script" node — adjust word count (currently 110-120 words) |
| Change TTS voice | Edit "Generate Voiceover" node — options: `Kore`, `Charon`, `Fenrir`, `Aoede`, `Puck`, `Zephyr` |
| Add scheduled trigger | Replace Manual Trigger with Schedule Trigger (cron: `0 9 * * *` for daily 9 AM) |
| Multi-platform posting | Add Blotato node for TikTok, Instagram Reels |

See [docs/workflow-reference.md](docs/workflow-reference.md) → Modification Guide for details.

---

## Using with Claude Code (Optional)

This repo includes two git submodules for building/modifying n8n workflows with [Claude Code](https://claude.ai/code):

- **`n8n-mcp/`** — MCP server that gives Claude Code direct access to 1,084+ n8n nodes and workflow management tools
- **`n8n-skills/`** — Expert skills for expression syntax, validation, node configuration, and workflow patterns

### Setup

1. Make sure submodules are cloned (done automatically if you used `--recurse-submodules`):
   ```bash
   git submodule init && git submodule update
   ```

2. Install the MCP server dependencies:
   ```bash
   cd n8n-mcp && npm install && cd ..
   ```

3. Get your n8n API key: Open n8n → **Settings** → **API** → **Create API Key**

4. Register the MCP server with Claude Code:
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

5. Start a **new Claude Code conversation** (MCP tools load on conversation start)

Then Claude Code can create, modify, validate, and deploy n8n workflows conversationally.

---

## Troubleshooting

| Error | Fix |
|---|---|
| "Service unavailable" on Gemini | Transient 503 error — the Script node auto-retries 3 times. If persistent, wait a few minutes |
| "API key not valid" on Gemini | Verify key at aistudio.google.com/apikeys, ensure it's not expired |
| "Connection refused" on image/video gen | ComfyUI not running. Start it with `comfyui\setup\run_api_server.bat` |
| OOM error on ComfyUI | Close other GPU apps. SDXL needs ~5-6GB, Hunyuan needs ~7-8GB VRAM |
| "Access blocked" on YouTube OAuth | Add yourself as test user: Google Cloud Console → OAuth consent screen → Audience → Add Users |
| "This app isn't verified" | Click Advanced → "Go to n8n YouTube (unsafe)" — this is your own app, safe to proceed |
| "Redirect URI mismatch" | Verify URI is exactly `http://localhost:5678/rest/oauth2-credential/callback` |
| "Refresh token is invalid/expired/revoked" on YouTube | Re-authorize OAuth2 credential in n8n. If recurring every 7 days, publish your app (Google Cloud Console → OAuth consent screen → Publish App) |
| "Quota exceeded" on YouTube | Wait until midnight Pacific Time (6 uploads/day max) |
| FFmpeg "command not found" | Rebuild image: `docker compose build && docker compose up -d` |
| "Cannot require 'child_process'" | Ensure you're using `docker compose up -d` (sets env var automatically) |
| "Task execution timed out" | Ensure `N8N_RUNNERS_TASK_TIMEOUT=9000` in docker-compose.yml (150 min for ComfyUI, value is in seconds) |
| n8n-mcp or n8n-skills folders are empty | Run `git submodule init && git submodule update` |

Full troubleshooting: [docs/setup-guide.md](docs/setup-guide.md#troubleshooting)

---

## Migrating to Another n8n Instance

1. Import `exports/youtube-shorts-tech-news.json` on the new instance
2. Replace `YOUR_GEMINI_API_KEY` in 2 nodes with your actual key
3. Re-configure YouTube OAuth2 credential
4. Set up ComfyUI with SDXL base 1.0 + HunyuanVideo I2V models (see [comfyui/README.md](comfyui/README.md))
5. Copy `Dockerfile` and `docker-compose.yml` from `D:\N8n\` to the new n8n directory, then run `docker compose build && docker compose up -d`
6. Ensure ComfyUI is running and reachable from Docker (`http://host.docker.internal:8188`)
7. Test with `unlisted` before going public

---

## Hardware Requirements

| Component | Minimum | Recommended (current setup) |
|---|---|---|
| GPU | NVIDIA RTX 3060 (8GB VRAM) | RTX 3070 Ti (8GB VRAM) |
| RAM | 16GB | 32GB DDR4 |
| CPU | Any modern x86_64 | Ryzen 5 5600X |
| Storage | ~35GB free (ComfyUI + models) | NVMe SSD |

### VRAM Budget

| Phase | Peak VRAM | Notes |
|-------|-----------|-------|
| SDXL base 1.0 image gen | ~5-6 GB | Fits on 8GB VRAM without special flags |
| HunyuanVideo I2V | ~7-8 GB | GGUF offloads weights to system RAM |

Models are loaded/unloaded sequentially — they cannot coexist in VRAM. ComfyUI handles the swap automatically.

### Timeline Per Video

| Stage | Time |
|-------|------|
| Fetch news + script gen | ~1 min |
| SDXL images (8×35-45s) | ~5-6 min |
| Model swap (SDXL→Hunyuan) | ~0.5-1 min |
| HunyuanVideo clips (8×49 frames) | ~65-100 min |
| Voiceover (Gemini TTS) | ~10 sec |
| FFmpeg stitch + audio (2-pass) | ~8-12 min |
| YouTube upload | ~1-2 min |
| **Total** | **~80-110 min** |

---

## Future Plans

- Migrate to n8n Cloud with daily scheduled trigger
- Add multi-platform posting (TikTok, Instagram Reels)
- Add thumbnail generation with text overlay
- A/B test titles for better CTR
- Upgrade to higher-quality video models as VRAM allows (Wan2.1, CogVideoX)
