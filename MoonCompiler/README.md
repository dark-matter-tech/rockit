# command

The Rockit language compiler. Written from scratch in Swift (Stage 0), self-hosting in Rockit (Stage 1+).

> **Status:** All phases complete. Self-hosting compiler achieves bit-identical fixed point.

For the full language specification and design rationale, see the [Rockit Language README](../README.md).

---

## Build

```bash
swift build
```

Binary lands at `.build/debug/command`.

## Run

```bash
# Tokenize a .rok file and dump the token stream
swift run command lex Examples/hello.rok --dump-tokens

# Parse and dump AST
swift run command parse Examples/hello.rok --dump-ast

# Type-check
swift run command check Examples/hello.rok

# Compile to bytecode
swift run command build Examples/hello.rok

# Run a .rok or .rokb file
swift run command run Examples/hello.rok

# Start REPL
swift run command repl

# Create a new project
swift run command init myproject

# Run tests
swift run command test

# Version
swift run command version
```

## Test

```bash
swift test
```

479+ test cases covering the full compiler pipeline — lexer, parser, type checker, MIR, optimizer, codegen, VM, collections, strings, break/continue, ARC, coroutines, actors, file I/O, and bytecode serialization.

---

## Architecture

```
command
├── RockitKit          # Core compiler library (importable)
│   ├── Token          # 130+ token types — full Rockit grammar coverage
│   ├── Lexer          # Single-pass UTF-8 scanner
│   ├── Parser         # Recursive descent parser
│   ├── TypeChecker    # Two-pass type checker
│   ├── MIRLowering    # AST → MIR
│   ├── MIROptimizer   # Optimization passes
│   ├── CodeGen        # MIR → bytecode
│   ├── VM             # Bytecode interpreter
│   ├── Diagnostic     # Error/warning reporting with source locations
│   └── ...            # 34 files total
└── RockitCLI          # CLI frontend (command binary)
```

RockitKit is a standalone library so it can be embedded in other tools — editor plugins, LSP server, Fuel package manager — without dragging in the CLI.

## Compiler Pipeline

| Phase | Input | Output | Status |
|-------|-------|--------|--------|
| **Lexer** | `.rok` source | Token stream | ✅ |
| **Parser** | Token stream | AST | ✅ |
| **Type Checker** | AST | Typed AST | ✅ |
| **MIR Lowering** | Typed AST | Rockit IR | ✅ |
| **Optimizer** | MIR | Optimized MIR | ✅ |
| **Codegen** | Optimized MIR | Bytecode | ✅ |
| **Runtime** | Bytecode | Execution | ✅ |

---

## Token Coverage

The lexer handles the complete Rockit token set as defined in the language spec.

**Rockit-specific keywords**
`view` · `actor` · `navigation` · `route` · `theme` · `style` · `suspend` · `async` · `await` · `concurrent` · `weak` · `unowned`

**Kotlin-inherited keywords**
`fun` · `val` · `var` · `class` · `data` · `sealed` · `enum` · `interface` · `object` · `when` · `is` · `as` · `in` · `if` · `else` · `for` · `while` · `return` · `break` · `continue` · `override` · `private` · `public` · `internal` · `protected` · `companion` · `typealias` · `import` · `package` · `try` · `catch` · `finally` · `throw` · `this` · `super` · `where` · `out` · `open` · `abstract` · `constructor` · `init` · `do`

**Literals**
- Integers: decimal, `0x` hex, `0b` binary, underscore separators (`1_000_000`)
- Floats: decimal with optional exponent (`3.14`, `1.0e10`, `2.5E-3`)
- Strings: escape sequences (`\n`, `\t`, `\r`, `\\`, `\"`, `\0`, `\u{XXXX}`), `$var` and `${expr}` interpolation
- Booleans: `true`, `false`
- Null: `null`

**Operators**
- Arithmetic: `+` `-` `*` `/` `%`
- Comparison: `==` `!=` `<` `<=` `>` `>=`
- Assignment: `=` `+=` `-=` `*=` `/=` `%=`
- Logical: `&&` `||` `!`
- Null safety: `?.` `?:` `!!` `?`
- Range: `..` `..<`
- Arrow: `->` `=>`
- Member: `.` `::` `.*`

**Comments**
- Single-line: `// ...`
- Multi-line: `/* ... */` (nestable)

---

## Requirements

- Swift 5.9+
- macOS 14+

## License

Proprietary. Copyright © 2026 Dark Matter Tech. All rights reserved.
