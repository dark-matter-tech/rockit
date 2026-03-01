#!/bin/bash
# run_benchmarks.sh — Rockit vs Rust vs Go vs Node.js benchmark runner
# Usage: bash Benchmarks/run_benchmarks.sh
# Run from: RockitCompiler/

set -e

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$BENCH_DIR")"
RESULTS_FILE="$BENCH_DIR/results.txt"
BUILD_DIR="$BENCH_DIR/build"
RUNS=3

mkdir -p "$BUILD_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Check available runtimes
HAS_NODE=false
HAS_GO=false
HAS_RUST=false
HAS_ROCKIT=false

command -v node >/dev/null 2>&1 && HAS_NODE=true
command -v go >/dev/null 2>&1 && HAS_GO=true
command -v rustc >/dev/null 2>&1 && HAS_RUST=true
# Check for Stage 0 compiler
if swift run rockit --help >/dev/null 2>&1; then
    HAS_ROCKIT=true
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         ROCKIT BENCHMARK SUITE v3.0          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Runtimes detected:"
$HAS_ROCKIT && echo -e "    ${GREEN}✓${NC} Rockit (native via LLVM)" || echo -e "    ${RED}✗${NC} Rockit"
$HAS_RUST   && echo -e "    ${GREEN}✓${NC} Rust $(rustc --version 2>/dev/null | awk '{print $2}')" || echo -e "    ${DIM}–${NC} Rust (not installed, skipping)"
$HAS_GO     && echo -e "    ${GREEN}✓${NC} Go $(go version 2>/dev/null | awk '{print $3}')" || echo -e "    ${DIM}–${NC} Go (not installed, skipping)"
$HAS_NODE   && echo -e "    ${GREEN}✓${NC} Node.js $(node --version)" || echo -e "    ${DIM}–${NC} Node.js (not installed, skipping)"
echo -e "  Runs: ${BOLD}${RUNS}${NC} (best of)"
echo ""

# Measure peak memory (macOS)
# Usage: measure_mem <command> [args...]
# Outputs: peak_rss_kb
measure_mem() {
    local tmpfile=$(mktemp)
    /usr/bin/time -l "$@" > /dev/null 2> "$tmpfile"
    local exit_code=$?
    local rss_bytes=$(grep "maximum resident set size" "$tmpfile" | awk '{print $1}')
    rm -f "$tmpfile"

    if [ $exit_code -ne 0 ] || [ -z "$rss_bytes" ]; then
        echo "–"
        return
    fi

    local rss_kb=$((rss_bytes / 1024))
    echo "$rss_kb"
}

# Time a command over N runs, return best time
# Usage: best_time <runs> <command> [args...]
# Outputs: best_seconds
best_time() {
    local runs="$1"
    shift
    local best=""

    for ((r = 1; r <= runs; r++)); do
        local start=$(python3 -c 'import time; print(time.time())')
        "$@" > /dev/null 2>&1
        local end=$(python3 -c 'import time; print(time.time())')
        local elapsed=$(python3 -c "print(f'{${end} - ${start}:.4f}')")

        if [ -z "$best" ]; then
            best="$elapsed"
        else
            best=$(python3 -c "print(f'{min(${best}, ${elapsed}):.4f}')")
        fi
    done

    # Format to 3 decimal places
    python3 -c "print(f'{${best}:.3f}')"
}

run_benchmark() {
    local name="$1"
    local rok_file="$BENCH_DIR/bench_${name}.rok"
    local rs_file="$BENCH_DIR/bench_${name}.rs"
    local go_file="$BENCH_DIR/bench_${name}.go"
    local js_file="$BENCH_DIR/bench_${name}.js"
    local rok_bin="$BUILD_DIR/bench_${name}"

    echo -e "${BOLD}── $name ──────────────────────────────────────${NC}"
    echo ""

    # Compile & run Rockit
    local rok_time="–"
    local rok_mem="–"
    local rok_actual_bin="${rok_file%.rok}"
    if $HAS_ROCKIT && [ -f "$rok_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Rockit...  "
        cd "$PROJECT_DIR"
        swift run rockit build-native "$rok_file" > /dev/null 2>&1
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Rockit...  "
        rok_time=$(best_time "$RUNS" "$rok_actual_bin")
        rok_mem=$(measure_mem "$rok_actual_bin")
        echo -e "${GREEN}${rok_time}s${NC}  mem: ${rok_mem} KB"
    fi

    # Compile & run Rust
    local rs_time="–"
    local rs_mem="–"
    if $HAS_RUST && [ -f "$rs_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Rust...    "
        rustc -O -o "$BUILD_DIR/bench_${name}_rs" "$rs_file" 2>/dev/null
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Rust...    "
        rs_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_rs")
        rs_mem=$(measure_mem "$BUILD_DIR/bench_${name}_rs")
        echo -e "${GREEN}${rs_time}s${NC}  mem: ${rs_mem} KB"
    fi

    # Compile & run Go
    local go_time="–"
    local go_mem="–"
    if $HAS_GO && [ -f "$go_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Go...      "
        go build -o "$BUILD_DIR/bench_${name}_go" "$go_file"
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Go...      "
        go_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_go")
        go_mem=$(measure_mem "$BUILD_DIR/bench_${name}_go")
        echo -e "${GREEN}${go_time}s${NC}  mem: ${go_mem} KB"
    fi

    # Run JavaScript
    local js_time="–"
    local js_mem="–"
    if $HAS_NODE && [ -f "$js_file" ]; then
        echo -ne "  ${BLUE}Running${NC}   Node.js... "
        js_time=$(best_time "$RUNS" node "$js_file")
        js_mem=$(measure_mem node "$js_file")
        echo -e "${GREEN}${js_time}s${NC}  mem: ${js_mem} KB"
    fi

    echo ""
    echo -e "  ${DIM}┌──────────────┬────────────┬────────────┐${NC}"
    printf "  ${DIM}│${NC} %-12s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "" "Time (s)" "Memory (KB)"
    echo -e "  ${DIM}├──────────────┼────────────┼────────────┤${NC}"
    printf "  ${DIM}│${NC} ${GREEN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Rockit" "$rok_time" "$rok_mem"
    printf "  ${DIM}│${NC} ${MAGENTA}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Rust" "$rs_time" "$rs_mem"
    printf "  ${DIM}│${NC} ${BLUE}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Go" "$go_time" "$go_mem"
    printf "  ${DIM}│${NC} ${YELLOW}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Node.js" "$js_time" "$js_mem"
    echo -e "  ${DIM}└──────────────┴────────────┴────────────┘${NC}"
    echo ""
}

# Run all benchmarks
echo -e "${BOLD}  Technical${NC}"
echo ""
run_benchmark "fib"
run_benchmark "loop"
run_benchmark "objects"
run_benchmark "strings"

echo -e "${BOLD}  Practical${NC}"
echo ""
run_benchmark "sieve"
run_benchmark "matrix"
run_benchmark "sort"

echo -e "${BOLD}Done.${NC} Best of ${RUNS} runs. Results above."
echo ""
