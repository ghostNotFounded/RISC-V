`timescale 1ns/1ps
`include "consts.svh"

module immGen #(
    parameter BUS_SIZE = 32
) (
    input logic [31:0] instr,
    input logic [2:0] immSel,

    output logic [31:0] y
);
    wire [31:0] y_imm, y_store, y_branch, y_jump, y_upper;

    assign y_imm = {{20{instr[31]}}, instr[31:20]};
    assign y_store = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign y_branch = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign y_jump = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    assign y_upper = {instr[31:12], 12'b0};

    always_comb begin
        case (immSel)
            `IMMSEL_I: y = y_imm;
            `IMMSEL_S: y = y_store;
            `IMMSEL_B: y = y_branch;
            `IMMSEL_U: y = y_upper;
            `IMMSEL_J: y = y_jump;
            default: y = 32'b0;
        endcase
    end
endmodule