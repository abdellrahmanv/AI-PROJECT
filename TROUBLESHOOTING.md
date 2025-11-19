# Troubleshooting Guide

## Missing Source Files Error

If `verify.sh` shows:
```
[ERROR] src/run_yolov8.py not found
[ERROR] src/run_yolov11.py not found
```

**Solution:**
```bash
cd ~/AI-PROJECT
git pull origin main
```

This downloads all the source files from GitHub.

---

## Camera Issues on Raspberry Pi

### Verify Camera is Connected
```bash
# For newer Raspberry Pi OS (libcamera/rpicam):
rpicam-hello --list-cameras

# For legacy camera:
vcgencmd get_camera
```

### Enable Camera
```bash
sudo raspi-config
# Navigate to: Interface Options > Camera > Enable
# Reboot: sudo reboot
```

### Test Camera with Benchmark
The scripts automatically try multiple backends:
1. V4L2 (Video4Linux2) - for libcamera
2. CAP_ANY - fallback
3. Default - last resort

---

## Model Download Issues

### Manual Download
If automatic download fails:

```bash
cd ~/AI-PROJECT

# Download PyTorch models
wget https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt -O models/yolov8n.pt
wget https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt -O models/yolo11n.pt

# Export to ONNX
source venv/bin/activate
python3 -c "from ultralytics import YOLO; YOLO('models/yolov8n.pt').export(format='onnx', simplify=True)"
python3 -c "from ultralytics import YOLO; YOLO('models/yolo11n.pt').export(format='onnx', simplify=True)"

# Move exported files
mv yolov8n.onnx models/
mv yolo11n.onnx models/
```

---

## Virtual Environment Issues

### Activate Manually
```bash
cd ~/AI-PROJECT
source venv/bin/activate
```

### Recreate if Broken
```bash
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements_installed.txt
```

---

## Import Errors

### OpenCV Not Found
```bash
source venv/bin/activate
pip uninstall opencv-python opencv-python-headless
pip install opencv-python-headless
```

### ONNX Runtime Issues
```bash
source venv/bin/activate
pip install onnxruntime --upgrade
```

---

## Permission Errors

### Camera Access Denied
```bash
# Add user to video group
sudo usermod -a -G video $USER

# Logout and login again for changes to take effect
```

### Cannot Write Logs
```bash
# Fix permissions
chmod -R u+w ~/AI-PROJECT/logs/
```

---

## Performance Issues

### Check Throttling
```bash
vcgencmd get_throttled
# 0x0 = no throttling (good)
# 0x50000 or 0x50005 = throttled (bad)
```

### Monitor Temperature
```bash
vcgencmd measure_temp
# Should be < 80°C
```

### Improve Cooling
- Add heatsinks to CPU
- Use a fan
- Ensure good airflow
- Reduce `duration` in benchmarks

---

## Quick Fixes

### Full Reset
```bash
cd ~/AI-PROJECT
git reset --hard origin/main
git pull origin main
bash setup/setup.sh
```

### Quick Verification
```bash
cd ~/AI-PROJECT
source venv/bin/activate
python3 -c "import cv2, onnxruntime, psutil, numpy; print('OK')"
```

### Test Camera Quickly
```bash
cd ~/AI-PROJECT
bash setup/camera_setup.sh
```
