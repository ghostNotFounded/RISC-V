`timescale 1ns/1ps
`include "consts.svh"

module CPU #(
    parameter BUS_SIZE = 32
) (
    input logic clk,
    input logic reset,
    
    output logic [31:0] debug_out
);

// IF STAGE
    logic [31:0] pc_reg;
    logic [31:0] if_instr;

    always_ff @(posedge clk) begin
        if (reset)       pc_reg <= 0;
        else if (flush)  pc_reg <= ex_y;        // branch taken: jump to target
        else if (stall)  pc_reg <= pc_reg;          // stall: hold PC
        else             pc_reg <= pc_reg + 4;
    end

    instruction_memory IMEM (
        .addr(pc_reg[15:0]),
        .instruction(if_instr)
    );

// IF/ID pipeline register
    logic [31:0] if_id_pc, if_id_instr;

    always_ff @(posedge clk) begin
        if (reset || flush) begin
            if_id_pc    <= 0;
            if_id_instr <= 32'h0000_0013;
        end else if (!stall) begin
            if_id_pc    <= pc_reg;
            if_id_instr <= if_instr;
        end
    end

// ID STAGE
    logic        id_pcsel, id_regwen, id_brun, id_bsel, id_memrw;
    logic [3:0]  id_aluop;
    logic [2:0]  id_imm_sel, id_mode;
    logic [1:0]  id_wbsel, id_asel;
    logic        id_breq, id_brlt;

    controlUnit CU (
        .instr(if_id_instr),
        .BrEq(id_breq),
        .BrLT(id_brlt),
        .PCSel(id_pcsel),
        .RegWEn(id_regwen),
        .BrUn(id_brun),
        .BSel(id_bsel),
        .MemRW(id_memrw),
        .ALUOp(id_aluop),
        .Mode(id_mode),
        .immSel(id_imm_sel),
        .WBSel(id_wbsel),
        .ASel(id_asel)
    );

    logic [31:0] id_immediate;
    immGen IG (
        .instr(if_id_instr),
        .immSel(id_imm_sel),
        .y(id_immediate)
    );

    logic [31:0] wb_data;
    always_comb begin
        case (mem_wb_wbsel)
            `WBSel_MEM: wb_data = mem_wb_mem_data;
            `WBSel_PC4: wb_data = mem_wb_pc + 4;
            default:    wb_data = mem_wb_y;
        endcase
    end

    logic [31:0] id_rdata1, id_rdata2;
    regfile RF (
        .clk(clk),
        .wenable(mem_wb_regwen),
        .rd(mem_wb_rd),
        .wdata(wb_data),
        .rs1(if_id_instr[19:15]),
        .rs2(if_id_instr[24:20]),
        .rdata1(id_rdata1),
        .rdata2(id_rdata2)
    );

    branchComp Comparator (
        .A(id_rdata1),
        .B(id_rdata2),
        .BrUn(id_brun),
        .BrEq(id_breq),
        .BrLT(id_brlt)
    );

    logic stall;
    assign stall = (id_ex_wbsel == `WBSel_MEM)
                && (id_ex_regwen)
                && (id_ex_rd != 5'b0)
                && ((id_ex_rd == if_id_instr[19:15]) ||
                    (id_ex_rd == if_id_instr[24:20]));

// ID/EX pipeline register
    logic [31:0] id_ex_pc, id_ex_rdata1, id_ex_rdata2, id_ex_imm;
    logic [4:0]  id_ex_rd, id_ex_rs1, id_ex_rs2;
    logic        id_ex_regwen, id_ex_brun, id_ex_bsel, id_ex_memrw;
    logic        id_ex_pcsel;
    logic [3:0]  id_ex_aluop;
    logic [2:0]  id_ex_mode;
    logic [1:0]  id_ex_wbsel, id_ex_asel;

    always_ff @(posedge clk) begin
        if (reset || stall) begin
            id_ex_pc      <= 0;
            id_ex_rdata1  <= 0;
            id_ex_rdata2  <= 0;
            id_ex_imm     <= 0;
            id_ex_rd      <= 0;
            id_ex_rs1     <= 0;
            id_ex_rs2     <= 0;
            id_ex_pcsel   <= 0;
            id_ex_regwen  <= 0;
            id_ex_brun    <= 0;
            id_ex_bsel    <= 0;
            id_ex_memrw   <= 0;
            id_ex_aluop   <= 0;
            id_ex_mode    <= 0;
            id_ex_wbsel   <= 0;
            id_ex_asel    <= 0;
        end else begin
            id_ex_pc      <= if_id_pc;
            id_ex_rdata1  <= id_rdata1;
            id_ex_rdata2  <= id_rdata2;
            id_ex_imm     <= id_immediate;
            id_ex_rd      <= if_id_instr[11:7];
            id_ex_rs1     <= if_id_instr[19:15];
            id_ex_rs2     <= if_id_instr[24:20];
            id_ex_pcsel   <= id_pcsel;
            id_ex_regwen  <= id_regwen;
            id_ex_brun    <= id_brun;
            id_ex_bsel    <= id_bsel;
            id_ex_memrw   <= id_memrw;
            id_ex_aluop   <= id_aluop;
            id_ex_mode    <= id_mode;
            id_ex_wbsel   <= id_wbsel;
            id_ex_asel    <= id_asel;
        end
    end

// EX STAGE

    logic [1:0] fwd_a, fwd_b;

    always_comb begin
        // Forward A
        if (ex_mem_regwen && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs1)
            fwd_a = 2'b01;
        else if (mem_wb_regwen && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs1)
            fwd_a = 2'b10;
        else
            fwd_a = 2'b00;

        // Forward B
        if (ex_mem_regwen && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs2)
            fwd_b = 2'b01;
        else if (mem_wb_regwen && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs2)
            fwd_b = 2'b10;
        else
            fwd_b = 2'b00;
    end

    logic [31:0] ex_rdata1, ex_rdata2;
    always_comb begin
        case (fwd_a)
            2'b01:   ex_rdata1 = ex_mem_y;
            2'b10:   ex_rdata1 = wb_data;
            default: ex_rdata1 = id_ex_rdata1;
        endcase

        case (fwd_b)
            2'b01:   ex_rdata2 = ex_mem_y;
            2'b10:   ex_rdata2 = wb_data;
            default: ex_rdata2 = id_ex_rdata2;
        endcase
    end

    logic [31:0] ex_alu_a, ex_alu_b;
    assign ex_alu_a = (id_ex_asel == 2'b10) ? 32'b0
                    : (id_ex_asel == 2'b01) ? id_ex_pc
                    :                         ex_rdata1;
    assign ex_alu_b = id_ex_bsel ? id_ex_imm : ex_rdata2;

    logic        ex_zero;
    logic [31:0] ex_y;
    alu ALU (
        .aluop(id_ex_aluop),
        .A(ex_alu_a),
        .B(ex_alu_b),
        .zero(ex_zero),
        .y(ex_y)
    );

    logic flush;
    assign flush = id_ex_pcsel;

// EX/MEM pipeline register
    logic [31:0] ex_mem_pc, ex_mem_y, ex_mem_rdata2;
    logic [4:0]  ex_mem_rd;
    logic        ex_mem_regwen, ex_mem_memrw, ex_mem_pcsel;
    logic [2:0]  ex_mem_mode;
    logic [1:0]  ex_mem_wbsel;

    always_ff @(posedge clk) begin
        if (reset || flush) begin
            ex_mem_pc     <= 0;
            ex_mem_y      <= 0;
            ex_mem_rdata2 <= 0;
            ex_mem_rd     <= 0;
            ex_mem_regwen <= 0;
            ex_mem_memrw  <= 0;
            ex_mem_pcsel  <= 0;
            ex_mem_mode   <= 0;
            ex_mem_wbsel  <= 0;
        end else begin
            ex_mem_pc     <= id_ex_pc;
            ex_mem_y      <= ex_y;
            ex_mem_rdata2 <= ex_rdata2;     // forwarded value (for stores)
            ex_mem_rd     <= id_ex_rd;
            ex_mem_regwen <= id_ex_regwen;
            ex_mem_memrw  <= id_ex_memrw;
            ex_mem_pcsel  <= id_ex_pcsel;
            ex_mem_mode   <= id_ex_mode;
            ex_mem_wbsel  <= id_ex_wbsel;
        end
    end

// MEM STAGE

    logic [31:0] mem_read_data;
    BankedMEM DMEM (
        .clk(clk),
        .mode(ex_mem_mode),
        .writeEn(ex_mem_memrw),
        .address(ex_mem_y),
        .writeData(ex_mem_rdata2),
        .readData(mem_read_data)
    );

// MEM/WB pipeline register
    logic [31:0] mem_wb_pc, mem_wb_y, mem_wb_mem_data;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_regwen;
    logic [1:0]  mem_wb_wbsel;

    always_ff @(posedge clk) begin
        if (reset) begin
            mem_wb_pc       <= 0;
            mem_wb_y        <= 0;
            mem_wb_mem_data <= 0;
            mem_wb_rd       <= 0;
            mem_wb_regwen   <= 0;
            mem_wb_wbsel    <= 0;
        end else begin
            mem_wb_pc       <= ex_mem_pc;
            mem_wb_y        <= ex_mem_y;
            mem_wb_mem_data <= mem_read_data;
            mem_wb_rd       <= ex_mem_rd;
            mem_wb_regwen   <= ex_mem_regwen;
            mem_wb_wbsel    <= ex_mem_wbsel;
        end
    end
    
    assign debug_out = mem_wb_y;

endmodule