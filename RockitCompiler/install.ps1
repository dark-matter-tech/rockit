# Rockit Compiler — Install Script for Windows
# Dark Matter Tech
#
# Usage (PowerShell):
#   iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.ps1 | iex
#
# Or run locally:
#   .\install.ps1

$ErrorActionPreference = "Stop"

$Repo = "Dark-Matter/moon"
$GitHubApi = "https://api.github.com"
$Prefix = if ($env:ROCKIT_PREFIX) { $env:ROCKIT_PREFIX } else { "$env:LOCALAPPDATA\Rockit" }
$InstallDir = "$Prefix\bin"
$LibDir = "$Prefix\lib\rockit\runtime"
$BuildDir = "$env:TEMP\rockit-install-$PID"

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "==> $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

# --- Try installing from prebuilt binary ---
function Install-Binary {
    try {
        Info "Checking for prebuilt binary (windows-x86_64)..."

        $release = Invoke-RestMethod -Uri "$GitHubApi/repos/$Repo/releases/latest" -ErrorAction Stop
        $tag = $release.tag_name
        $version = $tag -replace '^v', ''
        $archive = "rockit-${version}-windows-x86_64.zip"
        $downloadUrl = "https://github.com/$Repo/releases/download/$tag/$archive"

        Info "Downloading $archive..."
        $tmpZip = "$env:TEMP\rockit-download-$PID.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpZip -ErrorAction Stop

        Info "Installing to $InstallDir..."
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

        $tmpExtract = "$env:TEMP\rockit-extract-$PID"
        Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

        Copy-Item "$tmpExtract\rockit\rockit.exe" "$InstallDir\rockit.exe" -Force
        if (Test-Path "$tmpExtract\rockit\runtime") {
            Copy-Item "$tmpExtract\rockit\runtime\*" $LibDir -Force
        }
        if (Test-Path "$tmpExtract\rockit\editors") {
            $EditorsDir = "$Prefix\lib\rockit\editors"
            New-Item -ItemType Directory -Force -Path $EditorsDir | Out-Null
            Copy-Item "$tmpExtract\rockit\editors\*" $EditorsDir -Recurse -Force
        }

        Remove-Item -Recurse -Force $tmpZip -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $tmpExtract -ErrorAction SilentlyContinue

        Ok "Installed rockit $version (windows-x86_64)"
        return $true
    }
    catch {
        return $false
    }
}

# --- Fallback: build from source ---
function Install-Source {
    Info "Building from source..."

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

    Info "Downloading Rockit compiler..."
    if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
    git clone --depth 1 "https://github.com/$Repo.git" $BuildDir 2>$null
    if ($LASTEXITCODE -ne 0) { Fail "Failed to clone repository." }

    Push-Location "$BuildDir\RockitCompiler"

    Info "Building (release mode)..."
    swift build -c release
    if ($LASTEXITCODE -ne 0) { Fail "Build failed." }

    Info "Installing to $InstallDir..."
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

    Copy-Item ".build\release\rockit.exe" "$InstallDir\rockit.exe"
    Copy-Item "Runtime\rockit_runtime.c" "$LibDir\rockit_runtime.c"
    Copy-Item "Runtime\rockit_runtime.h" "$LibDir\rockit_runtime.h"

    # Bundle editor files
    $EditorsDir = "$Prefix\lib\rockit\editors"
    if (Test-Path "..\ide\vscode") {
        New-Item -ItemType Directory -Force -Path "$EditorsDir\vscode" | Out-Null
        Copy-Item "..\ide\vscode\*" "$EditorsDir\vscode\" -Recurse -Force
    }
    if (Test-Path "..\ide\vim") {
        New-Item -ItemType Directory -Force -Path "$EditorsDir\vim" | Out-Null
        Copy-Item "..\ide\vim\*" "$EditorsDir\vim\" -Recurse -Force
    }

    Pop-Location
    Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
    Ok "Installed rockit (built from source)"
}

# --- Main ---
$installed = Install-Binary
if (-not $installed) {
    Info "No prebuilt binary available, falling back to source build..."
    Install-Source
}

# --- Add to PATH ---
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$InstallDir", "User")
    Ok "Added $InstallDir to user PATH."
    Write-Host "  Restart your terminal for PATH changes to take effect."
}

# Set up editor plugins
Info "Setting up editor support..."
try { & "$InstallDir\rockit.exe" setup-editors 2>$null } catch {}

Ok "Installed successfully!"
Write-Host ""
Write-Host "  Rockit is ready. Try:"
Write-Host ""
Write-Host "    rockit run hello.rok          # bytecode (interpreted)"
Write-Host "    rockit run-native hello.rok   # native (compiled via LLVM)"
Write-Host "    rockit repl                   # interactive REPL"
Write-Host ""
Write-Host "  Update:    rockit update"
Write-Host "  Uninstall: Remove-Item -Recurse '$Prefix'"
Write-Host ""
