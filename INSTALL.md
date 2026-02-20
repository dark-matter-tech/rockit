# Installing Rockit

Rockit is a compiled programming language by Dark Matter Tech. This guide covers installing the compiler (`rockit`), the C runtime, and the IntelliJ IDEA plugin for syntax highlighting.

---

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
```

This installs the `rockit` binary to `/usr/local/bin` and the runtime to `/usr/local/share/rockit/`.

### Windows (PowerShell)

```powershell
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.ps1 | iex
```

This installs to `%LOCALAPPDATA%\Rockit\bin` and adds it to your user PATH.

### Docker

```bash
docker build -t rockit RockitCompiler/
docker run --rm rockit run /usr/local/lib/rockit/examples/hello.rok
```

---

## Prerequisites

| Prerequisite | Version | Install |
|---|---|---|
| **Swift** | 5.9+ | [swift.org/download](https://swift.org/download) |
| **Clang/LLVM** | 14+ | `xcode-select --install` (macOS), `apt install clang` (Linux), [releases.llvm.org](https://releases.llvm.org) (Windows) |
| **Git** | any | [git-scm.com](https://git-scm.com) |

For native compilation (`rockit run-native`), Clang must be on your PATH.

---

## Install from Source

### 1. Clone the repository

```bash
git clone https://rustygits.com/Dark-Matter/moon.git
cd moon/RockitCompiler
```

### 2. Build

```bash
# Debug build (faster compile, slower runtime)
make build

# Release build (slower compile, optimized runtime)
make release
```

### 3. Install system-wide

```bash
# Installs to /usr/local (may need sudo on Linux)
sudo make install

# Or install to a custom location
make install PREFIX=$HOME/.local
```

### 4. Verify

```bash
rockit --version
rockit run Examples/hello.rok
```

---

## Custom Install Location

Set `ROCKIT_PREFIX` before running the install script:

```bash
# macOS / Linux
export ROCKIT_PREFIX=$HOME/.rockit
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
```

```powershell
# Windows
$env:ROCKIT_PREFIX = "$env:USERPROFILE\.rockit"
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.ps1 | iex
```

If the runtime is in a non-standard location, set:

```bash
export ROCKIT_RUNTIME_DIR=/path/to/rockit/runtime
```

---

## Docker

The Docker image includes everything needed — no local Swift or Clang required.

```bash
# Build the image
cd RockitCompiler
docker build -t rockit .

# Run a .rok file
docker run --rm rockit run /usr/local/lib/rockit/examples/hello.rok

# Mount your project directory
docker run --rm -v $(pwd):/code rockit run /code/main.rok

# Interactive REPL
docker run --rm -it rockit repl

# Native compilation inside the container
docker run --rm -v $(pwd):/code rockit run-native /code/main.rok
```

---

## IDE Support — IntelliJ IDEA Plugin

The **Rockit Language Support** plugin provides syntax highlighting, brace matching, comment toggling, and a configurable color scheme for `.rok` files in IntelliJ IDEA, WebStorm, CLion, or any JetBrains IDE.

### Install the plugin

**Option A: Install from disk (recommended)**

1. Build the plugin (or download from releases):
   ```bash
   cd ide/intellij-rockit
   ./gradlew buildPlugin
   ```
2. In IntelliJ: **Settings > Plugins > gear icon > Install Plugin from Disk...**
3. Select `build/distributions/intellij-rockit-0.1.0.zip`
4. Restart IntelliJ

**Option B: From JetBrains Marketplace**

Search for "Rockit Language Support" in **Settings > Plugins > Marketplace**.

### What the plugin provides

- **Syntax highlighting** for all 47 keywords, operators, and punctuation
- **Distinct color categories** — declaration keywords (pink), Rockit keywords like `view`/`actor` (purple), built-in types (teal)
- **Built-in type highlighting** — `String`, `Int`, `Bool`, `List`, `Map`, etc.
- **Built-in function highlighting** — `println`, `listOf`, `mapOf`, etc.
- **String interpolation** — `$name` and `${expr}` highlighted within strings
- **Code folding** — collapse functions, classes, block comments, and import groups
- **Nestable block comments** — `/* outer /* inner */ still outer */`
- **Number formats** — decimal, hex (`0xFF`), binary (`0b1010`), floats, underscores (`1_000_000`)
- **Annotations** — `@Capability`, `@State`, etc.
- **Brace matching** — `()`, `{}`, `[]` highlighting and navigation
- **Comment toggling** — Cmd+/ (line) and Cmd+Shift+/ (block)
- **Auto-close quotes** — typing `"` auto-inserts the closing `"`
- **Configurable colors** — Settings > Editor > Color Scheme > Rockit

### Supported JetBrains IDEs

Any JetBrains IDE based on IntelliJ Platform 2023.3+:
- IntelliJ IDEA (Community or Ultimate)
- WebStorm
- CLion
- PyCharm
- GoLand
- Rider
- Fleet (with plugin support)

---

## Uninstall

### macOS / Linux
```bash
make uninstall
# or manually:
rm /usr/local/bin/rockit
rm -rf /usr/local/share/rockit
```

### Windows
```powershell
Remove-Item -Recurse "$env:LOCALAPPDATA\Rockit"
```

### Docker
```bash
docker rmi rockit
```

### IntelliJ Plugin
Settings > Plugins > Installed > find "Rockit Language Support" > Uninstall

---

## Troubleshooting

**`rockit: command not found`**
- Ensure the install directory is on your PATH
- macOS/Linux: `export PATH="/usr/local/bin:$PATH"` (add to `~/.zshrc` or `~/.bashrc`)
- Windows: The installer adds to PATH automatically; restart your terminal

**`error: clang not found`**
- Native compilation requires Clang. Install it:
  - macOS: `xcode-select --install`
  - Linux: `sudo apt install clang`
  - Windows: Install LLVM from [releases.llvm.org](https://releases.llvm.org)

**`error: runtime not found`**
- Set `ROCKIT_RUNTIME_DIR` to the directory containing `rockit_runtime.c`:
  ```bash
  export ROCKIT_RUNTIME_DIR=/usr/local/share/rockit
  ```

**Docker build fails**
- Ensure Docker Desktop is running
- Try: `docker system prune` then rebuild

**IntelliJ plugin doesn't load**
- Check your IntelliJ version (Help > About) — requires 2023.3+
- Make sure you're installing the `.zip` from `build/distributions/`, not a `.jar`
- Restart IntelliJ after installing
