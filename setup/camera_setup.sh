#!/bin/bash
#
# Camera Setup Helper for Raspberry Pi
# Configures camera for use with OpenCV and libcamera (rpicam)
#

echo "=========================================="
echo "Raspberry Pi Camera Setup Helper"
echo "=========================================="
echo ""

# Check if on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
    echo "⚠ Not running on Raspberry Pi - exiting"
    exit 1
fi

echo "Detecting camera system..."

# Check for libcamera (new system)
if command -v rpicam-hello &> /dev/null; then
    echo "✓ libcamera detected (rpicam commands available)"
    CAMERA_SYSTEM="libcamera"
elif command -v raspistill &> /dev/null; then
    echo "✓ Legacy camera system detected (raspistill)"
    CAMERA_SYSTEM="legacy"
else
    echo "⚠ No camera system detected"
    CAMERA_SYSTEM="none"
fi

echo ""
echo "Camera System: $CAMERA_SYSTEM"
echo ""

# Check camera status
if command -v vcgencmd &> /dev/null; then
    CAMERA_STATUS=$(vcgencmd get_camera 2>/dev/null)
    echo "Camera Status: $CAMERA_STATUS"
    
    if [[ $CAMERA_STATUS == *"detected=0"* ]]; then
        echo ""
        echo "⚠ Camera not detected!"
        echo ""
        echo "Steps to enable:"
        echo "  1. Run: sudo raspi-config"
        echo "  2. Navigate to: Interface Options > Camera"
        echo "  3. Select: Enable"
        echo "  4. Reboot: sudo reboot"
        exit 1
    fi
fi

echo ""
echo "Setting up camera for OpenCV..."

# For libcamera systems, we need v4l2 driver
if [ "$CAMERA_SYSTEM" = "libcamera" ]; then
    echo ""
    echo "Loading v4l2 driver for libcamera compatibility..."
    
    # Load the v4l2 module
    if sudo modprobe bcm2835-v4l2 2>/dev/null; then
        echo "✓ bcm2835-v4l2 module loaded"
    else
        echo "ℹ Module may already be loaded or not needed"
    fi
    
    # Make it persistent
    if ! grep -q "bcm2835-v4l2" /etc/modules 2>/dev/null; then
        echo ""
        read -p "Make v4l2 driver load automatically at boot? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "bcm2835-v4l2" | sudo tee -a /etc/modules > /dev/null
            echo "✓ Added bcm2835-v4l2 to /etc/modules"
        fi
    fi
    
    # Check for video device
    if [ -e /dev/video0 ]; then
        echo "✓ Video device found: /dev/video0"
    else
        echo "⚠ /dev/video0 not found"
        echo "  Try: sudo modprobe bcm2835-v4l2"
    fi
fi

# Test camera with libcamera
if [ "$CAMERA_SYSTEM" = "libcamera" ]; then
    echo ""
    echo "Testing camera with libcamera..."
    
    if timeout 2 rpicam-hello --timeout 1000 2>&1 | grep -q "Preview"; then
        echo "✓ Camera working with libcamera"
    else
        echo "⚠ Camera test inconclusive"
    fi
fi

# Test camera with OpenCV
echo ""
echo "Testing camera with OpenCV/Python..."

python3 << 'EOF'
import cv2
import sys

print("Attempting to open camera...")

# Try different backends
backends = [
    (cv2.CAP_V4L2, "V4L2"),
    (cv2.CAP_ANY, "ANY"),
    (0, "Default")
]

success = False
for backend, name in backends:
    try:
        if backend == 0:
            cap = cv2.VideoCapture(0)
        else:
            cap = cv2.VideoCapture(0, backend)
        
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            if ret and frame is not None:
                print(f"✓ Camera accessible via {name} backend")
                print(f"  Frame shape: {frame.shape}")
                success = True
                break
            else:
                print(f"⚠ {name} backend opened but cannot read frames")
        else:
            print(f"✗ Cannot open camera with {name} backend")
    except Exception as e:
        print(f"✗ {name} backend error: {e}")

if not success:
    print("\n⚠ Camera not accessible via OpenCV")
    sys.exit(1)
else:
    print("\n✓ Camera is ready for benchmarking!")
    sys.exit(0)
EOF

PYTHON_RESULT=$?

echo ""
echo "=========================================="

if [ $PYTHON_RESULT -eq 0 ]; then
    echo "✓ Camera Setup Complete!"
    echo ""
    echo "You can now run benchmarks:"
    echo "  python3 src/run_yolov8.py --duration 60"
    echo "  python3 src/run_yolov11.py --duration 60"
else
    echo "⚠ Camera Setup Issues Detected"
    echo ""
    echo "Troubleshooting steps:"
    echo ""
    echo "1. Enable camera:"
    echo "   sudo raspi-config"
    echo "   Interface Options > Camera > Enable"
    echo "   Reboot"
    echo ""
    echo "2. Load v4l2 driver manually:"
    echo "   sudo modprobe bcm2835-v4l2"
    echo ""
    echo "3. Check permissions:"
    echo "   sudo usermod -a -G video $USER"
    echo "   Log out and back in"
    echo ""
    echo "4. Verify device exists:"
    echo "   ls -l /dev/video*"
    echo ""
    echo "5. Test with rpicam (if available):"
    echo "   rpicam-hello"
    echo ""
    echo "6. Use image mode as alternative:"
    echo "   python3 src/run_yolov8.py --image test.jpg --iterations 100"
fi

echo "=========================================="
