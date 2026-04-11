# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# n8n YouTube Shorts Automation

## Instance Configuration
- **URL**: http://localhost:5678
- **Environment**: Local Docker container (shared n8n instance with JobSearchAutomation)
- **Focus**: Automated YouTube Shorts creation from trending tech news
- **n8n Workflow ID**: `zuFXklAfWmiZqTZh` (deployed to running instance)
- **Workflow Name**: "YouTube Shorts - Tech News Automation"
- **GitHub Repo**: https://github.com/skylark248/N8nYtAutomation.git

## Parent Directory Context

The n8n Docker instance lives at **`D:\N8n\`** (separate from this repo). That directory contains:
- `Dockerfile` -- custom n8n image with FFmpeg baked in (extends `docker.n8n.io/n8nio/n8n:latest`)
- `docker-compose.yml` -- one-command startup with all env vars, volumes, and `extra_hosts` for ComfyUI
- `start_instructions.txt` -- quick reference for all Docker commands
- n8n runtime data is stored in a named Docker volume (`n8n_data`)
- Workflow JSON files are imported via the n8n UI, not read from the filesystem at runtime

## Quick Start

```bash
# 1. Start n8n (run from D:\N8n — the directory containing docker-compose.yml)
# First time only: docker compose build  (builds custom image with FFmpeg)
docker compose up -d

# 2. Import the workflow
# Open http://localhost:5678 -> Import from file -> select exports/youtube-shorts-tech-news.json

# 3. Replace placeholder API keys directly in node code (see Placeholder Values table below):
#    - YOUR_GEMINI_API_KEY   → in Generate Script node URL param
#    - YOUR_FAL_API_KEY      → in Generate Images + Generate Video Clips nodes
#    - YOUR_ELEVENLABS_API_KEY → in Generate Voiceover node
#    - YOUR_STABILITY_API_KEY  → in Generate Background Music node (optional)
#    - =YOUR_PLAYLIST_ID    → in Add to Playlist node

# 4. Configure YouTube OAuth2 credential (see docs/setup-guide.md)

# 5. Test run with unlisted privacy, then switch to public
```

## Docker Setup

**Files** (in parent `/n8n/` directory, NOT in this repo):
- `Dockerfile` -- extends `n8nio/n8n:latest`, installs `ffmpeg-static` + `@ffprobe-installer/ffprobe` via npm, symlinks to `/usr/local/bin/`
- `docker-compose.yml` -- sets `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os`, `N8N_RUNNERS_TASK_TIMEOUT=9000` (150 min in **seconds** — unit is seconds NOT ms; using ms value overflows 32-bit int and crashes the task runner), `N8N_RUNNERS_HEARTBEAT_INTERVAL=600` (10 min), `extra_hosts: host.docker.internal:host-gateway` (Docker→Windows ComfyUI access), mounts `comfyui/workflows` as read-only volume, mounts `N8nYtAutomation/videos` → `/home/node/videos` (for `exportLocal` node), `N8N_RESTRICT_FILE_ACCESS_TO` includes `/home/node/videos`, `restart: always`

**Why custom image**: The official `n8nio/n8n` uses a hardened Alpine image without `apk` package manager. FFmpeg must be installed via npm global packages (`ffmpeg-static`, `@ffprobe-installer/ffprobe`) and symlinked to PATH.

## MCP Server Setup

### n8n MCP Server (czlonkowski/n8n-mcp)
Bridges Claude Code with n8n's workflow automation platform. Provides structured access to 1,084+ n8n nodes.

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

**Important Notes:**
- MCP tools are injected when a **new conversation begins** -- they don't appear retroactively
- "Failed to connect" when idle is **normal** -- it only connects during active conversations

**Documentation Tools:** `search_nodes`, `get_node`, `validate_node`, `validate_workflow`, `search_templates`, `get_template`, `tools_documentation`

**Workflow Management Tools** (requires API key): `n8n_create_workflow`, `n8n_get_workflow`, `n8n_update_partial_workflow`, `n8n_update_full_workflow`, `n8n_delete_workflow`, `n8n_list_workflows`, `n8n_validate_workflow`, `n8n_autofix_workflow`, `n8n_deploy_template`, `n8n_test_workflow`, `n8n_executions`, `n8n_health_check`

### MCP Gotchas (Learned from Building This Workflow)

- **`n8n_update_partial_workflow` updateNode operation**: Use `"updates": {...}` key, NOT `"properties": {...}`. The latter causes "Missing required parameter 'updates'" error.
- **YouTube node `playlistItem` resource**: Set `resource: "playlistItem"` and pass `playlistId` + `videoId`. The videoId comes from the Upload to YouTube response as `uploadId` or `id`. Use expression format `=PLxxxxxxx` for playlistId to avoid dropdown loading error ("[object Object]").
- **Binary data in Code nodes**: Do NOT use `getBinaryDataBuffer()` -- it loads entire binary into memory and causes OOM crashes. Instead, pass binary metadata through and let HTTP Request nodes handle binary natively.
- **Gemini API key in URL**: Pass as query param `?key=YOUR_KEY` -- no n8n credential setup needed. Simpler than header auth.
- **Gemini TTS returns raw PCM**: Not MP3/WAV. Must convert with `ffmpeg -f s16le -ar 24000 -ac 1 -i audio.pcm audio.wav` before use.
- **Gemini response text location**: `candidates[0].content.parts[0].text` (not OpenAI-style `choices[0].message.content`). Audio/image in `inlineData.data` (base64).
- **FFmpeg in Code nodes**: Requires `NODE_FUNCTION_ALLOW_BUILTIN=child_process,fs,path,os` Docker env var. Without it, `require('child_process')` fails.
- **Code node sandbox escape**: n8n Code nodes don't have `fetch`, `https`, or `curl`. To make HTTP requests, write a `.js` file to `/tmp/` and execute via `exec('node script.js')`. The spawned process runs outside the sandbox with full module access.
- **Task runner timeout**: Unit is **seconds** (not ms!). Default 60s. For ComfyUI generation (150 min), set `N8N_RUNNERS_TASK_TIMEOUT=9000` in docker-compose.yml. Setting a millisecond value like `9000000` causes a 32-bit integer overflow inside the task runner, making it crash on every task (symptom: "took too long to acknowledge acceptance of task" loop in logs).
- **Workflow creation**: Create with all nodes and connections in one `n8n_create_workflow` call for best results, then fix individual nodes with `n8n_update_partial_workflow`.
- **Reddit 403 Forbidden**: Reddit blocks bot User-Agents. Use `old.reddit.com` + a Chrome browser UA string + `Accept: application/json` header.
- **Gemini prompt format**: The `combinedPrompt` passed to Gemini for story selection must be raw headlines only — adding format instructions there causes Gemini JSON mode to return the wrong keys (STORY_TITLE/KEY_FACTS instead of SCRIPT/TITLE/IMAGE_PROMPTS).
- **API keys in Code nodes**: n8n sandbox blocks `process.env` access at runtime. All API keys are stored in `keys.json` (mounted at `/home/node/keys.json` in Docker) and read at runtime via `JSON.parse(fs.readFileSync('/home/node/keys.json', 'utf8'))`. Do NOT hardcode keys in node code.
- **Stable Audio model parameter**: Must include `model: stable-audio-2.5` as a multipart form field. Omitting it defaults to `stable-audio-2` (same cost: 20 credits/gen flat for 2.5, `17 + 0.06*steps` for 2.0 at default 50 steps = same 20 credits). Use 2.5 — it's the newer model.
- **ElevenLabs output format tier**: `mp3_44100_192` requires Creator plan. Starter plan max is `mp3_44100_128`. Use `mp3_44100_128` to avoid 403 errors on Starter tier.
- **Background agents**: Bash commands are auto-denied when agents run in background mode. Use the Write tool directly for file operations.
- **ComfyUI from Docker**: n8n Docker container reaches ComfyUI on Windows host via `http://host.docker.internal:8188`. Requires `extra_hosts: ["host.docker.internal:host-gateway"]` in docker-compose.yml and Windows Firewall rule for port 8188.
- **ComfyUI embedded Python**: ComfyUI uses its own Python at `C:\ComfyUI\python_embeded\python.exe` (Python 3.13). The `python` command in bash resolves to the Microsoft Store stub and fails. Always use the full path: `/c/ComfyUI/python_embeded/python.exe script.py`
- **ComfyUI NF4 vec_in_dim bug**: FLUX NF4 models cause `mat1 and mat2 shapes cannot be multiplied (1x1 and 768x3072)` in KSampler. Root cause: NF4 packs weights as `(out*in//2, 1)` uint8, so `model_detection.py` reads `shape[1]=1` as `vec_in_dim`. Fix applied to `C:\ComfyUI\ComfyUI\comfy\model_detection.py` lines 240-255 — detects uint8+shape[1]==1 and recovers actual dim from bias: `(w.shape[0] * 2) // bias.shape[0]`. See `comfyui-nf4-debugging` skill for full details.
- **ComfyUI pyc cache**: Python `.pyc` bytecode can be stale even when source is fixed (same-second mtime fools the check). After patching source: delete the `.pyc`, recompile with embedded Python, restart ComfyUI. Verify fix is in pyc with `marshal` check — search for a unique string from new code (comments are NOT stored in bytecode).
- **ComfyUI image upload**: To use an image in HunyuanVideo I2V, first upload it via `POST /upload/image` (multipart form), then reference the returned filename in the LoadImage node. The filename is returned in the JSON response.
- **ComfyUI polling**: After `POST /prompt`, poll `GET /history/{prompt_id}` until the prompt_id appears in the response. Output images/videos are in the `outputs` object with filenames to fetch via `GET /view?filename=...&subfolder=...&type=output`.
- **HunyuanImageToVideo is a conditioning node, NOT a sampler**: Outputs `[0]=CONDITIONING, [1]=LATENT`. It does NOT denoise — a separate KSampler node is required after it. Common mistake: connecting HunyuanImageToVideo output directly to VAEDecodeTiled causes `return_type_mismatch: received_type(CONDITIONING) mismatch input_type(LATENT)`.
- **HunyuanImageToVideo input names**: Use `length` (not `num_frames`) for frame count, `start_image` (not `image`) for the input image, `guidance_type: "v2 (replace)"` (with spaces, not `"v2(replace)"`). Input `positive` takes CONDITIONING from TextEncodeHunyuanVideo_ImageToVideo.
- **HunyuanVideo model file paths**: CLIP/text encoder at `split_files\\text_encoder\\llava_llama3_fp8_scaled.safetensors`, CLIPVision at `split_files\\clip_vision\\llava_llama3_vision.safetensors`, VAE at `split_files\\vae\\hunyuan_video_vae_bf16.safetensors`. These are subdirectory paths relative to their model folder — the flat filenames will fail with "not in list" errors.
- **CLIPVisionEncode required param**: Must include `crop: "center"` — omitting it causes a "Required input missing: crop" 400 error.
- **TextEncodeHunyuanVideo_ImageToVideo required param**: Must include `image_interleave: 2` (default value) — omitting it causes "Required input missing: image_interleave".
- **HunyuanVideo KSampler seed**: Set seed on the KSampler node (node `'10'` in the 12-node workflow), not on HunyuanImageToVideo.
- **SaveAnimatedWEBP output key**: Uses `"gifs"` key in history API response (not `"images"`). Use `node12.gifs || node12.images || []` for compatibility.
- **HunyuanVideo output node**: In the 12-node workflow, output is on node `'12'` (SaveAnimatedWEBP), not `'10'`.
- **Animated WEBP viewing**: Windows Photo Viewer shows animated WEBP as static. Open in Chrome/Edge/Firefox to verify animation is working.
- **`n8n_update_partial_workflow` updateNode node identification**: Use `nodeId` field (the node's programmatic ID like `"animateImages"`), not `id` or `name`. Using `name` with special characters fails with "Node not found".
- **Animated WEBP not decodable by static FFmpeg build**: `ffmpeg-static` (johnvansickle) skips `ANIM`/`ANMF` chunks — output from `SaveAnimatedWEBP` cannot be decoded. Fix: replace `SaveAnimatedWEBP` with `SaveImage` in the ComfyUI workflow. `SaveImage` outputs individual PNG frames; download all frames in n8n and assemble to MP4 with `ffmpeg -r 24 -i frame_%05d.png`. Duration = `frames.length / 24`.
- **FFmpeg xfade requires constant frame rate**: `fps=30` MUST come AFTER `trim+setpts` in the filter chain. Wrong: `scale,crop,fps=30,trim=duration=X,setpts=PTS-STARTPTS` → xfade error "current rate of 1/0 is invalid". Correct: `scale,crop,trim=duration=X,setpts=PTS-STARTPTS,fps=30`.
- **`ffprobe` permission denied in Docker**: `@ffprobe-installer/ffprobe` binary installs as `-rwxr--r--` (owner-execute only). The `node` user gets "Permission denied" at runtime. Fix in code: use `ffmpeg -i file 2>&1 || true` and parse `Duration: H:M:S` with regex. Fix in Dockerfile: add `chmod a+x $(node -p "require('@ffprobe-installer/ffprobe').path")` before the symlink (requires `docker compose build` rebuild).
- **`docker exec` path conversion in git bash (Windows)**: MSYS automatically converts Unix paths like `/tmp/` to Windows paths (`C:/Users/.../Temp/`), breaking docker exec commands. Prefix with `MSYS_NO_PATHCONV=1`: `MSYS_NO_PATHCONV=1 docker exec container bash -c "..."`.
- **SDXL quality settings**: For best image quality on 8GB VRAM — use `dpmpp_2m` sampler + `karras` scheduler + 30 steps + cfg 7.5. Significantly sharper than default `euler` + `normal` + 20 steps. Each image takes ~35-45s vs ~25-30s.
- **minterpolate is slow**: `minterpolate=fps=30:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1` generates true motion-estimated frames but takes ~5-10 min for 8 clips. Raise FFmpeg timeout to 600s in the Code node. Worth it — eliminates the jittery frame-duplication look from slow-motion stretching.
- **Stability AI Stable Audio API removed**: `api.stability.ai/v2beta/stable-audio/generate` returns 404 (endpoint removed as of April 2026). Their OpenAPI spec has no audio endpoints. Image endpoints (`/v2beta/stable-image/generate/sd3`, `/ultra`, `/core`) and 3D still work. Use fal.ai Stable Audio (`fal.run/fal-ai/stable-audio`) instead.
- **Stability AI SD3 returns base64**: Response JSON has `{image: "<base64>", finish_reason: "SUCCESS", seed: N}`. No URL — must convert to data URI (`data:image/jpeg;base64,...`) for downstream nodes.
- **fal.ai Kling accepts data URIs**: `image_url` parameter accepts `data:image/jpeg;base64,...` — no need to host images on a CDN. Tested and confirmed working.
- **Stability AI SD3 cost**: ~13 credits per image (9:16 aspect ratio, JPEG output). 1,025 credits ≈ $10 ≈ 78 images ≈ 13 full runs.
- **Sandbox escape multipart escaping**: Building multipart form data in the `js` array (spawned script) causes double-quote escaping nightmares (`\\"` vs `\\\"` across 3 layers of string encoding). Fix: build multipart body in the n8n Code node itself, base64-encode it, pass via cfg.json. Spawned script just decodes and POSTs.
- **fal.ai Stable Audio**: Endpoint `fal.run/fal-ai/stable-audio`, JSON body `{prompt, seconds_total, steps}`, returns `{audio_file: {url}}` (WAV). Convert to MP3 with FFmpeg. Same `Key {falApiKey}` auth as other fal.ai endpoints. Generation at steps=100 takes ~70-90s — exec timeout must be ≥300s.
- **Gemini thinking model token truncation**: `gemini-3-flash-preview` is a thinking model — thinking tokens count against `maxOutputTokens`. With 1500-2500 tokens, thinking consumes most of the budget, leaving too few for actual output → JSON truncated, no closing `}`. Fix: set `thinkingConfig: { thinkingBudget: 0 }` to disable thinking, and `maxOutputTokens: 8192`.
- **API keys in n8n execution logs**: Any field passed through node JSON output is stored in n8n execution history in plain text. Never pass API keys through node outputs. Read them directly from `keys.json` in each node that needs them.
- **Duplicate story detection**: `pickStory` writes chosen story title to `/home/node/videos/last_stories.json` (14-day rolling history). Uses 60% word-overlap check (words ≥4 chars). To reset: delete the file inside Docker. Falls back to top 3 regardless if all stories are duplicates.
- **ASS subtitles vs SRT in filter_complex**: `subtitles=file.srt` with `force_style` — commas in style values are FFmpeg filter separators and break parsing. Either escape with `\,` or switch to `.ass` file with `ass=file.ass` filter (style embedded in file header, no escaping needed). Current pipeline uses no burned captions — YouTube auto-captions instead.

### MCP Troubleshooting

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

1. **Expression Syntax** (`n8n-expression-syntax`) - Correct expression patterns and variable access
2. **MCP Tools Expert** (`n8n-mcp-tools-expert`) - Proper use of n8n-mcp server tools
3. **Workflow Patterns** (`n8n-workflow-patterns`) - 5 proven architectural approaches
4. **Validation Expert** (`n8n-validation-expert`) - Interpret and fix validation errors
5. **Node Configuration** (`n8n-node-configuration`) - Operation-specific node setup requirements
6. **Code JavaScript** (`n8n-code-javascript`) - JavaScript implementation in Code nodes
7. **Code Python** (`n8n-code-python`) - Python limitations and standard library usage

### ComfyUI Skills (custom)
Debugging guidance for ComfyUI local AI generation issues.

1. **NF4 Debugging** (`comfyui-nf4-debugging`) - Diagnose and fix NF4 quantized model errors (shape mismatches, pyc cache, model detection). Activates on `mat1 and mat2 shapes`, KSampler errors, or model_detection.py issues.
2. **HunyuanVideo I2V** (`comfyui-hunyuan-i2v`) - Build and debug HunyuanVideo Image-to-Video workflows. Covers correct 12-node structure, required params, model file paths, and all error fixes. Activates on HunyuanImageToVideo, animateImages, or I2V workflow issues.

### ComfyUI MCP Server (custom, created 2026-03-08)
Direct ComfyUI API access from Claude Code. Location: `C:\Users\rstar\.claude\comfyui-mcp\`

**Setup** (run once):
```bash
cd C:\Users\rstar\.claude\comfyui-mcp && npm install
claude mcp add comfyui-mcp \
  -e COMFYUI_URL=http://localhost:8188 \
  -s local \
  -- node C:\Users\rstar\.claude\comfyui-mcp\index.js
```

**Tools**: `comfyui_health`, `comfyui_submit_workflow`, `comfyui_poll_result`, `comfyui_upload_image`, `comfyui_free_memory`, `comfyui_get_node_info`, `comfyui_queue_status`

## Active Workflows

### YouTube Shorts - Tech News Automation
- **Status**: Inactive (manual trigger)
- **n8n Workflow ID**: `zuFXklAfWmiZqTZh`
- **Nodes**: 18 | **Connections**: 17
- **Estimated Runtime**: 25-40 minutes per video (cloud AI) | **Monthly Cost**: ~$44/month for 30 Shorts
- **Export File**: `exports/youtube-shorts-tech-news.json`
- **Version**: v8.4
- **Documentation**: `docs/workflow-reference.md` (full node-by-node breakdown)
- **Setup Guide**: `docs/setup-guide.md` (credential configuration)

**Pipeline**: Fetch news (Reddit + HN) → Pick best story (top 3, 14-day dupe check) → Generate script (Gemini 3 Flash, HECK-loop, 75-90 words) → Generate images (Stability AI SD3 primary / fal.ai Flux Schnell fallback, 6×) → Animate images (fal.ai Kling I2V, 6×5s clips) → Voiceover (ElevenLabs TTS, MP3) → Background music (fal.ai Stable Audio, 45s) → Compose video (FFmpeg: minterpolate + xfade + music mix, no burned captions) → Export locally → Upload to YouTube (public) → Add to playlist

**Required Credentials** (add to `keys.json` — mounted at `/home/node/keys.json` in Docker):
- `geminiApiKey` — Google AI Studio API key (Gemini script generation, free)
- `falApiKey` — fal.ai key (images fallback + video clips + music, ~$2.19/run)
- `elevenLabsApiKey` — ElevenLabs key (voiceover, Starter plan+, ~$0.17/run)
- `stabilityApiKey` — Stability AI key (images primary — auto-fallback to fal.ai when credits exhausted)
- `youtubePlaylistId` — YouTube playlist ID (optional)

**YouTube OAuth2** - configure in n8n credential UI. Enable YouTube Data API v3. Redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`

**No local GPU required** — all AI generation uses cloud APIs (fal.ai, ElevenLabs, Stability AI)

### Node List (18 nodes)

| # | Node Name | Type | ID | Purpose |
|---|---|---|---|---|
| 1 | Manual Trigger | manualTrigger | `trigger` | Click to run |
| 2 | Fetch Reddit Posts | httpRequest | `fetchReddit` | GET old.reddit.com/r/technology/hot.json?limit=15 |
| 3 | Format Reddit Data | code | `formatReddit` | Extract top 10 non-stickied posts |
| 4 | Fetch HN Posts | httpRequest | `fetchHN` | GET hn.algolia.com/api/v1/search?tags=front_page |
| 5 | Pick Best Story | code | `pickStory` | Score + rank Reddit/HN by engagement, dedupe against 14-day history, output top 3 |
| 6 | Prepare Story Data | code | `parseAgent` | Pass rankedStories as rawStory + timestamp (no API keys in output) |
| 7 | Generate Script (Gemini) | code | `scriptGen` | Gemini 3 Flash: HECK-loop script (75-90 words), title, 6 tags, 6 beat-tied image prompts. thinkingBudget:0 |
| 8 | Parse Script JSON | code | `parseScript` | Parse Gemini JSON, validate ≥65 words, ≥3 tags, ≥5 image prompts |
| 9 | Generate Images (SD3/Flux) | code | `generateImages` | Stability AI SD3 primary (9:16, ~13 credits/img, data URI output) / fal.ai Flux Schnell fallback (768x1344, ~$0.09). Atomic balance check — all 6 images use same provider |
| 10 | Generate Video Clips (fal.ai Kling) | code | `generateVideo` | Kling v1.6 I2V queue API: 6x clips (9:16, 5s each), sandbox escape, ~$2.10 total |
| 11 | Generate Voiceover (ElevenLabs) | code | `voiceover` | ElevenLabs eleven_multilingual_v2, voice Antoni, MP3 128kbps, sandbox escape |
| 12 | Generate Background Music (Stable Audio) | code | `generateMusic` | fal.ai Stable Audio: 45s WAV→MP3, 300s timeout, fallback silence if falApiKey not set |
| 13 | Compose Video (FFmpeg) | code | `composeVideo` | Download clips (3 retries) + minterpolate + xfade + voice+music mix, 1080x1920, no burned captions |
| 14 | Export Video Locally | code | `exportLocal` | Save video.mp4 + upload-info.txt to `videos/{timestamp}_{title}/` |
| 15 | Prepare YouTube Metadata | code | `prepareYT` | Append #Shorts, category 28, format tags |
| 16 | Upload to YouTube | youTube | `youtubeUpload` | Upload video binary, privacy: public |
| 17 | Add to Playlist | youTube | `addToPlaylist` | Add video to YouTube playlist |
| 18 | Success Output | code | `successOutput` | Return youtubeUrl, uploadTime |

### API Keys Configuration

All API keys are stored in `keys.json` at the repo root (mounted read-only into Docker at `/home/node/keys.json`):

```json
{
  "geminiApiKey": "YOUR_GEMINI_API_KEY",
  "falApiKey": "YOUR_FAL_API_KEY",
  "elevenLabsApiKey": "YOUR_ELEVENLABS_API_KEY",
  "stabilityApiKey": "YOUR_STABILITY_API_KEY",
  "youtubePlaylistId": "PLxxxxxxxxxxxxxxxx"
}
```

| Key | Where to Get | Required |
|---|---|---|
| `geminiApiKey` | aistudio.google.com/apikeys (free) | Yes |
| `falApiKey` | fal.ai/dashboard | Yes |
| `elevenLabsApiKey` | elevenlabs.io/app/settings/api-keys (Starter plan+) | Yes |
| `stabilityApiKey` | platform.stability.ai/account/keys (optional) | No — images fall back to fal.ai Flux |
| `youtubePlaylistId` | YouTube playlist URL after `list=` | No — skips playlist step |

**Also set** `=YOUR_PLAYLIST_ID` in the Add to Playlist node `playlistId` field (use `=PLxxxxxxx` expression syntax to avoid dropdown error).

## Project Structure

```
.
├── README.md                 # Project overview & quickstart
├── CLAUDE.md                 # Claude Code instructions (this file)
├── .env.example              # Template for secrets (copy to .env)
├── comfyui/                  # Local AI generation setup
│   ├── README.md             # ComfyUI setup guide (models, VRAM, troubleshooting)
│   ├── workflows/            # ComfyUI API-format workflow templates
│   │   ├── sdxl-text-to-image.json        # SDXL base 1.0 (768x1344) — reference only; n8n uses 30 steps, dpmpp_2m/karras, cfg=7.5
│   │   ├── flux-nf4-text-to-image.json    # FLUX.1 Dev NF4 (768x1344) — unused, kept for reference
│   │   └── hunyuan-i2v-gguf-q4.json       # HunyuanVideo I2V (544x960, 49 frames)
│   └── setup/                # Installation scripts
│       ├── install-models.ps1        # Download ~24GB of models
│       ├── install-custom-nodes.ps1  # Clone GGUF custom node (HunyuanVideo)
│       └── run_api_server.bat        # Launch ComfyUI API server
├── docs/
│   ├── setup-guide.md        # Step-by-step credential setup
│   └── workflow-reference.md # Complete 16-node workflow documentation + version history
├── exports/
│   └── youtube-shorts-tech-news.json  # Clean export (no credentials)
├── n8n-mcp/                  # MCP server (git submodule)
└── n8n-skills/               # Claude skills (git submodule)
```

## Workflow Development Guidelines

### Best Practices
- Always validate workflows after creation with `n8n_validate_workflow`
- Use `n8n_autofix_workflow` to fix expression format and version issues
- When updating nodes via MCP, use `n8n_update_partial_workflow` with `updateNode` operation and `"updates": {...}` key
- Export clean workflow JSON by fetching via `n8n_get_workflow` and stripping credentials/metadata
- For binary-heavy workflows, keep Code nodes lightweight -- let HTTP Request nodes handle binary natively

### n8n Expression Syntax Quick Reference
- Reference current item: `{{ $json.fieldName }}`
- Reference another node: `{{ $('Node Name').first().json.fieldName }}`
- Reference same-index item from another node: `{{ $('Node Name').item.json.fieldName }}`
- Current date: `{{ $now.format('yyyy-MM-dd') }}`
- n8n expressions start with `=` when used in node parameters: `={{ $json.field }}`
- JSON stringify in expressions: `={{ JSON.stringify({ key: $json.value }) }}`

## Version History (recent — see docs/workflow-reference.md for full history)

- **v8.4** (2026-04-11): 10-day test prep. `pickStory`: duplicate detection (60% word-overlap check against 14-day history in `/home/node/videos/last_stories.json`), top stories 6→3. `generateImages`: renamed to "Generate Images (SD3/Flux)", explicit stderr log on Flux fallback, confirmed atomic balance check (all 6 images same provider). `scriptGen`: reads `geminiApiKey` directly from keys.json (no longer passed via node output to prevent execution log leakage), word target 90-120→75-90 words, `thinkingBudget:0` (prevents token truncation). `parseScript`: min word count 80→65. `parseAgent`: removed `geminiApiKey` from output. `composeVideo`: removed .ass captions (YouTube auto-captions), download retry logic (3 attempts, status check, stream error handling), 300s timeout.
- **v8.3** (2026-04-10): Image + music provider changes. `generateImages`: Stability AI SD3 as primary, fal.ai Flux fallback. SD3 returns base64 → data URIs (Kling accepts directly). `generateMusic`: switched from Stability AI (404, removed) to fal.ai Stable Audio. `scriptGen`: converted to Code node with sandbox escape. `parseScript`: updated for Gemini 3 thinking model. `generateVideo`: fixed polling URL.
- **v8.2** (2026-04-08): API key fixes. `voiceover`: output format `mp3_44100_192` → `mp3_44100_128` (ElevenLabs Starter plan caps at 128kbps; 192kbps requires Creator tier). `generateMusic`: added `model: stable-audio-2.5` multipart field (newer model, flat 20 credits/gen). All API keys migrated to `keys.json` (mounted at `/home/node/keys.json`) — no more hardcoded keys in node code. All 4 cloud endpoints verified working: Gemini ✅ fal.ai Flux ✅ fal.ai Kling ✅ ElevenLabs ✅.
- **v8.1** (2026-04-06): Script generation improvements. `pickStory` now scores and ranks all Reddit+HN posts by engagement (Reddit: score+comments×2, HN: points+comments×3, +300 per viral keyword hit from 30-keyword list). `parseAgent` repurposed to pass ranked list as `rawStory`. Gemini prompt: raised target to 90-120 words, added explicit viral story-selection criteria, image prompts now tied to specific HECK beats (Hook/Explain×2/Climax×2/Kicker). `parseScript` validation tightened: min 80 words (was 70), min 3 tags added. No new nodes.
- **v8.0** (2026-04-06): Full cloud AI overhaul. Replaced ComfyUI SDXL+HunyuanVideo with fal.ai Flux Schnell (images) + Kling v1.6 I2V (video). Replaced Gemini TTS with ElevenLabs TTS (MP3, no PCM conversion). Added Stable Audio background music (45s, mixed at 28% vol). Added burned-in SRT captions via FFmpeg subtitles filter. Script prompt rewritten to HECK loop (Hook-Explain-Climax-Kicker) with seamless replay loop. Added Instagram Reels upload via Facebook Graph API resumable upload. 17→19 nodes. Runtime: 80-110 min → 35-70 min. Cost: $0 → ~$44/month for 30 Shorts (~$1.47/video: $0.09 images + $2.10 video + $0.17 voice + $0.37 music). No GPU or ComfyUI required.
- **v7.2** (2026-03-28): Added local video export. New `exportLocal` node (17 nodes) saves `video.mp4` + `upload-info.txt` to `videos/{timestamp}_{title}/` on Windows host after each run. Requires `D:\N8n\docker-compose.yml` volume mount + `docker compose restart`.
- **v7.1** (2026-03-28): Removed Instagram Reels cross-posting and Schedule Trigger. Back to 16 nodes, manual trigger only. YouTube-only pipeline.
- **v7.0** (2026-03-14): Added Instagram Reels cross-posting. 16→26 nodes. Fork after `composeVideo`: Instagram branch posts 4x/week (Mon/Wed/Fri/Sun) via Facebook Resumable Upload API + Graph API. Schedule Trigger added. (Reverted in v7.1)
- **v6.9** (2026-03-09): scriptGen model updated to `gemini-3-flash-preview` (Gemini 3 Flash). TTS stays on `gemini-2.5-flash-preview-tts`. **Full end-to-end run confirmed successful.**
- **v6.8** (2026-03-09): Script stays 110-120 words (~45s narration). `N8N_RUNNERS_TASK_TIMEOUT` 7200→9000 (150 min). animateImages GLOBAL_BUDGET_MS 6000000→9000000ms (150 min), exec timeout 6600000→9600000ms (160 min). Runtime: ~80-110 min.
- **v6.7** (2026-03-09): Increased HunyuanVideo frames 25→49 (2.04s clips) for smoother slow-motion — slowdown ratio drops from 4.5x to ~2.3x, so minterpolate needs far less interpolation. Increased Gemini script target 80-95→110-120 words for ~45s narration. Added word count validation (throws if <90 words). Poll timeout raised 1200s→1800s for longer clip generation. Expected animation runtime: ~65-75 min (+28 min vs v6.6).
- **v6.6** (2026-03-09): Fixed minterpolate+xfade incompatibility — root cause: minterpolate was running on ~6fps input (after 4x slowdown setpts), a 5x ratio that corrupts PTS and breaks xfade (hard cuts, short video). Fix: two-pass compose — Pass 1 applies minterpolate at native 24fps→60fps per clip and saves to intermediate file (normalises PTS); Pass 2 runs xfade on intermediate files with guaranteed clean timestamps. Compose time: ~8-12 min. Also added `trim+0.05s` buffer to avoid edge-case clip truncation.
- **v6.5** (2026-03-08): Quality improvements across all 3 AI nodes. generateImages: 20→30 steps, sampler `euler`→`dpmpp_2m`, scheduler `normal`→`karras`, cfg 7.0→7.5. animateImages: KSampler 15→20 steps, CRF 23→18. composeVideo: Lanczos upscaling (`flags=lanczos`), unsharp mask (`unsharp=luma_amount=0.8`), color grading (`eq=contrast=1.02:saturation=1.1`), encoder `-preset slow -crf 18`, audio 128k→192k. Runtime: 40-60 min → 55-75 min.
- **v6.4** (2026-03-08): Fixed jittery video — replaced frame duplication with `minterpolate=fps=30:mi_mode=mci` (motion-compensated interpolation) in composeVideo filter chain. Smooth slow-motion from 25 HunyuanVideo frames. Compose step now ~5-10 min (timeout raised to 600s). Also fixed animated WEBP decoding: replaced `SaveAnimatedWEBP` with `SaveImage` (individual PNG frames) in ComfyUI workflow — ffmpeg-static cannot decode animated WEBP (ANIM/ANMF chunks unsupported). animateImages now downloads all PNG frames and assembles to MP4 at 24fps.
- **v6.3** (2026-03-08): Fixed two composeVideo bugs found via Docker test: (1) `fps=30` moved after `trim+setpts` in FFmpeg filter chain — xfade requires constant frame rate input; (2) replaced `ffprobe` duration probe with `ffmpeg -i` + regex — `ffprobe` binary has wrong permissions in Docker (`node` user can't execute). Dockerfile updated with `chmod a+x` for both binaries (rebuild needed). All 3 AI nodes now tested end-to-end.
- **v6.2** (2026-03-08): Fixed HunyuanVideo I2V workflow structure — HunyuanImageToVideo is a conditioning node (outputs CONDITIONING+LATENT), requires separate KSampler. Added CLIPVisionEncode (crop=center), TextEncodeHunyuanVideo_ImageToVideo (image_interleave=2), negative CLIPTextEncode. Fixed model paths to use `split_files\\` subdirectory prefixes. Corrected HunyuanImageToVideo param names (`length` not `num_frames`, `start_image` not `image`). Updated animateImages n8n node to 12-node workflow. HunyuanVideo test confirmed working: ~211s (3.5 min) for 25 frames.
- **v6.1** (2026-03-07): Replaced FLUX NF4 with SDXL base 1.0 for images (~30s/image vs 2-5h in --lowvram). Reduced HunyuanVideo from 49→25 frames and 20→15 steps (~halves clip time). Runtime: 40-60 min. SDXL fits on 8GB VRAM without special flags. No new video model download needed.
- **v6.0** (2026-03-02): Local AI generation via ComfyUI. Replaced cloud image APIs with FLUX.1 Dev NF4 (768x1344, ~60s/image). Added HunyuanVideo I2V animation (544x960, 49 frames, ~7-12min/clip). Replaced FFmpeg Ken Burns with video clip stitching + slow-stretch. 16 nodes, 15 connections. Runtime: 75-115 min. $0.00/month (fully local).
- **v5.8** (2026-02-25): Fixed Pollinations.ai URL — migrated to `gen.pollinations.ai/image/` endpoint. API keys now hardcoded in Code node (n8n sandbox blocks env var access). Added provider tracking output. Reduced inter-image delay to 3s.
- **v5.7** (2026-02-25): Removed Together.ai (no longer free). Pollinations.ai → Pexels → FFmpeg gradient 3-provider stack.

## Commands

Run Docker commands from `D:\N8n` (the parent directory containing `docker-compose.yml`):

```bash
# n8n lifecycle
docker compose up -d                           # Start
docker compose down                            # Stop
docker compose build && docker compose up -d   # Rebuild (after Dockerfile/n8n version changes)
docker compose logs -f                         # View logs
docker compose restart                         # Restart without rebuild

# Health checks
curl -s http://localhost:5678/healthz           # n8n
curl http://localhost:8188/system_stats         # ComfyUI (run from Windows host, not Docker)

# Workflow management (via MCP tools in Claude)
# n8n_get_workflow      -- ID: zuFXklAfWmiZqTZh
# n8n_validate_workflow -- ID: zuFXklAfWmiZqTZh
# n8n_list_workflows
```
