#!/usr/bin/env bash
# Rockit — Code Signing Wrapper
# Dark Matter Tech
#
# Signs release artifacts using platform-appropriate methods.
# Gracefully skips if no signing credentials are configured.
#
# Usage:
#   ./sign.sh <file>              # Auto-detect platform and sign
#   ./sign.sh <file> codesign     # Force macOS codesign
#   ./sign.sh <file> gpg          # Force GPG signing
#
# Environment variables:
#   APPLE_IDENTITY    — macOS codesign identity (e.g., "Developer ID Application: ...")
#   GPG_KEY_ID        — GPG key ID for signing (e.g., "ABCD1234")

set -euo pipefail

FILE="${1:-}"
METHOD="${2:-auto}"

if [ -z "$FILE" ]; then
    echo "Usage: sign.sh <file> [codesign|gpg|auto]"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "error: file not found: $FILE"
    exit 1
fi

sign_codesign() {
    local identity="${APPLE_IDENTITY:-}"
    if [ -z "$identity" ]; then
        echo "  No APPLE_IDENTITY set — skipping macOS code signing"
        return 0
    fi
    echo "  Signing with codesign (identity: $identity)..."
    codesign --force --sign "$identity" --timestamp "$FILE"
    echo "  Signed: $FILE"
}

sign_gpg() {
    local key="${GPG_KEY_ID:-}"
    if [ -z "$key" ]; then
        echo "  No GPG_KEY_ID set — skipping GPG signing"
        return 0
    fi
    if ! command -v gpg >/dev/null 2>&1; then
        echo "  gpg not found — skipping GPG signing"
        return 0
    fi
    echo "  Signing with GPG (key: $key)..."
    gpg --detach-sign --armor --default-key "$key" --output "${FILE}.sig" "$FILE"
    echo "  Signature: ${FILE}.sig"
}

sign_auto() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin)
            sign_codesign
            ;;
        Linux)
            sign_gpg
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "  Windows signing (signtool.exe) — not yet implemented"
            ;;
        *)
            echo "  Unknown platform: $os — skipping signing"
            ;;
    esac
}

case "$METHOD" in
    codesign) sign_codesign ;;
    gpg)      sign_gpg ;;
    auto)     sign_auto ;;
    *)        echo "Unknown method: $METHOD"; exit 1 ;;
esac
