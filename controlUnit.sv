`timescale 1ns/1ps
`include "consts.svh"

module controlUnit #(
    parameter BUS_SIZE = 32
) (
    input logic [31:0] instr,
    input logic BrEq,
    input logic BrLT,

    output logic PCSel,
    output logic RegWEn,
    output logic BrUn,
    output logic BSel,
    output logic ASel,
    output logic [3:0] ALUOp,
    output logic MemRW,
    output logic [1:0] WBSel
);
    localparam WBSel_MEM = 2'b00;
    localparam WBSel_ALU = 2'b01;
    localparam WBSel_PC4 = 2'b10;

    wire [2:0] funct3;
    wire [6:0] funct7;

    always @(*) begin
        PCSel = 0;
        RegWEn = 0;
        BrUn = 0;
        BSel = 0;
        ASel = 0;
        ALUOp = 0;
        MemRW = 0;
        WBSel = 0;


        case (instr[6:0])
            `OPC_R: begin
                RegWEn = 1;
                WBSel = WBSel_ALU;

                case (funct3)
                    `FUNCT3_ADD_SUB:    ALUOp = (funct7 == `FUNCT7_SRA_SUB) ? `ALU_SUB : `ALU_ADD;
                    `FUNCT3_SLL:        ALUOp = `ALU_SLL;
                    `FUNCT3_SRL_SRA:    ALUOp = (funct7 == `FUNCT7_SRA_SUB) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_SLT:        ALUOp = `ALU_SLT;
                    `FUNCT3_SLTU:       ALUOp = `ALU_SLTU;
                    `FUNCT3_XOR:        ALUOp = `ALU_XOR;
                    `FUNCT3_OR:         ALUOp = `ALU_OR;
                    `FUNCT3_AND:        ALUOp = `ALU_AND;
                    default:            ALUOp = `ALU_AND;
                endcase
            end
            default: RegWEn = 0;
        endcase
    end

    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

endmodule