# Rockit Signing Keys

This directory will contain public keys used for release verification.

## Key Distribution Plan

| Key | Purpose | Format |
|-----|---------|--------|
| Dark Matter Release Key | Verifies release manifests (MANIFEST.sha256.sig) | GPG public key (.asc) |
| Apple Developer ID | macOS binary notarization | Managed via Apple Developer account |
| Authenticode Certificate | Windows binary signing | Managed via certificate authority |

## How Verification Works

1. Release tarballs include `MANIFEST.sha256` (hashes of all files)
2. `MANIFEST.sha256.sig` is a GPG detached signature of the manifest
3. Install scripts verify the signature, then verify each file hash

## Adding Keys

Public keys will be published here when the signing infrastructure is operational.
They will also be available at `https://rockit.dev/.well-known/rockit-keys.json`.
