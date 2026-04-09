`timescale 1ns/1ps

module instruction_memory #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 16384
)(
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] instruction
);
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    initial begin
        $readmemh("program.hex", mem);
    end

    assign instruction = mem[14'(addr >> 2)];
endmodule