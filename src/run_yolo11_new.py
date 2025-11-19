#!/usr/bin/env python3
"""
YOLO11n Benchmark for Raspberry Pi 4B
Using official Ultralytics library

Based on: https://docs.ultralytics.com/guides/raspberry-pi/
"""

import argparse
import time
import sys
from pathlib import Path
from datetime import datetime
import json

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent))

from utils.monitor import SystemMonitor
from utils.logger import BenchmarkLogger
from utils.fps import FPSCalculator


def run_camera_benchmark(model_path, duration, format_type='pt'):
    """Run benchmark with camera feed"""
    import cv2
    try:
        from picamera2 import Picamera2
        use_picamera2 = True
    except ImportError:
        use_picamera2 = False
        print("[WARNING] picamera2 not available, falling back to OpenCV")
    
    from ultralytics import YOLO
    
    print(f"\n{'='*60}")
    print("YOLO11n Camera Benchmark")
    print(f"{'='*60}")
    print(f"Model: {model_path}")
    print(f"Format: {format_type.upper()}")
    print(f"Duration: {duration}s")
    print(f"{'='*60}\n")
    
    # Initialize logger
    logger = BenchmarkLogger("yolo11n", model_format=format_type)
    fps_calc = FPSCalculator()
    monitor = SystemMonitor()
    
    # Load model
    print("[INFO] Loading model...")
    start_load = time.time()
    model = YOLO(model_path)
    load_time = time.time() - start_load
    print(f"[OK] Model loaded in {load_time:.2f}s")
    
    # Initialize camera
    print("[INFO] Initializing camera...")
    if use_picamera2:
        picam2 = Picamera2()
        picam2.preview_configuration.main.size = (640, 480)
        picam2.preview_configuration.main.format = "RGB888"
        picam2.preview_configuration.align()
        picam2.configure("preview")
        picam2.start()
        time.sleep(2)  # Warm up camera
        print("[OK] Picamera2 initialized")
    else:
        # Try different backends
        for backend in [cv2.CAP_V4L2, cv2.CAP_ANY]:
            cap = cv2.VideoCapture(0, backend)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                print(f"[OK] Camera opened with backend {backend}")
                break
        else:
            print("[ERROR] Failed to open camera")
            return
    
    # Warmup
    print("[INFO] Warming up...")
    monitor.start()
    for _ in range(10):
        if use_picamera2:
            frame = picam2.capture_array()
        else:
            ret, frame = cap.read()
            if not ret:
                continue
        _ = model(frame, verbose=False)
    print("[OK] Warmup complete")
    
    # Benchmark loop
    print(f"[INFO] Starting {duration}s benchmark...")
    start_time = time.time()
    frame_count = 0
    total_inference_time = 0
    
    try:
        while (time.time() - start_time) < duration:
            # Capture frame
            if use_picamera2:
                frame = picam2.capture_array()
            else:
                ret, frame = cap.read()
                if not ret:
                    print("[WARNING] Failed to read frame")
                    continue
            
            # Run inference
            inference_start = time.time()
            results = model(frame, verbose=False)
            inference_time = (time.time() - inference_start) * 1000  # ms
            
            # Update metrics
            total_inference_time += inference_time
            frame_count += 1
            fps_calc.update()
            
            # Log every 30 frames
            if frame_count % 30 == 0:
                metrics = monitor.get_metrics()
                current_fps = fps_calc.fps()
                print(f"Frame {frame_count:4d} | "
                      f"FPS: {current_fps:5.2f} | "
                      f"Inference: {inference_time:6.2f}ms | "
                      f"CPU: {metrics['cpu_percent']:5.1f}% | "
                      f"Temp: {metrics['temperature']:4.1f}°C")
                
                # Log to file
                logger.log_frame(
                    frame_number=frame_count,
                    inference_time=inference_time,
                    fps=current_fps,
                    cpu_percent=metrics['cpu_percent'],
                    memory_used=metrics['memory_mb'],
                    temperature=metrics['temperature'],
                    detections=len(results[0].boxes) if results[0].boxes is not None else 0
                )
    
    except KeyboardInterrupt:
        print("\n[INFO] Benchmark interrupted by user")
    
    finally:
        # Cleanup
        monitor.stop()
        if use_picamera2:
            picam2.stop()
        else:
            cap.release()
        cv2.destroyAllWindows()
    
    # Calculate final statistics
    elapsed = time.time() - start_time
    avg_fps = frame_count / elapsed
    avg_inference = total_inference_time / frame_count if frame_count > 0 else 0
    final_metrics = monitor.get_metrics()
    
    print(f"\n{'='*60}")
    print("Benchmark Results")
    print(f"{'='*60}")
    print(f"Total frames:      {frame_count}")
    print(f"Duration:          {elapsed:.2f}s")
    print(f"Average FPS:       {avg_fps:.2f}")
    print(f"Avg inference:     {avg_inference:.2f}ms")
    print(f"Max temperature:   {monitor.max_temperature:.1f}°C")
    print(f"Avg CPU usage:     {final_metrics['cpu_percent']:.1f}%")
    print(f"{'='*60}\n")
    
    # Save summary
    logger.save_summary(
        total_frames=frame_count,
        duration=elapsed,
        avg_fps=avg_fps,
        avg_inference_ms=avg_inference,
        max_temp=monitor.max_temperature
    )
    
    print(f"[OK] Results saved to: {logger.output_dir}")


def run_image_benchmark(model_path, image_path, iterations, format_type='pt'):
    """Run benchmark on a single image"""
    from ultralytics import YOLO
    import cv2
    
    print(f"\n{'='*60}")
    print("YOLO11n Image Benchmark")
    print(f"{'='*60}")
    print(f"Model: {model_path}")
    print(f"Format: {format_type.upper()}")
    print(f"Image: {image_path}")
    print(f"Iterations: {iterations}")
    print(f"{'='*60}\n")
    
    # Check image exists
    if not Path(image_path).exists():
        print(f"[ERROR] Image not found: {image_path}")
        return
    
    # Initialize
    logger = BenchmarkLogger("yolo11n", model_format=format_type)
    monitor = SystemMonitor()
    
    # Load model
    print("[INFO] Loading model...")
    model = YOLO(model_path)
    print("[OK] Model loaded")
    
    # Load image
    print("[INFO] Loading image...")
    image = cv2.imread(image_path)
    if image is None:
        print(f"[ERROR] Failed to load image: {image_path}")
        return
    print(f"[OK] Image loaded: {image.shape}")
    
    # Warmup
    print("[INFO] Warming up...")
    monitor.start()
    for _ in range(5):
        _ = model(image, verbose=False)
    print("[OK] Warmup complete")
    
    # Benchmark
    print(f"[INFO] Running {iterations} iterations...")
    inference_times = []
    
    for i in range(iterations):
        start = time.time()
        results = model(image, verbose=False)
        inference_time = (time.time() - start) * 1000
        inference_times.append(inference_time)
        
        if (i + 1) % 10 == 0:
            avg_so_far = sum(inference_times) / len(inference_times)
            print(f"Iteration {i+1:3d}/{iterations} | Avg: {avg_so_far:.2f}ms")
    
    monitor.stop()
    
    # Statistics
    avg_inference = sum(inference_times) / len(inference_times)
    min_inference = min(inference_times)
    max_inference = max(inference_times)
    
    print(f"\n{'='*60}")
    print("Benchmark Results")
    print(f"{'='*60}")
    print(f"Iterations:        {iterations}")
    print(f"Avg inference:     {avg_inference:.2f}ms")
    print(f"Min inference:     {min_inference:.2f}ms")
    print(f"Max inference:     {max_inference:.2f}ms")
    print(f"Max temperature:   {monitor.max_temperature:.1f}°C")
    print(f"{'='*60}\n")
    
    # Save results
    results_file = logger.output_dir / "image_benchmark.json"
    results_data = {
        "model": str(model_path),
        "format": format_type,
        "image": str(image_path),
        "iterations": iterations,
        "avg_inference_ms": avg_inference,
        "min_inference_ms": min_inference,
        "max_inference_ms": max_inference,
        "max_temp_c": monitor.max_temperature
    }
    
    with open(results_file, 'w') as f:
        json.dump(results_data, f, indent=2)
    
    print(f"[OK] Results saved to: {results_file}")


def main():
    parser = argparse.ArgumentParser(
        description='YOLO11n Benchmark for Raspberry Pi 4B',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Camera benchmark for 60 seconds (PyTorch)
  python3 run_yolo11_new.py --duration 60
  
  # Camera benchmark with NCNN format (fastest)
  python3 run_yolo11_new.py --duration 60 --format ncnn
  
  # Image benchmark
  python3 run_yolo11_new.py --image test.jpg --iterations 100
        """
    )
    
    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument('--duration', type=int,
                           help='Camera benchmark duration in seconds')
    mode_group.add_argument('--image', type=str,
                           help='Path to image file for image benchmark')
    
    # Common options
    parser.add_argument('--iterations', type=int, default=100,
                       help='Number of iterations for image benchmark (default: 100)')
    parser.add_argument('--model', type=str,
                       help='Path to model (default: auto-detect based on format)')
    parser.add_argument('--format', type=str, default='pt',
                       choices=['pt', 'ncnn', 'onnx'],
                       help='Model format: pt (PyTorch), ncnn (fastest), onnx (default: pt)')
    
    args = parser.parse_args()
    
    # Determine model path
    if args.model:
        model_path = args.model
    else:
        # Auto-detect model path based on format
        if args.format == 'pt':
            model_path = 'models/yolo11n.pt'
        elif args.format == 'ncnn':
            model_path = 'models/yolo11n_ncnn_model'
        elif args.format == 'onnx':
            model_path = 'models/yolo11n.onnx'
    
    if not Path(model_path).exists():
        print(f"[ERROR] Model not found: {model_path}")
        print("[INFO] Run setup/setup_new.sh to download models")
        sys.exit(1)
    
    # Run benchmark
    if args.duration:
        run_camera_benchmark(model_path, args.duration, args.format)
    else:
        run_image_benchmark(model_path, args.image, args.iterations, args.format)


if __name__ == "__main__":
    main()
