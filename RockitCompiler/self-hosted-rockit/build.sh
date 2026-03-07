#!/bin/bash
# Build the Stage 1 compiler by concatenating modules.
# Each module is a .rok file. The last module provides the main() function.
# Usage: ./build.sh

STAGE1_DIR="$(cd "$(dirname "$0")" && pwd)"

# Strip the main() function from a file (everything from "fun main()" to EOF)
strip_main() {
    awk '/^fun main\(\)/ { found=1 } !found { print }' "$1"
}

# Default: build lexer + parser + typechecker + optimizer + codegen into a combined file
OUTPUT="${STAGE1_DIR}/command.rok"

# Lexer (without main)
strip_main "${STAGE1_DIR}/lexer.rok" > "$OUTPUT"

# Parser (without main)
strip_main "${STAGE1_DIR}/parser.rok" >> "$OUTPUT"

# Type checker (without main)
strip_main "${STAGE1_DIR}/typechecker.rok" >> "$OUTPUT"

# Optimizer (without main)
strip_main "${STAGE1_DIR}/optimizer.rok" >> "$OUTPUT"

# LLVM IR generator (without main)
strip_main "${STAGE1_DIR}/llvmgen.rok" >> "$OUTPUT"

# Update system (without main)
if [ -f "${STAGE1_DIR}/update.rok" ]; then
    strip_main "${STAGE1_DIR}/update.rok" >> "$OUTPUT"
fi

# Code generator (with main)
cat "${STAGE1_DIR}/codegen.rok" >> "$OUTPUT"

# ---------------------------------------------------------------------------
# Inject build identity
# ---------------------------------------------------------------------------
VERSION="$(cat "${STAGE1_DIR}/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "0.1.0")"
GIT_HASH="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
BUILD_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"

# Use portable sed (macOS and Linux compatible)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/__ROCKIT_VERSION__/$VERSION/" "$OUTPUT"
    sed -i '' "s/__ROCKIT_GIT_HASH__/$GIT_HASH/" "$OUTPUT"
    sed -i '' "s/__ROCKIT_BUILD_TIMESTAMP__/$BUILD_TS/" "$OUTPUT"
    sed -i '' "s/__ROCKIT_BUILD_PLATFORM__/$PLATFORM/" "$OUTPUT"
else
    sed -i "s/__ROCKIT_VERSION__/$VERSION/" "$OUTPUT"
    sed -i "s/__ROCKIT_GIT_HASH__/$GIT_HASH/" "$OUTPUT"
    sed -i "s/__ROCKIT_BUILD_TIMESTAMP__/$BUILD_TS/" "$OUTPUT"
    sed -i "s/__ROCKIT_BUILD_PLATFORM__/$PLATFORM/" "$OUTPUT"
fi

# Source hash (computed after other substitutions)
SOURCE_HASH="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/__ROCKIT_SOURCE_HASH__/sha256:$SOURCE_HASH/" "$OUTPUT"
else
    sed -i "s/__ROCKIT_SOURCE_HASH__/sha256:$SOURCE_HASH/" "$OUTPUT"
fi

echo "Built: $OUTPUT"
echo "  version:   $VERSION"
echo "  commit:    $GIT_HASH"
echo "  source:    sha256:$SOURCE_HASH"
echo "  built:     $BUILD_TS"
echo "  platform:  $PLATFORM"
