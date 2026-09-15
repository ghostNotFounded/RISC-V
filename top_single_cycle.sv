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
        .immSel(imm_sel),
        .MultEn(),
        .DivEn(),
        .MDUOp()
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

    logic [3:0] byte_mask;
    logic [31:0] formatted_wdata;
    always_comb begin
        if (memrw) begin
            case (mode)
                `MEM_WORD: begin
                    byte_mask       = 4'b1111;
                    formatted_wdata = rdata2;
                end
                `MEM_HWORD: begin
                    byte_mask       = y[1] ? 4'b1100 : 4'b0011;
                    formatted_wdata = y[1] ? {rdata2[15:0], 16'b0} : {16'b0, rdata2[15:0]};
                end
                `MEM_BYTE: begin
                    case (y[1:0])
                        2'b00: begin
                            byte_mask       = 4'b0001;
                            formatted_wdata = {24'b0, rdata2[7:0]};
                        end
                        2'b01: begin
                            byte_mask       = 4'b0010;
                            formatted_wdata = {16'b0, rdata2[7:0], 8'b0};
                        end
                        2'b10: begin
                            byte_mask       = 4'b0100;
                            formatted_wdata = {8'b0, rdata2[7:0], 16'b0};
                        end
                        2'b11: begin
                            byte_mask       = 4'b1000;
                            formatted_wdata = {rdata2[7:0], 24'b0};
                        end
                        default: begin
                            byte_mask       = 4'b0000;
                            formatted_wdata = 32'b0;
                        end
                    endcase
                end
                default: begin
                    byte_mask       = 4'b0000;
                    formatted_wdata = 32'b0;
                end
            endcase
        end else begin
            byte_mask       = 4'b0000;
            formatted_wdata = 32'b0;
        end
    end

    logic [31:0] mem_raw_data;
    logic [31:0] mem_data;
    always_comb begin
        case (mode)
            `MEM_WORD:  mem_data = mem_raw_data;
            `MEM_HWORD: mem_data = y[1] ? {{16{mem_raw_data[31]}}, mem_raw_data[31:16]} : {{16{mem_raw_data[15]}}, mem_raw_data[15:0]};
            `MEM_BYTE: begin
                case (y[1:0])
                    2'b00: mem_data = {{24{mem_raw_data[7]}},  mem_raw_data[7:0]};
                    2'b01: mem_data = {{24{mem_raw_data[15]}}, mem_raw_data[15:8]};
                    2'b10: mem_data = {{24{mem_raw_data[23]}}, mem_raw_data[23:16]};
                    2'b11: mem_data = {{24{mem_raw_data[31]}}, mem_raw_data[31:24]};
                    default: mem_data = 32'b0;
                endcase
            end
            `MEM_HWORD_U: mem_data = y[1] ? {16'b0, mem_raw_data[31:16]} : {16'b0, mem_raw_data[15:0]};
            `MEM_BYTE_U: begin
                case (y[1:0])
                    2'b00: mem_data = {24'b0, mem_raw_data[7:0]};
                    2'b01: mem_data = {24'b0, mem_raw_data[15:8]};
                    2'b10: mem_data = {24'b0, mem_raw_data[23:16]};
                    2'b11: mem_data = {24'b0, mem_raw_data[31:24]};
                    default: mem_data = 32'b0;
                endcase
            end
            default: mem_data = 32'b0;
        endcase
    end

    BankedMEM DMEM (
        .clk(clk),
        .writeEn(memrw),
        .address(y),
        .writeData(formatted_wdata),
        .byte_mask(byte_mask),
        .readData(mem_raw_data)
    );
endmodule