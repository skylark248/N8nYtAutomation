# n8n YouTube Shorts Automation

## Instance Configuration
- **URL**: http://localhost:5678
- **Environment**: Local Docker container (shared n8n instance with JobSearchAutomation)
- **Focus**: Automated YouTube Shorts creation from trending tech news
- **n8n Workflow ID**: `mlyG42RX4q1yIk8r` (deployed to running instance)
- **Workflow Name**: "YouTube Shorts - Tech News Automation"
- **GitHub Repo**: https://github.com/skylark248/N8nYtAutomation.git

## Parent Directory Context

This project lives at `/Users/shivanshchoudhary/Downloads/n8n/YtShortsAutomation/`. The parent `/n8n/` directory contains:
- `JobSearchAutomation/` -- sibling project (Job Search AI Matching, separate repo)
- n8n runtime data: `database.sqlite`, `binaryData/`, `config`, `.mcp.json`, `crash.journal`
- The n8n Docker instance mounts the parent `/n8n/` directory as `/home/node/.n8n`
- Workflow JSON files are imported via the n8n UI, not read from the filesystem at runtime
- The root `/n8n/` directory also has copies of the original project files (before folder reorganization) -- these are the originals, the files here in `YtShortsAutomation/` are copies

## Quick Start

```bash
# 1. Start n8n with FFmpeg support (from parent /n8n/ directory)
docker run --rm --name n8n -p 5678:5678 \
  -e NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os \
  -v $(pwd):/home/node/.n8n \
  n8nio/n8n

# 2. Install FFmpeg in the running container
docker exec n8n apk add --no-cache ffmpeg

# 3. Get a Google AI Studio API key from https://aistudio.google.com/apikeys

# 4. Import the workflow
# Open http://localhost:5678 -> Import from file -> select exports/youtube-shorts-tech-news.json

# 5. Replace YOUR_GEMINI_API_KEY in 3 nodes (Script, Images, TTS) with your key

# 6. Configure YouTube OAuth2 credential (see docs/setup-guide.md)

# 7. Test run with unlisted privacy
```

## MCP Server Setup

### n8n MCP Server (czlonkowski/n8n-mcp)
Bridges Claude Code with n8n's workflow automation platform. Provides structured access to 1,084+ n8n nodes.

#### Setup Instructions

```bash
# Configure MCP server (replace YOUR_N8N_API_KEY with your actual key from n8n Settings -> API)
claude mcp add n8n-mcp \
  -e MCP_MODE=stdio \
  -e LOG_LEVEL=error \
  -e DISABLE_CONSOLE_OUTPUT=true \
  -e N8N_API_URL=http://localhost:5678 \
  -e N8N_API_KEY=YOUR_N8N_API_KEY \
  -s local \
  -- npx n8n-mcp
```

**Get your API key**: Open n8n -> Settings -> API -> Create API Key

**Verify setup:**
```bash
claude mcp list          # Should show n8n-mcp
claude mcp get n8n-mcp   # Check config
```

**Important Notes:**
- MCP tools are injected when a **new conversation begins** -- they don't appear retroactively
- "Failed to connect" when idle is **normal** -- it only connects during active conversations
- If tools aren't available after fixing issues, start a **new conversation**

#### Available MCP Tools (39 total)

**Documentation Tools:** `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`, `tools_documentation`

**Workflow Management Tools** (requires API key): `n8n_create_workflow`, `n8n_get_workflow`, `n8n_update_partial_workflow`, `n8n_update_full_workflow`, `n8n_delete_workflow`, `n8n_list_workflows`, `n8n_validate_workflow`, `n8n_autofix_workflow`, `n8n_deploy_template`, `n8n_test_workflow`, `n8n_executions`, `n8n_health_check`

#### MCP Gotchas (Learned from Building This Workflow)

- **`n8n_update_partial_workflow` updateNode operation**: Use `"updates": {...}` key, NOT `"properties": {...}`. The latter causes "Missing required parameter 'updates'" error.
- **YouTube node `playlistItem` resource**: Set `resource: "playlistItem"` and pass `playlistId` + `videoId`. The videoId comes from the Upload to YouTube response as `uploadId` or `id`.
- **Binary data in Code nodes**: Do NOT use `getBinaryDataBuffer()` -- it loads entire binary into memory and causes OOM crashes. Instead, pass binary metadata through and let HTTP Request nodes handle binary natively.
- **Gemini API key in URL**: Pass as query param `?key=YOUR_KEY` -- no n8n credential setup needed. Simpler than header auth.
- **Gemini TTS returns raw PCM**: Not MP3/WAV. Must convert with `ffmpeg -f s16le -ar 24000 -ac 1 -i audio.pcm audio.wav` before use.
- **FFmpeg in Code nodes**: Requires `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` Docker env var. Without it, `require('child_process')` fails.
- **Background agents**: Bash commands are auto-denied when agents run in background mode. Use the Write tool directly for file operations.
- **Workflow creation**: Create with all nodes and connections in one `n8n_create_workflow` call for best results, then fix individual nodes with `n8n_update_partial_workflow`.

#### Troubleshooting

**npm cache permission errors:**
```bash
sudo chown -R $(id -u):$(id -g) "$HOME/.npm"
npx n8n-mcp --help   # verify fix
```

**Reconfigure from scratch:**
```bash
claude mcp remove n8n-mcp -s local
# Then re-run the setup command above
```

## Claude Skills

### n8n Skills (czlonkowski/n8n-skills)
Expert guidance for building production-ready n8n workflows. Skills activate automatically based on context.

**Available Skills:**
1. **Expression Syntax** (`n8n-expression-syntax`) - Correct expression patterns and variable access
2. **MCP Tools Expert** (`n8n-mcp-tools-expert`) - Proper use of n8n-mcp server tools
3. **Workflow Patterns** (`n8n-workflow-patterns`) - 5 proven architectural approaches
4. **Validation Expert** (`n8n-validation-expert`) - Interpret and fix validation errors
5. **Node Configuration** (`n8n-node-configuration`) - Operation-specific node setup requirements
6. **Code JavaScript** (`n8n-code-javascript`) - JavaScript implementation in Code nodes
7. **Code Python** (`n8n-code-python`) - Python limitations and standard library usage

## Active Workflows

### YouTube Shorts - Tech News Automation
- **Status**: Inactive (manual trigger)
- **n8n Workflow ID**: `mlyG42RX4q1yIk8r`
- **Nodes**: 17 | **Connections**: 16
- **Estimated Runtime**: 3-5 minutes per video
- **Export File**: `exports/youtube-shorts-tech-news.json`
- **Documentation**: See `docs/workflow-reference.md` for full node-by-node breakdown
- **Setup Guide**: See `docs/setup-guide.md` for credential configuration

**Pipeline**: Fetch news (Reddit + HN) -> Generate script (Gemini 2.0 Flash) -> Create images (Gemini 2.5 Flash Image) -> Voiceover (Gemini 2.5 Flash TTS) -> Compose video (FFmpeg Ken Burns) -> Upload to YouTube (public) -> Add to playlist

**Required Credentials** (configure in n8n before running):
1. **Google AI Studio API Key** - for Gemini script, Gemini image gen, and Gemini TTS (passed in URL query params, no n8n credential needed)
2. **YouTube OAuth2** - for uploading videos and adding to playlist. Enable YouTube Data API v3 in Google Cloud Console. Redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`

**Required Docker Setup**:
- `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` env var (for FFmpeg Code node)
- `ffmpeg` installed in container (`docker exec n8n apk add --no-cache ffmpeg`)

**Monthly Cost**: $0.00 (all free APIs + local FFmpeg)

### Complete Node List (17 nodes)

| # | Node Name | Type | Version | ID | Purpose |
|---|---|---|---|---|---|
| 1 | Manual Trigger | `n8n-nodes-base.manualTrigger` | v1 | `trigger` | Click to run |
| 2 | Fetch Reddit Posts | `n8n-nodes-base.httpRequest` | v4.2 | `fetchReddit` | GET old.reddit.com/r/technology/hot.json?limit=15 |
| 3 | Format Reddit Data | `n8n-nodes-base.code` | v2 | `formatReddit` | Extract top 10 non-stickied posts with scores |
| 4 | Fetch HN Posts | `n8n-nodes-base.httpRequest` | v4.2 | `fetchHN` | GET hn.algolia.com/api/v1/search?tags=front_page |
| 5 | Pick Best Story | `n8n-nodes-base.code` | v2 | `pickStory` | Combine Reddit + HN data into selection prompt |
| 6 | Prepare Story Data | `n8n-nodes-base.code` | v2 | `parseAgent` | Format combined prompt with timestamp |
| 7 | Generate Script (Gemini) | `n8n-nodes-base.httpRequest` | v4.2 | `scriptGen` | Gemini 2.0 Flash: script, title, tags, 8 image prompts |
| 8 | Parse Script JSON | `n8n-nodes-base.code` | v2 | `parseScript` | Parse Gemini JSON with fallback regex extraction |
| 9 | Split Image Prompts | `n8n-nodes-base.splitOut` | v1 | `splitImages` | Split 8 imagePrompts into individual items |
| 10 | Generate Images (Gemini) | `n8n-nodes-base.httpRequest` | v4.2 | `generateImages` | Gemini 2.5 Flash Image: vertical 9:16, base64 output |
| 11 | Collect All Images | `n8n-nodes-base.code` | v2 | `collectImages` | Gather 8 base64 images into single array |
| 12 | Generate Voiceover (Gemini TTS) | `n8n-nodes-base.httpRequest` | v4.2 | `voiceover` | Gemini 2.5 Flash TTS: voice Kore, PCM base64 output |
| 13 | Compose Video (FFmpeg) | `n8n-nodes-base.code` | v2 | `composeVideo` | Ken Burns zoom/pan + crossfade + audio, outputs MP4 |
| 14 | Prepare YouTube Metadata | `n8n-nodes-base.code` | v2 | `prepareYT` | Append #Shorts, set category 28, format tags |
| 15 | Upload to YouTube | `n8n-nodes-base.youTube` | v1 | `youtubeUpload` | Upload video binary, privacy: public |
| 16 | Add to Playlist | `n8n-nodes-base.youTube` | v1 | `addToPlaylist` | Add video to YouTube playlist |
| 17 | Success Output | `n8n-nodes-base.code` | v2 | `successOutput` | Return videoUrl, videoId, uploadTime |

### Connection Map

```
Manual Trigger               -> Fetch Reddit Posts            (main)
Fetch Reddit Posts           -> Format Reddit Data            (main)
Format Reddit Data           -> Fetch HN Posts                (main)
Fetch HN Posts               -> Pick Best Story               (main)
Pick Best Story              -> Prepare Story Data            (main)
Prepare Story Data           -> Generate Script (Gemini)      (main)
Generate Script (Gemini)     -> Parse Script JSON             (main)
Parse Script JSON            -> Split Image Prompts           (main)
Split Image Prompts          -> Generate Images (Gemini)      (main)
Generate Images (Gemini)     -> Collect All Images            (main)
Collect All Images           -> Generate Voiceover (Gemini TTS) (main)
Generate Voiceover (Gemini TTS) -> Compose Video (FFmpeg)     (main)
Compose Video (FFmpeg)       -> Prepare YouTube Metadata      (main)
Prepare YouTube Metadata     -> Upload to YouTube             (main)
Upload to YouTube            -> Add to Playlist               (main)
Add to Playlist              -> Success Output                (main)
```

### Key Node Implementation Details

**Fetch Reddit Posts** (HTTP Request):
- URL: `https://old.reddit.com/r/technology/hot.json?limit=15`
- Headers: `User-Agent: Mozilla/5.0 (Chrome browser UA)`, `Accept: application/json` (Reddit blocks bot UAs with 403)
- Timeout: 10000ms

**Format Reddit Data** (Code node):
- Filters out stickied posts
- Takes top 10, formats as `"1. [Score: X] Title (Y comments)"`

**Pick Best Story** (Code node):
- Combines Reddit summary + HN summary
- Creates prompt asking AI to pick the SINGLE most interesting tech/AI story
- References Format Reddit Data via `$('Format Reddit Data').first().json.redditSummary`

**Generate Script (Gemini)** (HTTP Request):
- POST `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=API_KEY`
- System instruction + user prompt requesting JSON output
- `responseMimeType: 'application/json'` for structured output
- Requests: SCRIPT (80-95 words), TITLE, DESCRIPTION, TAGS, IMAGE_PROMPTS (8 vertical 9:16 prompts)

**Parse Script JSON** (Code node):
- Reads from `$input.first().json.candidates[0].content.parts[0].text` (Gemini format)
- Primary: `JSON.parse(response)`
- Fallback: regex `/\{[\s\S]*\}/` to extract JSON from markdown code blocks
- Validates required fields: SCRIPT, TITLE, IMAGE_PROMPTS array (minimum 4)

**Generate Images (Gemini)** (HTTP Request):
- POST `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=API_KEY`
- Body: `{ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseModalities: ['IMAGE', 'TEXT'] } }`
- Returns base64-encoded images in `candidates[0].content.parts[].inlineData.data`
- Auth: API key in URL query param (no n8n credential needed)
- Timeout: 60000ms

**Collect All Images** (Code node):
- Extracts base64 image data from 8 Gemini responses
- Looks for `inlineData` parts with `image/*` mimeType
- Outputs: `{ imageBase64Array: [...], imageCount: 8 }`

**Generate Voiceover (Gemini TTS)** (HTTP Request):
- POST `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=API_KEY`
- Body: `{ contents: [{ parts: [{ text: script }] }], generationConfig: { responseModalities: ['AUDIO'], speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Kore' } } } } }`
- Returns base64 PCM audio (24kHz, 16-bit, mono) in `candidates[0].content.parts[0].inlineData.data`
- Voice options: Kore, Charon, Fenrir, Aoede, Leda, Orus, Puck, Zephyr (and more)

**Compose Video (FFmpeg)** (Code node):
- Requires `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` and `ffmpeg` installed
- Writes 8 base64 images to `/tmp/` as PNG files
- Converts PCM audio to WAV via FFmpeg
- Applies Ken Burns effect: alternating zoom-in/zoom-out on each image (~5.6s per image)
- Crossfade transitions (0.5s) between images using xfade filter
- Overlays audio track, outputs 1080x1920 vertical MP4
- Returns video as n8n binary data
- Estimated render time: 30-60s on M1, 15-30s on modern x86

**Upload to YouTube** (YouTube node):
- Resource: `video`, Operation: `upload`
- Binary property: `video`
- Privacy: `public` (change to `unlisted` for testing)
- Category: 28 (Science & Technology)
- Tags joined with commas, notifySubscribers: true

**Add to Playlist** (YouTube node):
- Resource: `playlistItem`, Operation: default (add)
- `playlistId`: `YOUR_PLAYLIST_ID` -- **SETUP REQUIRED**
- `videoId`: `={{ $json.uploadId || $json.id || $json.videoId }}`
- Uses same YouTube OAuth2 credential as Upload

### Placeholder Values to Configure

| Placeholder | Where | Replace With |
|---|---|---|
| `YOUR_GEMINI_API_KEY` | Generate Script, Generate Images, Generate Voiceover nodes (URL query param) | Your Google AI Studio API key |
| `YOUR_PLAYLIST_ID` | Add to Playlist node, `playlistId` field | Your YouTube playlist ID (starts with `PL...`) |

## Project Structure

```
.
├── README.md                 # Start here -- project overview & quickstart
├── CLAUDE.md                 # Claude Code instructions (this file)
├── .env.example              # Template for secrets (copy to .env)
├── .gitignore                # Excludes sensitive files from git
├── .gitmodules               # Git submodule references (n8n-mcp, n8n-skills)
│
├── docs/                     # All documentation
│   ├── setup-guide.md        # Step-by-step credential setup
│   └── workflow-reference.md # Complete 24-node workflow documentation
│
├── exports/                  # Importable workflow JSON files
│   ├── youtube-shorts-tech-news.json          # Clean export (no credentials)
│   └── youtube-shorts-tech-news-with-creds.json  # With creds (gitignored)
│
├── n8n-mcp/                  # MCP server (git submodule: github.com/czlonkowski/n8n-mcp)
└── n8n-skills/               # Claude skills (git submodule: github.com/czlonkowski/n8n-skills)
```

## Workflow Development Guidelines

### Best Practices
1. Use descriptive names for workflows and nodes
2. Add notes to complex logic for maintainability
3. Handle errors gracefully with Error Trigger nodes
4. Test workflows with sample data before activating
5. Never commit API keys or credentials -- use `.env` + `.gitignore`
6. Always validate workflows after creation with `n8n_validate_workflow`
7. Use `n8n_autofix_workflow` to fix expression format and version issues
8. When updating nodes via MCP, use `n8n_update_partial_workflow` with `updateNode` operation and `"updates": {...}` key
9. Export clean workflow JSON by fetching via `n8n_get_workflow` and stripping credentials/metadata
10. For binary-heavy workflows, keep Code nodes lightweight -- let HTTP Request nodes handle binary natively

### Common Automation Patterns
- **Scheduled tasks**: Use Cron/Schedule triggers
- **AI Agent pipelines**: Use AI Agent node + tools for research/content generation
- **Content creation**: Fetch data -> AI Script Gen -> Media Gen -> Compose -> Publish
- **Binary data pipeline**: Generate binary (TTS/images) -> Upload to temp host -> Pass URLs to renderer

### n8n Expression Syntax Quick Reference
- Reference current item: `{{ $json.fieldName }}`
- Reference another node: `{{ $('Node Name').first().json.fieldName }}`
- Reference same-index item from another node: `{{ $('Node Name').item.json.fieldName }}`
- Current date: `{{ $now.format('yyyy-MM-dd') }}`
- n8n expressions start with `=` when used in node parameters: `={{ $json.field }}`
- JSON stringify in expressions: `={{ JSON.stringify({ key: $json.value }) }}`

## Cost Estimate

| Service | Per Video | Monthly (30 videos) |
|---|---|---|
| Gemini 2.0 Flash (script) | $0.00 | $0.00 (free tier) |
| Gemini 2.5 Flash Image (8 images) | $0.00 | $0.00 (free tier) |
| Gemini 2.5 Flash TTS (voiceover) | $0.00 | $0.00 (free tier) |
| FFmpeg (video render) | $0.00 | $0.00 (local) |
| YouTube API | $0.00 | $0.00 |
| **Total** | **$0.00** | **$0.00** |

**Free tier limits** (Google AI Studio):
- Gemini 2.0 Flash: Free, generous RPM/RPD
- Gemini 2.5 Flash Image: ~500-1000 images/day free
- Gemini 2.5 Flash TTS: Free tier available
- For 1 video/day: uses ~1 script + 8 images + 1 TTS = well within limits

## Version History

- **v4.0** (2026-02-16): Migrated to completely free stack. Replaced OpenAI GPT-5 -> Gemini 2.0 Flash, DALL-E 3 -> Gemini 2.5 Flash Image, OpenAI TTS -> Gemini 2.5 Flash TTS, Creatomate -> FFmpeg Ken Burns. Increased to 8 images for ~45s video. Removed 8 nodes (Creatomate pipeline), added 1 (FFmpeg compose). 17 nodes, 16 connections. $0/month.
- **v3.1** (2026-02-09): Added Add to Playlist node -- videos automatically added to YouTube playlist after upload. 24 nodes, 23 connections.
- **v3.0** (2026-02-09): Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs). Split video data prep into 3 lightweight nodes to avoid OOM. Privacy set to public. 23 nodes, 22 connections.
- **v2.0** (2026-02-08): Replaced AI Agent with direct HTTP fetches. DALL-E via HTTP Request for URL output. Added render validation. 21 nodes.
- **v1.0** (2026-02-07): Initial creation. 18 nodes, manual trigger, Creatomate free tier.

## Development History

This workflow evolved over multiple iterations (v1.0 -> v4.0):

**v1.0 (Day 1)**: Initial 18-node workflow with AI Agent for news research. Failed because AI Agent was unreliable for structured output.

**v2.0 (Day 2)**: Replaced AI Agent with direct HTTP requests to Reddit and Hacker News APIs. Switched DALL-E from binary output to URL output. Added Creatomate render validation (status check + error handling). 21 nodes.

**v3.0-3.1 (Day 3)**: Fixed OOM crashes, added tmpfiles.org upload for Creatomate audio, added playlist management. 24 nodes.

**v4.0 (Day 10)**: Complete migration to free APIs. Single Google AI Studio API key replaces all paid services. FFmpeg Ken Burns effect replaces Creatomate for local video composition. 8 images instead of 4 for full 45-second coverage. Docker requires `NODE_FUNCTION_ALLOW_BUILTIN` env var and `ffmpeg` installed. 17 nodes.

Key issues encountered and resolved:
- **Reddit 403 Forbidden**: Reddit blocks bot-like User-Agent strings. Fixed by using `old.reddit.com` + Chrome browser UA + `Accept: application/json`.
- **n8n OOM crashes**: Caused by `getBinaryDataBuffer()` in Code nodes. Fixed by keeping Code nodes lightweight.
- **Gemini response format**: Different from OpenAI. Text in `candidates[0].content.parts[0].text`, images/audio in `inlineData.data` (base64).
- **Gemini TTS audio format**: Returns raw PCM (24kHz, 16-bit, mono). Must convert to WAV via FFmpeg before use.
- **FFmpeg in n8n**: Requires `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` env var and `apk add ffmpeg` in container.
- **YouTube quota**: 10,000 units/day, upload costs 1,600 units = max ~6 uploads/day.

## PC Upgrade Path (Future)

When running on a PC with NVIDIA GPU (e.g., RTX 3070 Ti + 32GB RAM):
1. Install ComfyUI + Stable Video Diffusion (SVD-XT) on PC
2. Replace FFmpeg Ken Burns with SVD image-to-video animation via ComfyUI API
3. Each of 8 images -> 5-sec AI-animated clip via ComfyUI HTTP API
4. FFmpeg only for stitching clips + adding audio
5. Result: AI-animated video instead of zoom/pan effect
6. n8n Docker can call ComfyUI on PC's local IP (e.g., `http://192.168.x.x:8188/`)
7. Requires: ComfyUI running with `--listen 0.0.0.0`, SVD model downloaded (~4GB)

## Commands
- Start n8n: `docker run --rm --name n8n -p 5678:5678 -e NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os -v $(pwd):/home/node/.n8n n8nio/n8n`
- Install FFmpeg: `docker exec n8n apk add --no-cache ffmpeg`
- Stop n8n: `docker stop n8n`
- Health check: `curl -s http://localhost:5678/healthz`
- Get workflow via MCP: `n8n_get_workflow` with ID `mlyG42RX4q1yIk8r`
- Validate workflow: `n8n_validate_workflow` with ID `mlyG42RX4q1yIk8r`
- List all workflows: `n8n_list_workflows`
