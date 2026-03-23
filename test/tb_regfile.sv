`timescale 1ns/1ps

module tb_regfile;
    logic           clk;
    logic           reset;
    logic           wenable;
    logic [4:0]     rs1, rs2, rd;
    logic [31:0]    wdata;
    logic [31:0]    rdata1, rdata2;

    regfile dut (clk, reset, wenable, rd, wdata, rs1, rdata1, rs2, rdata2);

    initial clk = 0;
    always #5 clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    logic [31:0] model [31:0];

    // Write one register and update the model
    task write_reg(input [4:0] addr, input [31:0] data);
        @(negedge clk);          // set inputs before rising edge
        wenable    = 1;
        rd    = addr;
        wdata = data;
        @(posedge clk);          // write happens here
        #1;                      // tiny delta after edge
        wenable = 0;
        if (addr != 0)
            model[addr] = data;
    endtask

    // Read both ports and check against model
    task automatic check_read(
        input [4:0]  a1, a2,
        input string test_name
    );
        logic [31:0] exp1;
        logic [31:0] exp2;
        rs1 = a1;
        rs2 = a2;
        #1;   // let combinational logic settle (async read)
        exp1 = model[a1];
        exp2 = model[a2];

        if (rdata1 === exp1 && rdata2 === exp2) begin
            $display("  PASS  [%s]  rs1[x%0d]=0x%08h  rs2[x%0d]=0x%08h",
                     test_name, a1, rdata1, a2, rdata2);
            pass_count++;
        end else begin
            $display("  FAIL  [%s]", test_name);
            if (rdata1 !== exp1)
                $display("         rs1[x%0d]: got 0x%08h  expected 0x%08h", a1, rdata1, exp1);
            if (rdata2 !== exp2)
                $display("         rs2[x%0d]: got 0x%08h  expected 0x%08h", a2, rdata2, exp2);
            fail_count++;
        end
    endtask

    string vcd_file;
    initial begin
        // Waveform dump
        if ($value$plusargs("vcd=%s", vcd_file))
            $dumpfile(vcd_file);
        else
            $dumpfile("task1.vcd");

        $dumpvars(0, dut);

        // Initialise
        wenable = 0; rd = 0; rs1 = 0; rs2 = 0; wdata = 0;
        foreach (model[i]) model[i] = 0;

        // Give design a couple cycles to settle
        repeat(2) @(posedge clk);

        // ====================================================
        // TEST 1: x0 always reads as zero (never written)
        // ====================================================
        $display("\n=== TEST 1: x0 hardwired to zero ===");

        // Attempt to write x0
        write_reg(5'd0, 32'hDEADBEEF);
        rs1 = 5'd0; rs2 = 5'd0; #1;
        if (rdata1 === 32'h0 && rdata2 === 32'h0) begin
            $display("  PASS  x0 ignores write, reads 0x00000000");
            pass_count++;
        end else begin
            $display("  FAIL  x0 was written! rdata1=0x%08h rdata2=0x%08h", rdata1, rdata2);
            fail_count++;
        end

        // ====================================================
        // TEST 2: Basic write then read — all 31 registers
        // ====================================================
        $display("\n=== TEST 2: Write + read all x1–x31 ===");
        for (int i = 1; i <= 31; i++) begin
            automatic logic [31:0] val = 32'hA5000000 | i;
            write_reg(i[4:0], val);
            check_read(i[4:0], 5'd0, $sformatf("basic_rw_x%0d", i));
        end

        // ====================================================
        // TEST 3: Boundary values
        // ====================================================
        $display("\n=== TEST 3: Boundary values ===");
        write_reg(5'd1,  32'h00000000); check_read(5'd1,  5'd0, "val_all_zeros");
        write_reg(5'd2,  32'hFFFFFFFF); check_read(5'd2,  5'd0, "val_all_ones");
        write_reg(5'd3,  32'h80000000); check_read(5'd3,  5'd0, "val_min_neg");
        write_reg(5'd4,  32'h7FFFFFFF); check_read(5'd4,  5'd0, "val_max_pos");
        write_reg(5'd5,  32'hAAAAAAAA); check_read(5'd5,  5'd0, "val_alternating_A");
        write_reg(5'd6,  32'h55555555); check_read(5'd6,  5'd0, "val_alternating_5");

        // ====================================================
        // TEST 4: Simultaneous dual-port reads
        // ====================================================
        $display("\n=== TEST 4: Simultaneous dual-port reads ===");
        write_reg(5'd10, 32'hCAFEBABE);
        write_reg(5'd11, 32'h12345678);
        check_read(5'd10, 5'd11, "dual_read_different_regs");
        check_read(5'd11, 5'd10, "dual_read_swapped_ports");
        // Read same register on both ports
        check_read(5'd10, 5'd10, "dual_read_same_reg");

        // ====================================================
        // TEST 5: Write-After-Read hazard (WAR timing)
        // Async read should see OLD value before posedge,
        // NEW value only after posedge
        // ====================================================
        $display("\n=== TEST 5: WAR — read old value before write commits ===");
        write_reg(5'd7, 32'hAABBCCDD);
        @(negedge clk);
        // Set up write on rd=x7, but sample READ before posedge
        wenable = 1; rd = 5'd7; wdata = 32'h11223344;
        rs1 = 5'd7;
        #1;  // still before posedge — async read should return OLD value
        if (rdata1 === 32'hAABBCCDD) begin
            $display("  PASS  WAR: read old value 0x%08h before write commits", rdata1);
            pass_count++;
        end else begin
            $display("  FAIL  WAR: expected 0xAABBCCDD before posedge, got 0x%08h", rdata1);
            fail_count++;
        end
        @(posedge clk); #1;
        wenable = 0; model[7] = 32'h11223344;
        check_read(5'd7, 5'd0, "WAR_new_value_after_posedge");

        // ====================================================
        // TEST 6: Write enable = 0 does NOT change register
        // ====================================================
        $display("\n=== TEST 6: Write enable gating ===");
        write_reg(5'd8, 32'hDEAD0000);
        // Try write with wenable=0
        @(negedge clk);
        wenable = 0; rd = 5'd8; wdata = 32'hBEEFBEEF;
        @(posedge clk); #1;
        check_read(5'd8, 5'd0, "wenable_disabled_no_change");

        // ====================================================
        // TEST 7: Overwrite — last write wins
        // ====================================================
        $display("\n=== TEST 7: Overwrite ===");
        write_reg(5'd9, 32'h11111111);
        write_reg(5'd9, 32'h22222222);
        write_reg(5'd9, 32'h33333333);
        check_read(5'd9, 5'd0, "overwrite_last_wins");

        // ====================================================
        // TEST 8: x0 reads as 0 while reading live registers
        // ====================================================
        $display("\n=== TEST 8: x0 on port 2 while port 1 reads live data ===");
        write_reg(5'd15, 32'hFEEDFACE);
        check_read(5'd15, 5'd0, "live_vs_x0");
        check_read(5'd0,  5'd15, "x0_vs_live");

        // ====================================================
        // TEST 9: Random stress — 200 random writes + reads
        // ====================================================
        $display("\n=== TEST 9: Random stress (200 ops) ===");
        begin
            automatic int unsigned seed = 42;
            for (int i = 0; i < 200; i++) begin : stress_loop
                int r1, r2, addr;
                logic [31:0] val;

                addr = ($urandom(seed) % 31) + 1;
                val  = $urandom(seed);
                seed++;

                write_reg(addr[4:0], val);

                r1 = $urandom(seed) % 32; seed++;
                r2 = $urandom(seed) % 32; seed++;
                check_read(r1[4:0], r2[4:0], $sformatf("stress_%0d", i));
            end
        end

        // ====================================================
        // SUMMARY
        // ====================================================
        $display("\n========================================");
        $display("  Results: %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED — register file verified");
        else
            $display("  FAILURES DETECTED — check waveform: gtkwave regfile.vcd");
        $display("========================================\n");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog — kill sim if it hangs
    // --------------------------------------------------------
    initial begin
        #500000;
        $display("TIMEOUT — simulation hung");
        $finish;
    end

endmodule