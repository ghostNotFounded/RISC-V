`timescale 1ns/1ps

module tb_top_single_cycle;
    reg clk, reset;

    singleCycleCPU uut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end

    string vcd_file;
    initial begin
        // Waveform dump
        if ($value$plusargs("vcd=%s", vcd_file))
            $dumpfile(vcd_file);
        else
            $dumpfile("tb_alu.vcd");
        $dumpvars(0, uut);


        reset = 1; #2; reset = 0;

        #100;
        $finish;
    end

endmodule