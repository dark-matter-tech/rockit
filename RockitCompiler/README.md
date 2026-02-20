# Rockit Compiler

The Rockit language compiler. Self-hosting — Rockit compiles itself.

> **Status:** All phases complete. 542 tests passing. Self-hosting bootstrap verified (Stage 2 == Stage 3). Runtime rewritten in Rockit.

---

## Install

**macOS / Linux (one-liner):**
```bash
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.ps1 | iex
```

The installer downloads a prebuilt binary if available, or builds from source as a fallback.

**Update:**
```bash
rockit update
```

---

## Build

```bash
# Debug build
swift build

# Release build
swift build -c release

# Using Make
make build     # debug
make release   # release
```

## Run

```bash
# Run a .rok file (bytecode)
rockit run Examples/hello.rok

# Compile to native binary
rockit build-native Examples/hello.rok

# Compile to native and run
rockit run-native Examples/hello.rok

# Compile without the standard runtime (freestanding mode)
rockit build-native Examples/test_freestanding.rok --no-runtime

# Parse and dump AST
rockit parse Examples/hello.rok --dump-ast

# Type-check
rockit check Examples/hello.rok

# Compile to bytecode
rockit build Examples/hello.rok

# Emit LLVM IR
rockit emit-llvm Examples/hello.rok

# Start REPL
rockit launch

# Create a new project
rockit init myproject

# Run tests
rockit test

# Update to latest version
rockit update

# Version
rockit version
```

## Test

```bash
swift test
```

542 test cases covering the full compiler pipeline: lexer, parser, type checker, MIR, optimizer, codegen, VM, collections, strings, ARC, coroutines, actors, structured concurrency, file I/O, and bytecode serialization.

---

## Performance

The native compiler includes several optimizations that make Rockit competitive with established languages:

**Immortal String Literals** — String constants are never heap-allocated or reference-counted. They live in the binary's read-only data segment and bypass ARC entirely.

**ARC Write Barriers** — The compiler tracks `ptrFieldBits` per object so `rockit_release` only scans fields that actually contain heap pointers, eliminating unnecessary reference counting on primitive fields.

**Inline ARC** — String release is emitted as inline LLVM IR (refcount decrement + conditional free) instead of a function call, saving overhead on every string deallocation.

**Value Types** — `data class` declarations with only primitive fields (Int, Float, Bool, etc.) use inline GEP field access instead of runtime function calls, and skip ARC retain/release for field values.

**Escape Analysis & Stack Promotion** — Value-type `data class` instances that don't escape the current function are stack-allocated via LLVM `alloca` instead of heap-allocated via `malloc`. Interprocedural analysis proves parameters don't escape through read-only callees, enabling stack promotion even when objects are passed to functions.

**Inline List Access** — `listGet`, `listSet`, and `listSize` are compiled to direct GEP memory operations with inline bounds checks instead of runtime function calls, eliminating call overhead while maintaining memory safety. Bounds checks add only 1-5% overhead — LLVM hot/cold splitting moves panic paths out of loop bodies.

**Inline Integer Comparison** — `==` and `!=` on known integer operands compile to a single `icmp` instruction instead of calling the polymorphic `rockit_string_eq` runtime function.

**TBAA Alias Analysis** — List struct field loads (size, data pointer) are annotated with LLVM TBAA metadata, proving they can't alias element stores. This lets LLVM hoist struct field loads out of inner loops, eliminating redundant memory accesses.

**Inline `toInt()`** — When the argument is a known integer, `toInt()` is compiled to a direct copy instead of a runtime function call. Combined with TBAA, this lets LLVM fully optimize tight loops with no function call barriers.

**Bulk List Initialization** — `listCreateFilled(size, value)` allocates and fills a list in a single `malloc` + `memset`, replacing N individual `listAppend` calls that each involve function call overhead, capacity checks, and potential reallocations.

**Multi-String Concat Flattening** — Chains of string `+` operations (e.g. `"(" + left + " " + op + " " + right + ")"`) are flattened at compile time into a single `concat_n` call that measures total length once, allocates once, and copies all parts in. A 7-part concat goes from 6 intermediate allocations to 1.

**Internal Linkage** — Non-`main` functions are emitted with `internal` linkage, giving LLVM full freedom to inline and optimize across function boundaries.

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

Run the full suite: `bash Benchmarks/run_benchmarks.sh`

---

## Architecture

```
RockitCompiler/
├── Sources/
│   ├── RockitKit/          # Core compiler library (importable)
│   │   ├── Token.swift     # 130+ token types
│   │   ├── Lexer.swift     # Single-pass UTF-8 scanner
│   │   ├── Parser.swift    # Recursive descent parser
│   │   ├── TypeChecker.swift
│   │   ├── MIRLowering.swift
│   │   ├── MIROptimizer.swift
│   │   ├── CodeGen.swift   # MIR → bytecode
│   │   ├── LLVMCodeGen.swift  # MIR → LLVM IR → native
│   │   ├── VM.swift        # Bytecode interpreter
│   │   ├── Scheduler.swift # Coroutine scheduler
│   │   ├── Coroutine.swift # Coroutine state machine
│   │   └── ...             # 37+ files total
│   └── RockitCLI/          # CLI entry point
├── Tests/                  # 542 tests
├── Runtime/
│   ├── rockit_runtime.c    # C runtime (ARC, actors, coroutines)
│   └── rockit/             # Modular Rockit runtime (freestanding)
│       ├── memory.rok      # malloc/free, ARC retain/release
│       ├── string.rok      # String struct, new, eq, neq, concat, length
│       ├── string_ops.rok  # charAt, indexOf, substring, split, trim
│       ├── object.rok      # Object alloc, field access, type checking
│       ├── list.rok        # List create/append/get/set/remove/size
│       ├── map.rok         # Map create/put/get/keys/remove
│       ├── io.rok          # println, print (int, float, string, any)
│       ├── exception.rok   # setjmp/longjmp exception stack
│       ├── file.rok        # fileRead, fileWrite, fileExists, fileDelete
│       ├── process.rok     # processArgs, getEnv, platformOS, systemExec
│       ├── math.rok        # sqrt, sin, cos, tan, floor, ceil, round, etc.
│       ├── concurrency.rok # Task scheduler, frame alloc/free, event loop
│       └── build.sh        # Concatenates and compiles all modules
├── Stage1/                 # Self-hosting compiler in Rockit (~12K lines)
│   ├── lexer.rok           # Stage 1 lexer
│   ├── parser.rok          # Stage 1 parser
│   ├── typechecker.rok     # Stage 1 type checker
│   ├── optimizer.rok       # Stage 1 optimizer
│   ├── codegen.rok         # Stage 1 bytecode codegen
│   ├── llvmgen.rok         # Stage 1 LLVM native codegen
│   ├── command.rok         # Concatenated compiler source
│   ├── command             # Stage 1 native binary
│   └── stdlib/             # Standard library modules
└── Examples/               # 48 example/test .rok files
```

RockitKit is a standalone library so it can be imported by other tools (editor plugins, LSP server, Fuel) without the CLI.

### Freestanding Mode (`--no-runtime`)

The `--no-runtime` flag compiles Rockit programs without linking the standard runtime. This enables low-level systems programming with direct memory control:

```kotlin
extern fun malloc(size: Int): Ptr<Int>
extern fun free(ptr: Ptr<Int>): Unit
extern fun puts(s: Int): Int

fun main(): Unit {
    unsafe {
        val buf = alloc(64)
        storeByte(buf, 0, 72)  // 'H'
        storeByte(buf, 1, 105) // 'i'
        storeByte(buf, 2, 0)   // null terminator
        puts(buf)
        free(bitcast(buf))
    }
}
```

Stage 1 features available in freestanding mode: `Ptr<T>`, `alloc`/`free`, `bitcast`, `cstr`, `unsafe` blocks, `loadByte`/`storeByte`, `extern` C functions, `@CRepr` structs, global variables.

## Language Server (LSP)

Rockit ships a built-in language server. Start it with:

```bash
rockit lsp
```

Works with any LSP-compatible editor. IDE configs are provided in `ide/` for JetBrains, VS Code, Vim/Neovim, Sublime Text, Emacs, Helix, and Zed.

### Capabilities

| Feature | LSP Method | Status |
|---------|-----------|--------|
| Diagnostics | `textDocument/publishDiagnostics` | Done |
| Hover | `textDocument/hover` | Done |
| Completion | `textDocument/completion` | Done |
| Go to Definition | `textDocument/definition` | Done |
| Go to Type Definition | `textDocument/typeDefinition` | Done |
| Go to Implementation | `textDocument/implementation` | Done |
| Find References | `textDocument/references` | Done |
| Document Symbols | `textDocument/documentSymbol` | Done |
| Workspace Symbols | `workspace/symbol` | Done |
| Signature Help | `textDocument/signatureHelp` | Done |
| Rename Symbol | `textDocument/rename` | Done |
| Call Hierarchy | `callHierarchy/incomingCalls`, `outgoingCalls` | Done |
| Semantic Tokens | `textDocument/semanticTokens/full` | Done |
| Document Formatting | `textDocument/formatting` | Done |
| On Type Formatting | `textDocument/onTypeFormatting` | Done |
| Inlay Hints | `textDocument/inlayHint` | Done |
| Code Actions | `textDocument/codeAction` | Done |
| Document Links | `textDocument/documentLink` | Done |
| Folding Ranges | `textDocument/foldingRange` | Done |
| Document Highlight | `textDocument/documentHighlight` | Done |
| Selection Range | `textDocument/selectionRange` | Done |
| Type Hierarchy | `typeHierarchy/supertypes`, `subtypes` | Done |
| Range Formatting | `textDocument/rangeFormatting` | Done |
| Incremental Sync | `textDocument/didChange` (mode 2) | Done |

### Editor Setup

**JetBrains (IntelliJ / Fleet):** Install the plugin from `ide/intellij-rockit/build/distributions/intellij-rockit-*.zip` via Settings > Plugins > Install Plugin from Disk.

**VS Code:** Open `ide/vscode/` and run `npm install && npm run compile`. Install via Extensions > Install from VSIX or symlink into `~/.vscode/extensions/`.

**Neovim (nvim-lspconfig):**
```lua
require('lspconfig.configs').rockit = {
  default_config = {
    cmd = { 'rockit', 'lsp' },
    filetypes = { 'rockit' },
    root_dir = require('lspconfig.util').root_pattern('fuel.toml', '.git'),
  },
}
require('lspconfig').rockit.setup({})
```

**Sublime Text:** Copy `ide/sublime/LSP-rockit.sublime-settings` into your Packages/LSP/ directory.

**Emacs:** See `ide/emacs/rockit-lsp.el` for lsp-mode and eglot configurations.

**Helix:** Copy `ide/helix/languages.toml` into your Helix config directory.

**Zed:** Copy `ide/zed/settings.json` into your Zed settings.

---

## Compiler Pipeline

| Phase | Input | Output | Status |
|-------|-------|--------|--------|
| **Lexer** | `.rok` source | Token stream | Complete |
| **Parser** | Token stream | AST | Complete |
| **Type Checker** | AST | Typed AST | Complete |
| **MIR Lowering** | Typed AST | Rockit IR | Complete |
| **Optimizer** | MIR | Optimized MIR | Complete |
| **Codegen** | Optimized MIR | Bytecode / LLVM IR | Complete |
| **Runtime** | Bytecode | Execution | Complete |

---

## Platforms

| Platform | Swift build | Bytecode VM | Native compile |
|----------|-------------|-------------|----------------|
| macOS (arm64, x86_64) | Yes | Yes | Yes |
| Linux (x86_64, arm64) | Yes | Yes | Yes |
| Windows (x86_64) | Yes | Yes | Yes |

### Prerequisites

- **Swift 5.9+** — [swift.org/download](https://swift.org/download)
- **Clang/LLVM 14+** — required for native compilation (`rockit build-native`)
  - macOS: `xcode-select --install`
  - Linux: `sudo apt install clang`
  - Windows: [releases.llvm.org](https://releases.llvm.org)

---

## License

Apache 2.0. Copyright 2026 Dark Matter Tech.
