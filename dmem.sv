module data_memory #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 32
)(
    input  logic                   clk,
    input  logic                   mem_write, // Write Enable signal
    input  logic [ADDR_WIDTH-1:0]  addr,      // Memory Address
    input  logic [DATA_WIDTH-1:0]  write_data,// Data to store
    output logic [DATA_WIDTH-1:0]  read_data  // Data retrieved
);
    logic [DATA_WIDTH-1:0] ram [0:MEM_DEPTH-1];

    always_ff @(posedge clk) begin
        if (mem_write) begin
            ram[addr[ADDR_WIDTH-1:2]] <= write_data;
        end
    end

    assign read_data = ram[addr[ADDR_WIDTH-1:2]];

endmodule