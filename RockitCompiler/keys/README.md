# Rockit Signing Keys

This directory contains public keys used for release verification.

## Key Distribution Plan

| Key | Purpose | Format |
|-----|---------|--------|
| Dark Matter Release Key | Verifies release manifests and binaries (GPG) | `darkmatter-release.asc` |
| Apple Developer ID | macOS binary codesign + notarization | Managed via Apple Developer account |
| Authenticode Certificate | Windows binary signing | Managed via certificate authority |

## How Verification Works

1. Release tarballs include `MANIFEST.sha256` (SHA-256 hashes of all files)
2. `MANIFEST.sha256.sig` is a GPG detached signature of the manifest
3. Install scripts automatically:
   - Import the public key from this directory
   - Verify the GPG signature on the manifest
   - Verify each file hash against the manifest
4. On macOS, binaries are also codesigned + notarized (Apple verification)
5. On Windows, binaries are Authenticode-signed (OS-level trust)

## Setting Up Signing

### GPG (universal — all platforms)

Generate a dedicated release signing key:

```bash
gpg --full-generate-key
# Select: RSA and RSA, 4096 bits, does not expire
# Name: Dark Matter Tech
# Email: security@darkmatter.tech

# Export the public key for the repo
gpg --armor --export "Dark Matter Tech" > keys/darkmatter-release.asc

# Export the private key for CI (store as GPG_PRIVATE_KEY secret)
gpg --armor --export-secret-keys "Dark Matter Tech" | base64

# Get the key ID (for GPG_KEY_ID env var)
gpg --list-secret-keys --keyid-format long
```

CI secrets needed:
- `GPG_PRIVATE_KEY` — base64-encoded private key (or raw armored)
- `GPG_PASSPHRASE` — key passphrase (for non-interactive CI use)

### macOS Codesign + Notarization

Requires an Apple Developer ID ($99/year).

```bash
# List available signing identities
security find-identity -v -p codesigning

# Store the identity name as APPLE_IDENTITY, e.g.:
# "Developer ID Application: Dark Matter Tech (TEAMID)"

# For notarization, create an app-specific password at appleid.apple.com
# Or use xcrun notarytool store-credentials to save a keychain profile
xcrun notarytool store-credentials "rockit-notary" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

CI secrets needed:
- `APPLE_IDENTITY` — codesign identity string
- `APPLE_TEAM_ID` — Apple Developer Team ID
- `APPLE_ID` — Apple ID email
- `APPLE_APP_PASSWORD` — app-specific password
- Or: `APPLE_KEYCHAIN_PROFILE` — stored notarytool profile name

### Windows Authenticode

Options:
1. **Free (self-signed):** `New-SelfSignedCertificate` — works for testing, not trusted by Windows
2. **Paid ($200-400/year):** Code signing certificate from DigiCert, Sectigo, etc.
3. **Free (open source):** SignPath.io offers free code signing for open source projects

```powershell
# Export certificate as .pfx (store as WIN_CERT_PATH secret or base64)
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert
Export-PfxCertificate -Cert $cert -FilePath "rockit-signing.pfx" -Password (ConvertTo-SecureString -String "password" -AsPlainText -Force)
```

CI secrets needed:
- `WIN_CERT_PATH` — path to .pfx certificate (or decoded from base64 in CI)
- `WIN_CERT_PASSWORD` — certificate password
- `WIN_TIMESTAMP_URL` — timestamp server (default: http://timestamp.digicert.com)

## Adding Public Keys

When the GPG signing key is generated, export and commit the public key:

```bash
gpg --armor --export "Dark Matter Tech" > keys/darkmatter-release.asc
git add keys/darkmatter-release.asc
git commit -m "Add Dark Matter GPG release signing public key"
```

The public key will also be published at `https://rockit.dev/.well-known/rockit-keys.json`.
