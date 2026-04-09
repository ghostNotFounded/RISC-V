`ifndef CONSTS
`define CONSTS
    // OPCODES
    `define OPC_R               7'b0110011
    `define OPC_I               7'b0010011
    `define OPC_LOAD            7'b0000011
    `define OPC_STORE           7'b0100011
    `define OPC_BRANCH          7'b1100011
    `define OPC_JAL             7'b1101111
    `define OPC_JALR            7'b1100111
    `define OPC_LUI             7'b0110111
    `define OPC_AUIPC           7'b0010111

    // FUNCT3 (R)
    `define FUNCT3_ADD_SUB      3'h0
    `define FUNCT3_SLL          3'h1
    `define FUNCT3_SLT          3'h2
    `define FUNCT3_SLTU         3'h3
    `define FUNCT3_XOR          3'h4
    `define FUNCT3_SRL_SRA      3'h5
    `define FUNCT3_OR           3'h6
    `define FUNCT3_AND          3'h7

    // FUNCT7 (R)
    `define FUNCT7_SRA_SUB      7'h20

    // FUNCT3 (I)
    `define FUNCT3_ADDI         3'b000
    `define FUNCT3_ANDI         3'b111
    `define FUNCT3_ORI          3'b110
    `define FUNCT3_XORI         3'b100
    `define FUNCT3_SLTI         3'b010
    `define FUNCT3_SLTIU        3'b011
    `define FUNCT3_SRAI_SRLI    3'b101
    `define FUNCT3_SLLI         3'b001

    // FUNCT3 (LOAD)
    `define FUNCT3_LB           3'b000
    `define FUNCT3_LH           3'b001
    `define FUNCT3_LW           3'b010
    `define FUNCT3_LBU          3'b100 
    `define FUNCT3_LHU          3'b101

    // FUNCT3 (STORE)
    `define FUNCT3_SB           3'b000
    `define FUNCT3_SH           3'b001
    `define FUNCT3_SW           3'b010

    // FUNCT3 (BRANCH)
    `define FUNCT3_BEQ          3'b000
    `define FUNCT3_BNE          3'b001
    `define FUNCT3_BLT          3'b100
    `define FUNCT3_BGE          3'b101
    `define FUNCT3_BLTU         3'b110
    `define FUNCT3_BGEU         3'b111

    // ALU OPERATIONS
    `define ALU_ADD             4'd0
    `define ALU_SUB             4'd1
    `define ALU_AND             4'd2
    `define ALU_OR              4'd3
    `define ALU_XOR             4'd4

    `define ALU_SLL             4'd5
    `define ALU_SRL             4'd6
    `define ALU_SRA             4'd7

    `define ALU_SLT             4'd8
    `define ALU_SLTU            4'd9

    // Memory operation modes
    `define MEM_WORD            3'b000
    `define MEM_HWORD           3'b001
    `define MEM_BYTE            3'b010
    `define MEM_BYTE_U          3'b100
    `define MEM_HWORD_U         3'b101

    // ImmSel
    `define IMMSEL_I            3'b000
    `define IMMSEL_S            3'b001
    `define IMMSEL_B            3'b010
    `define IMMSEL_U            3'b011
    `define IMMSEL_J            3'b100

    // Write Back Operations
    `define WBSel_MEM           2'b00
    `define WBSel_ALU           2'b01
    `define WBSel_PC4           2'b10
`endif