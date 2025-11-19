#!/bin/bash
#
# YOLO Benchmark Setup for Raspberry Pi 4B
# Based on official Ultralytics documentation
# https://docs.ultralytics.com/guides/raspberry-pi/
#

set -e

# Get script directory and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT" || exit 1

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "=========================================="
echo "YOLO Benchmark Setup - Raspberry Pi 4B"
echo "=========================================="
echo "Project: $PROJECT_ROOT"
echo ""

# Check if running on Raspberry Pi
if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    print_warning "Not running on Raspberry Pi - some features may not work"
fi

# Detect Python version
# Try Python 3.11 first (best compatibility), then 3.12, then 3.10
PYTHON_CMD=""
PYTHON_VERSION=""

for py_ver in python3.11 python3.12 python3.10 python3; do
    if command -v $py_ver &> /dev/null; then
        PYTHON_VERSION=$($py_ver --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$($py_ver -c 'import sys; print(sys.version_info[0])')
        PYTHON_MINOR=$($py_ver -c 'import sys; print(sys.version_info[1])')
        
        # Check if version is 3.10, 3.11, or 3.12 (not 3.13!)
        if [[ $PYTHON_MAJOR -eq 3 ]] && [[ $PYTHON_MINOR -ge 10 ]] && [[ $PYTHON_MINOR -le 12 ]]; then
            PYTHON_CMD="$py_ver"
            print_success "Using $py_ver (version $PYTHON_VERSION)"
            break
        elif [[ $PYTHON_MAJOR -eq 3 ]] && [[ $PYTHON_MINOR -eq 13 ]]; then
            print_warning "$py_ver is version $PYTHON_VERSION (too new - ONNX doesn't compile)"
        fi
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    print_warning "No compatible Python version found (3.10-3.12)."
    print_info "Current python3 is too new ($PYTHON_VERSION)."
    
    print_info "Attempting to install Python 3.11 automatically..."
    echo "Running: sudo apt update && sudo apt install -y python3.11 python3.11-venv python3.11-dev"
    
    if sudo apt update && sudo apt install -y python3.11 python3.11-venv python3.11-dev; then
        print_success "Python 3.11 installed successfully!"
        PYTHON_CMD="python3.11"
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    else
        print_error "Failed to install Python 3.11 automatically. Please install it manually:\n  sudo apt install -y python3.11 python3.11-venv python3.11-dev"
        exit 1
    fi
fi

print_info "Python version: $PYTHON_VERSION"

# ==========================================
# Step 1: System Dependencies
# ==========================================
print_info "Step 1: Installing system dependencies..."
echo ""

# Update package lists
print_info "Updating package lists..."
sudo apt update || print_error "Failed to update package lists"

# Essential packages
PACKAGES=(
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "build-essential"
    "git"
    "wget"
    "libopencv-dev"
    "python3-opencv"
    "libatlas-base-dev"
    "libopenblas-dev"
    "libjpeg-dev"
    "libpng-dev"
    "libtiff-dev"
    "libavcodec-dev"
    "libavformat-dev"
    "libswscale-dev"
    "libv4l-dev"
    "libxvidcore-dev"
    "libx264-dev"
    "libgtk-3-dev"
)

print_info "Installing system packages..."
sudo apt install -y "${PACKAGES[@]}" || print_warning "Some packages failed to install"

print_success "System dependencies installed"
echo ""

# ==========================================
# Step 2: Python Virtual Environment
# ==========================================
print_info "Step 2: Setting up Python virtual environment..."
echo ""

VENV_DIR="$PROJECT_ROOT/venv"

if [[ -d "$VENV_DIR" ]]; then
    # Check if existing venv is Python 3.13 (broken)
    if "$VENV_DIR/bin/python3" -c 'import sys; exit(0 if sys.version_info[1] == 13 else 1)'; then
        print_warning "Detected Python 3.13 in existing venv (incompatible). Removing..."
        rm -rf "$VENV_DIR"
    else
        print_warning "Virtual environment already exists at $VENV_DIR"
        read -p "Remove and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
            print_info "Removed existing virtual environment"
        else
            print_info "Using existing virtual environment"
        fi
    fi
fi

if [[ ! -d "$VENV_DIR" ]]; then
    print_info "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR" || print_error "Failed to create virtual environment"
    print_success "Virtual environment created"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate" || print_error "Failed to activate virtual environment"
print_success "Virtual environment activated"
echo ""

# ==========================================
# Step 3: Upgrade pip
# ==========================================
print_info "Step 3: Upgrading pip..."
pip install --upgrade pip || print_warning "Failed to upgrade pip"
print_success "pip upgraded"
echo ""

# ==========================================
# Step 4: Install Ultralytics
# ==========================================
print_info "Step 4: Installing Ultralytics with export dependencies..."
echo ""

# Install ultralytics with export support (includes NCNN export)
print_info "Installing ultralytics[export]..."
pip install "ultralytics[export]" || print_error "Failed to install ultralytics"
print_success "Ultralytics installed"
echo ""

# ==========================================
# Step 5: Install Additional Dependencies
# ==========================================
print_info "Step 5: Installing additional dependencies..."
echo ""

# Install compatible numpy version (OpenCV compatibility)
print_info "Installing numpy<2.0 (OpenCV compatibility)..."
pip install "numpy<2.0" || print_warning "Failed to install numpy"

# Install psutil for system monitoring
print_info "Installing psutil..."
pip install psutil || print_warning "Failed to install psutil"

# Install picamera2 for camera support (if on Raspberry Pi)
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    print_info "Installing picamera2..."
    pip install picamera2 || print_warning "Failed to install picamera2"
fi

print_success "Additional dependencies installed"
echo ""

# ==========================================
# Step 6: Download Models
# ==========================================
print_info "Step 6: Downloading YOLO models..."
echo ""

# Create models directory
mkdir -p "$PROJECT_ROOT/models"
cd "$PROJECT_ROOT/models" || exit 1

# Function to download and optionally export models
download_model() {
    local model_name=$1
    local export_format=$2  # Optional: ncnn, onnx, etc.
    
    print_info "Processing $model_name..."
    
    # Download .pt model if not exists
    if [[ ! -f "${model_name}.pt" ]]; then
        print_info "Downloading ${model_name}.pt..."
        python3 -c "
from ultralytics import YOLO
model = YOLO('${model_name}.pt')
print(f'Downloaded ${model_name}.pt')
" || print_warning "Failed to download ${model_name}.pt"
    else
        print_success "${model_name}.pt already exists"
    fi
    
    # Export to specified format if requested
    if [[ -n "$export_format" ]]; then
        export_file="${model_name}_${export_format}_model"
        if [[ ! -d "$export_file" ]]; then
            print_info "Exporting ${model_name}.pt to $export_format..."
            python3 -c "
from ultralytics import YOLO
model = YOLO('${model_name}.pt')
model.export(format='${export_format}')
print(f'Exported to ${export_format}')
" || print_warning "Failed to export to ${export_format}"
        else
            print_success "${export_file} already exists"
        fi
    fi
}

# Download YOLOv8n (PyTorch format - fastest to start)
download_model "yolov8n"

# Download YOLO11n (PyTorch format)
download_model "yolo11n"

# Export to NCNN for optimal Raspberry Pi performance
print_info "Exporting models to NCNN format (optimal for Raspberry Pi)..."
download_model "yolov8n" "ncnn"
download_model "yolo11n" "ncnn"

cd "$PROJECT_ROOT"
print_success "Models downloaded and exported"
echo ""

# ==========================================
# Step 7: Camera Setup (Raspberry Pi only)
# ==========================================
if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    print_info "Step 7: Camera setup..."
    echo ""
    
    print_info "Testing camera with rpicam-hello..."
    if command -v rpicam-hello &> /dev/null; then
        print_success "rpicam-hello found"
        print_info "Run 'rpicam-hello' to test your camera"
    else
        print_warning "rpicam-hello not found"
        print_info "Install camera tools: sudo apt install -y rpicam-apps"
    fi
    echo ""
fi

# ==========================================
# Step 8: Verify Installation
# ==========================================
print_info "Step 8: Verifying installation..."
echo ""

python3 << 'EOF'
import sys

def check_package(name):
    try:
        __import__(name)
        print(f"[OK] {name}")
        return True
    except ImportError:
        print(f"[ERROR] {name} not found")
        return False

print("Checking Python packages:")
packages = ['ultralytics', 'cv2', 'numpy', 'psutil']
all_ok = all(check_package(pkg) for pkg in packages)

if all_ok:
    print("\n[OK] All packages installed successfully")
    
    # Check Ultralytics version
    import ultralytics
    print(f"\nUltralytics version: {ultralytics.__version__}")
    
    # Check available models
    from ultralytics import YOLO
    print("\nYOLO models ready to use")
else:
    print("\n[ERROR] Some packages missing")
    sys.exit(1)
EOF

if [[ $? -eq 0 ]]; then
    print_success "Installation verified"
else
    print_error "Verification failed"
fi
echo ""

# ==========================================
# Setup Complete
# ==========================================
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Activate virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Run YOLOv8n benchmark (Fastest):"
echo "   python3 src/run_yolov8_new.py --duration 60 --format ncnn"
echo ""
echo "3. Run YOLO11n benchmark (Fastest):"
echo "   python3 src/run_yolo11_new.py --duration 60 --format ncnn"
echo ""
echo "4. Compare results:"
echo "   python3 src/compare_results.py --auto"
echo ""
echo "Models available:"
echo "  - models/yolov8n.pt (PyTorch)"
echo "  - models/yolo11n.pt (PyTorch)"
echo "  - models/yolov8n_ncnn_model (NCNN - fastest)"
echo "  - models/yolo11n_ncnn_model (NCNN - fastest)"
echo ""
echo "For camera testing:"
echo "  rpicam-hello"
echo ""
print_success "Setup complete!"
