`timescale 1ns/1ps
`include "consts.svh"

module BankedMEM (
    input  logic        clk,
    input  logic        writeEn,
    input  logic [31:0] address,
    input  logic [31:0] writeData,
    input  logic [2:0]  mode,        // 00: Word  01: Half Word  10: Byte 3rd bit for unsigned(1) signed(0)

    output logic [31:0] readData
);
    logic [31:0] mem [0:16383];

    logic [13:0] word_addr = address[15:2];  // 14 bits for 16384 words
    logic [1:0]  byte_off  = address[1:0];

    // Synchronous write
    always @(posedge clk) begin
        if (writeEn) begin
            case (mode)
                `MEM_WORD:  mem[word_addr] <= writeData;

                `MEM_HWORD: begin
                    case (byte_off[1])
                        1'b0: mem[word_addr][15:0]  <= writeData[15:0];
                        1'b1: mem[word_addr][31:16] <= writeData[15:0];
                    endcase
                end

                `MEM_BYTE: begin
                    case (byte_off)
                        2'b00: mem[word_addr][7:0]   <= writeData[7:0];
                        2'b01: mem[word_addr][15:8]  <= writeData[7:0];
                        2'b10: mem[word_addr][23:16] <= writeData[7:0];
                        2'b11: mem[word_addr][31:24] <= writeData[7:0];
                    endcase
                end

                default: ;
            endcase
        end
    end

    // Combinational read with zero-extension
    always @(*) begin
        case (mode)
            `MEM_WORD:  readData = mem[word_addr];

            `MEM_HWORD: begin
                case (byte_off[1])
                    1'b0: readData = {{16{mem[word_addr][15]}}, mem[word_addr][15:0]};
                    1'b1: readData = {{16{mem[word_addr][31]}}, mem[word_addr][31:16]};
                    default: readData = 32'b0;
                endcase
            end

            `MEM_BYTE: begin
                case (byte_off)
                    2'b00: readData = {{24{mem[word_addr][7]}},  mem[word_addr][7:0]};
                    2'b01: readData = {{24{mem[word_addr][15]}}, mem[word_addr][15:8]};
                    2'b10: readData = {{24{mem[word_addr][23]}}, mem[word_addr][23:16]};
                    2'b11: readData = {{24{mem[word_addr][31]}}, mem[word_addr][31:24]};
                    default: readData = 32'b0;
                endcase
            end

            `MEM_HWORD_U: begin
                case (byte_off[1])
                    1'b0: readData = {16'b0, mem[word_addr][15:0]};
                    1'b1: readData = {16'b0, mem[word_addr][31:16]};
                    default: readData = 32'b0;
                endcase
            end

            `MEM_BYTE_U: begin
                case (byte_off)
                    2'b00: readData = {24'b0, mem[word_addr][7:0]};
                    2'b01: readData = {24'b0, mem[word_addr][15:8]};
                    2'b10: readData = {24'b0, mem[word_addr][23:16]};
                    2'b11: readData = {24'b0, mem[word_addr][31:24]};
                    default: readData = 32'b0;
                endcase
            end

            default: readData = 32'b0;
        endcase
    end

endmodule