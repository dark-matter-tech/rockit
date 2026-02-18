# Rockit Language Support for JetBrains IDEs

<!-- Plugin description -->
Language support for the **Rockit** programming language (`.rok` files) in JetBrains IDEs.

### Features
- Full syntax highlighting for all 47 keywords and operators
- Distinct colors for declaration, control flow, and Rockit-specific keywords (view, actor, suspend, etc.)
- Built-in type and function recognition (String, Int, println, listOf, etc.)
- String interpolation highlighting (`$name` and `${expr}`)
- Code folding for brace blocks, comments, and import groups
- Nestable block comment support
- Brace, bracket, and parenthesis matching
- Line and block comment toggling (Cmd+/ / Ctrl+/)
- Auto-close quotes
- Annotation highlighting (@Capability, @State, etc.)
- Xcode/Swift-inspired color palette with light and dark theme support
- Fully configurable via Settings > Editor > Color Scheme > Rockit
<!-- Plugin description end -->

---

## Install

### One-liner (recommended)

Installs Rockit support to all detected editors (VS Code, Vim, Neovim, JetBrains, Visual Studio):

**macOS / Linux / Windows (WSL, Git Bash):**
```bash
curl -fsSL https://raw.githubusercontent.com/Dark-Matter/moon/master/ide/install.sh | bash
```

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/Dark-Matter/moon/master/ide/install.ps1 | iex
```

### From disk

1. Build the plugin (or download the zip from releases):
   ```bash
   cd ide/intellij-rockit
   ./gradlew buildPlugin
   ```
2. In IntelliJ: **Settings > Plugins > gear icon > Install Plugin from Disk...**
3. Select `build/distributions/intellij-rockit-0.1.0.zip`
4. Restart the IDE

### From JetBrains Marketplace

Search for "Rockit Language Support" in **Settings > Plugins > Marketplace** (once approved).

---

## Supported IDEs

Any JetBrains IDE based on IntelliJ Platform 2023.3+:
- IntelliJ IDEA (Community or Ultimate)
- WebStorm
- CLion
- PyCharm
- GoLand
- Rider

---

## Syntax Highlighting

The plugin provides distinct color categories:

| Category | Examples | Dark theme | Light theme |
|----------|----------|------------|-------------|
| Declaration keywords | `fun`, `val`, `class`, `import` | Pink, bold | Blue, bold |
| Control flow | `if`, `else`, `return`, `for` | Pink, bold | Blue, bold |
| Rockit keywords | `view`, `actor`, `suspend`, `async` | Purple, bold | Purple, bold |
| Literal keywords | `true`, `false`, `null` | Pink, bold | Blue, bold |
| Built-in types | `String`, `Int`, `Bool`, `List` | Teal | Dark teal |
| Built-in functions | `println`, `listOf`, `mapOf` | Teal, italic | Dark teal, italic |
| Strings | `"hello"`, `"""multiline"""` | Red/salmon | Green |
| String interpolation | `$name`, `${expr}` | Blue, bold | Blue, bold |
| Escape sequences | `\n`, `\t`, `\\` | Gold, bold | Blue, bold |
| Numbers | `42`, `0xFF`, `3.14` | Yellow/gold | Blue |
| Comments | `//`, `/* */` | Gray, italic | Gray, italic |
| Annotations | `@Capability`, `@State` | Orange | Yellow-brown |

All colors are customizable via **Settings > Editor > Color Scheme > Rockit**.

---

## Development

### Prerequisites

- JDK 17+
- Gradle 8.13+ (wrapper included)

### Build

```bash
./gradlew buildPlugin
```

### Run in sandbox

```bash
./gradlew runIde
```

This launches a sandboxed IntelliJ instance with the plugin loaded for testing.

### Regenerate lexer

The JFlex lexer is regenerated automatically during build from `src/main/jflex/Rockit.flex`.

---

## License

Apache 2.0. Copyright 2026 Dark Matter Tech.
