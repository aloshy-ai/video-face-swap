#!/bin/bash
# Optimize Git LFS checkout by selectively pulling only required model files
# Usage: ./optimize-git-lfs.sh [--only-models]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔄 Optimizing Git LFS checkout..."

# Make sure Git LFS is installed
if ! command -v git-lfs &> /dev/null; then
    echo "❌ Git LFS is not installed. Please install it first."
    echo "   macOS: brew install git-lfs"
    echo "   Linux: apt-get install git-lfs"
    echo "   Windows: https://git-lfs.github.com/"
    exit 1
fi

# List of critical model files that should always be pulled
CRITICAL_MODELS=(
    "models/inswapper_128.onnx"
    "models/detection_Resnet50_Final.pth"
)

# Check if we need to do a full clone or just update models
if [[ "$1" == "--only-models" ]]; then
    echo "🔍 Only pulling model files..."
    
    # Pull only critical model files
    for model in "${CRITICAL_MODELS[@]}"; do
        echo "📥 Pulling $model..."
        if ! git -C "${REPO_ROOT}" lfs pull --include="$model"; then
            echo "⚠️  Warning: Could not pull $model, it may not exist in the repository"
        fi
    done
else
    # Start with a clean slate - avoid partially checked out LFS files
    echo "🧹 Cleaning up partial LFS checkouts..."
    git -C "${REPO_ROOT}" lfs uninstall
    git -C "${REPO_ROOT}" lfs install
    
    # Set LFS to not automatically download LFS files on checkout/clone
    export GIT_LFS_SKIP_SMUDGE=1
    
    # Pull only critical model files
    for model in "${CRITICAL_MODELS[@]}"; do
        echo "📥 Pulling $model..."
        if ! git -C "${REPO_ROOT}" lfs pull --include="$model"; then
            echo "⚠️  Warning: Could not pull $model, it may not exist in the repository"
        fi
    done
    
    echo "✅ Git LFS optimization complete. Only critical models were downloaded."
    echo "   If you need additional LFS files, use: git lfs pull --include=\"path/to/file\""
fi

# List downloaded LFS files
echo "📋 Downloaded LFS files:"
find "${REPO_ROOT}" -type f -not -path "*/\.*" -size +1M -exec ls -lh {} \;

echo "✨ Done!"
