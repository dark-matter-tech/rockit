# Rockit Editor Support — Universal Install Script (PowerShell)
# Dark Matter Tech
#
# Usage:
#   iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/ide/install.ps1 | iex
#
# Or run locally:
#   powershell -ExecutionPolicy Bypass -File ide\install.ps1
#
# Environment variables:
#   ROCKIT_REPO_URL  — override the git repo URL

$ErrorActionPreference = "Stop"

$RepoUrl = if ($env:ROCKIT_REPO_URL) { $env:ROCKIT_REPO_URL } else { "https://github.com/Dark-Matter/moon.git" }
$WorkDir = Join-Path $env:TEMP "rockit-editor-install-$PID"
$Installed = [System.Collections.ArrayList]::new()

function Info($msg)  { Write-Host "==> $msg" -ForegroundColor White }
function Ok($msg)    { Write-Host "==> $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg)  { Write-Host "error: $msg" -ForegroundColor Red; exit 1 }

# ─── Get Editor Files ────────────────────────────────────────────────

$IdeDir = $null

if (Test-Path "ide\vscode\package.json") {
    $IdeDir = Join-Path (Get-Location) "ide"
    Info "Using local editor files"
} elseif (Test-Path "..\ide\vscode\package.json") {
    $IdeDir = (Resolve-Path "..\ide").Path
    Info "Using local editor files"
} else {
    Info "Downloading Rockit editor files..."
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { Fail "git is required. Install it and try again." }

    git clone --depth 1 --filter=blob:none --sparse $RepoUrl $WorkDir 2>$null
    if ($LASTEXITCODE -ne 0) { Fail "Failed to clone repository." }
    Push-Location $WorkDir
    git sparse-checkout set ide 2>$null
    Pop-Location
    $IdeDir = Join-Path $WorkDir "ide"
}

# ─── VS Code ─────────────────────────────────────────────────────────

function Install-VSCode($Variant, $Label) {
    if ($Variant -eq "code-insiders") {
        $extDir = Join-Path $HOME ".vscode-insiders\extensions"
    } else {
        $extDir = Join-Path $HOME ".vscode\extensions"
    }

    $hasCmd = Get-Command $Variant -ErrorAction SilentlyContinue
    if (-not $hasCmd -and -not (Test-Path $extDir)) { return }

    $src = Join-Path $IdeDir "vscode"
    if (-not (Test-Path (Join-Path $src "package.json"))) { return }

    $target = Join-Path $extDir "darkmattertech.rockit-lang-0.1.0"
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    Copy-Item (Join-Path $src "package.json") $target
    Copy-Item (Join-Path $src "language-configuration.json") $target
    foreach ($sub in @("syntaxes", "snippets", "icons")) {
        $subSrc = Join-Path $src $sub
        if (Test-Path $subSrc) { Copy-Item $subSrc $target -Recurse }
    }

    Ok "  ${Label}: installed to $target"
    $Installed.Add($Label) | Out-Null
}

# ─── Vim ──────────────────────────────────────────────────────────────

function Install-Vim {
    $vimDir = Join-Path $HOME "vimfiles"

    $hasVim = Get-Command vim -ErrorAction SilentlyContinue
    if (-not $hasVim -and -not (Test-Path $vimDir)) { return }

    $src = Join-Path $IdeDir "vim"
    if (-not (Test-Path (Join-Path $src "syntax\rockit.vim"))) { return }

    New-Item -ItemType Directory -Path (Join-Path $vimDir "ftdetect") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $vimDir "syntax") -Force | Out-Null
    Copy-Item (Join-Path $src "ftdetect\rockit.vim") (Join-Path $vimDir "ftdetect\rockit.vim") -Force
    Copy-Item (Join-Path $src "syntax\rockit.vim") (Join-Path $vimDir "syntax\rockit.vim") -Force

    Ok "  Vim: installed to $vimDir"
    $Installed.Add("Vim") | Out-Null
}

# ─── Neovim ──────────────────────────────────────────────────────────

function Install-Neovim {
    $localApp = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME "AppData\Local" }
    $nvimSite = Join-Path $localApp "nvim-data\site"
    $nvimConfig = Join-Path $localApp "nvim"

    $hasNvim = Get-Command nvim -ErrorAction SilentlyContinue
    if (-not $hasNvim -and -not (Test-Path $nvimConfig)) { return }

    $src = Join-Path $IdeDir "vim"
    if (-not (Test-Path (Join-Path $src "syntax\rockit.vim"))) { return }

    New-Item -ItemType Directory -Path (Join-Path $nvimSite "ftdetect") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $nvimSite "syntax") -Force | Out-Null
    Copy-Item (Join-Path $src "ftdetect\rockit.vim") (Join-Path $nvimSite "ftdetect\rockit.vim") -Force
    Copy-Item (Join-Path $src "syntax\rockit.vim") (Join-Path $nvimSite "syntax\rockit.vim") -Force

    Ok "  Neovim: installed to $nvimSite"
    $Installed.Add("Neovim") | Out-Null
}

# ─── JetBrains ───────────────────────────────────────────────────────

function Install-JetBrains {
    $appData = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME "AppData\Roaming" }
    $baseDir = Join-Path $appData "JetBrains"
    if (-not (Test-Path $baseDir)) { return }

    # Find plugin zip
    $distDir = Join-Path $IdeDir "intellij-rockit\build\distributions"
    $pluginZip = $null
    if (Test-Path $distDir) {
        $pluginZip = Get-ChildItem $distDir -Filter "*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    # Try building if no zip
    if (-not $pluginZip) {
        $gradlew = Join-Path $IdeDir "intellij-rockit\gradlew.bat"
        if (Test-Path $gradlew) {
            Info "  Building JetBrains plugin..."
            Push-Location (Join-Path $IdeDir "intellij-rockit")
            & .\gradlew.bat buildPlugin -q 2>$null
            Pop-Location
            if (Test-Path $distDir) {
                $pluginZip = Get-ChildItem $distDir -Filter "*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        }
    }

    $knownPrefixes = @("IntelliJIdea", "IdeaIC", "WebStorm", "CLion", "PyCharm", "GoLand", "Rider", "RubyMine", "PhpStorm", "DataGrip", "DataSpell", "AndroidStudio", "Fleet", "Writerside")

    foreach ($ideItem in (Get-ChildItem $baseDir -Directory -ErrorAction SilentlyContinue)) {
        $dirName = $ideItem.Name
        $isIde = $false
        foreach ($prefix in $knownPrefixes) {
            if ($dirName.StartsWith($prefix)) { $isIde = $true; break }
        }
        if (-not $isIde) { continue }

        $pluginsDir = Join-Path $ideItem.FullName "plugins"
        if (-not (Test-Path $pluginsDir)) { continue }

        $friendly = switch -Wildcard ($dirName) {
            "IntelliJIdea*" { "IntelliJ IDEA" }
            "IdeaIC*"       { "IntelliJ IDEA CE" }
            "WebStorm*"     { "WebStorm" }
            "CLion*"        { "CLion" }
            "PyCharm*"      { "PyCharm" }
            "GoLand*"       { "GoLand" }
            "Rider*"        { "Rider" }
            "Fleet*"        { "Fleet" }
            "RubyMine*"     { "RubyMine" }
            "PhpStorm*"     { "PhpStorm" }
            "DataGrip*"     { "DataGrip" }
            "DataSpell*"    { "DataSpell" }
            "Writerside*"   { "Writerside" }
            "AndroidStudio*" { "Android Studio" }
            default         { $dirName }
        }

        if ($pluginZip) {
            Expand-Archive -Path $pluginZip.FullName -DestinationPath $pluginsDir -Force
            Ok "  ${friendly}: installed plugin"
            $Installed.Add($friendly) | Out-Null
        } else {
            Warn "  ${friendly}: detected but no plugin .zip available"
        }
    }
}

# ─── Visual Studio ───────────────────────────────────────────────────

function Install-VisualStudio {
    $docsDir = Join-Path $HOME "Documents"
    if (-not (Test-Path $docsDir)) { return }

    foreach ($vsDir in (Get-ChildItem $docsDir -Directory -Filter "Visual Studio *" -ErrorAction SilentlyContinue)) {
        $extDir = Join-Path $vsDir.FullName "Extensions\DarkMatterTech\Rockit"
        New-Item -ItemType Directory -Path $extDir -Force | Out-Null

        $src = Join-Path $IdeDir "vscode"
        $syntaxSrc = Join-Path $src "syntaxes"
        if (Test-Path $syntaxSrc) {
            Copy-Item $syntaxSrc $extDir -Recurse -Force
            Ok "  Visual Studio ($($vsDir.Name)): installed syntax files"
            $Installed.Add("Visual Studio") | Out-Null
        }
    }
}

# ─── GUI Summary ─────────────────────────────────────────────────────

function Show-GuiSummary($Message) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $Message,
            "Rockit Editor Setup",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        # GUI not available, terminal output is sufficient
    }
}

# ─── Main ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Rockit Editor Support Installer" -ForegroundColor White
Write-Host "  Dark Matter Tech"
Write-Host ""

Info "Detecting installed editors..."
Write-Host ""

Install-VSCode "code" "VS Code"
Install-VSCode "code-insiders" "VS Code Insiders"
Install-Vim
Install-Neovim
Install-JetBrains
Install-VisualStudio

Write-Host ""

if ($Installed.Count -eq 0) {
    Warn "No supported editors detected."
    Write-Host ""
    Write-Host "  Rockit supports: VS Code, Vim, Neovim, JetBrains IDEs, Visual Studio"
    Write-Host ""
    Write-Host "  Manual install:"
    Write-Host "    VS Code:    code --install-extension rockit-lang-0.1.0.vsix"
    Write-Host "    Vim:        Copy syntax\rockit.vim to ~/vimfiles/syntax/"
    Write-Host "    Neovim:     Copy syntax\rockit.vim to %LOCALAPPDATA%\nvim-data\site\syntax\"
    Write-Host "    JetBrains:  Settings > Plugins > Install from Disk"
    Write-Host ""

    Show-GuiSummary "No supported editors were detected.`n`nRockit supports: VS Code, Vim, Neovim, JetBrains IDEs, Visual Studio.`n`nSee the README for manual install instructions."
} else {
    $unique = $Installed | Select-Object -Unique
    $list = $unique -join ", "

    Ok "Installed Rockit editor support for: $list"
    Write-Host ""
    Write-Host "  Restart your editor(s) to activate."
    Write-Host ""

    Show-GuiSummary "Rockit editor support installed for:`n`n$list`n`nRestart your editor(s) to activate."
}

# Cleanup
if (Test-Path $WorkDir) { Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
