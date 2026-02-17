# CLAUDE.md — Rockit Compiler (command)

## Project

You are building `command`, the compiler for the Rockit programming language. Rockit is a statically-typed, compiled, memory-safe language designed to replace JavaScript, HTML, CSS, and the DOM as the foundational technology of the web platform. Developed by Dark Matter Tech under codename Mars.

Rockit is NOT a wrapper around another language. It is its own language with its own compiler, its own runtime, its own intermediate representation (MIR), and its own package manager (Fuel). The goal is zero dependency on any external language ecosystem.

## Bootstrap Strategy

The compiler follows a standard self-hosting bootstrap:

- **Stage 0:** `command` written in Swift. Its purpose is to compile Stage 1.
- **Stage 1:** `command` rewritten in Rockit. Compiled by the Stage 0 Swift compiler.
- **Stage 2:** Stage 1 compiles its own source code. Self-hosting verified — Stage 2 == Stage 3 bytecode.

From Stage 2 onward, each new version of `command` is compiled by the previous version. Self-hosted.

**Current status:** Self-hosting achieved. All compiler phases complete. 539 unit tests passing.

## Ecosystem

| Tool | Name |
|------|------|
| Language | Rockit (.rok / .rokb) |
| CLI / Build Tool | Command |
| Package Manager | Fuel |
| Test Framework | Probe |
| Registry | Silo |
| REPL | Launch |
| Browser | Nova |

## Language Summary

Rockit's syntax is Kotlin-inspired with these Rockit-specific additions:

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
.rok source → Lexer → Tokens → Parser → AST → Type Checker → Typed AST → MIR Lowering → MIR → Optimizer → Optimized MIR → Codegen → Bytecode
```

All phases complete in both Stage 0 (Swift) and Stage 1 (Rockit):

### Phase 1: Lexer ✅
130+ token types, string interpolation, nestable comments, significant newlines.

### Phase 2: Parser ✅
Recursive descent. All declarations (fun, class, data class, sealed class, enum, interface, object, actor, view, navigation, theme, package), expressions (binary, unary, call, member access, lambda, when, if, string interpolation, await), statements, type annotations, annotations.

### Phase 3: Type Checker ✅
Type inference, null safety, exhaustive `when`, generics with variance, suspend/await validation, actor isolation.

### Phase 4: MIR Lowering ✅
AST → MIR intermediate representation.

### Phase 5: Structured Concurrency ✅
- **Native codegen**: CPS coroutine transform (suspend functions → state machines), concurrent blocks with event loop + join counter
- **Bytecode VM**: Cooperative scheduler, coroutine suspend/resume, concurrent block interleaving, actor message dispatch via mailbox, error propagation, cancellation
- **Runtime**: Frame alloc/free, task scheduling, event loop (C runtime for native; Scheduler/Coroutine/ActorRuntime Swift classes for VM)

### Phase 6: Codegen ✅
MIR → bytecode (Stage 0 CodeGen.swift) and direct AST → bytecode (Stage 1 codegen.rok). Native codegen via LLVM IR (Stage 0 LLVMCodeGen.swift, Stage 1 llvmgen.rok).

### Phase 7: Runtime ✅
ARC with cycle detector, coroutine scheduler, actor message dispatch, platform capability bridge.

## Project Structure

```
RockitCompiler/
├── Package.swift                    # Swift Package Manager manifest
├── CLAUDE.md                        # This file
├── README.md                        # Compiler README
├── Sources/
│   ├── RockitKit/                   # Core compiler library
│   │   ├── Token.swift              # Token types and source locations
│   │   ├── Lexer.swift              # Tokenizer
│   │   ├── Diagnostic.swift         # Error/warning reporting engine
│   │   ├── AST.swift                # AST node definitions
│   │   ├── Parser.swift             # Recursive descent parser
│   │   ├── TypeChecker.swift        # Two-pass type checker
│   │   ├── MIRLowering.swift        # AST → MIR
│   │   ├── MIROptimizer.swift       # Optimization passes
│   │   ├── CodeGen.swift            # MIR → bytecode
│   │   ├── VM.swift                 # Bytecode interpreter
│   │   ├── Heap.swift               # Object heap (RockitObject)
│   │   └── ...                      # 37+ files total
│   └── RockitCLI/                   # CLI entry point
│       └── main.swift               # command tool
├── Tests/
│   └── RockitKitTests/              # 14+ test files, 539 tests
├── Stage1/                          # Self-hosting compiler in Rockit
│   ├── lexer.rok                    # Stage 1 lexer
│   ├── parser.rok                   # Stage 1 parser
│   ├── typechecker.rok              # Stage 1 type checker
│   ├── optimizer.rok                # Stage 1 optimizer
│   ├── llvmgen.rok                  # Stage 1 LLVM native codegen (CPS coroutine transform)
│   ├── codegen.rok                  # Stage 1 bytecode codegen + main()
│   ├── command.rok                  # Concatenated compiler (auto-gen via build.sh)
│   ├── command                      # Stage 1 native binary
│   └── stdlib/rockit/               # Standard library modules
├── Runtime/
│   └── rockit_runtime.c             # C runtime (ARC, task scheduler, event loop, actor wrappers)
└── Examples/
    └── test_f*.rok                  # 35+ feature test files
```

RockitKit is a standalone library so it can be imported by other tools (editor plugins, LSP server, Fuel) without the CLI.

## Coding Standards

- One type per file. No multi-type files.
- `public` API for anything RockitKit consumers need. `internal` or `private` for everything else.
- Every compiler phase gets its own file(s) in RockitKit.
- AST nodes should be enums with associated values where possible (Swift's algebraic types map well to compiler IR).
- All diagnostics go through `DiagnosticEngine` — never `print()` errors directly.
- Tests for every phase. The compiler must be testable at each boundary: source→tokens, tokens→AST, AST→typed AST, etc.
- Use descriptive names. This is a compiler — clarity matters more than brevity.

## Grammar Reference (EBNF)

This is the abbreviated formal grammar from the Rockit spec. The parser must handle all of this.

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

- `Sources/RockitKit/Token.swift` — All token definitions. Start here to understand the lexical grammar.
- `Sources/RockitKit/Lexer.swift` — The lexer implementation. Working and tested.
- `Examples/hello.rok` — A comprehensive test file that exercises most language features.
- `Tests/RockitKitTests/LexerTests.swift` — Shows expected tokenization for various constructs.

## Owner

Micah — Dark Matter Tech founder. Private pilot, Part 107 sUAS operator, iOS developer. Building Rockit as part of the Orion browser platform.
