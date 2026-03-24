`timescale 1ns/1ps

module tb_immGen;

    // --------------------------------------------------------
    // DUT ports
    // --------------------------------------------------------
    logic [31:0] instr;
    logic [31:0] y;

    immGen #(.BUS_SIZE(32)) dut (
        .instr (instr),
        .y     (y)
    );

    int pass_count = 0;
    int fail_count = 0;

    // --------------------------------------------------------
    // RISC-V opcodes
    // --------------------------------------------------------
    localparam OP_ITYPE  = 7'b0010011;  // addi, xori, ori, andi, slli, srli, srai, slti, sltiu
    localparam OP_LOAD   = 7'b0000011;  // lb, lh, lw, lbu, lhu
    localparam OP_STORE  = 7'b0100011;  // sb, sh, sw
    localparam OP_BRANCH = 7'b1100011;  // beq, bne, blt, bge, bltu, bgeu
    localparam OP_JAL    = 7'b1101111;  // jal
    localparam OP_JALR   = 7'b1100111;  // jalr
    localparam OP_LUI    = 7'b0110111;  // lui
    localparam OP_AUIPC  = 7'b0010111;  // auipc

    // --------------------------------------------------------
    // Task: drive instr, wait for combinational settle, check
    // --------------------------------------------------------
    task automatic check_imm(
        input [31:0] instruction,
        input [31:0] expected,
        input string test_name
    );
        instr = instruction;
        #5;
        if (y === expected) begin
            $display("  PASS  [%s]  instr=0x%08h -> y=0x%08h", test_name, instruction, y);
            pass_count++;
        end else begin
            $display("  FAIL  [%s]  instr=0x%08h", test_name, instruction);
            $display("         got      0x%08h", y);
            $display("         expected 0x%08h", expected);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------
    // Software model functions — mirror the corrected RTL
    // --------------------------------------------------------
    function automatic logic [31:0] f_imm(input [31:0] i);
        f_imm = {{20{i[31]}}, i[31:20]};
    endfunction

    function automatic logic [31:0] f_store(input [31:0] i);
        f_store = {{20{i[31]}}, i[31:25], i[11:7]};
    endfunction

    function automatic logic [31:0] f_branch(input [31:0] i);
        f_branch = {{20{i[31]}}, i[7], i[30:25], i[11:8], 1'b0};
    endfunction

    function automatic logic [31:0] f_jump(input [31:0] i);
        // Corrected JAL: {{12{i[31]}}, i[19:12], i[20], i[30:21], 1'b0}
        f_jump = {{12{i[31]}}, i[19:12], i[20], i[30:21], 1'b0};
    endfunction

    function automatic logic [31:0] f_upper(input [31:0] i);
        // U-type: upper 20 bits kept, lower 12 zeroed — no sign extension
        f_upper = {i[31:12], 12'b0};
    endfunction

    // --------------------------------------------------------
    // Instruction encoders
    // Sets only the immediate bits; rd/rs/funct fields left 0.
    // --------------------------------------------------------
    function automatic logic [31:0] mk_itype(input logic [6:0] op, input logic [11:0] imm12);
        mk_itype = {imm12, 20'b0} | {25'b0, op};
    endfunction

    function automatic logic [31:0] mk_stype(input logic [11:0] imm12);
        // imm[11:5]->instr[31:25], imm[4:0]->instr[11:7]
        mk_stype = {imm12[11:5], 13'b0, imm12[4:0], 7'b0} | {25'b0, OP_STORE};
    endfunction

    function automatic logic [31:0] mk_btype(input logic [12:1] imm13);
        // imm[12]->instr[31], imm[10:5]->instr[30:25],
        // imm[4:1]->instr[11:8], imm[11]->instr[7]
        mk_btype = {imm13[12], imm13[10:5], 13'b0, imm13[4:1], imm13[11], 7'b0}
                   | {25'b0, OP_BRANCH};
    endfunction

    function automatic logic [31:0] mk_jtype(input logic [20:1] imm21);
        // imm[20]->instr[31], imm[10:1]->instr[30:21],
        // imm[11]->instr[20], imm[19:12]->instr[19:12]
        mk_jtype = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], 12'b0}
                   | {25'b0, OP_JAL};
    endfunction

    function automatic logic [31:0] mk_utype(input logic [6:0] op, input logic [31:12] imm20);
        mk_utype = {imm20, 12'b0} | {25'b0, op};
    endfunction

    // --------------------------------------------------------
    // Test stimulus
    // --------------------------------------------------------
    logic [31:0] iw;

    string vcd_file;
    initial begin
        if ($value$plusargs("vcd=%s", vcd_file))
            $dumpfile(vcd_file);
        else
            $dumpfile("tb_immGen.vcd");
        $dumpvars(0, dut);

        instr = 0;
        #10;

        // ====================================================
        // TEST 1: I-type — ITYPE opcode (addi, xori, etc.)
        // ====================================================
        $display("\n=== TEST 1: I-type immediate (OP_ITYPE) ===");

        iw = mk_itype(OP_ITYPE, 12'h001);
        check_imm(iw, f_imm(iw), "itype_pos_1");

        iw = mk_itype(OP_ITYPE, 12'h7FF);
        check_imm(iw, f_imm(iw), "itype_max_pos_2047");

        iw = mk_itype(OP_ITYPE, 12'h800);
        check_imm(iw, f_imm(iw), "itype_min_neg_-2048");

        iw = mk_itype(OP_ITYPE, 12'hFFF);
        check_imm(iw, f_imm(iw), "itype_neg_1");

        iw = mk_itype(OP_ITYPE, 12'h000);
        check_imm(iw, f_imm(iw), "itype_zero");

        iw = mk_itype(OP_ITYPE, 12'hABC);
        check_imm(iw, f_imm(iw), "itype_pattern_ABC");

        // ====================================================
        // TEST 2: I-type — LOAD opcode (lb, lh, lw, etc.)
        // Same immediate format, different opcode
        // ====================================================
        $display("\n=== TEST 2: I-type immediate (OP_LOAD) ===");

        iw = mk_itype(OP_LOAD, 12'h004);
        check_imm(iw, f_imm(iw), "load_offset_4");

        iw = mk_itype(OP_LOAD, 12'h7FF);
        check_imm(iw, f_imm(iw), "load_max_pos");

        iw = mk_itype(OP_LOAD, 12'hFFF);
        check_imm(iw, f_imm(iw), "load_neg_1");

        iw = mk_itype(OP_LOAD, 12'h800);
        check_imm(iw, f_imm(iw), "load_min_neg");

        // ====================================================
        // TEST 3: I-type — JALR opcode
        // ====================================================
        $display("\n=== TEST 3: I-type immediate (OP_JALR) ===");

        iw = mk_itype(OP_JALR, 12'h004);
        check_imm(iw, f_imm(iw), "jalr_offset_4");

        iw = mk_itype(OP_JALR, 12'hFFF);
        check_imm(iw, f_imm(iw), "jalr_neg_1");

        iw = mk_itype(OP_JALR, 12'h7FF);
        check_imm(iw, f_imm(iw), "jalr_max_pos");

        // ====================================================
        // TEST 4: S-type — STORE opcode
        // Immediate split across instr[31:25] and instr[11:7]
        // ====================================================
        $display("\n=== TEST 4: S-type immediate (OP_STORE) ===");

        iw = mk_stype(12'h001);
        check_imm(iw, f_store(iw), "store_offset_1");

        iw = mk_stype(12'h7FF);
        check_imm(iw, f_store(iw), "store_max_pos");

        iw = mk_stype(12'h800);
        check_imm(iw, f_store(iw), "store_min_neg");

        iw = mk_stype(12'hFFF);
        check_imm(iw, f_store(iw), "store_neg_1");

        iw = mk_stype(12'h000);
        check_imm(iw, f_store(iw), "store_zero");

        iw = mk_stype(12'h5A5);
        check_imm(iw, f_store(iw), "store_pattern_5A5");

        // ====================================================
        // TEST 5: B-type — BRANCH opcode
        // Bit 0 always 0; bits are scrambled across the word
        // ====================================================
        $display("\n=== TEST 5: B-type immediate (OP_BRANCH) ===");

        iw = mk_btype(12'h002);
        check_imm(iw, f_branch(iw), "branch_offset_2");

        iw = mk_btype(12'h7FE);
        check_imm(iw, f_branch(iw), "branch_max_pos");

        iw = mk_btype(12'h800);
        check_imm(iw, f_branch(iw), "branch_min_neg");

        iw = mk_btype(12'hFFE);
        check_imm(iw, f_branch(iw), "branch_neg_2");

        iw = mk_btype(12'h000);
        check_imm(iw, f_branch(iw), "branch_zero");

        iw = mk_btype(12'hAAA);
        check_imm(iw, f_branch(iw), "branch_pattern_AAA");

        // ====================================================
        // TEST 6: J-type — JAL opcode
        // 21-bit immediate, bit 0 always 0, heavily scrambled
        // ====================================================
        $display("\n=== TEST 6: J-type immediate (OP_JAL) ===");

        iw = mk_jtype(20'h00002);
        check_imm(iw, f_jump(iw), "jal_offset_2");

        iw = mk_jtype(20'hFFFFE);
        check_imm(iw, f_jump(iw), "jal_max_pos");

        iw = mk_jtype(20'h80000);
        check_imm(iw, f_jump(iw), "jal_min_neg");

        iw = mk_jtype(20'hFFFFF);
        check_imm(iw, f_jump(iw), "jal_neg_2");

        iw = mk_jtype(20'h00000);
        check_imm(iw, f_jump(iw), "jal_zero");

        iw = mk_jtype(20'hAAAAA);
        check_imm(iw, f_jump(iw), "jal_pattern");

        // ====================================================
        // TEST 7: U-type — LUI and AUIPC
        // Upper 20 bits straight through; lower 12 zeroed
        // ====================================================
        $display("\n=== TEST 7: U-type immediate (LUI / AUIPC) ===");

        iw = mk_utype(OP_LUI, 20'h00001);
        check_imm(iw, f_upper(iw), "lui_1");

        iw = mk_utype(OP_LUI, 20'hFFFFF);
        check_imm(iw, f_upper(iw), "lui_all_ones");

        iw = mk_utype(OP_LUI, 20'h00000);
        check_imm(iw, f_upper(iw), "lui_zero");

        iw = mk_utype(OP_LUI, 20'hAAAAA);
        check_imm(iw, f_upper(iw), "lui_pattern_A");

        iw = mk_utype(OP_LUI, 20'h80000);
        check_imm(iw, f_upper(iw), "lui_msb_only");

        iw = mk_utype(OP_AUIPC, 20'h00001);
        check_imm(iw, f_upper(iw), "auipc_1");

        iw = mk_utype(OP_AUIPC, 20'hFFFFF);
        check_imm(iw, f_upper(iw), "auipc_all_ones");

        iw = mk_utype(OP_AUIPC, 20'h55555);
        check_imm(iw, f_upper(iw), "auipc_pattern_5");

        // ====================================================
        // TEST 8: Real RISC-V instruction encodings
        // Hand-assembled instructions with known correct values
        // ====================================================
        $display("\n=== TEST 8: Real RISC-V encodings ===");

        // ADDI x1, x0, 5   -> imm = +5
        check_imm(32'h00500093, 32'h00000005, "addi_x1_x0_5");

        // ADDI x1, x0, -1  -> imm = -1
        check_imm(32'hFFF00093, 32'hFFFFFFFF, "addi_x1_x0_neg1");

        // LW x1, 4(x2)     -> imm = +4
        check_imm(32'h00412083, 32'h00000004, "lw_x1_4_x2");

        // SW x2, 8(x3)     -> imm = +8
        check_imm(32'h00218423, 32'h00000008, "sw_x2_8_x3");

        // BEQ x0, x0, +4   -> imm = +4
        check_imm(32'h00000263, 32'h00000004, "beq_x0_x0_4");

        // JAL x0, +4       -> imm = +4
        check_imm(32'h0040006F, 32'h00000004, "jal_x0_4");

        // LUI x1, 1        -> imm = 0x00001000
        check_imm(32'h000010B7, 32'h00001000, "lui_x1_1");

        // AUIPC x1, 1      -> imm = 0x00001000
        check_imm(32'h00001097, 32'h00001000, "auipc_x1_1");

        // JALR x0, x1, 0   -> imm = 0
        check_imm(32'h00008067, 32'h00000000, "jalr_x0_x1_0");

        // ====================================================
        // TEST 9: Sign extension — upper bits must match sign
        // ====================================================
        $display("\n=== TEST 9: Sign extension correctness ===");

        iw = mk_itype(OP_ITYPE, 12'hFFF); // sign=1 -> upper 20 bits all 1
        check_imm(iw, 32'hFFFFFFFF, "itype_signext_all_ones");

        iw = mk_itype(OP_ITYPE, 12'h7FF); // sign=0 -> upper 20 bits all 0
        check_imm(iw, 32'h000007FF, "itype_signext_all_zeros");

        iw = mk_stype(12'hFFF);
        check_imm(iw, 32'hFFFFFFFF, "stype_signext_all_ones");

        iw = mk_btype(12'hFFE);
        check_imm(iw, 32'hFFFFFFFC, "btype_signext_all_ones");

        iw = mk_jtype(20'hFFFFF);
        check_imm(iw, 32'hFFFFFFFE, "jtype_signext_all_ones");

        // U-type: no sign extension; upper bits come from instr directly
        iw = mk_utype(OP_LUI, 20'hFFFFF);
        check_imm(iw, 32'hFFFFF000, "utype_upper_preserved_low_zeroed");

        iw = mk_utype(OP_LUI, 20'h00000);
        check_imm(iw, 32'h00000000, "utype_zero_low_12_zeroed");

        // ====================================================
        // TEST 10: Default opcode -> output must be 0
        // ====================================================
        $display("\n=== TEST 10: Default case (unknown opcode) ===");
        check_imm(32'hFFFFFFE0 | 32'b0000000, 32'h00000000, "default_opcode_0x00");
        check_imm(32'hFFFFFFE0 | 32'b0101010, 32'h00000000, "default_opcode_0x2A");
        check_imm(32'hFFFFFFE0 | 32'b1111111, 32'h00000000, "default_opcode_0x7F");

        // ====================================================
        // TEST 11: Random stress — 300 random instructions
        // ====================================================
        $display("\n=== TEST 11: Random stress (300 ops) ===");
        begin
            automatic int unsigned seed = 13;
            automatic logic [6:0] opcodes[8] = '{
                OP_ITYPE, OP_LOAD, OP_STORE, OP_BRANCH,
                OP_JAL,   OP_JALR, OP_LUI,   OP_AUIPC
            };

            for (int i = 0; i < 300; i++) begin : stress_loop
                automatic int          pick;
                automatic logic [6:0]  op;
                automatic logic [31:0] rnd, exp;

                pick = $urandom(seed) % 8; seed++;
                op   = opcodes[pick];

                // Random upper bits, force correct opcode into [6:0]
                rnd = ($urandom(seed) & 32'hFFFFFF80) | {25'b0, op};
                seed++;

                case (op)
                    OP_ITYPE,
                    OP_LOAD,
                    OP_JALR:   exp = f_imm(rnd);
                    OP_STORE:  exp = f_store(rnd);
                    OP_BRANCH: exp = f_branch(rnd);
                    OP_JAL:    exp = f_jump(rnd);
                    OP_LUI,
                    OP_AUIPC:  exp = f_upper(rnd);
                    default:   exp = 32'h0;
                endcase

                check_imm(rnd, exp, $sformatf("stress_%0d_op%07b", i, op));
            end
        end

        // ====================================================
        // SUMMARY
        // ====================================================
        $display("\n========================================");
        $display("  Results: %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — ImmGen verified");
        else
            $display("  FAILURES DETECTED — check waveform: gtkwave tb_immGen.vcd");
        $display("========================================\n");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #500000;
        $display("TIMEOUT — simulation hung");
        $finish;
    end

endmodule