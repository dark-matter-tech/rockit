# Rockit Compiler — Install Script for Windows
# Dark Matter Tech
#
# Usage (PowerShell):
#   iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.ps1 | iex
#
# Or run locally:
#   .\install.ps1

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/Dark-Matter/moon.git"
$Prefix = if ($env:ROCKIT_PREFIX) { $env:ROCKIT_PREFIX } else { "$env:LOCALAPPDATA\Rockit" }
$InstallDir = "$Prefix\bin"
$LibDir = "$Prefix\lib\rockit\runtime"
$BuildDir = "$env:TEMP\rockit-install-$PID"

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "==> $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

# --- Check prerequisites ---
Info "Checking prerequisites..."

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Fail "Swift 5.9+ is required. Install from https://swift.org/download"
}
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    Fail "Clang is required. Install LLVM from https://releases.llvm.org"
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is required."
}

$SwiftVersion = (swift --version 2>&1 | Select-Object -First 1)
Ok "Swift: $SwiftVersion"
$ClangVersion = (clang --version 2>&1 | Select-Object -First 1)
Ok "Clang: $ClangVersion"

# --- Clone ---
Info "Downloading Rockit compiler..."
if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
git clone --depth 1 $RepoUrl $BuildDir 2>$null
if ($LASTEXITCODE -ne 0) { Fail "Failed to clone repository." }

Push-Location "$BuildDir\RockitCompiler"

# --- Build ---
Info "Building (release mode)..."
swift build -c release
if ($LASTEXITCODE -ne 0) { Fail "Build failed." }

# --- Install ---
Info "Installing to $InstallDir..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

Copy-Item ".build\release\rockit.exe" "$InstallDir\rockit.exe"
Copy-Item "Runtime\rockit_runtime.c" "$LibDir\rockit_runtime.c"
Copy-Item "Runtime\rockit_runtime.h" "$LibDir\rockit_runtime.h"

Pop-Location

# --- Add to PATH ---
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$InstallDir", "User")
    Ok "Added $InstallDir to user PATH."
    Write-Host "  Restart your terminal for PATH changes to take effect."
}

# --- Cleanup ---
Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue

Ok "Installed successfully!"
Write-Host ""
Write-Host "  Rockit is ready. Try:"
Write-Host ""
Write-Host "    rockit run hello.rok          # bytecode (interpreted)"
Write-Host "    rockit run-native hello.rok   # native (compiled via LLVM)"
Write-Host "    rockit repl                   # interactive REPL"
Write-Host ""
Write-Host "  Uninstall: Remove-Item -Recurse '$Prefix'"
Write-Host ""
