# n8n YouTube Shorts Automation

Automated pipeline that creates and publishes YouTube Shorts about trending tech/AI news — fully hands-free.

**Pipeline:** Fetch news (Reddit + Hacker News) → Generate script (GPT-5) → Create images (DALL-E 3) → Generate voiceover (OpenAI TTS) → Compose video (Creatomate) → Upload to YouTube → Add to playlist

**Cost:** ~$0.22 per video (~$7/month for 30 videos)

---

## How It Works

```
Manual Trigger
    ↓
Fetch trending tech news from Reddit + Hacker News (direct HTTP)
    ↓
GPT-5 picks best story + writes 45-second script + title + image prompts
    ↓
DALL-E 3 generates 4 vertical images (1024x1792)
    ↓
OpenAI TTS creates voiceover narration
    ↓
Creatomate composes slideshow video (images + audio)
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
- **OpenAI account** with API billing enabled ($10-20 to start) — [platform.openai.com](https://platform.openai.com)
- **Google account** with a YouTube channel
- **Creatomate account** (free tier, no credit card) — [creatomate.com](https://creatomate.com)

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

### Step 3: Start n8n

```bash
docker run --rm --name n8n -p 5678:5678 -v $(pwd):/home/node/.n8n n8nio/n8n
```

Open [http://localhost:5678](http://localhost:5678) in your browser. Create an account when prompted (this is your local instance, data stays on your machine).

### Step 4: Import the Workflow

1. In n8n, click **"Add workflow"** (or the import icon)
2. Click **"Import from file"**
3. Select `exports/youtube-shorts-tech-news.json` from the cloned repo
4. The full 24-node workflow appears ready to configure

### Step 5: Configure Credentials

You need 4 credentials. All are configured **inside n8n** (not in code):

| # | Credential | Where to Get | Cost |
|---|---|---|---|
| 1 | **OpenAI API Key** | [platform.openai.com](https://platform.openai.com) → API Keys | ~$0.22/video |
| 2 | **OpenAI TTS** (Header Auth) | Same key as above, wrapped as `Authorization: Bearer sk-...` | Included |
| 3 | **Creatomate API Key** | [creatomate.com](https://creatomate.com) → Project Settings → API | Free (10/mo) |
| 4 | **YouTube OAuth2** | [Google Cloud Console](https://console.cloud.google.com) → YouTube Data API v3 | Free |

**Step-by-step instructions for each credential:** See [docs/setup-guide.md](docs/setup-guide.md)

### Step 6: Create Creatomate Template

1. Sign up at [creatomate.com](https://creatomate.com) (free, no credit card)
2. Create a blank template: **1080x1920** (9:16 vertical), **45 seconds**
3. Add 4 image elements named exactly: `Image-1`, `Image-2`, `Image-3`, `Image-4`
4. Add 1 audio element named exactly: `Audio`
5. Save the template
6. Copy the **template ID** from the URL (the UUID at the end)
7. In n8n, open the **"Compose Video (Creatomate)"** node and paste the template ID

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
4. Wait 8-12 minutes for the full pipeline to complete
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
```

---

## Cost Breakdown

| Service | Per Video | Monthly (30 videos) |
|---|---|---|
| GPT-5 (news research + script) | $0.06 | $1.80 |
| DALL-E 3 (4 images) | $0.16 | $4.80 |
| OpenAI TTS (voiceover) | $0.001 | $0.03 |
| Creatomate (video) | $0.00 | $0.00 (free tier: 10/mo) |
| YouTube API | $0.00 | $0.00 |
| **Total** | **$0.22** | **~$7** |

---

## Customization

| What | How |
|---|---|
| Change news sources | Edit the Fetch Reddit Posts URL or Pick Best Story code |
| Change script length | Edit "Generate Script" node — adjust word count (currently 80-95 words) |
| Change TTS voice | Edit "Generate Voiceover" node — options: `alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer` |
| Add scheduled trigger | Replace Manual Trigger with Schedule Trigger (cron: `0 9 * * *` for daily 9 AM) |
| Upgrade to AI video | Replace Creatomate nodes with fal.ai Sora/Veo API (~$1-4/clip) |
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
| "Invalid API key" on OpenAI | Check key at platform.openai.com, verify billing credits |
| "Access blocked" on YouTube OAuth | Add yourself as test user: Google Cloud Console → OAuth consent screen → Audience → Add Users |
| "This app isn't verified" | Click Advanced → "Go to n8n YouTube (unsafe)" — this is your own app, safe to proceed |
| "Redirect URI mismatch" | Verify URI is exactly `http://localhost:5678/rest/oauth2-credential/callback` |
| "Quota exceeded" on YouTube | Wait until midnight Pacific Time (6 uploads/day max) |
| Creatomate render fails | Verify template ID and element names match exactly (`Image-1`, `Image-2`, etc.) |
| n8n-mcp or n8n-skills folders are empty | Run `git submodule init && git submodule update` |

Full troubleshooting: [docs/setup-guide.md](docs/setup-guide.md#troubleshooting)

---

## Migrating to Another n8n Instance

1. Import `exports/youtube-shorts-tech-news.json` on the new instance
2. Re-configure all 4 credentials
3. Update Creatomate template ID if using a different account
4. Update YouTube OAuth redirect URI to match new instance URL
5. Test with `unlisted` before going public

See [docs/setup-guide.md](docs/setup-guide.md#migrating-to-a-different-n8n-instance) for full migration guide (4 methods including n8n Cloud).

---

## Future Plans

- Replace Creatomate with AI video generation (Sora/Veo via fal.ai)
- Migrate to n8n Cloud with daily scheduled trigger
- Add multi-platform posting (TikTok, Instagram Reels)
- Add thumbnail generation with text overlay
- A/B test titles for better CTR
