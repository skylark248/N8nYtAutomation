# ComfyUI Custom Node Installation Script
# Installs required custom nodes for FLUX.1 NF4 + HunyuanVideo I2V GGUF

$ComfyUIPath = "C:\ComfyUI\ComfyUI"
$CustomNodesPath = "$ComfyUIPath\custom_nodes"
$PythonPath = "C:\ComfyUI\python_embeded\python.exe"

if (-not (Test-Path $ComfyUIPath)) {
    Write-Error "ComfyUI not found at $ComfyUIPath. Install ComfyUI first."
    exit 1
}

Write-Host "=== Installing Custom Nodes ===" -ForegroundColor Cyan

# ComfyUI_bitsandbytes_NF4 - Required for loading FLUX.1 NF4 checkpoints
Write-Host "Installing ComfyUI_bitsandbytes_NF4..."
if (-not (Test-Path "$CustomNodesPath\ComfyUI_bitsandbytes_NF4")) {
    git clone https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git "$CustomNodesPath\ComfyUI_bitsandbytes_NF4"
} else {
    Write-Host "  Already exists, pulling latest..."
    git -C "$CustomNodesPath\ComfyUI_bitsandbytes_NF4" pull
}
if (Test-Path "$CustomNodesPath\ComfyUI_bitsandbytes_NF4\requirements.txt") {
    & $PythonPath -m pip install -r "$CustomNodesPath\ComfyUI_bitsandbytes_NF4\requirements.txt"
}

# ComfyUI-GGUF - Required for loading HunyuanVideo I2V GGUF models
Write-Host "Installing ComfyUI-GGUF..."
if (-not (Test-Path "$CustomNodesPath\ComfyUI-GGUF")) {
    git clone https://github.com/city96/ComfyUI-GGUF.git "$CustomNodesPath\ComfyUI-GGUF"
} else {
    Write-Host "  Already exists, pulling latest..."
    git -C "$CustomNodesPath\ComfyUI-GGUF" pull
}
if (Test-Path "$CustomNodesPath\ComfyUI-GGUF\requirements.txt") {
    & $PythonPath -m pip install -r "$CustomNodesPath\ComfyUI-GGUF\requirements.txt"
}

Write-Host ""
Write-Host "=== Custom nodes installed! ===" -ForegroundColor Green
Write-Host "Restart ComfyUI for changes to take effect."
