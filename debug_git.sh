#!/bin/bash
#
# Debug script to check Git status and source files
#

echo "=========================================="
echo "Git Repository Debug"
echo "=========================================="
echo ""

# Check current directory
echo "Current directory:"
pwd
echo ""

# Check git status
echo "Git status:"
git status
echo ""

# Check git remote
echo "Git remote:"
git remote -v
echo ""

# Check current branch and commits
echo "Current branch:"
git branch -vv
echo ""

# Check what files Git knows about in src/
echo "Files in src/ according to Git:"
git ls-tree -r HEAD --name-only src/ || echo "ERROR: Could not list files"
echo ""

# Check what actually exists in src/
echo "Files actually in src/ directory:"
if [ -d "src" ]; then
    ls -laR src/
else
    echo "ERROR: src/ directory does not exist!"
fi
echo ""

# Check if any src files exist locally
echo "Checking individual files:"
for file in src/run_yolov8.py src/run_yolov11.py src/compare_results.py src/utils/monitor.py src/utils/logger.py src/utils/fps.py; do
    if [ -f "$file" ]; then
        echo "[OK] $file exists ($(wc -l < "$file") lines)"
    else
        echo "[MISSING] $file"
    fi
done
echo ""

# Check git log
echo "Last 5 commits:"
git log --oneline -5
echo ""

# Check if working directory is clean
echo "Checking for uncommitted changes:"
git diff --stat
echo ""

# Try to fetch latest
echo "Fetching from remote:"
git fetch origin
echo ""

# Check if behind remote
echo "Comparing with remote:"
git status -uno
echo ""

echo "=========================================="
echo "Debug complete"
echo "=========================================="
echo ""
echo "If files are missing, try:"
echo "  git reset --hard origin/main"
echo "  git pull origin main"
