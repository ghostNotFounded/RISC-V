`timescale 1ns/1ps

module immGen #(
    parameter BUS_SIZE = 32
) (
    input logic [31:0] instr,

    output logic [31:0] y
);
    wire [31:0] y_imm, y_store, y_branch, y_jump, y_upper;

    assign y_imm = {{20{instr[31]}}, instr[31:20]};
    assign y_store = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign y_branch = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    assign y_jump = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    assign y_upper = {instr[31:12], 12'b0};

    always @(*) begin
        case (instr[6:0])
            7'b0010011: y = y_imm;      // addi xori ori andi slli srli srai slti sltiu
            7'b0000011: y = y_imm;      // lb lh lw lbu lhu
            7'b0100011: y = y_store;    // sb sh sw
            7'b1100011: y = y_branch;   // beq bne blt bge bltu bgeu
            7'b1101111: y = y_jump;     // jal
            7'b1100111: y = y_imm;      // jalr
            7'b0110111: y = y_upper;    // lui
            7'b0010111: y = y_upper;    // auipc
            default:    y = 32'b0;
        endcase
    end
endmodule