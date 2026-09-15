module div_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        en,
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [1:0]  op,
    output logic [31:0] result,
    output logic        stall
);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALC = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t state;

    logic [4:0]  count;
    logic [31:0] divisor;
    logic [31:0] quot;
    logic [31:0] acc;
    logic        sign_quot;
    logic        sign_rem;
    logic [1:0]  saved_op;
    logic        is_div_by_zero;
    logic        is_signed_overflow;
    logic [31:0] saved_a;

    wire [31:0] a_gated = en ? a : 32'b0;
    wire [31:0] b_gated = en ? b : 32'b0;

    logic is_signed;
    assign is_signed = ~op[0];

    logic [31:0] abs_a;
    logic [31:0] abs_b;
    assign abs_a = (is_signed && a_gated[31]) ? -a_gated : a_gated;
    assign abs_b = (is_signed && b_gated[31]) ? -b_gated : b_gated;

    logic [31:0] next_acc;
    logic [31:0] next_quot;
    logic [32:0] sub_res;

    wire [31:0] shift_acc = {acc[30:0], quot[31]};
    assign sub_res = {1'b0, shift_acc} - {1'b0, divisor};

    always_comb begin
        if (!sub_res[32]) begin
            next_acc  = sub_res[31:0];
            next_quot = {quot[30:0], 1'b1};
        end else begin
            next_acc  = shift_acc;
            next_quot = {quot[30:0], 1'b0};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state              <= IDLE;
            count              <= '0;
            divisor            <= '0;
            quot               <= '0;
            acc                <= '0;
            sign_quot          <= 1'b0;
            sign_rem           <= 1'b0;
            saved_op           <= '0;
            is_div_by_zero     <= 1'b0;
            is_signed_overflow <= 1'b0;
            saved_a            <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (en) begin
                        saved_op           <= op;
                        saved_a            <= a_gated;
                        is_div_by_zero     <= (b_gated == 32'b0);
                        is_signed_overflow <= is_signed && (a_gated == 32'h8000_0000) && (b_gated == 32'hffff_ffff);
                        if (b_gated == 32'b0 || (is_signed && (a_gated == 32'h8000_0000) && (b_gated == 32'hffff_ffff))) begin
                            state <= DONE;
                        end else begin
                            sign_quot <= is_signed && (a_gated[31] ^ b_gated[31]);
                            sign_rem  <= is_signed && a_gated[31];
                            divisor   <= abs_b;
                            acc       <= 32'b0;
                            quot      <= abs_a;
                            count     <= 5'd31;
                            state     <= CALC;
                        end
                    end
                end

                CALC: begin
                    acc  <= next_acc;
                    quot <= next_quot;
                    if (count == 5'd0) begin
                        state <= DONE;
                    end else begin
                        count <= count - 5'd1;
                    end
                end

                DONE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    logic [31:0] final_quot;
    logic [31:0] final_rem;
    assign final_quot = sign_quot ? -quot : quot;
    assign final_rem  = sign_rem  ? -acc  : acc;

    always_comb begin
        if (!en) begin
            result = 32'b0;
            stall  = 1'b0;
        end else if (state == DONE) begin
            stall = 1'b0;
            if (is_div_by_zero) begin
                case (saved_op)
                    2'b00, 2'b01: result = 32'hffff_ffff;
                    default:      result = saved_a;
                endcase
            end else if (is_signed_overflow) begin
                case (saved_op)
                    2'b00:   result = 32'h8000_0000;
                    default: result = 32'b0;
                endcase
            end else begin
                case (saved_op)
                    2'b00:   result = final_quot;
                    2'b01:   result = quot;
                    2'b10:   result = final_rem;
                    default: result = acc;
                endcase
            end
        end else begin
            result = 32'b0;
            stall  = 1'b1;
        end
    end

endmodule
