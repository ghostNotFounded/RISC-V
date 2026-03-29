module singleCycleCPU #(
    parameter BUS_SIZE = 32
) (
    input logic clk,
    input logic reset
);
    logic [31:0] pc_reg = 0;
    logic [31:0] instr_reg;

    always @(posedge clk) begin
        pc_reg <= pc_reg + 4;
    end

    instruction_memory imem (
        .addr(pc_reg[6:0]),
        .instruction(instr_reg)
    );

    wire pcsel, regwen, brun, bsel, asel, memrw;
    wire [3:0] aluop;
    wire [1:0] wbsel;

    controlUnit cu (
        .instr(instr_reg),
        .BrEq(0),
        .BrLT(0),

        .PCSel(pcsel),
        .RegWEn(regwen),
        .BrUn(brun),
        .BSel(bsel),
        .ASel(asel),
        .ALUOp(aluop),
        .MemRW(memrw),
        .WBSel(wbsel)
    );

    wire [31:0] immediate;
    immGen imm (
        .instr(instr_reg),
        .y(immediate)
    );

    wire [31:0] wb_data = 
    wire [31:0] rdata1, rdata2;
    regfile rf (
        .clk(clk),
        .reset(reset),
        .wenable(regwen),
        .rd(instr_reg[11:7]),
        .wdata(y),
        .rs1(instr_reg[19:15]),
        .rs2(instr_reg[24:20]),
        
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    wire zero;
    wire [31:0] y;

    wire [31:0] alu_a = asel ? pc : rdata1;
    wire [31:0] alu_b = asel ? immediate : rdata2;
    alu alu1 (
        .aluop(aluop),
        .A(alu_a),
        .B(alu_b),

        .zero(zero),
        .y(y)
    );
endmodule