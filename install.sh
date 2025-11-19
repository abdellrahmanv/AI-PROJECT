#!/bin/bash
#
# Install script - comprehensive installation with virtual environment
# Alternative to setup.sh with even more robust error handling
#

set +e

echo "╔════════════════════════════════════════╗"
echo "║   YOLO Benchmark - Full Installation  ║"
echo "║      Raspberry Pi 4B Optimized        ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Check if we're in the right directory
if [ ! -f "requirements.txt" ] || [ ! -d "src" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check for sudo access
echo "Checking permissions..."
if sudo -n true 2>/dev/null; then
    print_success "Sudo access confirmed"
else
    print_info "This script requires sudo access for system packages"
    sudo -v
fi

# Update system
print_info "Updating package lists..."
sudo apt-get update -qq

# Install all essential system packages
print_info "Installing essential packages (this may take 5-10 minutes)..."

ESSENTIAL_PACKAGES="python3 python3-pip python3-venv python3-dev build-essential cmake git wget curl"

for pkg in $ESSENTIAL_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        sudo apt-get install -y $pkg >/dev/null 2>&1
    fi
done

print_success "Essential packages installed"

# Install OpenCV dependencies
print_info "Installing OpenCV dependencies..."
sudo apt-get install -y \
    libopencv-dev python3-opencv \
    libjpeg-dev libtiff5-dev libpng-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev \
    libatlas-base-dev gfortran \
    >/dev/null 2>&1

print_success "OpenCV dependencies installed"

# Create and activate virtual environment
VENV_DIR="venv"

if [ -d "$VENV_DIR" ]; then
    print_warning "Virtual environment exists - removing..."
    rm -rf "$VENV_DIR"
fi

print_info "Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
print_success "Virtual environment created and activated"

# Upgrade pip, setuptools, wheel
print_info "Upgrading build tools..."
pip install --upgrade pip setuptools wheel >/dev/null 2>&1
print_success "Build tools upgraded"

# Install packages from requirements.txt
print_info "Installing Python packages from requirements.txt..."
print_info "This will take 10-20 minutes on Raspberry Pi..."

if pip install -r requirements.txt; then
    print_success "All packages installed from requirements.txt"
else
    print_warning "Some packages failed, installing individually..."
    
    # Install individually with fallbacks
    pip install "numpy>=1.21.0,<=1.24.3" || pip install "numpy==1.21.0"
    pip install "opencv-python>=4.5.0,<=4.8.1.78" || pip install "opencv-python-headless"
    pip install "onnxruntime>=1.15.0,<=1.16.3" || pip install "onnxruntime"
    pip install "psutil>=5.9.0"
fi

# Verify critical imports
print_info "Verifying installation..."
python3 -c "import cv2, onnxruntime, psutil, numpy; print('[OK] All critical packages verified')"

# Create directories
mkdir -p models logs/yolov8 logs/yolov11

# Download models
print_info "Downloading YOLO models..."
if [ ! -f "models/yolov8n.onnx" ]; then
    wget -q --show-progress https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx
    print_success "YOLOv8n downloaded"
fi

if [ ! -f "models/yolo11n.onnx" ]; then
    wget -q --show-progress https://github.com/ultralytics/assets/releases/download/v8.2.0/yolo11n.onnx -O models/yolo11n.onnx || \
    wget -q --show-progress https://github.com/ultralytics/assets/releases/download/v8.1.0/yolo11n.onnx -O models/yolo11n.onnx
    print_success "YOLO11n downloaded"
fi

# Create activation script
cat > activate_env.sh << 'EOF'
#!/bin/bash
source venv/bin/activate
echo "✓ Environment activated"
EOF
chmod +x activate_env.sh

# Save installed package versions
pip freeze > requirements_installed.txt

echo ""
print_success "═══════════════════════════════════════"
print_success "  Installation Complete!"
print_success "═══════════════════════════════════════"
echo ""
echo "To use the benchmark:"
echo "  1. Activate environment: source venv/bin/activate"
echo "  2. Run benchmark: python3 src/run_yolov8.py"
echo ""
print_info "Or use the quick start script: ./quickstart.sh"
