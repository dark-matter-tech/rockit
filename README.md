# Rockit

A statically-typed, compiled, memory-safe programming language designed to replace JavaScript, HTML, CSS, and the DOM as the foundational technology of the web platform.

Built by [Dark Matter Tech](https://github.com/Dark-Matter).

---

## Status

The compiler is **self-hosting** — Rockit compiles itself. All compiler phases are complete and 539+ tests pass across the full pipeline.

| Component | Status |
|-----------|--------|
| Lexer | Complete |
| Parser | Complete |
| Type Checker | Complete |
| MIR Lowering | Complete |
| Optimizer | Complete |
| Codegen (bytecode + native) | Complete |
| Runtime (ARC, actors, coroutines) | Complete |
| Structured concurrency (VM) | Complete |
| Self-hosting bootstrap | Complete |
| Editor support | VS Code, JetBrains, Vim/Neovim |

---

## Quick Start

### Install

**macOS / Linux (one-liner):**
```bash
curl -fsSL https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.ps1 | iex
```

The installer downloads a prebuilt binary if available, or builds from source as a fallback.

**Or build manually:**
```bash
git clone https://github.com/Dark-Matter/moon.git
cd moon/RockitCompiler
make release && sudo make install
```

### Update

```bash
rockit update
```

### Hello World

```kotlin
// hello.rok
fun main() {
    println("Hello, Rockit!")
}
```

```bash
rockit run hello.rok
```

---

## Language Overview

Rockit's syntax is Kotlin-inspired with purpose-built constructs for UI, concurrency, and styling:

```kotlin
// Data classes with null safety
data class User(val name: String, val email: String?)

// Pattern matching
fun greet(user: User) {
    val display = user.email ?: "no email"
    println("Hello, ${user.name} ($display)")
}

// Declarative UI
view Greeting(val name: String) {
    Text("Hello, $name!")
}

// Thread-safe concurrency
actor Counter {
    private var count: Int = 0
    suspend fun increment() { count += 1 }
    suspend fun get(): Int = count
}

// Structured concurrency
suspend fun loadData(client: HttpClient) {
    concurrent {
        val users = await client.get("/users")
        val posts = await client.get("/posts")
    }
}

// Type-safe styling
theme AppTheme {
    val primary = Color.BLUE
    val background = "#1E1E2E"
}

// Declarative navigation
navigation AppRouter {
    route("/") { Greeting("Rockit") }
    route("/counter") { Counter() }
}
```

### Key Features

- **Null safety** enforced at compile time (`String` vs `String?`, `?.`, `?:`, `!!`)
- **Sealed classes** with exhaustive `when` matching
- **Data classes** with destructuring
- **Generics** with variance (`out`, `in`)
- **String interpolation** (`"Hello, ${name}"`)
- **ARC memory model** with compile-time cycle analysis — no garbage collector
- **Actors** for thread-safe concurrent objects
- **Structured concurrency** with `suspend`, `async`, `await`, `concurrent`
- **Views** for declarative UI components
- **Themes** and **styles** for type-safe styling

---

## Ecosystem

| Tool | Name | Description |
|------|------|-------------|
| Language | **Rockit** | `.rok` / `.rokb` files |
| Compiler | **Command** | Compiles, runs, and manages Rockit projects |
| Package Manager | **Fuel** | Dependency management |
| Test Framework | **Probe** | Built-in testing |
| Registry | **Silo** | Package registry |
| REPL | **Launch** | Interactive shell |

---

## Editor Support

All editors share a single canonical syntax definition (`ide/shared/rockit-language.json`). Add a keyword once, regenerate, and every editor updates.

### Quick Install (all editors)

Auto-detects and installs Rockit support for every editor on your system:

**macOS / Linux / Windows (WSL, Git Bash):**
```bash
curl -fsSL https://raw.githubusercontent.com/Dark-Matter/moon/master/ide/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/ide/install.ps1 | iex
```

### VS Code

Full extension with syntax highlighting, 25+ snippets, bracket matching, and auto-close pairs.

**Install from source:**
```bash
cd ide/vscode
# Install with: code --install-extension .
# Or copy to ~/.vscode/extensions/rockit-lang-0.1.0/
```

### JetBrains (IntelliJ IDEA, WebStorm, CLion, etc.)

Full plugin with JFlex lexer, syntax highlighting, code folding, brace matching, and configurable Xcode/Swift-inspired color themes.

**Install:** Settings > Plugins > gear icon > Install Plugin from Disk > select `intellij-rockit-0.1.0.zip`

```bash
cd ide/intellij-rockit
./gradlew buildPlugin
# Output: build/distributions/intellij-rockit-0.1.0.zip
```

### Vim / Neovim

Syntax highlighting and filetype detection.

**Install manually:**
```bash
cp ide/vim/syntax/rockit.vim ~/.vim/syntax/
cp ide/vim/ftdetect/rockit.vim ~/.vim/ftdetect/
```

**Or with a plugin manager (e.g. vim-plug):**
```vim
Plug 'Dark-Matter/moon', { 'rtp': 'ide/vim' }
```

### Regenerating Editor Files

When you modify `rockit-language.json`, regenerate all editor syntax files:

```bash
cd ide/shared
python3 generate.py
```

---

## Performance

The native compiler includes several optimizations that make Rockit competitive with established languages:

- **Escape Analysis & Stack Promotion** — Value-type `data class` instances that don't escape are stack-allocated via LLVM `alloca` instead of heap-allocated. Interprocedural analysis proves parameters don't escape through read-only callees.
- **MIR Function Inlining** — Small single-block functions with value-type parameters are inlined at the MIR level, exposing `newObject` calls to escape analysis for stack promotion.
- **Immortal String Literals** — String constants live in the binary's read-only data segment and bypass ARC entirely.
- **Inline ARC** — String retain/release is emitted as inline LLVM IR instead of function calls.
- **ARC Write Barriers** — The compiler tracks `ptrFieldBits` per object so `rockit_release` only scans fields that actually contain heap pointers.
- **Value Types** — `data class` with only primitive fields uses inline GEP field access and skips ARC.
- **Inline List Access** — `listGet`, `listSet`, and `listSize` compile to direct GEP memory operations with inline bounds checks.
- **Inline Integer Comparison** — `==` and `!=` on known integers compile to a single `icmp` instruction.
- **TBAA Alias Analysis** — List struct field loads are annotated with LLVM TBAA metadata, letting LLVM hoist loads out of inner loops.
- **Multi-String Concat Flattening** — Chains of string `+` operations are flattened into a single `concat_n` call that allocates once.
- **Bulk List Initialization** — `listCreateFilled(size, value)` allocates and fills in a single `malloc` + `memset`.
- **Internal Linkage** — Non-`main` functions use `internal` linkage, giving LLVM full freedom to inline and optimize.

### Benchmarks

All benchmarks run on Apple M1, best of 3 runs.

#### Core Benchmarks

| Benchmark | Rockit | Go | Node.js |
|-----------|--------|-----|---------|
| **Fibonacci** (fib 40, recursive) | **0.31s** | 0.34s | 1.03s |
| **Object alloc** (1M data class) | **0.002s** | 0.003s | 0.07s |
| **Prime sieve** (primes to 1M) | **0.004s** | 0.004s | 0.07s |
| **Matrix multiply** (200x200) | **0.006s** | 0.011s | 0.08s |
| **Quicksort** (500K integers) | **0.031s** | 0.034s | 0.18s |
| **String concat** (500K iterations) | **0.17s** | 0.35s | **0.06s** |
| **Monkey interpreter** (lex+parse+eval) | 0.25s | **0.19s** | – |

#### CLBG Benchmarks

| Benchmark | Rockit | Go |
|-----------|--------|-----|
| **Binary trees** (depth 21) | **5.41s** | 10.52s |
| **Fannkuch** (n=12) | 25.03s | **24.79s** |
| **N-body** (50M steps) | 2.63s | **2.42s** |
| **Spectral norm** (n=5500) | 1.15s | **1.14s** |

Rockit beats Go on 7 of 11 benchmarks. Rockit outperforms Node.js 3-15x across all measured benchmarks.

Run the full suite: `bash RockitCompiler/Benchmarks/run_benchmarks.sh`

---

## Project Structure

```
moon/
├── RockitCompiler/
│   ├── Sources/RockitKit/       # Core compiler library (37+ files)
│   ├── Sources/RockitCLI/       # CLI entry point
│   ├── Tests/                   # 539+ tests
│   ├── Runtime/                 # C runtime (ARC, actors, coroutines)
│   ├── Stage1/                  # Self-hosting compiler in Rockit
│   └── Examples/                # Example .rok files
├── ide/
│   ├── shared/                  # Canonical syntax definition + generator
│   ├── vscode/                  # VS Code extension
│   ├── vim/                     # Vim/Neovim plugin
│   └── intellij-rockit/         # JetBrains IDE plugin
├── .github/workflows/           # CI + release automation
└── CLAUDE.md                    # Compiler specification
```

---

## Building from Source

### Prerequisites

| Prerequisite | Version | macOS | Linux | Windows |
|---|---|---|---|---|
| **Swift** | 5.9+ | Xcode or [swift.org](https://swift.org/download) | [swift.org](https://swift.org/download) | [swift.org](https://swift.org/download) |
| **Clang/LLVM** | 14+ | `xcode-select --install` | `apt install clang` | [releases.llvm.org](https://releases.llvm.org) |
| **Git** | any | Included with Xcode | `apt install git` | [git-scm.com](https://git-scm.com) |

### Build

```bash
cd RockitCompiler

# Debug
make build

# Release
make release

# Run tests
make test
```

### Install

```bash
# macOS/Linux (installs to /usr/local)
sudo make install

# Custom prefix
make install PREFIX=$HOME/.local

# Verify
rockit version
rockit run Examples/hello.rok
```

---

## CLI Commands

```
rockit run <file>            Execute a .rok or .rokb file
rockit build <file.rok>      Compile to bytecode (.rokb)
rockit build-native <file>   Compile to native executable via LLVM
rockit run-native <file>     Compile to native and execute
rockit emit-llvm <file>      Emit LLVM IR (.ll) for inspection
rockit launch                Start interactive REPL
rockit init [name]           Create a new Rockit project
rockit test [file]           Run tests
rockit update                Update rockit to the latest version
rockit version               Print version
```

---

## Platforms

| Platform | Build | Run bytecode | Native compile |
|----------|-------|-------------|----------------|
| **macOS** (arm64, x86_64) | Yes | Yes | Yes |
| **Linux** (x86_64, arm64) | Yes | Yes | Yes |
| **Windows** (x86_64) | Yes | Yes | Yes |
| **Docker** | Yes | Yes | Yes |

---

## License

Apache 2.0. Copyright 2026 Dark Matter Tech.
