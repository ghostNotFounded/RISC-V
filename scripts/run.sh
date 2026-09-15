#!/usr/bin/env bash
set -e

# Paths
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TB_FILE="$PROJECT_DIR/test/tb_$1.sv"
EXE_PATH="$PROJECT_DIR/sim/sim_$1"
HEX_DIR="$PROJECT_DIR/tests"

mkdir -p "$PROJECT_DIR/sim"

# 1. Compile — list ALL your .sv source files here
echo "==> Compiling..."
verilator --binary --timing \
    -sv \
    --top-module tb_$1 \
    "$TB_FILE" \
    $([ "$1" != "top_multi_cycle" ] && echo "$PROJECT_DIR/top_multi_cycle.sv") \
    $([ "$1" != "cpu" ] && echo "$PROJECT_DIR/cpu.sv") \
    "$PROJECT_DIR/$1.sv" \
    "$PROJECT_DIR/instruction_memory.sv" \
    "$PROJECT_DIR/BankedMEM.sv" \
    "$PROJECT_DIR/controlUnit.sv" \
    "$PROJECT_DIR/alu.sv" \
    "$PROJECT_DIR/multUnit.sv" \
    "$PROJECT_DIR/divUnit.sv" \
    "$PROJECT_DIR/regfile.sv" \
    "$PROJECT_DIR/immGen.sv" \
    "$PROJECT_DIR/branchComp.sv" \
    -I"$PROJECT_DIR" \
    -o "$EXE_PATH"

# 2. Run all tests
echo "==> Running riscv-tests..."
"$EXE_PATH" +hex_dir="$HEX_DIR/"