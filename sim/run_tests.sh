#!/usr/bin/env bash
#
# FPGA Pong testbench runner (Icarus Verilog).
#
# Compiles and runs every self-checking testbench in sim/ against the design
# in src/, and exits non-zero if any test fails. Used both locally and by CI
# (.github/workflows/ci.yml), so tests no longer depend on a manual Vivado GUI
# run.
#
# A testbench is auto-discovered if its filename matches *_tb.v or tb_*.v, and
# its top module name is assumed to equal the filename stem (true for every
# testbench in this repo). Each one is elaborated with -s against the full set
# of src/*.v files; unreferenced modules are simply compiled but not used, so
# no per-testbench dependency list has to be maintained.
#
# A test PASSES iff its run prints the "ALL TESTS PASSED" sentinel and emits no
# [FAIL]/FATAL lines. vvp always exits 0 (the testbenches end via $finish), so
# the output sentinels -- not the exit code -- are the source of truth.
#
# Usage: bash sim/run_tests.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
SIM="$ROOT/sim"
BUILD="$ROOT/build"

mkdir -p "$BUILD"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "error: iverilog not found on PATH (install Icarus Verilog)" >&2
    exit 127
fi

shopt -s nullglob
SRCS=("$SRC"/*.v)
TBS=("$SIM"/*_tb.v "$SIM"/tb_*.v)

if [ "${#TBS[@]}" -eq 0 ]; then
    echo "error: no testbenches found in $SIM" >&2
    exit 1
fi

echo "=== FPGA Pong testbench suite (Icarus Verilog) ==="

pass=0
fail=0
failed_names=""

for tb in "${TBS[@]}"; do
    name="$(basename "$tb" .v)"
    vvp_bin="$BUILD/$name.vvp"
    log="$BUILD/$name.log"

    printf '[ RUN  ] %s\n' "$name"

    if ! iverilog -g2005 -s "$name" -o "$vvp_bin" "$tb" "${SRCS[@]}" > "$log" 2>&1; then
        printf '[ FAIL ] %s (compile error)\n' "$name"
        sed 's/^/    /' "$log"
        fail=$((fail + 1))
        failed_names="$failed_names $name"
        continue
    fi

    vvp "$vvp_bin" > "$log" 2>&1

    if grep -q "ALL TESTS PASSED" "$log" && ! grep -qE "\[FAIL\]|FATAL|TEST\(S\) FAILED" "$log"; then
        printf '[ PASS ] %s\n' "$name"
        pass=$((pass + 1))
    else
        printf '[ FAIL ] %s\n' "$name"
        sed 's/^/    /' "$log"
        fail=$((fail + 1))
        failed_names="$failed_names $name"
    fi
done

echo ""
echo "=== $pass passed, $fail failed ==="

if [ "$fail" -ne 0 ]; then
    echo "failed:$failed_names"
    exit 1
fi
