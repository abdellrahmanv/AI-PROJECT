# Python 3.13 Compatibility Issue - CRITICAL FIX

## The Problem

You're seeing this error:
```
error: 'uint32_t' was not declared in this scope
```

**This is because Python 3.13 is too new!**

The ONNX package (required by Ultralytics) doesn't compile on Python 3.13 yet. This is a known issue with protobuf compilation.

## The Solution

### Option 1: Install Python 3.11 (RECOMMENDED)

```bash
# Install Python 3.11
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3.11-pip

# Verify installation
python3.11 --version

# Remove old virtual environment
cd ~/AI-PROJECT
rm -rf venv

# Run setup again (will now use Python 3.11)
./setup/setup_new.sh
```

### Option 2: Use system Python 3.11 if already installed

```bash
# Check what Python versions you have
ls /usr/bin/python3*

# If you see python3.11, just remove venv and re-run setup
cd ~/AI-PROJECT
rm -rf venv
./setup/setup_new.sh  # Will automatically detect and use 3.11
```

## Why This Happened

- Raspberry Pi OS Bookworm might have Python 3.13 as default
- Python 3.13 was released recently (October 2024)
- ONNX package hasn't been updated for 3.13 yet
- Protobuf (dependency of ONNX) has compilation issues with Python 3.13

## Supported Python Versions

- ✅ **Python 3.11** (BEST - fully tested)
- ✅ **Python 3.12** (Good - tested)
- ✅ **Python 3.10** (Good - tested)
- ❌ **Python 3.13** (TOO NEW - doesn't work!)

## After Installing Python 3.11

The updated setup script will automatically:
1. Detect Python 3.11
2. Use it instead of Python 3.13
3. Create virtual environment with 3.11
4. Install all packages successfully

Then you can run benchmarks normally:
```bash
source venv/bin/activate
python3 src/run_yolov8_new.py --duration 60 --format ncnn
```

## Alternative: Wait for ONNX Update

If you don't want to install Python 3.11, you can wait for ONNX to release a version compatible with Python 3.13. But this might take weeks or months.

## References

- [ONNX Issue Tracker](https://github.com/onnx/onnx/issues)
- [Protobuf Python 3.13 compatibility](https://github.com/protocolbuffers/protobuf/issues)
