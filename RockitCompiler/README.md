# Rockit Compiler

![CI](https://github.com/dark-matter-tech/rockit/actions/workflows/ci.yml/badge.svg)

The Rockit language compiler. Self-hosting — Rockit compiles itself.

> **Status:** All phases complete. 542 tests passing. Self-hosting bootstrap verified (Stage 2 == Stage 3). Runtime rewritten in Rockit.

---

## Install

**macOS / Linux (one-liner):**
```bash
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/scripts/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/scripts/install.ps1 | iex
```

The installer downloads a prebuilt binary if available, or builds from source as a fallback. The release includes:

- `rockit` — compiler and build tool
- `fuel` — package manager
- Standard library (22 modules: `rockit.core.*`, `rockit.encoding.*`, `rockit.filesystem.*`, `rockit.networking.*`, `rockit.security.*`, `rockit.testing.*`, `rockit.time.*`)
- C runtime (`rockit_runtime.c`)

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
rockit run examples/hello.rok

# Compile to native binary
rockit build-native examples/hello.rok

# Compile to native and run
rockit run-native examples/hello.rok

# Compile without the standard runtime (freestanding mode)
rockit build-native examples/test_freestanding.rok --no-runtime

# Parse and dump AST
rockit parse examples/hello.rok --dump-ast

# Type-check
rockit check examples/hello.rok

# Compile to bytecode
rockit build examples/hello.rok

# Emit LLVM IR
rockit emit-llvm examples/hello.rok

# Start REPL
rockit launch

# Create a new project
rockit init myproject

# Run tests (recursive discovery in tests/)
rockit test

# Run tests with filter
rockit test --filter testAdd             # match function name
rockit test --filter MathTests           # match class (all tests)
rockit test --filter MathTests::testAdd  # match exact method

# Run tests in watch mode (re-run on file change)
rockit test --watch

# Run a named test scheme from fuel.toml
rockit test --scheme unit

# Run benchmarks
rockit bench                              # run all benchmarks/*.rok
rockit bench benchmarks/bench_fib.rok     # run a single benchmark
rockit bench benchmarks/ --save           # save results to history

# Update to latest version
rockit update

# Version
rockit version

# Fuel — package management
rockit fuel install              # Resolve and fetch all dependencies
rockit fuel add json --git <url> # Add a dependency
rockit fuel remove json          # Remove a dependency
rockit fuel clean                # Clear the package cache
```

## Fuel (Package Manager)

Fuel manages dependencies for Rockit projects. Dependencies are declared in `fuel.toml` and resolved automatically during builds.

### Create a project

```bash
rockit init myproject
cd myproject
```

This creates:
```
myproject/
  fuel.toml         # Project manifest
  src/main.rok      # Entry point
  tests/test_main.rok
```

### fuel.toml

```toml
[package]
name = "myproject"
version = "0.1.0"

[dependencies]
json = "^1.0.0"
http = { version = "~2.1", git = "https://rustygits.com/Dark-Matter/http.git" }
utils = { path = "../my-utils" }

[test]
directory = "tests"
recursive = true
timeout = 30

[test.scheme.unit]
include = ["core", "types", "functions"]

[test.scheme.integration]
include = ["stdlib"]

[test.scheme.all]
include = ["*"]
exclude = ["advanced"]
```

The `[test]` section configures the test runner:
- `directory` — test directory (default: `tests`)
- `recursive` — scan subdirectories (default: `true`)
- `timeout` — per-test timeout in seconds (default: `30`)

Test schemes define named subsets: `rockit test --scheme unit` runs only tests in the `core`, `types`, and `functions` subdirectories.

Dependencies can be:
- **Simple**: `name = "version-constraint"` (requires git URL via `fuel add`)
- **Git**: `name = { version = "constraint", git = "url" }`
- **Local path**: `name = { path = "../relative/path" }`

### Version constraints

| Syntax | Meaning |
|--------|---------|
| `^1.2.3` | Compatible — `>=1.2.3, <2.0.0` |
| `~1.2.3` | Patch only — `>=1.2.3, <1.3.0` |
| `>=1.0.0` | Greater or equal |
| `1.2.3` | Exact version |
| `*` | Any version |

### Commands

```bash
# Add a dependency (git URL required until Silo registry is live)
rockit fuel add json --git https://rustygits.com/Dark-Matter/json.git --version "^1.0"

# Install all dependencies from fuel.toml
rockit fuel install

# Remove a dependency
rockit fuel remove json

# Clear the global package cache
rockit fuel clean
```

### How it works

1. `fuel.toml` is parsed for `[dependencies]`
2. Version tags are discovered via `git ls-remote --tags`
3. The highest version matching each constraint is selected
4. Packages are fetched (shallow clone) into `~/.rockit/packages/`
5. `fuel.lock` is written for reproducible builds
6. All build commands (`build`, `run`, `build-native`, `run-native`, `check`, `emit-llvm`) automatically resolve dependencies — no separate install step required

### Using dependencies

Once a dependency is installed, import its modules:

```kotlin
import json
import http.client

fun main() {
    val data = json.parse("{\"key\": \"value\"}")
    println(data)
}
```

---

## Standard Library

The standard library ships under `self-hosted-rockit/stdlib/rockit/` and is imported with `import rockit.<domain>.<module>`. 22 modules covering core utilities, encoding, filesystem, networking, security, testing, and time.

### Modules

| Module | Import | Description |
|--------|--------|-------------|
| **Core** | | |
| `core/collections` | `import rockit.core.collections` | List utilities — map, filter, fold, sort, zip, flatten, distinct, slice |
| `core/math` | `import rockit.core.math` | Integer and floating-point math — clamp, lerp, gcd, lcm, trig, log, exp |
| `core/strings` | `import rockit.core.strings` | String utilities — pad, repeat, join, split, reversed, replace, truncate |
| `core/result` | `import rockit.core.result` | Result type — Success/Failure sealed class with map, orElse |
| `core/uuid` | `import rockit.core.uuid` | UUID v4 random generation (RFC 4122) |
| **I/O** | | |
| `io/file` | `import rockit.io.file` | File I/O — readFile, writeFile, readLines, writeLines, exists, deleteFile |
| `io/path` | `import rockit.io.path` | Path manipulation — join, dir, base, ext, normalize, isAbsolute |
| **Networking** | | |
| `net/http` | `import rockit.net.http` | HTTP/1.1 client — GET, POST, PUT, DELETE with HTTPS fallback via curl |
| `net/ws` | `import rockit.net.ws` | WebSocket client (RFC 6455) — connect, send, recv, close with masking |
| `net/url` | `import rockit.net.url` | URL parser — parse, encode, decode, query params |
| **Encoding** | | |
| `encoding/base64` | `import rockit.encoding.base64` | Base64 encode/decode (RFC 4648) |
| **Time** | | |
| `time/datetime` | `import rockit.time.datetime` | Date/time — now, dateFromEpoch, formatDate, isLeapYear, dayOfWeek |
| **Data** | | |
| `json` | `import rockit.json` | JSON encoder/decoder — parse, stringify, pretty-print, type-safe API |
| **Testing** | | |
| `test/probe` | `import rockit.test.probe` | Probe test framework — 20 assertion functions for `@Test` annotated tests |

### rockit.core.collections

```
listOf1(a)                              Create single-element list
listOf2(a, b) / listOf3 / listOf4 / listOf5   Create multi-element lists
listMap(list, transform)                Transform each element
listFilter(list, predicate)             Keep matching elements
listFold(list, initial, combine)        Reduce to single value
listSort(list)                          In-place insertion sort
listReverse(list)                       Reverse in place
listSlice(list, start, end)             Sublist extraction
listZip(a, b)                           Interleave two lists
listFlatten(lists)                      Flatten list of lists
listDistinct(list)                      Remove duplicates
listFind(list, predicate)               First match or -1
listAny(list, predicate)                Check if any match
listAll(list, predicate)                Check if all match
listCount(list, predicate)              Count matches
listSum(list) / listMax / listMin       Aggregations
listJoin(list, sep)                     Join as string
listCopy(list)                          Shallow copy
listFirst(list) / listLast(list)        Access endpoints
listIsEmpty(list) / listForEach(list)   Utilities
```

### rockit.core.math

```
square(n) / cube(n) / power(base, exp) / factorial(n)   Integer arithmetic
gcd(a, b) / lcm(a, b)                  Number theory
clamp(value, lo, hi) / sign(n)         Utilities
isEven(n) / isOdd(n)                   Parity checks
PI() / E() / TAU()                      Constants
sqrt(x) / sin(x) / cos(x) / tan(x)    Trigonometry
atan2(y, x) / pow(base, exp)           Advanced math
log(x) / exp(x)                         Logarithms
floor(x) / ceil(x) / round(x)          Rounding
absFloat(x) / clampFloat(v, lo, hi)    Float utilities
toRadians(deg) / toDegrees(rad)         Angle conversion
lerp(a, b, t)                           Linear interpolation
```

### rockit.core.strings

```
padLeft(s, width, ch) / padRight(s, width, ch)  Padding
repeat(s, count)                        Repeat string
join(items, sep) / split(s, delim)      Join and split
reversed(s)                             Reverse string
toUpper(s) / toLower(s)                 Case conversion
trim(s)                                 Strip whitespace
contains(s, sub) / indexOf(s, sub)      Search
replace(s, old, new)                    Replace all occurrences
substring(s, start, end)                Extract range
countOccurrences(s, sub)                Count matches
truncate(s, maxLen)                     Truncate with "..."
zeroPad(s, width)                       Left-pad with zeros
isEmpty(s) / isNotEmpty(s) / length(s)  Properties
charAtPos(s, index)                     Character access
```

### rockit.core.result

```
sealed class Result(val isSuccess: Bool)
class Success(val value: Int) : Result(true)
class Failure(val error: String) : Result(false)

resultOrElse(r, default)                Unwrap or default
resultError(r)                          Get error message
resultMap(r, transform)                 Transform Success value
isSuccess(r) / isFailure(r)             Type checks
```

### rockit.io.file

```
readFile(path)                          Read entire file as string
writeFile(path, content)                Write string to file
readLines(path)                         Read file as list of lines
writeLines(path, lines)                 Write lines to file
exists(path)                            Check if file exists
deleteFile(path)                        Delete file
```

### rockit.io.path

```
pathJoin(a, b)                          Join path components
pathDir(path)                           Directory component
pathBase(path)                          Filename component
pathExt(path)                           File extension (.ext)
pathWithoutExt(path)                    Remove extension
pathIsAbsolute(path)                    Check if absolute
pathNormalize(path)                     Resolve . and ..
```

### rockit.net.http

```
httpGet(url)                            GET request → response map
httpPost(url, body, contentType)        POST request
httpPostJson(url, jsonBody)             POST with JSON content type
httpPut(url, body, contentType)         PUT request
httpDelete(url)                         DELETE request
httpRequest(method, url, headers, body) Full HTTP request
httpStatus(r) / httpBody(r)             Response accessors
httpHeader(r, name) / httpHeaders(r)    Header access (case-insensitive)
httpIsError(r) / httpErrorMessage(r)    Error handling
```

HTTP uses raw TCP sockets for `http://` URLs and falls back to `curl` for `https://`.

### rockit.net.ws

```
wsConnect(url)                          Open WebSocket connection → {fd, error}
wsSend(ws, message)                     Send text frame
wsSendBinary(ws, data)                  Send binary frame
wsRecv(ws)                              Receive frame → {type, data}
wsClose(ws)                             Send close frame and disconnect
wsIsOpen(ws)                            Check connection status
WS_TEXT() / WS_BINARY() / WS_CLOSE()   Frame type constants
WS_PING() / WS_PONG()
```

### rockit.net.url

```
urlParse(url)                           Parse URL → {scheme, host, port, path, query, fragment}
urlScheme(p) / urlHost(p) / urlPort(p)  Component accessors
urlPath(p) / urlQuery(p) / urlFragment(p)
urlQueryParams(query)                   Parse query string → Map
urlQueryParam(query, name)              Get single parameter
urlEncode(s) / urlDecode(s)             Percent-encoding
urlToString(parsed)                     Reconstruct URL
```

### rockit.encoding.base64

```
base64Encode(s)                         Encode string to base64
base64Decode(s)                         Decode base64 to string
```

### rockit.time.datetime

```
now()                                   Current time (epoch millis)
epochSeconds()                          Current time (epoch seconds)
dateFromEpoch(epochMs)                  Epoch → {year, month, day, hour, minute, second, dayOfWeek}
formatDate(d, pattern)                  Format: "YYYY-MM-DD", "MM/DD/YYYY", "DD.MM.YYYY"
formatTime(d)                           Format: "HH:MM:SS"
formatDateTime(d)                       Format: "YYYY-MM-DDTHH:MM:SS"
isLeapYear(year)                        Leap year check
daysInMonth(year, month)                Days in month
dayOfWeek(year, month, day)             0=Sun..6=Sat (Tomohiko Sakamoto)
```

### rockit.json

```
jsonParse(input)                        Parse JSON string → value or error
jsonStringify(v)                        Compact serialization
jsonStringifyPretty(v, indent)          Pretty-print with indentation

jsonNull() / jsonBool(b) / jsonNumber(n) / jsonString(s)  Constructors
jsonArray() / jsonObject() / jsonError(msg)

jsonIsNull(v) / jsonIsBool(v) / jsonIsNumber(v)           Type checks
jsonIsString(v) / jsonIsArray(v) / jsonIsObject(v) / jsonIsError(v)

jsonGetBool(v) / jsonGetInt(v) / jsonGetString(v)         Accessors

jsonArrayAppend(arr, item)              Array operations
jsonArrayGet(arr, i) / jsonArraySet(arr, i, v) / jsonArrayRemoveAt(arr, i)
jsonArraySize(arr)

jsonObjectPut(obj, key, val)            Object operations
jsonObjectGet(obj, key) / jsonObjectRemove(obj, key)
jsonObjectKeys(obj) / jsonObjectSize(obj) / jsonObjectHas(obj, key)

jsonEquals(a, b)                        Deep equality
```

### rockit.test.probe

Probe is the Rockit test framework. Write tests with `@Test` annotation and run with `rockit test`.

**Top-level tests** (backward compatible):

```kotlin
import rockit.test.probe

@Test
fun testMath() {
    assertEquals(4, 2 + 2, "addition")
    assertGreaterThan(10, 5)
}
```

**Class-based test suites** — classes containing `@Test` methods act as test suites (like Kotlin/Swift). Optional `setUp()` and `tearDown()` lifecycle methods run before/after each test:

```kotlin
import rockit.test.probe

class MathTests {
    fun setUp() { /* runs before each @Test */ }
    fun tearDown() { /* runs after each @Test */ }

    @Test fun testAdd() { assertEquals(4, 2 + 2, "addition") }
    @Test fun testSub() { assertEquals(1, 3 - 2, "subtraction") }
}

// Top-level @Test functions still work alongside class suites
@Test fun testStandalone() { assertTrue(true, "standalone") }
```

Output format:
```
  PASS  test_math.rok::MathTests::testAdd
  PASS  test_math.rok::MathTests::testSub
  PASS  test_math.rok::testStandalone
```

**Assertions:**

```
assert(condition, message?)             Generic assertion
assertTrue(cond, msg?) / assertFalse(cond, msg?)
assertEquals(expected, actual, msg?)    Int equality
assertEqualsStr(expected, actual, msg?) String equality
assertNotEquals(a, b, msg?)             Int inequality
assertGreaterThan(a, b, msg?)           a > b
assertLessThan(a, b, msg?)             a < b
assertStringContains(s, sub, msg?)      Substring check
assertStartsWith(s, prefix, msg?)       Prefix check
assertEndsWith(s, suffix, msg?)         Suffix check
fail(msg?)                              Unconditional failure
```

**Running tests:**

```bash
rockit test                              # discover tests/ recursively
rockit test path/to/file.rok             # run a specific file
rockit test --filter testAdd             # match function name
rockit test --filter MathTests           # all tests in class
rockit test --filter MathTests::testAdd  # exact class::method
rockit test --watch                      # re-run on file changes
rockit test --scheme unit                # run named scheme from fuel.toml
```

### JSON Example

```kotlin
import rockit.json

fun main(): Unit {
    val input = "{\"name\": \"Rockit\", \"version\": 1, \"features\": [\"fast\", \"safe\"]}"
    val obj = jsonParse(input)

    // Read values
    println(jsonGetString(jsonObjectGet(obj, "name")))  // Rockit
    println(jsonGetInt(jsonObjectGet(obj, "version")))   // 1

    // Modify
    jsonObjectPut(obj, "stable", jsonBool(true))

    // Serialize
    println(jsonStringify(obj))
    println(jsonStringifyPretty(obj, 0))
}
```

See `examples/json_tool.rok` for a complete file-based JSON tool (pretty-print, compact, info modes).

---

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

Run the full suite: `bash benchmarks/run_benchmarks.sh`

### Built-in Benchmark Runner

`rockit bench` provides built-in benchmarking with history tracking and regression detection.

**Whole-file benchmarks** — any `.rok` file in `benchmarks/` is treated as a benchmark:

```bash
rockit bench benchmarks/bench_fib.rok         # single file
rockit bench benchmarks/                       # all benchmarks in directory
rockit bench                                   # default: benchmarks/ directory
```

**`@Benchmark` annotated functions** — fine-grained benchmarks within a file:

```kotlin
import rockit.test.probe

fun fib(n: Int): Int {
    if (n <= 1) { return n }
    return fib(n - 1) + fib(n - 2)
}

@Benchmark
fun benchFib30() {
    val result = fib(30)
}
```

**Options:**

```bash
rockit bench --runs 10                # measurement runs (default: 5)
rockit bench --warmup 3               # warmup runs (default: 2)
rockit bench --save                   # save to .rockit/bench_history.json
```

**Regression detection** — when history exists, results are compared against the previous run:

```
  bench_fib       145ms avg    +2.1ms (+1.5%)
  bench_monkey    892ms avg    -30ms  (-3.3%)  ✓ faster
  bench_matrix    355ms avg    +14ms  (+4.1%)  ⚠ regression (>3%)
```

Results are stored in `.rockit/bench_history.json` with commit hash and timestamp for tracking performance over time.

---

## Architecture

```
RockitCompiler/
├── Package.swift
├── README.md
├── bootstrap-swift/           # Stage 0 Swift compiler
│   ├── RockitKit/             #   Core compiler library (37+ files)
│   │   ├── Token.swift        #   130+ token types
│   │   ├── Lexer.swift        #   Single-pass UTF-8 scanner
│   │   ├── Parser.swift       #   Recursive descent parser
│   │   ├── TypeChecker.swift
│   │   ├── MIRLowering.swift
│   │   ├── MIROptimizer.swift
│   │   ├── CodeGen.swift      #   MIR → bytecode
│   │   ├── LLVMCodeGen.swift  #   MIR → LLVM IR → native
│   │   ├── VM.swift           #   Bytecode interpreter
│   │   ├── Scheduler.swift    #   Coroutine scheduler
│   │   ├── Coroutine.swift    #   Coroutine state machine
│   │   └── ...
│   ├── RockitCLI/             #   CLI entry point
│   └── Tests/RockitKitTests/  #   542 Swift tests
├── lsp/
│   └── RockitLSP/             # Language server (12 files)
├── self-hosted-rockit/        # Stage 1 Rockit compiler (~12K lines)
│   ├── lexer.rok
│   ├── parser.rok
│   ├── typechecker.rok
│   ├── optimizer.rok
│   ├── codegen.rok
│   ├── llvmgen.rok
│   ├── command.rok            # Concatenated compiler source
│   ├── command                # Stage 1 native binary
│   └── stdlib/                # Standard library submodule (launchpad, 22 modules)
│       └── rockit/
│           ├── core/          # collections, math, strings, result, uuid
│           ├── encoding/      # base64, hpack, json, xml
│           ├── filesystem/    # file, path
│           ├── networking/    # http, http2, url, websocket
│           ├── security/      # tls, crypto, x509, pem
│           ├── testing/       # probe
│           └── time/          # datetime
├── tests/                     # Rockit integration tests
│   ├── advanced/
│   ├── core/
│   ├── collections/
│   ├── concurrency/
│   ├── functions/
│   ├── patterns/
│   ├── stdlib/
│   ├── types/
│   └── ui/
├── examples/                  # 48+ example/test .rok files
├── benchmarks/                # Benchmark suite
├── runtime/
│   ├── rockit_runtime.c       # C runtime (ARC, actors, coroutines)
│   └── rockit/                # Modular Rockit runtime (freestanding)
│       ├── memory.rok         # malloc/free, ARC retain/release
│       ├── string.rok         # String struct, new, eq, neq, concat, length
│       ├── string_ops.rok     # charAt, indexOf, substring, split, trim
│       ├── object.rok         # Object alloc, field access, type checking
│       ├── list.rok           # List create/append/get/set/remove/size
│       ├── map.rok            # Map create/put/get/keys/remove
│       ├── io.rok             # println, print (int, float, string, any)
│       ├── exception.rok      # setjmp/longjmp exception stack
│       ├── file.rok           # fileRead, fileWrite, fileExists, fileDelete
│       ├── process.rok        # processArgs, getEnv, platformOS, systemExec
│       ├── math.rok           # sqrt, sin, cos, tan, floor, ceil, round, etc.
│       ├── concurrency.rok    # Task scheduler, frame alloc/free, event loop
│       └── build.sh           # Concatenates and compiles all modules
└── scripts/                   # Install and packaging scripts
    ├── install.sh
    ├── install.ps1
    └── package.sh
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
| Diagnostics | `textDocument/publishDiagnostics` | Tested |
| Hover | `textDocument/hover` | Tested |
| Completion | `textDocument/completion` | Tested |
| Go to Definition | `textDocument/definition` | Tested |
| Go to Type Definition | `textDocument/typeDefinition` | Tested |
| Go to Implementation | `textDocument/implementation` | Tested |
| Find References | `textDocument/references` | Tested |
| Document Symbols | `textDocument/documentSymbol` | Tested |
| Workspace Symbols | `workspace/symbol` | Tested |
| Signature Help | `textDocument/signatureHelp` | Tested |
| Rename Symbol | `textDocument/rename` | Tested |
| Call Hierarchy | `callHierarchy/incomingCalls`, `outgoingCalls` | TODO: test |
| Semantic Tokens | `textDocument/semanticTokens/full` | Tested |
| Document Formatting | `textDocument/formatting` | Tested |
| On Type Formatting | `textDocument/onTypeFormatting` | TODO: test |
| Inlay Hints | `textDocument/inlayHint` | Tested |
| Code Actions | `textDocument/codeAction` | TODO: test |
| Document Links | `textDocument/documentLink` | Tested |
| Folding Ranges | `textDocument/foldingRange` | Tested |
| Document Highlight | `textDocument/documentHighlight` | Tested |
| Selection Range | `textDocument/selectionRange` | TODO: test |
| Type Hierarchy | `typeHierarchy/supertypes`, `subtypes` | Tested |
| Range Formatting | `textDocument/rangeFormatting` | TODO: test |
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
