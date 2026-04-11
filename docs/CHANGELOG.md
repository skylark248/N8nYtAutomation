# Changelog

All notable changes to the YouTube Shorts Tech News Automation workflow are recorded here.

---

## v8.4 — 2026-04-11

**10-day test prep. API key security, shorter scripts, duplicate detection.**

### Changed
- **pickStory**: Added 14-day duplicate detection via `/home/node/videos/last_stories.json`. 60% word-overlap check (words ≥4 chars). Top stories 6 → 3. Falls back to top 3 regardless if all are dupes (never blocks a run).
- **generateImages**: Renamed to "Generate Images (SD3/Flux)". Added explicit stderr log when falling back to fal.ai Flux: `"Stability credits N < 78 needed, using fal.ai Flux"`. Balance check confirmed atomic — all 6 images use same provider per run.
- **scriptGen**: Reads `geminiApiKey` directly from `keys.json` (no longer passed through node output → prevents API key leakage into execution logs). Word target 90-120 → **75-90 words**. Added `thinkingConfig: { thinkingBudget: 0 }` + `maxOutputTokens: 8192` (permanent fix for Gemini thinking model JSON truncation).
- **parseScript**: Min word count 80 → **65** (matches new shorter script target).
- **parseAgent**: Removed `geminiApiKey` from output entirely. Now only outputs `{ rawStory, timestamp }`.
- **composeVideo**: Removed burned `.ass` captions (YouTube auto-captions used instead). Added download retry logic: 3 attempts, 5s delay, HTTP status check, `r.on('error')` stream handling, 60s socket timeout. Exec timeout 180s → 300s.
- **generateMusic**: Exec timeout 120s → 300s (fal.ai Stable Audio generation takes ~70-90s at steps=100).

### Fixed
- Gemini API key no longer stored in n8n execution history
- Video length reduced from ~47s to ~38-42s (shorter script target)

---

## v8.3 — 2026-04-10

**Image and music provider switch. Stability AI as primary for images, fal.ai Stable Audio for music.**

### Changed
- **generateImages**: Stability AI SD3 as primary (balance check → base64 → data URIs). fal.ai Flux Schnell as fallback. SD3 returns base64 — converted to `data:image/jpeg;base64,...` data URIs. fal.ai Kling confirmed accepting data URIs as `image_url` directly.
- **generateMusic**: Switched from Stability AI Stable Audio (404, endpoint removed April 2026) to fal.ai Stable Audio (`fal.run/fal-ai/stable-audio`, JSON body `{prompt, seconds_total:45, steps:100}`, returns WAV, converts to MP3 via FFmpeg).
- **scriptGen**: Converted from HTTP Request node to Code node with sandbox escape (writes `.js` to `/tmp/`, executes via `exec('node script.js')`).
- **generateVideo**: Fixed polling URL — use `status_url`/`response_url` from fal.ai submit response.

### Fixed
- Stability AI audio endpoint 404 (removed by Stability AI)
- fal.ai polling 404 (wrong URL construction)

---

## v8.2 — 2026-04-08

**API key security and ElevenLabs output format fix. All 4 cloud endpoints verified.**

### Changed
- All API keys migrated from hardcoded node code to `keys.json` (mounted at `/home/node/keys.json:ro`)
- ElevenLabs output format `mp3_44100_192` → `mp3_44100_128` (192kbps requires Creator plan; Starter plan max is 128kbps)
- Stable Audio model: added `model: stable-audio-2.5` multipart field (newer model, flat 20 credits/gen)

### Verified
- All 4 cloud endpoints confirmed working: Gemini ✅ fal.ai Flux ✅ fal.ai Kling ✅ ElevenLabs ✅

---

## v8.1 — 2026-04-06

**Improved story selection and image prompts tied to HECK beats.**

### Changed
- **pickStory**: Scores and ranks all Reddit+HN posts by engagement (Reddit: score+comments×2; HN: points+comments×3; +300 per viral keyword hit from 30-keyword list)
- **parseAgent**: Repurposed to pass ranked list as `rawStory`
- **scriptGen**: Raised target to 90-120 words, added explicit viral story-selection criteria. Image prompts now tied to specific HECK beats (Hook/Explain×2/Climax×2/Kicker)
- **parseScript**: Validation tightened — min 80 words (was 70), min 3 tags added

---

## v8.0 — 2026-04-06

**Full cloud AI overhaul. No GPU required. Major cost and runtime change.**

### Added
- fal.ai Kling v1.6 I2V for video animation (6×5s clips, 9:16)
- ElevenLabs TTS for voiceover (MP3, Antoni voice — no PCM conversion needed)
- Stability AI Stable Audio for background music (45s, mixed at 28% volume)
- Burned-in SRT captions via FFmpeg `subtitles` filter
- HECK loop script structure (Hook-Explain-Climax-Kicker with seamless replay)

### Changed
- Replaced ComfyUI SDXL + HunyuanVideo with fal.ai Flux Schnell (images) + Kling I2V (video)
- Replaced Gemini TTS with ElevenLabs TTS
- 17 → 19 nodes (added music, Instagram Reels upload)

### Removed
- ComfyUI dependency (SDXL, HunyuanVideo) — no local GPU required
- Gemini TTS PCM-to-WAV conversion step

### Stats
- Cost: $0.00/video → ~$1.47/video ($0.09 images + $2.10 video + $0.17 voice + $0.37 music)
- Monthly (30 Shorts): ~$44/month
- Runtime: 80-110 min → 35-70 min

---

## v7.2 — 2026-03-28

**Added local video export after compose step.**

### Added
- `exportLocal` node (17 nodes total): saves `video.mp4` + `upload-info.txt` to `videos/{timestamp}_{title}/` on Windows host after each run
- Requires volume mount in `D:\N8n\docker-compose.yml`

---

## v7.1 — 2026-03-28

**Removed Instagram Reels cross-posting and Schedule Trigger.**

### Removed
- Instagram Reels cross-posting (Facebook Graph API upload)
- Schedule Trigger

### Changed
- Back to 16 nodes, manual trigger only, YouTube-only pipeline

---

## v7.0 — 2026-03-14

**Added Instagram Reels cross-posting. *(Reverted in v7.1)***

### Added
- Instagram Reels posting via Facebook Resumable Upload API + Graph API
- Schedule Trigger (4×/week: Mon/Wed/Fri/Sun)
- 16 → 26 nodes

---

## v6.9 — 2026-03-09 ✅ Confirmed Working End-to-End

### Changed
- **scriptGen model**: Updated to `gemini-3-flash-preview` (Gemini 3 Flash). Script generation now uses the latest Gemini 3 model.
- **TTS model**: Stays on `gemini-2.5-flash-preview-tts` (unchanged).

### Fixed
- Restored full HTTP Request node parameters after accidental parameter stripping during update.

---

## v6.8 — 2026-03-09

### Changed
- **`N8N_RUNNERS_TASK_TIMEOUT`**: Raised from 7200s (120 min) to 9000s (150 min) in `docker-compose.yml`.
- **animateImages `GLOBAL_BUDGET_MS`**: Raised from 6,000,000ms (100 min) to 9,000,000ms (150 min).
- **animateImages exec timeout**: Raised from 6,600,000ms to 9,600,000ms (160 min).
- Script length target kept at 110-120 words (~45s narration).

---

## v6.7 — 2026-03-09

### Changed
- **HunyuanVideo frames**: 25 → 49 frames per clip (2.04s clips). Slowdown ratio drops from 4.5× to ~2.9×, producing much smoother slow-motion.
- **Script length**: 80-95 words → 110-120 words (~45s narration at 155 wpm).
- **Word count validation**: `parseScript` now throws if script < 90 words.
- **Poll timeout per clip**: 1200s → 1800s in `animateImages`.

### Fixed
- `successOutput` bug: Was reading playlist `id` field (base64 garbage) as video ID. Now reads `contentDetails.videoId`.

---

## v6.6 — 2026-03-09

### Fixed
- **minterpolate + xfade incompatibility**: `minterpolate` was running on ~6fps input (after 4× `setpts` slowdown), causing corrupted PTS and broken xfade (hard cuts, short video).
- **Two-pass compose**:
  - Pass 1: `minterpolate=fps=60` at native 24fps per clip → saves to intermediate `.mp4` (resets PTS).
  - Pass 2: `xfade` on clean intermediate files → smooth crossfades.
- Added `trim+0.05s` buffer to avoid edge-case clip truncation.

### Performance
- Compose step: ~8-12 min total.

---

## v6.5 — 2026-03-08

### Changed – Quality improvements across all AI nodes
- **generateImages**: 20 → 30 steps; sampler `euler` → `dpmpp_2m`; scheduler `normal` → `karras`; cfg 7.0 → 7.5. Each image ~35-45s (up from ~25-30s).
- **animateImages**: KSampler 15 → 20 steps, CRF 23 → 18.
- **composeVideo**: Lanczos upscaling, unsharp mask, color grading (`eq=contrast=1.02:saturation=1.1`), encoder `-preset slow -crf 18`, audio 128k → 192kbps.

### Performance
- Runtime: 40-60 min → 55-75 min.

---

## v6.4 — 2026-03-08

### Fixed
- **Jittery slow-motion**: Replaced frame duplication with `minterpolate=fps=30:mi_mode=mci` (motion-compensated interpolation).
- **Animated WEBP not decodable**: `ffmpeg-static` skips `ANIM`/`ANMF` chunks. Fixed by replacing `SaveAnimatedWEBP` with `SaveImage` (individual PNG frames) in the ComfyUI workflow. `animateImages` now downloads all PNG frames and assembles to MP4 at 24fps.

### Changed
- Compose step timeout raised to 600s (~10 min).

---

## v6.3 — 2026-03-08

### Fixed
- **FFmpeg filter chain**: `fps=30` moved to AFTER `trim+setpts` — xfade requires constant frame rate input.
- **`ffprobe` permission denied in Docker**: Binary installs as `-rwxr--r--`. Replaced `ffprobe` duration probe with `ffmpeg -i` + regex parse. Dockerfile updated with `chmod a+x` (rebuild required).

---

## v6.2 — 2026-03-08

### Fixed – HunyuanVideo I2V workflow structure
- `HunyuanImageToVideo` is a **conditioning node** (not a sampler) — outputs `CONDITIONING + LATENT`. Added separate `KSampler` node.
- Added `CLIPVisionEncode` (`crop: center`), `TextEncodeHunyuanVideo_ImageToVideo` (`image_interleave: 2`), negative `CLIPTextEncode`.
- Fixed model paths: `split_files\\` subdirectory prefixes required.
- Fixed param names: `length` (not `num_frames`), `start_image` (not `image`).
- HunyuanVideo test confirmed working: ~211s (3.5 min) for 25 frames.

---

## v6.1 — 2026-03-07

### Changed
- **Image generation**: Replaced FLUX.1 Dev NF4 with **SDXL base 1.0** (~30s/image vs 2-5h in `--lowvram`). SDXL fits on 8GB VRAM without special flags.
- **HunyuanVideo**: Reduced frames 49 → 25, KSampler steps 20 → 15 (~halves clip time).

### Performance
- Runtime: 40-60 min. No new model download needed.

---

## v6.0 — 2026-03-02

### Added – Fully local AI generation via ComfyUI
- **Generate Images (ComfyUI FLUX)**: FLUX.1 Dev NF4 text-to-image (768×1344, ~60s/image).
- **Animate Images (ComfyUI Hunyuan)**: HunyuanVideo I2V Q4 GGUF image-to-video (544×960, 49 frames, ~7-12min/clip).
- Docker `extra_hosts: host.docker.internal:host-gateway` for n8n → ComfyUI connectivity.
- Custom Dockerfile with FFmpeg baked in via `npm -g ffmpeg-static`.

### Changed
- **composeVideo**: Replaced FFmpeg Ken Burns zoom/pan with video clip stitching + slow-stretch.
- **Timeout**: Docker task runner raised to 2 hours.

### Stats
- 16 nodes, 15 connections. Runtime: 75-115 min. **$0.00/month** (fully local).

---

## v5.8 — 2026-02-25

### Fixed
- Pollinations.ai URL: Migrated from `image.pollinations.ai/prompt/` (down since Feb 13) to `gen.pollinations.ai/image/`.
- API keys hardcoded in Code node (n8n sandbox blocks `process.env` access).

### Changed
- Inter-image delay reduced from 5s to 3s.
- Added `providers`/`providerSummary` tracking output.

---

## v5.7 — 2026-02-25

### Changed
- Removed Together.ai (no longer free).
- 3-provider stack: Pollinations.ai (primary) → Pexels stock photos → FFmpeg gradient.

---

## v5.6 — 2026-02-25

### Added
- 4-provider image fallback: Together.ai → Pollinations.ai (secret key) → Pexels → FFmpeg gradient.
- Global 780s time budget prevents timeout.

---

## v5.5 — 2026-02-24

### Fixed
- Gemini returning wrong JSON format (`STORY_TITLE`/`KEY_FACTS` instead of `SCRIPT`/`TITLE`/`IMAGE_PROMPTS`).
- Removed conflicting format instructions from Pick Best Story prompt.
- Added system instruction to Generate Script enforcing exact output keys.

---

## v5.4 — 2026-02-24

### Fixed
- Pollinations.ai rate limiting (6/8 images falling back to gradient). Increased delays and retries.

### Changed
- Added `N8N_RUNNERS_HEARTBEAT_INTERVAL=300` to prevent FFmpeg render kill.

---

## v5.3 — 2026-02-24

### Fixed
- FFmpeg gradient fallback: Unescaped double quotes in filter syntax.

### Added
- Auto-retry on Generate Script node (3 attempts, 5s delay) for transient Gemini 503 errors.

---

## v5.2 — 2026-02-23

### Added
- **Robust `parseScript`**: `findScriptData()` recursively searches for `SCRIPT` field up to 2 levels deep. Handles flat, wrapped (`YOUTUBE_SHORT`), and nested (`story_analysis` + `youtube_short_script`) Gemini response formats. Case-insensitive key matching.

---

## v5.1 — 2026-02-23

### Changed
- Triple-provider image fallback: Pollinations.ai → HuggingFace FLUX.1 → FFmpeg gradient.
- Task runner timeout increased to 900s.

---

## v5.0 — 2026-02-23

### Changed
- **Script generation**: Gemini 2.0 Flash → Gemini 2.5 Flash (5 RPM free tier).
- **Image generation**: Gemini (0 free quota) → HuggingFace Spaces FLUX.1 (free, no API key).
- Merged Split Image Prompts + Generate Images + Collect All Images into single Code node.

### Stats
- 15 nodes, 14 connections. $0.00/video.

---

## v4.0 — 2026-02-16

### Changed – Migrated to completely free stack
- Script: OpenAI GPT-4o → Gemini 2.0 Flash
- Images: DALL-E 3 → Gemini 2.5 Flash Image
- TTS: OpenAI TTS → Gemini 2.5 Flash TTS
- Video: Creatomate (paid) → local FFmpeg Ken Burns effect
- 8 images instead of 4.

### Stats
- 17 nodes, 16 connections. **$0.00/video**.

---

## v3.1 — 2026-02-09

### Added
- **Add to Playlist** node: Videos automatically added to a YouTube playlist after upload.

### Stats
- 24 nodes, 23 connections.

---

## v3.0 — 2026-02-09

### Added
- Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs).

### Changed
- Split video data prep into 3 lightweight nodes to avoid OOM.
- Privacy set to public.

### Stats
- 23 nodes, 22 connections.

---

## v2.0 — 2026-02-08

### Changed
- Replaced AI Agent with direct HTTP fetches.
- DALL-E via HTTP Request for URL output.
- Added render validation.

### Stats
- 21 nodes.

---

## v1.0 — 2026-02-07

### Initial release
- 18 nodes, manual trigger, Creatomate free tier.
- OpenAI GPT-4o script + DALL-E 3 images + OpenAI TTS.
- YouTube upload via OAuth2.
