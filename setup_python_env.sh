#!/bin/bash
set -e

echo "============================================="
echo "  Korean Learning App - Python Setup Script  "
echo "============================================="

# 1. Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed or not in PATH. Please install Python 3.8 - 3.12 and try again."
    exit 1
fi

python3_version=$(python3 --version)
echo "Found Python: $python3_version"

# 2. Create Virtual Environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment in .venv..."
    python3 -m venv .venv
    echo "Virtual environment created successfully."
else
    echo "Virtual environment .venv already exists."
fi

# 3. Upgrade pip & setuptools
echo "Upgrading pip and setuptools..."
.venv/bin/python -m pip install --upgrade pip setuptools

# 4. Install Torch and Torchaudio (CPU only)
echo "Installing PyTorch and Torchaudio (CPU-only version)..."
.venv/bin/python -m pip install torch==2.1.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cpu

# 5. Install other requirements
echo "Installing dependencies from requirements.txt..."
.venv/bin/python -m pip install -r requirements.txt

# 6. Pre-fetch TTS Models
echo "Pre-fetching offline TTS models (MMS and Sherpa KSS)..."
.venv/bin/python download_models.py

echo "============================================="
echo "  Python environment setup complete!         "
echo "============================================="
