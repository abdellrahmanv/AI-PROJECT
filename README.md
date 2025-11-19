# YOLO Benchmark for Raspberry Pi 4B

A scientific benchmarking framework for comparing YOLOv8n and YOLO11n object detection models on Raspberry Pi 4B. This project provides fair, reproducible performance measurements with comprehensive system monitoring.

## 🎯 Project Goals

- **Fair Comparison**: Identical preprocessing, resolution, and runtime conditions
- **Scientific Rigor**: Reproducible measurements with detailed logging
- **System Monitoring**: Real-time tracking of CPU, RAM, temperature, and throttling
- **Base Models Only**: Uses stock ONNX models without custom training

## 📋 Features

- ✅ Identical inference pipeline for both models
- ✅ Real-time FPS calculation with rolling averages
- ✅ Comprehensive system resource monitoring
- ✅ Camera and static image input support
- ✅ Detailed logging with JSON export
- ✅ Automatic result comparison
- ✅ Throttling detection and logging
- ✅ Temperature monitoring

## 🏗️ Architecture

```
yolo_pi_benchmark/
│
├── setup/
│   ├── setup.sh              # Automated setup script
│   └── verify.sh             # Verification script
│
├── models/
│   ├── yolov8n.onnx         # YOLOv8n model (download separately)
│   └── yolov11n.onnx        # YOLO11n model (download separately)
│
├── src/
│   ├── run_yolov8.py        # YOLOv8n benchmark script
│   ├── run_yolov11.py       # YOLO11n benchmark script
│   ├── compare_results.py   # Results comparison tool
│   │
│   └── utils/
│       ├── monitor.py       # System monitoring module
│       ├── logger.py        # Logging utilities
│       └── fps.py           # FPS calculation
│
└── logs/
    ├── yolov8/              # YOLOv8 benchmark logs
    └── yolov11/             # YOLO11 benchmark logs
```

## 🚀 Quick Start

### 1. Setup on Raspberry Pi 4B

**Option A: Automatic Setup (Recommended)**

```bash
# Clone or copy the project to your Raspberry Pi
cd yolo_pi_benchmark

# Make scripts executable
chmod +x setup/setup.sh quickstart.sh install.sh

# Run comprehensive setup (installs everything + creates venv + downloads models)
./setup/setup.sh
```

The setup script will:
- ✅ Install all system dependencies
- ✅ Create and configure virtual environment
- ✅ Install all Python packages with fallback versions
- ✅ Download YOLO models automatically
- ✅ Verify installation with tests
- ✅ Handle errors gracefully with retries

**Option B: Quick Install (Alternative)**

```bash
# Simpler installation script
./install.sh
```

**Option C: Interactive Quick Start**

```bash
# All-in-one interactive menu
./quickstart.sh
```

### 2. Download Models

**Option A: Direct Download (Recommended)**

```bash
# Download YOLOv8n
wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx

# Download YOLO11n
wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolo11n.onnx -O models/yolov11n.onnx
```

**Option B: Export from PyTorch (requires ultralytics)**

```bash
python3 -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='onnx')"
python3 -c "from ultralytics import YOLO; YOLO('yolo11n.pt').export(format='onnx')"
mv yolov8n.onnx yolo11n.onnx models/
```

### 3. Verify Installation

```bash
./setup/verify.sh
```

### 4. Run Benchmarks

**Camera Mode (Default - 60 seconds)**

```bash
# Benchmark YOLOv8n
python3 src/run_yolov8.py --duration 60

# Benchmark YOLO11n
python3 src/run_yolov11.py --duration 60
```

**Image Mode (Static Image)**

```bash
# Benchmark with test image (100 iterations)
python3 src/run_yolov8.py --image test.jpg --iterations 100
python3 src/run_yolov11.py --image test.jpg --iterations 100
```

### 5. Compare Results

```bash
# Automatically compare latest logs
python3 src/compare_results.py --auto

# Or specify log files manually
python3 src/compare_results.py \
    --yolov8 logs/yolov8/yolov8_2024-01-20_10-30-00.json \
    --yolov11 logs/yolov11/yolov11_2024-01-20_11-00-00.json
```

## 📊 Usage Examples

### Basic Benchmark

```bash
# 60-second camera benchmark with default settings
python3 src/run_yolov8.py
```

### Custom Configuration

```bash
# 2-minute benchmark with custom input size
python3 src/run_yolov8.py --duration 120 --input-size 416

# Use different camera
python3 src/run_yolov8.py --camera 1

# Adjust confidence threshold
python3 src/run_yolov8.py --conf 0.5
```

### Image Benchmarking

```bash
# Test with static image (fast, controlled)
python3 src/run_yolov8.py --image samples/test.jpg --iterations 200
```

## 📈 Understanding Results

### Log Files

Each benchmark creates two files:
- **`.log`**: Human-readable text log with detailed metrics
- **`.json`**: Structured data for analysis and comparison

### Metrics Tracked

**Performance Metrics:**
- Average, Min, Max FPS
- Average, Min, Max Inference Time
- Total frames processed

**System Metrics:**
- CPU usage (per-core and overall)
- RAM usage
- Temperature
- System load
- Throttling events

### Sample Output

```
================================================================================
BENCHMARK COMPARISON REPORT
================================================================================

Comparing: yolov8 vs yolov11

--------------------------------------------------------------------------------
PERFORMANCE METRICS
--------------------------------------------------------------------------------

📊 Average FPS:
  🏆 yolov11    :  12.45 FPS
     yolov8     :  11.82 FPS
  → yolov11 is 5.3% faster

⏱️  Average Inference Time:
  🏆 yolov11    :   78.2 ms
     yolov8     :   82.5 ms
  → yolov11 is 5.2% faster

--------------------------------------------------------------------------------
SYSTEM RESOURCE USAGE
--------------------------------------------------------------------------------

💻 Average CPU Usage:
  🏆 yolov11    :  68.3%
     yolov8     :  72.1%

🧠 Average Memory Usage:
  🏆 yolov8     :  42.8%
     yolov11    :  43.5%

🌡️  Average Temperature:
  🏆 yolov8     :  58.2°C
     yolov11    :  59.1°C
```

## 🔧 Configuration Options

### YOLOv8 / YOLO11 Benchmark Scripts

```bash
python3 src/run_yolov8.py [OPTIONS]

Options:
  --model PATH          Path to ONNX model (default: models/yolov8n.onnx)
  --input-size SIZE     Input image size (default: 640)
  --duration SECONDS    Benchmark duration (default: 60)
  --camera INDEX        Camera device index (default: 0)
  --image PATH          Use static image instead of camera
  --iterations N        Number of iterations for image mode (default: 100)
  --conf THRESHOLD      Confidence threshold (default: 0.25)
```

### Comparison Script

```bash
python3 src/compare_results.py [OPTIONS]

Options:
  --auto                Automatically find latest logs
  --yolov8 PATH         Path to YOLOv8 JSON log
  --yolov11 PATH        Path to YOLO11 JSON log
  --log-dir PATH        Base log directory (default: logs)
  --output PATH         Output comparison file (default: comparison_result.json)
```

## 🛠️ Dependencies

### System Requirements
- Raspberry Pi 4B (tested on 4GB model)
- Raspberry Pi OS (Debian-based)
- Python 3.8+
- Camera module (optional, for camera mode)

### Python Packages
- `opencv-python` (4.8.1.78)
- `onnxruntime` (1.16.3)
- `numpy` (1.24.3)
- `psutil` (latest)

All dependencies are automatically installed by `setup.sh`.

## 📝 Important Notes

### Preprocessing
Both models use **identical preprocessing**:
1. Resize to specified input size (default 640x640)
2. BGR to RGB conversion
3. Normalization to [0, 1]
4. CHW format
5. Batch dimension added

### Model Comparability
- Uses **stock ONNX models** from Ultralytics
- No custom training or fine-tuning
- No class modifications
- Ensures true performance comparison

### Raspberry Pi Optimization
- Uses all 4 CPU cores
- ONNX Runtime graph optimizations enabled
- CPU execution provider only
- Monitors for thermal throttling

### Best Practices
1. Let the Pi cool down between benchmarks
2. Use consistent ambient temperature
3. Ensure adequate power supply (3A recommended)
4. Close unnecessary applications
5. Run multiple iterations for statistical validity

## 🐛 Troubleshooting

### Camera Not Detected
```bash
# Enable camera with raspi-config
sudo raspi-config
# Navigate to: Interface Options > Camera > Enable
# Reboot after enabling
```

### Import Errors
```bash
# Re-run setup
./setup/setup.sh

# Verify installation
./setup/verify.sh
```

### Low FPS
- Check for throttling in logs
- Verify adequate cooling
- Check power supply (use official 3A adapter)
- Reduce input size: `--input-size 416`

### Memory Issues
- Close unnecessary applications
- Use image mode instead of camera mode
- Restart the Pi before benchmarking

## 📊 Sample Benchmark Results

Typical results on Raspberry Pi 4B (4GB) at 640x640 input:

| Model    | Avg FPS | Avg Inference | Avg CPU | Avg Temp |
|----------|---------|---------------|---------|----------|
| YOLOv8n  | ~12 FPS | ~82ms         | ~72%    | ~58°C    |
| YOLO11n  | ~13 FPS | ~78ms         | ~68%    | ~59°C    |

*Results vary based on ambient temperature, power supply, and system load.*

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Additional inference backends (NCNN, TFLite)
- GPU acceleration support (if available)
- Additional YOLO variants
- Visualization tools
- Statistical analysis features

## 📄 License

This project is provided as-is for educational and benchmarking purposes.

## 🙏 Acknowledgments

- Ultralytics for YOLO models
- ONNX Runtime team
- Raspberry Pi Foundation

## 📞 Support

For issues specific to:
- **YOLO models**: Visit [Ultralytics GitHub](https://github.com/ultralytics/ultralytics)
- **ONNX Runtime**: Visit [ONNX Runtime GitHub](https://github.com/microsoft/onnxruntime)
- **Raspberry Pi**: Visit [Raspberry Pi Forums](https://forums.raspberrypi.com/)

---

**Happy Benchmarking! 🚀**
