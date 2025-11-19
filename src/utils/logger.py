"""
Logging Module for YOLO Benchmarking
Handles structured logging of benchmark results and system metrics
"""

import os
import json
from datetime import datetime
from typing import Dict, List, Optional, Any
from pathlib import Path


class BenchmarkLogger:
    """Logger for YOLO benchmark results"""
    
    def __init__(self, model_name: str, log_dir: str = 'logs'):
        """Initialize benchmark logger
        
        Args:
            model_name: Name of the model (e.g., 'yolov8', 'yolov11')
            log_dir: Base directory for logs
        """
        self.model_name = model_name
        self.log_dir = Path(log_dir) / model_name
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Create timestamped log filename
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        self.log_filename = f"{model_name}_{timestamp}.log"
        self.log_path = self.log_dir / self.log_filename
        
        self.json_filename = f"{model_name}_{timestamp}.json"
        self.json_path = self.log_dir / self.json_filename
        
        self.metrics_buffer: List[Dict] = []
        self.run_config: Optional[Dict] = None
        self.summary: Optional[Dict] = None
        
    def write_header(self, config: Dict):
        """Write benchmark configuration header
        
        Args:
            config: Configuration dictionary with model and run settings
        """
        self.run_config = config
        
        with open(self.log_path, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write(f"YOLO BENCHMARK LOG - {self.model_name.upper()}\n")
            f.write("=" * 80 + "\n")
            f.write(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Model: {config.get('model_path', 'N/A')}\n")
            f.write(f"Input Size: {config.get('input_size', 'N/A')}\n")
            f.write(f"Backend: {config.get('backend', 'ONNX Runtime')}\n")
            f.write(f"Input Source: {config.get('input_source', 'Camera')}\n")
            f.write(f"Duration: {config.get('duration_seconds', 'N/A')} seconds\n")
            f.write("=" * 80 + "\n\n")
    
    def log_metric(self, metric_data: Dict):
        """Log a single metric entry
        
        Args:
            metric_data: Dictionary containing metric information
        """
        self.metrics_buffer.append(metric_data)
        
        # Write to log file
        with open(self.log_path, 'a') as f:
            timestamp = metric_data.get('timestamp', datetime.now().timestamp())
            dt = datetime.fromtimestamp(timestamp)
            
            f.write(f"[{dt.strftime('%H:%M:%S.%f')[:-3]}] ")
            
            if 'fps' in metric_data:
                f.write(f"FPS: {metric_data['fps']:.2f} | ")
            
            if 'inference_time' in metric_data:
                f.write(f"Inference: {metric_data['inference_time']*1000:.1f}ms | ")
            
            if 'cpu_percent' in metric_data:
                f.write(f"CPU: {metric_data['cpu_percent']:.1f}% | ")
            
            if 'memory_percent' in metric_data:
                f.write(f"RAM: {metric_data['memory_percent']:.1f}% | ")
            
            if 'temperature' in metric_data and metric_data['temperature']:
                f.write(f"Temp: {metric_data['temperature']:.1f}°C | ")
            
            if 'throttled' in metric_data and metric_data['throttled']:
                f.write("⚠️ THROTTLED")
            
            f.write("\n")
    
    def log_system_snapshot(self, snapshot: Dict):
        """Log system monitoring snapshot
        
        Args:
            snapshot: System snapshot from SystemMonitor
        """
        metric_data = {
            'timestamp': snapshot['timestamp'],
            'cpu_percent': snapshot['cpu']['overall'],
            'memory_percent': snapshot['memory']['percent'],
            'temperature': snapshot.get('temperature'),
            'load_1min': snapshot['load']['load_1min']
        }
        
        if snapshot.get('throttling'):
            throttle = snapshot['throttling']
            metric_data['throttled'] = (
                throttle.get('throttled_now', False) or 
                throttle.get('under_voltage_now', False)
            )
        
        self.metrics_buffer.append(metric_data)
    
    def log_inference(self, frame_num: int, inference_time: float, fps: float):
        """Log inference results
        
        Args:
            frame_num: Frame number
            inference_time: Inference time in seconds
            fps: Current FPS
        """
        metric_data = {
            'timestamp': datetime.now().timestamp(),
            'frame': frame_num,
            'inference_time': inference_time,
            'fps': fps
        }
        self.log_metric(metric_data)
    
    def write_summary(self, summary_data: Dict):
        """Write benchmark summary
        
        Args:
            summary_data: Summary statistics
        """
        self.summary = summary_data
        
        with open(self.log_path, 'a') as f:
            f.write("\n" + "=" * 80 + "\n")
            f.write("BENCHMARK SUMMARY\n")
            f.write("=" * 80 + "\n")
            f.write(f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("Performance Metrics:\n")
            f.write(f"  Total Frames: {summary_data.get('total_frames', 0)}\n")
            f.write(f"  Average FPS: {summary_data.get('avg_fps', 0):.2f}\n")
            f.write(f"  Min FPS: {summary_data.get('min_fps', 0):.2f}\n")
            f.write(f"  Max FPS: {summary_data.get('max_fps', 0):.2f}\n")
            f.write(f"  Avg Inference Time: {summary_data.get('avg_inference_ms', 0):.1f}ms\n")
            f.write(f"  Min Inference Time: {summary_data.get('min_inference_ms', 0):.1f}ms\n")
            f.write(f"  Max Inference Time: {summary_data.get('max_inference_ms', 0):.1f}ms\n\n")
            
            f.write("System Metrics:\n")
            f.write(f"  Avg CPU: {summary_data.get('avg_cpu', 0):.1f}%\n")
            f.write(f"  Max CPU: {summary_data.get('max_cpu', 0):.1f}%\n")
            f.write(f"  Avg RAM: {summary_data.get('avg_memory', 0):.1f}%\n")
            f.write(f"  Max RAM: {summary_data.get('max_memory', 0):.1f}%\n")
            
            if summary_data.get('avg_temperature'):
                f.write(f"  Avg Temperature: {summary_data['avg_temperature']:.1f}°C\n")
                f.write(f"  Max Temperature: {summary_data.get('max_temperature', 0):.1f}°C\n")
                f.write(f"  Temperature Rise: {summary_data.get('temp_rise', 0):.1f}°C\n")
            
            if summary_data.get('throttle_events', 0) > 0:
                f.write(f"\n  ⚠️  Throttling Events: {summary_data['throttle_events']}\n")
            
            f.write("\n" + "=" * 80 + "\n")
    
    def save_json(self):
        """Save complete benchmark data as JSON"""
        data = {
            'model': self.model_name,
            'timestamp': datetime.now().isoformat(),
            'config': self.run_config,
            'metrics': self.metrics_buffer,
            'summary': self.summary
        }
        
        with open(self.json_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def get_log_path(self) -> str:
        """Get the path to the current log file"""
        return str(self.log_path)
    
    def get_json_path(self) -> str:
        """Get the path to the current JSON file"""
        return str(self.json_path)


class ConsoleLogger:
    """Simple console logger with color support"""
    
    @staticmethod
    def info(message: str):
        """Log info message"""
        print(f"ℹ️  {message}")
    
    @staticmethod
    def success(message: str):
        """Log success message"""
        print(f"✓ {message}")
    
    @staticmethod
    def warning(message: str):
        """Log warning message"""
        print(f"⚠️  {message}")
    
    @staticmethod
    def error(message: str):
        """Log error message"""
        print(f"❌ {message}")
    
    @staticmethod
    def progress(message: str):
        """Log progress message"""
        print(f"⏳ {message}")


if __name__ == '__main__':
    # Test the logger
    logger = BenchmarkLogger('test_model')
    
    config = {
        'model_path': 'models/test.onnx',
        'input_size': '640x640',
        'backend': 'ONNX Runtime',
        'input_source': 'Camera',
        'duration_seconds': 60
    }
    
    logger.write_header(config)
    
    # Log some test metrics
    for i in range(5):
        logger.log_inference(i, 0.05 + i*0.001, 20.0 - i*0.1)
    
    summary = {
        'total_frames': 5,
        'avg_fps': 19.8,
        'min_fps': 19.6,
        'max_fps': 20.0,
        'avg_inference_ms': 51.0,
        'min_inference_ms': 50.0,
        'max_inference_ms': 54.0,
        'avg_cpu': 65.3,
        'max_cpu': 78.2,
        'avg_memory': 42.1,
        'max_memory': 45.8
    }
    
    logger.write_summary(summary)
    logger.save_json()
    
    print(f"\nTest log created at: {logger.get_log_path()}")
    print(f"Test JSON created at: {logger.get_json_path()}")
