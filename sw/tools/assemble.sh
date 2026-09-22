#!/usr/bin/env bash
# ============================================================================
#  assemble.sh -- DLX assembler front-end
#
#  Usage:
#      sw/tools/assemble.sh sw/asm/test_pro_stress.asm
#
#  Produces, next to the source:
#      <name>.bin        raw big-endian machine code
#      <name>.list       annotated listing
#      <name>.mem        one 8-digit hex word per line, ready for the IRAM
#
#  The .mem file is what sim/test.asm.mem has to be replaced with:
#      cp sw/asm/foo.mem sim/test.asm.mem
#  or, in one step,
#      sim/run_ghdl.sh -m sw/asm/foo.mem
# ============================================================================
set -euo pipefail

if [ $# -ne 1 ] || [ ! -r "$1" ]; then
    echo "usage: $0 <dlx_assembly_file>.asm" >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
src="$1"
base="${src%.*}"

command -v perl >/dev/null 2>&1 || { echo "error: perl not found in PATH" >&2; exit 1; }

perl "$HERE/dlxasm.pl" -o "$base.bin" -list "$base.list" "$src"
rm -f "$base.bin.hdr"

# Big-endian 32-bit words, one per line, upper-case hex.
# od is used instead of hexdump because it ships with Git Bash / MSYS2 on
# Windows, where hexdump usually does not.
od --width=4 -t xC "$base.bin" | awk 'NF>=5 {print toupper($2$3$4$5)}' > "$base.mem"

printf '%s -> %s (%s words)\n' "$src" "$base.mem" "$(wc -l < "$base.mem" | tr -d ' ')"
