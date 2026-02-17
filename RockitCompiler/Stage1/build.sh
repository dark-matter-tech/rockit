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

# Code generator (with main)
cat "${STAGE1_DIR}/codegen.rok" >> "$OUTPUT"

echo "Built: $OUTPUT"
