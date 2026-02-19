# Rockit — Windows Install Script
# Dark Matter Tech
#
# Usage (PowerShell):
#   irm https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.ps1 | iex
#
# Or run locally:
#   .\install.ps1

$ErrorActionPreference = "Stop"

$VERSION = "0.1.0"
$GITEA = "https://rustygits.com"
$REPO = "Dark-Matter/moon"
$REPO_FUEL = "Dark-Matter/fuel"
$INSTALL_DIR = "$env:LOCALAPPDATA\Rockit\bin"
$SHARE_DIR = "$env:LOCALAPPDATA\Rockit\share\rockit"

function Write-Info($msg) { Write-Host "==> $msg" }
function Write-Ok($msg) { Write-Host "==> $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  Rockit Installer v$VERSION"
Write-Host "  Dark Matter Tech"
Write-Host ""

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { Write-Fail "32-bit Windows is not supported" }

$platform = "windows-$arch"
$archive = "rockit-$VERSION-$platform.zip"
$url = "$GITEA/$REPO/releases/download/v$VERSION/$archive"

# Check for clang
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    Write-Fail "clang is required.`nInstall LLVM from https://releases.llvm.org or via: winget install LLVM.LLVM"
}

# Try prebuilt binary
Write-Info "Checking for prebuilt binary ($platform)..."

$tmp = Join-Path $env:TEMP "rockit-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$downloaded = $false
try {
    Invoke-WebRequest -Uri $url -OutFile "$tmp\$archive" -ErrorAction Stop
    $downloaded = $true
} catch {
    # No prebuilt available
}

if ($downloaded) {
    Write-Info "Installing Rockit $VERSION..."
    Expand-Archive -Path "$tmp\$archive" -DestinationPath $tmp -Force

    $extracted = "$tmp\rockit-$VERSION-$platform\rockit"

    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $SHARE_DIR | Out-Null

    Copy-Item "$extracted\bin\rockit.exe" "$INSTALL_DIR\rockit.exe" -Force
    Copy-Item "$extracted\bin\fuel.exe" "$INSTALL_DIR\fuel.exe" -Force
    Copy-Item "$extracted\share\rockit\rockit_runtime.c" "$SHARE_DIR\rockit_runtime.c" -Force
    Copy-Item "$extracted\share\rockit\rockit_runtime.h" "$SHARE_DIR\rockit_runtime.h" -Force

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Write-Ok "Installed Rockit $VERSION ($platform)"
} else {
    # Build from source
    Write-Info "No prebuilt binary for $platform, building from source..."

    if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
        Write-Fail "Swift 5.9+ is required to build from source.`nInstall from https://swift.org/download"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail "Git is required."
    }

    # Clone compiler
    Write-Info "Downloading Rockit compiler..."
    git clone --depth 1 --branch develop "$GITEA/$REPO.git" "$tmp\moon" 2>&1 | Select-Object -Last 1

    # Build Stage 1
    Write-Info "Building compiler (this takes a minute)..."
    Push-Location "$tmp\moon\RockitCompiler"
    swift run rockit build-native Stage1\command.rok
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "Compiler build failed." }
    Pop-Location

    # Clone and build Fuel
    Write-Info "Building Fuel package manager..."
    git clone --depth 1 --branch develop "$GITEA/$REPO_FUEL.git" "$tmp\fuel" 2>&1 | Select-Object -Last 1
    & "$tmp\moon\RockitCompiler\Stage1\command.exe" build-native "$tmp\fuel\src\fuel.rok" -o "$tmp\fuel\fuel.exe" --runtime-path "$tmp\moon\RockitCompiler\Runtime\rockit_runtime.c"

    # Install
    Write-Info "Installing to $INSTALL_DIR..."
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $SHARE_DIR | Out-Null

    Copy-Item "$tmp\moon\RockitCompiler\Stage1\command.exe" "$INSTALL_DIR\rockit.exe" -Force
    Copy-Item "$tmp\fuel\fuel.exe" "$INSTALL_DIR\fuel.exe" -Force
    Copy-Item "$tmp\moon\RockitCompiler\Runtime\rockit_runtime.c" "$SHARE_DIR\rockit_runtime.c" -Force
    Copy-Item "$tmp\moon\RockitCompiler\Runtime\rockit_runtime.h" "$SHARE_DIR\rockit_runtime.h" -Force

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Write-Ok "Built and installed from source"
}

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$INSTALL_DIR*") {
    Write-Info "Adding $INSTALL_DIR to your PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$INSTALL_DIR", "User")
    $env:Path = "$env:Path;$INSTALL_DIR"
}

# Verify
Write-Host ""
if (Get-Command rockit -ErrorAction SilentlyContinue) {
    $ver = & rockit version 2>&1
    Write-Ok "rockit installed: $ver"
} else {
    Write-Host "  Restart your terminal, then run: rockit version"
}

if (Get-Command fuel -ErrorAction SilentlyContinue) {
    $ver = & fuel version 2>&1
    Write-Ok "fuel installed: $ver"
}

Write-Host ""
Write-Host "  Get started:"
Write-Host "    fuel init my-app"
Write-Host "    cd my-app"
Write-Host "    fuel build"
Write-Host "    fuel run"
Write-Host ""
Write-Host "  Uninstall:"
Write-Host "    Remove-Item -Recurse -Force '$env:LOCALAPPDATA\Rockit'"
Write-Host ""
