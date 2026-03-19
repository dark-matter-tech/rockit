# Rockit Compiler Security Architecture

## Overview

This document defines the security architecture for the Rockit toolchain. The goal
is end-to-end integrity: from source code to compiled output, from package registry
to browser execution, every artifact is verifiable and every link in the chain is
authenticated.

## Threat Model

| Threat | Example | Mitigation Layer |
|--------|---------|-----------------|
| Tampered compiler binary | Attacker modifies `rockit` binary in distribution | Layers 1-3 |
| Compromised build environment | CI runner injects backdoor during build | Layers 4-5 |
| Supply chain attack on dependencies | Malicious stdlib or Fuel package | Layers 2, 7 |
| Trojan compiler (Thompson attack) | Compiler inserts backdoor not present in source | Layers 4-5 |
| Tampered bytecode in transit | Man-in-the-middle modifies .rokb served to Nova | Layers 6, 9 |
| Compromised signing key | Attacker signs malicious release with stolen key | Layer 8 |
| Rollback attack | Attacker serves old, vulnerable version as current | Layers 2, 8 |

## Security Layers

### Layer 1 — Build Identity

**Status:** Implemented
**Priority:** Immediate

Embed build metadata as compile-time constants in the compiler binary:

- `ROCKIT_VERSION` — semantic version (e.g., `0.1.0`)
- `ROCKIT_GIT_HASH` — full git commit SHA at build time
- `ROCKIT_SOURCE_HASH` — SHA-256 of `command.rok` (the concatenated source)
- `ROCKIT_BUILD_TIMESTAMP` — ISO 8601 UTC build time
- `ROCKIT_BUILD_PLATFORM` — target platform (e.g., `macos-arm64`, `linux-x86_64`, `windows-x86_64`)

Output via `rockit version`:

```
rockit 0.1.0
commit:    a1b2c3d4e5f6...
source:    sha256:9f86d08...
built:     2026-03-06T12:00:00Z
platform:  macos-arm64
```

**Implementation:**
- `build.sh` computes git hash, source hash, timestamp, platform
- Injects constants into `command.rok` before compilation
- `codegen.rok` main() reads constants for `version` command

### Layer 2 — Release Manifest

**Status:** Implemented
**Priority:** High

Every release tarball includes `MANIFEST.sha256` containing SHA-256 hashes of
every file in the distribution:

```
sha256:abc123...  bin/rockit
sha256:def456...  bin/fuel
sha256:789abc...  share/rockit/rockit_runtime.o
sha256:012def...  share/rockit/stdlib/rockit/core/collections.rok
...
```

The manifest itself is signed (Layer 3). Verification:

- `install.sh` / `install.ps1` verify manifest signature, then verify each file hash
- `rockit verify-install` — post-install integrity check

**Implementation:**
- `package.sh` generates `MANIFEST.sha256` after building
- `package.sh` signs manifest with release key
- `install.sh` and `install.ps1` verify before installing

### Layer 3 — Code Signing

**Status:** Implemented
**Priority:** High

Platform-native code signing for the compiler binary, plus GPG as the universal
baseline that works on all platforms:

| Platform | Method | Tool | Env Vars |
|----------|--------|------|----------|
| All | GPG detached signature | `gpg --detach-sign` | `GPG_KEY_ID`, `GPG_PASSPHRASE` |
| macOS | Codesign + Notarization | `codesign`, `notarytool` | `APPLE_IDENTITY`, `APPLE_TEAM_ID`, `APPLE_ID`, `APPLE_APP_PASSWORD` |
| Windows | Authenticode | `signtool.exe` | `WIN_CERT_PATH`, `WIN_CERT_PASSWORD` |

GPG signing runs on every platform as the universal verification path.
Platform-specific signing (codesign, Authenticode) runs in addition to GPG
on macOS and Windows respectively.

**Verification flow (install.sh / install.ps1):**
1. Import Dark Matter public key from `keys/darkmatter-release.asc`
2. Verify GPG signature on `MANIFEST.sha256` → confirms manifest integrity
3. Verify SHA-256 hash of every file against the manifest → confirms file integrity

**Key management:**
- Signing keys stored in hardware security module (HSM) or secure vault
- CI/CD imports `GPG_PRIVATE_KEY` secret for automated signing
- Public keys published in the repo (`keys/`) and at well-known URL
- `sign.sh` gracefully skips signing when credentials are not configured (dev builds)

### Layer 3.5 — DO-178C Safety Verification

**Status:** Implemented
**Priority:** High

The compiler includes a safety verification pass supporting DO-178C Design Assurance Levels A through E and DO-330 TQL-1 tool qualification:

- **SafetyVerifier** checks source code against configurable DAL levels, enforcing restrictions on dynamic allocation, unbounded recursion/loops, closures, exceptions, async/await, dynamic strings, and heap construction
- **LLVM debug metadata** — `DICompileUnit`, `DIFile`, `DISubprogram`, `DILocation` with `!dbg` annotations on instructions for source-to-binary traceability
- **MIR source maps** track instruction-level mapping from MIR back to original `.rok` source line/column
- **Audit trail** — `--audit <path>` flag generates a JSON report containing compiler version, phase-by-phase artifacts, and safety verification results with violation details and compliant alternatives
- Each safety violation includes an engineering rationale (ARC-specific costs, WCET impact) and a compliant alternative (pool allocation, `Result<T>`, bounded iteration, `Ptr<T>` buffers)

Both Stage 0 (Swift) and Stage 1 (Rockit) emit identical debug metadata, ensuring traceability is maintained through the bootstrap chain.

### Layer 4 — Bootstrap Chain Verification

**Status:** Implemented (`rockit verify-bootstrap` command + CI verification)
**Priority:** High

Formalize the bootstrap verification process:

```
Stage 0 (Swift)  compiles  command.rok  →  Stage 1 binary  (hash: H1)
Stage 1 binary   compiles  command.rok  →  Stage 2 binary  (hash: H2)
Stage 2 binary   compiles  command.rok  →  Stage 3 binary  (hash: H3)
                                            Verify: H2 == H3
```

**Implementation:**
- `rockit verify-bootstrap` command that runs the full chain automatically
- Prints hash at each stage, reports pass/fail
- Expected Stage 2 hash published with each release
- CI runs bootstrap verification on every release build

### Layer 5 — Reproducible Builds

**Status:** Not implemented
**Priority:** Medium

Guarantee: same source + same compiler version + same platform = identical binary.

Requirements:
- Pin clang/LLVM version in build scripts
- Strip timestamps from object files (`-Wno-builtin-macro-redefined -D__DATE__= -D__TIME__=`)
- Deterministic linking order (already achieved — `build.sh` concatenation is ordered)
- Document exact build environment (OS version, clang version, SDK version)
- CI publishes build environment spec alongside each release

Verification: anyone can clone the repo, follow the build instructions, and produce
a binary with the same SHA-256 as the published release.

### Layer 6 — Compiled Output Provenance

**Status:** Not implemented
**Priority:** Medium (needed before Fuel/Silo launch)

When the compiler produces output, it can optionally embed provenance metadata:

**Bytecode (.rokb):**
```
Header:
  magic:            ROKB
  version:          1
  compiler_hash:    sha256 of compiler that produced this
  source_hash:      sha256 of source files
  timestamp:        build time
  signature:        optional — publisher signs the bytecode
```

**Native binary:**
- Provenance embedded in a custom ELF/Mach-O/PE section
- Extractable via `rockit inspect <binary>`

**Commands:**
- `rockit build-native app.rok --sign --key <keyfile>` — sign output
- `rockit inspect <file>` — show provenance metadata
- `rockit verify <file>` — verify signature

### Layer 7 — Package Signing (Fuel / Silo)

**Status:** Not implemented
**Priority:** Medium (needed for Silo launch)

Every package published to Silo is signed by the publisher:

- Publishers register a public key with Silo
- `fuel publish` signs the package with the publisher's private key
- `fuel install` verifies the signature before extracting
- `fuel audit` checks integrity of all installed packages

Package manifest (`fuel.toml`) includes:
```toml
[package]
name = "mylib"
version = "1.0.0"
publisher = "darkmattech"
signature = "sha256:..."
```

### Layer 8 — Binary Transparency Log

**Status:** Not implemented
**Priority:** Low (hardening)

A public, append-only ledger of every official release:

```
timestamp       version   platform       sha256
2026-03-06T...  0.1.0     macos-arm64    abc123...
2026-03-06T...  0.1.0     linux-x86_64   def456...
2026-03-06T...  0.1.0     windows-x86_64 789abc...
```

- Hosted publicly (e.g., Git repo, or dedicated transparency service)
- Community monitors for unauthorized entries
- Detects key compromise: if a signed binary appears that Dark Matter didn't publish,
  the transparency log reveals the discrepancy
- Inspired by Certificate Transparency (RFC 6962)

### Layer 9 — Nova Code Verification

**Status:** Not implemented
**Priority:** Future (needed for Nova browser launch)

Rockit web apps served to Nova carry publisher signatures:

- `.rokb` files include a signature header (Layer 6)
- Nova verifies the signature before executing
- Trust model: publisher keys registered with Silo
- Unsigned code: refused or run in restricted sandbox
- Revocation: Silo maintains a revocation list for compromised keys

This replaces the web's current model (TLS verifies the server, but code is
unsigned) with code-level authentication: the *code itself* is signed, not just
the transport.

```
User visits app.rok → Nova downloads .rokb
  → Verify publisher signature against Silo key registry
  → Verify compiler provenance (Layer 6)
  → If valid: execute via Rockit Engine (fast path)
  → If invalid: refuse / sandbox / warn user
```

## Implementation Roadmap

| Phase | Layers | Milestone |
|-------|--------|-----------|
| 1 | 1, 2, 3 | Secure distribution — every release is verifiable |
| 2 | 4, 5 | Trusted builds — bootstrap and reproducibility verified |
| 3 | 6, 7 | Trusted output — compiler output and packages are signed |
| 4 | 8, 9 | Ecosystem trust — transparency log and Nova verification |

## Key Distribution

| Key | Purpose | Storage |
|-----|---------|---------|
| Dark Matter Release Key | Signs release manifests and binaries | HSM / secure vault |
| Apple Developer ID | macOS codesign + notarization | Apple Developer account |
| Authenticode Certificate | Windows code signing | Certificate authority |
| Dark Matter GPG Key | Linux binary signatures | GPG keyring (HSM-backed) |
| Publisher Keys (Silo) | Package signing by third parties | Silo registry |

Public keys are published:
- In the repository (`keys/` directory)
- At `https://rockit.dev/.well-known/rockit-keys.json`
- In Silo's key registry
