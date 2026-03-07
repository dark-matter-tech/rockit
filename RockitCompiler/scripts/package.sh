#!/usr/bin/env bash
# Rockit — Release Packaging Script
# Dark Matter Tech
#
# Builds rockit + fuel and creates a release tarball for the current platform.
#
# Usage:
#   ./package.sh                     # build and package
#   ./package.sh --fuel-path /path   # use external fuel repo
#
# Output:
#   dist/rockit-VERSION-PLATFORM.tar.gz

set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
FUEL_REPO="${FUEL_REPO:-https://rustygits.com/Dark-Matter/fuel.git}"

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

# Parse args
FUEL_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fuel-path) FUEL_PATH="$2"; shift 2 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

PLATFORM=$(detect_platform)
ARCHIVE_NAME="rockit-${VERSION}-${PLATFORM}"

info "Packaging Rockit ${VERSION} for ${PLATFORM}"

# --- Step 1: Build Stage 1 compiler ---
COMPILER="${PROJECT_DIR}/self-hosted-rockit/command"
RUNTIME="${PROJECT_DIR}/runtime/rockit_runtime.c"

if [[ ! -f "$COMPILER" ]]; then
    info "Building Stage 1 compiler..."
    cd "$PROJECT_DIR"
    swift run rockit build-native self-hosted-rockit/command.rok
fi

[[ -f "$COMPILER" ]] || fail "Stage 1 compiler not found at ${COMPILER}"
[[ -f "$RUNTIME" ]]  || fail "Runtime not found at ${RUNTIME}"

ok "Compiler ready: ${COMPILER}"

# --- Step 2: Build Fuel ---
if [[ -n "$FUEL_PATH" ]]; then
    FUEL_SRC="${FUEL_PATH}"
else
    FUEL_SRC="/tmp/rockit-fuel-$$"
    info "Cloning Fuel..."
    git clone --depth 1 --branch develop "${FUEL_REPO}" "${FUEL_SRC}" 2>&1 | tail -1
fi

info "Building Fuel..."
"$COMPILER" build-native "${FUEL_SRC}/src/fuel.rok" -o "${FUEL_SRC}/fuel" --runtime-path "$RUNTIME"
ok "Fuel built"

# --- Step 3: Create release layout ---
STAGING="${DIST_DIR}/${ARCHIVE_NAME}/rockit"
rm -rf "${DIST_DIR}/${ARCHIVE_NAME}"
mkdir -p "${STAGING}/bin" "${STAGING}/share/rockit"

cp "$COMPILER"                    "${STAGING}/bin/rockit"
cp "${FUEL_SRC}/fuel"             "${STAGING}/bin/fuel"
cp "$RUNTIME"                     "${STAGING}/share/rockit/rockit_runtime.c"
cp "${PROJECT_DIR}/runtime/rockit_runtime.h" "${STAGING}/share/rockit/rockit_runtime.h"
cp -r "${PROJECT_DIR}/self-hosted-rockit/stdlib"          "${STAGING}/share/rockit/stdlib"
chmod +x "${STAGING}/bin/rockit" "${STAGING}/bin/fuel"

# Clean up temp clone
if [[ -z "$FUEL_PATH" && -d "$FUEL_SRC" ]]; then
    rm -rf "$FUEL_SRC"
fi

# --- Step 4: Generate release manifest ---
info "Generating release manifest..."
cd "$STAGING"
find . -type f ! -name "MANIFEST.sha256" | sort | while read -r f; do
    hash=$(shasum -a 256 "$f" | awk '{print $1}')
    echo "sha256:${hash}  ${f#./}" >> MANIFEST.sha256
done
ok "Manifest generated: MANIFEST.sha256"
cd "$DIST_DIR"

# --- Step 5: Sign release (if credentials available) ---
if [ -f "${SCRIPT_DIR}/sign.sh" ]; then
    bash "${SCRIPT_DIR}/sign.sh" "${STAGING}/MANIFEST.sha256" || true
fi

# --- Step 6: Create tarball ---
mkdir -p "$DIST_DIR"
cd "$DIST_DIR"
tar -czf "${ARCHIVE_NAME}.tar.gz" "${ARCHIVE_NAME}"
rm -rf "${ARCHIVE_NAME}"

ok "Package created: dist/${ARCHIVE_NAME}.tar.gz"
echo ""
echo "  Contents:"
echo "    rockit/bin/rockit              — Rockit compiler"
echo "    rockit/bin/fuel                — Fuel package manager"
echo "    rockit/share/rockit/rockit_runtime.c — C runtime"
echo "    rockit/share/rockit/stdlib/    — Standard library"
echo "    rockit/MANIFEST.sha256         — File integrity manifest"
echo ""
echo "  Upload to Gitea releases:"
echo "    https://rustygits.com/Dark-Matter/moon/releases/new"
echo ""
