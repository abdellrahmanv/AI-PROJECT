#!/usr/bin/env python3
"""
Comparison Script for YOLOv8n vs YOLO11n Benchmark Results
Analyzes and compares log files from both models
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Tuple
import glob


class BenchmarkComparator:
    """Compare benchmark results between models"""
    
    def __init__(self):
        self.results = {}
    
    def load_json_log(self, json_path: str, model_name: str):
        """Load JSON log file
        
        Args:
            json_path: Path to JSON log file
            model_name: Name identifier for the model
        """
        with open(json_path, 'r') as f:
            data = json.load(f)
            self.results[model_name] = data
            print(f"✓ Loaded {model_name}: {json_path}")
    
    def find_latest_logs(self, log_dir: str = 'logs') -> Dict[str, str]:
        """Find latest log files for each model
        
        Args:
            log_dir: Base log directory
            
        Returns:
            Dictionary mapping model names to latest JSON files
        """
        log_path = Path(log_dir)
        latest_logs = {}
        
        for model_name in ['yolov8', 'yolov11']:
            model_dir = log_path / model_name
            if not model_dir.exists():
                continue
            
            # Find all JSON files
            json_files = list(model_dir.glob('*.json'))
            if json_files:
                # Get most recent
                latest = max(json_files, key=lambda p: p.stat().st_mtime)
                latest_logs[model_name] = str(latest)
        
        return latest_logs
    
    def compare(self) -> Dict:
        """Compare loaded benchmark results
        
        Returns:
            Comparison dictionary with metrics
        """
        if len(self.results) < 2:
            print("⚠️  Need at least 2 benchmark results to compare")
            return {}
        
        comparison = {
            'models': list(self.results.keys()),
            'performance': {},
            'system': {},
            'winner': {}
        }
        
        # Extract summaries
        summaries = {name: data.get('summary', {}) 
                    for name, data in self.results.items()}
        
        # Compare FPS
        fps_data = {name: summary.get('avg_fps', 0) 
                   for name, summary in summaries.items()}
        
        comparison['performance']['fps'] = fps_data
        comparison['winner']['fps'] = max(fps_data, key=fps_data.get)
        comparison['performance']['fps_improvement'] = self._calculate_improvement(fps_data)
        
        # Compare inference time
        inference_data = {name: summary.get('avg_inference_ms', 0) 
                         for name, summary in summaries.items()}
        
        comparison['performance']['inference_ms'] = inference_data
        comparison['winner']['inference'] = min(inference_data, key=inference_data.get)
        comparison['performance']['inference_improvement'] = self._calculate_improvement(
            inference_data, lower_is_better=True
        )
        
        # Compare CPU usage
        cpu_data = {name: summary.get('avg_cpu', 0) 
                   for name, summary in summaries.items()}
        
        comparison['system']['cpu'] = cpu_data
        comparison['winner']['cpu'] = min(cpu_data, key=cpu_data.get)
        
        # Compare memory
        memory_data = {name: summary.get('avg_memory', 0) 
                      for name, summary in summaries.items()}
        
        comparison['system']['memory'] = memory_data
        comparison['winner']['memory'] = min(memory_data, key=memory_data.get)
        
        # Compare temperature
        temp_data = {name: summary.get('avg_temperature') 
                    for name, summary in summaries.items() 
                    if summary.get('avg_temperature')}
        
        if temp_data:
            comparison['system']['temperature'] = temp_data
            comparison['winner']['temperature'] = min(temp_data, key=temp_data.get)
        
        # Throttling events
        throttle_data = {name: summary.get('throttle_events', 0) 
                        for name, summary in summaries.items()}
        
        comparison['system']['throttle_events'] = throttle_data
        
        return comparison
    
    def _calculate_improvement(self, data: Dict[str, float], 
                               lower_is_better: bool = False) -> Dict:
        """Calculate percentage improvement between models
        
        Args:
            data: Dictionary of model names to values
            lower_is_better: If True, lower values are better
            
        Returns:
            Dictionary with improvement calculations
        """
        if len(data) != 2:
            return {}
        
        models = list(data.keys())
        values = list(data.values())
        
        if lower_is_better:
            # For metrics like latency where lower is better
            improvement_pct = ((values[0] - values[1]) / values[0]) * 100
            better_model = models[1] if values[1] < values[0] else models[0]
        else:
            # For metrics like FPS where higher is better
            improvement_pct = ((values[1] - values[0]) / values[0]) * 100
            better_model = models[1] if values[1] > values[0] else models[0]
        
        return {
            'percentage': abs(improvement_pct),
            'better_model': better_model,
            'direction': 'improvement' if improvement_pct > 0 else 'regression'
        }
    
    def print_comparison(self, comparison: Dict):
        """Print formatted comparison report
        
        Args:
            comparison: Comparison dictionary
        """
        print("\n" + "=" * 80)
        print("BENCHMARK COMPARISON REPORT")
        print("=" * 80)
        
        models = comparison['models']
        print(f"\nComparing: {' vs '.join(models)}")
        
        # Performance comparison
        print("\n" + "-" * 80)
        print("PERFORMANCE METRICS")
        print("-" * 80)
        
        perf = comparison['performance']
        
        # FPS
        print(f"\n📊 Average FPS:")
        for model in models:
            fps = perf['fps'][model]
            is_winner = (comparison['winner']['fps'] == model)
            marker = "🏆" if is_winner else "  "
            print(f"  {marker} {model:12s}: {fps:6.2f} FPS")
        
        if 'fps_improvement' in perf and perf['fps_improvement']:
            imp = perf['fps_improvement']
            print(f"  → {imp['better_model']} is {imp['percentage']:.1f}% faster")
        
        # Inference time
        print(f"\n⏱️  Average Inference Time:")
        for model in models:
            inf = perf['inference_ms'][model]
            is_winner = (comparison['winner']['inference'] == model)
            marker = "🏆" if is_winner else "  "
            print(f"  {marker} {model:12s}: {inf:6.1f} ms")
        
        if 'inference_improvement' in perf and perf['inference_improvement']:
            imp = perf['inference_improvement']
            print(f"  → {imp['better_model']} is {imp['percentage']:.1f}% faster")
        
        # System metrics
        print("\n" + "-" * 80)
        print("SYSTEM RESOURCE USAGE")
        print("-" * 80)
        
        sys_metrics = comparison['system']
        
        # CPU
        print(f"\n💻 Average CPU Usage:")
        for model in models:
            cpu = sys_metrics['cpu'][model]
            is_winner = (comparison['winner']['cpu'] == model)
            marker = "🏆" if is_winner else "  "
            print(f"  {marker} {model:12s}: {cpu:5.1f}%")
        
        # Memory
        print(f"\n🧠 Average Memory Usage:")
        for model in models:
            mem = sys_metrics['memory'][model]
            is_winner = (comparison['winner']['memory'] == model)
            marker = "🏆" if is_winner else "  "
            print(f"  {marker} {model:12s}: {mem:5.1f}%")
        
        # Temperature
        if 'temperature' in sys_metrics:
            print(f"\n🌡️  Average Temperature:")
            for model in models:
                if model in sys_metrics['temperature']:
                    temp = sys_metrics['temperature'][model]
                    is_winner = (comparison['winner'].get('temperature') == model)
                    marker = "🏆" if is_winner else "  "
                    print(f"  {marker} {model:12s}: {temp:5.1f}°C")
        
        # Throttling
        print(f"\n⚠️  Throttling Events:")
        for model in models:
            throttle = sys_metrics['throttle_events'][model]
            marker = "✓" if throttle == 0 else "⚠️ "
            print(f"  {marker} {model:12s}: {throttle} events")
        
        # Overall winner
        print("\n" + "=" * 80)
        print("OVERALL ASSESSMENT")
        print("=" * 80)
        
        # Count wins
        wins = {model: 0 for model in models}
        for category, winner in comparison['winner'].items():
            if winner in wins:
                wins[winner] += 1
        
        print(f"\nCategory Wins:")
        for model, count in wins.items():
            print(f"  {model:12s}: {count} categories")
        
        overall_winner = max(wins, key=wins.get)
        print(f"\n🏆 Overall Winner: {overall_winner}")
        
        print("\n" + "=" * 80)
    
    def save_comparison(self, comparison: Dict, output_path: str):
        """Save comparison to JSON file
        
        Args:
            comparison: Comparison dictionary
            output_path: Output file path
        """
        with open(output_path, 'w') as f:
            json.dump(comparison, f, indent=2)
        print(f"\n✓ Comparison saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Compare YOLOv8n and YOLO11n benchmark results'
    )
    parser.add_argument('--yolov8', type=str, default=None,
                       help='Path to YOLOv8 JSON log file')
    parser.add_argument('--yolov11', type=str, default=None,
                       help='Path to YOLO11 JSON log file')
    parser.add_argument('--log-dir', type=str, default='logs',
                       help='Base log directory (default: logs)')
    parser.add_argument('--auto', action='store_true',
                       help='Automatically find and compare latest logs')
    parser.add_argument('--output', type=str, default='comparison_result.json',
                       help='Output file for comparison (default: comparison_result.json)')
    
    args = parser.parse_args()
    
    comparator = BenchmarkComparator()
    
    if args.auto or (not args.yolov8 and not args.yolov11):
        # Auto-find latest logs
        print("🔍 Searching for latest benchmark logs...")
        latest_logs = comparator.find_latest_logs(args.log_dir)
        
        if len(latest_logs) < 2:
            print("❌ Could not find logs for both models")
            print(f"   Found: {list(latest_logs.keys())}")
            print(f"   Please run benchmarks first or specify log files manually")
            return
        
        # Load found logs
        for model_name, log_path in latest_logs.items():
            comparator.load_json_log(log_path, model_name)
    
    else:
        # Load specified logs
        if args.yolov8:
            if not Path(args.yolov8).exists():
                print(f"❌ YOLOv8 log not found: {args.yolov8}")
                return
            comparator.load_json_log(args.yolov8, 'yolov8')
        
        if args.yolov11:
            if not Path(args.yolov11).exists():
                print(f"❌ YOLO11 log not found: {args.yolov11}")
                return
            comparator.load_json_log(args.yolov11, 'yolov11')
    
    # Perform comparison
    comparison = comparator.compare()
    
    if comparison:
        # Print report
        comparator.print_comparison(comparison)
        
        # Save to file
        comparator.save_comparison(comparison, args.output)


if __name__ == '__main__':
    main()
