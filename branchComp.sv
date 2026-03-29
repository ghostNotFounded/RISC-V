`timescale 1ns/1ps

module branchComp #(
    parameter BUS_SIZE = 32
) (
    input  logic [BUS_SIZE-1:0] A,
    input  logic [BUS_SIZE-1:0] B,
    input  logic                BrUn,

    output logic                BrEq,
    output logic                BrLT
);

    always_comb begin
        BrEq = (A == B);
        
        if (BrUn) begin
            BrLT = ($unsigned(A) < $unsigned(B));
        end else begin
            BrLT = ($signed(A) < $signed(B));
        end
    end

endmodule