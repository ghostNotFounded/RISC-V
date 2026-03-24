module alu #(
    parameter BUS_SIZE = 32
) (
    input   logic [2:0]             aluop,
    input   logic signed [BUS_SIZE-1:0]    A,
    input   logic signed [BUS_SIZE-1:0]    B,

    output  logic                   zero,
    output  logic [BUS_SIZE-1:0]    y
);
    always @(*) begin
        case (aluop)
            3'b001: y = (A + B);                       // ADD
            3'b000: y = A - B;                         // SUB
            3'b010: y = A & B;                         // AND
            3'b011: y = A | B;                         // OR
            3'b100: y = (A << B[4:0]);                 // SLL
            3'b101: y = (A >> B[4:0]);                 // SRL
            3'b110: y = (A < B) ? 32'b1 : 32'b0;       // SLT
            3'b111: y = 32'b0;                             // Output zero
            default: y = 32'b0;
        endcase
    end

    assign zero = (y == 32'b0);
endmodule