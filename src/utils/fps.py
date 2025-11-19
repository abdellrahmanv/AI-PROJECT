"""
FPS Calculator Module
Provides accurate FPS calculation with rolling average
"""

import time
from collections import deque
from typing import Optional


class FPSCalculator:
    """Calculate FPS with rolling average"""
    
    def __init__(self, window_size: int = 30):
        """Initialize FPS calculator
        
        Args:
            window_size: Number of frames to use for rolling average
        """
        self.window_size = window_size
        self.frame_times = deque(maxlen=window_size)
        self.frame_count = 0
        self.start_time = None
        self.last_frame_time = None
        
    def start(self):
        """Start FPS calculation"""
        self.start_time = time.time()
        self.last_frame_time = self.start_time
        self.frame_count = 0
        self.frame_times.clear()
    
    def update(self) -> float:
        """Update FPS calculation with new frame
        
        Returns:
            Current FPS (rolling average)
        """
        current_time = time.time()
        
        if self.last_frame_time is not None:
            frame_time = current_time - self.last_frame_time
            self.frame_times.append(frame_time)
        
        self.last_frame_time = current_time
        self.frame_count += 1
        
        return self.get_fps()
    
    def get_fps(self) -> float:
        """Get current FPS based on rolling window
        
        Returns:
            Current FPS
        """
        if not self.frame_times:
            return 0.0
        
        avg_frame_time = sum(self.frame_times) / len(self.frame_times)
        
        if avg_frame_time > 0:
            return 1.0 / avg_frame_time
        return 0.0
    
    def get_average_fps(self) -> float:
        """Get overall average FPS since start
        
        Returns:
            Overall average FPS
        """
        if self.start_time is None or self.frame_count == 0:
            return 0.0
        
        elapsed = time.time() - self.start_time
        if elapsed > 0:
            return self.frame_count / elapsed
        return 0.0
    
    def get_frame_count(self) -> int:
        """Get total frame count"""
        return self.frame_count
    
    def get_elapsed_time(self) -> float:
        """Get elapsed time since start
        
        Returns:
            Elapsed time in seconds
        """
        if self.start_time is None:
            return 0.0
        return time.time() - self.start_time
    
    def reset(self):
        """Reset FPS calculator"""
        self.frame_times.clear()
        self.frame_count = 0
        self.start_time = None
        self.last_frame_time = None


class InferenceTimer:
    """Timer for measuring inference time"""
    
    def __init__(self):
        self.start_time = None
        self.times = []
        
    def start(self):
        """Start timing"""
        self.start_time = time.time()
    
    def stop(self) -> float:
        """Stop timing and record
        
        Returns:
            Elapsed time in seconds
        """
        if self.start_time is None:
            return 0.0
        
        elapsed = time.time() - self.start_time
        self.times.append(elapsed)
        self.start_time = None
        return elapsed
    
    def get_last_time(self) -> Optional[float]:
        """Get last recorded time
        
        Returns:
            Last inference time in seconds, or None
        """
        if not self.times:
            return None
        return self.times[-1]
    
    def get_average(self) -> float:
        """Get average inference time
        
        Returns:
            Average time in seconds
        """
        if not self.times:
            return 0.0
        return sum(self.times) / len(self.times)
    
    def get_min(self) -> Optional[float]:
        """Get minimum inference time
        
        Returns:
            Minimum time in seconds, or None
        """
        if not self.times:
            return None
        return min(self.times)
    
    def get_max(self) -> Optional[float]:
        """Get maximum inference time
        
        Returns:
            Maximum time in seconds, or None
        """
        if not self.times:
            return None
        return max(self.times)
    
    def get_count(self) -> int:
        """Get number of recorded times"""
        return len(self.times)
    
    def reset(self):
        """Reset timer"""
        self.start_time = None
        self.times.clear()


if __name__ == '__main__':
    # Test FPS calculator
    print("Testing FPS Calculator...")
    
    fps_calc = FPSCalculator(window_size=10)
    fps_calc.start()
    
    # Simulate frame processing
    for i in range(30):
        time.sleep(0.033)  # ~30 FPS
        fps = fps_calc.update()
        if i % 10 == 0:
            print(f"Frame {i}: Current FPS: {fps:.2f}, Average FPS: {fps_calc.get_average_fps():.2f}")
    
    print(f"\nFinal Statistics:")
    print(f"Total Frames: {fps_calc.get_frame_count()}")
    print(f"Elapsed Time: {fps_calc.get_elapsed_time():.2f}s")
    print(f"Average FPS: {fps_calc.get_average_fps():.2f}")
    
    # Test inference timer
    print("\n" + "="*50)
    print("Testing Inference Timer...")
    
    timer = InferenceTimer()
    
    for i in range(5):
        timer.start()
        time.sleep(0.05)  # Simulate 50ms inference
        elapsed = timer.stop()
        print(f"Inference {i+1}: {elapsed*1000:.1f}ms")
    
    print(f"\nTimer Statistics:")
    print(f"Count: {timer.get_count()}")
    print(f"Average: {timer.get_average()*1000:.1f}ms")
    print(f"Min: {timer.get_min()*1000:.1f}ms")
    print(f"Max: {timer.get_max()*1000:.1f}ms")
