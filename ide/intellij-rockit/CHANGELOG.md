# Changelog

## [Unreleased]

### Added
- Class-level play button for test suite classes containing `@Test` methods
  - Click to run all tests in the class via `rockit test --filter <ClassName>`
  - Aggregated state: green (all pass), red (any fail), yellow (running)
- Per-assertion pass/fail gutter icons after running tests with `--detailed`
- Full syntax highlighting for all 47 Rockit keywords
- Distinct color categories: declaration, control flow, Rockit-specific, and literal keywords
- Built-in type and function highlighting
- String interpolation highlighting ($name and ${expr})
- Nestable block comment support
- Brace, bracket, and parenthesis matching
- Line and block comment toggling
- Auto-close quotes
- Annotation highlighting
- Number literal highlighting (decimal, hex, binary, float)
- Xcode/Swift-inspired dark theme colors
- Configurable color scheme (Settings > Editor > Color Scheme > Rockit)
