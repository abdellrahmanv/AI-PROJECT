# Models Directory

Place your ONNX models in this directory.

## Download Instructions

### YOLOv8n

```bash
wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx -O models/yolov8n.onnx
```

### YOLO11n

```bash
wget https://github.com/ultralytics/assets/releases/download/v8.1.0/yolo11n.onnx -O models/yolov11n.onnx
```

### Alternative: Export from PyTorch

If you have the `.pt` files:

```bash
python3 -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='onnx')"
python3 -c "from ultralytics import YOLO; YOLO('yolo11n.pt').export(format='onnx')"
```

## Expected Files

After downloading, you should have:
- `yolov8n.onnx` (~6MB)
- `yolov11n.onnx` (~6MB)

Both are nano versions optimized for edge devices like Raspberry Pi.
