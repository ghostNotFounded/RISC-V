`timescale 1ns/1ps

module tb_alu;

    // --------------------------------------------------------
    // DUT ports
    // --------------------------------------------------------
    logic [2:0]  aluop;
    logic [31:0] A, B;
    logic        zero;
    logic [31:0] result;

    alu #(.BUS_SIZE(32)) dut (
        .aluop(aluop),
        .A(A),
        .B(B),
        .zero(zero),
        .y(result)
    );

    int pass_count = 0;
    int fail_count = 0;

    // --------------------------------------------------------
    // Task: drive inputs and check outputs against expected
    // --------------------------------------------------------
    task automatic check_op(
        input [2:0]  op,
        input [31:0] a_in,
        input [31:0] b_in,
        input [31:0] exp_result,
        input logic  exp_zero,
        input string test_name
    );
        aluop = op;
        A     = a_in;
        B     = b_in;
        #5;  // let combinational logic settle

        if (result === exp_result && zero === exp_zero) begin
            $display("  PASS  [%s]  A=0x%08h B=0x%08h -> result=0x%08h zero=%b",
                     test_name, a_in, b_in, result, zero);
            pass_count++;
        end else begin
            $display("  FAIL  [%s]", test_name);
            if (result !== exp_result)
                $display("         result: got 0x%08h  expected 0x%08h", result, exp_result);
            if (zero !== exp_zero)
                $display("         zero:   got %b         expected %b",   zero,   exp_zero);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------
    // Opcode definitions (match your ALU design)
    // --------------------------------------------------------
    localparam OP_ADD  = 3'b001;
    localparam OP_SUB  = 3'b000;
    localparam OP_AND  = 3'b010;
    localparam OP_OR   = 3'b011;
    localparam OP_SLL  = 3'b100;
    localparam OP_SRL  = 3'b101;
    localparam OP_SLT  = 3'b110;
    localparam OP_ZERO = 3'b111;

    string vcd_file;

    initial begin
        // Waveform dump
        if ($value$plusargs("vcd=%s", vcd_file))
            $dumpfile(vcd_file);
        else
            $dumpfile("tb_alu.vcd");
        $dumpvars(0, dut);

        // Initialise
        aluop = 0; A = 0; B = 0;
        #10;

        // ====================================================
        // TEST 1: ADD (3'b001)
        // ====================================================
        $display("\n=== TEST 1: ADD ===");
        check_op(OP_ADD, 32'd0,          32'd0,          32'd0,          1'b1, "add_0_0");
        check_op(OP_ADD, 32'd1,          32'd1,          32'd2,          1'b0, "add_1_1");
        check_op(OP_ADD, 32'd100,        32'd200,        32'd300,        1'b0, "add_100_200");
        check_op(OP_ADD, 32'hFFFFFFFF,   32'd1,          32'd0,          1'b1, "add_overflow_wraps");
        check_op(OP_ADD, 32'h7FFFFFFF,   32'd1,          32'h80000000,   1'b0, "add_signed_overflow");
        check_op(OP_ADD, 32'hAAAAAAAA,   32'h55555555,   32'hFFFFFFFF,   1'b0, "add_pattern");

        // ====================================================
        // TEST 2: SUB (3'b000)
        // ====================================================
        $display("\n=== TEST 2: SUB ===");
        check_op(OP_SUB, 32'd5,          32'd3,          32'd2,          1'b0, "sub_5_3");
        check_op(OP_SUB, 32'd0,          32'd0,          32'd0,          1'b1, "sub_0_0_zero_flag");
        check_op(OP_SUB, 32'd100,        32'd100,        32'd0,          1'b1, "sub_equal_zero_flag");
        check_op(OP_SUB, 32'd0,          32'd1,          32'hFFFFFFFF,   1'b0, "sub_underflow_wraps");
        check_op(OP_SUB, 32'hFFFFFFFF,   32'hFFFFFFFF,   32'd0,          1'b1, "sub_maxval_equal");

        // ====================================================
        // TEST 3: AND (3'b010)
        // ====================================================
        $display("\n=== TEST 3: AND ===");
        check_op(OP_AND, 32'hFFFFFFFF,   32'hFFFFFFFF,   32'hFFFFFFFF,   1'b0, "and_all_ones");
        check_op(OP_AND, 32'hFFFFFFFF,   32'h00000000,   32'h00000000,   1'b1, "and_with_zero");
        check_op(OP_AND, 32'hAAAAAAAA,   32'h55555555,   32'h00000000,   1'b1, "and_alternating_zero");
        check_op(OP_AND, 32'hAAAAAAAA,   32'hAAAAAAAA,   32'hAAAAAAAA,   1'b0, "and_same_pattern");
        check_op(OP_AND, 32'hF0F0F0F0,   32'h0F0F0F0F,   32'h00000000,   1'b1, "and_nibble_complement");

        // ====================================================
        // TEST 4: OR (3'b011)
        // ====================================================
        $display("\n=== TEST 4: OR ===");
        check_op(OP_OR,  32'h00000000,   32'h00000000,   32'h00000000,   1'b1, "or_zero_zero");
        check_op(OP_OR,  32'hAAAAAAAA,   32'h55555555,   32'hFFFFFFFF,   1'b0, "or_alternating_fill");
        check_op(OP_OR,  32'hFFFFFFFF,   32'h00000000,   32'hFFFFFFFF,   1'b0, "or_with_zero");
        check_op(OP_OR,  32'hF0F0F0F0,   32'h0F0F0F0F,   32'hFFFFFFFF,   1'b0, "or_nibble_complement");

        // ====================================================
        // TEST 5: SLL — shift left logical (3'b100)
        // Uses B[4:0] as shift amount
        // ====================================================
        $display("\n=== TEST 5: SLL ===");
        check_op(OP_SLL, 32'h00000001,   32'd0,          32'h00000001,   1'b0, "sll_by_0");
        check_op(OP_SLL, 32'h00000001,   32'd1,          32'h00000002,   1'b0, "sll_by_1");
        check_op(OP_SLL, 32'h00000001,   32'd31,         32'h80000000,   1'b0, "sll_by_31");
        check_op(OP_SLL, 32'h80000000,   32'd1,          32'h00000000,   1'b1, "sll_msb_shifts_out");
        check_op(OP_SLL, 32'hFFFFFFFF,   32'd4,          32'hFFFFFFF0,   1'b0, "sll_ff_by_4");
        // B[4:0] masking: shift amount uses only lower 5 bits
        check_op(OP_SLL, 32'h00000001,   32'd32,         32'h00000001,   1'b0, "sll_b_low5_masked_32");

        // ====================================================
        // TEST 6: SRL — shift right logical (3'b101)
        // ====================================================
        $display("\n=== TEST 6: SRL ===");
        check_op(OP_SRL, 32'h80000000,   32'd0,          32'h80000000,   1'b0, "srl_by_0");
        check_op(OP_SRL, 32'h80000000,   32'd1,          32'h40000000,   1'b0, "srl_msb_by_1");
        check_op(OP_SRL, 32'hFFFFFFFF,   32'd1,          32'h7FFFFFFF,   1'b0, "srl_logical_no_sign_ext");
        check_op(OP_SRL, 32'hFFFFFFFF,   32'd31,         32'h00000001,   1'b0, "srl_by_31");
        check_op(OP_SRL, 32'h00000001,   32'd1,          32'h00000000,   1'b1, "srl_last_bit_out");

        // ====================================================
        // TEST 7: SLT — set less than (3'b110)
        // Result is 1 if A < B (unsigned), else 0
        // ====================================================
        $display("\n=== TEST 7: SLT ===");
        check_op(OP_SLT, 32'd1,          32'd2,          32'd1,          1'b0, "slt_1_lt_2");
        check_op(OP_SLT, 32'd2,          32'd1,          32'd0,          1'b1, "slt_2_not_lt_1");
        check_op(OP_SLT, 32'd5,          32'd5,          32'd0,          1'b1, "slt_equal_is_zero");
        check_op(OP_SLT, 32'd0,          32'hFFFFFFFF,   32'd0,          1'b1, "slt_0_lt_max_unsigned");
        check_op(OP_SLT, 32'hFFFFFFFF,   32'd0,          32'd1,          1'b0, "slt_max_not_lt_0_unsigned");

        // ====================================================
        // TEST 8: Force-zero output (3'b111)
        // ====================================================
        $display("\n=== TEST 8: Force zero output ===");
        check_op(OP_ZERO, 32'hDEADBEEF, 32'hCAFEBABE, 32'h00000000, 1'b1, "zero_any_inputs_a");
        check_op(OP_ZERO, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'h00000000, 1'b1, "zero_all_ones");
        check_op(OP_ZERO, 32'd0,        32'd0,        32'h00000000, 1'b1, "zero_already_zero");

        // ====================================================
        // TEST 9: Zero flag on non-zero results
        // ====================================================
        $display("\n=== TEST 9: Zero flag accuracy ===");
        // Add: non-zero result must NOT set zero flag
        check_op(OP_ADD, 32'd1,  32'd1,  32'd2, 1'b0, "zero_flag_off_add");
        check_op(OP_AND, 32'hFF, 32'hFF, 32'hFF,1'b0, "zero_flag_off_and");
        check_op(OP_OR,  32'd1,  32'd0,  32'd1, 1'b0, "zero_flag_off_or");
        // Subtraction to zero sets flag
        check_op(OP_SUB, 32'd42, 32'd42, 32'd0, 1'b1, "zero_flag_on_sub");

        // ====================================================
        // TEST 10: Boundary values across ops
        // ====================================================
        $display("\n=== TEST 10: Boundary values ===");
        check_op(OP_ADD, 32'h7FFFFFFF, 32'h7FFFFFFF, 32'hFFFFFFFE, 1'b0, "add_max_pos_twice");
        check_op(OP_AND, 32'h00000000, 32'h00000000, 32'h00000000, 1'b1, "and_zero_zero");
        check_op(OP_SRL, 32'h00000000, 32'd15,       32'h00000000, 1'b1, "srl_zero_input");
        check_op(OP_SLL, 32'h00000000, 32'd15,       32'h00000000, 1'b1, "sll_zero_input");

        // ====================================================
        // TEST 11: Random stress — 200 random operations
        // ====================================================
        $display("\n=== TEST 11: Random stress (200 ops) ===");
        begin
            automatic int unsigned seed = 99;
            for (int i = 0; i < 200; i++) begin : stress_loop
                automatic logic [2:0]  op;
                automatic logic [31:0] a_val, b_val, exp;
                automatic logic        exp_z;

                op    = 3'($urandom(seed) % 8); seed++;
                a_val = $urandom(seed);     seed++;
                b_val = $urandom(seed);     seed++;

                case (op)
                    OP_ADD:  exp = a_val + b_val;
                    OP_SUB:  exp = a_val - b_val;
                    OP_AND:  exp = a_val & b_val;
                    OP_OR:   exp = a_val | b_val;
                    OP_SLL:  exp = a_val << b_val[4:0];
                    OP_SRL:  exp = a_val >> b_val[4:0];
                    OP_SLT:  exp = (a_val < b_val) ? 32'd1 : 32'd0;
                    OP_ZERO: exp = 32'h0;
                    default: exp = 32'hX;
                endcase
                exp_z = (exp == 32'h0) ? 1'b1 : 1'b0;

                check_op(op, a_val, b_val, exp, exp_z, $sformatf("stress_%0d_op%03b", i, op));
            end
        end

        // ====================================================
        // SUMMARY
        // ====================================================
        $display("\n========================================");
        $display("  Results: %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — ALU verified");
        else
            $display("  FAILURES DETECTED — check waveform: gtkwave tb_alu.vcd");
        $display("========================================\n");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #100000;
        $display("TIMEOUT — simulation hung");
        $finish;
    end

endmodule