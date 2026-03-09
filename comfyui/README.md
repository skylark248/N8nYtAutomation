# ComfyUI Setup for YouTube Shorts Automation

Local AI image and video generation using SDXL base 1.0 + HunyuanVideo I2V on RTX 3070 Ti (8GB VRAM).

## Prerequisites

- Windows 10/11 with NVIDIA GPU (RTX 3070 Ti or similar with 8GB+ VRAM)
- NVIDIA drivers updated (Game Ready or Studio)
- ~25GB free disk space (ComfyUI + models)
- Git installed

## Quick Setup

### 1. Install ComfyUI

Download `ComfyUI_windows_portable_nvidia.7z` from [ComfyUI releases](https://github.com/Comfy-Org/ComfyUI/releases) and extract to `C:\ComfyUI`.

### 2. Install Custom Nodes

```powershell
.\setup\install-custom-nodes.ps1
```

Or manually:
```bash
cd C:\ComfyUI\ComfyUI\custom_nodes
# GGUF loader — required for HunyuanVideo I2V
git clone https://github.com/city96/ComfyUI-GGUF.git
```

### 3. Download Models (~24GB)

```powershell
# Requires: pip install huggingface-hub
.\setup\install-models.ps1
```

Or download manually from HuggingFace (see script for URLs and target folders).

### 4. Start ComfyUI API Server

```batch
.\setup\run_api_server.bat
```

This starts ComfyUI listening on `0.0.0.0:8188` so Docker containers can reach it.

### 5. Windows Firewall

Allow Docker to reach ComfyUI:
```powershell
New-NetFirewallRule -DisplayName "ComfyUI API" -Direction Inbound -Protocol TCP -LocalPort 8188 -Action Allow
```

### 6. Verify

```bash
curl http://localhost:8188/system_stats
```

Should return JSON with GPU info.

## Models Reference

| Model | File | Size | Folder |
|-------|------|------|--------|
| SDXL base 1.0 | `sd_xl_base_1.0.safetensors` | ~6.5GB | `checkpoints/` |
| CLIP-L | `clip_l.safetensors` | ~235MB | `clip/` |
| HunyuanVideo I2V Q4 | `hunyuan-video-i2v-720p-Q4_K_M.gguf` | ~6.8GB | `unet/` |
| LLaVA LLaMA3 FP8 | `llava_llama3_fp8_scaled.safetensors` | ~5GB | `clip/split_files/text_encoder/` |
| LLaVA Vision | `llava_llama3_vision.safetensors` | ~1.2GB | `clip_vision/split_files/clip_vision/` |
| HunyuanVideo VAE | `hunyuan_video_vae_bf16.safetensors` | ~222MB | `vae/split_files/vae/` |

> **Legacy**: `flux-nf4-text-to-image.json` workflow template is kept for reference but the n8n pipeline uses SDXL base 1.0. If you want to use FLUX.1 Dev NF4 (~12GB), also install `ComfyUI_bitsandbytes_NF4` custom node and download `flux1-dev-bnb-nf4-v2.safetensors`.

## VRAM Budget (RTX 3070 Ti 8GB)

| Phase | Peak VRAM | Notes |
|-------|-----------|-------|
| SDXL base 1.0 image gen | ~5-6 GB | Fits comfortably on 8GB VRAM without special flags |
| HunyuanVideo I2V | ~7-8 GB | GGUF offloads weights to 32GB system RAM |

Models are loaded/unloaded sequentially — they cannot coexist in VRAM. ComfyUI handles the swap automatically (~30-60s between phases).

## Workflow Templates

- `workflows/sdxl-text-to-image.json` — SDXL base 1.0 text-to-image (768x1344) — reference only; n8n builds the workflow inline
- `workflows/hunyuan-i2v-gguf-q4.json` — HunyuanVideo I2V image-to-video (544x960, 49 frames) — reference only; n8n builds the workflow inline
- `workflows/flux-nf4-text-to-image.json` — FLUX.1 Dev NF4 text-to-image — legacy, kept for reference

These are in ComfyUI API format. The n8n Code nodes build the workflow JSON inline and POST to the ComfyUI `/prompt` endpoint.

## Troubleshooting

**OOM on SDXL**: Close other GPU applications. SDXL needs ~5-6GB VRAM. Make sure no other models are loaded in ComfyUI.

**OOM on HunyuanVideo**: Reduce `temporal_size` from 32 to 16 in the workflow template, or reduce frames from 49 to 33.

**ComfyUI not reachable from Docker**: Verify firewall rule exists and ComfyUI is started with `--listen 0.0.0.0`. Test with `curl http://host.docker.internal:8188/system_stats` from inside the Docker container.

**Slow first generation**: Normal — ComfyUI loads models into VRAM on first use. Subsequent generations are faster.

**`mat1 and mat2 shapes cannot be multiplied`** (FLUX NF4 only): NF4 model detection bug in `model_detection.py`. See the `comfyui-nf4-debugging` Claude skill for the exact patch.
