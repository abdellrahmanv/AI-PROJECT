# YOLO Benchmark for Raspberry Pi 4B

**Rewritten based on official Ultralytics documentation**

Compare YOLOv8n vs YOLO11n performance on Raspberry Pi 4B using the official Ultralytics library.

## What Changed

The previous version had several critical issues:
- ❌ Used ONNX Runtime manually (slower, more complex)
- ❌ Incorrect model download URLs
- ❌ Manual ONNX preprocessing (error-prone)
- ❌ Camera compatibility issues
- ❌ NumPy version conflicts

The new version:
- ✅ Uses official Ultralytics library
- ✅ Supports NCNN format (2x faster than ONNX on Pi!)
- ✅ Proper picamera2 integration
- ✅ Automatic model download
- ✅ Compatible numpy versions
- ✅ Simpler, cleaner code

## Quick Start

### 1. Clone Repository
```bash
cd ~
git clone https://github.com/abdellrahmanv/AI-PROJECT.git
cd AI-PROJECT
```

### 2. Run Setup
```bash
chmod +x setup/setup_new.sh
./setup/setup_new.sh
```

This will:
- Install system dependencies
- Create Python virtual environment
- Install ultralytics with export support
- Download YOLOv8n and YOLO11n models
- Export models to NCNN format (fastest for Pi)
- Setup camera support

### 3. Run Benchmarks

Activate virtual environment:
```bash
source venv/bin/activate
```

**Camera benchmark (60 seconds) - PyTorch format:**
```bash
python3 src/run_yolov8_new.py --duration 60
python3 src/run_yolo11_new.py --duration 60
```

**Camera benchmark - NCNN format (fastest):**
```bash
python3 src/run_yolov8_new.py --duration 60 --format ncnn
python3 src/run_yolo11_new.py --duration 60 --format ncnn
```

**Image benchmark:**
```bash
python3 src/run_yolov8_new.py --image test.jpg --iterations 100 --format ncnn
```

### 4. Compare Results
```bash
python3 src/compare_results.py --auto
```

## Model Formats

The setup script downloads models in multiple formats:

| Format | Speed | File Size | Best For |
|--------|-------|-----------|----------|
| **PyTorch (.pt)** | Baseline | ~6MB | General use, easy debugging |
| **NCNN** | **Fastest** (~94ms)* | ~10MB | **Raspberry Pi - RECOMMENDED** |
| **ONNX** | Slower (~191ms)* | ~10MB | Cross-platform compatibility |

*Inference times from [official benchmarks](https://docs.ultralytics.com/guides/raspberry-pi/) on Raspberry Pi 5

**For Raspberry Pi 4B, always use NCNN format for best performance!**

## Expected Performance

Based on Raspberry Pi 5 benchmarks (Pi 4B will be slower):

### YOLOv8n
- PyTorch: ~387ms inference
- ONNX: ~191ms inference  
- **NCNN: ~94ms inference** ⚡

### YOLO11n
- Similar performance to YOLOv8n
- Benchmark will show exact differences

## Project Structure

```
AI-PROJECT/
├── setup/
│   ├── setup_new.sh          # New setup script (use this!)
│   └── setup.sh              # Old version (deprecated)
├── src/
│   ├── run_yolov8_new.py     # YOLOv8n benchmark (new)
│   ├── run_yolo11_new.py     # YOLO11n benchmark (new)
│   ├── compare_results.py     # Compare benchmarks
│   └── utils/
│       ├── monitor.py         # System monitoring
│       ├── logger.py          # Logging utilities
│       └── fps.py             # FPS calculation
├── models/                    # Downloaded models
│   ├── yolov8n.pt
│   ├── yolo11n.pt
│   ├── yolov8n_ncnn_model/
│   └── yolo11n_ncnn_model/
├── logs/                      # Benchmark results
└── README_NEW.md             # This file
```

## Camera Setup

### Test Camera
```bash
rpicam-hello
```

### Camera Modes

The new scripts support:
1. **picamera2** (recommended) - Native Raspberry Pi camera support
2. **OpenCV fallback** - Works with USB cameras

Both are handled automatically.

## Advanced Usage

### Custom Model Path
```bash
python3 src/run_yolov8_new.py --duration 60 --model custom/path/model.pt
```

### Different Formats
```bash
# PyTorch (default)
python3 src/run_yolov8_new.py --duration 60 --format pt

# NCNN (fastest)
python3 src/run_yolov8_new.py --duration 60 --format ncnn

# ONNX
python3 src/run_yolov8_new.py --duration 60 --format onnx
```

### Image Benchmark
```bash
# Test on single image
python3 src/run_yolov8_new.py --image test.jpg --iterations 100 --format ncnn

# Compare formats
python3 src/run_yolov8_new.py --image test.jpg --iterations 100 --format pt
python3 src/run_yolov8_new.py --image test.jpg --iterations 100 --format ncnn
python3 src/run_yolov8_new.py --image test.jpg --iterations 100 --format onnx
```

## Troubleshooting

### Import Errors
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Check installations
pip list | grep ultralytics
pip list | grep opencv
```

### Camera Not Working
```bash
# Test camera
rpicam-hello

# Install camera tools
sudo apt install -y rpicam-apps

# Check picamera2
python3 -c "from picamera2 import Picamera2; print('OK')"
```

### Model Not Found
```bash
# Re-run setup
./setup/setup_new.sh

# Or download manually
cd models
python3 -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"
```

### Performance Issues
1. **Use NCNN format** - 2x faster than ONNX
2. **Close other applications** - Free up CPU/RAM
3. **Check temperature** - Ensure proper cooling
4. **Lower resolution** - Reduce camera resolution if needed

## Migration from Old Version

If you're using the old version:

```bash
# Pull latest code
git pull origin main

# Remove old virtual environment
rm -rf venv

# Remove old/corrupted models
rm -rf models setup/models

# Run new setup
./setup/setup_new.sh

# Use new scripts
python3 src/run_yolov8_new.py --duration 60 --format ncnn
```

## Performance Tips

1. **Always use NCNN format** on Raspberry Pi
2. **Enable overclocking** (optional, but helps):
   ```bash
   sudo nano /boot/firmware/config.txt
   # Add:
   # arm_freq=2000
   # gpu_freq=750
   ```
3. **Use SSD instead of SD card** for better I/O
4. **Ensure proper cooling** - heatsink + fan recommended
5. **Close unnecessary processes** before benchmarking

## References

- [Official Ultralytics Raspberry Pi Guide](https://docs.ultralytics.com/guides/raspberry-pi/)
- [NCNN Documentation](https://docs.ultralytics.com/integrations/ncnn/)
- [Raspberry Pi Camera Setup](https://www.raspberrypi.com/documentation/computers/camera_software.html)

## License

This project uses the [Ultralytics YOLO](https://github.com/ultralytics/ultralytics) library (AGPL-3.0).

## Credits

Based on official Ultralytics documentation and benchmarks.
