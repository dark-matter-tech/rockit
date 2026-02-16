# Rockit

A statically-typed, compiled, memory-safe programming language designed to replace JavaScript, HTML, CSS, and the DOM as the foundational technology of the web platform.

Built by [Dark Matter Tech](https://github.com/Dark-Matter).

---

## Status

The compiler is **self-hosting** — Rockit compiles itself. All compiler phases are complete and 521+ tests pass across the full pipeline.

| Component | Status |
|-----------|--------|
| Lexer | Complete |
| Parser | Complete |
| Type Checker | Complete |
| MIR Lowering | Complete |
| Optimizer | Complete |
| Codegen (bytecode + native) | Complete |
| Runtime (ARC, actors, coroutines) | Complete |
| Self-hosting bootstrap | Complete |
| IDE plugin (JetBrains) | Available |

---

## Quick Start

### Install

**macOS / Linux:**
```bash
git clone https://github.com/Dark-Matter/moon.git
cd moon/RockitCompiler
make release && sudo make install
```

**Windows:**
```powershell
git clone https://github.com/Dark-Matter/moon.git
cd moon\RockitCompiler
swift build -c release
copy .build\release\rockit.exe %LOCALAPPDATA%\Rockit\bin\
```

See [INSTALL.md](INSTALL.md) for full installation instructions, Docker, and IDE setup.

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

## IDE Support

### JetBrains (IntelliJ IDEA, WebStorm, CLion, etc.)

The **Rockit Language Support** plugin provides:

- Syntax highlighting with distinct colors for keywords, types, strings, annotations
- Rockit-specific keyword highlighting (`view`, `actor`, `suspend`, `async`)
- Code folding for functions, classes, comments, and import groups
- Brace matching, comment toggling, auto-close quotes
- Xcode/Swift-inspired color palette (dark and light themes)
- Configurable via Settings > Editor > Color Scheme > Rockit

**Install:** Settings > Plugins > gear icon > Install Plugin from Disk > select `intellij-rockit-0.1.0.zip`

Build from source:
```bash
cd ide/intellij-rockit
./gradlew buildPlugin
# Output: build/distributions/intellij-rockit-0.1.0.zip
```

---

## Project Structure

```
moon/
├── RockitCompiler/
│   ├── Sources/RockitKit/       # Core compiler library (34 files)
│   ├── Sources/RockitCLI/       # CLI entry point
│   ├── Tests/                   # 521+ tests
│   ├── Runtime/                 # C runtime (ARC, actors, coroutines)
│   ├── Stage1/                  # Self-hosting compiler in Rockit
│   └── Examples/                # Example .rok files
├── ide/
│   └── intellij-rockit/         # JetBrains IDE plugin
├── INSTALL.md                   # Installation guide
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
rockit --version
rockit run Examples/hello.rok
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
