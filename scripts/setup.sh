#!/bin/bash
# Setup script for development environment
# 
# This script:
# 1. Installs Git LFS if needed
# 2. Optimizes Git LFS usage for this repository
# 3. Sets up pre-commit hooks
# 4. Creates a Python virtual environment (optional)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🚀 Setting up development environment for Video Face Swap..."

# Step 1: Check and install Git LFS
if ! command -v git-lfs &> /dev/null; then
    echo "🔍 Git LFS not found. Attempting to install..."
    
    if command -v brew &> /dev/null; then
        echo "🍺 Installing Git LFS with Homebrew..."
        brew install git-lfs
    elif command -v apt-get &> /dev/null; then
        echo "📦 Installing Git LFS with apt..."
        sudo apt-get update
        sudo apt-get install -y git-lfs
    elif command -v yum &> /dev/null; then
        echo "📦 Installing Git LFS with yum..."
        sudo yum install -y git-lfs
    else
        echo "❌ Could not automatically install Git LFS."
        echo "   Please install it manually: https://git-lfs.github.com/"
        exit 1
    fi
fi

# Step 2: Set up Git LFS
echo "⚙️ Setting up Git LFS..."
git lfs install

# Step 3: Run Git LFS optimization
echo "🔄 Optimizing Git LFS..."
"${REPO_ROOT}/scripts/optimize-git-lfs.sh"

# Step 4: Set up pre-commit hook
echo "🪝 Setting up pre-commit hook..."
mkdir -p "${REPO_ROOT}/.git/hooks"
ln -sf "../../scripts/git-hooks/pre-commit" "${REPO_ROOT}/.git/hooks/pre-commit"
chmod +x "${REPO_ROOT}/.git/hooks/pre-commit"
echo "✅ Pre-commit hook installed."

# Step 5: Offer to create Python virtual environment
echo ""
read -p "📦 Would you like to create a Python virtual environment? (y/n) " create_venv

if [[ "$create_venv" =~ ^[Yy]$ ]]; then
    echo "🐍 Creating Python virtual environment..."
    
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 not found. Please install Python 3 and try again."
        exit 1
    fi
    
    # Create virtual environment
    python3 -m venv "${REPO_ROOT}/.venv"
    
    # Activate virtual environment
    source "${REPO_ROOT}/.venv/bin/activate"
    
    # Install dependencies
    pip install --upgrade pip
    pip install -r "${REPO_ROOT}/requirements.txt"
    
    echo "✅ Virtual environment created and dependencies installed."
    echo "   To activate the virtual environment, run:"
    echo "   source .venv/bin/activate"
fi

echo ""
echo "✨ Setup complete! You're ready to develop."
echo ""
echo "Useful commands:"
echo "  • ./scripts/optimize-git-lfs.sh      - Optimize Git LFS usage"
echo "  • ./scripts/run_tests.sh             - Run tests"
echo "  • docker build -t video-face-swap .  - Build Docker image"
echo ""
