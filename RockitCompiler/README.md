# Rockit Compiler

The Rockit language compiler. Self-hosting — Rockit compiles itself.

> **Status:** All phases complete. 539+ tests passing. Self-hosting bootstrap verified (Stage 2 == Stage 3).

---

## Install

**macOS / Linux (one-liner):**
```bash
curl -fsSL https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/RockitCompiler/install.ps1 | iex
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

539+ test cases covering the full compiler pipeline: lexer, parser, type checker, MIR, optimizer, codegen, VM, collections, strings, ARC, coroutines, actors, structured concurrency, file I/O, and bytecode serialization.

---

## Performance

The native compiler includes several optimizations that make Rockit competitive with established languages:

**Immortal String Literals** — String constants are never heap-allocated or reference-counted. They live in the binary's read-only data segment and bypass ARC entirely.

**ARC Write Barriers** — The compiler tracks `ptrFieldBits` per object so `rockit_release` only scans fields that actually contain heap pointers, eliminating unnecessary reference counting on primitive fields.

**Inline ARC** — String release is emitted as inline LLVM IR (refcount decrement + conditional free) instead of a function call, saving overhead on every string deallocation.

**Value Types** — `data class` declarations with only primitive fields (Int, Float, Bool, etc.) use inline GEP field access instead of runtime function calls, and skip ARC retain/release for field values.

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
| **Fibonacci** (fib 40, recursive) | **0.31s** | 0.34s | 1.05s |
| **Object alloc** (1M data class) | 0.04s | **0.003s** | 0.07s |
| **Prime sieve** (primes to 1M) | **0.004s** | 0.006s | 0.07s |
| **Matrix multiply** (200x200) | **0.010s** | 0.013s | 0.08s |
| **Quicksort** (500K integers) | **0.032s** | 0.035s | 0.18s |
| **Monkey interpreter** (lex+parse+eval) | 0.24s | **0.19s** | – |

#### CLBG Benchmarks

| Benchmark | Rockit | Go |
|-----------|--------|-----|
| **Binary trees** (depth 21) | **5.27s** | 10.41s |
| **Fannkuch** (n=12) | **25.05s** | 25.33s |
| **N-body** (50M steps) | 2.68s | **2.46s** |
| **Spectral norm** (n=5500) | **1.17s** | 1.19s |

Rockit beats Go on 7 of 10 benchmarks. Rockit outperforms Node.js 3-18x across all measured benchmarks.

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
├── Tests/                  # 539+ tests
├── Runtime/                # C runtime (ARC, actors, coroutines)
├── Stage1/                 # Self-hosting compiler in Rockit
│   ├── command.rok         # Concatenated compiler source
│   ├── command             # Stage 1 native binary
│   └── stdlib/             # Standard library modules
└── Examples/
```

RockitKit is a standalone library so it can be imported by other tools (editor plugins, LSP server, Fuel) without the CLI.

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
