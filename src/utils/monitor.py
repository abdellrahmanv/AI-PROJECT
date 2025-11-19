"""
System Monitoring Module for Raspberry Pi 4B
Tracks CPU usage, RAM, temperature, and throttling status
"""

import psutil
import subprocess
import time
from typing import Dict, Optional


class SystemMonitor:
    """Monitor system resources on Raspberry Pi"""
    
    def __init__(self):
        self.is_raspberry_pi = self._check_raspberry_pi()
        self.initial_temp = self.get_cpu_temp() if self.is_raspberry_pi else None
        
    def _check_raspberry_pi(self) -> bool:
        """Check if running on Raspberry Pi"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                return 'Raspberry Pi' in cpuinfo or 'BCM' in cpuinfo
        except FileNotFoundError:
            return False
    
    def get_cpu_percent(self, per_core: bool = True) -> Dict:
        """Get CPU usage percentage
        
        Args:
            per_core: If True, return per-core usage
            
        Returns:
            Dictionary with CPU usage information
        """
        if per_core:
            per_cpu = psutil.cpu_percent(interval=0.1, percpu=True)
            return {
                'overall': psutil.cpu_percent(interval=0),
                'cores': per_cpu,
                'core_count': len(per_cpu)
            }
        else:
            return {
                'overall': psutil.cpu_percent(interval=0.1)
            }
    
    def get_memory_usage(self) -> Dict:
        """Get RAM usage statistics
        
        Returns:
            Dictionary with memory information
        """
        mem = psutil.virtual_memory()
        return {
            'total_mb': mem.total / (1024 * 1024),
            'used_mb': mem.used / (1024 * 1024),
            'available_mb': mem.available / (1024 * 1024),
            'percent': mem.percent
        }
    
    def get_cpu_temp(self) -> Optional[float]:
        """Get CPU temperature in Celsius
        
        Returns:
            Temperature in Celsius or None if unavailable
        """
        if not self.is_raspberry_pi:
            return None
            
        try:
            # Try vcgencmd first (Raspberry Pi specific)
            result = subprocess.run(
                ['vcgencmd', 'measure_temp'],
                capture_output=True,
                text=True,
                timeout=1
            )
            if result.returncode == 0:
                # Output format: temp=42.8'C
                temp_str = result.stdout.strip()
                temp = float(temp_str.split('=')[1].split("'")[0])
                return temp
        except (FileNotFoundError, subprocess.TimeoutExpired, IndexError, ValueError):
            pass
        
        try:
            # Fallback to thermal_zone
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = float(f.read().strip()) / 1000.0
                return temp
        except (FileNotFoundError, ValueError):
            return None
    
    def get_throttling_status(self) -> Optional[Dict]:
        """Check if Pi is being throttled
        
        Returns:
            Dictionary with throttling status or None if unavailable
        """
        if not self.is_raspberry_pi:
            return None
            
        try:
            result = subprocess.run(
                ['vcgencmd', 'get_throttled'],
                capture_output=True,
                text=True,
                timeout=1
            )
            if result.returncode == 0:
                # Output format: throttled=0x0
                throttled_hex = result.stdout.strip().split('=')[1]
                throttled_value = int(throttled_hex, 16)
                
                return {
                    'raw_value': throttled_hex,
                    'under_voltage_now': bool(throttled_value & 0x1),
                    'freq_capped_now': bool(throttled_value & 0x2),
                    'throttled_now': bool(throttled_value & 0x4),
                    'soft_temp_limit_now': bool(throttled_value & 0x8),
                    'under_voltage_occurred': bool(throttled_value & 0x10000),
                    'freq_capped_occurred': bool(throttled_value & 0x20000),
                    'throttled_occurred': bool(throttled_value & 0x40000),
                    'soft_temp_limit_occurred': bool(throttled_value & 0x80000)
                }
        except (FileNotFoundError, subprocess.TimeoutExpired, IndexError, ValueError):
            return None
    
    def get_system_load(self) -> Dict:
        """Get system load averages
        
        Returns:
            Dictionary with load averages
        """
        load1, load5, load15 = psutil.getloadavg()
        cpu_count = psutil.cpu_count()
        
        return {
            'load_1min': load1,
            'load_5min': load5,
            'load_15min': load15,
            'load_1min_percent': (load1 / cpu_count) * 100 if cpu_count else 0
        }
    
    def get_full_snapshot(self) -> Dict:
        """Get complete system snapshot
        
        Returns:
            Dictionary with all system metrics
        """
        snapshot = {
            'timestamp': time.time(),
            'cpu': self.get_cpu_percent(per_core=True),
            'memory': self.get_memory_usage(),
            'load': self.get_system_load(),
            'temperature': self.get_cpu_temp(),
            'throttling': self.get_throttling_status()
        }
        
        return snapshot
    
    def format_snapshot(self, snapshot: Dict) -> str:
        """Format snapshot as human-readable string
        
        Args:
            snapshot: System snapshot dictionary
            
        Returns:
            Formatted string
        """
        lines = []
        lines.append(f"CPU: {snapshot['cpu']['overall']:.1f}%")
        
        if 'cores' in snapshot['cpu']:
            cores_str = ', '.join([f"{c:.0f}%" for c in snapshot['cpu']['cores']])
            lines.append(f"  Cores: [{cores_str}]")
        
        mem = snapshot['memory']
        lines.append(f"RAM: {mem['used_mb']:.0f}/{mem['total_mb']:.0f} MB ({mem['percent']:.1f}%)")
        
        if snapshot['temperature']:
            lines.append(f"Temp: {snapshot['temperature']:.1f}°C")
        
        load = snapshot['load']
        lines.append(f"Load: {load['load_1min']:.2f} ({load['load_1min_percent']:.0f}%)")
        
        if snapshot['throttling']:
            throttle = snapshot['throttling']
            if throttle['throttled_now'] or throttle['under_voltage_now']:
                lines.append("⚠️  THROTTLING ACTIVE")
        
        return '\n'.join(lines)


if __name__ == '__main__':
    # Test the monitor
    monitor = SystemMonitor()
    print("System Monitor Test")
    print("=" * 50)
    
    for i in range(3):
        snapshot = monitor.get_full_snapshot()
        print(f"\nSnapshot {i+1}:")
        print(monitor.format_snapshot(snapshot))
        time.sleep(1)
