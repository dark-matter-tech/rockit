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
    concurrency.rok \
    > rockit_runtime.rok

echo "Concatenated runtime → rockit_runtime.rok"

# Compile with --no-runtime to produce .ll file
"$COMMAND" build-native rockit_runtime.rok --no-runtime -o rockit_runtime

echo "Built rockit_runtime"
