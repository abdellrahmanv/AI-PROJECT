#!/bin/bash
#
# Quick Start Script for YOLO Benchmark
# Automatically sets up everything needed to run benchmarks
#

echo "=========================================="
echo "YOLO Benchmark Quick Start"
echo "=========================================="
echo ""

# Check if setup has been run
if [ ! -d "venv" ] && [ ! -d "src/utils" ]; then
    echo "⚠ Setup not detected. Running full setup..."
    echo ""
    
    if [ -f "setup/setup.sh" ]; then
        chmod +x setup/setup.sh
        bash setup/setup.sh
    else
        echo "✗ setup.sh not found!"
        echo "Please run from project root directory"
        exit 1
    fi
fi

# Activate virtual environment if it exists
if [ -f "venv/bin/activate" ]; then
    echo "✓ Activating virtual environment..."
    source venv/bin/activate
else
    echo "⚠ Virtual environment not found, using system Python"
fi

# Check if models exist
echo ""
echo "Checking for models..."
MODELS_MISSING=false

if [ ! -f "models/yolov8n.onnx" ]; then
    echo "⚠ YOLOv8n model not found"
    MODELS_MISSING=true
fi

if [ ! -f "models/yolo11n.onnx" ]; then
    echo "⚠ YOLO11n model not found"
    MODELS_MISSING=true
fi

if [ "$MODELS_MISSING" = true ]; then
    echo ""
    read -p "Download missing models now? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Downloading models..."
        
        if [ ! -f "models/yolov8n.onnx" ]; then
            wget -q --show-progress https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx
        fi
        
        if [ ! -f "models/yolo11n.onnx" ]; then
            wget -q --show-progress https://github.com/ultralytics/assets/releases/download/v8.2.0/yolo11n.onnx -O models/yolo11n.onnx
        fi
        
        echo "✓ Models downloaded"
    fi
fi

# Show menu
echo ""
echo "=========================================="
echo "What would you like to do?"
echo "=========================================="
echo ""
echo "1. Run YOLOv8n benchmark (60s camera)"
echo "2. Run YOLO11n benchmark (60s camera)"
echo "3. Run both benchmarks sequentially"
echo "4. Compare latest results"
echo "5. Run with test image (100 iterations)"
echo "6. Custom benchmark parameters"
echo "7. Verify installation"
echo "8. Exit"
echo ""
read -p "Enter choice [1-8]: " choice

case $choice in
    1)
        echo ""
        echo "Running YOLOv8n benchmark..."
        python3 src/run_yolov8.py --duration 60
        ;;
    2)
        echo ""
        echo "Running YOLO11n benchmark..."
        python3 src/run_yolov11.py --duration 60
        ;;
    3)
        echo ""
        echo "Running YOLOv8n benchmark first..."
        python3 src/run_yolov8.py --duration 60
        
        echo ""
        echo "Waiting 30 seconds for Pi to cool down..."
        sleep 30
        
        echo ""
        echo "Running YOLO11n benchmark..."
        python3 src/run_yolov11.py --duration 60
        
        echo ""
        echo "Comparing results..."
        python3 src/compare_results.py --auto
        ;;
    4)
        echo ""
        echo "Comparing latest results..."
        python3 src/compare_results.py --auto
        ;;
    5)
        echo ""
        read -p "Enter path to test image: " img_path
        if [ -f "$img_path" ]; then
            echo "Running YOLOv8n with test image..."
            python3 src/run_yolov8.py --image "$img_path" --iterations 100
            
            echo ""
            echo "Running YOLO11n with test image..."
            python3 src/run_yolov11.py --image "$img_path" --iterations 100
            
            echo ""
            echo "Comparing results..."
            python3 src/compare_results.py --auto
        else
            echo "✗ Image not found: $img_path"
        fi
        ;;
    6)
        echo ""
        echo "Custom benchmark parameters:"
        read -p "Model (yolov8/yolov11): " model
        read -p "Duration (seconds, default 60): " duration
        duration=${duration:-60}
        read -p "Input size (default 640): " size
        size=${size:-640}
        
        if [ "$model" = "yolov8" ]; then
            python3 src/run_yolov8.py --duration $duration --input-size $size
        elif [ "$model" = "yolov11" ]; then
            python3 src/run_yolov11.py --duration $duration --input-size $size
        else
            echo "✗ Invalid model choice"
        fi
        ;;
    7)
        echo ""
        echo "Verifying installation..."
        if [ -f "setup/verify.sh" ]; then
            chmod +x setup/verify.sh
            bash setup/verify.sh
        else
            echo "✗ verify.sh not found"
        fi
        ;;
    8)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "✗ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
