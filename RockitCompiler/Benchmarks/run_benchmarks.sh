#!/bin/bash
# run_benchmarks.sh — Rockit vs JavaScript vs Go benchmark runner
# Usage: bash Benchmarks/run_benchmarks.sh
# Run from: RockitCompiler/

set -e

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$BENCH_DIR")"
RESULTS_FILE="$BENCH_DIR/results.txt"
BUILD_DIR="$BENCH_DIR/build"

mkdir -p "$BUILD_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Check available runtimes
HAS_NODE=false
HAS_GO=false
HAS_ROCKIT=false

command -v node >/dev/null 2>&1 && HAS_NODE=true
command -v go >/dev/null 2>&1 && HAS_GO=true
# Check for Stage 0 compiler
if swift run rockit --help >/dev/null 2>&1; then
    HAS_ROCKIT=true
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         ROCKIT BENCHMARK SUITE v1.0          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Runtimes detected:"
$HAS_ROCKIT && echo -e "    ${GREEN}✓${NC} Rockit (native via LLVM)" || echo -e "    ${RED}✗${NC} Rockit"
$HAS_NODE   && echo -e "    ${GREEN}✓${NC} Node.js $(node --version)" || echo -e "    ${RED}✗${NC} Node.js"
$HAS_GO     && echo -e "    ${GREEN}✓${NC} Go $(go version 2>/dev/null | awk '{print $3}')" || echo -e "    ${DIM}–${NC} Go (not installed, skipping)"
echo ""

# Measure execution time and peak memory (macOS)
# Usage: measure <command> [args...]
# Outputs: time_seconds peak_rss_kb
measure() {
    local tmpfile=$(mktemp)
    # Use /usr/bin/time for memory
    /usr/bin/time -l "$@" > /dev/null 2> "$tmpfile"
    local exit_code=$?
    # macOS format: "    1490944  maximum resident set size" (leading whitespace, value first)
    local rss_bytes=$(grep "maximum resident set size" "$tmpfile" | awk '{print $1}')
    rm -f "$tmpfile"

    if [ $exit_code -ne 0 ] || [ -z "$rss_bytes" ]; then
        echo "–"
        return
    fi

    # macOS reports bytes, convert to KB
    local rss_kb=$((rss_bytes / 1024))
    echo "$rss_kb"
}

run_benchmark() {
    local name="$1"
    local rok_file="$BENCH_DIR/bench_${name}.rok"
    local js_file="$BENCH_DIR/bench_${name}.js"
    local go_file="$BENCH_DIR/bench_${name}.go"
    local rok_bin="$BUILD_DIR/bench_${name}"

    echo -e "${BOLD}── $name ──────────────────────────────────────${NC}"
    echo ""

    # Compile Rockit
    local rok_time="–"
    local rok_mem="–"
    # build-native places binary next to source (strips .rok extension)
    local rok_actual_bin="${rok_file%.rok}"
    if $HAS_ROCKIT && [ -f "$rok_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Rockit...  "
        cd "$PROJECT_DIR"
        swift run rockit build-native "$rok_file" > /dev/null 2>&1
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Rockit...  "
        local start_rok=$(python3 -c 'import time; print(time.time())')
        local mem_rok=$(measure "$rok_actual_bin")
        local end_rok=$(python3 -c 'import time; print(time.time())')
        rok_time=$(python3 -c "print(f'{${end_rok} - ${start_rok}:.3f}')")
        rok_mem="$mem_rok"
        echo -e "${GREEN}${rok_time}s${NC}  mem: ${rok_mem} KB"
    fi

    # Run JavaScript
    local js_time="–"
    local js_mem="–"
    if $HAS_NODE && [ -f "$js_file" ]; then
        echo -ne "  ${BLUE}Running${NC}   Node.js... "
        local start_js=$(python3 -c 'import time; print(time.time())')
        local mem_js=$(measure node "$js_file")
        local end_js=$(python3 -c 'import time; print(time.time())')
        js_time=$(python3 -c "print(f'{${end_js} - ${start_js}:.3f}')")
        js_mem="$mem_js"
        echo -e "${GREEN}${js_time}s${NC}  mem: ${js_mem} KB"
    fi

    # Run Go
    local go_time="–"
    local go_mem="–"
    if $HAS_GO && [ -f "$go_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Go...      "
        go build -o "$BUILD_DIR/bench_${name}_go" "$go_file"
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Go...      "
        local start_go=$(python3 -c 'import time; print(time.time())')
        local mem_go=$(measure "$BUILD_DIR/bench_${name}_go")
        local end_go=$(python3 -c 'import time; print(time.time())')
        go_time=$(python3 -c "print(f'{${end_go} - ${start_go}:.3f}')")
        go_mem="$mem_go"
        echo -e "${GREEN}${go_time}s${NC}  mem: ${go_mem} KB"
    fi

    echo ""
    echo -e "  ${DIM}┌──────────────┬────────────┬────────────┐${NC}"
    printf "  ${DIM}│${NC} %-12s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "" "Time (s)" "Memory (KB)"
    echo -e "  ${DIM}├──────────────┼────────────┼────────────┤${NC}"
    printf "  ${DIM}│${NC} ${GREEN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Rockit" "$rok_time" "$rok_mem"
    printf "  ${DIM}│${NC} ${YELLOW}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Node.js" "$js_time" "$js_mem"
    printf "  ${DIM}│${NC} ${BLUE}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Go" "$go_time" "$go_mem"
    echo -e "  ${DIM}└──────────────┴────────────┴────────────┘${NC}"
    echo ""
}

# Run all benchmarks
run_benchmark "fib"
run_benchmark "loop"
run_benchmark "objects"
run_benchmark "strings"

echo -e "${BOLD}Done.${NC} Results above."
echo ""
