`timescale 1ns/1ps
`include "consts.svh"

module top_multi_cycle #(
    parameter BUS_SIZE = 32
) (
    input logic clk,
    input logic reset
);

    // Instruction memory interface signals
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    // Data memory interface signals
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_we;
    logic [3:0]  dmem_byte_mask;
    logic [31:0] dmem_rdata;

    // Instantiate ASIC 5-stage CPU core
    cpu CPU_inst (
        .clk(clk),
        .rst_n(~reset),

        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),

        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_byte_mask(dmem_byte_mask),
        .dmem_rdata(dmem_rdata)
    );

    // Instantiate Instruction Memory
    instruction_memory IMEM (
        .addr(imem_addr[15:0]),
        .instruction(imem_rdata)
    );

    // Instantiate External Data Memory with Byte Mask
    BankedMEM DMEM (
        .clk(clk),
        .writeEn(dmem_we),
        .address(dmem_addr),
        .writeData(dmem_wdata),
        .byte_mask(dmem_byte_mask),
        .readData(dmem_rdata)
    );

endmodule
