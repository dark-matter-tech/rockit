#!/bin/bash
# build.sh — Build the Rockit runtime from modular .rok sources
# Concatenates all modules in dependency order, compiles with --no-runtime

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Find the Stage 1 compiler
COMMAND="$SCRIPT_DIR/../../Stage1/command"
if [ ! -f "$COMMAND" ]; then
    echo "Error: Stage 1 compiler not found at $COMMAND"
    exit 1
fi

# Concatenate modules in dependency order
cat \
    math.rok \
    memory.rok \
    string.rok \
    string_ops.rok \
    object.rok \
    list.rok \
    map.rok \
    io.rok \
    exception.rok \
    file.rok \
    process.rok \
    network.rok \
    concurrency.rok \
    > rockit_runtime.rok

echo "Concatenated runtime → rockit_runtime.rok"

# Compile with --no-runtime to produce LLVM IR
"$COMMAND" compile rockit_runtime.rok --emit-llvm --no-runtime -o rockit_runtime.ll

echo "Generated rockit_runtime.ll"

# Compile LLVM IR to linkable object file
clang -c -O1 -w rockit_runtime.ll -o rockit_runtime.o

# Copy to parent Runtime/ directory for Stage 0 discovery
cp rockit_runtime.o "$SCRIPT_DIR/../rockit_runtime.o"

echo "Built rockit_runtime.o"
