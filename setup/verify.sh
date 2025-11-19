#!/bin/bash
#
# Verification Script for YOLO Benchmark Setup
# Checks if everything is properly configured
#

echo "=========================================="
echo "YOLO Benchmark Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

ERRORS=0

# Check Python version
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ $MAJOR -eq 3 ] && [ $MINOR -ge 8 ]; then
        print_success "Python $PYTHON_VERSION (OK)"
    else
        print_warning "Python $PYTHON_VERSION (recommend 3.8+)"
    fi
else
    print_error "Python3 not found"
    ERRORS=$((ERRORS + 1))
fi

# Check Python packages
echo ""
echo "Checking Python packages..."

python3 -c "import cv2; print('OpenCV:', cv2.__version__)" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "OpenCV installed"
else
    print_error "OpenCV not installed"
    ERRORS=$((ERRORS + 1))
fi

python3 -c "import onnxruntime; print('ONNX Runtime:', onnxruntime.__version__)" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "ONNX Runtime installed"
else
    print_error "ONNX Runtime not installed"
    ERRORS=$((ERRORS + 1))
fi

python3 -c "import psutil; print('psutil:', psutil.__version__)" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "psutil installed"
else
    print_error "psutil not installed"
    ERRORS=$((ERRORS + 1))
fi

python3 -c "import numpy; print('numpy:', numpy.__version__)" 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "numpy installed"
else
    print_error "numpy not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check directories
echo ""
echo "Checking directories..."

for dir in models logs logs/yolov8 logs/yolov11 src/utils; do
    if [ -d "$dir" ]; then
        print_success "$dir exists"
    else
        print_error "$dir not found"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check source files
echo ""
echo "Checking source files..."

for file in src/run_yolov8.py src/run_yolov11.py src/compare_results.py \
            src/utils/monitor.py src/utils/logger.py src/utils/fps.py; do
    if [ -f "$file" ]; then
        print_success "$file exists"
    else
        print_error "$file not found"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check models
echo ""
echo "Checking models..."

if [ -f "models/yolov8n.onnx" ]; then
    SIZE=$(du -h models/yolov8n.onnx | cut -f1)
    print_success "yolov8n.onnx found ($SIZE)"
else
    print_warning "yolov8n.onnx not found - download it to run benchmarks"
fi

if [ -f "models/yolov11n.onnx" ]; then
    SIZE=$(du -h models/yolov11n.onnx | cut -f1)
    print_success "yolo11n.onnx found ($SIZE)"
else
    print_warning "yolo11n.onnx not found - download it to run benchmarks"
fi

# Check camera (if on Pi)
echo ""
echo "Checking camera..."

if command -v vcgencmd &> /dev/null; then
    CAMERA=$(vcgencmd get_camera 2>/dev/null)
    if [[ $CAMERA == *"detected=1"* ]]; then
        print_success "Camera detected"
    else
        print_warning "Camera not detected - you can still use image mode"
    fi
else
    print_info "Not on Raspberry Pi - camera check skipped"
fi

# Check system resources
echo ""
echo "Checking system resources..."

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
print_info "Total RAM: ${TOTAL_MEM}MB"

if [ $TOTAL_MEM -lt 1024 ]; then
    print_warning "Low RAM - benchmarks may fail"
elif [ $TOTAL_MEM -lt 2048 ]; then
    print_warning "Limited RAM - performance may be affected"
else
    print_success "Sufficient RAM"
fi

CPU_COUNT=$(nproc)
print_info "CPU cores: $CPU_COUNT"

# Temperature check (if on Pi)
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -o '[0-9.]*')
    if [ ! -z "$TEMP" ]; then
        print_info "Current temperature: ${TEMP}°C"
        
        if (( $(echo "$TEMP > 70" | bc -l) )); then
            print_warning "High temperature - consider cooling"
        fi
    fi
fi

# Summary
echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    print_success "Verification passed - system is ready"
    echo ""
    echo "You can now run benchmarks:"
    echo "  python3 src/run_yolov8.py --help"
    echo "  python3 src/run_yolov11.py --help"
    exit 0
else
    print_error "Verification failed with $ERRORS error(s)"
    echo ""
    echo "Please fix the errors and run setup again:"
    echo "  ./setup/setup.sh"
    exit 1
fi
