#!/usr/bin/env bash
# Rockit Editor Support — Universal Install Script
# Dark Matter Tech
#
# Usage:
#   curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/master/ide/install.sh | bash
#
# Or clone and run locally:
#   bash ide/install.sh
#
# Environment variables:
#   ROCKIT_REPO_URL  — override the git repo URL (default: GitHub)

set -euo pipefail

REPO_URL="${ROCKIT_REPO_URL:-https://rustygits.com/Dark-Matter/moon.git}"
TMPDIR="${TMPDIR:-/tmp}"
WORK_DIR="${TMPDIR}/rockit-editor-install-$$"
INSTALLED=()
TARGETS=()

# ─── Colors ──────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Bright variants
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BCYAN='\033[1;36m'

info()  { echo -e "  ${BOLD}==> ${RESET}$1"; }
ok()    { echo -e "  ${GREEN} ✓  ${RESET}$1"; }
warn()  { echo -e "  ${CYAN} ●  ${RESET}$1"; }
fail()  { echo -e "  ${RED} ✗  ${RESET}$1"; exit 1; }

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# ─── Terminal Helpers ────────────────────────────────────────────────

# Hide/show cursor
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
trap 'show_cursor' EXIT

# Move cursor
move_up()   { printf "\033[%dA" "$1"; }
move_down() { printf "\033[%dB" "$1"; }
clear_line() { printf "\033[2K\r"; }

# ─── ASCII Art ───────────────────────────────────────────────────────

show_banner() {
    clear
    echo ""
    echo -e "${BRED}            /\\             ${RESET}"
    echo -e "${BRED}           /  \\            ${RESET}"
    echo -e "${WHITE}          /    \\           ${RESET}"
    echo -e "${WHITE}         | ${CYAN}(  )${WHITE} |          ${RESET}"
    echo -e "${WHITE}         |${RED}----${WHITE}|          ${RESET}"
    echo -e "${WHITE}         |${RED}*${BLUE}====${WHITE}|          ${RESET}"
    echo -e "${WHITE}         |${RED}*${BLUE}====${WHITE}|          ${RESET}"
    echo -e "${WHITE}         |${RED}----${WHITE}|          ${RESET}"
    echo -e "${WHITE}         |${WHITE}=====${WHITE}|          ${RESET}"
    echo -e "${WHITE}         |${RED}----${WHITE}|          ${RESET}"
    echo -e "${BLUE}        /|     |\\         ${RESET}"
    echo -e "${BLUE}       / |     | \\        ${RESET}"
    echo -e "${BLUE}      /  |     |  \\       ${RESET}"
    echo -e "${YELLOW}         |${RED}IIIII${YELLOW}|          ${RESET}"
    echo -e "${YELLOW}         |${RED}IIIII${YELLOW}|          ${RESET}"
    echo -e "${DIM}       ~~~~~~~~~~~        ${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}    R O C K I T${RESET}   ${DIM}Editor Support${RESET}"
    echo -e "${DIM}      Dark Matter Tech${RESET}"
    echo ""
}

# ─── Progress Bar ────────────────────────────────────────────────────

BAR_WIDTH=40

draw_progress() {
    local percent="$1"
    local label="$2"
    local filled=$(( (percent * BAR_WIDTH) / 100 ))
    local empty=$(( BAR_WIDTH - filled ))

    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    clear_line
    if [ "$percent" -lt 100 ]; then
        printf "  ${CYAN}[${BCYAN}%s${GRAY}%s${CYAN}]${RESET} ${WHITE}%3d%%${RESET}  ${DIM}%s${RESET}" \
            "$(printf '%0.s█' $(seq 1 "$filled" 2>/dev/null) || true)" \
            "$(printf '%0.s░' $(seq 1 "$empty" 2>/dev/null) || true)" \
            "$percent" "$label"
    else
        printf "  ${GREEN}[${BGREEN}%s${GREEN}]${RESET} ${BGREEN}%3d%%${RESET}  ${GREEN}%s${RESET}" \
            "$(printf '%0.s█' $(seq 1 $BAR_WIDTH))" \
            "$percent" "$label"
    fi
}

# ─── Launch Animation ────────────────────────────────────────────────

rocket_launch() {
    local lines=18
    hide_cursor

    # Rocket frames moving upward
    local frames=12
    for ((frame=0; frame<frames; frame++)); do
        clear
        local pad=$((frame + 1))

        # Stars (random-ish)
        local starfield=""
        for ((s=0; s<(lines - pad); s++)); do
            local star_pos=$(( (s * 7 + frame * 3) % 50 ))
            local line=""
            for ((c=0; c<50; c++)); do
                if [ $c -eq $star_pos ] || [ $c -eq $(( (star_pos + 23) % 50 )) ]; then
                    line+="."
                else
                    line+=" "
                fi
            done
            echo -e "${DIM}$line${RESET}"
        done

        # Rocket with flag
        echo -e "${BRED}            /\\             ${RESET}"
        echo -e "${BRED}           /  \\            ${RESET}"
        echo -e "${WHITE}          /    \\           ${RESET}"
        echo -e "${WHITE}         | ${CYAN}(  )${WHITE} |          ${RESET}"
        echo -e "${WHITE}         |${RED}*${BLUE}====${WHITE}|          ${RESET}"
        echo -e "${WHITE}         |${RED}----${WHITE}|          ${RESET}"
        echo -e "${BLUE}        /|     |\\         ${RESET}"
        echo -e "${BLUE}       / |     | \\        ${RESET}"

        # Exhaust (grows with frame)
        if [ $frame -lt 3 ]; then
            echo -e "${YELLOW}         |${RED}*${YELLOW}***${RED}*${YELLOW}|          ${RESET}"
        elif [ $frame -lt 6 ]; then
            echo -e "${YELLOW}         |${RED}*${YELLOW}***${RED}*${YELLOW}|          ${RESET}"
            echo -e "${RED}          \\\\${YELLOW}|||${RED}/          ${RESET}"
        elif [ $frame -lt 9 ]; then
            echo -e "${YELLOW}         |${RED}*${YELLOW}***${RED}*${YELLOW}|          ${RESET}"
            echo -e "${RED}          \\\\${YELLOW}|||${RED}/          ${RESET}"
            echo -e "${YELLOW}           ${RED}|||${YELLOW}           ${RESET}"
        else
            echo -e "${YELLOW}         |${RED}*${YELLOW}***${RED}*${YELLOW}|          ${RESET}"
            echo -e "${RED}          \\\\${YELLOW}|||${RED}/          ${RESET}"
            echo -e "${YELLOW}           ${RED}|||${YELLOW}           ${RESET}"
            echo -e "${DIM}           ...           ${RESET}"
        fi

        # Fill remaining lines
        local used=$(( (lines - pad) + 8 + (frame < 3 ? 1 : frame < 6 ? 2 : frame < 9 ? 3 : 4) ))
        for ((r=used; r<lines+8; r++)); do
            echo ""
        done

        sleep 0.08
    done

    show_cursor
}

# ─── Success Screen ──────────────────────────────────────────────────

show_success() {
    local editor_list="$1"

    clear
    echo ""
    echo ""
    echo -e "${BGREEN}            /\\             ${RESET}"
    echo -e "${BGREEN}           /  \\            ${RESET}"
    echo -e "${BGREEN}          /    \\           ${RESET}"
    echo -e "${BGREEN}         | ${WHITE}(  )${BGREEN} |          ${RESET}"
    echo -e "${BGREEN}         |${RED}*${BLUE}====${BGREEN}|          ${RESET}"
    echo -e "${BGREEN}         |${RED}----${BGREEN}|          ${RESET}"
    echo -e "${BGREEN}         |${WHITE}=====${BGREEN}|          ${RESET}"
    echo -e "${BGREEN}        /|     |\\         ${RESET}"
    echo -e "${BGREEN}       / |     | \\        ${RESET}"
    echo ""
    echo -e "${BOLD}${BGREEN}  ══════════════════════════════════${RESET}"
    echo -e "${BOLD}${BGREEN}     INSTALLATION COMPLETE!${RESET}"
    echo -e "${BOLD}${BGREEN}  ══════════════════════════════════${RESET}"
    echo ""
    echo -e "${WHITE}  Installed Rockit support for:${RESET}"
    echo ""

    echo "$editor_list" | while IFS= read -r editor; do
        echo -e "    ${GREEN}✓${RESET}  ${WHITE}$editor${RESET}"
    done

    echo ""
    echo -e "  ${DIM}Restart your editor(s) to activate.${RESET}"
    echo ""
    echo -e "  ${BOLD}${WHITE}R O C K I T${RESET}  ${DIM}— Dark Matter Tech${RESET}"
    echo ""
}

# ─── Detect Platform ─────────────────────────────────────────────────

detect_platform() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin)               echo "macos" ;;
        Linux)                echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)                    echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)
HOME_DIR="${HOME:-$( (getent passwd "$(whoami)" 2>/dev/null || echo "::::::$HOME") | cut -d: -f6)}"

# ─── Get Editor Files ────────────────────────────────────────────────

get_editor_files() {
    # Check relative to the script's own location first
    local script_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    # Script lives in ide/ — so script_dir IS the ide directory
    if [ -n "$script_dir" ] && [ -f "$script_dir/vscode/package.json" ]; then
        IDE_DIR="$script_dir"
        return
    fi

    # Check from cwd
    if [ -f "ide/vscode/package.json" ]; then
        IDE_DIR="$(pwd)/ide"
        return
    fi
    if [ -f "../ide/vscode/package.json" ]; then
        IDE_DIR="$(cd .. && pwd)/ide"
        return
    fi

    command -v git >/dev/null 2>&1 || fail "git is required. Install it and try again."
    git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" "$WORK_DIR" 2>/dev/null || \
        fail "Failed to clone repository. Check your network connection."
    cd "$WORK_DIR"
    git sparse-checkout set ide 2>/dev/null
    IDE_DIR="$WORK_DIR/ide"
}

# ─── Detection ───────────────────────────────────────────────────────

detect_vscode() {
    local variant="$1" label="$2"
    local ext_dir
    if [ "$variant" = "code-insiders" ]; then
        ext_dir="$HOME_DIR/.vscode-insiders/extensions"
    else
        ext_dir="$HOME_DIR/.vscode/extensions"
    fi
    local has_cmd=false
    command -v "$variant" >/dev/null 2>&1 && has_cmd=true
    if [ "$has_cmd" = true ] || [ -d "$ext_dir" ]; then
        [ -f "$IDE_DIR/vscode/package.json" ] && TARGETS+=("vscode:$variant:$label")
    fi
}

detect_vim() {
    local vim_dir
    case "$PLATFORM" in
        windows) vim_dir="$HOME_DIR/vimfiles" ;;
        *)       vim_dir="$HOME_DIR/.vim" ;;
    esac
    local has_vim=false
    command -v vim >/dev/null 2>&1 && has_vim=true
    if [ "$has_vim" = true ] || [ -d "$vim_dir" ]; then
        [ -f "$IDE_DIR/vim/syntax/rockit.vim" ] && TARGETS+=("vim")
    fi
}

detect_neovim() {
    local nvim_config
    case "$PLATFORM" in
        macos|linux) nvim_config="$HOME_DIR/.config/nvim" ;;
        windows)     nvim_config="${LOCALAPPDATA:-$HOME_DIR/AppData/Local}/nvim" ;;
    esac
    local has_nvim=false
    command -v nvim >/dev/null 2>&1 && has_nvim=true
    if [ "$has_nvim" = true ] || [ -d "$nvim_config" ]; then
        [ -f "$IDE_DIR/vim/syntax/rockit.vim" ] && TARGETS+=("neovim")
    fi
}

detect_jetbrains() {
    local base_dirs=()
    case "$PLATFORM" in
        macos)   base_dirs=("$HOME_DIR/Library/Application Support/JetBrains") ;;
        linux)   base_dirs=("$HOME_DIR/.local/share/JetBrains" "$HOME_DIR/.config/JetBrains") ;;
        windows) base_dirs=("${APPDATA:-$HOME_DIR/AppData/Roaming}/JetBrains") ;;
    esac

    local known_prefixes="IntelliJIdea IdeaIC WebStorm CLion PyCharm GoLand Rider RubyMine PhpStorm DataGrip DataSpell AndroidStudio Fleet Writerside"

    for base in "${base_dirs[@]}"; do
        [ -d "$base" ] || continue
        for ide_dir in "$base"/*/; do
            [ -d "$ide_dir" ] || continue
            local dir_name
            dir_name=$(basename "$ide_dir")
            [ -d "$ide_dir/plugins" ] || continue

            for prefix in $known_prefixes; do
                case "$dir_name" in
                    "$prefix"*)
                        local friendly
                        friendly=$(jetbrains_friendly_name "$dir_name")
                        TARGETS+=("jetbrains:$ide_dir:$friendly")
                        break
                        ;;
                esac
            done
        done
    done
}

detect_visual_studio() {
    [ "$PLATFORM" = "windows" ] || return 0
    local docs_dir="$HOME_DIR/Documents"
    [ -d "$docs_dir" ] || return 0
    for vs_dir in "$docs_dir"/Visual\ Studio\ */; do
        [ -d "$vs_dir" ] || continue
        TARGETS+=("visualstudio:$vs_dir")
    done
}

jetbrains_friendly_name() {
    local d="$1"
    case "$d" in
        IntelliJIdea*)  echo "IntelliJ IDEA" ;;
        IdeaIC*)        echo "IntelliJ IDEA CE" ;;
        WebStorm*)      echo "WebStorm" ;;
        CLion*)         echo "CLion" ;;
        PyCharm*)       echo "PyCharm" ;;
        GoLand*)        echo "GoLand" ;;
        Rider*)         echo "Rider" ;;
        Fleet*)         echo "Fleet" ;;
        RubyMine*)      echo "RubyMine" ;;
        PhpStorm*)      echo "PhpStorm" ;;
        DataGrip*)      echo "DataGrip" ;;
        DataSpell*)     echo "DataSpell" ;;
        Writerside*)    echo "Writerside" ;;
        AndroidStudio*) echo "Android Studio" ;;
        *)              echo "$d" ;;
    esac
}

# ─── Installation ────────────────────────────────────────────────────

do_install_vscode() {
    local variant="$1" label="$2"
    local ext_dir
    if [ "$variant" = "code-insiders" ]; then
        ext_dir="$HOME_DIR/.vscode-insiders/extensions"
    else
        ext_dir="$HOME_DIR/.vscode/extensions"
    fi
    local src="$IDE_DIR/vscode"
    local target="$ext_dir/darkmattertech.rockit-lang-0.1.0"
    rm -rf "$target"
    mkdir -p "$target"
    cp "$src/package.json" "$target/"
    cp "$src/language-configuration.json" "$target/"
    for sub in syntaxes snippets icons; do
        [ -d "$src/$sub" ] && cp -r "$src/$sub" "$target/"
    done
    INSTALLED+=("$label")
}

do_install_vim() {
    local vim_dir
    case "$PLATFORM" in
        windows) vim_dir="$HOME_DIR/vimfiles" ;;
        *)       vim_dir="$HOME_DIR/.vim" ;;
    esac
    mkdir -p "$vim_dir/ftdetect" "$vim_dir/syntax"
    cp "$IDE_DIR/vim/ftdetect/rockit.vim" "$vim_dir/ftdetect/rockit.vim"
    cp "$IDE_DIR/vim/syntax/rockit.vim" "$vim_dir/syntax/rockit.vim"
    INSTALLED+=("Vim")
}

do_install_neovim() {
    local nvim_site
    case "$PLATFORM" in
        macos|linux) nvim_site="$HOME_DIR/.local/share/nvim/site" ;;
        windows)     nvim_site="${LOCALAPPDATA:-$HOME_DIR/AppData/Local}/nvim-data/site" ;;
    esac
    mkdir -p "$nvim_site/ftdetect" "$nvim_site/syntax"
    cp "$IDE_DIR/vim/ftdetect/rockit.vim" "$nvim_site/ftdetect/rockit.vim"
    cp "$IDE_DIR/vim/syntax/rockit.vim" "$nvim_site/syntax/rockit.vim"
    INSTALLED+=("Neovim")
}

do_install_jetbrains() {
    local ide_dir="$1" friendly="$2"
    local plugins_dir="${ide_dir}/plugins"
    local plugin_zip=""
    local dist_dir="$IDE_DIR/intellij-rockit/build/distributions"
    if [ -d "$dist_dir" ]; then
        plugin_zip=$(find "$dist_dir" -name '*.zip' -print -quit 2>/dev/null || true)
    fi
    if [ -z "$plugin_zip" ] && [ -f "$IDE_DIR/intellij-rockit/gradlew" ]; then
        (cd "$IDE_DIR/intellij-rockit" && ./gradlew buildPlugin -q 2>/dev/null) || true
        plugin_zip=$(find "$dist_dir" -name '*.zip' -print -quit 2>/dev/null || true)
    fi
    if [ -n "$plugin_zip" ]; then
        unzip -o -q "$plugin_zip" -d "$plugins_dir" 2>/dev/null && INSTALLED+=("$friendly")
    fi
}

do_install_visualstudio() {
    local vs_dir="$1"
    local ext_dir="${vs_dir}/Extensions/DarkMatterTech/Rockit"
    mkdir -p "$ext_dir"
    if [ -d "$IDE_DIR/vscode/syntaxes" ]; then
        cp -r "$IDE_DIR/vscode/syntaxes" "$ext_dir/"
        INSTALLED+=("Visual Studio")
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────

# If Python 3 is available and install.py exists alongside this script,
# hand off to the cinematic Python installer for the full experience.
_try_python_installer() {
    command -v python3 >/dev/null 2>&1 || return 1
    local script_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    [ -n "$script_dir" ] && [ -f "$script_dir/install.py" ] && {
        exec python3 "$script_dir/install.py"
    }
    # Also check cwd
    [ -f "ide/install.py" ] && { exec python3 "ide/install.py"; }
    return 1
}
_try_python_installer || true

# ─── Bash fallback (no Python 3 or install.py not found) ─────────────

show_banner
sleep 0.5

info "Fueling up..."
get_editor_files
sleep 0.3

info "Scanning launch pad..."
echo ""

detect_vscode "code" "VS Code"
detect_vscode "code-insiders" "VS Code Insiders"
detect_vim
detect_neovim
detect_jetbrains
detect_visual_studio

TOTAL=${#TARGETS[@]}

if [ "$TOTAL" -eq 0 ]; then
    echo ""
    warn "No supported editors detected."
    echo ""
    echo -e "  ${WHITE}Rockit supports:${RESET} VS Code, Vim, Neovim, JetBrains IDEs, Visual Studio"
    echo ""
    echo -e "  ${DIM}Manual install:${RESET}"
    echo -e "    ${DIM}VS Code:    code --install-extension rockit-lang-0.1.0.vsix${RESET}"
    echo -e "    ${DIM}Vim:        cp syntax/rockit.vim ~/.vim/syntax/${RESET}"
    echo -e "    ${DIM}Neovim:     cp syntax/rockit.vim ~/.local/share/nvim/site/syntax/${RESET}"
    echo -e "    ${DIM}JetBrains:  Settings > Plugins > Install from Disk${RESET}"
    echo ""
    show_cursor
    exit 0
fi

info "Found ${WHITE}$TOTAL${RESET} target(s). Ignition sequence start..."
echo ""
sleep 0.3

hide_cursor

# Install with animated progress bar
CURRENT=0
echo ""  # line for progress bar
echo ""  # line for status

for target in "${TARGETS[@]}"; do
    IFS=':' read -r type arg1 arg2 <<< "$target"
    local_label=""

    case "$type" in
        vscode)       local_label="$arg2"; do_install_vscode "$arg1" "$arg2" ;;
        vim)          local_label="Vim"; do_install_vim ;;
        neovim)       local_label="Neovim"; do_install_neovim ;;
        jetbrains)    local_label="$arg2"; do_install_jetbrains "$arg1" "$arg2" ;;
        visualstudio) local_label="Visual Studio"; do_install_visualstudio "$arg1" ;;
    esac

    CURRENT=$((CURRENT + 1))
    pct=$(( (CURRENT * 100) / TOTAL ))

    # Redraw progress bar
    move_up 2
    draw_progress "$pct" "Installing $local_label..."
    echo ""
    clear_line
    printf "  ${DIM}$CURRENT / $TOTAL targets${RESET}"
    echo ""

    sleep 0.12
done

# Final 100%
move_up 2
draw_progress 100 "All systems go!"
echo ""
clear_line
printf "  ${GREEN}$TOTAL / $TOTAL targets${RESET}"
echo ""
echo ""

show_cursor
sleep 0.5

# Rocket launch animation
rocket_launch
sleep 0.3

# Success screen
unique_list=$(printf "%s\n" "${INSTALLED[@]}" | awk '!seen[$0]++')
show_success "$unique_list"
