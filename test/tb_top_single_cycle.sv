`timescale 1ns/1ps

module tb_top_single_cycle;
    reg clk, reset;

    singleCycleCPU uut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer pass_count = 0;
    integer fail_count = 0;

    task run_test;
        input string hex_file;
        input string name;
        integer cycle;
        logic [31:0] tohost;
    begin
        // Clear IMEM, DMEM, regfile
        for (int i = 0; i < 16384; i++) uut.IMEM.mem[i] = 0;
        for (int i = 0; i < 16384;  i++) uut.DMEM.mem[i] = 0;
        for (int i = 0; i < 32;    i++) uut.RF.regs[i]  = 0;

        // Load program into IMEM
        $readmemh(hex_file, uut.IMEM.mem, 13'h0);
        $readmemh(hex_file, uut.DMEM.mem, 13'h800);

        // Reset CPU
        reset = 1;
        uut.pc_reg = 32'h00000000;
        @(posedge clk);
        reset = 0;
        // @(posedge clk);
        $display("[%s]\nPC: 0x%08x instr=0x%08x", name, uut.pc_reg, uut.instr_reg);

        // Snoop the store bus for a write to tohost (byte addr 0x1000)
        tohost = 0;
        for (cycle = 0; cycle < 10; cycle++) begin
            @(posedge clk);
            $display("PC: 0x%08x instr=0x%08x", uut.pc_reg, uut.instr_reg);

            // Intercept ecall (0x00000073) — gp (x3) has pass/fail value
            if (uut.instr_reg == 32'h00000073) begin
                tohost = uut.RF.regs[3]; // gp = x3
                break;
            end

            // Also keep the tohost store snoop as fallback
            if (uut.memrw && uut.y == 32'h00001000) begin
                tohost = uut.rdata2;
                break;
            end
        end

        if (tohost == 1) begin
            $display("PASS: %s", name);
            pass_count++;
        end else if (tohost == 0) begin
            $display("TIMEOUT: %s (never wrote tohost)", name);
            fail_count++;
        end else begin
            $display("FAIL: %s - test case %0d failed", name, tohost >> 1);
            fail_count++;
        end
    end
    endtask

    initial begin
        string hex_dir;
        if (!$value$plusargs("hex_dir=%s", hex_dir))
            hex_dir = "tests/";

        reset = 1; #2;

        // run_test({hex_dir, "rv32ui-p-simple.hex"},  "simple");
        run_test({hex_dir, "rv32ui-p-add.hex"},     "add");
        // run_test({hex_dir, "rv32ui-p-addi.hex"},    "addi");
        // run_test({hex_dir, "rv32ui-p-and.hex"},     "and");
        // run_test({hex_dir, "rv32ui-p-andi.hex"},    "andi");
        // run_test({hex_dir, "rv32ui-p-auipc.hex"},   "auipc");
        // run_test({hex_dir, "rv32ui-p-beq.hex"},     "beq");
        // run_test({hex_dir, "rv32ui-p-bge.hex"},     "bge");
        // run_test({hex_dir, "rv32ui-p-bgeu.hex"},    "bgeu");
        // run_test({hex_dir, "rv32ui-p-blt.hex"},     "blt");
        // run_test({hex_dir, "rv32ui-p-bltu.hex"},    "bltu");
        // run_test({hex_dir, "rv32ui-p-bne.hex"},     "bne");
        // run_test({hex_dir, "rv32ui-p-jal.hex"},     "jal");
        // run_test({hex_dir, "rv32ui-p-jalr.hex"},    "jalr");
        // run_test({hex_dir, "rv32ui-p-or.hex"},      "or");
        // run_test({hex_dir, "rv32ui-p-ori.hex"},     "ori");
        // run_test({hex_dir, "rv32ui-p-sll.hex"},     "sll");
        // run_test({hex_dir, "rv32ui-p-slli.hex"},    "slli");
        // run_test({hex_dir, "rv32ui-p-slt.hex"},     "slt");
        // run_test({hex_dir, "rv32ui-p-slti.hex"},    "slti");
        // run_test({hex_dir, "rv32ui-p-sltiu.hex"},   "sltiu");
        // run_test({hex_dir, "rv32ui-p-sltu.hex"},    "sltu");
        // run_test({hex_dir, "rv32ui-p-sra.hex"},     "sra");
        // run_test({hex_dir, "rv32ui-p-srai.hex"},    "srai");
        // run_test({hex_dir, "rv32ui-p-srl.hex"},     "srl");
        // run_test({hex_dir, "rv32ui-p-srli.hex"},    "srli");
        // run_test({hex_dir, "rv32ui-p-sub.hex"},     "sub");
        // run_test({hex_dir, "rv32ui-p-xor.hex"},     "xor");
        // run_test({hex_dir, "rv32ui-p-xori.hex"},    "xori");
        // run_test({hex_dir, "rv32ui-p-lui.hex"},     "lui");
        // run_test({hex_dir, "rv32ui-p-sw.hex"},      "sw");
        // run_test({hex_dir, "rv32ui-p-sh.hex"},      "sh");
        // run_test({hex_dir, "rv32ui-p-sb.hex"},      "sb");
        // run_test({hex_dir, "rv32ui-p-lw.hex"},      "lw");
        // run_test({hex_dir, "rv32ui-p-lh.hex"},      "lh");
        // run_test({hex_dir, "rv32ui-p-lb.hex"},      "lb");
        // run_test({hex_dir, "rv32ui-p-lhu.hex"},     "lhu");
        // run_test({hex_dir, "rv32ui-p-lbu.hex"},     "lbu");

        $display("\n=== Results: %0d passed, %0d failed ===",
                 pass_count, fail_count);
        $finish;
    end

endmodule