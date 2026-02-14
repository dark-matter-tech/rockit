# moonc

The Moon language compiler. Written from scratch in Swift.

> **Status:** Phase 1 — Lexer complete. Parser next.

For the full language specification and design rationale, see the [Moon Language README](../README.md).

---

## Build

```bash
swift build
```

Binary lands at `.build/debug/moonc`.

## Run

```bash
# Tokenize a .moon file and dump the token stream
swift run moonc lex Examples/hello.moon --dump-tokens

# Just tokenize (summary only)
swift run moonc lex Examples/hello.moon

# Version
swift run moonc version
```

## Test

```bash
swift test
```

25+ test cases covering the full token set — keywords, literals, operators, comments, string interpolation, null safety operators, generics, annotations, error recovery, and source location tracking.

---

## Architecture

```
moonc
├── MoonKit          # Core compiler library (importable)
│   ├── Token        # 130+ token types — full Moon grammar coverage
│   ├── Lexer        # Single-pass UTF-8 scanner
│   ├── Diagnostic   # Error/warning reporting with source locations
│   ├── AST          # (Phase 2)
│   └── Parser       # (Phase 2)
└── MoonCLI          # CLI frontend (moonc binary)
```

MoonKit is a standalone library so it can be embedded in other tools — editor plugins, LSP server, Aurora package manager — without dragging in the CLI.

## Compiler Pipeline

| Phase | Input | Output | Status |
|-------|-------|--------|--------|
| **Lexer** | `.moon` source | Token stream | ✅ |
| **Parser** | Token stream | AST | 🔨 Next |
| **Type Checker** | AST | Typed AST | ⬜ |
| **MIR Lowering** | Typed AST | Moon IR | ⬜ |
| **Optimizer** | MIR | Optimized MIR | ⬜ |
| **Codegen** | Optimized MIR | Bytecode | ⬜ |
| **Runtime** | Bytecode | Execution | ⬜ |

---

## Token Coverage

The lexer handles the complete Moon token set as defined in the language spec.

**Moon-specific keywords**
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

## Example Output

```bash
$ moonc lex Examples/hello.moon --dump-tokens
```

```
  1:1      package                        kwPackage
  1:9      com                            identifier("com")
  1:12     .                              '.'
  1:13     darkmatter                     identifier("darkmatter")
  1:23     .                              '.'
  1:24     hello                          identifier("hello")
  3:1      import                         kwImport
  ...
  8:1      val                            kwVal
  8:5      appName                        identifier("appName")
  8:12     :                              ':'
  8:14     String                         identifier("String")
  8:21     =                              '='
  8:23     "Moon Demo"                    string("Moon Demo")
  ...
  EOF

Examples/hello.moon: 312 tokens
OK
```

---

## Requirements

- Swift 5.9+
- macOS 14+

## License

Proprietary. Copyright © 2026 Dark Matter Tech. All rights reserved.
