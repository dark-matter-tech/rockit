# 🌙 Moon

**A type-safe, compiled, memory-safe programming language designed to replace JavaScript and the DOM.**

> Codename: Mars | Status: Draft Specification | Confidential

---

## What is Moon?

Moon is a ground-up replacement for the web's execution model. It eliminates JavaScript, the DOM, and CSS, replacing them with a compiled language, a declarative UI scene graph, and a platform-aware runtime that bridges to native capabilities.

Moon isn't an incremental improvement. It's the language the web would have if we built it today.

```
view HelloWorld() {
    @State var name = ""

    Column(spacing = 16.dp, padding = 24.dp) {
        Text("Hello, ${name.ifEmpty { "Moon" }}!")
            .font(.display)

        TextField(value = name, onChanged = { name = it })
            .placeholder("Enter your name")

        Button("Greet") {
            Platform.notifications.send(
                title = "Hello!",
                body = "Welcome to Moon, $name"
            )
        }
        .style(.primary)
    }
}
```

No HTML. No CSS. No JavaScript. No DOM. Just code.

---

## Why Moon?

JavaScript was built in 10 days. The DOM is a document model tortured into an application platform. CSS specificity rules have caused more developer suffering than any technology in history. npm downloads 400MB of `node_modules` to center a div.

Moon fixes all of it.

| Problem | Legacy Web | Moon |
|---|---|---|
| Type safety | Runtime errors everywhere | Every type known at compile time |
| Memory | GC pauses cause UI jank | ARC — deterministic, no pauses |
| UI model | Imperative DOM mutation | Declarative reactive scene graph |
| Styling | CSS cascade + specificity | Type-safe scoped properties |
| Packages | npm supply chain attacks | Signed binaries, no install scripts |
| Payments | 3 different browser APIs | One call, runtime resolves native |
| Push notifications | Different per browser | One API — APNs, FCM, WNS |
| Security | Software-only Web Crypto | Hardware HSM bridge, keys never exposed |
| Null safety | `undefined is not a function` | Nullable types enforced at compile time |

---

## Core Design Principles

**Declare intent, not mechanics.** Write what you want. The runtime figures out how, based on the platform.

**One codebase, native everywhere.** Moon runs on WebKit (Apple) and Blink (everything else). Each platform gets its best native experience — not lowest common denominator.

**Fail at compile time, not runtime.** If it compiles, it works. The type system, null safety, and exhaustive pattern matching catch errors before deployment.

**Security is not optional.** Hardware-backed crypto, signed packages, capability-based permissions, and zero-trust networking are built in — not bolted on.

**Performance is a feature.** ARC memory management and AOT compilation ensure consistent 60/120fps without GC pauses.

---

## Language at a Glance

### Kotlin-Inspired Syntax
```
data class User(
    val id: String,
    val name: String,
    val email: String,
    val role: Role = Role.Viewer
)

fun greet(user: User): String = "Hello, ${user.name}!"

val admins = users.filter { it.role == Role.Admin }
                  .sortedBy { it.name }
```

### Null Safety
```
val name: String = "Moon"       // cannot be null
val alias: String? = null       // explicitly nullable
val len = alias?.length ?: 0    // safe call + elvis operator
```

### Sealed Classes + Exhaustive Matching
```
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

val output = when (result) {
    is Result.Success -> render(result.data)
    is Result.Error -> showError(result.message)
    Result.Loading -> showSpinner()
    // No default needed — compiler enforces exhaustiveness
}
```

### Structured Concurrency
```
suspend fun loadDashboard() {
    val (user, orders, alerts) = concurrent {
        val user = async { fetchUser(userId) }
        val orders = async { fetchOrders(userId) }
        val alerts = async { fetchAlerts(userId) }
        Triple(user.await(), orders.await(), alerts.await())
    }
    render(Dashboard(user, orders, alerts))
}
```

### Actors for Thread Safety
```
actor ShoppingCart {
    private var items: MutableList<CartItem> = mutableListOf()

    fun add(item: CartItem) { items.add(item) }
    fun total(): Float64 = items.sumOf { it.price * it.quantity }
}
```

---

## MoonView — The UI Framework

MoonView replaces HTML, CSS, and the DOM with a declarative, reactive scene graph. If you've used SwiftUI or Jetpack Compose, you already know how to think in MoonView.

### Declarative Components
```
view ProductCard(product: Product) {
    Column(spacing = 12.dp, padding = 16.dp) {
        Image(product.thumbnailUrl)
            .size(200.dp, 200.dp)
            .cornerRadius(8.dp)

        Text(product.name)
            .font(.headline)

        Text("$${product.price}")
            .font(.body)
            .color(.secondary)

        Button("Add to Cart") { cart.add(product) }
            .style(.primary)
            .fullWidth()
    }
}
```

### Reactive State
```
view SearchPage() {
    @State var query = ""
    @State var results: List<Product> = emptyList()

    Column {
        TextField(value = query, onChanged = { query = it })
        
        for (product in results) {
            ProductCard(product)
        }
    }
    .onAppear { results = api.search(query) }
}
```

### Declarative Navigation
```
navigation App {
    route("/") { HomePage() }
    route("/products/{id}") { params ->
        ProductDetail(productId = params["id"])
    }
    route("/cart") { CartPage() }
    route("/checkout") { CheckoutFlow() }
}
```

### Type-Safe Styling (No CSS)
```
val cardStyle = Style {
    background(.surface)
    cornerRadius(12.dp)
    shadow(elevation = 4.dp, color = .black.opacity(0.1))
    padding(16.dp)
}

theme AppTheme {
    colors {
        primary = Color(0x5B21B6)
        surface = Color(0xFFFFFF)
    }
    typography {
        headline = Font("Inter", size = 24.sp, weight = .semibold)
    }
}
```

---

## Platform Capability API

Moon's runtime detects the underlying platform and bridges to native capabilities. Developers declare intent — the runtime resolves implementation.

### Payments
```
@Capability(requires = Capability.Payments)
suspend fun checkout(cart: Cart): PaymentResult {
    // Apple → Apple Pay | Android → Native Pay | Fallback → Stripe
    return Platform.payments.request(
        Payment(amount = cart.total, currency = Currency.USD)
    )
}
```

### Push Notifications
```
@Capability(requires = Capability.Notifications)
suspend fun registerPush() {
    // Apple → APNs | Android → FCM | Windows → WNS
    val token = Platform.notifications.register()
    api.registerDevice(token)
}
```

### Biometrics
```
@Capability(requires = Capability.Biometrics)
suspend fun authenticate(): AuthResult {
    // Apple → Face ID / Touch ID | Android → BiometricPrompt | Windows → Hello
    return Platform.biometrics.authenticate(reason = "Confirm your identity")
}
```

---

## Hardware Security Bridge

Moon treats hardware security as a first-class citizen. Orion discovers HSMs, secure enclaves, and hardware tokens, and provides a unified cryptographic API. **Private keys never leave the hardware.**

```
@Capability(requires = Capability.HardwareCrypto)
suspend fun signDocument(document: ByteArray): Signature {
    val key = Platform.crypto.getKey(
        id = "signing-key",
        type = KeyType.Ed25519,
        requireHardware = true
    )
    return key.sign(document)
}
```

### Supported Hardware
- YubiKey / Titan (FIDO2, USB/NFC)
- Apple Secure Enclave
- TPM 2.0
- Ledger / Trezor (BLE/USB)
- Smart cards (PKCS#11)
- Custom USB/BLE HSMs

### Capability Manifest
```yaml
crypto:
  operations: [sign, verify, encrypt, decrypt, keyExchange]
  key_types: [ed25519, x25519, ecdsa-p256]
  requires_hardware: true
  fallback: none    # hardware or nothing
  attestation: required
```

---

## Aurora — Package Manager

Aurora replaces npm, webpack, babel, eslint, and all associated configuration. One tool. One manifest. No `node_modules`.

### Commands
```bash
aurora init my-app           # scaffold new project
aurora add moon-http         # add dependency (exact version pinned)
aurora dev                   # dev server + hot reload
aurora build --release       # AOT compile for production
aurora test                  # run test suite
aurora publish --sign        # publish (requires signing key)
aurora audit --deep          # security audit
```

### Manifest
```yaml
# aurora.manifest
name: my-app
version: 1.0.0
target: web
moon: 1.0

platform_capabilities:
  - payments
  - notifications
  - crypto:
      requires_hardware: true

dependencies:
  moon-ui: 2.1.0
  moon-http: 1.4.0
  moon-json: 3.0.0
```

### Security Model
- All packages are **cryptographically signed** by the author
- Packages are distributed as **compiled artifacts**, not source code
- **No install scripts** execute during dependency resolution
- **Flat dependency resolution** — no nested `node_modules` hell
- **Exact version pinning** — nothing changes under you silently
- **Registry-level scanning** for vulnerabilities and malicious code

---

## Interoperability

Moon is a polyglot compilation target. Write in Moon directly, or use a supported source language.

| Language | Tier | Path |
|---|---|---|
| Moon | Primary | Moon → MIR → Bytecode |
| Kotlin | Tier 1 | Kotlin → KIR → MIR → Bytecode |
| Swift | Tier 1 | Swift → SIL → MIR → Bytecode |
| Rust | Tier 2 | Rust → LLVM IR → MIR → Bytecode |
| TypeScript | Migration | TS → AST → MIR (limited) |

### MIR (Moon Intermediate Representation)
MIR is the stable contract. If any upstream language introduces breaking changes, compiled MIR packages continue to function. Developers who need maximum stability can write MIR directly.

---

## Compilation Pipeline

### Development
```
aurora dev
→ Incremental compilation (< 50ms)
→ Hot reload (no page refresh)
→ Real-time type checking
→ http://localhost:3000
```

### Production
```
aurora build --release
→ Full type check + null safety verification
→ Capability validation
→ MIR optimization + tree shaking
→ AOT bytecode generation
→ Output: dist/app.moonpkg
```

---

## Memory Model

Moon uses **Automatic Reference Counting (ARC)** with a lightweight cycle detector.

- **Deterministic deallocation** — no GC pauses, smooth 60/120fps rendering
- **`weak` and `unowned` references** to break cycles
- **Compile-time cycle analysis** — objects proven cycle-free skip the detector entirely
- **Background cycle detector** runs incrementally on a low-priority thread for edge cases

---

## Orion Runtime Architecture

```
┌──────────────────────────────────┐
│      Moon Application Code       │
├──────────────────────────────────┤
│      Universal Capability API    │
│   (payments, push, crypto, etc)  │
├──────────────────────────────────┤
│      Platform Detection &        │
│      Native Bridge Router        │
├────────┬─────────┬───────────────┤
│ Apple  │ Dark    │   Microsoft   │
│ WebKit │ Blink   │   Blink       │
│ APNs   │ FCM     │   WNS         │
│ PassKit│ GPay    │   Win Hello   │
│ Sec.Enc│ Android │   TPM         │
└────────┴─────────┴───────────────┘
```

---

## Roadmap

| Phase | Target | Milestone |
|---|---|---|
| Alpha | 2026 Q3 | Language spec finalized, compiler prototype |
| Beta | 2027 Q1 | Aurora registry, MoonView beta, Orion canary builds |
| Dev Preview | 2027 Q3 | Public SDK, docs, example apps |
| Orion Integration | 2028 Q1 | Moon runtime ships in Orion stable (behind flag) |
| GA | 2028 Q3 | Flag removed, available to all Orion users |
| Legacy Deprecation | 2030+ | Begin JS engine deprecation signaling |

---

## Project Structure

```
my-app/
  aurora.manifest
  aurora.lock
  src/
    main.moon
    views/
    models/
    services/
  tests/
  assets/
```

---

## Migration

```bash
# Convert an existing TypeScript project
aurora migrate --from typescript --source ./src
```

Orion ships with a dual-runtime engine — legacy HTML/CSS/JS sites continue working unchanged while new applications target the Moon runtime. Gradual migration, not a cliff.

---

## Contributing

This project is in early specification phase. Contact the Dark Matter Tech team for access.

## License

Proprietary. Dark Matter Tech Confidential.

---

<p align="center">
  <strong>Moon</strong> · Codename Mars · The language the web deserves.
</p>
