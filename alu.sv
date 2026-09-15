`timescale 1ns/1ps
`include "consts.svh"

module alu #(
    parameter BUS_SIZE = 32
) (
    input   logic [3:0]             aluop,
    input   logic signed [BUS_SIZE-1:0]    A,
    input   logic signed [BUS_SIZE-1:0]    B,

    output  logic                   zero,
    output  logic [BUS_SIZE-1:0]    y
);
    always @(*) begin
        case (aluop)
            `ALU_ADD:   y = A + B;
            `ALU_SUB:   y = A - B;
            `ALU_AND:   y = A & B;
            `ALU_OR:    y = A | B;
            `ALU_XOR:   y = A ^ B;
            
            `ALU_SLL:   y = A << B[4:0];
            `ALU_SRL:   y = $unsigned(A) >> B[4:0];
            `ALU_SRA:   y = A >>> B[4:0];
            
            `ALU_SLT:   y = (A < B) ? 32'd1 : 32'd0;
            `ALU_SLTU:  y = ($unsigned(A) < $unsigned(B)) ? 32'd1 : 32'd0;

            default:    y = 32'b0;
        endcase
    end

    assign zero = (y == 32'b0);
endmodule