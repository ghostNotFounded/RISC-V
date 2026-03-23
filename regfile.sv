module regfile #(
    parameter BUS_SIZE = 32,
    parameter REG_COUNT = 32
) (
    input   logic                   clk,    // System clock
    input   logic                   reset,  // Sync reset
    
    input   logic                   wenable,// Write enable
    input   logic [4:0]             rd,     // Write address (5-bit)
    input   logic [BUS_SIZE-1:0]    wdata,  // Write data (32-bit)

    input   logic [4:0]             rs1,    // Read address rs1 (5-bit)
    output  logic [BUS_SIZE-1:0]    rdata1, // Output: Read data rs1 (32-bit)
    
    input   logic [4:0]             rs2,    // Read address rs2 (5-bit)
    output  logic [BUS_SIZE-1:0]    rdata2  // Output: Read data rs2 (32-bit)
);
    logic [BUS_SIZE-1:0] regs[0:REG_COUNT-1]; // 32 32-bit registers

    always @(posedge clk) begin
        if (!reset) begin
            if (wenable && rd != 0) begin
                regs[rd] <= wdata;
            end
        end
    end

    always @(*) begin
        if (reset || rs1 == 0) begin
            rdata1 = 0;
        end else begin
            rdata1 = regs[rs1];
        end
    end

    always @(*) begin
        if (reset || rs2 == 0) begin
            rdata2 = 0;
        end else begin
            rdata2 = regs[rs2];
        end
    end
endmodule
