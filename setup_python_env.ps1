Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Korean Learning App - Python Setup Script  " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# 1. Check Python
$pythonInstalled = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonInstalled) {
    Write-Error "Python is not installed or not in PATH. Please install Python 3.8 - 3.12 and try again."
    Exit 1
}

$pythonVersion = python --version
Write-Host "Found Python: $pythonVersion" -ForegroundColor Cyan

# 2. Create Virtual Environment
if (-not (Test-Path -Path ".venv")) {
    Write-Host "Creating virtual environment in .venv..." -ForegroundColor Yellow
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create virtual environment."
        Exit 1
    }
    Write-Host "Virtual environment created successfully." -ForegroundColor Green
} else {
    Write-Host "Virtual environment .venv already exists." -ForegroundColor Cyan
}

# 3. Upgrade pip & setuptools
Write-Host "Upgrading pip and setuptools..." -ForegroundColor Yellow
& .venv\Scripts\python.exe -m pip install --upgrade pip setuptools
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to upgrade pip."
    Exit 1
}

# 4. Install Torch and Torchaudio (CPU only)
Write-Host "Installing PyTorch and Torchaudio (CPU-only version)..." -ForegroundColor Yellow
& .venv\Scripts\python.exe -m pip install torch==2.1.2+cpu torchaudio==2.1.2+cpu --index-url https://download.pytorch.org/whl/cpu
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install PyTorch/Torchaudio."
    Exit 1
}

# 5. Install other requirements
Write-Host "Installing dependencies from requirements.txt..." -ForegroundColor Yellow
& .venv\Scripts\python.exe -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install requirements."
    Exit 1
}

# 6. Pre-fetch TTS Models
Write-Host "Pre-fetching offline TTS models (MMS and Sherpa KSS)..." -ForegroundColor Yellow
& .venv\Scripts\python.exe download_models.py

Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Python environment setup complete!         " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
