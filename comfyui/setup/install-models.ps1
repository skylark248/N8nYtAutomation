# ComfyUI Model Download Script for YouTube Shorts Automation
# Requires: hf CLI (pip install huggingface-hub) OR manual download
#
# Total download size: ~31GB
# Models: FLUX.1 Dev NF4, T5-XXL FP8, CLIP-L, FLUX VAE, HunyuanVideo I2V Q4, LLaVA CLIP, HunyuanVideo VAE

$ComfyUIPath = "C:\ComfyUI\ComfyUI"

if (-not (Test-Path $ComfyUIPath)) {
    Write-Error "ComfyUI not found at $ComfyUIPath. Install ComfyUI first."
    exit 1
}

Write-Host "=== FLUX.1 Dev NF4 (Image Generation) ===" -ForegroundColor Cyan

# FLUX.1 Dev NF4 checkpoint (~12GB)
Write-Host "Downloading flux1-dev-bnb-nf4-v2.safetensors (~12GB)..."
hf download lllyasviel/flux1-dev-bnb-nf4 flux1-dev-bnb-nf4-v2.safetensors `
    --local-dir "$ComfyUIPath\models\checkpoints"

# T5-XXL FP8 text encoder (~5GB)
Write-Host "Downloading t5xxl_fp8_e4m3fn.safetensors (~5GB)..."
hf download comfyanonymous/flux_text_encoders t5xxl_fp8_e4m3fn.safetensors `
    --local-dir "$ComfyUIPath\models\clip"

# CLIP-L text encoder (~235MB) - shared between FLUX and HunyuanVideo
Write-Host "Downloading clip_l.safetensors (~235MB)..."
hf download comfyanonymous/flux_text_encoders clip_l.safetensors `
    --local-dir "$ComfyUIPath\models\clip"

# FLUX VAE (~335MB)
Write-Host "Downloading ae.safetensors (~335MB)..."
hf download black-forest-labs/FLUX.1-dev ae.safetensors `
    --local-dir "$ComfyUIPath\models\vae"

Write-Host ""
Write-Host "=== HunyuanVideo I2V Q4 GGUF (Video Generation) ===" -ForegroundColor Cyan

# HunyuanVideo I2V Q4 GGUF (~6.8GB)
Write-Host "Downloading hunyuan-video-i2v-720p-Q4_K_M.gguf (~6.8GB)..."
hf download city96/HunyuanVideo-I2V-gguf hunyuan-video-i2v-720p-Q4_K_M.gguf `
    --local-dir "$ComfyUIPath\models\unet"

# LLaVA LLaMA3 FP8 CLIP (~5GB)
Write-Host "Downloading llava_llama3_fp8_scaled.safetensors (~5GB)..."
hf download Comfy-Org/HunyuanVideo_repackaged split_files/text_encoder/llava_llama3_fp8_scaled.safetensors `
    --local-dir "$ComfyUIPath\models\clip"

# LLaVA LLaMA3 Vision encoder (~1.2GB)
Write-Host "Downloading llava_llama3_vision.safetensors (~1.2GB)..."
hf download Comfy-Org/HunyuanVideo_repackaged split_files/clip_vision/llava_llama3_vision.safetensors `
    --local-dir "$ComfyUIPath\models\clip_vision"

# HunyuanVideo VAE (~222MB)
Write-Host "Downloading hunyuan_video_vae_bf16.safetensors (~222MB)..."
hf download Comfy-Org/HunyuanVideo_repackaged split_files/vae/hunyuan_video_vae_bf16.safetensors `
    --local-dir "$ComfyUIPath\models\vae"

Write-Host ""
Write-Host "=== All models downloaded! ===" -ForegroundColor Green
Write-Host "Total: ~31GB across checkpoints, clip, clip_vision, unet, and vae folders"
Write-Host ""
Write-Host "Verify by checking these directories:"
Write-Host "  $ComfyUIPath\models\checkpoints\"
Write-Host "  $ComfyUIPath\models\clip\"
Write-Host "  $ComfyUIPath\models\clip_vision\"
Write-Host "  $ComfyUIPath\models\unet\"
Write-Host "  $ComfyUIPath\models\vae\"
