#!/usr/bin/env bash
# Rockit Compiler — Install Script
# Dark Matter Tech
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.sh | bash
#
# Or clone and run locally:
#   ./install.sh

set -euo pipefail

REPO="Dark-Matter/moon"
GITHUB_API="https://api.github.com"
PREFIX="${ROCKIT_PREFIX:-/usr/local}"
INSTALL_DIR="${PREFIX}/bin"
LIB_DIR="${PREFIX}/lib/rockit"
TMPDIR="${TMPDIR:-/tmp}"
BUILD_DIR="${TMPDIR}/rockit-install-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${BOLD}==>${RESET} $1"; }
ok()    { echo -e "${GREEN}==>${RESET} $1"; }
fail()  { echo -e "${RED}error:${RESET} $1"; exit 1; }

# --- Detect platform ---
detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin) os="macos" ;;
        Linux)  os="linux" ;;
        *)      os="" ;;
    esac

    case "$arch" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64)  arch="x86_64" ;;
        *)             arch="" ;;
    esac

    if [ -n "$os" ] && [ -n "$arch" ]; then
        echo "${os}-${arch}"
    fi
}

# --- Try installing from prebuilt binary ---
install_binary() {
    local platform="$1"

    command -v curl >/dev/null 2>&1 || return 1

    info "Checking for prebuilt binary (${platform})..."

    # Get latest release tag
    local release_info
    release_info=$(curl -fsSL "${GITHUB_API}/repos/${REPO}/releases/latest" 2>/dev/null) || return 1

    local tag
    tag=$(echo "$release_info" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
    [ -n "$tag" ] || return 1

    local version="${tag#v}"
    local archive="rockit-${version}-${platform}.tar.gz"
    local download_url="https://github.com/${REPO}/releases/download/${tag}/${archive}"

    info "Downloading ${archive}..."
    local tmp_archive="${TMPDIR}/rockit-download-$$.tar.gz"
    curl -fSL "$download_url" -o "$tmp_archive" 2>/dev/null || return 1

    info "Installing to ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${LIB_DIR}"

    local tmp_extract="${TMPDIR}/rockit-extract-$$"
    mkdir -p "$tmp_extract"
    tar -xzf "$tmp_archive" -C "$tmp_extract"

    cp "${tmp_extract}/rockit/rockit" "${INSTALL_DIR}/rockit"
    chmod +x "${INSTALL_DIR}/rockit"
    if [ -d "${tmp_extract}/rockit/runtime" ]; then
        mkdir -p "${LIB_DIR}/runtime"
        cp "${tmp_extract}/rockit/runtime/"* "${LIB_DIR}/runtime/"
    fi

    rm -rf "$tmp_archive" "$tmp_extract"
    ok "Installed rockit ${version} (${platform})"
    return 0
}

# --- Fallback: build from source ---
install_source() {
    info "Building from source..."

    command -v swift >/dev/null 2>&1 || fail "Swift 5.9+ is required. Install from https://swift.org/download"
    command -v clang >/dev/null 2>&1 || fail "Clang is required. Install via: apt install clang (Linux) or xcode-select --install (macOS)"
    command -v git   >/dev/null 2>&1 || fail "Git is required."

    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    ok "Swift: ${SWIFT_VERSION}"
    ok "Clang: $(clang --version 2>&1 | head -1)"

    info "Downloading Rockit compiler..."
    rm -rf "${BUILD_DIR}"
    git clone --depth 1 "https://github.com/${REPO}.git" "${BUILD_DIR}" 2>/dev/null || \
        fail "Failed to clone repository. Check your network connection."

    cd "${BUILD_DIR}/RockitCompiler"

    info "Building (release mode)..."
    swift build -c release 2>&1 | tail -3

    info "Installing to ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${LIB_DIR}/runtime"

    cp .build/release/rockit "${INSTALL_DIR}/rockit"
    cp Runtime/rockit_runtime.c "${LIB_DIR}/runtime/"
    cp Runtime/rockit_runtime.h "${LIB_DIR}/runtime/"

    rm -rf "${BUILD_DIR}"
    ok "Installed rockit (built from source)"
}

# --- Main ---
PLATFORM=$(detect_platform)

if [ -n "$PLATFORM" ] && install_binary "$PLATFORM"; then
    : # Binary install succeeded
else
    if [ -n "$PLATFORM" ]; then
        info "No prebuilt binary available for ${PLATFORM}, falling back to source build..."
    fi
    install_source
fi

# --- Verify ---
if command -v rockit >/dev/null 2>&1; then
    ok "Installed successfully!"
    echo "  $(rockit version 2>/dev/null || echo "rockit ready")"
else
    echo ""
    echo "  rockit was installed to ${INSTALL_DIR}/rockit"
    echo "  Add it to your PATH if not already:"
    echo ""
    echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
fi

echo ""
echo "  Rockit is ready. Try:"
echo ""
echo "    rockit run hello.rok       # bytecode (interpreted)"
echo "    rockit run-native hello.rok # native (compiled via LLVM)"
echo "    rockit repl                 # interactive REPL"
echo ""
echo "  Update:    rockit update"
echo "  Uninstall: rm ${INSTALL_DIR}/rockit && rm -rf ${LIB_DIR}"
echo ""
