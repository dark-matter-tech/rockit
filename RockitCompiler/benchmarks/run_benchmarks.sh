#!/bin/bash
# run_benchmarks.sh — Rockit vs C++ vs Rust vs Go vs Node.js benchmark runner
# Usage: bash benchmarks/run_benchmarks.sh [--profile standard|turbo|safety|all]
# Run from: RockitCompiler/

set -e

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$BENCH_DIR")"
BUILD_DIR="$BENCH_DIR/build"
RUNS=3
PROFILE="all"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --standard|--turbo|--safety|--all)
            PROFILE="${1#--}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p "$BUILD_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Check available runtimes
HAS_NODE=false
HAS_GO=false
HAS_RUST=false
HAS_ROCKIT=false
HAS_CPP=false

command -v node >/dev/null 2>&1 && HAS_NODE=true
command -v go >/dev/null 2>&1 && HAS_GO=true
command -v rustc >/dev/null 2>&1 && HAS_RUST=true
command -v clang++ >/dev/null 2>&1 && HAS_CPP=true
# Check for Stage 0 compiler
if swift run rockit --help >/dev/null 2>&1; then
    HAS_ROCKIT=true
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         ROCKIT BENCHMARK SUITE v4.0          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Profile: ${BOLD}${PROFILE}${NC}"
echo -e "  Runtimes detected:"
$HAS_ROCKIT && echo -e "    ${GREEN}✓${NC} Rockit (native via LLVM)" || echo -e "    ${RED}✗${NC} Rockit"
$HAS_CPP    && echo -e "    ${GREEN}✓${NC} C++ (clang++ $(clang++ --version 2>/dev/null | head -1 | sed 's/.*version //' | awk '{print $1}'))" || echo -e "    ${DIM}–${NC} C++ (not installed, skipping)"
$HAS_RUST   && echo -e "    ${GREEN}✓${NC} Rust $(rustc --version 2>/dev/null | awk '{print $2}')" || echo -e "    ${DIM}–${NC} Rust (not installed, skipping)"
$HAS_GO     && echo -e "    ${GREEN}✓${NC} Go $(go version 2>/dev/null | awk '{print $3}')" || echo -e "    ${DIM}–${NC} Go (not installed, skipping)"
$HAS_NODE   && echo -e "    ${GREEN}✓${NC} Node.js $(node --version)" || echo -e "    ${DIM}–${NC} Node.js (not installed, skipping)"
echo -e "  Runs: ${BOLD}${RUNS}${NC} (best of)"
echo ""

# Measure peak memory (macOS)
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

    python3 -c "print(f'{${best}:.3f}')"
}

# Time with extra args passed to binary
best_time_with_args() {
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

    python3 -c "print(f'{${best}:.3f}')"
}

# ─── Standard benchmark (5 languages) ─────────────────────────────────────────
run_benchmark() {
    local name="$1"
    local extra_args="$2"
    local rok_file="$BENCH_DIR/bench_${name}.rok"
    local cpp_file="$BENCH_DIR/bench_${name}.cpp"
    local rs_file="$BENCH_DIR/bench_${name}.rs"
    local go_file="$BENCH_DIR/bench_${name}.go"
    local js_file="$BENCH_DIR/bench_${name}.js"

    echo -e "${BOLD}── $name ──────────────────────────────────────${NC}"
    echo ""

    # Compile & run Rockit
    local rok_time="–"
    local rok_mem="–"
    local rok_actual_bin="${rok_file%.rok}"
    if $HAS_ROCKIT && [ -f "$rok_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Rockit...  "
        cd "$PROJECT_DIR"
        if swift run rockit build-native "$rok_file" > /dev/null 2>&1; then
            echo -e "${GREEN}done${NC}"

            echo -ne "  ${BLUE}Running${NC}   Rockit...  "
            if [ -n "$extra_args" ]; then
                rok_time=$(best_time "$RUNS" "$rok_actual_bin" $extra_args)
                rok_mem=$(measure_mem "$rok_actual_bin" $extra_args)
            else
                rok_time=$(best_time "$RUNS" "$rok_actual_bin")
                rok_mem=$(measure_mem "$rok_actual_bin")
            fi
            echo -e "${GREEN}${rok_time}s${NC}  mem: ${rok_mem} KB"
        else
            echo -e "${RED}FAIL${NC} (compile error, skipping)"
        fi
    fi

    # Compile & run C++
    local cpp_time="–"
    local cpp_mem="–"
    if $HAS_CPP && [ -f "$cpp_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} C++...     "
        clang++ -O2 -std=c++17 -o "$BUILD_DIR/bench_${name}_cpp" "$cpp_file" 2>/dev/null
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   C++...     "
        if [ -n "$extra_args" ]; then
            cpp_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_cpp" $extra_args)
            cpp_mem=$(measure_mem "$BUILD_DIR/bench_${name}_cpp" $extra_args)
        else
            cpp_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_cpp")
            cpp_mem=$(measure_mem "$BUILD_DIR/bench_${name}_cpp")
        fi
        echo -e "${GREEN}${cpp_time}s${NC}  mem: ${cpp_mem} KB"
    fi

    # Compile & run Rust
    local rs_time="–"
    local rs_mem="–"
    if $HAS_RUST && [ -f "$rs_file" ]; then
        echo -ne "  ${YELLOW}Compiling${NC} Rust...    "
        rustc -O -o "$BUILD_DIR/bench_${name}_rs" "$rs_file" 2>/dev/null
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   Rust...    "
        if [ -n "$extra_args" ]; then
            rs_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_rs" $extra_args)
            rs_mem=$(measure_mem "$BUILD_DIR/bench_${name}_rs" $extra_args)
        else
            rs_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_rs")
            rs_mem=$(measure_mem "$BUILD_DIR/bench_${name}_rs")
        fi
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
        if [ -n "$extra_args" ]; then
            go_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_go" $extra_args)
            go_mem=$(measure_mem "$BUILD_DIR/bench_${name}_go" $extra_args)
        else
            go_time=$(best_time "$RUNS" "$BUILD_DIR/bench_${name}_go")
            go_mem=$(measure_mem "$BUILD_DIR/bench_${name}_go")
        fi
        echo -e "${GREEN}${go_time}s${NC}  mem: ${go_mem} KB"
    fi

    # Run JavaScript
    local js_time="–"
    local js_mem="–"
    if $HAS_NODE && [ -f "$js_file" ]; then
        echo -ne "  ${BLUE}Running${NC}   Node.js... "
        if [ -n "$extra_args" ]; then
            js_time=$(best_time "$RUNS" node "$js_file" $extra_args)
            js_mem=$(measure_mem node "$js_file" $extra_args)
        else
            js_time=$(best_time "$RUNS" node "$js_file")
            js_mem=$(measure_mem node "$js_file")
        fi
        echo -e "${GREEN}${js_time}s${NC}  mem: ${js_mem} KB"
    fi

    echo ""
    echo -e "  ${DIM}┌──────────────┬────────────┬────────────┐${NC}"
    printf "  ${DIM}│${NC} %-12s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "" "Time (s)" "Memory (KB)"
    echo -e "  ${DIM}├──────────────┼────────────┼────────────┤${NC}"
    printf "  ${DIM}│${NC} ${GREEN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Rockit" "$rok_time" "$rok_mem"
    printf "  ${DIM}│${NC} ${CYAN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "C++" "$cpp_time" "$cpp_mem"
    printf "  ${DIM}│${NC} ${MAGENTA}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Rust" "$rs_time" "$rs_mem"
    printf "  ${DIM}│${NC} ${BLUE}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Go" "$go_time" "$go_mem"
    printf "  ${DIM}│${NC} ${YELLOW}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Node.js" "$js_time" "$js_mem"
    echo -e "  ${DIM}└──────────────┴────────────┴────────────┘${NC}"
    echo ""
}

# ─── Safety benchmark (Rockit standard vs safety side by side) ─────────────────
run_benchmark_safe() {
    local name="$1"
    local rok_file="$BENCH_DIR/bench_${name}.rok"
    local safe_file="$BENCH_DIR/bench_${name}_safe.rok"

    if [ ! -f "$safe_file" ]; then
        return
    fi

    echo -e "${BOLD}── $name (standard vs safety) ────────────────${NC}"
    echo ""

    local std_time="–"
    local std_mem="–"
    local safe_time="–"
    local safe_mem="–"

    if $HAS_ROCKIT; then
        # Compile & run standard version
        if [ -f "$rok_file" ]; then
            local rok_actual_bin="${rok_file%.rok}"
            echo -ne "  ${YELLOW}Compiling${NC} Standard... "
            cd "$PROJECT_DIR"
            if swift run rockit build-native "$rok_file" > /dev/null 2>&1; then
                echo -e "${GREEN}done${NC}"

                echo -ne "  ${BLUE}Running${NC}   Standard... "
                std_time=$(best_time "$RUNS" "$rok_actual_bin")
                std_mem=$(measure_mem "$rok_actual_bin")
                echo -e "${GREEN}${std_time}s${NC}  mem: ${std_mem} KB"
            else
                echo -e "${RED}FAIL${NC} (compile error, skipping)"
            fi
        fi

        # Compile & run safety version
        local safe_actual_bin="${safe_file%.rok}"
        echo -ne "  ${YELLOW}Compiling${NC} Safety...   "
        cd "$PROJECT_DIR"
        if swift run rockit build-native --no-runtime "$safe_file" > /dev/null 2>&1; then
            echo -e "${GREEN}done${NC}"

            echo -ne "  ${BLUE}Running${NC}   Safety...   "
            safe_time=$(best_time "$RUNS" "$safe_actual_bin")
            safe_mem=$(measure_mem "$safe_actual_bin")
            echo -e "${GREEN}${safe_time}s${NC}  mem: ${safe_mem} KB"
        else
            echo -e "${RED}FAIL${NC} (compile error, skipping)"
        fi
    fi

    # Compute overhead ratio
    local overhead="–"
    if [ "$std_time" != "–" ] && [ "$safe_time" != "–" ]; then
        overhead=$(python3 -c "
std = float('$std_time')
safe = float('$safe_time')
if std > 0:
    print(f'{safe/std:.2f}x')
else:
    print('–')
")
    fi

    echo ""
    echo -e "  ${DIM}┌──────────────┬────────────┬────────────┬────────────┐${NC}"
    printf "  ${DIM}│${NC} %-12s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "" "Time (s)" "Memory (KB)" "Ratio"
    echo -e "  ${DIM}├──────────────┼────────────┼────────────┼────────────┤${NC}"
    printf "  ${DIM}│${NC} ${GREEN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Standard" "$std_time" "$std_mem" "1.00x"
    printf "  ${DIM}│${NC} ${CYAN}%-12s${NC} ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC} %10s ${DIM}│${NC}\n" "Safety" "$safe_time" "$safe_mem" "$overhead"
    echo -e "  ${DIM}└──────────────┴────────────┴────────────┴────────────┘${NC}"
    echo ""
}

# ─── Safety overhead benchmark (Rockit freestanding, internal timing) ──────────
run_overhead_benchmark() {
    local name="$1"
    local rok_file="$BENCH_DIR/bench_${name}.rok"

    if [ ! -f "$rok_file" ]; then
        return
    fi

    echo -e "${BOLD}── $name (overhead measurement) ──────────────${NC}"
    echo ""

    if $HAS_ROCKIT; then
        local rok_actual_bin="${rok_file%.rok}"
        echo -ne "  ${YELLOW}Compiling${NC} ...  "
        cd "$PROJECT_DIR"
        swift run rockit build-native --no-runtime "$rok_file" > /dev/null 2>&1
        echo -e "${GREEN}done${NC}"

        echo -ne "  ${BLUE}Running${NC}   ...  "
        local output=$("$rok_actual_bin" 2>&1)
        echo -e "${GREEN}done${NC}"
        echo ""
        echo -e "  ${DIM}Result:${NC} $output"
    else
        echo -e "  ${RED}Rockit not available${NC}"
    fi
    echo ""
}

# ─── Generate temp file for file_read benchmark ──────────────────────────────
TEMP_FILE=""
generate_temp_file() {
    TEMP_FILE=$(mktemp)
    echo -ne "  ${DIM}Generating temp file (200K lines)...${NC} "
    python3 -c "
import sys
line = 'a' * 100
for i in range(200000):
    sys.stdout.write(line + '\n')
" > "$TEMP_FILE"
    echo -e "${GREEN}done${NC} ($(du -h "$TEMP_FILE" | awk '{print $1}'))"
}

cleanup_temp_file() {
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup_temp_file EXIT

# ─── Run profiles ─────────────────────────────────────────────────────────────

run_standard_profile() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  STANDARD BENCHMARKS (12 benchmarks, 5 langs) ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo ""

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

    echo -e "${BOLD}  CLBG${NC}"
    echo ""
    run_benchmark "binarytrees"
    run_benchmark "fannkuch"
    run_benchmark "nbody"
    run_benchmark "spectralnorm"

}

run_turbo_profile() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  TURBO I/O BENCHMARKS (6 benchmarks, 5 langs) ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo ""

    run_benchmark "split"
    run_benchmark "field_extract"
    run_benchmark "parse_int"
    run_benchmark "csv_pipeline"
    run_benchmark "list_build"

    # file_read needs a temp file
    generate_temp_file
    run_benchmark "file_read" "$TEMP_FILE"
}

run_safety_profile() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  SAFETY PROFILE (standard vs freestanding)    ${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BOLD}  Safety Variants${NC}"
    echo ""
    run_benchmark_safe "fib"
    run_benchmark_safe "objects"
    run_benchmark_safe "strings"
    run_benchmark_safe "sort"
    run_benchmark_safe "matrix"
    run_benchmark_safe "sieve"
    run_benchmark_safe "binarytrees"

    echo -e "${BOLD}  Safety Overhead Measurements${NC}"
    echo ""
    run_overhead_benchmark "bounds_check"
    run_overhead_benchmark "null_check"
    run_overhead_benchmark "pool_alloc"
    run_overhead_benchmark "region_alloc"
    run_overhead_benchmark "wcet_variance"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

case "$PROFILE" in
    standard)
        run_standard_profile
        ;;
    turbo)
        run_turbo_profile
        ;;
    safety)
        run_safety_profile
        ;;
    all)
        run_standard_profile
        run_turbo_profile
        run_safety_profile
        ;;
    *)
        echo -e "${RED}Unknown profile: $PROFILE${NC}"
        echo "Usage: $0 [--profile standard|turbo|safety|all]"
        exit 1
        ;;
esac

echo -e "${BOLD}Done.${NC} Best of ${RUNS} runs. Profile: ${PROFILE}."
echo ""
