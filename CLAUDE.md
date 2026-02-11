# CLAUDE.md — Moon Compiler (moonc)

## Project

You are building `moonc`, the compiler for the Moon programming language. Moon is a statically-typed, compiled, memory-safe language designed to replace JavaScript, HTML, CSS, and the DOM as the foundational technology of the web platform. Developed by Dark Matter Tech under codename Mars.

Moon is NOT a wrapper around another language. It is its own language with its own compiler, its own runtime, its own intermediate representation (MIR), and its own package manager (Aurora). The goal is zero dependency on any external language ecosystem.

## Bootstrap Strategy

The compiler follows a standard self-hosting bootstrap:

- **Stage 0 (current):** `moonc` written in Swift. Temporary. Its only purpose is to compile enough Moon to reach Stage 1.
- **Stage 1:** `moonc` rewritten in Moon. Compiled by the Stage 0 Swift compiler.
- **Stage 2:** Stage 1 compiles its own source code. The Swift bootstrap is deleted. Moon compiles Moon.

From Stage 2 onward, each new version of `moonc` is compiled by the previous version. Self-hosted. No external dependencies.

## Language Summary

Moon's syntax is Kotlin-inspired with these Moon-specific additions:

- `view` — declarative UI components (replaces HTML/DOM)
- `actor` — thread-safe concurrent objects
- `navigation` / `route` — declarative app navigation
- `theme` / `style` — type-safe styling (replaces CSS)
- `suspend` / `async` / `await` / `concurrent` — structured concurrency
- `weak` / `unowned` — ARC memory management annotations
- `@Capability` — platform capability declarations

Key language properties:
- Null safety enforced at compile time (`String` vs `String?`, `?.`, `?:`, `!!`)
- Sealed classes with exhaustive `when` matching
- Data classes with destructuring
- Generics with variance (`out`, `in`)
- String interpolation (`"Hello, ${name}"` and `"Hello, $name"`)
- ARC memory model with compile-time cycle analysis
- No GC — deterministic deallocation

## Compiler Pipeline

```
.moon source → Lexer → Tokens → Parser → AST → Type Checker → Typed AST → MIR Lowering → MIR → Optimizer → Optimized MIR → Codegen → Bytecode
```

### Phase 1: Lexer ✅ COMPLETE
- Single-pass UTF-8 scanner
- 130+ token types covering full Moon grammar
- Handles: all keywords, identifiers, int/float/hex/binary literals, string literals with interpolation and escape sequences, all operators, nestable block comments, significant newlines
- Source location tracking for error reporting
- 25+ unit tests

### Phase 2: Parser 🔨 NEXT
- Recursive descent parser
- Produces AST from token stream
- Must handle: declarations (fun, val, var, class, data class, sealed class, enum, interface, object, actor, view, navigation, theme), expressions (binary, unary, call, member access, lambda, when, if, string interpolation), statements (return, break, continue, for, while, assignment), type annotations (nullable, generics, function types), annotations (@Capability, @State, @NoCycle)
- Error recovery — don't stop at first error, synchronize and keep parsing

### Phase 3: Type Checker
- Full type inference
- Null safety enforcement
- Exhaustive `when` checking for sealed classes and enums
- Generic type resolution with variance
- Capability validation

### Phase 4: MIR Lowering
- AST → Moon Intermediate Representation
- MIR is the stable contract layer
- Platform-agnostic

### Phase 5: Optimizer
- Dead code elimination
- Inlining
- Constant folding
- Tree shaking

### Phase 6: Codegen
- MIR → bytecode for Moon runtime

### Phase 7: Runtime
- ARC with cycle detector
- Coroutine scheduler for structured concurrency
- Actor message dispatch
- Platform capability bridge

## Project Structure

```
MoonCompiler/
├── Package.swift                    # Swift Package Manager manifest
├── CLAUDE.md                        # This file
├── README.md                        # Compiler README
├── Sources/
│   ├── MoonKit/                     # Core compiler library
│   │   ├── Token.swift              # Token types and source locations
│   │   ├── Lexer.swift              # Tokenizer
│   │   ├── Diagnostic.swift         # Error/warning reporting engine
│   │   ├── AST.swift                # (Phase 2) AST node definitions
│   │   └── Parser.swift             # (Phase 2) Recursive descent parser
│   └── MoonCLI/                     # CLI entry point
│       └── main.swift               # moonc command
├── Tests/
│   └── MoonKitTests/
│       └── LexerTests.swift         # Lexer test suite
└── Examples/
    └── hello.moon                   # Test source file
```

MoonKit is a standalone library so it can be imported by other tools (editor plugins, LSP server, Aurora) without the CLI.

## Coding Standards

- One type per file. No multi-type files.
- `public` API for anything MoonKit consumers need. `internal` or `private` for everything else.
- Every compiler phase gets its own file(s) in MoonKit.
- AST nodes should be enums with associated values where possible (Swift's algebraic types map well to compiler IR).
- All diagnostics go through `DiagnosticEngine` — never `print()` errors directly.
- Tests for every phase. The compiler must be testable at each boundary: source→tokens, tokens→AST, AST→typed AST, etc.
- Use descriptive names. This is a compiler — clarity matters more than brevity.

## Grammar Reference (EBNF)

This is the abbreviated formal grammar from the Moon spec. The parser must handle all of this.

```
program       = { declaration } ;
declaration   = funDecl | viewDecl | classDecl | enumDecl
              | interfaceDecl | actorDecl | typeAlias ;

funDecl       = ["suspend"] "fun" id [typeParams]
                "(" [params] ")" [":" type] block ;
viewDecl      = "view" id "(" [params] ")" viewBlock ;
classDecl     = ["data"|"sealed"] "class" id [typeParams]
                ["(" [params] ")"] [":" typeList] classBlock ;
actorDecl     = "actor" id classBlock ;
enumDecl      = "enum" "class" id enumBlock ;
navDecl       = "navigation" id navBlock ;

type          = id [typeArgs] ["?"] | funcType | tupleType ;
funcType      = "(" [typeList] ")" "->" type ;

statement     = valDecl | varDecl | assignment | expression
              | ifExpr | whenExpr | forLoop | returnStmt ;
valDecl       = "val" id [":" type] "=" expression ;
varDecl       = ["weak"|"unowned"] "var" id [":" type] "=" expr ;
whenExpr      = "when" "(" expr ")" "{" { whenEntry } "}" ;
lambda        = "{" [params "->"] statements "}" ;
```

## Key Files to Reference

- `Sources/MoonKit/Token.swift` — All token definitions. Start here to understand the lexical grammar.
- `Sources/MoonKit/Lexer.swift` — The lexer implementation. Working and tested.
- `Examples/hello.moon` — A comprehensive test file that exercises most language features.
- `Tests/MoonKitTests/LexerTests.swift` — Shows expected tokenization for various constructs.

## What's Next

Build the parser. Start with:
1. Define AST node types in `AST.swift`
2. Implement recursive descent parser in `Parser.swift`
3. Start with the simplest constructs: `val`/`var` declarations, function declarations, basic expressions
4. Add `moonc parse Examples/hello.moon --dump-ast` command to the CLI
5. Build up to classes, sealed classes, views, actors, navigation, when expressions
6. Write tests for each construct as you go

## Owner

Micah — Dark Matter Tech founder. Private pilot, Part 107 sUAS operator, iOS developer. Building Moon as part of the Orion browser platform.
