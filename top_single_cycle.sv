`timescale 1ns/1ps
`include "consts.svh"

module singleCycleCPU #(
    parameter BUS_SIZE = 32
) (
    input logic clk,
    input logic reset
);
    logic [31:0] pc_reg = -4;
    logic [31:0] instr_reg;

    always @(posedge clk) begin
        pc_reg <= pcsel ? y : pc_reg + 4;
    end

    instruction_memory IMEM (
        .addr(pc_reg[15:0]),
        .instruction(instr_reg)
    );

    logic pcsel, regwen, brun, bsel, memrw, breq, brlt;
    logic [3:0] aluop;
    logic [2:0] imm_sel, mode;
    logic [1:0] wbsel, asel;

    controlUnit CU (
        .instr(instr_reg),
        .BrEq(breq),
        .BrLT(brlt),

        .PCSel(pcsel),
        .RegWEn(regwen),
        .Mode(mode),
        .BrUn(brun),
        .BSel(bsel),
        .ASel(asel),
        .ALUOp(aluop),
        .MemRW(memrw),
        .WBSel(wbsel),
        .immSel(imm_sel)
    );

    logic [31:0] immediate;
    immGen IG (
        .instr(instr_reg),
        .immSel(imm_sel),
        .y(immediate)
    );

    logic [31:0] wb_data;
    always_comb begin
        case (wbsel)
            `WBSel_MEM:  wb_data = mem_data;
            `WBSel_PC4:  wb_data = pc_reg + 4;
            default:     wb_data = y;
        endcase
    end
    logic [31:0] rdata1, rdata2;
    regfile RF (
        .clk(clk),
        .wenable(regwen),
        .rd(instr_reg[11:7]),
        .wdata(wb_data),
        .rs1(instr_reg[19:15]),
        .rs2(instr_reg[24:20]),
        
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    branchComp Comparator (
        .A(rdata1),
        .B(rdata2),
        .BrUn(brun),

        .BrLT(brlt),
        .BrEq(breq)
    );

    logic zero;
    logic [31:0] y;

    logic [31:0] alu_a;
    logic [31:0] alu_b;

    assign alu_a = (asel == 2'b10) ? 32'b0 : (asel == 2'b01) ? pc_reg : rdata1; 
    assign alu_b = bsel ? immediate : rdata2;
    alu ALU (
        .aluop(aluop),
        .A(alu_a),
        .B(alu_b),

        .zero(zero),
        .y(y)
    );

    logic [31:0] mem_data;
    BankedMEM DMEM (
        .clk(clk),
        .mode(mode),
        .writeEn(memrw),
        .address(y),
        .writeData(rdata2),
        .readData(mem_data)
    );
endmodule