# n8n YouTube Shorts Automation

Automated pipeline that creates and publishes YouTube Shorts about trending tech/AI news — fully hands-free, completely free.

**Pipeline:** Fetch news (Reddit + Hacker News) → Generate script (Gemini 2.5 Flash) → Create images (Pollinations.ai / HuggingFace FLUX.1) → Generate voiceover (Gemini 2.5 Flash TTS) → Compose video (FFmpeg Ken Burns) → Upload to YouTube → Add to playlist

**Cost:** $0.00 per video (all free APIs + local FFmpeg)

---

## How It Works

```
Manual Trigger
    ↓
Fetch trending tech news from Reddit + Hacker News (direct HTTP)
    ↓
Gemini 2.5 Flash picks best story + writes 45-second script + 8 image prompts
    ↓
Pollinations.ai / HuggingFace FLUX.1 generates 8 vertical images (768×1344)
    ↓
Gemini 2.5 Flash TTS creates voiceover narration (PCM audio)
    ↓
FFmpeg composes video with Ken Burns zoom/pan effect + crossfade transitions
    ↓
Uploads to YouTube as a Short with full metadata
    ↓
Adds video to your YouTube playlist
```

---

## Prerequisites

Before you start, make sure you have:

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

The repo includes a `Dockerfile` and `docker-compose.yml` in the parent directory that build a custom n8n image with FFmpeg baked in — no manual installation needed.

```bash
docker compose up -d
```

This single command:
- Builds a custom image with FFmpeg + ffprobe pre-installed
- Sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` (required for video composition)
- Mounts the current directory as n8n data volume
- Auto-restarts with Docker Desktop (`restart: unless-stopped`)

Open [http://localhost:5678](http://localhost:5678) in your browser. Create an account when prompted (this is your local instance, data stays on your machine).

> **Note**: The official `n8nio/n8n` image uses a hardened Alpine without `apk`. The custom Dockerfile installs FFmpeg via `npm -g ffmpeg-static` instead.

### Step 4: Import the Workflow

1. In n8n, click **"Add workflow"** (or the import icon)
2. Click **"Import from file"**
3. Select `exports/youtube-shorts-tech-news.json` from the cloned repo
4. The full 15-node workflow appears ready to configure

### Step 5: Add Your Gemini API Key

1. Get your API key from [Google AI Studio](https://aistudio.google.com/apikeys) (free)
2. In n8n, open these 2 nodes and replace `YOUR_GEMINI_API_KEY` in the URL:
   - **"Generate Script (Gemini)"**
   - **"Generate Voiceover (Gemini TTS)"**

No n8n credential setup needed — the API key is passed directly in the URL query parameter.

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
3. Click **"Test Workflow"** (play button in top-right)
4. Wait 3-5 minutes for the full pipeline to complete
5. Check [YouTube Studio](https://studio.youtube.com) — your Short should appear as unlisted
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
| Gemini 2.5 Flash (script) | $0.00 | $0.00 (free tier) |
| Pollinations.ai / FLUX.1 (8 images) | $0.00 | $0.00 (free, no API key) |
| Gemini 2.5 Flash TTS (voiceover) | $0.00 | $0.00 (free tier) |
| FFmpeg (video render) | $0.00 | $0.00 (local) |
| YouTube API | $0.00 | $0.00 |
| **Total** | **$0.00** | **$0.00** |

---

## Customization

| What | How |
|---|---|
| Change news sources | Edit the Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit "Generate Script" node — adjust word count (currently 80-95 words) |
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
| "API key not valid" on Gemini | Verify key at aistudio.google.com/apikeys, ensure it's not expired |
| "Access blocked" on YouTube OAuth | Add yourself as test user: Google Cloud Console → OAuth consent screen → Audience → Add Users |
| "This app isn't verified" | Click Advanced → "Go to n8n YouTube (unsafe)" — this is your own app, safe to proceed |
| "Redirect URI mismatch" | Verify URI is exactly `http://localhost:5678/rest/oauth2-credential/callback` |
| "Quota exceeded" on YouTube | Wait until midnight Pacific Time (6 uploads/day max) |
| FFmpeg "command not found" | Rebuild image: `docker compose build && docker compose up -d` |
| "Cannot require 'child_process'" | Ensure you're using `docker compose up -d` (sets env var automatically) |
| n8n-mcp or n8n-skills folders are empty | Run `git submodule init && git submodule update` |

Full troubleshooting: [docs/setup-guide.md](docs/setup-guide.md#troubleshooting)

---

## Migrating to Another n8n Instance

1. Import `exports/youtube-shorts-tech-news.json` on the new instance
2. Replace `YOUR_GEMINI_API_KEY` in 2 nodes with your actual key
3. Re-configure YouTube OAuth2 credential
4. Copy `Dockerfile` and `docker-compose.yml` to the n8n directory, then run `docker compose up -d`
5. Or manually: start n8n with `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` env var and install FFmpeg
6. Test with `unlisted` before going public

---

## PC Upgrade Path (GPU-Accelerated AI Video)

If you have a PC with an NVIDIA GPU (e.g., RTX 3070 Ti + 32GB RAM), you can upgrade from FFmpeg Ken Burns (zoom/pan on static images) to **AI-animated video clips** using Stable Video Diffusion:

### What Changes

| Component | Current (Mac) | Upgraded (PC with GPU) |
|---|---|---|
| Video Generation | FFmpeg Ken Burns (zoom/pan) | SVD image-to-video animation |
| Video Quality | Professional slideshows | AI-animated motion |
| Render Time | 30-60s | 30-60s per clip (8 clips) |
| Hardware | Any CPU | NVIDIA GPU (6GB+ VRAM) |

### Setup Steps

1. **Install ComfyUI** on your PC:
   ```bash
   git clone https://github.com/comfyanonymous/ComfyUI.git
   cd ComfyUI && pip install -r requirements.txt
   ```

2. **Download SVD model** (~4GB):
   - Download `svd_xt_1_1.safetensors` from Hugging Face
   - Place in `ComfyUI/models/checkpoints/`

3. **Start ComfyUI as API server** (accessible from network):
   ```bash
   python main.py --listen 0.0.0.0 --port 8188
   ```

4. **Update n8n workflow**:
   - Replace the "Compose Video (FFmpeg)" node with HTTP Request calls to ComfyUI
   - Each image → POST to `http://YOUR_PC_IP:8188/prompt` with SVD workflow
   - Collect 8 animated clips → FFmpeg stitches them + adds audio
   - n8n Docker can reach your PC via local network IP (e.g., `192.168.1.100`)

5. **Requirements**:
   - NVIDIA GPU with 6GB+ VRAM (RTX 3060+)
   - 16GB+ system RAM
   - ComfyUI running and accessible from Docker network

### Future Possibilities

- **AnimateDiff**: Lower VRAM usage (4-6GB), cartoon/stylized animation
- **CogVideoX-2B**: Text-to-video, tighter VRAM (7-8GB on RTX 3070 Ti)
- **Wan2.1**: Latest open-source video model, excellent quality

---

## Future Plans

- Migrate to n8n Cloud with daily scheduled trigger
- Add multi-platform posting (TikTok, Instagram Reels)
- Add thumbnail generation with text overlay
- A/B test titles for better CTR
- Integrate ComfyUI for AI-animated video clips (PC upgrade path above)
