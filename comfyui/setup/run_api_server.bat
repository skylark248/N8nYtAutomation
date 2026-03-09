@echo off
echo Starting ComfyUI API Server...
echo Listening on 0.0.0.0:8188 (accessible from Docker containers)
echo Press Ctrl+C to stop.
echo.
cd /d C:\ComfyUI
.\python_embeded\python.exe -s ComfyUI\main.py --listen 0.0.0.0 --port 8188 --preview-method auto --gpu-only
pause
