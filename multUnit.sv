module mult_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        en,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [1:0]  op,
    output logic [31:0] result,
    output logic        stall
);

    typedef enum logic {
        IDLE = 1'b0,
        DONE = 1'b1
    } state_t;

    state_t state;

    wire [31:0] a_gated = en ? a : 32'b0;
    wire [31:0] b_gated = en ? b : 32'b0;

    wire a_signed = (op == 2'b01) || (op == 2'b10);
    wire b_signed = (op == 2'b01);

    wire signed [32:0] a_ext = {a_signed & a_gated[31], a_gated};
    wire signed [16:0] b_lo  = {1'b0, b_gated[15:0]};
    wire signed [16:0] b_hi  = {b_signed & b_gated[31], b_gated[31:16]};

    logic signed [32:0] saved_a_ext;
    logic signed [16:0] saved_b_hi;
    logic [1:0]         saved_op;
    logic signed [49:0] p0_reg;

    wire signed [32:0] core_a = (state == IDLE) ? a_ext : saved_a_ext;
    wire signed [16:0] core_b = (state == IDLE) ? b_lo  : saved_b_hi;
    wire signed [49:0] core_prod = core_a * core_b;

    always_ff @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            saved_a_ext <= '0;
            saved_b_hi  <= '0;
            saved_op    <= '0;
            p0_reg      <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (en) begin
                        saved_a_ext <= a_ext;
                        saved_b_hi  <= b_hi;
                        saved_op    <= op;
                        p0_reg      <= core_prod;
                        state       <= DONE;
                    end
                end
                DONE: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    wire signed [65:0] full_prod = (core_prod <<< 16) + {{16{p0_reg[49]}}, p0_reg};

    assign stall  = en && (state != DONE);
    assign result = (en && (state == DONE)) ? ((saved_op == 2'b00) ? full_prod[31:0] : full_prod[63:32]) : 32'b0;

endmodule