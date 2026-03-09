#!/usr/bin/env bash
# Rockit — Code Signing Pipeline
# Dark Matter Tech
#
# Signs release artifacts using all available methods:
#   1. GPG (universal baseline — always attempted on all platforms)
#   2. macOS codesign + notarization (Darwin only)
#   3. Windows Authenticode (Windows only, via signtool.exe)
#
# Usage:
#   ./sign.sh <file>                    # Auto-detect platform, sign with all available methods
#   ./sign.sh <file> gpg               # GPG only
#   ./sign.sh <file> codesign          # macOS codesign only
#   ./sign.sh <file> notarize          # macOS codesign + notarize
#   ./sign.sh <file> authenticode      # Windows Authenticode only
#   ./sign.sh <file> manifest          # Sign a MANIFEST.sha256 file (GPG detached sig)
#
# Environment variables:
#   GPG_KEY_ID              — GPG key ID for signing (e.g., "ABCD1234...")
#   GPG_PASSPHRASE          — GPG passphrase (for CI non-interactive use)
#   APPLE_IDENTITY          — macOS codesign identity (e.g., "Developer ID Application: Dark Matter Tech (TEAMID)")
#   APPLE_TEAM_ID           — Apple Developer Team ID (for notarization)
#   APPLE_ID                — Apple ID email (for notarization)
#   APPLE_APP_PASSWORD      — App-specific password (for notarization)
#   APPLE_KEYCHAIN_PROFILE  — Notarytool keychain profile (alternative to ID + password)
#   WIN_CERT_PATH           — Path to .pfx code signing certificate (Windows)
#   WIN_CERT_PASSWORD       — Certificate password (Windows)
#   WIN_TIMESTAMP_URL       — Timestamp server URL (default: http://timestamp.digicert.com)

set -euo pipefail

FILE="${1:-}"
METHOD="${2:-auto}"

if [ -z "$FILE" ]; then
    echo "Usage: sign.sh <file> [auto|gpg|codesign|notarize|authenticode|manifest]"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "error: file not found: $FILE"
    exit 1
fi

SIGNED_SOMETHING=false

# ---------------------------------------------------------------------------
# GPG signing — universal, works on all platforms
# ---------------------------------------------------------------------------
sign_gpg() {
    local key="${GPG_KEY_ID:-}"
    if [ -z "$key" ]; then
        echo "  [gpg] No GPG_KEY_ID set — skipping GPG signing"
        return 0
    fi
    if ! command -v gpg >/dev/null 2>&1; then
        echo "  [gpg] gpg not found — skipping GPG signing"
        return 0
    fi

    echo "  [gpg] Signing with GPG (key: $key)..."

    local gpg_args=(
        --detach-sign
        --armor
        --default-key "$key"
        --output "${FILE}.sig"
    )

    # Non-interactive mode for CI (passphrase via env var)
    if [ -n "${GPG_PASSPHRASE:-}" ]; then
        gpg_args+=(--batch --yes --pinentry-mode loopback --passphrase-fd 0)
        echo "$GPG_PASSPHRASE" | gpg "${gpg_args[@]}" "$FILE"
    else
        gpg "${gpg_args[@]}" "$FILE"
    fi

    echo "  [gpg] Signature: ${FILE}.sig"
    SIGNED_SOMETHING=true

    # Verify the signature we just created
    if gpg --verify "${FILE}.sig" "$FILE" >/dev/null 2>&1; then
        echo "  [gpg] Verification: OK"
    else
        echo "  [gpg] WARNING: Signature verification failed!"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# macOS codesign — binary signing with Apple Developer ID
# ---------------------------------------------------------------------------
sign_codesign() {
    local identity="${APPLE_IDENTITY:-}"
    if [ -z "$identity" ]; then
        echo "  [codesign] No APPLE_IDENTITY set — skipping macOS code signing"
        return 0
    fi
    if ! command -v codesign >/dev/null 2>&1; then
        echo "  [codesign] codesign not found (not macOS?) — skipping"
        return 0
    fi

    echo "  [codesign] Signing with identity: $identity"

    # --force: replace any existing signature
    # --sign: the identity to sign with
    # --timestamp: include a secure timestamp from Apple's server
    # --options runtime: enable hardened runtime (required for notarization)
    codesign --force \
        --sign "$identity" \
        --timestamp \
        --options runtime \
        "$FILE"

    echo "  [codesign] Signed: $FILE"
    SIGNED_SOMETHING=true

    # Verify
    if codesign --verify --deep --strict "$FILE" 2>/dev/null; then
        echo "  [codesign] Verification: OK"
    else
        echo "  [codesign] WARNING: Signature verification failed!"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# macOS notarization — submit to Apple for notarization + staple
# ---------------------------------------------------------------------------
sign_notarize() {
    # First, codesign the binary
    sign_codesign || return 1

    local team_id="${APPLE_TEAM_ID:-}"
    local profile="${APPLE_KEYCHAIN_PROFILE:-}"
    local apple_id="${APPLE_ID:-}"
    local app_password="${APPLE_APP_PASSWORD:-}"

    if [ -z "$team_id" ]; then
        echo "  [notarize] No APPLE_TEAM_ID set — skipping notarization"
        return 0
    fi
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "  [notarize] xcrun not found — skipping notarization"
        return 0
    fi

    # Create a zip for notarization (notarytool requires zip, dmg, or pkg)
    local zip_path="${FILE}.zip"
    ditto -c -k --keepParent "$FILE" "$zip_path"

    echo "  [notarize] Submitting to Apple for notarization..."

    if [ -n "$profile" ]; then
        # Use stored keychain profile (preferred for CI — set up once with
        # xcrun notarytool store-credentials)
        xcrun notarytool submit "$zip_path" \
            --keychain-profile "$profile" \
            --wait
    elif [ -n "$apple_id" ] && [ -n "$app_password" ]; then
        # Use Apple ID + app-specific password
        xcrun notarytool submit "$zip_path" \
            --apple-id "$apple_id" \
            --password "$app_password" \
            --team-id "$team_id" \
            --wait
    else
        echo "  [notarize] No credentials — need APPLE_KEYCHAIN_PROFILE or APPLE_ID + APPLE_APP_PASSWORD"
        rm -f "$zip_path"
        return 0
    fi

    rm -f "$zip_path"

    # Staple the notarization ticket to the binary
    echo "  [notarize] Stapling notarization ticket..."
    xcrun stapler staple "$FILE"

    echo "  [notarize] Notarization complete"
    SIGNED_SOMETHING=true
}

# ---------------------------------------------------------------------------
# Windows Authenticode — signtool.exe
# ---------------------------------------------------------------------------
sign_authenticode() {
    local cert_path="${WIN_CERT_PATH:-}"
    local cert_pass="${WIN_CERT_PASSWORD:-}"
    local timestamp_url="${WIN_TIMESTAMP_URL:-http://timestamp.digicert.com}"

    if [ -z "$cert_path" ]; then
        echo "  [authenticode] No WIN_CERT_PATH set — skipping Authenticode signing"
        return 0
    fi
    if [ ! -f "$cert_path" ]; then
        echo "  [authenticode] Certificate file not found: $cert_path"
        return 1
    fi

    # Find signtool.exe
    local signtool=""
    if command -v signtool.exe >/dev/null 2>&1; then
        signtool="signtool.exe"
    else
        # Search in Windows SDK directories
        local sdk_base="/c/Program Files (x86)/Windows Kits/10/bin"
        if [ -d "$sdk_base" ]; then
            signtool=$(find "$sdk_base" -name "signtool.exe" -path "*/x64/*" 2>/dev/null | sort -V | tail -1)
        fi
    fi

    if [ -z "$signtool" ]; then
        echo "  [authenticode] signtool.exe not found — skipping Authenticode signing"
        echo "  [authenticode] Install Windows SDK or add signtool.exe to PATH"
        return 0
    fi

    echo "  [authenticode] Signing with Authenticode..."

    local sign_args=(
        sign
        /f "$cert_path"
        /fd sha256
        /tr "$timestamp_url"
        /td sha256
    )

    if [ -n "$cert_pass" ]; then
        sign_args+=(/p "$cert_pass")
    fi

    sign_args+=("$FILE")

    "$signtool" "${sign_args[@]}"

    echo "  [authenticode] Signed: $FILE"
    SIGNED_SOMETHING=true

    # Verify
    if "$signtool" verify /pa "$FILE" >/dev/null 2>&1; then
        echo "  [authenticode] Verification: OK"
    else
        echo "  [authenticode] WARNING: Signature verification failed!"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Manifest signing — GPG sign a MANIFEST.sha256 file
# ---------------------------------------------------------------------------
sign_manifest() {
    echo "  [manifest] Signing release manifest..."
    sign_gpg
}

# ---------------------------------------------------------------------------
# Auto-detect: GPG always + platform-specific
# ---------------------------------------------------------------------------
sign_auto() {
    local os
    os="$(uname -s)"

    # GPG is the universal baseline — always attempt it
    sign_gpg

    # Platform-specific signing on top
    case "$os" in
        Darwin)
            sign_codesign
            # Notarization only if team ID is configured
            if [ -n "${APPLE_TEAM_ID:-}" ]; then
                # Don't re-codesign — notarize uses the existing signature
                local profile="${APPLE_KEYCHAIN_PROFILE:-}"
                local apple_id="${APPLE_ID:-}"
                local app_password="${APPLE_APP_PASSWORD:-}"

                if [ -n "$profile" ] || { [ -n "$apple_id" ] && [ -n "$app_password" ]; }; then
                    local zip_path="${FILE}.zip"
                    ditto -c -k --keepParent "$FILE" "$zip_path"
                    echo "  [notarize] Submitting to Apple for notarization..."
                    if [ -n "$profile" ]; then
                        xcrun notarytool submit "$zip_path" --keychain-profile "$profile" --wait
                    else
                        xcrun notarytool submit "$zip_path" \
                            --apple-id "$apple_id" \
                            --password "$app_password" \
                            --team-id "${APPLE_TEAM_ID}" \
                            --wait
                    fi
                    rm -f "$zip_path"
                    xcrun stapler staple "$FILE"
                    echo "  [notarize] Notarization complete"
                fi
            fi
            ;;
        Linux)
            # GPG already ran above — nothing else needed on Linux
            ;;
        MINGW*|MSYS*|CYGWIN*)
            sign_authenticode
            ;;
        *)
            echo "  Unknown platform: $os — GPG signing only"
            ;;
    esac

    if [ "$SIGNED_SOMETHING" = false ]; then
        echo "  No signing credentials configured — artifact is unsigned"
        echo "  Set GPG_KEY_ID for universal signing, or platform-specific vars"
    fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
echo "==> Signing: $FILE (method: $METHOD)"

case "$METHOD" in
    gpg)           sign_gpg ;;
    codesign)      sign_codesign ;;
    notarize)      sign_notarize ;;
    authenticode)  sign_authenticode ;;
    manifest)      sign_manifest ;;
    auto)          sign_auto ;;
    *)             echo "Unknown method: $METHOD"; exit 1 ;;
esac
