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

    instruction_memory imem (
        .addr(pc_reg[6:0]),
        .instruction(instr_reg)
    );

    logic pcsel, regwen, brun, bsel, asel, memrw, breq, brlt;
    logic [3:0] aluop;
    logic [1:0] wbsel;

    controlUnit cu (
        .instr(instr_reg),
        .BrEq(breq),
        .BrLT(brlt),

        .PCSel(pcsel),
        .RegWEn(regwen),
        .BrUn(brun),
        .BSel(bsel),
        .ASel(asel),
        .ALUOp(aluop),
        .MemRW(memrw),
        .WBSel(wbsel)
    );

    logic [31:0] immediate;
    immGen imm (
        .instr(instr_reg),
        .y(immediate)
    );

    // logic [31:0] wb_data = 
    logic [31:0] rdata1, rdata2;
    regfile rf (
        .clk(clk),
        .wenable(regwen),
        .rd(instr_reg[11:7]),
        .wdata(y),
        .rs1(instr_reg[19:15]),
        .rs2(instr_reg[24:20]),
        
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    branchComp comparator (
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

    assign alu_a = asel ? pc_reg : rdata1; 
    assign alu_b = bsel ? immediate : rdata2;
    alu alu1 (
        .aluop(aluop),
        .A(alu_a),
        .B(alu_b),

        .zero(zero),
        .y(y)
    );
endmodule