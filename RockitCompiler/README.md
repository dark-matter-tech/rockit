# Rockit Compiler

The Rockit language compiler. Self-hosting — Rockit compiles itself.

> **Status:** All phases complete. 521+ tests passing. Self-hosting bootstrap verified (Stage 2 == Stage 3).

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

# Parse and dump AST
rockit parse Examples/hello.rok --dump-ast

# Type-check
rockit check Examples/hello.rok

# Compile to bytecode
rockit build Examples/hello.rok

# Start REPL
rockit repl

# Create a new project
rockit init myproject

# Run tests
rockit test

# Version
rockit --version
```

## Test

```bash
swift test
```

521+ test cases covering the full compiler pipeline: lexer, parser, type checker, MIR, optimizer, codegen, VM, collections, strings, ARC, coroutines, actors, file I/O, and bytecode serialization.

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
│   │   └── ...             # 34 files total
│   └── RockitCLI/          # CLI entry point
├── Tests/                  # 521+ tests
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
