# Changelog

All notable changes to the YouTube Shorts Tech News Automation workflow are recorded here.

---

## [v6.9] – 2026-03-09 ✅ Confirmed Working End-to-End

### Changed
- **scriptGen model**: Updated to `gemini-3-flash-preview` (Gemini 3 Flash). Script generation now uses the latest Gemini 3 model.
- **TTS model**: Stays on `gemini-2.5-flash-preview-tts` (unchanged).

### Fixed
- Restored full HTTP Request node parameters after accidental parameter stripping during update.

---

## [v6.8] – 2026-03-09

### Changed
- **`N8N_RUNNERS_TASK_TIMEOUT`**: Raised from 7200s (120 min) to 9000s (150 min) in `docker-compose.yml`.
- **animateImages `GLOBAL_BUDGET_MS`**: Raised from 6 000 000 ms (100 min) to 9 000 000 ms (150 min).
- **animateImages exec timeout**: Raised from 6 600 000 ms to 9 600 000 ms (160 min).
- Script length target kept at 110–120 words (~45 s narration).

---

## [v6.7] – 2026-03-09

### Changed
- **HunyuanVideo frames**: 25 → 49 frames per clip (2.04 s clips). Slowdown ratio drops from 4.5× to ~2.9×, producing much smoother slow-motion.
- **Script length**: 80–95 words → 110–120 words (~45 s narration at 155 wpm).
- **Word count validation**: `parseScript` now throws if script < 90 words.
- **Poll timeout per clip**: 1 200 s → 1 800 s in `animateImages`.

### Fixed
- `successOutput` bug: Was reading playlist `id` field (base64 garbage) as video ID. Now reads `contentDetails.videoId`.

---

## [v6.6] – 2026-03-09

### Fixed
- **minterpolate + xfade incompatibility**: `minterpolate` was running on ~6 fps input (after 4× `setpts` slowdown), causing corrupted PTS and broken xfade (hard cuts, short video).
- **Two-pass compose**:
  - Pass 1: `minterpolate=fps=60` at native 24 fps per clip → saves to intermediate `.mp4` (resets PTS).
  - Pass 2: `xfade` on clean intermediate files → smooth crossfades.
- Added `trim+0.05 s` buffer to avoid edge-case clip truncation.

### Performance
- Compose step: ~8–12 min total.

---

## [v6.5] – 2026-03-08

### Changed – Quality improvements across all AI nodes
- **generateImages**: 20 → 30 steps; sampler `euler` → `dpmpp_2m`; scheduler `normal` → `karras`; cfg 7.0 → 7.5. Each image ~35–45 s (up from ~25–30 s).
- **animateImages**: KSampler 15 → 20 steps.
- **composeVideo**: Lanczos upscaling, unsharp mask, color grading (`eq=contrast=1.02:saturation=1.1`), encoder `-preset slow -crf 18`, audio 128 k → 192 kbps.

### Performance
- Runtime: 40–60 min → 55–75 min.

---

## [v6.4] – 2026-03-08

### Fixed
- **Jittery slow-motion**: Replaced frame duplication with `minterpolate=fps=30:mi_mode=mci` (motion-compensated interpolation).
- **Animated WEBP not decodable**: `ffmpeg-static` (johnvansickle) skips `ANIM`/`ANMF` chunks. Fixed by replacing `SaveAnimatedWEBP` with `SaveImage` (individual PNG frames) in the ComfyUI workflow. `animateImages` now downloads all PNG frames and assembles to MP4 at 24 fps.

### Changed
- Compose step timeout raised to 600 s (~10 min).

---

## [v6.3] – 2026-03-08

### Fixed
- **FFmpeg filter chain**: `fps=30` moved to AFTER `trim+setpts` — xfade requires constant frame rate input.
- **`ffprobe` permission denied in Docker**: Binary installs as `-rwxr--r--`. Replaced `ffprobe` duration probe with `ffmpeg -i` + regex parse. Dockerfile updated with `chmod a+x` (rebuild required).

---

## [v6.2] – 2026-03-08

### Fixed – HunyuanVideo I2V workflow structure
- `HunyuanImageToVideo` is a **conditioning node** (not a sampler) — outputs `CONDITIONING + LATENT`. Added separate `KSampler` node.
- Added `CLIPVisionEncode` (`crop: center`), `TextEncodeHunyuanVideo_ImageToVideo` (`image_interleave: 2`), negative `CLIPTextEncode`.
- Fixed model paths: `split_files\\` subdirectory prefixes required.
- Fixed param names: `length` (not `num_frames`), `start_image` (not `image`).
- HunyuanVideo test confirmed working: ~211 s (3.5 min) for 25 frames.

---

## [v6.1] – 2026-03-07

### Changed
- **Image generation**: Replaced FLUX.1 Dev NF4 with **SDXL base 1.0** (~30 s/image vs 2–5 h in `--lowvram`). SDXL fits on 8 GB VRAM without special flags.
- **HunyuanVideo**: Reduced frames 49 → 25, KSampler steps 20 → 15 (~halves clip time).

### Performance
- Runtime: 40–60 min. No new model download needed.

---

## [v6.0] – 2026-03-02

### Added – Fully local AI generation via ComfyUI
- **Generate Images (ComfyUI FLUX)**: FLUX.1 Dev NF4 text-to-image (768×1344, ~60 s/image).
- **Animate Images (ComfyUI Hunyuan)**: HunyuanVideo I2V Q4 GGUF image-to-video (544×960, 49 frames, ~7–12 min/clip).
- Docker `extra_hosts: host.docker.internal:host-gateway` for n8n → ComfyUI connectivity.
- Custom Dockerfile with FFmpeg baked in via `npm -g ffmpeg-static`.

### Changed
- **composeVideo**: Replaced FFmpeg Ken Burns zoom/pan with video clip stitching + slow-stretch.
- **Timeout**: Docker task runner raised to 2 hours.

### Stats
- 16 nodes, 15 connections. Runtime: 75–115 min. **$0.00/month** (fully local).

---

## [v5.8] – 2026-02-25

### Fixed
- Pollinations.ai URL: Migrated from `image.pollinations.ai/prompt/` (down since Feb 13) to `gen.pollinations.ai/image/`.
- API keys hardcoded in Code node (n8n sandbox blocks `process.env` access).

### Changed
- Inter-image delay reduced from 5 s to 3 s.
- Added `providers`/`providerSummary` tracking output.

---

## [v5.7] – 2026-02-25

### Changed
- Removed Together.ai (no longer free).
- 3-provider stack: Pollinations.ai (primary) → Pexels stock photos → FFmpeg gradient.

---

## [v5.6] – 2026-02-25

### Added
- 4-provider image fallback: Together.ai → Pollinations.ai (secret key) → Pexels → FFmpeg gradient.
- Global 780 s time budget prevents timeout.

---

## [v5.5] – 2026-02-24

### Fixed
- Gemini returning wrong JSON format (`STORY_TITLE`/`KEY_FACTS` instead of `SCRIPT`/`TITLE`/`IMAGE_PROMPTS`).
- Removed conflicting format instructions from Pick Best Story prompt.
- Added system instruction to Generate Script enforcing exact output keys.

---

## [v5.4] – 2026-02-24

### Fixed
- Pollinations.ai rate limiting (6/8 images falling back to gradient). Increased delays and retries.

### Changed
- Added `N8N_RUNNERS_HEARTBEAT_INTERVAL=300` to prevent FFmpeg render kill.

---

## [v5.3] – 2026-02-24

### Fixed
- FFmpeg gradient fallback: Unescaped double quotes in filter syntax.

### Added
- Auto-retry on Generate Script node (3 attempts, 5 s delay) for transient Gemini 503 errors.

---

## [v5.2] – 2026-02-23

### Added
- **Robust `parseScript`**: `findScriptData()` recursively searches for `SCRIPT` field up to 2 levels deep. Handles flat, wrapped (`YOUTUBE_SHORT`), and nested (`story_analysis` + `youtube_short_script`) Gemini response formats. Case-insensitive key matching.

---

## [v5.1] – 2026-02-23

### Changed
- Triple-provider image fallback: Pollinations.ai → HuggingFace FLUX.1 → FFmpeg gradient.
- Task runner timeout increased to 900 s.

---

## [v5.0] – 2026-02-23

### Changed
- **Script generation**: Gemini 2.0 Flash → Gemini 2.5 Flash (5 RPM free tier).
- **Image generation**: Gemini (0 free quota) → HuggingFace Spaces FLUX.1 (free, no API key).
- Merged Split Image Prompts + Generate Images + Collect All Images into single Code node.

### Stats
- 15 nodes, 14 connections. $0.00/video.

---

## [v4.0] – 2026-02-16

### Changed – Migrated to completely free stack
- Script: OpenAI GPT-5 → Gemini 2.0 Flash
- Images: DALL-E 3 → Gemini 2.5 Flash Image
- TTS: OpenAI TTS → Gemini 2.5 Flash TTS
- Video: Creatomate (paid) → local FFmpeg Ken Burns effect
- 8 images instead of 4.

### Stats
- 17 nodes, 16 connections. **$0.00/video**.

---

## [v3.1] – 2026-02-09

### Added
- **Add to Playlist** node: Videos are automatically added to a YouTube playlist after upload.

### Stats
- 24 nodes, 23 connections.

---

## [v3.0] – 2026-02-09

### Added
- Audio upload via tmpfiles.org (Creatomate requires real URLs, not data URIs).

### Changed
- Split video data prep into 3 lightweight nodes to avoid OOM.
- Privacy set to public.

### Stats
- 23 nodes, 22 connections.

---

## [v2.0] – 2026-02-08

### Changed
- Replaced AI Agent with direct HTTP fetches.
- DALL-E via HTTP Request for URL output.
- Added render validation.

### Stats
- 21 nodes.

---

## [v1.0] – 2026-02-07

### Initial release
- 18 nodes, manual trigger, Creatomate free tier.
- OpenAI GPT-5 script + DALL-E 3 images + OpenAI TTS.
- YouTube upload via OAuth2.
