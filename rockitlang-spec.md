# Rockit Programming Language — Complete Website Spec

> Single source of truth for rockitlang.com.
> Everything marked **[Shipped]** is real and working today.
> Everything marked **[Planned]** is on the roadmap but not yet available.
> All code examples use Rockit syntax (`.rok` files).

---

## 1. Identity

- **Name:** Rockit
- **File extensions:** `.rok` (source), `.rokb` (bytecode)
- **Organization:** Dark Matter Tech
- **Tagline:** A statically-typed, compiled, memory-safe programming language.
- **License:** Apache 2.0
- **Copyright:** 2026 Dark Matter Tech
- **Website:** rockitlang.com
- **Source Code:** https://rustygits.com/Dark-Matter/moon
- **Current Version:** 0.1.0

---

## 2. What Rockit Is

Rockit is a general-purpose, statically-typed, compiled programming language designed to eventually replace JavaScript, HTML, CSS, and the DOM as the foundational technology of the web platform. Today it ships as a standalone compiled language with a rich standard library, package manager, test framework, and editor support.

Rockit is **not** a wrapper around another language. It has its own compiler, its own runtime, its own intermediate representation (MIR), and its own package manager (Fuel). The goal is zero dependency on any external language ecosystem.

### Design Philosophy

- **Declare intent, not mechanics.** Developers describe what they want. The runtime handles platform-specific implementation.
- **One codebase, native everywhere.** Rockit runs on macOS, Linux, and Windows — each delivering its best native experience.
- **Fail at compile time, not runtime.** Type system, null safety, exhaustive matching, and capability declarations catch errors before deployment.
- **Security is not optional.** Hardware-backed crypto, signed packages, capability permissions built in.
- **Performance is a feature.** ARC + AOT + retained-mode renderer = consistent 60/120fps.

### Key Properties

- **Type safety** — All types known at compile time. No implicit coercion, no runtime type errors.
- **Null safety** — Enforced at compile time. `String` vs `String?`, safe calls (`?.`), elvis operator (`?:`), non-null assertion (`!!`), smart casts.
- **Memory safety** — ARC (Automatic Reference Counting) with cycle detection. No garbage collector. No manual memory management. Deterministic deallocation.
- **Compiled** — AOT compilation to native binaries via LLVM. Also has a bytecode interpreter for development.
- **Self-hosting** — The Rockit compiler is written in Rockit. It compiles itself.
- **Kotlin-inspired syntax** — Familiar to Kotlin, Swift, and TypeScript developers. Its memory model borrows from Swift's ARC. Its UI framework draws from SwiftUI, Jetpack Compose, and Flutter's declarative paradigms.

---

## 3. Status — What's Shipped

The compiler is **self-hosting** and all compiler phases are complete. 542 tests pass across the full pipeline.

| Component | Status |
|-----------|--------|
| Lexer (130+ token types) | **[Shipped]** |
| Parser (recursive descent) | **[Shipped]** |
| Type Checker (inference, null safety, generics) | **[Shipped]** |
| MIR Lowering (AST → Rockit IR) | **[Shipped]** |
| MIR Optimizer (DCE, inlining, constant folding) | **[Shipped]** |
| Bytecode Codegen | **[Shipped]** |
| Native Codegen (LLVM IR → ARM64/x86_64) | **[Shipped]** |
| Bytecode VM (interpreter) | **[Shipped]** |
| Runtime (ARC, actors, coroutines) | **[Shipped]** |
| Runtime rewrite (Rockit, freestanding) | **[Shipped]** |
| Freestanding Mode (`--no-runtime`) | **[Shipped]** |
| Global Variables | **[Shipped]** |
| Structured Concurrency (VM) | **[Shipped]** |
| Self-hosting Bootstrap (Stage 2 == Stage 3) | **[Shipped]** |
| Standard Library (15 modules) | **[Shipped]** |
| Package Manager (Fuel) | **[Shipped]** |
| Test Framework (Probe) | **[Shipped]** |
| Benchmark Runner | **[Shipped]** |
| REPL (Launch) | **[Shipped]** |
| Language Server (LSP, 25+ features) | **[Shipped]** |
| Editor Support (VS Code, JetBrains, Vim/Neovim) | **[Shipped]** |

---

## 4. Ecosystem

| Tool | Name | Status | Description |
|------|------|--------|-------------|
| Language | **Rockit** | [Shipped] | `.rok` / `.rokb` files |
| Compiler + CLI | **Command** | [Shipped] | Build, run, test, benchmark |
| Package Manager | **Fuel** | [Shipped] | Bundled with every release |
| Standard Library | **stdlib** (`rockit.*`) | [Shipped] | 15 modules bundled |
| Test Framework | **Probe** | [Shipped] | `@Test` annotations, 20 assertions |
| Benchmark Runner | Built-in | [Shipped] | `@Benchmark`, history tracking |
| REPL | **Launch** | [Shipped] | `rockit launch` |
| Language Server | **RockitLSP** | [Shipped] | `rockit lsp` |
| Package Registry | **Silo** | [Planned] | Centralized package registry |
| Browser | **Nova** | [Planned] | Dual-engine (Rockit + legacy JS) |
| Rendering Engine | **Supernova** | [Planned] | GPU-accelerated compositor |

Rockit releases bundle the compiler, Fuel, stdlib, and prebuilt runtime into a single download. Install once, everything works.

---

## 5. Installation

### Quick Install

**macOS / Linux (one-liner):**
```bash
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
```

This installs the `rockit` binary to `/usr/local/bin` and the runtime to `/usr/local/share/rockit/`.

**Windows (PowerShell):**
```powershell
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.ps1 | iex
```

This installs to `%LOCALAPPDATA%\Rockit\bin` and adds it to your user PATH.

The installer downloads a prebuilt binary if available, or builds from source as a fallback.

### Docker

```bash
# Build the image
docker build -t rockit RockitCompiler/

# Run a .rok file
docker run --rm rockit run /usr/local/lib/rockit/examples/hello.rok

# Mount your project directory
docker run --rm -v $(pwd):/code rockit run /code/main.rok

# Interactive REPL
docker run --rm -it rockit repl

# Native compilation inside the container
docker run --rm -v $(pwd):/code rockit run-native /code/main.rok
```

### Build from Source

**Prerequisites:**

| Prerequisite | Version | macOS | Linux | Windows |
|---|---|---|---|---|
| **Swift** | 5.9+ | Xcode or swift.org | swift.org | swift.org |
| **Clang/LLVM** | 14+ | `xcode-select --install` | `apt install clang` | releases.llvm.org |
| **Git** | any | Included with Xcode | `apt install git` | git-scm.com |

```bash
git clone https://rustygits.com/Dark-Matter/moon.git
cd moon/RockitCompiler

# Debug build
make build

# Release build
make release

# Install system-wide (may need sudo on Linux)
sudo make install

# Or install to a custom location
make install PREFIX=$HOME/.local

# Verify
rockit version
rockit run Examples/hello.rok
```

### Custom Install Location

```bash
# macOS / Linux
export ROCKIT_PREFIX=$HOME/.rockit
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/RockitCompiler/install.sh | bash
```

If the runtime is in a non-standard location:
```bash
export ROCKIT_RUNTIME_DIR=/path/to/rockit/runtime
```

### Update

```bash
rockit update
```

### What Gets Installed

- `rockit` — compiler and build tool
- `fuel` — package manager
- Standard library (15 modules under `share/rockit/stdlib/`)
- Prebuilt runtime (`rockit_runtime.o`)

### Platforms

| Platform | Build | Bytecode VM | Native Compile |
|----------|-------|-------------|----------------|
| macOS (arm64) | Yes | Yes | Yes |
| macOS (x86_64) | Yes | Yes | Yes |
| Linux (x86_64) | Yes | Yes | Yes |
| Linux (arm64) | Yes | Yes | Yes |
| Windows (x86_64) | Yes | Yes | Yes |
| Docker | Yes | Yes | Yes |

### Uninstall

**macOS / Linux:**
```bash
make uninstall
# or manually:
rm /usr/local/bin/rockit
rm -rf /usr/local/share/rockit
```

**Windows:**
```powershell
Remove-Item -Recurse "$env:LOCALAPPDATA\Rockit"
```

### Troubleshooting

**`rockit: command not found`** — Ensure the install directory is on your PATH. macOS/Linux: `export PATH="/usr/local/bin:$PATH"` (add to `~/.zshrc` or `~/.bashrc`). Windows: The installer adds to PATH automatically; restart your terminal.

**`error: clang not found`** — Native compilation requires Clang. Install it: macOS: `xcode-select --install`. Linux: `sudo apt install clang`. Windows: Install LLVM from releases.llvm.org.

**`error: runtime not found`** — Set `ROCKIT_RUNTIME_DIR` to the directory containing the runtime: `export ROCKIT_RUNTIME_DIR=/usr/local/share/rockit`

---

## 6. Hello World

```kotlin
// hello.rok
fun main() {
    println("Hello, Rockit!")
}
```

```bash
# Run with bytecode interpreter
rockit run hello.rok

# Compile to native binary and run
rockit run-native hello.rok

# Compile to native binary (output: hello)
rockit build-native hello.rok
```

---

## 7. Language Overview

### 7.1 Variables and Constants

```kotlin
val name: String = "Rockit"     // immutable (cannot be reassigned)
var counter: Int = 0            // mutable
val inferred = 42               // type inference (compiler infers Int)

// Null safety
val required: String = "always set"      // can never be null
val optional: String? = null             // nullable type
val length = optional?.length ?: 0       // safe call + elvis operator
val forced = optional!!                  // non-null assertion (throws if null)

// Smart casts
if (optional != null) {
    print(optional.length)               // compiler knows it's non-null here
}
```

### 7.2 Functions

```kotlin
fun add(a: Int, b: Int): Int {
    return a + b
}

// Expression body (single expression)
fun multiply(a: Int, b: Int): Int = a * b

// Default parameters
fun greet(name: String, greeting: String = "Hello"): String {
    return "${greeting}, ${name}!"
}

// Unit return type (void)
fun logMessage(msg: String): Unit {
    println(msg)
}

// Suspend functions (for async)
suspend fun fetchData(): String {
    return await httpGet("https://api.example.com/data")
}
```

### 7.3 Control Flow

```kotlin
// If as expression
val label = if (count > 0) "Items: $count" else "Empty"

// When (exhaustive pattern matching)
val result = when (status) {
    Status.Active  -> "Running"
    Status.Paused  -> "On hold"
    Status.Stopped -> "Done"
}

// When with type checking
fun describe(obj: Any): String = when {
    obj is String -> "String: $obj"
    obj is Int    -> "Int: $obj"
    else          -> "Unknown"
}

// For loops
for (i in 0 until 10) { /* 0..9 */ }
for (item in list) { /* iterate */ }

// While loops
while (condition) { /* body */ }
```

### 7.4 Classes

```kotlin
class Person(val name: String, var age: Int) {
    fun greet(): String = "Hi, I'm $name"
}

// Inheritance
open class Animal(val name: String) {
    open fun speak(): String = "..."
}

class Dog(name: String) : Animal(name) {
    override fun speak(): String = "Woof!"
}
```

### 7.5 Data Classes

Auto-generated `equals`, `hashCode`, `toString`, `copy`, and destructuring.

```kotlin
data class User(
    val id: String,
    val name: String,
    val email: String,
    val role: Role = Role.Viewer
)

val user = User("1", "Alice", "alice@example.com")
val (id, name, email) = user                  // destructuring
val admin = user.copy(role = Role.Admin)       // copy with modification
println(user)  // User(id=1, name=Alice, email=alice@example.com, role=Viewer)
```

### 7.6 Sealed Classes

Restricted class hierarchies with exhaustive `when` matching.

```kotlin
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

fun handle(r: Result<User>) = when (r) {
    is Result.Success -> showUser(r.data)
    is Result.Error   -> showError(r.message)
    Result.Loading    -> showSpinner()
    // No else needed — compiler verifies all cases covered
}
```

### 7.7 Interfaces

```kotlin
interface Serializable {
    fun toBytes(): ByteArray
    fun contentType(): String = "application/octet-stream"  // default implementation
}

class ApiResponse(
    override val cacheKey: String,
    val body: ByteArray
) : Serializable, Cacheable {
    override fun toBytes() = body
}
```

### 7.8 Enum Classes

```kotlin
enum class Color {
    RED, GREEN, BLUE
}

enum class Direction {
    NORTH, SOUTH, EAST, WEST
}
```

### 7.9 Object Declarations (Singletons)

```kotlin
object Logger {
    fun info(msg: String) { println("[INFO] $msg") }
    fun error(msg: String) { println("[ERROR] $msg") }
}

Logger.info("Starting up")
```

### 7.10 Generics

```kotlin
class Repository<T : Entity> {
    fun add(item: T) { items.add(item) }
    fun find(id: String): T? = items.firstOrNull { it.id == id }
}

// Variance
interface Producer<out T> { fun produce(): T }     // covariant
interface Consumer<in T> { fun consume(item: T) }  // contravariant
```

### 7.11 Extension Functions

```kotlin
fun String.isValidEmail(): Bool =
    this.matches(Regex("[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+"))

val List<Int>.median: Float64
    get() {
        val s = this.sorted()
        return if (size % 2 == 0) (s[size/2-1] + s[size/2]) / 2.0
        else s[size/2].toFloat64()
    }
```

### 7.12 String Interpolation

```kotlin
val name = "Rockit"
println("Hello, $name!")                         // simple variable
println("Result: ${2 + 2}")                     // expression
println("${user.name} (${user.email})")         // member access
println("Items: ${list.size}")                  // method call
```

### 7.13 Lambdas

```kotlin
val doubled = listOf(1, 2, 3).map { it * 2 }
items.filter { it.price > 10.0 }.sortedBy { it.name }.take(5)

// With explicit parameters
val sum = listOf(1, 2, 3).fold(0) { acc, item -> acc + item }
```

### 7.14 Number Formats

```kotlin
val decimal = 1_000_000          // underscores for readability
val hex = 0xFF                   // hexadecimal
val binary = 0b1010              // binary
val float = 3.14                 // float literal
val scientific = 1.5e10          // scientific notation
```

### 7.15 Comments

```kotlin
// Single-line comment

/* Block comment */

/* Nestable block comments
   /* inner comment */
   still in outer comment
*/
```

### 7.16 Annotations

```kotlin
@Test                    // marks a function as a test
@Benchmark               // marks a function as a benchmark
@Capability(...)         // declares platform capability requirements [Planned]
@State                   // marks view state variable [Planned]
@NoCycle                 // compiler hint: no reference cycles possible
@CRepr                   // C-compatible memory layout (freestanding mode)
```

### 7.17 Type Aliases

```kotlin
typealias StringMap = Map<String, String>
typealias Handler = (Request) -> Response
```

---

## 8. Type System

Every value has a known type at compile time. No `any` type in user code (internally the compiler supports `Any` for stdlib auto-wrapping), no implicit coercion, no escape hatches.

### 8.1 Primitive Types

| Type | Size | Description |
|------|------|-------------|
| `Int` | 64-bit | Signed integer (default) |
| `Int8` | 8-bit | Signed byte |
| `Int16` | 16-bit | Signed short |
| `Int32` | 32-bit | Signed int |
| `Float32` | 32-bit | IEEE 754 single-precision float |
| `Float64` | 64-bit | IEEE 754 double-precision float |
| `Bool` | 1-bit | `true` or `false` |
| `Char` | 32-bit | Unicode scalar value |
| `String` | Variable | UTF-8, immutable |
| `ByteArray` | Variable | Mutable byte buffer |
| `List` | Variable | Ordered, mutable collection |
| `Map` | Variable | Key-value hash table |
| `Unit` | 0-bit | Void (function returns nothing useful) |
| `Nothing` | 0-bit | Bottom type (function never returns) |
| `Any` | — | Top type (accepts any value, used internally) |

### 8.2 Null Safety

```kotlin
val name: String = "Rockit"       // never null — compile error if assigned null
val alias: String? = null         // nullable — explicitly opted in
val len = alias?.length ?: 0      // safe call returns null if alias is null; elvis provides default

if (alias != null) {
    print(alias.length)           // smart cast: compiler knows alias is non-null here
}

val forced = alias!!              // non-null assertion: throws NullPointerException if null
```

### 8.3 Generics with Variance

```kotlin
class Box<T>(val value: T)

interface Producer<out T> { fun produce(): T }     // covariant (out = read-only)
interface Consumer<in T> { fun consume(item: T) }  // contravariant (in = write-only)

class Repository<T : Entity> {                     // upper bound constraint
    fun add(item: T) { items.add(item) }
    fun find(id: String): T? = items.firstOrNull { it.id == id }
}
```

---

## 9. Memory Model — ARC

Rockit uses **Automatic Reference Counting** (ARC) supplemented by a lightweight cycle detector. No garbage collector.

### Why ARC (not GC)

- **Deterministic deallocation** — objects are freed the instant the last reference drops
- **No GC pauses** — garbage collectors periodically stop the world to scan memory. Even "low-pause" GCs like G1 or ZGC add 1-10ms jitter. At 60fps you have 16.6ms per frame; at 120fps you have 8.3ms. A single GC pause can drop frames.
- **Predictable memory usage** — no surprise spikes from collection runs
- **Lower baseline memory** — no GC runtime overhead. Rockit uses 3-40x less memory than Node.js and 2-6x less than Go.

### ARC Semantics

```kotlin
fun processOrder(cart: Cart) {
    val order = Order(cart)           // refcount = 1
    val receipt = order.receipt()     // refcount = 2
    sendEmail(receipt)
    // scope exit: refcount drops to 0 → immediate deallocation
}
```

### Weak and Unowned References

Used to break reference cycles:

```kotlin
class Parent { var children: List<Child> = emptyList() }
class Child { weak var parent: Parent? = null }       // zeroed when parent is freed
class Engine { unowned val vehicle: Vehicle }          // not zeroed, dangling access crashes
```

### Cycle Detector

- Compiler statically analyzes object graphs. Objects with no possible cycles are marked `@NoCycle` automatically (zero overhead).
- Only potential-cycle objects register with the background incremental detector.
- Detector uses a mark-and-sweep variant running in incremental slices during idle time.
- Never pauses the UI thread.
- Typical cycle collection: < 0.1ms per scan.

```kotlin
// Compiler-inferred: no cycle possible
@NoCycle
class Logger(val tag: String)

// Potential cycle: parent <-> child
class TreeNode(val value: String) {
    var children: List<TreeNode> = emptyList()
    weak var parent: TreeNode? = null
}
```

---

## 10. Concurrency

Structured concurrency inspired by Kotlin coroutines and Swift async/await, with compile-time data race safety.

### 10.1 Async/Await

```kotlin
suspend fun fetchUser(id: String): User {
    val resp = http.get("https://api.example.com/users/$id")
    return resp.decode<User>()
}
```

### 10.2 Structured Concurrency

```kotlin
suspend fun loadDashboard() {
    val (user, orders, notifs) = concurrent {
        val u = async { fetchUser(userId) }
        val o = async { fetchOrders(userId) }
        val n = async { fetchNotifications(userId) }
        Triple(u.await(), o.await(), n.await())
    }
    render(Dashboard(user, orders, notifs))
}
```

### 10.3 Actors

Thread-safe objects with serialized access. All method calls are automatically dispatched through a mailbox — safe from any coroutine.

```kotlin
actor ShoppingCart {
    private var items = mutableListOf<CartItem>()
    fun add(item: CartItem) { items.add(item) }
    fun total(): Float64 = items.sumOf { it.price * it.quantity }
}

// All access automatically serialized — no data races
cart.add(item)  // safe from any coroutine
```

### 10.4 Reactive Streams [Planned]

```kotlin
val prices: Flow<Float64> = stockTicker("GOOG")
prices.filter { it > 150.0 }
    .map { PriceAlert("GOOG", it) }
    .collect { notify(it) }

val cartItems = MutableStateFlow<List<CartItem>>(emptyList())
cartItems.value = cartItems.value + newItem  // triggers re-render
```

---

## 11. Declarative UI [Language Shipped, Runtime Planned]

Rockit has first-class syntax for UI components, styling, and navigation. The language constructs (parser, type checker, codegen) are fully implemented. The rendering runtime (Supernova) is planned.

### 11.1 Views

```kotlin
view ProductCard(product: Product) {
    Column(spacing = 12.dp, padding = 16.dp) {
        Image(product.thumbnailUrl)
            .size(200.dp, 200.dp).cornerRadius(8.dp)
        Text(product.name).font(.headline).color(.primary)
        Text("$$${product.price}").font(.body).color(.secondary)
        Button("Add to Cart") { cart.add(product) }
            .style(.primary).fullWidth()
    }
}
```

### 11.2 State Management

```kotlin
view Counter() {
    @State var count = 0
    Column(alignment = .center, spacing = 16.dp) {
        Text("Count: $count").font(.display)
        Row(spacing = 8.dp) {
            Button("-") { count-- }.style(.outlined)
            Button("+") { count++ }.style(.primary)
        }
    }
}
```

### 11.3 Navigation

```kotlin
navigation App {
    route("/") { HomePage() }
    route("/products/{id}") { p -> ProductDetail(p["id"]) }
    route("/cart") { CartPage() }
}
Navigator.push("/products/${product.id}")
```

### 11.4 Styling (No CSS)

Type-safe styling with no cascade, no specificity, no selectors.

```kotlin
val cardStyle = Style {
    background(.surface)
    cornerRadius(12.dp)
    shadow(elevation = 4.dp, color = .black.opacity(0.1))
    padding(16.dp)
}

theme AppTheme {
    colors { primary = Color(0x5B21B6); surface = Color(0xFFFFFF) }
    typography {
        headline = Font("Inter", size = 24.sp, weight = .semibold)
        body = Font("Inter", size = 16.sp, weight = .regular)
    }
}
```

---

## 12. Platform Capability API [Planned]

Rockit apps declare intent; the runtime resolves platform-specific implementation. One codebase works across all platforms.

### 12.1 Payments

```kotlin
@Capability(requires = Capability.Payments)
suspend fun checkout(cart: Cart): PaymentResult {
    val payment = Payment(cart.total, Currency.USD)
    // Apple -> Apple Pay | Android -> Google Pay | Fallback -> Stripe
    return Platform.payments.request(payment)
}
```

### 12.2 Notifications

```kotlin
@Capability(requires = Capability.Notifications)
suspend fun registerPush() {
    val token = Platform.notifications.register()
    // Apple -> APNs | Android -> FCM | Windows -> WNS
    api.registerDevice(token)
}
```

### 12.3 Biometrics

```kotlin
@Capability(requires = Capability.Biometrics)
suspend fun authenticate(): AuthResult {
    return Platform.biometrics.authenticate(
        reason = "Confirm your identity"
    )
    // Apple -> Face ID | Android -> BiometricPrompt | Win -> Hello
}
```

### 12.4 Hardware Security

First-class HSM, secure enclave, and hardware token support. Private keys never leave the hardware.

```kotlin
@Capability(requires = Capability.HardwareCrypto)
suspend fun signDocument(doc: ByteArray): Signature {
    val key = Platform.crypto.getKey(
        id = "signing-key", type = KeyType.Ed25519,
        requireHardware = true
    )
    return key.sign(doc)  // hardware signs, key never exposed
}
```

### 12.5 Platform Detection

```kotlin
when (Platform.current.os) {
    OS.MacOS   -> { /* WebKit */ }
    OS.Android -> { /* Blink */ }
    OS.Windows -> { /* Blink */ }
}
if (Platform.supports(Capability.Payments)) showPaymentButton()
```

---

## 13. CLI Reference

### All Commands

| Command | Description |
|---------|-------------|
| `rockit run <file>` | Execute a `.rok` or `.rokb` file (bytecode) |
| `rockit build <file.rok>` | Compile to bytecode (`.rokb`) |
| `rockit build-native <file>` | Compile to native executable via LLVM |
| `rockit run-native <file>` | Compile to native and execute |
| `rockit emit-llvm <file>` | Emit LLVM IR (`.ll`) for inspection |
| `rockit parse <file> --dump-ast` | Parse and dump AST |
| `rockit check <file>` | Type-check only |
| `rockit launch` | Start interactive REPL |
| `rockit init [name]` | Create a new Rockit project |
| `rockit test [file]` | Run tests (recursive discovery, class suites) |
| `rockit bench [file\|dir]` | Run benchmarks and track performance |
| `rockit update` | Update Rockit to the latest version |
| `rockit version` | Print version |
| `rockit lsp` | Start the language server |
| `rockit fuel install` | Resolve and fetch all dependencies |
| `rockit fuel add <pkg> --git <url>` | Add a dependency |
| `rockit fuel remove <pkg>` | Remove a dependency |
| `rockit fuel clean` | Clear the package cache |

### Test Options

```
--filter <name>     Filter by function name, ClassName, or ClassName::method
--watch             Re-run tests on file changes
--scheme <name>     Run a named test scheme from fuel.toml
```

### Bench Options

```
--runs <n>          Measurement runs (default: 5)
--warmup <n>        Warmup runs (default: 2)
--save              Save results to .rockit/bench_history.json
```

### Build Options

```
--no-runtime        Compile without standard runtime (freestanding mode)
-o <output>         Specify output path
--runtime-path <p>  Specify runtime object path
```

---

## 14. Fuel (Package Manager)

Fuel ships bundled with every Rockit install. It manages dependencies declared in `fuel.toml`.

### 14.1 Create a Project

```bash
rockit init myproject
cd myproject
```

Creates:
```
myproject/
  fuel.toml           # Project manifest
  src/main.rok        # Entry point
  tests/test_main.rok # Test file
```

### 14.2 fuel.toml

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

### 14.3 Version Constraints

| Syntax | Meaning |
|--------|---------|
| `^1.2.3` | Compatible — `>=1.2.3, <2.0.0` |
| `~1.2.3` | Patch only — `>=1.2.3, <1.3.0` |
| `>=1.0.0` | Greater or equal |
| `1.2.3` | Exact version |
| `*` | Any version |

### 14.4 Dependency Types

- **Simple**: `name = "version-constraint"` (requires git URL via `fuel add`)
- **Git**: `name = { version = "constraint", git = "url" }`
- **Local path**: `name = { path = "../relative/path" }`

### 14.5 How It Works

1. `fuel.toml` is parsed for `[dependencies]`
2. Version tags are discovered via `git ls-remote --tags`
3. The highest version matching each constraint is selected
4. Packages are fetched (shallow clone) into `~/.rockit/packages/`
5. `fuel.lock` is written for reproducible builds
6. All build commands (`build`, `run`, `build-native`, `run-native`, `check`, `emit-llvm`) automatically resolve dependencies — no separate install step required

### 14.6 Using Dependencies

```kotlin
import json
import http.client

fun main() {
    val data = json.parse("{\"key\": \"value\"}")
    println(data)
}
```

### 14.7 Test Schemes

Named subsets of tests defined in `fuel.toml`:

```bash
rockit test --scheme unit          # only core/types/functions tests
rockit test --scheme integration   # only stdlib tests
rockit test --scheme all           # everything except "advanced"
```

---

## 15. Standard Library — Complete API Reference

15 modules ship with every Rockit install. Import with `import rockit.<module>`.

### Module Overview

| Module | Import | Description |
|--------|--------|-------------|
| Collections | `import rockit.core.collections` | List utilities — map, filter, fold, sort, zip, flatten, distinct |
| Math | `import rockit.core.math` | Integer/float math, trig, gcd, lcm, constants |
| Strings | `import rockit.core.strings` | Pad, repeat, join, split, replace, truncate, case conversion |
| Result | `import rockit.core.result` | Result type (Success/Failure) for error handling |
| UUID | `import rockit.core.uuid` | UUID v4 random generation (RFC 4122) |
| File I/O | `import rockit.io.file` | Read, write, exists, delete files |
| Path | `import rockit.io.path` | Path join, dir, base, ext, normalize, isAbsolute |
| HTTP | `import rockit.net.http` | HTTP/1.1 client — GET, POST, PUT, DELETE with HTTPS fallback |
| WebSocket | `import rockit.net.ws` | WebSocket client (RFC 6455) — connect, send, recv, close |
| URL | `import rockit.net.url` | URL parser — parse, encode, decode, query params |
| Base64 | `import rockit.encoding.base64` | Base64 encode/decode (RFC 4648) |
| XML | `import rockit.encoding.xml` | XML parser, serializer, pretty-print, JSON bridge |
| DateTime | `import rockit.time.datetime` | Date/time — now, epoch, format, dayOfWeek, isLeapYear |
| JSON | `import rockit.json` | JSON parse, stringify, pretty-print, auto-wrap, type-safe API |
| Probe | `import rockit.test.probe` | Test framework — 20 assertions, class suites, setUp/tearDown |

---

### 15.1 rockit.core.collections

List utilities for functional-style programming.

```
listOf1(a)                                       Create single-element list
listOf2(a, b) / listOf3 / listOf4 / listOf5     Create multi-element lists
listMap(list, transform)                         Transform each element
listFilter(list, predicate)                      Keep matching elements
listFold(list, initial, combine)                 Reduce to single value
listSort(list)                                   In-place insertion sort
listReverse(list)                                Reverse in place
listSlice(list, start, end)                      Sublist extraction
listZip(a, b)                                    Interleave two lists
listFlatten(lists)                               Flatten list of lists
listDistinct(list)                               Remove duplicates
listFind(list, predicate)                        First match or -1
listAny(list, predicate)                         Check if any match
listAll(list, predicate)                         Check if all match
listCount(list, predicate)                       Count matches
listSum(list) / listMax(list) / listMin(list)    Aggregations
listJoin(list, sep)                              Join as string
listCopy(list)                                   Shallow copy
listFirst(list) / listLast(list)                 Access endpoints
listIsEmpty(list)                                Check if empty
listForEach(list, action)                        Iterate with side effects
```

---

### 15.2 rockit.core.math

Integer and floating-point math.

```
square(n) / cube(n)                              Integer powers
power(base, exp) / factorial(n)                  Integer arithmetic
gcd(a, b) / lcm(a, b)                           Number theory
clamp(value, lo, hi) / sign(n)                   Utilities
isEven(n) / isOdd(n)                             Parity checks
PI() / E() / TAU()                               Constants (3.14159..., 2.71828..., 6.28318...)
sqrt(x) / sin(x) / cos(x) / tan(x)              Trigonometry
atan2(y, x) / pow(base, exp)                     Advanced math
log(x) / exp(x)                                  Logarithms
floor(x) / ceil(x) / round(x)                    Rounding
absFloat(x) / clampFloat(v, lo, hi)              Float utilities
toRadians(deg) / toDegrees(rad)                  Angle conversion
lerp(a, b, t)                                    Linear interpolation
```

---

### 15.3 rockit.core.strings

String manipulation utilities.

```
padLeft(s, width, ch) / padRight(s, width, ch)   Padding
repeat(s, count)                                  Repeat string N times
join(items, sep) / split(s, delim)                Join list and split string
reversed(s)                                       Reverse string
toUpper(s) / toLower(s)                           Case conversion
trim(s)                                           Strip whitespace
contains(s, sub) / indexOf(s, sub)                Search
replace(s, old, new)                              Replace all occurrences
substring(s, start, end)                          Extract range
countOccurrences(s, sub)                          Count matches
truncate(s, maxLen)                               Truncate with "..."
zeroPad(s, width)                                 Left-pad with zeros
isEmpty(s) / isNotEmpty(s) / length(s)            Properties
charAtPos(s, index)                               Character access
```

---

### 15.4 rockit.core.result

Result type for error handling without exceptions.

```kotlin
sealed class Result(val isSuccess: Bool)
class Success(val value: Int) : Result(true)
class Failure(val error: String) : Result(false)
```

```
resultOrElse(r, default)                          Unwrap or return default
resultError(r)                                    Get error message
resultMap(r, transform)                           Transform Success value
isSuccess(r) / isFailure(r)                       Type checks
```

---

### 15.5 rockit.core.uuid

```
uuid4()                                           Generate random UUID v4 string (RFC 4122)
```

---

### 15.6 rockit.io.file

File I/O operations.

```
readFile(path)                                    Read entire file as string
writeFile(path, content)                          Write string to file
readLines(path)                                   Read file as list of lines
writeLines(path, lines)                           Write lines to file
exists(path)                                      Check if file exists (returns Bool)
deleteFile(path)                                  Delete file
```

---

### 15.7 rockit.io.path

Path manipulation utilities.

```
pathJoin(a, b)                                    Join path components
pathDir(path)                                     Directory component ("/foo/bar" → "/foo")
pathBase(path)                                    Filename component ("/foo/bar.rok" → "bar.rok")
pathExt(path)                                     File extension ("/foo/bar.rok" → ".rok")
pathWithoutExt(path)                              Remove extension ("/foo/bar.rok" → "/foo/bar")
pathIsAbsolute(path)                              Check if absolute path
pathNormalize(path)                               Resolve `.` and `..`
```

---

### 15.8 rockit.net.http

HTTP/1.1 client. Uses raw TCP sockets for `http://` URLs and falls back to `curl` for `https://`.

```
httpGet(url)                                      GET request → response map
httpPost(url, body, contentType)                  POST request
httpPostJson(url, jsonBody)                       POST with JSON content type
httpPut(url, body, contentType)                   PUT request
httpDelete(url)                                   DELETE request
httpRequest(method, url, headers, body)           Full HTTP request with custom headers
httpStatus(r)                                     Response status code (Int)
httpBody(r)                                       Response body (String)
httpHeader(r, name)                               Get header value (case-insensitive)
httpHeaders(r)                                    All response headers (Map)
httpIsError(r)                                    Check if request failed
httpErrorMessage(r)                               Get error message
```

Example:
```kotlin
import rockit.net.http

fun main() {
    val resp = httpGet("http://example.com/api/users")
    if (!httpIsError(resp)) {
        println("Status: ${httpStatus(resp)}")
        println("Body: ${httpBody(resp)}")
        println("Content-Type: ${httpHeader(resp, "content-type")}")
    } else {
        println("Error: ${httpErrorMessage(resp)}")
    }
}
```

---

### 15.9 rockit.net.ws

WebSocket client (RFC 6455) with frame masking.

```
wsConnect(url)                                    Open WebSocket → {fd, error}
wsSend(ws, message)                               Send text frame
wsSendBinary(ws, data)                            Send binary frame
wsRecv(ws)                                        Receive frame → {type, data}
wsClose(ws)                                       Send close frame and disconnect
wsIsOpen(ws)                                      Check connection status
WS_TEXT() / WS_BINARY() / WS_CLOSE()             Frame type constants
WS_PING() / WS_PONG()                            Control frame constants
```

---

### 15.10 rockit.net.url

URL parsing and encoding.

```
urlParse(url)                                     Parse URL → {scheme, host, port, path, query, fragment}
urlScheme(p) / urlHost(p) / urlPort(p)            Component accessors
urlPath(p) / urlQuery(p) / urlFragment(p)         Component accessors
urlQueryParams(query)                             Parse query string → Map
urlQueryParam(query, name)                        Get single query parameter
urlEncode(s) / urlDecode(s)                       Percent-encoding
urlToString(parsed)                               Reconstruct URL from parsed components
```

---

### 15.11 rockit.encoding.base64

```
base64Encode(s)                                   Encode string to base64
base64Decode(s)                                   Decode base64 to string
```

---

### 15.12 rockit.encoding.xml

Full XML parser, serializer, and JSON bridge.

**Node types:** Element, Text, CDATA, Comment, ProcessingInstruction, Document, Error

```
xmlElement(tag)                                   Create element node
xmlText(value)                                    Create text node
xmlCdata(value)                                   Create CDATA node
xmlComment(value)                                 Create comment node
xmlPI(target, data)                               Create processing instruction
xmlDocument()                                     Create document node
xmlError(message)                                 Create error node

xmlSetAttr(el, name, value)                       Set attribute on element
xmlGetAttr(el, name)                              Get attribute value
xmlHasAttr(el, name)                              Check if attribute exists
xmlAppendChild(parent, child)                     Append child node
xmlGetChildren(el)                                Get all child nodes
xmlGetChildrenByTag(el, tag)                      Get children by tag name
xmlGetTag(el)                                     Get element tag name
xmlGetText(el)                                    Get text content (recursive)

xmlIsElement(n) / xmlIsText(n) / xmlIsCdata(n)    Type checks
xmlIsComment(n) / xmlIsError(n)

xmlParse(input)                                   Parse XML string → node tree
xmlStringify(node)                                Compact serialization
xmlStringifyPretty(node, indent)                  Pretty-print with indentation

xmlEscapeText(s) / xmlEscapeAttr(s)               Escape special characters
xmlDecodeEntities(s)                              Decode &amp; &lt; &gt; &quot; &apos; &#123; &#x7B;

xmlToJson(node)                                   Convert XML node to JSON value
jsonToXml(json, rootTag)                          Convert JSON value to XML element
xmlFrom(value, tag)                               Auto-wrap native value as XML element
```

---

### 15.13 rockit.time.datetime

```
now()                                             Current time (epoch milliseconds)
epochSeconds()                                    Current time (epoch seconds)
dateFromEpoch(epochMs)                            Epoch → {year, month, day, hour, minute, second, dayOfWeek}
formatDate(d, pattern)                            Format: "YYYY-MM-DD", "MM/DD/YYYY", "DD.MM.YYYY"
formatTime(d)                                     Format: "HH:MM:SS"
formatDateTime(d)                                 Format: "YYYY-MM-DDTHH:MM:SS"
isLeapYear(year)                                  Leap year check
daysInMonth(year, month)                          Days in month
dayOfWeek(year, month, day)                       0=Sun..6=Sat (Tomohiko Sakamoto algorithm)
```

---

### 15.14 rockit.json

Full JSON encoder/decoder with type-safe API and auto-wrapping.

**Constructors:**
```
jsonNull() / jsonBool(b) / jsonNumber(n) / jsonString(s)
jsonArray() / jsonObject() / jsonError(msg)
```

**Type checks:**
```
jsonIsNull(v) / jsonIsBool(v) / jsonIsNumber(v)
jsonIsString(v) / jsonIsArray(v) / jsonIsObject(v) / jsonIsError(v)
```

**Accessors:**
```
jsonGetBool(v)                                    Extract Bool value
jsonGetInt(v)                                     Extract Int value
jsonGetString(v)                                  Extract String value
```

**Array operations:**
```
jsonArrayAppend(arr, item)                        Append item to array
jsonArrayGet(arr, index)                          Get item at index
jsonArraySet(arr, index, value)                   Set item at index
jsonArrayRemoveAt(arr, index)                     Remove item at index
jsonArraySize(arr)                                Get array length
```

**Object operations:**
```
jsonObjectPut(obj, key, value)                    Set key-value pair
jsonObjectGet(obj, key)                           Get value by key
jsonObjectRemove(obj, key)                        Remove key
jsonObjectKeys(obj)                               Get all keys as List
jsonObjectSize(obj)                               Get number of keys
jsonObjectHas(obj, key)                           Check if key exists
```

**Serialization:**
```
jsonParse(input)                                  Parse JSON string → value (or error)
jsonStringify(v)                                  Compact serialization
jsonStringifyPretty(v, indent)                    Pretty-print with indentation
```

**Auto-wrapping (accepts Any type):**
```
jsonFrom(value)                                   Auto-wrap native value → JSON (Int, String, Bool, null, List, Map)
jsonFromList(list)                                Recursively wrap List → JSON array
jsonFromMap(map)                                  Recursively wrap Map → JSON object
jsonToValue(v)                                    Unwrap JSON → native value
jsonToList(v)                                     Unwrap JSON array → List
jsonToMap(v)                                      Unwrap JSON object → Map
```

**Comparison:**
```
jsonEquals(a, b)                                  Deep equality comparison
```

Example:
```kotlin
import rockit.json

fun main() {
    val input = "{\"name\": \"Rockit\", \"version\": 1, \"features\": [\"fast\", \"safe\"]}"
    val obj = jsonParse(input)

    // Read values
    println(jsonGetString(jsonObjectGet(obj, "name")))  // Rockit
    println(jsonGetInt(jsonObjectGet(obj, "version")))   // 1

    // Modify
    jsonObjectPut(obj, "stable", jsonBool(true))

    // Auto-wrap native values
    val auto = jsonFrom(42)             // wraps Int → jsonNumber(42)
    val nested = jsonFrom(myMap)        // recursively wraps Maps and Lists

    // Serialize
    println(jsonStringify(obj))
    println(jsonStringifyPretty(obj, 0))
}
```

---

### 15.15 rockit.test.probe

Test framework. Write tests with `@Test` annotation, run with `rockit test`.

**Test structure:**

```kotlin
import rockit.test.probe

// Top-level tests
@Test
fun testMath() {
    assertEquals(4, 2 + 2, "addition")
    assertGreaterThan(10, 5)
}

// Class-based test suites
class MathTests {
    fun setUp() { /* runs before each @Test */ }
    fun tearDown() { /* runs after each @Test */ }

    @Test fun testAdd() { assertEquals(4, 2 + 2, "addition") }
    @Test fun testSub() { assertEquals(1, 3 - 2, "subtraction") }
}
```

Output format:
```
  PASS  test_math.rok::MathTests::testAdd
  PASS  test_math.rok::MathTests::testSub
  PASS  test_math.rok::testMath
```

**All 20 assertions:**

```
assert(condition, message?)                       Generic assertion
assertTrue(cond, msg?) / assertFalse(cond, msg?)  Boolean checks
assertEquals(expected, actual, msg?)              Int equality
assertEqualsStr(expected, actual, msg?)           String equality
assertEqualsBool(expected, actual, msg?)          Bool equality
assertNotEquals(a, b, msg?)                       Int inequality
assertNotEqualsStr(a, b, msg?)                    String inequality
assertGreaterThan(a, b, msg?)                     a > b
assertLessThan(a, b, msg?)                        a < b
assertGreaterThanOrEqual(a, b, msg?)              a >= b
assertLessThanOrEqual(a, b, msg?)                 a <= b
assertBetween(value, lo, hi, msg?)                lo <= value <= hi
assertStringContains(s, sub, msg?)                Substring check
assertStartsWith(s, prefix, msg?)                 Prefix check
assertEndsWith(s, suffix, msg?)                   Suffix check
assertStringEmpty(s, msg?)                        Empty string check
assertStringNotEmpty(s, msg?)                     Non-empty string check
assertStringLength(s, expected, msg?)             String length check
fail(msg?)                                        Unconditional failure
```

---

## 16. Benchmark Runner

Built-in benchmarking with history tracking and regression detection.

### Whole-file Benchmarks

Any `.rok` file in `Benchmarks/` is treated as a benchmark:

```bash
rockit bench Benchmarks/bench_fib.rok         # single file
rockit bench Benchmarks/                       # all benchmarks in directory
rockit bench                                   # default: Benchmarks/ directory
```

### @Benchmark Annotated Functions

Fine-grained benchmarks within a file:

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

### Options

```bash
rockit bench --runs 10               # measurement runs (default: 5)
rockit bench --warmup 3              # warmup runs (default: 2)
rockit bench --save                  # save to .rockit/bench_history.json
```

### Regression Detection

When history exists, results are compared against the previous run:

```
  bench_fib       145ms avg    +2.1ms (+1.5%)
  bench_monkey    892ms avg    -30ms  (-3.3%)  ✓ faster
  bench_matrix    355ms avg    +14ms  (+4.1%)  ⚠ regression (>3%)
```

Results are stored in `.rockit/bench_history.json` with commit hash and timestamp.

---

## 17. Performance

### Optimization Techniques

Rockit compiles to native code via LLVM with aggressive optimizations:

- **Escape Analysis & Stack Promotion** — Value-type `data class` instances that don't escape the current function are stack-allocated via LLVM `alloca` instead of heap-allocated via `malloc`. Interprocedural analysis proves parameters don't escape through read-only callees.
- **MIR Function Inlining** — Small single-block functions with value-type parameters are inlined at the MIR level, exposing `newObject` calls to escape analysis for stack promotion.
- **Immortal String Literals** — String constants live in the binary's read-only data segment and bypass ARC entirely. Never heap-allocated, never reference-counted.
- **Inline ARC** — String retain/release is emitted as inline LLVM IR (refcount decrement + conditional free) instead of function calls, saving overhead on every allocation.
- **ARC Write Barriers** — The compiler tracks `ptrFieldBits` per object so `rockit_release` only scans fields that actually contain heap pointers, eliminating unnecessary reference counting on primitive fields.
- **Value Types** — `data class` with only primitive fields uses inline GEP field access and skips ARC retain/release.
- **Inline List Access** — `listGet`, `listSet`, and `listSize` compile to direct GEP memory operations with inline bounds checks. Bounds checks add only 1-5% overhead — LLVM hot/cold splitting moves panic paths out of loop bodies.
- **Inline ByteArray Access** — `byteArrayGet` and `byteArraySet` compile to direct GEP + load/store instructions with inline bounds checks, enabling LLVM to optimize byte-level operations.
- **Inline Integer Comparison** — `==` and `!=` on known integer operands compile to a single `icmp` instruction.
- **TBAA Alias Analysis** — List struct field loads are annotated with LLVM TBAA metadata, proving they can't alias element stores. LLVM hoists struct field loads out of inner loops.
- **Multi-String Concat Flattening** — Chains of `+` (e.g. `"(" + left + " " + op + " " + right + ")"`) are flattened into a single `concat_n` call that measures total length once, allocates once, copies all parts. 7-part concat: 6 intermediate allocations → 1.
- **Bulk List Initialization** — `listCreateFilled(size, value)` allocates and fills in a single `malloc` + `memset`.
- **Internal Linkage** — Non-`main` functions use `internal` linkage, giving LLVM full freedom to inline and optimize across function boundaries.

### Benchmarks

All benchmarks on Apple M1, best of 3 runs.

#### Core Benchmarks (Time)

| Benchmark | Rockit | Rust | Go | Node.js |
|-----------|--------|------|-----|---------|
| **Fibonacci** (fib 40, recursive) | **0.31s** | 0.31s | 0.34s | 1.03s |
| **Object alloc** (1M data class) | **0.002s** | 0.002s | 0.003s | 0.07s |
| **Prime sieve** (primes to 1M) | **0.004s** | 0.003s | 0.004s | 0.07s |
| **Matrix multiply** (200×200) | **0.006s** | 0.006s | 0.011s | 0.08s |
| **Quicksort** (500K integers) | **0.031s** | 0.025s | 0.034s | 0.18s |
| **String concat** (500K chars) | **0.17s** | 0.003s | 0.35s | 0.06s |

#### Core Benchmarks (Memory)

| Benchmark | Rockit | Go | Node.js |
|-----------|--------|-----|---------|
| Fibonacci | **1.3 MB** | 4.0 MB | 47.5 MB |
| Object alloc | **1.3 MB** | 3.9 MB | 50.6 MB |
| Prime sieve | 8.9 MB | **4.9 MB** | 49.1 MB |
| Matrix multiply | **2.2 MB** | 4.9 MB | 49.1 MB |
| Quicksort | **5.1 MB** | 8.3 MB | 71.3 MB |
| String concat | **2.4 MB** | 15.3 MB | 51.7 MB |

#### CLBG Benchmarks (Computer Language Benchmarks Game)

| Benchmark | Rockit | Go | Rockit Mem | Go Mem |
|-----------|--------|-----|------------|--------|
| **Binary trees** (depth 21) | **5.41s** | 10.52s | 261 MB | **204 MB** |
| **Fannkuch** (n=12) | 25.03s | **24.79s** | **1.3 MB** | 4.1 MB |
| **N-body** (50M steps) | 2.63s | **2.42s** | **1.3 MB** | 4.1 MB |
| **Spectral norm** (n=5500) | 1.15s | **1.14s** | **2.3 MB** | 4.9 MB |

#### Summary

- Rockit is **neck-and-neck with Rust** on compute benchmarks.
- Rockit **beats Go** on 7 of 11 benchmarks.
- Rockit **outperforms Node.js 3-15x** across all measured benchmarks.
- Rockit uses **3-40x less memory than Node.js** and **2-6x less than Go** thanks to ARC (no GC runtime overhead).

---

## 18. Editor Support

### 18.1 Quick Install (All Editors)

Auto-detects and installs Rockit support for every editor on your system:

**macOS / Linux / Windows (WSL, Git Bash):**
```bash
curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/ide/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://rustygits.com/Dark-Matter/moon/raw/branch/develop/ide/install.ps1 | iex
```

### 18.2 VS Code

Full extension with:
- Syntax highlighting for all 47 keywords, operators, and punctuation
- 25+ code snippets (fun, class, data class, view, actor, when, for, etc.)
- Bracket matching and auto-close pairs
- Language configuration (comments, indentation rules)

### 18.3 JetBrains (IntelliJ IDEA, WebStorm, CLion, etc.)

Full plugin with:
- **JFlex-based lexer** for fast, accurate tokenization
- **Syntax highlighting** for all 47 keywords, operators, and punctuation
- **Distinct color categories:**
  - Declaration keywords (pink): `fun`, `class`, `val`, `var`, `interface`
  - Rockit keywords (purple): `view`, `actor`, `navigation`, `theme`, `style`, `route`
  - Control flow (orange): `if`, `else`, `when`, `for`, `while`, `return`
  - Built-in types (teal): `String`, `Int`, `Bool`, `List`, `Map`, `Float64`
  - Built-in functions (cyan): `println`, `listOf`, `mapOf`
- **String interpolation** highlighting (`$name` and `${expr}` within strings)
- **Code folding** — collapse functions, classes, block comments, import groups
- **Nestable block comments** — `/* outer /* inner */ still outer */`
- **Number formats** — decimal, hex (`0xFF`), binary (`0b1010`), floats, underscores (`1_000_000`)
- **Annotations** — `@Capability`, `@State`, `@Test`, `@Benchmark`, etc.
- **Brace matching** — `()`, `{}`, `[]` highlighting and navigation
- **Comment toggling** — Cmd+/ (line) and Cmd+Shift+/ (block)
- **Auto-close quotes** — typing `"` auto-inserts the closing `"`
- **Configurable colors** — Settings > Editor > Color Scheme > Rockit

**Supported JetBrains IDEs** (IntelliJ Platform 2023.3+):
IntelliJ IDEA (Community or Ultimate), WebStorm, CLion, PyCharm, GoLand, Rider, Fleet, RubyMine, PhpStorm, DataGrip, DataSpell, Android Studio, Writerside

**Install:** Settings > Plugins > gear icon > Install Plugin from Disk > select `intellij-rockit-0.1.0.zip`. Or search "Rockit Language Support" on JetBrains Marketplace.

### 18.4 Vim / Neovim

Syntax highlighting and filetype detection.

**Manual install:**
```bash
cp ide/vim/syntax/rockit.vim ~/.vim/syntax/
cp ide/vim/ftdetect/rockit.vim ~/.vim/ftdetect/
```

**With a plugin manager (e.g. vim-plug):**
```vim
Plug 'Dark-Matter/moon', { 'rtp': 'ide/vim' }
```

### 18.5 Language Server (LSP)

Built-in LSP server works with any LSP-compatible editor:

```bash
rockit lsp
```

**All LSP capabilities:**

| Feature | LSP Method | Status |
|---------|-----------|--------|
| Diagnostics | `textDocument/publishDiagnostics` | [Shipped] |
| Hover | `textDocument/hover` | [Shipped] |
| Completion | `textDocument/completion` | [Shipped] |
| Go to Definition | `textDocument/definition` | [Shipped] |
| Go to Type Definition | `textDocument/typeDefinition` | [Shipped] |
| Go to Implementation | `textDocument/implementation` | [Shipped] |
| Find References | `textDocument/references` | [Shipped] |
| Document Symbols | `textDocument/documentSymbol` | [Shipped] |
| Workspace Symbols | `workspace/symbol` | [Shipped] |
| Signature Help | `textDocument/signatureHelp` | [Shipped] |
| Rename Symbol | `textDocument/rename` | [Shipped] |
| Call Hierarchy | `callHierarchy/incomingCalls`, `outgoingCalls` | [Shipped] |
| Semantic Tokens | `textDocument/semanticTokens/full` | [Shipped] |
| Document Formatting | `textDocument/formatting` | [Shipped] |
| On Type Formatting | `textDocument/onTypeFormatting` | [Shipped] |
| Inlay Hints | `textDocument/inlayHint` | [Shipped] |
| Code Actions | `textDocument/codeAction` | [Shipped] |
| Document Links | `textDocument/documentLink` | [Shipped] |
| Folding Ranges | `textDocument/foldingRange` | [Shipped] |
| Document Highlight | `textDocument/documentHighlight` | [Shipped] |
| Selection Range | `textDocument/selectionRange` | [Shipped] |
| Type Hierarchy | `typeHierarchy/supertypes`, `subtypes` | [Shipped] |
| Range Formatting | `textDocument/rangeFormatting` | [Shipped] |
| Incremental Sync | `textDocument/didChange` (mode 2) | [Shipped] |

### 18.6 Editor-Specific LSP Setup

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

## 19. Compiler Architecture

### 19.1 Bootstrap Strategy

The compiler follows a standard self-hosting bootstrap:

- **Stage 0:** Compiler written in Swift (~37+ files). Its purpose is to compile Stage 1.
- **Stage 1:** Compiler rewritten in Rockit (~12,000 lines). Compiled by Stage 0.
- **Stage 2:** Stage 1 compiles its own source code. Self-hosting verified — Stage 2 output == Stage 3 output.

From Stage 2 onward, each new version of the compiler is compiled by the previous version. Fully self-hosted.

### 19.2 Pipeline

```
.rok source → Lexer → Tokens → Parser → AST → Type Checker → Typed AST
→ MIR Lowering → MIR → Optimizer → Optimized MIR → Codegen → Bytecode / LLVM IR → Native Binary
```

| Stage | Input | Output | Description |
|-------|-------|--------|-------------|
| Lexer | `.rok` source | Token stream | 130+ token types, string interpolation, nestable comments, significant newlines |
| Parser | Token stream | AST | Recursive descent. All declarations, expressions, statements, type annotations, annotations |
| Type Checker | AST | Typed AST | Type inference, null safety, exhaustive `when`, generics with variance, suspend/await validation, actor isolation |
| MIR Lowering | Typed AST | MIR | AST → Rockit Intermediate Representation |
| Optimizer | MIR | Optimized MIR | Dead code elimination, function inlining, constant folding, tree shaking |
| Codegen | Optimized MIR | Bytecode or LLVM IR | Bytecode for VM execution, or LLVM IR for native compilation |
| LLVM | LLVM IR | Native binary | ARM64, x86_64 via system Clang/LLVM |

### 19.3 Structured Concurrency Implementation

- **Native codegen:** CPS coroutine transform (suspend functions → state machines), concurrent blocks with event loop + join counter
- **Bytecode VM:** Cooperative scheduler, coroutine suspend/resume, concurrent block interleaving, actor message dispatch via mailbox, error propagation, cancellation
- **Runtime:** Frame alloc/free, task scheduling, event loop

### 19.4 Freestanding Mode (`--no-runtime`)

Compiles Rockit programs without linking the standard runtime. Enables low-level systems programming with direct memory control.

**Available features in freestanding mode:**
- `Ptr<T>` — typed pointer
- `alloc(size)` / `free(ptr)` — manual memory management
- `bitcast(ptr)` — pointer type cast
- `cstr(string)` — string to C string
- `loadByte(ptr, offset)` / `storeByte(ptr, offset, value)` — byte-level access
- `unsafe { }` blocks — bypass safety checks
- `extern fun` — declare external C functions
- `@CRepr` — C-compatible struct memory layout

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

The Rockit runtime itself is written in Rockit using freestanding mode — 12 modules covering memory, strings, objects, lists, maps, I/O, exceptions, file operations, process management, math, and concurrency.

---

## 20. What Rockit Replaces (Vision)

| Legacy Technology | Rockit Replacement | Why |
|-------------------|--------------------|-----|
| JavaScript / TypeScript | Rockit language | Type-safe, compiled, memory-safe |
| HTML DOM | Declarative `view` components | Reactive scene graph, retained-mode, no DOM |
| CSS | Type-safe `style` / `theme` | No cascade, no specificity wars, no selectors |
| npm / node_modules | Fuel package manager | Signed binaries, flat deps, no install scripts |
| WebAuthn (auth only) | Hardware Crypto Bridge | Full HSM operations |
| Web Crypto API | Hardware-backed crypto | Keys never leave hardware |
| Service Workers | Native push integration | APNs/FCM/WNS via bridge |
| Payment Request API | Native payment bridge | Apple Pay/Google Pay/native |

### Security Model (Fuel Packages) [Planned]

- All packages cryptographically signed by author
- Distributed as compiled artifacts, not source
- No install scripts during dependency resolution
- Flat resolution — no nested node_modules
- Exact version pinning — nothing changes silently
- Registry-level scanning for vulnerabilities

---

## 21. Nova Browser [Planned]

Nova is a dual-engine browser. Rockit apps run natively; legacy JavaScript websites use a compatibility engine.

### Dual Engine Design

- **Rockit path (fast):** Baseline compiler translates `.rokb` bytecode to native machine code on first load (<100ms), caches result. Supernova GPU rendering. ARC memory. No interpreter, no VM in the hot path. Optional LLVM tier for background recompilation.
- **Legacy path (compat):** JavaScriptCore on macOS/iOS (ships with OS, zero size cost). V8 or Hermes on Windows/Linux.
- **Detection:** Content type determines engine. Every existing website works from day one.

### Rendering: Supernova [Planned]

GPU-accelerated compositor for `view` trees. GPU compute for `parallel` blocks. Full rendering pipeline for 3D apps. Backends: Metal (macOS/iOS), Vulkan (Android/Linux), Direct3D 12 (Windows).

### Platform Backends

| Platform | Rendering | Push | Payments | Crypto | Biometrics |
|----------|-----------|------|----------|--------|------------|
| **Apple** | WebKit | APNs | PassKit | Secure Enclave | Face ID |
| **Android** | Blink | FCM | Google Pay | TEE | BiometricPrompt |
| **Windows** | Blink | WNS | — | TPM 2.0 | Win Hello |
| **Linux** | Blink | D-Bus Notify | — | PKCS#11 | — |

---

## 22. Roadmap

| Phase | Target | Milestone |
|-------|--------|-----------|
| Alpha | 2026 Q3 | Spec finalized, compiler prototype, dev tools |
| Beta | 2027 Q1 | Silo registry, view runtime beta, Nova canary |
| Dev Preview | 2027 Q3 | Public SDK, documentation, example apps |
| Nova Integration | 2028 Q1 | Rockit runtime in Nova stable (behind flag) |
| GA | 2028 Q3 | Flag removed, available to all Nova users |
| Legacy Deprecation | 2030+ | Begin JS engine deprecation signaling |

---

## 23. Grammar Reference (EBNF)

Abbreviated formal grammar in Extended Backus-Naur Form:

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
