#!/usr/bin/env bash
# Rockit — Install Script
# Dark Matter Tech
#
# Usage:
#   curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/scripts/install.sh | bash
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

# Signing key URL — the GPG public key used to sign release manifests
SIGNING_KEY_URL="${GITEA}/${REPO_COMPILER}/raw/branch/master/RockitCompiler/keys/darkmatter-release.asc"
SIGNING_KEY_ID="Dark Matter Tech <security@darkmatter.tech>"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${BOLD}==>${RESET} $1"; }
ok()    { echo -e "${GREEN}==>${RESET} $1"; }
warn()  { echo -e "${YELLOW}==>${RESET} $1"; }
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

# --- Signature and manifest verification ---
import_signing_key() {
    if ! command -v gpg >/dev/null 2>&1; then
        warn "gpg not found — cannot verify signatures"
        warn "Install gnupg to enable signature verification:"
        warn "  macOS:  brew install gnupg"
        warn "  Linux:  sudo apt install gnupg"
        return 1
    fi

    # Check if we already have the key
    if gpg --list-keys "$SIGNING_KEY_ID" >/dev/null 2>&1; then
        return 0
    fi

    # Try to fetch the public key
    info "Importing Dark Matter release signing key..."
    local tmp_key="/tmp/rockit-key-$$.asc"
    if curl -fsSL "$SIGNING_KEY_URL" -o "$tmp_key" 2>/dev/null; then
        gpg --import "$tmp_key" 2>/dev/null
        rm -f "$tmp_key"
        if gpg --list-keys "$SIGNING_KEY_ID" >/dev/null 2>&1; then
            ok "Signing key imported"
            return 0
        fi
    fi

    rm -f "$tmp_key"
    warn "Could not import signing key — signature verification unavailable"
    return 1
}

verify_manifest_signature() {
    local manifest_file="$1"
    local sig_file="${manifest_file}.sig"

    if [ ! -f "$sig_file" ]; then
        warn "No signature file found (${sig_file})"
        warn "Skipping signature verification — release may be unsigned"
        return 0
    fi

    if ! command -v gpg >/dev/null 2>&1; then
        warn "gpg not found — skipping signature verification"
        return 0
    fi

    info "Verifying manifest signature..."
    if gpg --verify "$sig_file" "$manifest_file" 2>/dev/null; then
        ok "Manifest signature: VALID"
        return 0
    else
        fail "Manifest signature verification FAILED — the release may have been tampered with!"
        return 1
    fi
}

verify_manifest_hashes() {
    local manifest_file="$1"
    local base_dir="$2"

    if [ ! -f "$manifest_file" ]; then
        warn "No MANIFEST.sha256 found — skipping integrity check"
        return 0
    fi

    info "Verifying file integrity..."
    local failures=0
    local checked=0

    while IFS= read -r line; do
        # Format: sha256:<hash>  <filepath>
        local expected_hash
        expected_hash=$(echo "$line" | awk '{print $1}' | sed 's/^sha256://')
        local filepath
        filepath=$(echo "$line" | awk '{print $2}')

        if [ -z "$expected_hash" ] || [ -z "$filepath" ]; then
            continue
        fi

        local full_path="${base_dir}/${filepath}"
        if [ ! -f "$full_path" ]; then
            echo "    MISSING: $filepath"
            failures=$((failures + 1))
            continue
        fi

        local actual_hash
        actual_hash=$(shasum -a 256 "$full_path" | awk '{print $1}')

        if [ "$actual_hash" = "$expected_hash" ]; then
            checked=$((checked + 1))
        else
            echo "    MISMATCH: $filepath"
            echo "      expected: $expected_hash"
            echo "      actual:   $actual_hash"
            failures=$((failures + 1))
        fi
    done < "$manifest_file"

    if [ "$failures" -gt 0 ]; then
        fail "Integrity check FAILED — $failures file(s) corrupted or tampered with!"
        return 1
    fi

    ok "Integrity check passed ($checked files verified)"
    return 0
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

        # --- Verify release integrity ---
        # Try to import signing key (non-fatal if gpg unavailable)
        import_signing_key || true

        # Verify GPG signature on manifest
        if [ -f "${extracted}/MANIFEST.sha256" ]; then
            # Download the detached signature if it wasn't in the tarball
            if [ ! -f "${extracted}/MANIFEST.sha256.sig" ]; then
                local sig_url="${GITEA}/${REPO_COMPILER}/releases/download/v${VERSION}/MANIFEST.sha256.sig"
                curl -fsSL "$sig_url" -o "${extracted}/MANIFEST.sha256.sig" 2>/dev/null || true
            fi
            verify_manifest_signature "${extracted}/MANIFEST.sha256"
            verify_manifest_hashes "${extracted}/MANIFEST.sha256" "$extracted"
        else
            warn "No MANIFEST.sha256 in release — skipping integrity verification"
        fi

        # --- Install verified files ---
        sudo mkdir -p "${BIN_DIR}" "${SHARE_DIR}"
        sudo cp "${extracted}/bin/rockit" "${BIN_DIR}/rockit"
        sudo cp "${extracted}/bin/fuel" "${BIN_DIR}/fuel"
        sudo chmod +x "${BIN_DIR}/rockit" "${BIN_DIR}/fuel"
        sudo cp "${extracted}/share/rockit/rockit_runtime.o" "${SHARE_DIR}/rockit_runtime.o"
        if [ -d "${extracted}/share/rockit/stdlib" ]; then
            sudo cp -r "${extracted}/share/rockit/stdlib" "${SHARE_DIR}/stdlib"
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
    git clone --depth 1 --recurse-submodules --branch develop "${GITEA}/${REPO_COMPILER}.git" "${tmp}/moon" 2>&1 | tail -1

    # Build Stage 1 compiler
    info "Building compiler (this takes a minute)..."
    cd "${tmp}/moon/RockitCompiler"
    swift run rockit build-native self-hosted-rockit/command.rok 2>&1

    # Clone and build Fuel
    info "Building Fuel package manager..."
    git clone --depth 1 --branch develop "${GITEA}/${REPO_FUEL}.git" "${tmp}/fuel" 2>&1 | tail -1
    self-hosted-rockit/command build-native "${tmp}/fuel/src/fuel.rok" -o "${tmp}/fuel/fuel"

    # Install
    info "Installing to ${BIN_DIR}..."
    sudo mkdir -p "${BIN_DIR}" "${SHARE_DIR}"
    sudo cp self-hosted-rockit/command "${BIN_DIR}/rockit"
    sudo cp "${tmp}/fuel/fuel" "${BIN_DIR}/fuel"
    sudo chmod +x "${BIN_DIR}/rockit" "${BIN_DIR}/fuel"
    # Build and install the Rockit runtime
    if [ -d runtime/rockit ]; then
        cd runtime/rockit && bash build.sh && cd ../..
        sudo cp runtime/rockit_runtime.o "${SHARE_DIR}/rockit_runtime.o"
    fi
    # Install standard library
    if [ -d self-hosted-rockit/stdlib ]; then
        sudo cp -r self-hosted-rockit/stdlib "${SHARE_DIR}/stdlib"
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
