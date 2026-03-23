#!/usr/bin/env bash
set -e

# 1. Setup
if [ -z "$1" ]; then
    echo "Usage: $0 <module_name>"
    exit 1
fi

MODULE=$1
TB_FILE="test/tb_${MODULE}.sv"
SRC_FILE="${MODULE}.sv"

# Use PWD to ensure Verilator puts the binary in the right project folder
EXE_NAME="sim_${MODULE}"
EXE_PATH="$(pwd)/sim/$EXE_NAME"
VCD_FILE="sim/vcd/${MODULE}.vcd"

# Ensure directories exist
mkdir -p sim/vcd

# 2. Compile
echo "==> Compiling ${MODULE} with Verilator..."
verilator --binary --trace --timing \
    -sv \
    --top-module "tb_${MODULE}" \
    "$TB_FILE" "$SRC_FILE" \
    -o "$EXE_PATH"

# 3. Run
echo "==> Running simulation for ${MODULE}..."
# When using --binary, the executable is placed exactly where -o specifies
"$EXE_PATH" +vcd="$VCD_FILE"

# 4. Open Waveform
if [ -f "$VCD_FILE" ]; then
    echo "==> Opening waveform: $VCD_FILE"
    gtkwave "$VCD_FILE" &
else
    # Fallback check for the hardcoded name in your TB
    if [ -f "task1.vcd" ]; then
         mv task1.vcd "$VCD_FILE"
         gtkwave "$VCD_FILE" &
    else
        echo "Warning: $VCD_FILE not found."
    fi
fi