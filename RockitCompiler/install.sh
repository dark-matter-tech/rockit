#!/usr/bin/env bash
# Rockit — Install Script
# Dark Matter Tech
#
# Usage:
#   curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
#
# Or clone and run locally:
#   ./install.sh

set -euo pipefail

VERSION="0.1.0"
GITEA="https://rustygits.com"
REPO_COMPILER="Dark-Matter/moon"
REPO_FUEL="Dark-Matter/fuel"
PREFIX="${ROCKIT_PREFIX:-/usr/local}"
BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share/rockit"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${BOLD}==>${RESET} $1"; }
ok()    { echo -e "${GREEN}==>${RESET} $1"; }
fail()  { echo -e "${RED}error:${RESET} $1"; exit 1; }

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin) os="macos" ;;
        Linux)  os="linux" ;;
        *)      fail "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="x86_64" ;;
        *)             fail "Unsupported architecture: $arch" ;;
    esac

    echo "${os}-${arch}"
}

check_deps() {
    command -v clang >/dev/null 2>&1 || fail "clang is required.
  macOS:  xcode-select --install
  Linux:  sudo apt install clang"
}

# --- Try installing from prebuilt release ---
install_binary() {
    local platform="$1"
    local archive="rockit-${VERSION}-${platform}.tar.gz"
    local url="${GITEA}/${REPO_COMPILER}/releases/download/v${VERSION}/${archive}"
    local tmp="/tmp/rockit-install-$$"

    info "Checking for prebuilt binary (${platform})..."
    mkdir -p "$tmp"

    if curl -fSL "$url" -o "${tmp}/${archive}" 2>/dev/null; then
        info "Installing Rockit ${VERSION}..."
        tar -xzf "${tmp}/${archive}" -C "$tmp"

        local extracted="${tmp}/rockit-${VERSION}-${platform}/rockit"
        sudo mkdir -p "${BIN_DIR}" "${SHARE_DIR}"
        sudo cp "${extracted}/bin/rockit" "${BIN_DIR}/rockit"
        sudo cp "${extracted}/bin/fuel" "${BIN_DIR}/fuel"
        sudo chmod +x "${BIN_DIR}/rockit" "${BIN_DIR}/fuel"
        sudo cp "${extracted}/share/rockit/rockit_runtime.c" "${SHARE_DIR}/rockit_runtime.c"
        sudo cp "${extracted}/share/rockit/rockit_runtime.h" "${SHARE_DIR}/rockit_runtime.h"
        if [ -d "${extracted}/share/rockit/rockit" ]; then
            sudo mkdir -p "${SHARE_DIR}/rockit"
            sudo cp "${extracted}/share/rockit/rockit/"* "${SHARE_DIR}/rockit/"
        fi

        rm -rf "$tmp"
        return 0
    fi

    rm -rf "$tmp"
    return 1
}

# --- Fallback: build from source ---
install_source() {
    info "Building from source..."

    command -v swift >/dev/null 2>&1 || fail "Swift 5.9+ is required to build from source.
  Install from https://swift.org/download
  Or wait for prebuilt binaries at ${GITEA}/${REPO_COMPILER}/releases"
    command -v git >/dev/null 2>&1 || fail "Git is required."

    local tmp="/tmp/rockit-build-$$"
    rm -rf "$tmp"
    mkdir -p "$tmp"

    # Clone compiler
    info "Downloading Rockit compiler..."
    git clone --depth 1 --branch develop "${GITEA}/${REPO_COMPILER}.git" "${tmp}/moon" 2>&1 | tail -1

    # Build Stage 1 compiler
    info "Building compiler (this takes a minute)..."
    cd "${tmp}/moon/RockitCompiler"
    swift run rockit build-native Stage1/command.rok 2>&1

    # Clone and build Fuel
    info "Building Fuel package manager..."
    git clone --depth 1 --branch develop "${GITEA}/${REPO_FUEL}.git" "${tmp}/fuel" 2>&1 | tail -1
    Stage1/command build-native "${tmp}/fuel/src/fuel.rok" -o "${tmp}/fuel/fuel"

    # Install
    info "Installing to ${BIN_DIR}..."
    sudo mkdir -p "${BIN_DIR}" "${SHARE_DIR}"
    sudo cp Stage1/command "${BIN_DIR}/rockit"
    sudo cp "${tmp}/fuel/fuel" "${BIN_DIR}/fuel"
    sudo chmod +x "${BIN_DIR}/rockit" "${BIN_DIR}/fuel"
    sudo cp Runtime/rockit_runtime.c "${SHARE_DIR}/rockit_runtime.c"
    sudo cp Runtime/rockit_runtime.h "${SHARE_DIR}/rockit_runtime.h"
    if [ -d Runtime/rockit ]; then
        sudo mkdir -p "${SHARE_DIR}/rockit"
        sudo cp Runtime/rockit/*.rok "${SHARE_DIR}/rockit/"
        sudo cp Runtime/rockit/build.sh "${SHARE_DIR}/rockit/"
    fi

    rm -rf "$tmp"
    ok "Built and installed from source"
}

# --- Main ---
echo ""
echo "  Rockit Installer v${VERSION}"
echo "  Dark Matter Tech"
echo ""

PLATFORM=$(detect_platform)
check_deps

if install_binary "$PLATFORM"; then
    ok "Installed Rockit ${VERSION} (${PLATFORM})"
else
    info "No prebuilt binary for ${PLATFORM}, building from source..."
    install_source
fi

# --- Verify ---
echo ""
if command -v rockit >/dev/null 2>&1; then
    ok "rockit installed: $(rockit version 2>/dev/null || echo "${BIN_DIR}/rockit")"
else
    echo "  Add to your PATH:"
    echo "    export PATH=\"${BIN_DIR}:\$PATH\""
fi

if command -v fuel >/dev/null 2>&1; then
    ok "fuel installed: $(fuel version 2>/dev/null || echo "${BIN_DIR}/fuel")"
fi

echo ""
echo "  Get started:"
echo "    fuel init my-app"
echo "    cd my-app"
echo "    fuel build"
echo "    fuel run"
echo ""
echo "  Uninstall:"
echo "    sudo rm ${BIN_DIR}/rockit ${BIN_DIR}/fuel"
echo "    sudo rm -rf ${SHARE_DIR}"
echo ""
