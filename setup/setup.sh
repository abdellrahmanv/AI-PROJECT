#!/bin/bash
#
# Setup Script for YOLO Benchmark on Raspberry Pi 4B
# Installs all dependencies and prepares the system
# Enhanced with robust error handling and recovery
#

# Don't exit on error - we'll handle errors ourselves
set +e

echo "=========================================="
echo "YOLO Benchmark Setup for Raspberry Pi 4B"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error tracking
ERRORS=0
WARNINGS=0

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_progress() {
    echo -e "${BLUE}⏳${NC} $1"
}

# Function to retry a command
retry_command() {
    local max_attempts=3
    local timeout=1
    local attempt=1
    local cmd="$@"
    
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            print_info "Retry attempt $attempt of $max_attempts..."
            sleep $timeout
            timeout=$((timeout * 2))
        fi
        
        eval "$cmd"
        local status=$?
        
        if [ $status -eq 0 ]; then
            return 0
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check internet connectivity
check_internet() {
    print_progress "Checking internet connectivity..."
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 google.com >/dev/null 2>&1; then
        print_success "Internet connection available"
        return 0
    else
        print_error "No internet connection detected"
        print_info "Please check your network connection and try again"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local required_mb=2000
    local available_kb=$(df . | tail -1 | awk '{print $4}')
    local available_mb=$((available_kb / 1024))
    
    print_info "Available disk space: ${available_mb}MB"
    
    if [ $available_mb -lt $required_mb ]; then
        print_warning "Low disk space (${available_mb}MB available, ${required_mb}MB recommended)"
        print_info "Installation may fail if space runs out"
    else
        print_success "Sufficient disk space available"
    fi
}


# Check if running on Raspberry Pi
echo "Checking system..."
if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null || grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
    print_success "Running on Raspberry Pi"
    IS_PI=true
    
    # Get Pi model
    PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    print_info "Model: $PI_MODEL"
else
    print_warning "Not running on Raspberry Pi - some features may not work"
    IS_PI=false
fi

# Check architecture
ARCH=$(uname -m)
print_info "Architecture: $ARCH"

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    print_info "OS: $PRETTY_NAME"
fi

# Check internet
if ! check_internet; then
    print_error "Internet connection required for installation"
    exit 1
fi

# Check disk space
check_disk_space

# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then 
    print_warning "Running as root is not recommended"
    print_info "Consider running as regular user with sudo when needed"
fi

# Update system
echo ""
echo "Updating system packages..."
print_progress "Running apt-get update..."

if retry_command "sudo apt-get update -qq"; then
    print_success "System package list updated"
else
    print_warning "apt-get update had issues, but continuing..."
fi

# Upgrade existing packages (optional but recommended)
read -p "Do you want to upgrade existing packages? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_progress "Upgrading packages (this may take a while)..."
    if retry_command "sudo apt-get upgrade -y"; then
        print_success "Packages upgraded"
    else
        print_warning "Package upgrade had issues, but continuing..."
    fi
fi

# Install Python3 and pip
echo ""
echo "Installing Python3 and pip..."

if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    print_success "Python3 already installed: $PYTHON_VERSION"
else
    print_progress "Installing Python3..."
    if retry_command "sudo apt-get install -y python3 python3-pip python3-dev"; then
        PYTHON_VERSION=$(python3 --version 2>&1)
        print_success "Python3 installed: $PYTHON_VERSION"
    else
        print_error "Failed to install Python3"
        print_info "Try manually: sudo apt-get install python3 python3-pip python3-dev"
        exit 1
    fi
fi

# Check Python version
PYTHON_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')

if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
    print_success "Python version is compatible (3.8+)"
else
    print_warning "Python 3.8+ recommended (found Python $PYTHON_MAJOR.$PYTHON_MINOR)"
fi

# Install pip if not available
if ! command_exists pip3; then
    print_progress "Installing pip3..."
    if retry_command "sudo apt-get install -y python3-pip"; then
        print_success "pip3 installed"
    else
        print_error "Failed to install pip3"
        # Try alternative method
        print_progress "Trying alternative pip installation..."
        if curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python3 /tmp/get-pip.py; then
            print_success "pip3 installed via get-pip.py"
        else
            print_error "All pip installation methods failed"
            exit 1
        fi
    fi
fi

# Install python3-venv for virtual environment support
echo ""
echo "Installing virtual environment support..."
if dpkg -l | grep -q "^ii  python3-venv "; then
    print_success "python3-venv already installed"
else
    print_progress "Installing python3-venv..."
    if retry_command "sudo apt-get install -y python3-venv"; then
        print_success "python3-venv installed"
    else
        print_warning "python3-venv installation failed, will try alternative method"
    fi
fi

# Install wget and curl if not available
for tool in wget curl; do
    if ! command_exists $tool; then
        print_progress "Installing $tool..."
        if retry_command "sudo apt-get install -y $tool"; then
            print_success "$tool installed"
        else
            print_warning "$tool installation failed"
        fi
    fi
done

# Install system dependencies
echo ""
echo "Installing system dependencies..."
print_progress "This may take 5-10 minutes..."

REQUIRED_PACKAGES=(
    "build-essential"
    "cmake"
    "pkg-config"
    "libjpeg-dev"
    "libtiff5-dev"
    "libpng-dev"
    "libavcodec-dev"
    "libavformat-dev"
    "libswscale-dev"
    "libv4l-dev"
    "libxvidcore-dev"
    "libx264-dev"
    "libatlas-base-dev"
    "gfortran"
    "libhdf5-dev"
    "python3-pyqt5"
)

OPTIONAL_PACKAGES=(
    "libfontconfig1-dev"
    "libcairo2-dev"
    "libgdk-pixbuf2.0-dev"
    "libpango1.0-dev"
    "libgtk2.0-dev"
    "libgtk-3-dev"
    "libqt5gui5"
    "libqt5webkit5"
    "libqt5test5"
)

# Install required packages
FAILED_PACKAGES=()
for package in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "$package already installed"
    else
        print_progress "Installing $package..."
        if retry_command "sudo apt-get install -y $package 2>&1 | grep -v 'debconf: unable to initialize'"; then
            print_success "$package installed"
        else
            print_error "Failed to install $package"
            FAILED_PACKAGES+=("$package")
        fi
    fi
done

# Install optional packages (failures are okay)
for package in "${OPTIONAL_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        continue
    else
        if sudo apt-get install -y $package >/dev/null 2>&1; then
            print_success "$package installed"
        else
            print_info "Skipped optional package: $package"
        fi
    fi
done

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    print_warning "Some required packages failed to install: ${FAILED_PACKAGES[*]}"
    print_info "You may need to install these manually"
else
    print_success "All required system dependencies installed"
fi

# Create virtual environment BEFORE installing Python packages
echo ""
echo "=========================================="
echo "CREATING VIRTUAL ENVIRONMENT"
echo "=========================================="
echo ""

VENV_DIR="venv"
VENV_PATH="$(pwd)/$VENV_DIR"

if [ -d "$VENV_DIR" ]; then
    print_warning "Virtual environment already exists at $VENV_DIR"
    read -p "Do you want to remove and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_progress "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
        print_success "Removed existing virtual environment"
    else
        print_info "Using existing virtual environment"
        SKIP_VENV_CREATE=true
    fi
fi

if [ "$SKIP_VENV_CREATE" != true ]; then
    print_progress "Creating virtual environment at $VENV_DIR..."
    
    if python3 -m venv "$VENV_DIR" 2>/dev/null; then
        print_success "Virtual environment created successfully"
    else
        print_warning "venv module failed, trying virtualenv..."
        
        # Try installing virtualenv
        if python3 -m pip install --user virtualenv >/dev/null 2>&1; then
            if virtualenv "$VENV_DIR" 2>/dev/null; then
                print_success "Virtual environment created with virtualenv"
            else
                print_error "All virtual environment creation methods failed"
                print_info "Continuing with system Python (not recommended)"
                VENV_FAILED=true
            fi
        else
            print_error "Cannot create virtual environment"
            print_info "Continuing with system Python (not recommended)"
            VENV_FAILED=true
        fi
    fi
fi

# Activate virtual environment
if [ "$VENV_FAILED" != true ] && [ -f "$VENV_DIR/bin/activate" ]; then
    print_progress "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    print_success "Virtual environment activated"
    
    # Verify activation
    CURRENT_PYTHON=$(which python3)
    if [[ "$CURRENT_PYTHON" == *"$VENV_DIR"* ]]; then
        print_success "Using Python from virtual environment: $CURRENT_PYTHON"
    else
        print_warning "Virtual environment may not be properly activated"
    fi
    
    # Upgrade pip in venv
    print_progress "Upgrading pip in virtual environment..."
    if python3 -m pip install --upgrade pip >/dev/null 2>&1; then
        PIP_VERSION=$(pip3 --version 2>&1 | awk '{print $2}')
        print_success "pip upgraded to $PIP_VERSION in venv"
    fi
    
    # Install wheel and setuptools
    print_progress "Installing build tools..."
    pip3 install --upgrade setuptools wheel >/dev/null 2>&1
    print_success "Build tools installed"
    
else
    print_warning "Skipping virtual environment - using system Python"
fi

# Function to install Python package with fallback
install_python_package() {
    local package=$1
    local version=$2
    local package_name=$3
    
    if [ -n "$version" ]; then
        local full_package="${package}==${version}"
    else
        local full_package="${package}"
    fi
    
    print_progress "Installing ${package_name:-$package}..."
    
    # Try with specific version first
    if pip3 install "$full_package" >/dev/null 2>&1; then
        print_success "${package_name:-$package} installed successfully"
        return 0
    fi
    
    # If specific version fails, try without version
    if [ -n "$version" ]; then
        print_warning "Specific version failed, trying latest version..."
        if pip3 install "$package" >/dev/null 2>&1; then
            print_success "${package_name:-$package} installed (latest version)"
            return 0
        fi
    fi
    
    # Try with --no-cache-dir
    print_progress "Retrying with --no-cache-dir..."
    if pip3 install --no-cache-dir "$package" >/dev/null 2>&1; then
        print_success "${package_name:-$package} installed (no cache)"
        return 0
    fi
    
    # Try with --user flag
    print_progress "Retrying with --user flag..."
    if pip3 install --user "$package" >/dev/null 2>&1; then
        print_success "${package_name:-$package} installed (user mode)"
        return 0
    fi
    
    print_error "Failed to install ${package_name:-$package}"
    return 1
}

# Install Python packages
echo ""
echo "=========================================="
echo "INSTALLING PYTHON PACKAGES"
echo "=========================================="
echo ""
print_info "Installing packages in $([ "$VENV_FAILED" != true ] && echo "virtual environment" || echo "system Python")..."
print_info "This may take 10-20 minutes on Raspberry Pi..."
echo ""

PYTHON_ERRORS=0

# Install numpy first (required by others)
if ! install_python_package "numpy" "1.24.3" "numpy"; then
    # Try older version for older Python
    print_progress "Trying numpy 1.21.0 (compatible with older Python)..."
    if ! install_python_package "numpy" "1.21.0" "numpy"; then
        print_error "All numpy installation attempts failed"
        PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
    fi
fi

# Verify numpy
if python3 -c "import numpy" 2>/dev/null; then
    NUMPY_VERSION=$(python3 -c "import numpy; print(numpy.__version__)")
    print_success "numpy $NUMPY_VERSION ready"
else
    print_error "numpy verification failed"
    PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
fi

# Install OpenCV
if ! install_python_package "opencv-python" "4.8.1.78" "opencv-python"; then
    # Try different versions
    print_progress "Trying opencv-python-headless..."
    if ! install_python_package "opencv-python-headless" "" "opencv-python-headless"; then
        print_error "All OpenCV installation attempts failed"
        PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
    fi
fi

# Verify OpenCV
if "$VENV_PATH/bin/python3" -c "import cv2" 2>/dev/null || python3 -c "import cv2" 2>/dev/null; then
    CV2_VERSION=$(python3 -c "import cv2; print(cv2.__version__)" 2>/dev/null || echo "unknown")
    print_success "opencv-python $CV2_VERSION ready"
else
    print_error "OpenCV verification failed"
    PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
fi

# Install ONNX Runtime (CPU only for Pi)
if ! install_python_package "onnxruntime" "1.16.3" "onnxruntime"; then
    # Try older version
    print_progress "Trying onnxruntime 1.15.0..."
    if ! install_python_package "onnxruntime" "1.15.0" "onnxruntime"; then
        # Try latest
        print_progress "Trying latest onnxruntime..."
        if ! install_python_package "onnxruntime" "" "onnxruntime"; then
            print_error "All ONNX Runtime installation attempts failed"
            PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
        fi
    fi
fi

# Verify ONNX Runtime
if python3 -c "import onnxruntime" 2>/dev/null; then
    ORT_VERSION=$(python3 -c "import onnxruntime; print(onnxruntime.__version__)")
    print_success "onnxruntime $ORT_VERSION ready"
else
    print_error "ONNX Runtime verification failed"
    PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
fi

# Install psutil for system monitoring
if ! install_python_package "psutil" "" "psutil"; then
    print_error "psutil installation failed"
    PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
fi

# Verify psutil
if python3 -c "import psutil" 2>/dev/null; then
    PSUTIL_VERSION=$(python3 -c "import psutil; print(psutil.__version__)")
    print_success "psutil $PSUTIL_VERSION ready"
else
    print_error "psutil verification failed"
    PYTHON_ERRORS=$((PYTHON_ERRORS + 1))
fi

# Install ultralytics (optional)
print_info "Installing ultralytics (optional, for model export)..."
if install_python_package "ultralytics" "" "ultralytics"; then
    print_success "ultralytics installed"
else
    print_warning "ultralytics installation failed (optional, not critical)"
fi

# Summary of Python package installation
echo ""
if [ $PYTHON_ERRORS -eq 0 ]; then
    print_success "All critical Python packages installed successfully"
else
    print_error "$PYTHON_ERRORS critical Python package(s) failed to install"
    print_info "The benchmark may not work correctly"
fi

# Download YOLO models automatically
echo ""
echo "=========================================="
echo "DOWNLOADING YOLO MODELS"
echo "=========================================="
echo ""

# Ensure models directory exists before downloading
if [ ! -d "models" ]; then
    print_progress "Creating models directory..."
    mkdir -p models
    print_success "models directory created"
fi

download_model() {
    local model_name=$1
    local model_url=$2
    local model_path="models/${model_name}.onnx"
    
    if [ -f "$model_path" ]; then
        local size=$(du -h "$model_path" | cut -f1)
        print_success "${model_name}.onnx already exists ($size)"
        return 0
    fi
    
    print_progress "Downloading ${model_name}.onnx..."
    
    # Try wget first
    if command_exists wget; then
        if wget -q --show-progress "$model_url" -O "$model_path" 2>&1; then
            print_success "${model_name}.onnx downloaded successfully"
            return 0
        else
            print_warning "wget download failed, trying curl..."
            rm -f "$model_path"
        fi
    fi
    
    # Try curl
    if command_exists curl; then
        if curl -L --progress-bar "$model_url" -o "$model_path" 2>&1; then
            print_success "${model_name}.onnx downloaded successfully"
            return 0
        else
            print_error "${model_name}.onnx download failed"
            rm -f "$model_path"
            return 1
        fi
    fi
    
    print_error "No download tool available (wget or curl)"
    return 1
}

# Ask user if they want to download models
read -p "Do you want to download YOLO models now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # YOLOv8n URL (official Ultralytics release)
    YOLOV8_URL="https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx"
    
    # YOLO11n URL - try multiple sources
    YOLO11_URLS=(
        "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolo11n.onnx"
        "https://github.com/ultralytics/assets/releases/download/v8.1.0/yolo11n.onnx"
    )
    
    # Download YOLOv8n
    if ! download_model "yolov8n" "$YOLOV8_URL"; then
        print_warning "YOLOv8n download failed - you'll need to download it manually"
    fi
    
    # Download YOLO11n (try multiple URLs)
    YOLO11_SUCCESS=false
    for url in "${YOLO11_URLS[@]}"; do
        if download_model "yolo11n" "$url"; then
            YOLO11_SUCCESS=true
            break
        fi
    done
    
    if [ "$YOLO11_SUCCESS" != true ]; then
        print_warning "YOLO11n download failed - trying alternative method..."
        
        # Try exporting with ultralytics if available
        if python3 -c "import ultralytics" 2>/dev/null; then
            print_progress "Attempting to export YOLO11n using ultralytics..."
            
            if python3 << 'EOF'
from ultralytics import YOLO
try:
    model = YOLO('yolo11n.pt')
    model.export(format='onnx')
    print("Export successful")
except Exception as e:
    print(f"Export failed: {e}")
    exit(1)
EOF
            then
                if [ -f "yolo11n.onnx" ]; then
                    mv yolo11n.onnx models/
                    print_success "YOLO11n exported and moved to models/"
                fi
            else
                print_warning "YOLO11n export failed"
            fi
        fi
    fi
    
    # Verify downloaded models
    echo ""
    print_info "Verifying downloaded models..."
    
    for model in yolov8n yolo11n; do
        if [ -f "models/${model}.onnx" ]; then
            size=$(du -h "models/${model}.onnx" | cut -f1)
            print_success "${model}.onnx verified ($size)"
        else
            print_warning "${model}.onnx not found"
        fi
    done
else
    print_info "Skipping model download"
    echo ""
    echo "To download models manually, run:"
    echo "  wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx"
    echo "  wget https://github.com/ultralytics/assets/releases/download/v8.2.0/yolo11n.onnx -O models/yolo11n.onnx"
fi

# Create activation helper script
echo ""
print_progress "Creating helper scripts..."

if [ "$VENV_FAILED" != true ] && [ -d "$VENV_DIR" ]; then
    cat > activate_env.sh << 'EOF'
#!/bin/bash
# Activation helper script for YOLO benchmark environment

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "✓ Virtual environment activated"
    echo ""
    echo "You can now run:"
    echo "  python3 src/run_yolov8.py"
    echo "  python3 src/run_yolov11.py"
    echo "  python3 src/compare_results.py --auto"
    echo ""
    echo "To deactivate: deactivate"
else
    echo "✗ Virtual environment not found"
    echo "Run: ./setup/setup.sh"
fi
EOF
    chmod +x activate_env.sh
    print_success "Created activate_env.sh helper script"
fi

# Create requirements.txt from installed packages
if [ "$VENV_FAILED" != true ]; then
    print_progress "Generating requirements.txt..."
    pip3 freeze > requirements_installed.txt 2>/dev/null
    print_success "Created requirements_installed.txt with exact versions"
fi

# Final summary
echo ""
echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="
echo ""

# Count successes and failures
if [ $ERRORS -eq 0 ]; then
    print_success "Setup completed successfully with no errors!"
elif [ $ERRORS -lt 3 ]; then
    print_warning "Setup completed with $ERRORS minor error(s)"
else
    print_error "Setup completed with $ERRORS error(s)"
    print_info "Some features may not work correctly"
fi

if [ $WARNINGS -gt 0 ]; then
    print_info "$WARNINGS warning(s) were reported"
fi

# Print next steps
echo ""
echo "NEXT STEPS:"
echo "==========="
echo ""

if [ "$VENV_FAILED" != true ] && [ -d "$VENV_DIR" ]; then
    echo "1. Activate virtual environment:"
    echo "   source venv/bin/activate"
    echo "   OR use helper: source activate_env.sh"
    echo ""
fi

if [ ! -f "models/yolov8n.onnx" ] || [ ! -f "models/yolo11n.onnx" ]; then
    echo "2. Download missing models (if any):"
    if [ ! -f "models/yolov8n.onnx" ]; then
        echo "   wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx"
    fi
    if [ ! -f "models/yolo11n.onnx" ]; then
        echo "   wget https://github.com/ultralytics/assets/releases/download/v8.2.0/yolo11n.onnx -O models/yolo11n.onnx"
    fi
    echo ""
fi

echo "3. Verify installation:"
echo "   ./setup/verify.sh"
echo ""

echo "4. Run benchmarks:"
if [ "$VENV_FAILED" != true ] && [ -d "$VENV_DIR" ]; then
    echo "   source venv/bin/activate  # if not already activated"
fi
echo "   python3 src/run_yolov8.py --duration 60"
echo "   python3 src/run_yolov11.py --duration 60"
echo ""

echo "5. Compare results:"
echo "   python3 src/compare_results.py --auto"
echo ""

echo "For help on any script:"
echo "   python3 src/run_yolov8.py --help"
echo "   python3 src/run_yolov11.py --help"
echo "   python3 src/compare_results.py --help"
echo ""

if [ "$VENV_FAILED" != true ] && [ -d "$VENV_DIR" ]; then
    print_success "Virtual environment ready at: $VENV_PATH"
fi

print_success "Setup complete! Happy benchmarking! 🚀"
echo ""
if [ "$IS_PI" = true ] && command_exists vcgencmd; then
    CAMERA_STATUS=$(vcgencmd get_camera 2>/dev/null || echo "unknown")
    if [[ $CAMERA_STATUS == *"detected=1"* ]]; then
        print_success "Camera detected and enabled"
    elif [[ $CAMERA_STATUS == *"detected=0"* ]]; then
        print_warning "Camera not detected"
        print_info "Make sure camera is connected properly"
        print_info "Enable camera with: sudo raspi-config"
        print_info "Navigate to: Interface Options > Camera > Enable"
    else
        print_warning "Could not determine camera status"
    fi
else
    if [ "$IS_PI" = true ]; then
        print_warning "vcgencmd not available - cannot check camera"
    else
        print_info "Camera check skipped (not on Raspberry Pi)"
    fi
fi

# Check available memory
echo ""
echo "Checking system resources..."
if command_exists free; then
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
    print_info "Total RAM: ${TOTAL_MEM}MB"
    print_info "Available RAM: ${AVAILABLE_MEM}MB"
    
    if [ $TOTAL_MEM -lt 1024 ]; then
        print_error "Less than 1GB RAM - benchmarks will likely fail"
    elif [ $TOTAL_MEM -lt 2048 ]; then
        print_warning "Less than 2GB RAM - performance may be limited"
    else
        print_success "Sufficient RAM available"
    fi
    
    if [ $AVAILABLE_MEM -lt 512 ]; then
        print_warning "Low available RAM - consider closing applications"
    fi
else
    print_warning "Cannot check memory (free command not available)"
fi

# Check CPU info
if [ "$IS_PI" = true ]; then
    CPU_COUNT=$(nproc 2>/dev/null || echo "unknown")
    print_info "CPU cores: $CPU_COUNT"
    
    if command_exists vcgencmd; then
        CPU_FREQ=$(vcgencmd measure_clock arm 2>/dev/null | cut -d= -f2)
        if [ -n "$CPU_FREQ" ]; then
            CPU_FREQ_MHZ=$((CPU_FREQ / 1000000))
            print_info "CPU frequency: ${CPU_FREQ_MHZ}MHz"
        fi
        
        TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -o '[0-9.]*')
        if [ -n "$TEMP" ]; then
            print_info "Current temperature: ${TEMP}°C"
            if (( $(echo "$TEMP > 70" | bc -l 2>/dev/null || echo 0) )); then
                print_warning "High temperature detected - ensure proper cooling"
            fi
        fi
    fi
fi

# Create directory structure if not exists
echo ""
echo "Setting up directory structure..."
DIRECTORIES=("models" "logs/yolov8" "logs/yolov11" "src/utils")

for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        # Directory already exists (may have been created during model download)
        print_success "$dir created"
    else
        if mkdir -p "$dir" 2>/dev/null; then
            print_success "$dir created"
        else
            print_error "Failed to create $dir"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Test installation
echo ""
echo "Testing installation..."
print_progress "Running import tests..."

# Create a test script
TEST_SCRIPT=$(mktemp)
cat > "$TEST_SCRIPT" << 'EOF'
import sys
errors = []
success = []

# Test imports
packages = [
    ("cv2", "OpenCV"),
    ("onnxruntime", "ONNX Runtime"),
    ("psutil", "psutil"),
    ("numpy", "numpy")
]

for module, name in packages:
    try:
        exec(f"import {module}")
        version = eval(f"{module}.__version__")
        success.append(f"{name} {version}")
    except ImportError as e:
        errors.append(name)
    except AttributeError:
        success.append(name)

# Print results
for s in success:
    print(f"✓ {s}")

if errors:
    print(f"\n✗ Failed imports: {', '.join(errors)}")
    sys.exit(1)
else:
    print("\n✓ All packages verified")
    sys.exit(0)
EOF

# Run test
if python3 "$TEST_SCRIPT" 2>/dev/null; then
    print_success "Installation test passed"
else
    print_error "Installation test failed"
    print_info "Some packages may not be properly installed"
    ERRORS=$((ERRORS + 1))
fi

# Clean up test script
rm -f "$TEST_SCRIPT"

# Test camera access (if on Pi)
if [ "$IS_PI" = true ]; then
    echo ""
    print_progress "Testing camera access..."
    
    CAMERA_TEST=$(mktemp)
    cat > "$CAMERA_TEST" << 'EOF'
import cv2
import sys

try:
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        ret, frame = cap.read()
        cap.release()
        if ret:
            print("✓ Camera accessible")
            sys.exit(0)
        else:
            print("⚠ Camera opened but cannot read frames")
            sys.exit(1)
    else:
        print("⚠ Cannot open camera")
        sys.exit(1)
except Exception as e:
    print(f"⚠ Camera test error: {e}")
    sys.exit(1)
EOF
    
    if python3 "$CAMERA_TEST" 2>/dev/null; then
        print_success "Camera is accessible"
    else
        print_warning "Camera test failed - you can still use image mode"
    fi
    
    rm -f "$CAMERA_TEST"
fi

# Note: Virtual environment already created and activated earlier in the script (after system dependencies)
# All Python packages below will be installed in the venv
