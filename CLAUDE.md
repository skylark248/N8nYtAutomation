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
# 1. Start n8n (from parent /n8n/ directory)
docker run --rm --name n8n -p 5678:5678 -v $(pwd):/home/node/.n8n n8nio/n8n

# 2. Copy env file and fill in your API keys
cp .env.example .env

# 3. Import the workflow
# Open http://localhost:5678 -> Import from file -> select exports/youtube-shorts-tech-news.json

# 4. Configure credentials (see docs/setup-guide.md)

# 5. Test run with unlisted privacy
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
- **Creatomate requires real URLs**: Data URIs don't work for audio/image sources. Upload audio to a temporary file host (tmpfiles.org) first.
- **tmpfiles.org URL format**: The API returns `tmpfiles.org/XXXX/file.mp3` but direct download requires `tmpfiles.org/dl/XXXX/file.mp3` -- insert `/dl/` after the domain.
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
- **Nodes**: 24 | **Connections**: 23
- **Estimated Runtime**: 8-12 minutes per video
- **Export File**: `exports/youtube-shorts-tech-news.json`
- **Documentation**: See `docs/workflow-reference.md` for full node-by-node breakdown
- **Setup Guide**: See `docs/setup-guide.md` for credential configuration

**Pipeline**: Fetch news (Reddit + HN) -> Generate script (GPT-5) -> Create images (DALL-E 3 via HTTP) -> Voiceover (OpenAI TTS) -> Upload audio to tmpfiles.org -> Compose video (Creatomate) -> Check render -> Upload to YouTube (public) -> Add to playlist

**Required Credentials** (configure in n8n before running):
1. **OpenAI API** - for GPT-5 script generation (native OpenAI node)
2. **HTTP Header Auth (OpenAI)** - for DALL-E 3 and TTS endpoints: `Authorization: Bearer sk-...` (HTTP Request nodes)
3. **HTTP Header Auth (Creatomate)** - for video composition: `Authorization: Bearer cm-...`
4. **YouTube OAuth2** - for uploading videos and adding to playlist. Enable YouTube Data API v3 in Google Cloud Console. Redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`

**Monthly Cost**: ~$7.23 (OpenAI API) + $0 (Creatomate free tier, 10 videos/month)

### Complete Node List (24 nodes)

| # | Node Name | Type | Version | ID | Purpose |
|---|---|---|---|---|---|
| 1 | Manual Trigger | `n8n-nodes-base.manualTrigger` | v1 | `trigger` | Click to run |
| 2 | Fetch Reddit Posts | `n8n-nodes-base.httpRequest` | v4.2 | `fetchReddit` | GET reddit.com/r/technology/hot.json?limit=15 |
| 3 | Format Reddit Data | `n8n-nodes-base.code` | v2 | `formatReddit` | Extract top 10 non-stickied posts with scores |
| 4 | Fetch HN Posts | `n8n-nodes-base.httpRequest` | v4.2 | `fetchHN` | GET hn.algolia.com/api/v1/search?tags=front_page |
| 5 | Pick Best Story | `n8n-nodes-base.code` | v2 | `pickStory` | Combine Reddit + HN data into selection prompt |
| 6 | Prepare Story Data | `n8n-nodes-base.code` | v2 | `parseAgent` | Format combined prompt with timestamp |
| 7 | Generate Script (GPT-5) | `n8n-nodes-base.openAi` | v1 | `scriptGen` | Create script, title, description, tags, image prompts |
| 8 | Parse Script JSON | `n8n-nodes-base.code` | v2 | `parseScript` | Parse GPT-5 JSON with fallback regex extraction |
| 9 | Split Image Prompts | `n8n-nodes-base.splitOut` | v1 | `splitImages` | Split imagePrompts array into individual items |
| 10 | Generate Images (DALL-E 3) | `n8n-nodes-base.httpRequest` | v4.2 | `generateImages` | POST openai.com/v1/images/generations, 1024x1792 |
| 11 | Collect All Images | `n8n-nodes-base.code` | v2 | `collectImages` | Gather 4 image URLs into single array |
| 12 | Generate Voiceover (TTS) | `n8n-nodes-base.httpRequest` | v4.2 | `voiceover` | POST openai.com/v1/audio/speech, voice: onyx, mp3 |
| 13 | Prepare Video Data | `n8n-nodes-base.code` | v2 | `prepareVideoData` | Set binary filename, extract imageUrls (lightweight) |
| 14 | Upload Audio | `n8n-nodes-base.httpRequest` | v4.2 | `uploadAudio` | POST tmpfiles.org/api/v1/upload (multipart form) |
| 15 | Build Video Payload | `n8n-nodes-base.code` | v2 | `buildVideoPayload` | Combine imageUrls + audio download URL |
| 16 | Compose Video (Creatomate) | `n8n-nodes-base.httpRequest` | v4.2 | `creatomateRender` | POST creatomate.com/v1/renders with template |
| 17 | Wait for Rendering | `n8n-nodes-base.wait` | v1.1 | `waitRender` | 90 seconds wait |
| 18 | Check Render Status | `n8n-nodes-base.httpRequest` | v4.2 | `checkRender` | GET creatomate.com/v1/renders/{id} |
| 19 | Validate Render | `n8n-nodes-base.code` | v2 | `validateRender` | Verify status === 'succeeded' |
| 20 | Download Rendered Video | `n8n-nodes-base.httpRequest` | v4.2 | `downloadVideo` | GET rendered MP4 as binary |
| 21 | Prepare YouTube Metadata | `n8n-nodes-base.code` | v2 | `prepareYT` | Append #Shorts, set category 28, format tags |
| 22 | Upload to YouTube | `n8n-nodes-base.youTube` | v1 | `youtubeUpload` | Upload video binary, privacy: public |
| 23 | Add to Playlist | `n8n-nodes-base.youTube` | v1 | `addToPlaylist` | Add video to YouTube playlist |
| 24 | Success Output | `n8n-nodes-base.code` | v2 | `successOutput` | Return videoUrl, videoId, uploadTime |

### Connection Map

```
Manual Trigger               -> Fetch Reddit Posts            (main)
Fetch Reddit Posts           -> Format Reddit Data            (main)
Format Reddit Data           -> Fetch HN Posts                (main)
Fetch HN Posts               -> Pick Best Story               (main)
Pick Best Story              -> Prepare Story Data            (main)
Prepare Story Data           -> Generate Script (GPT-5)       (main)
Generate Script (GPT-5)      -> Parse Script JSON             (main)
Parse Script JSON            -> Split Image Prompts           (main)
Split Image Prompts          -> Generate Images (DALL-E 3)    (main)
Generate Images (DALL-E 3)   -> Collect All Images            (main)
Collect All Images           -> Generate Voiceover (TTS)      (main)
Generate Voiceover (TTS)     -> Prepare Video Data            (main)
Prepare Video Data           -> Upload Audio                  (main)
Upload Audio                 -> Build Video Payload           (main)
Build Video Payload          -> Compose Video (Creatomate)    (main)
Compose Video (Creatomate)   -> Wait for Rendering            (main)
Wait for Rendering           -> Check Render Status           (main)
Check Render Status          -> Validate Render               (main)
Validate Render              -> Download Rendered Video       (main)
Download Rendered Video      -> Prepare YouTube Metadata      (main)
Prepare YouTube Metadata     -> Upload to YouTube             (main)
Upload to YouTube            -> Add to Playlist               (main)
Add to Playlist              -> Success Output                (main)
```

### Key Node Implementation Details

**Fetch Reddit Posts** (HTTP Request):
- URL: `https://www.reddit.com/r/technology/hot.json?limit=15`
- Header: `User-Agent: n8n-bot/1.0` (required by Reddit API)
- Timeout: 10000ms

**Format Reddit Data** (Code node):
- Filters out stickied posts
- Takes top 10, formats as `"1. [Score: X] Title (Y comments)"`

**Pick Best Story** (Code node):
- Combines Reddit summary + HN summary
- Creates prompt asking GPT-5 to pick the SINGLE most interesting tech/AI story
- References Format Reddit Data via `$('Format Reddit Data').first().json.redditSummary`

**Generate Script (GPT-5)** (OpenAI node):
- Model: GPT-5
- System prompt: "tech news researcher and YouTube Shorts scriptwriter"
- Requests JSON response with: SCRIPT (80-95 words), TITLE (under 70 chars), DESCRIPTION, TAGS, IMAGE_PROMPTS (4 vertical DALL-E prompts)
- `options: {}` -- GPT-5 does not support custom temperature/max_tokens

**Parse Script JSON** (Code node):
- Reads from `$input.first().json.content` or `$input.first().json.message?.content`
- Primary: `JSON.parse(response)`
- Fallback: regex `/\{[\s\S]*\}/` to extract JSON from markdown code blocks
- Validates required fields: SCRIPT, TITLE, IMAGE_PROMPTS array

**Generate Images (DALL-E 3)** (HTTP Request):
- POST `https://api.openai.com/v1/images/generations`
- Auth: HTTP Header Auth (OpenAI) -- `Authorization: Bearer sk-...`
- Body: `{ model: "dall-e-3", prompt: "{{ $json.imagePrompts }}", size: "1024x1792", n: 1 }`
- Returns URLs (not binary) -- critical for passing to Creatomate
- Timeout: 60000ms

**Generate Voiceover (TTS)** (HTTP Request):
- POST `https://api.openai.com/v1/audio/speech`
- Body: `{ model: "tts-1", input: script, voice: "onyx", response_format: "mp3" }`
- Response format: `file` with output property `voiceover`
- Voice options: alloy, echo, fable, onyx, nova, shimmer

**Prepare Video Data** (Code node):
- LIGHTWEIGHT -- does NOT use `getBinaryDataBuffer()` (avoids OOM)
- Just extracts imageUrls from Collect All Images and sets binary filename to `voiceover.mp3`

**Upload Audio** (HTTP Request):
- POST `https://tmpfiles.org/api/v1/upload`
- Content type: multipart-form-data
- Binary property: `voiceover`
- tmpfiles.org provides temporary URLs (files expire after ~1 hour)

**Build Video Payload** (Code node):
- Reads imageUrls from Prepare Video Data
- Reads upload response from tmpfiles.org
- Converts URL: inserts `/dl/` after `tmpfiles.org/` for direct download
- Outputs `{ imageUrls, audioUrl }`

**Compose Video (Creatomate)** (HTTP Request):
- POST `https://api.creatomate.com/v1/renders`
- Auth: HTTP Header Auth (Creatomate)
- Body: `{ template_id: "YOUR_TEMPLATE_ID", modifications: { "Image-1.source": url1, ..., "Audio.source": audioUrl } }`
- **SETUP REQUIRED**: Replace `YOUR_TEMPLATE_ID`

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
| `YOUR_TEMPLATE_ID` | Compose Video (Creatomate) node, in jsonBody | Your Creatomate template UUID |
| `YOUR_PLAYLIST_ID` | Add to Playlist node, `playlistId` field | Your YouTube playlist ID (starts with `PL...`) |

### Creatomate Template Requirements

1. Template size: 1080x1920 (9:16 vertical), 45 seconds
2. Elements (names must match exactly):
   - `Image-1`, `Image-2`, `Image-3`, `Image-4` -- each shows ~10 seconds with fade transitions
   - `Audio` -- voiceover track
3. All elements: Provider = **URL**, **Dynamic Source** checked
4. Template ID found in the Creatomate dashboard URL

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
| GPT-5 (script generation) | $0.06 | $1.80 |
| DALL-E 3 (4 images) | $0.16 | $4.80 |
| OpenAI TTS (voiceover) | $0.001 | $0.03 |
| Creatomate (video render) | $0.00 | $0.00 (free: 10/mo) |
| YouTube API | $0.00 | $0.00 |
| tmpfiles.org (temp audio host) | $0.00 | $0.00 |
| **Total** | **~$0.22** | **~$7** |

## Version History

- **v3.1** (2026-02-09): Added Add to Playlist node -- videos automatically added to YouTube playlist after upload. 24 nodes, 23 connections.
- **v3.0** (2026-02-09): Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs). Split video data prep into 3 lightweight nodes to avoid OOM. Privacy set to public. 23 nodes, 22 connections.
- **v2.0** (2026-02-08): Replaced AI Agent with direct HTTP fetches. DALL-E via HTTP Request for URL output. Added render validation. 21 nodes.
- **v1.0** (2026-02-07): Initial creation. 18 nodes, manual trigger, Creatomate free tier.

## Development History

This workflow evolved over 3 days (v1.0 -> v3.1):

**v1.0 (Day 1)**: Initial 18-node workflow with AI Agent for news research. Failed because AI Agent was unreliable for structured output.

**v2.0 (Day 2)**: Replaced AI Agent with direct HTTP requests to Reddit and Hacker News APIs. Switched DALL-E from binary output to URL output. Added Creatomate render validation (status check + error handling). 21 nodes.

**v3.0 (Day 3 morning)**: Fixed critical OOM crash caused by loading binary audio data in Code nodes. Split monolithic "Prepare Video" node into 3 lightweight nodes. Discovered Creatomate doesn't accept data URIs for audio -- added tmpfiles.org upload step. Changed YouTube privacy from unlisted to public. 23 nodes.

**v3.1 (Day 3 afternoon)**: Added "Add to Playlist" node to automatically organize uploaded Shorts into a YouTube playlist. 24 nodes.

Key issues encountered and resolved:
- **n8n OOM crashes**: Caused by `getBinaryDataBuffer()` in Code nodes. Fixed by keeping Code nodes lightweight and letting HTTP Request nodes handle binary.
- **Creatomate audio failure**: Data URIs rejected. Fixed by uploading to tmpfiles.org and passing real download URL.
- **tmpfiles.org URL format**: API returns viewing URL, not download URL. Fixed by inserting `/dl/` in path.
- **DALL-E binary vs URL**: Initially used binary output but Creatomate needs URLs. Switched to URL-only response.
- **YouTube quota**: 10,000 units/day, upload costs 1,600 units = max ~6 uploads/day.

## Commands
- Start n8n: `docker run --rm --name n8n -p 5678:5678 -v $(pwd):/home/node/.n8n n8nio/n8n`
- Stop n8n: `docker stop n8n`
- Health check: `curl -s http://localhost:5678/healthz`
- Get workflow via MCP: `n8n_get_workflow` with ID `mlyG42RX4q1yIk8r`
- Validate workflow: `n8n_validate_workflow` with ID `mlyG42RX4q1yIk8r`
- List all workflows: `n8n_list_workflows`
