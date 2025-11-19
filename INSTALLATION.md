# Installation & Usage Guide

## 📦 Complete Installation Guide

### Method 1: Comprehensive Setup (Recommended)

The `setup.sh` script handles everything automatically with robust error handling:

```bash
cd yolo_pi_benchmark
chmod +x setup/setup.sh
./setup/setup.sh
```

**What it does:**
- ✅ Checks system compatibility and resources
- ✅ Installs all system dependencies with retries
- ✅ Creates isolated Python virtual environment
- ✅ Installs Python packages with fallback versions
- ✅ Downloads YOLO models automatically (optional)
- ✅ Verifies installation with import tests
- ✅ Tests camera access (if available)
- ✅ Creates helper scripts (activate_env.sh)
- ✅ Generates requirements_installed.txt with exact versions

**Error Handling Features:**
- Automatic retries for failed downloads
- Fallback package versions
- Alternative installation methods
- Detailed error reporting
- Continues on non-critical failures

### Method 2: Quick Install

For a faster, simpler installation:

```bash
chmod +x install.sh
./install.sh
```

### Method 3: Interactive Quick Start

All-in-one menu-driven interface:

```bash
chmod +x quickstart.sh
./quickstart.sh
```

Select from menu options to:
1. Run benchmarks
2. Compare results
3. Verify installation
4. Download models

## 🔧 Virtual Environment

### Activation

```bash
# Method 1: Direct activation
source venv/bin/activate

# Method 2: Helper script
source activate_env.sh

# Method 3: From quickstart
./quickstart.sh
```

Your terminal prompt will show `(venv)` when activated.

### Deactivation

```bash
deactivate
```

## 🎯 Running Benchmarks

### With Virtual Environment (Recommended)

```bash
# 1. Activate environment
source venv/bin/activate

# 2. Run benchmark
python3 src/run_yolov8.py --duration 60

# 3. Deactivate when done
deactivate
```

### Quick Commands

```bash
# YOLOv8n - 60 second camera benchmark
source venv/bin/activate && python3 src/run_yolov8.py --duration 60

# YOLO11n - 60 second camera benchmark
source venv/bin/activate && python3 src/run_yolov11.py --duration 60

# Run both and compare
source venv/bin/activate && \
python3 src/run_yolov8.py --duration 60 && \
sleep 30 && \
python3 src/run_yolov11.py --duration 60 && \
python3 src/compare_results.py --auto
```

### With Test Image

```bash
source venv/bin/activate
python3 src/run_yolov8.py --image test.jpg --iterations 100
python3 src/run_yolov11.py --image test.jpg --iterations 100
python3 src/compare_results.py --auto
```

## 🔍 Verification

```bash
# Run verification script
./setup/verify.sh
```

Checks:
- Python version and packages
- Directory structure
- Model files
- Camera availability
- System resources

## 📊 Comparing Results

```bash
# Automatic comparison of latest logs
source venv/bin/activate
python3 src/compare_results.py --auto

# Manual log file comparison
python3 src/compare_results.py \
    --yolov8 logs/yolov8/yolov8_2024-01-20_10-00-00.json \
    --yolov11 logs/yolov11/yolov11_2024-01-20_11-00-00.json
```

## 🐛 Troubleshooting

### Installation Issues

**Problem: Package installation fails**
```bash
# Solution 1: Clear pip cache
source venv/bin/activate
pip cache purge
pip install -r requirements.txt

# Solution 2: Install individually
pip install numpy opencv-python onnxruntime psutil
```

**Problem: Virtual environment creation fails**
```bash
# Solution: Install venv manually
sudo apt-get install python3-venv
python3 -m venv venv
```

**Problem: OpenCV import fails**
```bash
# Solution: Try headless version
source venv/bin/activate
pip uninstall opencv-python
pip install opencv-python-headless
```

### Runtime Issues

**Problem: Camera not accessible**
```bash
# Enable camera
sudo raspi-config
# Interface Options > Camera > Enable
sudo reboot

# Check camera
vcgencmd get_camera
```

**Problem: Out of memory**
```bash
# Increase swap
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Set CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

**Problem: Thermal throttling**
```bash
# Check throttling
vcgencmd get_throttled

# Monitor temperature
watch -n 1 vcgencmd measure_temp

# Solutions:
# - Add heatsink
# - Improve airflow
# - Reduce input size: --input-size 416
```

## 📦 Package Management

### Update Packages

```bash
source venv/bin/activate
pip install --upgrade pip
pip install --upgrade -r requirements.txt
```

### Add New Packages

```bash
source venv/bin/activate
pip install package-name
pip freeze > requirements_installed.txt
```

### Reinstall Everything

```bash
rm -rf venv
./setup/setup.sh
```

## 🎛️ Advanced Usage

### Custom Benchmark Parameters

```bash
source venv/bin/activate

# Custom duration and input size
python3 src/run_yolov8.py --duration 120 --input-size 416

# Different camera
python3 src/run_yolov8.py --camera 1

# Adjust confidence threshold
python3 src/run_yolov8.py --conf 0.5

# Multiple options
python3 src/run_yolov8.py \
    --duration 180 \
    --input-size 480 \
    --conf 0.3 \
    --camera 0
```

### Batch Benchmarking

```bash
source venv/bin/activate

# Test different input sizes
for size in 320 416 480 640; do
    echo "Testing size: $size"
    python3 src/run_yolov8.py --duration 60 --input-size $size
    sleep 60  # Cool down
done
```

### Automated Testing Script

```bash
#!/bin/bash
source venv/bin/activate

# Run multiple benchmarks with cooling periods
python3 src/run_yolov8.py --duration 60
echo "Cooling down (60s)..."
sleep 60

python3 src/run_yolov11.py --duration 60
echo "Cooling down (60s)..."
sleep 60

python3 src/compare_results.py --auto
```

## 📋 Log Management

### View Latest Logs

```bash
# Text logs
cat logs/yolov8/*.log | tail -50
cat logs/yolov11/*.log | tail -50

# JSON logs (formatted)
python3 -m json.tool logs/yolov8/*.json
```

### Clean Old Logs

```bash
# Remove logs older than 7 days
find logs/ -name "*.log" -mtime +7 -delete
find logs/ -name "*.json" -mtime +7 -delete
```

### Export Results

```bash
# Copy logs to external location
cp -r logs/ /media/usb/yolo_benchmark_results_$(date +%Y%m%d)/
```

## 🔄 Updating the Project

```bash
# Pull latest changes (if using git)
git pull

# Reinstall dependencies
source venv/bin/activate
pip install -r requirements.txt

# Re-run verification
./setup/verify.sh
```

## 💡 Tips for Best Results

1. **Cool Down Between Runs**: Wait 30-60 seconds between benchmarks
2. **Consistent Environment**: Same ambient temperature, same power supply
3. **Multiple Runs**: Run each benchmark 3-5 times for statistical validity
4. **Monitor System**: Keep an eye on temperature and throttling
5. **Close Apps**: Minimize background processes during benchmarking
6. **Use Virtual Environment**: Always activate venv for consistent results
7. **Check Logs**: Review logs for throttling events or errors
8. **Regular Updates**: Keep packages updated for best performance

## 📞 Getting Help

```bash
# Script help
python3 src/run_yolov8.py --help
python3 src/run_yolov11.py --help
python3 src/compare_results.py --help

# Check versions
source venv/bin/activate
python3 --version
pip list

# System info
./setup/verify.sh
```
