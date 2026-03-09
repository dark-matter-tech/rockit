# Rockit — Windows Install Script
# Dark Matter Tech
#
# Usage (PowerShell):
#   irm https://rustygits.com/Dark-Matter/moon/raw/branch/staging/RockitCompiler/scripts/install.ps1 | iex
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

# Signing key URL
$SIGNING_KEY_URL = "$GITEA/$REPO/raw/branch/staging/RockitCompiler/keys/darkmatter-release.asc"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Info($msg)  { Write-Host "==> $msg" }
function Write-Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

function Add-ToUserPath($dir) {
    # Add to current session
    if ($env:Path -notlike "*$dir*") {
        $env:Path = "$dir;$env:Path"
    }
    # Add permanently
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$dir*") {
        [Environment]::SetEnvironmentVariable("Path", "$dir;$userPath", "User")
        Write-Info "Added to PATH: $dir"
    }
}

function Set-UserEnvVar($name, $value) {
    [Environment]::SetEnvironmentVariable($name, $value, "User")
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
    Write-Info "Set $name = $value"
}

function Test-CommandWorks($cmd) {
    try {
        $null = & $cmd --version 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Prerequisite: 64-bit Windows
# ---------------------------------------------------------------------------

function Resolve-Architecture {
    if ([Environment]::Is64BitOperatingSystem) {
        Write-Ok "64-bit Windows"
        return "x86_64"
    }
    Write-Fail "32-bit Windows is not supported."
}

# ---------------------------------------------------------------------------
# Prerequisite: Git
# ---------------------------------------------------------------------------

function Resolve-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git $(git --version 2>&1)"
        return
    }

    Write-Warn "Git not found. Installing via winget..."
    winget install Git.Git --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    # Refresh PATH from the machine-level change the Git installer makes
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git installed: $(git --version 2>&1)"
    } else {
        Write-Fail "Failed to install Git. Install manually from https://git-scm.com"
    }
}

# ---------------------------------------------------------------------------
# Prerequisite: Visual Studio Build Tools + Windows SDK
# ---------------------------------------------------------------------------

function Resolve-VisualStudio {
    $vsFound = $false
    $sdkFound = $false

    # Check for Visual Studio (any edition)
    $vsBase = "C:\Program Files\Microsoft Visual Studio"
    if (Test-Path $vsBase) {
        $editions = Get-ChildItem $vsBase -Directory -ErrorAction SilentlyContinue
        if ($editions) { $vsFound = $true }
    }
    $vsBTBase = "C:\Program Files (x86)\Microsoft Visual Studio"
    if (-not $vsFound -and (Test-Path $vsBTBase)) {
        $editions = Get-ChildItem $vsBTBase -Directory -ErrorAction SilentlyContinue
        if ($editions) { $vsFound = $true }
    }

    # Check for Windows SDK
    $sdkBase = "C:\Program Files (x86)\Windows Kits\10\Include"
    if (Test-Path $sdkBase) {
        $versions = Get-ChildItem $sdkBase -Directory -ErrorAction SilentlyContinue
        if ($versions) { $sdkFound = $true }
    }

    if ($vsFound -and $sdkFound) {
        Write-Ok "Visual Studio + Windows SDK"
        return
    }

    if (-not $vsFound) {
        Write-Warn "Visual Studio not found. Installing Build Tools..."
        winget install Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" 2>&1 | Out-Null
        if (Test-Path "C:\Program Files\Microsoft Visual Studio") {
            Write-Ok "Visual Studio Build Tools installed"
        } else {
            Write-Fail "Visual Studio Build Tools are required for Swift on Windows.`nInstall from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022`nSelect 'Desktop development with C++' workload."
        }
    } elseif (-not $sdkFound) {
        Write-Fail "Windows SDK not found.`nInstall Visual Studio Build Tools with the 'Desktop development with C++' workload."
    }
}

# ---------------------------------------------------------------------------
# Prerequisite: LLVM / Clang
# ---------------------------------------------------------------------------

function Resolve-Clang {
    # Already on PATH?
    if (Get-Command clang -ErrorAction SilentlyContinue) {
        Write-Ok "Clang $(clang --version 2>&1 | Select-Object -First 1)"
        return
    }

    # Installed but not on PATH?
    $knownPaths = @(
        "C:\Program Files\LLVM\bin",
        "C:\Program Files (x86)\LLVM\bin",
        "$env:LOCALAPPDATA\LLVM\bin"
    )
    foreach ($p in $knownPaths) {
        if (Test-Path "$p\clang.exe") {
            Write-Warn "Clang found at $p but not on PATH. Fixing..."
            Add-ToUserPath $p
            Write-Ok "Clang $(clang --version 2>&1 | Select-Object -First 1)"
            return
        }
    }

    # Not installed — install via winget
    Write-Warn "Clang not found. Installing LLVM via winget..."
    winget install LLVM.LLVM --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

    # Find where it installed
    foreach ($p in $knownPaths) {
        if (Test-Path "$p\clang.exe") {
            Add-ToUserPath $p
            Write-Ok "LLVM installed: $(clang --version 2>&1 | Select-Object -First 1)"
            return
        }
    }

    Write-Fail "Failed to install LLVM.`nInstall manually: winget install LLVM.LLVM`nOr download from https://releases.llvm.org"
}

# ---------------------------------------------------------------------------
# Prerequisite: Swift toolchain + runtime DLLs + SDKROOT
# ---------------------------------------------------------------------------

function Find-SwiftToolchain {
    # Search for Swift toolchain in known locations
    $swiftBase = "$env:LOCALAPPDATA\Programs\Swift\Toolchains"
    if (-not (Test-Path $swiftBase)) { return $null }

    $versions = Get-ChildItem $swiftBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($v in $versions) {
        $bin = Join-Path $v.FullName "usr\bin"
        if (Test-Path "$bin\swift.exe") { return $bin }
    }
    return $null
}

function Find-SwiftRuntime {
    $rtBase = "$env:LOCALAPPDATA\Programs\Swift\Runtimes"
    if (-not (Test-Path $rtBase)) { return $null }

    $versions = Get-ChildItem $rtBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($v in $versions) {
        $bin = Join-Path $v.FullName "usr\bin"
        if (Test-Path "$bin\swiftCore.dll") { return $bin }
    }
    return $null
}

function Find-SwiftSDK {
    $platBase = "$env:LOCALAPPDATA\Programs\Swift\Platforms"
    if (-not (Test-Path $platBase)) { return $null }

    $versions = Get-ChildItem $platBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($v in $versions) {
        $sdk = Join-Path $v.FullName "Windows.platform\Developer\SDKs\Windows.sdk"
        if (Test-Path $sdk) { return $sdk }
    }
    return $null
}

function Resolve-Swift {
    $needsInstall = $true

    # Already on PATH and working?
    if (Get-Command swift -ErrorAction SilentlyContinue) {
        if (Test-CommandWorks "swift") {
            Write-Ok "Swift $(swift --version 2>&1 | Select-Object -First 1)"
            $needsInstall = $false
        }
    }

    if ($needsInstall) {
        # Installed but not on PATH, or DLLs missing?
        $tcBin = Find-SwiftToolchain
        $rtBin = Find-SwiftRuntime

        if ($tcBin) {
            Write-Warn "Swift found but not on PATH. Fixing..."
            Add-ToUserPath $tcBin
            if ($rtBin) { Add-ToUserPath $rtBin }

            if (Test-CommandWorks "swift") {
                Write-Ok "Swift $(swift --version 2>&1 | Select-Object -First 1)"
                $needsInstall = $false
            } else {
                Write-Warn "Swift found but not functional (missing DLLs?). Reinstalling..."
            }
        }
    }

    if ($needsInstall) {
        Write-Warn "Swift not found. Installing via winget (this downloads ~850 MB)..."
        # Use --skip-dependencies to avoid Git/Python installer conflicts
        winget install Swift.Toolchain --accept-package-agreements --accept-source-agreements --skip-dependencies 2>&1 | Out-Null

        $tcBin = Find-SwiftToolchain
        $rtBin = Find-SwiftRuntime

        if (-not $tcBin) {
            Write-Fail "Failed to install Swift.`nInstall manually from https://swift.org/download"
        }

        Add-ToUserPath $tcBin
        if ($rtBin) { Add-ToUserPath $rtBin }

        if (Test-CommandWorks "swift") {
            Write-Ok "Swift installed: $(swift --version 2>&1 | Select-Object -First 1)"
        } else {
            Write-Fail "Swift installed but not functional.`nTry restarting your terminal and running this script again."
        }
    }

    # --- SDKROOT ---
    $sdkroot = [Environment]::GetEnvironmentVariable("SDKROOT", "User")
    if (-not $sdkroot -or -not (Test-Path $sdkroot -ErrorAction SilentlyContinue)) {
        $sdkroot = [Environment]::GetEnvironmentVariable("SDKROOT", "Machine")
    }

    if ($sdkroot -and (Test-Path $sdkroot -ErrorAction SilentlyContinue)) {
        # Ensure it's set in the current process too (registry reads don't set $env:)
        $env:SDKROOT = $sdkroot
        Write-Ok "SDKROOT = $sdkroot"
    } else {
        $sdk = Find-SwiftSDK
        if ($sdk) {
            Set-UserEnvVar "SDKROOT" $sdk
            Write-Ok "SDKROOT = $sdk"
        } else {
            Write-Fail "Could not find Windows Swift SDK.`nExpected at: $env:LOCALAPPDATA\Programs\Swift\Platforms\*\Windows.platform\Developer\SDKs\Windows.sdk"
        }
    }
}

# ---------------------------------------------------------------------------
# Prerequisite: winget itself
# ---------------------------------------------------------------------------

function Resolve-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return
    }
    Write-Fail "winget (Windows Package Manager) is required but not found.`nIt ships with Windows 10 1809+ and Windows 11.`nInstall from: https://aka.ms/getwinget"
}

# ---------------------------------------------------------------------------
# Release Verification: GPG signature + manifest hash checks
# ---------------------------------------------------------------------------

function Import-SigningKey {
    # Check if gpg is available (installed via Gpg4win or Git for Windows)
    if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
        Write-Warn "gpg not found - cannot verify signatures"
        Write-Warn "Install Gpg4win (winget install GnuPG.Gpg4win) to enable signature verification"
        return $false
    }

    # Try to fetch and import the public key
    $tmpKey = Join-Path $env:TEMP "rockit-key-$(Get-Random).asc"
    try {
        Invoke-WebRequest -Uri $SIGNING_KEY_URL -OutFile $tmpKey -ErrorAction Stop
        gpg --import $tmpKey 2>$null
        Remove-Item $tmpKey -ErrorAction SilentlyContinue
        Write-Ok "Signing key imported"
        return $true
    } catch {
        Remove-Item $tmpKey -ErrorAction SilentlyContinue
        Write-Warn "Could not import signing key - signature verification unavailable"
        return $false
    }
}

function Test-ManifestSignature($manifestPath) {
    $sigPath = "$manifestPath.sig"

    if (-not (Test-Path $sigPath)) {
        Write-Warn "No signature file found - skipping signature verification"
        return $true
    }

    if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
        Write-Warn "gpg not found - skipping signature verification"
        return $true
    }

    Write-Info "Verifying manifest signature..."
    $result = gpg --verify $sigPath $manifestPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Manifest signature: VALID"
        return $true
    } else {
        Write-Fail "Manifest signature verification FAILED - the release may have been tampered with!"
        return $false
    }
}

function Test-ManifestHashes($manifestPath, $baseDir) {
    if (-not (Test-Path $manifestPath)) {
        Write-Warn "No MANIFEST.sha256 found - skipping integrity check"
        return $true
    }

    Write-Info "Verifying file integrity..."
    $failures = 0
    $checked = 0

    foreach ($line in (Get-Content $manifestPath)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Format: sha256:<hash>  <filepath>
        $parts = $line -split '\s+', 2
        if ($parts.Count -lt 2) { continue }

        $expectedHash = $parts[0] -replace '^sha256:', ''
        $filePath = $parts[1]

        $fullPath = Join-Path $baseDir $filePath
        if (-not (Test-Path $fullPath)) {
            Write-Host "    MISSING: $filePath"
            $failures++
            continue
        }

        $actualHash = (Get-FileHash $fullPath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -eq $expectedHash) {
            $checked++
        } else {
            Write-Host "    MISMATCH: $filePath"
            Write-Host "      expected: $expectedHash"
            Write-Host "      actual:   $actualHash"
            $failures++
        }
    }

    if ($failures -gt 0) {
        Write-Fail "Integrity check FAILED - $failures file(s) corrupted or tampered with!"
        return $false
    }

    Write-Ok "Integrity check passed ($checked files verified)"
    return $true
}

# ===========================================================================
# Main
# ===========================================================================

Write-Host ""
Write-Host "  Rockit Installer v$VERSION"
Write-Host "  Dark Matter Tech"
Write-Host ""

# --- Phase 1: Detect architecture ---
$arch = Resolve-Architecture
$platform = "windows-$arch"
$archive = "rockit-$VERSION-$platform.zip"
$url = "$GITEA/$REPO/releases/download/v$VERSION/$archive"

# --- Phase 2: Try prebuilt binary (no prerequisites needed) ---
Write-Info "Checking for prebuilt binary ($platform)..."

$tmp = Join-Path $env:TEMP "rockit-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$downloaded = $false
try {
    Invoke-WebRequest -Uri $url -OutFile "$tmp\$archive" -ErrorAction Stop
    $downloaded = $true
} catch {
    # No prebuilt available — will build from source
}

if ($downloaded) {
    # Prebuilt path only needs clang (for user's future native compiles)
    Write-Info "Prebuilt binary found. Checking runtime prerequisites..."
    Resolve-Winget
    Resolve-Clang

    Write-Info "Installing Rockit $VERSION..."
    Expand-Archive -Path "$tmp\$archive" -DestinationPath $tmp -Force

    $extracted = "$tmp\rockit-$VERSION-$platform\rockit"

    # --- Verify release integrity ---
    $keyImported = Import-SigningKey

    $manifestPath = "$extracted\MANIFEST.sha256"
    if (Test-Path $manifestPath) {
        # Try to download the detached signature if not in the archive
        $sigPath = "$manifestPath.sig"
        if (-not (Test-Path $sigPath)) {
            $sigUrl = "$GITEA/$REPO/releases/download/v$VERSION/MANIFEST.sha256.sig"
            try {
                Invoke-WebRequest -Uri $sigUrl -OutFile $sigPath -ErrorAction Stop
            } catch {
                # Signature file not available — that's OK
            }
        }

        Test-ManifestSignature $manifestPath
        Test-ManifestHashes $manifestPath $extracted
    } else {
        Write-Warn "No MANIFEST.sha256 in release - skipping integrity verification"
    }

    # --- Install verified files ---
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $SHARE_DIR | Out-Null

    Copy-Item "$extracted\bin\rockit.exe" "$INSTALL_DIR\rockit.exe" -Force
    Copy-Item "$extracted\bin\fuel.exe" "$INSTALL_DIR\fuel.exe" -Force
    Copy-Item "$extracted\share\rockit\rockit_runtime.c" "$SHARE_DIR\rockit_runtime.c" -Force
    Copy-Item "$extracted\share\rockit\rockit_runtime.h" "$SHARE_DIR\rockit_runtime.h" -Force
    if (Test-Path "$extracted\share\rockit\stdlib") {
        Copy-Item "$extracted\share\rockit\stdlib" "$SHARE_DIR\stdlib" -Recurse -Force
    }

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Write-Ok "Installed Rockit $VERSION ($platform)"
} else {
    # --- Phase 3: Build from source — full prerequisites needed ---
    Write-Info "No prebuilt binary for $platform. Building from source..."
    Write-Host ""
    Write-Info "Checking prerequisites..."

    Resolve-Winget
    Resolve-Git
    Resolve-VisualStudio
    Resolve-Clang
    Resolve-Swift

    Write-Host ""
    Write-Info "All prerequisites satisfied. Building..."
    Write-Host ""

    # Git and Swift both write progress/diagnostics to stderr.
    # PowerShell's "Stop" mode treats ANY stderr as a terminating error.
    # Use SilentlyContinue for external tool calls, check $LASTEXITCODE manually.
    $savedEAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"

    # Change to TEMP before git operations — Git Credential Manager
    # crashes when CWD is a protected directory like system32.
    Push-Location $env:TEMP

    # Clone compiler
    Write-Info "Downloading Rockit compiler..."
    git clone --depth 1 --recurse-submodules --branch develop "$GITEA/$REPO.git" "$tmp\moon" 2>&1 | Out-Null
    if (-not (Test-Path "$tmp\moon\RockitCompiler\Package.swift")) {
        Pop-Location
        $ErrorActionPreference = $savedEAP
        Write-Fail "Failed to clone compiler repository."
    }

    Pop-Location

    # Build Stage 1
    Write-Info "Building compiler (this takes a minute)..."
    Push-Location "$tmp\moon\RockitCompiler"
    swift run rockit build-native self-hosted-rockit\command.rok 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { Pop-Location; $ErrorActionPreference = $savedEAP; Write-Fail "Compiler build failed." }
    Pop-Location

    # Clone and build Fuel
    Push-Location $env:TEMP

    Write-Info "Building Fuel package manager..."
    git clone --depth 1 --branch develop "$GITEA/$REPO_FUEL.git" "$tmp\fuel" 2>&1 | Out-Null

    Pop-Location

    if (Test-Path "$tmp\fuel\src\fuel.rok") {
        & "$tmp\moon\RockitCompiler\self-hosted-rockit\command.exe" build-native "$tmp\fuel\src\fuel.rok" -o "$tmp\fuel\fuel.exe" --runtime-path "$tmp\moon\RockitCompiler\runtime\rockit_runtime.c" 2>&1 | ForEach-Object { "$_" }
    }

    # Install
    Write-Info "Installing to $INSTALL_DIR..."
    New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $SHARE_DIR | Out-Null

    Copy-Item "$tmp\moon\RockitCompiler\self-hosted-rockit\command.exe" "$INSTALL_DIR\rockit.exe" -Force
    if (Test-Path "$tmp\fuel\fuel.exe") {
        Copy-Item "$tmp\fuel\fuel.exe" "$INSTALL_DIR\fuel.exe" -Force
    }
    Copy-Item "$tmp\moon\RockitCompiler\runtime\rockit_runtime.c" "$SHARE_DIR\rockit_runtime.c" -Force
    Copy-Item "$tmp\moon\RockitCompiler\runtime\rockit_runtime.h" "$SHARE_DIR\rockit_runtime.h" -Force
    if (Test-Path "$tmp\moon\RockitCompiler\self-hosted-rockit\stdlib") {
        Copy-Item "$tmp\moon\RockitCompiler\self-hosted-rockit\stdlib" "$SHARE_DIR\stdlib" -Recurse -Force
    }

    $ErrorActionPreference = $savedEAP

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Write-Ok "Built and installed from source"
}

# --- Phase 4: PATH + Verify ---
Add-ToUserPath $INSTALL_DIR

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
