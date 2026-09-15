`timescale 1ns/1ps
`include "consts.svh"

module controlUnit #(
    parameter BUS_SIZE = 32
) (
    input logic [31:0] instr,
    input logic BrEq,
    input logic BrLT,

    output logic PCSel,
    output logic RegWEn,
    output logic BrUn,
    output logic BSel,
    output logic [1:0] ASel,
    output logic [2:0] Mode,
    output logic [3:0] ALUOp,
    output logic MemRW,
    output logic [1:0] WBSel,
    output logic [2:0] immSel,
    output logic MultEn,
    output logic DivEn,
    output logic [1:0] MDUOp
);
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin
        Mode = 0;
        PCSel = 0;
        RegWEn = 0;
        BrUn = 0;
        BSel = 0;
        ASel = 0;
        ALUOp = 0;
        MemRW = 0;
        WBSel = 0;
        immSel = 0;
        MultEn = 0;
        DivEn = 0;
        MDUOp = 0;

        case (instr[6:0])
            `OPC_R: begin
                RegWEn = 1;
                WBSel = `WBSel_ALU;

                if (funct7 == `FUNCT7_MUL) begin
                    MDUOp = funct3[1:0];
                    if (funct3[2] == 1'b0) begin
                        MultEn = 1;
                    end else begin
                        DivEn = 1;
                    end
                end else begin
                    case (funct3)
                        `FUNCT3_ADD_SUB:    ALUOp = (funct7 == `FUNCT7_SRA_SUB) ? `ALU_SUB : `ALU_ADD;
                        `FUNCT3_SLL:        ALUOp = `ALU_SLL;
                        `FUNCT3_SRL_SRA:    ALUOp = (funct7 == `FUNCT7_SRA_SUB) ? `ALU_SRA : `ALU_SRL;
                        `FUNCT3_SLT:        ALUOp = `ALU_SLT;
                        `FUNCT3_SLTU:       ALUOp = `ALU_SLTU;
                        `FUNCT3_XOR:        ALUOp = `ALU_XOR;
                        `FUNCT3_OR:         ALUOp = `ALU_OR;
                        `FUNCT3_AND:        ALUOp = `ALU_AND;

                        default:            ALUOp = `ALU_ADD;
                    endcase
                end
            end

            `OPC_I: begin
                RegWEn = 1;
                BSel = 1;
                WBSel = `WBSel_ALU;
                immSel = `IMMSEL_I;

                case (funct3)
                    `FUNCT3_ADDI:       ALUOp = `ALU_ADD;
                    `FUNCT3_XORI:       ALUOp = `ALU_XOR;
                    `FUNCT3_ORI:        ALUOp = `ALU_OR;
                    `FUNCT3_ANDI:       ALUOp = `ALU_AND;
                    `FUNCT3_SLLI:       ALUOp = `ALU_SLL;
                    `FUNCT3_SRAI_SRLI:  ALUOp = (funct7 == `FUNCT7_SRA_SUB) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_SLTI:       ALUOp = `ALU_SLT;
                    `FUNCT3_SLTIU:      ALUOp = `ALU_SLTU;

                    default:            ALUOp = `ALU_ADD;
                endcase
            end

            `OPC_STORE: begin
                BSel = 1;
                ALUOp = `ALU_ADD;
                MemRW = 1;
                immSel = `IMMSEL_S;

                case (funct3)
                    `FUNCT3_SB: Mode = `MEM_BYTE;
                    `FUNCT3_SW: Mode = `MEM_WORD;
                    `FUNCT3_SH: Mode = `MEM_HWORD; 
                    default: ;
                endcase
            end
            
            `OPC_BRANCH: begin
                ASel = 1;
                BSel = 1;
                ALUOp = `ALU_ADD;
                immSel = `IMMSEL_B;

                case (funct3)
                    `FUNCT3_BEQ:        PCSel = BrEq ? 1 : 0;
                    `FUNCT3_BNE:        PCSel = ~BrEq ? 1 : 0;
                    `FUNCT3_BLT:        PCSel = (BrLT) ? 1 : 0;
                    `FUNCT3_BGE:        PCSel = (~BrLT) ? 1 : 0;
                    `FUNCT3_BLTU: begin
                                        BrUn = 1;
                                        PCSel = (BrLT) ? 1 : 0;
                    end
                    `FUNCT3_BGEU: begin
                                        BrUn = 1;
                                        PCSel = (~BrLT) ? 1 : 0;
                    end
                    default: PCSel = 0;
                endcase
            end

            `OPC_JAL: begin
                PCSel = 1;
                RegWEn = 1;
                BSel = 1;
                ASel = 1;
                ALUOp = `ALU_ADD;
                WBSel = `WBSel_PC4;
                immSel = `IMMSEL_J;
            end

            `OPC_JALR: begin
                PCSel = 1;
                RegWEn = 1;
                BSel = 1;
                ALUOp = `ALU_ADD;
                WBSel = `WBSel_PC4;
                immSel = `IMMSEL_I;
            end

            `OPC_LOAD: begin
                BSel = 1;
                RegWEn = 1;
                ALUOp = `ALU_ADD;
                immSel = `IMMSEL_I;

                case (funct3)
                    `FUNCT3_LW: Mode = `MEM_WORD;
                    `FUNCT3_LH: Mode = `MEM_HWORD; 
                    `FUNCT3_LB: Mode = `MEM_BYTE;
                    `FUNCT3_LHU: Mode = `MEM_HWORD_U; 
                    `FUNCT3_LBU: Mode = `MEM_BYTE_U;
                    default: ;
                endcase
            end

            `OPC_LUI: begin
                RegWEn = 1;
                WBSel = `WBSel_ALU;
                immSel = `IMMSEL_U;
                ALUOp = `ALU_ADD;
                BSel = 1;
                ASel = 2'b10;
            end

            `OPC_AUIPC: begin
                RegWEn = 1;
                WBSel = `WBSel_ALU;
                immSel = `IMMSEL_U;
                ALUOp = `ALU_ADD;
                BSel = 1;
                ASel = 2'b01;
            end

            `OPC_FENCE: begin
                RegWEn = 0;
                MemRW  = 0;
            end

            `OPC_SYSTEM: begin
                RegWEn = 0;
                MemRW  = 0;
            end

            default: RegWEn = 0;
        endcase
    end

endmodule