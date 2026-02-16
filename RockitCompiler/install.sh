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

REPO_URL="https://github.com/Dark-Matter/moon.git"
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

# --- Check prerequisites ---
info "Checking prerequisites..."

command -v swift >/dev/null 2>&1 || fail "Swift 5.9+ is required. Install from https://swift.org/download"
command -v clang >/dev/null 2>&1 || fail "Clang is required. Install via: apt install clang (Linux) or xcode-select --install (macOS)"
command -v git   >/dev/null 2>&1 || fail "Git is required."

SWIFT_VERSION=$(swift --version 2>&1 | head -1)
ok "Swift: ${SWIFT_VERSION}"
ok "Clang: $(clang --version 2>&1 | head -1)"

# --- Clone ---
info "Downloading Rockit compiler..."
rm -rf "${BUILD_DIR}"
git clone --depth 1 "${REPO_URL}" "${BUILD_DIR}" 2>/dev/null || \
    fail "Failed to clone repository. Check your network connection."

cd "${BUILD_DIR}/RockitCompiler"

# --- Build ---
info "Building (release mode)..."
swift build -c release 2>&1 | tail -3

# --- Install ---
info "Installing to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${LIB_DIR}/runtime"

cp .build/release/rockit "${INSTALL_DIR}/rockit"
cp Runtime/rockit_runtime.c "${LIB_DIR}/runtime/"
cp Runtime/rockit_runtime.h "${LIB_DIR}/runtime/"

# --- Verify ---
if command -v rockit >/dev/null 2>&1; then
    ok "Installed successfully!"
else
    echo ""
    echo "  rockit was installed to ${INSTALL_DIR}/rockit"
    echo "  Add it to your PATH if not already:"
    echo ""
    echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo ""
fi

# --- Cleanup ---
rm -rf "${BUILD_DIR}"

echo ""
echo "  Rockit is ready. Try:"
echo ""
echo "    rockit run hello.rok       # bytecode (interpreted)"
echo "    rockit run-native hello.rok # native (compiled via LLVM)"
echo "    rockit repl                 # interactive REPL"
echo ""
echo "  Uninstall: rm ${INSTALL_DIR}/rockit && rm -rf ${LIB_DIR}"
echo ""
