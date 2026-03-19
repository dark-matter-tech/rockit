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

**Current status:** Self-hosting achieved. All compiler phases complete. 591 unit tests passing. Runtime rewritten in modular Rockit. DO-178C audit readiness (safety verification, LLVM debug metadata, audit trail).

## Ecosystem

| Tool | Name | Status |
|------|------|--------|
| Language | Rockit (.rok / .rokb) | Shipped |
| CLI / Build Tool | Command | Shipped |
| Package Manager | Fuel | Shipped (bundled with Rockit releases) |
| Standard Library | stdlib (`rockit.*`) | Shipped (bundled with Rockit releases) |
| Test Framework | Probe | Shipped |
| Registry | Silo | Planned |
| REPL | Launch | Shipped |
| Browser | Nova | Planned |
| Rendering Engine | Supernova | Planned |

### Distribution

Rockit releases bundle the compiler, Fuel, stdlib, and prebuilt runtime into a single tarball. Fuel is built from the separate `fuel` repo (`Dark-Matter/fuel`) during the release workflow. The release structure:

```
rockit/
  bin/
    rockit              # Stage 1 compiler
    fuel                # Package manager
  share/rockit/
    rockit_runtime.o    # Prebuilt Rockit runtime
    stdlib/rockit/      # Standard library modules
```

## Nova Browser Architecture

Nova is a dual-engine browser. It runs Rockit web apps natively and supports legacy JavaScript websites for compatibility.

### Dual Engine Design

```
User visits a site → Nova detects content type
       ↓
  Rockit (.rok/.rokb)          HTML/JS (legacy web)
       ↓                            ↓
  Rockit Engine                JS Compatibility Engine
  - Baseline compiler          - JavaScriptCore (macOS/iOS)
    (.rokb → native ARM64/x86) - V8 or Hermes (Windows/Linux)
  - Supernova (GPU rendering)
  - ARC memory management
  - @Capability platform bridge
```

### Rockit Engine (fast path)

- **Execution:** Baseline compiler translates `.rokb` bytecode to native machine code on first load (<100ms), caches result. No interpreter, no VM in the loop.
- **Rendering:** Supernova — GPU-accelerated compositor for `view` trees, GPU compute for `parallel` blocks, full rendering pipeline for 3D apps. Backends: Metal (macOS/iOS), Vulkan (Android/Linux), Direct3D 12 (Windows).
- **Memory:** ARC with configurable budgets per app (heap bytes, object count, coroutine count, instruction budget). No GC overhead.
- **Concurrency:** CPS coroutine model with cooperative scheduling. Actor isolation for thread safety.
- **Optional LLVM tier:** Background recompilation of frequently-used apps with full LLVM optimization. Replaces cached baseline binary.

### JS Compatibility Engine (legacy path)

- **macOS/iOS:** JavaScriptCore (ships with OS, zero additional size)
- **Windows/Linux:** V8 or Hermes (embedded)
- **Detection:** HTML content type → JS engine. Rockit content type → Rockit engine.
- **Purpose:** Every existing website works from day one. Users can switch to Nova immediately.

### Migration Strategy

1. Launch Nova with both engines — full web compatibility from day one
2. Rockit apps get the fast path — native compiled, Supernova rendering, low memory
3. JS sites get the compat path — functional, but no faster than Chrome/Safari
4. Developers migrate to Rockit over time — better performance, simpler stack
5. JS engine becomes vestigial as ecosystem matures

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
MIR → bytecode (Stage 0 CodeGen.swift) and direct AST → bytecode (Stage 1 codegen.rok). Native codegen via LLVM IR (Stage 0 LLVMCodeGen.swift, Stage 1 llvmgen.rok). Supports global variables (OP_LOAD_GLOBAL/OP_STORE_GLOBAL opcodes 83/84).

### Phase 7: Runtime ✅
ARC with cycle detector, coroutine scheduler, actor message dispatch, platform capability bridge.

### Phase 8: Freestanding Mode (`--no-runtime`) ✅
Compiles Rockit programs without the standard runtime. Enables low-level systems programming with `Ptr<T>`, `alloc`/`free`, `bitcast`, `cstr`, `unsafe` blocks, `loadByte`/`storeByte`, `extern` C functions, `@CRepr` structs. The runtime itself (`runtime/rockit/`) is written in Rockit using this mode.

### Phase 9: Safety Verification (DO-178C) ✅
Configurable Design Assurance Level (DAL A through DAL E) enforcement. Checks for unbounded recursion, dynamic allocation, closures, exceptions, unbounded loops, dynamic strings, async/await, and heap construction. Each violation includes an engineering rationale (ARC-specific costs) and compliant alternative. LLVM debug metadata emission (DICompileUnit, DIFile, DISubprogram, DILocation with `!dbg` annotations). Audit trail export via `--audit <path>` flag generates JSON report with phase artifacts and safety verification results.

## Project Structure

```
RockitCompiler/
├── Package.swift                    # Swift Package Manager manifest
├── CLAUDE.md                        # This file
├── README.md                        # Compiler README
├── bootstrap-swift/                 # Stage 0 Swift compiler
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
│   │   ├── SafetyProfile.swift      # DO-178C DAL A-E safety verification
│   │   ├── CompilerPipeline.swift   # Phased compilation with audit trail
│   │   └── ...                      # 39+ files total
│   ├── RockitCLI/                   # CLI entry point
│   │   └── main.swift               # command tool
│   └── Tests/RockitKitTests/        # 17+ test files, 591 tests
├── lsp/
│   └── RockitLSP/                   # Language server (12 files)
├── self-hosted-rockit/              # Self-hosting compiler in Rockit (~12K lines)
│   ├── lexer.rok                    # Stage 1 lexer
│   ├── parser.rok                   # Stage 1 parser
│   ├── typechecker.rok              # Stage 1 type checker
│   ├── optimizer.rok                # Stage 1 optimizer
│   ├── llvmgen.rok                  # Stage 1 LLVM native codegen (CPS coroutine transform)
│   ├── codegen.rok                  # Stage 1 bytecode codegen + main()
│   ├── command.rok                  # Concatenated compiler (auto-gen via build.sh)
│   ├── command                      # Stage 1 native binary
│   └── stdlib/                      # Standard library submodule (dark-matter-tech/launchpad, 15 modules)
│       └── rockit/                  # 15 stdlib modules (from launchpad submodule)
│           ├── core/collections.rok   # List map/filter/fold/sort/zip/flatten
│           ├── core/math.rok          # Integer & float math, trig, constants
│           ├── core/strings.rok       # pad, repeat, join, split, replace
│           ├── core/result.rok        # Result type (Success/Failure)
│           ├── core/uuid.rok          # UUID v4 generation
│           ├── encoding/base64.rok    # Base64 encode/decode (RFC 4648)
│           ├── encoding/json.rok      # JSON encoder/decoder (RFC 8259)
│           ├── encoding/xml.rok       # XML parsing and generation (W3C XML 1.0)
│           ├── filesystem/file.rok    # File I/O wrappers
│           ├── filesystem/path.rok    # Path join/dir/base/ext/normalize
│           ├── networking/http.rok    # HTTP/1.1 client (RFC 9110)
│           ├── networking/url.rok     # URL parser and encoder (RFC 3986)
│           ├── networking/websocket.rok # WebSocket client (RFC 6455)
│           ├── testing/probe.rok      # Probe test framework (20+ assertions)
│           └── time/datetime.rok      # Date/time utilities (ISO 8601)
├── tests/                           # Rockit integration tests
│   ├── advanced/ core/ collections/ concurrency/
│   ├── functions/ patterns/ stdlib/ types/ ui/
├── runtime/
│   ├── rockit_runtime.c             # C runtime (ARC, task scheduler, event loop, actor wrappers)
│   └── rockit/                      # Modular Rockit runtime (freestanding)
│       ├── memory.rok               # malloc/free wrappers, ARC retain/release
│       ├── string.rok               # RockitString @CRepr struct, new, eq, neq, concat, length
│       ├── string_ops.rok           # charAt, indexOf, substring, split, trim, etc.
│       ├── object.rok               # RockitObject alloc, field get/set, type checking
│       ├── list.rok                 # RockitList, create/append/get/set/remove/size
│       ├── map.rok                  # RockitMap hash table, create/put/get/keys/remove
│       ├── io.rok                   # println, print (int, float, string, any)
│       ├── exception.rok            # setjmp/longjmp exception stack
│       ├── file.rok                 # fileRead, fileWrite, fileExists, fileDelete
│       ├── process.rok              # processArgs, getEnv, platformOS, systemExec
│       ├── math.rok                 # sqrt, sin, cos, tan, floor, ceil, round, etc.
│       ├── concurrency.rok          # Task scheduler, frame alloc/free, event loop
│       └── build.sh                 # Concatenates and compiles all modules
├── examples/                        # 48 feature test files
├── benchmarks/                      # Benchmark suite
└── scripts/                         # Install and packaging scripts
    ├── install.sh
    ├── install.ps1
    └── package.sh
```

RockitKit is a standalone library so it can be imported by other tools (editor plugins, LSP server, Fuel) without the CLI.

## Standard Library

15 modules in `self-hosted-rockit/stdlib/rockit/` (submodule from [dark-matter-tech/launchpad](https://github.com/dark-matter-tech/launchpad)). Import via dot-separated paths: `import rockit.encoding.json`, `import rockit.core.collections`.

| Module | Import | Key Functions |
|--------|--------|--------------|
| Collections | `rockit.core.collections` | listMap, listFilter, listFold, listSort, listZip, listFlatten |
| Math | `rockit.core.math` | gcd, lcm, clamp, lerp, sqrt, sin, cos, PI, pow, log |
| Strings | `rockit.core.strings` | pad, repeat, join, split, reversed, replace, truncate |
| Result | `rockit.core.result` | Success/Failure, resultOrElse, resultMap |
| UUID | `rockit.core.uuid` | uuid4 |
| File I/O | `rockit.filesystem.file` | readFile, writeFile, readLines, exists, deleteFile |
| Path | `rockit.filesystem.path` | pathJoin, pathDir, pathBase, pathExt, pathNormalize |
| HTTP | `rockit.networking.http` | httpGet, httpPost, httpPut, httpDelete, httpRequest |
| WebSocket | `rockit.networking.websocket` | wsConnect, wsSend, wsRecv, wsClose |
| URL | `rockit.networking.url` | urlParse, urlEncode, urlDecode, urlQueryParams |
| Base64 | `rockit.encoding.base64` | base64Encode, base64Decode |
| XML | `rockit.encoding.xml` | xmlParse, xmlStringify, xmlElement, xmlAttribute |
| DateTime | `rockit.time.datetime` | now, dateFromEpoch, formatDate, dayOfWeek |
| JSON | `rockit.encoding.json` | jsonParse, jsonStringify, jsonObject, jsonArray, jsonFrom |
| Probe | `rockit.testing.probe` | 20+ assertions: assertEquals, assertEqualsStr, assertEqualsBool, assertNotEquals, assertNotEqualsStr, assertTrue, assertFalse, assertGreaterThan, assertLessThan, assertGreaterThanOrEqual, assertLessThanOrEqual, assertBetween, assertStringContains, assertStartsWith, assertEndsWith, assertStringEmpty, assertStringNotEmpty, assertStringLength, assert, fail |

### Key constraints for stdlib development

- Only Stage 1 builtins are available (registered in `self-hosted-rockit/typechecker.rok` lines 105-199)
- **NOT available in native codegen**: `toFloat`, `formatFloat`, `stringContains`, `stringSubstring` (use `substring`), `intToString` (use `toString`), `mapContainsKey` (use `mapGet` + null check)
- **Available**: `toString`, `toInt`, `charAt`, `charCodeAt`, `intToChar`, `substring`, `stringLength`, `stringConcat`, `stringIndexOf`, `mapGet`, `mapPut`, `mapKeys`, `listCreate`, `listAppend`, `listGet`, `listSet`, `listSize`, `fileRead`, `fileWriteBytes`, `processArgs`, `getEnv`, `typeOf`, `isMap`, `isList`
- No `continue` in loops — use if/else chains
- `mapGet` returns `null` for missing keys — always check before `toString`
- Tests follow the `test_stdlib_*.rok` naming convention in `examples/`

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

- `bootstrap-swift/RockitKit/Token.swift` — All token definitions. Start here to understand the lexical grammar.
- `bootstrap-swift/RockitKit/Lexer.swift` — The lexer implementation. Working and tested.
- `examples/hello.rok` — A comprehensive test file that exercises most language features.
- `bootstrap-swift/Tests/RockitKitTests/LexerTests.swift` — Shows expected tokenization for various constructs.

## Owner

Micah — Dark Matter Tech founder. Private pilot, Part 107 sUAS operator, iOS developer. Building Rockit as part of the Orion browser platform.
