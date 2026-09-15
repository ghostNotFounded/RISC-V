`timescale 1ns/1ps
`include "consts.svh"

module BankedMEM (
    input  logic        clk,
    input  logic        writeEn,
    input  logic [31:0] address,
    input  logic [31:0] writeData,
    input  logic [3:0]  byte_mask,

    output logic [31:0] readData
);
    logic [31:0] mem [0:16383];

    logic [13:0] word_addr;
    assign word_addr = address[15:2];

    // Synchronous write
    always @(posedge clk) begin
        if (writeEn) begin
            if (byte_mask[0]) mem[word_addr][7:0]   <= writeData[7:0];
            if (byte_mask[1]) mem[word_addr][15:8]  <= writeData[15:8];
            if (byte_mask[2]) mem[word_addr][23:16] <= writeData[23:16];
            if (byte_mask[3]) mem[word_addr][31:24] <= writeData[31:24];
        end
    end

    // Combinational read
    assign readData = mem[word_addr];

endmodule