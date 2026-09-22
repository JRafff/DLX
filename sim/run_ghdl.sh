#!/usr/bin/env bash
# ============================================================================
#  run_ghdl.sh -- compile and simulate DLX-pro with GHDL (free, cross-platform)
#
#  Usage, from the sim/ directory:
#      ./run_ghdl.sh                       # run test.asm.mem for 400 cycles
#      ./run_ghdl.sh -c 6000               # run for 6000 cycles
#      ./run_ghdl.sh -m ../sw/asm/foo.mem  # run a different program
#      ./run_ghdl.sh -w                    # also dump dlx.ghw for gtkwave
#
#  --ieee=synopsys is required because the Control Unit, the ALU and the IRAM
#  use std_logic_arith / std_logic_unsigned / std_logic_textio.
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"

GHDL="${GHDL:-ghdl}"
command -v "$GHDL" >/dev/null 2>&1 || {
    echo "error: ghdl not found in PATH. Set GHDL=/path/to/ghdl or install it:"
    echo "       winget install ghdl.ghdl.ucrt64.mcode      (Windows)"
    echo "       brew install ghdl                          (macOS)"
    echo "       apt install ghdl                           (Debian/Ubuntu)"
    exit 1
}

CYCLES=400
MEM=""
WAVE=""
while getopts "c:m:wh" opt; do
    case $opt in
        c) CYCLES=$OPTARG ;;
        m) MEM=$OPTARG ;;
        w) WAVE="--wave=dlx.ghw" ;;
        h) sed -n '2,12p' "$0"; exit 0 ;;
        *) exit 1 ;;
    esac
done

if [ -n "$MEM" ]; then
    cp "$MEM" test.asm.mem
    echo "==> program: $MEM"
fi
[ -f test.asm.mem ] || { echo "error: test.asm.mem not found in $(pwd)"; exit 1; }

BUILD=build
mkdir -p "$BUILD"

SRC=../src
FILES=(
    "$SRC/000-globals.vhd"
    "$SRC/common/01-reg_en.vhd"
    "$SRC/common/01-G_block.vhd"
    "$SRC/common/01-PG_block.vhd"
    "$SRC/common/01-pg_network.vhd"
    "$SRC/common/01-koggle_stone_adder.vhd"
    "$SRC/common/01-shifter.vhd"
    "$SRC/common/01-logic.vhd"
    "$SRC/common/01-comparator_eq.vhd"
    "$SRC/common/01-zero_check.vhd"
    "$SRC/common/01-ADD_SUB.vhd"
    "$SRC/core/a.b-IFStage.core/a.b.a-PC_sel.vhd"
    "$SRC/core/a.b-IFStage.core/a.b.b-BTB.vhd"
    "$SRC/core/a.b-IFStage.core/a.b.c-Icache.vhd"
    "$SRC/core/a.b-IFStage.core/a.b.d-IRAM.vhd"
    "$SRC/core/a.c-IDStage.core/a.c.a-RF.vhd"
    "$SRC/core/a.c-IDStage.core/a.c.b-ImmGen.vhd"
    "$SRC/core/a.c-IDStage.core/a.c.c-branch_resolution.vhd"
    "$SRC/core/a.d-EXStage.core/a.d.a-ALU.vhd"
    "$SRC/core/a.e-MEMStage.core/a.e.a-DRAM.vhd"
    "$SRC/core/a.g-IF_ID_reg.vhd"
    "$SRC/core/a.h-ID_EX_reg.vhd"
    "$SRC/core/a.i-EX_MEM_reg.vhd"
    "$SRC/core/a.j-MEM_WB_reg.vhd"
    "$SRC/core/a.b-IFStage.vhd"
    "$SRC/core/a.c-IDStage.vhd"
    "$SRC/core/a.d-EXStage.vhd"
    "$SRC/core/a.e-MEMStage.vhd"
    "$SRC/core/a.f-WBStage.vhd"
    "$SRC/core/a.k-forwarding_unit.vhd"
    "$SRC/core/a.l-forwarding_id.vhd"
    "$SRC/core/a.m-hazard_detector.vhd"
    "$SRC/core/a.a-CU.vhd"
    "$SRC/core/a-DLX.vhd"
    "tb/TB_DLX.vhd"
)

FLAGS="--std=93c --ieee=synopsys --workdir=$BUILD"

echo "==> analysing ${#FILES[@]} files"
for f in "${FILES[@]}"; do
    $GHDL -a $FLAGS "$f"
done

echo "==> elaborating"
$GHDL -e $FLAGS tb_dlx

echo "==> running $CYCLES cycles"
$GHDL -r $FLAGS tb_dlx -gSIM_CYCLES="$CYCLES" $WAVE \
      --stop-time=$(( (CYCLES + 10) * 10 ))ns || true

echo "==> done"
[ -n "$WAVE" ] && echo "    waveform: sim/dlx.ghw  (open with: gtkwave dlx.ghw)"
exit 0
