#!/usr/bin/env python3
"""
YOLOv8n Benchmark Script for Raspberry Pi 4B
Runs YOLOv8n model with ONNX Runtime and logs performance metrics
"""

import sys
import os
import time
import argparse
import threading
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort

# Add utils to path
sys.path.insert(0, str(Path(__file__).parent))
from utils import SystemMonitor, BenchmarkLogger, ConsoleLogger, FPSCalculator, InferenceTimer


class YOLOv8Benchmark:
    """YOLOv8n benchmark runner"""
    
    def __init__(self, model_path: str, input_size: int = 640, conf_threshold: float = 0.25):
        """Initialize YOLOv8 benchmark
        
        Args:
            model_path: Path to ONNX model
            input_size: Input image size (default 640)
            conf_threshold: Confidence threshold for detections
        """
        self.model_path = model_path
        self.input_size = input_size
        self.conf_threshold = conf_threshold
        
        ConsoleLogger.info(f"Initializing YOLOv8n Benchmark")
        ConsoleLogger.info(f"Model: {model_path}")
        ConsoleLogger.info(f"Input Size: {input_size}x{input_size}")
        
        # Initialize ONNX Runtime
        self.session = self._load_model()
        
        # Get model input/output details
        self.input_name = self.session.get_inputs()[0].name
        self.output_names = [output.name for output in self.session.get_outputs()]
        
        # Initialize monitoring
        self.monitor = SystemMonitor()
        self.logger = None
        
        # Performance tracking
        self.fps_calc = FPSCalculator(window_size=30)
        self.inference_timer = InferenceTimer()
        
        # Threading control
        self.monitoring_active = False
        self.monitor_thread = None
        
    def _load_model(self):
        """Load ONNX model with optimizations"""
        ConsoleLogger.progress("Loading ONNX model...")
        
        # Session options for optimization
        sess_options = ort.SessionOptions()
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        sess_options.intra_op_num_threads = 4  # Use all 4 cores of Pi 4B
        
        # Create inference session
        session = ort.InferenceSession(
            self.model_path,
            sess_options=sess_options,
            providers=['CPUExecutionProvider']
        )
        
        ConsoleLogger.success(f"Model loaded successfully")
        return session
    
    def _preprocess(self, image: np.ndarray) -> np.ndarray:
        """Preprocess image for YOLO
        
        Args:
            image: Input image (BGR format)
            
        Returns:
            Preprocessed image tensor
        """
        # Resize with letterbox (maintain aspect ratio)
        img = cv2.resize(image, (self.input_size, self.input_size))
        
        # Convert BGR to RGB
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Normalize to [0, 1]
        img = img.astype(np.float32) / 255.0
        
        # Transpose to CHW format
        img = np.transpose(img, (2, 0, 1))
        
        # Add batch dimension
        img = np.expand_dims(img, axis=0)
        
        return img
    
    def _inference(self, input_tensor: np.ndarray):
        """Run inference
        
        Args:
            input_tensor: Preprocessed input tensor
            
        Returns:
            Model output
        """
        outputs = self.session.run(
            self.output_names,
            {self.input_name: input_tensor}
        )
        return outputs
    
    def _warmup(self, num_iterations: int = 10):
        """Warm up the model
        
        Args:
            num_iterations: Number of warm-up iterations
        """
        ConsoleLogger.progress("Warming up model...")
        
        dummy_input = np.random.rand(1, 3, self.input_size, self.input_size).astype(np.float32)
        
        for _ in range(num_iterations):
            self._inference(dummy_input)
        
        ConsoleLogger.success("Warm-up complete")
    
    def _start_monitoring(self):
        """Start system monitoring thread"""
        self.monitoring_active = True
        
        def monitor_loop():
            while self.monitoring_active:
                snapshot = self.monitor.get_full_snapshot()
                self.logger.log_system_snapshot(snapshot)
                time.sleep(1.0)  # Log every second
        
        self.monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        self.monitor_thread.start()
    
    def _stop_monitoring(self):
        """Stop system monitoring thread"""
        self.monitoring_active = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2.0)
    
    def run_camera_benchmark(self, duration: int = 60, camera_index: int = 0):
        """Run benchmark using camera input
        
        Args:
            duration: Benchmark duration in seconds
            camera_index: Camera device index
        """
        # Initialize logger
        self.logger = BenchmarkLogger('yolov8')
        
        config = {
            'model_path': self.model_path,
            'input_size': f'{self.input_size}x{self.input_size}',
            'backend': 'ONNX Runtime',
            'input_source': f'Camera {camera_index}',
            'duration_seconds': duration,
            'conf_threshold': self.conf_threshold
        }
        
        self.logger.write_header(config)
        ConsoleLogger.info(f"Log file: {self.logger.get_log_path()}")
        
        # Warm up model
        self._warmup()
        
        # Open camera
        ConsoleLogger.progress(f"Opening camera {camera_index}...")
        cap = cv2.VideoCapture(camera_index)
        
        if not cap.isOpened():
            ConsoleLogger.error("Failed to open camera")
            return
        
        # Set camera properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        ConsoleLogger.success("Camera opened")
        
        # Start monitoring
        self._start_monitoring()
        
        # Start FPS calculation
        self.fps_calc.start()
        
        ConsoleLogger.info(f"Starting benchmark for {duration} seconds...")
        start_time = time.time()
        frame_count = 0
        
        try:
            while time.time() - start_time < duration:
                # Capture frame
                ret, frame = cap.read()
                if not ret:
                    ConsoleLogger.warning("Failed to capture frame")
                    continue
                
                # Preprocess
                input_tensor = self._preprocess(frame)
                
                # Inference
                self.inference_timer.start()
                outputs = self._inference(input_tensor)
                inference_time = self.inference_timer.stop()
                
                # Update FPS
                fps = self.fps_calc.update()
                
                # Log inference
                frame_count += 1
                if frame_count % 30 == 0:  # Log every 30 frames
                    self.logger.log_inference(frame_count, inference_time, fps)
                    
                    # Console update
                    elapsed = time.time() - start_time
                    remaining = duration - elapsed
                    print(f"\rFrame {frame_count} | FPS: {fps:.2f} | "
                          f"Inference: {inference_time*1000:.1f}ms | "
                          f"Remaining: {remaining:.0f}s", end='', flush=True)
        
        except KeyboardInterrupt:
            ConsoleLogger.warning("\nBenchmark interrupted by user")
        
        finally:
            print()  # New line after progress
            
            # Stop monitoring
            self._stop_monitoring()
            
            # Release camera
            cap.release()
            
            # Calculate summary
            self._write_summary()
            
            ConsoleLogger.success("Benchmark complete!")
            ConsoleLogger.info(f"Results saved to: {self.logger.get_log_path()}")
    
    def run_image_benchmark(self, image_path: str, num_iterations: int = 100):
        """Run benchmark using static image
        
        Args:
            image_path: Path to test image
            num_iterations: Number of iterations
        """
        # Initialize logger
        self.logger = BenchmarkLogger('yolov8')
        
        config = {
            'model_path': self.model_path,
            'input_size': f'{self.input_size}x{self.input_size}',
            'backend': 'ONNX Runtime',
            'input_source': f'Image: {image_path}',
            'num_iterations': num_iterations,
            'conf_threshold': self.conf_threshold
        }
        
        self.logger.write_header(config)
        ConsoleLogger.info(f"Log file: {self.logger.get_log_path()}")
        
        # Load image
        ConsoleLogger.progress(f"Loading image: {image_path}")
        image = cv2.imread(image_path)
        if image is None:
            ConsoleLogger.error("Failed to load image")
            return
        
        ConsoleLogger.success("Image loaded")
        
        # Warm up model
        self._warmup()
        
        # Preprocess once
        input_tensor = self._preprocess(image)
        
        # Start monitoring
        self._start_monitoring()
        
        # Start FPS calculation
        self.fps_calc.start()
        
        ConsoleLogger.info(f"Running {num_iterations} iterations...")
        
        try:
            for i in range(num_iterations):
                # Inference
                self.inference_timer.start()
                outputs = self._inference(input_tensor)
                inference_time = self.inference_timer.stop()
                
                # Update FPS
                fps = self.fps_calc.update()
                
                # Log
                if (i + 1) % 10 == 0:
                    self.logger.log_inference(i + 1, inference_time, fps)
                    print(f"\rIteration {i+1}/{num_iterations} | FPS: {fps:.2f} | "
                          f"Inference: {inference_time*1000:.1f}ms", end='', flush=True)
        
        except KeyboardInterrupt:
            ConsoleLogger.warning("\nBenchmark interrupted by user")
        
        finally:
            print()  # New line
            
            # Stop monitoring
            self._stop_monitoring()
            
            # Calculate summary
            self._write_summary()
            
            ConsoleLogger.success("Benchmark complete!")
            ConsoleLogger.info(f"Results saved to: {self.logger.get_log_path()}")
    
    def _write_summary(self):
        """Calculate and write summary statistics"""
        # Collect all inference times
        inference_times = [m.get('inference_time') for m in self.logger.metrics_buffer 
                          if 'inference_time' in m]
        
        # Collect all FPS values
        fps_values = [m.get('fps') for m in self.logger.metrics_buffer 
                     if 'fps' in m]
        
        # Collect system metrics
        cpu_values = [m.get('cpu_percent') for m in self.logger.metrics_buffer 
                     if 'cpu_percent' in m]
        
        memory_values = [m.get('memory_percent') for m in self.logger.metrics_buffer 
                        if 'memory_percent' in m]
        
        temp_values = [m.get('temperature') for m in self.logger.metrics_buffer 
                      if m.get('temperature') is not None]
        
        throttle_count = sum(1 for m in self.logger.metrics_buffer 
                           if m.get('throttled', False))
        
        summary = {
            'total_frames': self.fps_calc.get_frame_count(),
            'avg_fps': self.fps_calc.get_average_fps(),
            'min_fps': min(fps_values) if fps_values else 0,
            'max_fps': max(fps_values) if fps_values else 0,
            'avg_inference_ms': (sum(inference_times) / len(inference_times) * 1000) if inference_times else 0,
            'min_inference_ms': (min(inference_times) * 1000) if inference_times else 0,
            'max_inference_ms': (max(inference_times) * 1000) if inference_times else 0,
            'avg_cpu': sum(cpu_values) / len(cpu_values) if cpu_values else 0,
            'max_cpu': max(cpu_values) if cpu_values else 0,
            'avg_memory': sum(memory_values) / len(memory_values) if memory_values else 0,
            'max_memory': max(memory_values) if memory_values else 0,
            'throttle_events': throttle_count
        }
        
        if temp_values:
            initial_temp = temp_values[0] if temp_values else 0
            summary['avg_temperature'] = sum(temp_values) / len(temp_values)
            summary['max_temperature'] = max(temp_values)
            summary['temp_rise'] = max(temp_values) - initial_temp
        
        self.logger.write_summary(summary)
        self.logger.save_json()


def main():
    parser = argparse.ArgumentParser(description='YOLOv8n Benchmark for Raspberry Pi 4B')
    parser.add_argument('--model', type=str, default='models/yolov8n.onnx',
                       help='Path to YOLOv8n ONNX model')
    parser.add_argument('--input-size', type=int, default=640,
                       help='Input image size (default: 640)')
    parser.add_argument('--duration', type=int, default=60,
                       help='Benchmark duration in seconds (default: 60)')
    parser.add_argument('--camera', type=int, default=0,
                       help='Camera device index (default: 0)')
    parser.add_argument('--image', type=str, default=None,
                       help='Path to test image (alternative to camera)')
    parser.add_argument('--iterations', type=int, default=100,
                       help='Number of iterations for image mode (default: 100)')
    parser.add_argument('--conf', type=float, default=0.25,
                       help='Confidence threshold (default: 0.25)')
    
    args = parser.parse_args()
    
    # Check if model exists
    if not os.path.exists(args.model):
        ConsoleLogger.error(f"Model not found: {args.model}")
        ConsoleLogger.info("Please download YOLOv8n ONNX model first")
        return
    
    # Create benchmark
    benchmark = YOLOv8Benchmark(
        model_path=args.model,
        input_size=args.input_size,
        conf_threshold=args.conf
    )
    
    # Run benchmark
    if args.image:
        benchmark.run_image_benchmark(args.image, args.iterations)
    else:
        benchmark.run_camera_benchmark(args.duration, args.camera)


if __name__ == '__main__':
    main()
