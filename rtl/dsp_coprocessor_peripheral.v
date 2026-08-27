`timescale 1ns / 1ps
module dsp_coprocessor_peripheral #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  p_clk,
    input  wire                  p_aresetn,
    // FIFO1 Pop Port
    input  wire [DATA_WIDTH-1:0] p_rd_data,
    input  wire                  p_rd_valid,
    output wire                  p_rd_ready,
    input  wire                  p_rd_empty,
    // FIFO2 Push Port
    output reg  [DATA_WIDTH-1:0] p_wr_data,
    output reg                   p_wr_valid,
    input  wire                  p_wr_ready,
    input  wire                  p_wr_full
);

    // ------------------------------------------------------------------
    // States
    // NOTE: STATE_PROCESS2 added to split the 32-bit add across two
    // clock cycles. This removes the single 32-bit ripple-carry adder
    // that was the design's critical path (only 13-26 ps of setup
    // margin at synthesis). Splitting it into two 16-bit adds roughly
    // halves the combinational depth per cycle, at the cost of exactly
    // one extra clock cycle of latency between p_rd_valid and
    // p_wr_valid. External interface (ports) is unchanged.
    // ------------------------------------------------------------------
    localparam STATE_IDLE     = 2'd0;
    localparam STATE_PROCESS  = 2'd1;
    localparam STATE_PROCESS2 = 2'd2;
    localparam STATE_WRITE    = 2'd3;

    reg [1:0]  state;
    reg [DATA_WIDTH-1:0] sample_reg;

    // Pipeline registers for the split addition
    reg [15:0] sum_lo;    // lower 16 bits of the result
    reg        carry_lo;  // carry out of the lower-16-bit add

    assign p_rd_ready = (state == STATE_IDLE) && p_rd_valid;

    always @(posedge p_clk or negedge p_aresetn) begin
        if (!p_aresetn) begin
            state       <= STATE_IDLE;
            sample_reg  <= {DATA_WIDTH{1'b0}};
            sum_lo      <= 16'd0;
            carry_lo    <= 1'b0;
            p_wr_data   <= {DATA_WIDTH{1'b0}};
            p_wr_valid  <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    p_wr_valid <= 1'b0;
                    if (p_rd_valid) begin
                        sample_reg <= p_rd_data;
                        state      <= STATE_PROCESS;
                    end else begin
                        state      <= STATE_IDLE;
                    end
                end

                // Cycle 1 of 2: same math as before --
                //   (sample_reg << 1) + (sample_reg[31] ? 4 : 5)
                // computed only on the lower 16 bits of the shifted
                // value, capturing the carry into the upper half.
                STATE_PROCESS: begin
                    {carry_lo, sum_lo} <=
                        {1'b0, sample_reg[14:0], 1'b0} +
                        (sample_reg[31] ? 17'd4 : 17'd5);
                    state <= STATE_PROCESS2;
                end

                // Cycle 2 of 2: upper 16 bits of the shifted value,
                // plus the carry registered from cycle 1. This
                // reproduces the exact same 32-bit result as the
                // original single-cycle expression.
                STATE_PROCESS2: begin
                    p_wr_data  <= {(sample_reg[30:15] + {15'd0, carry_lo}), sum_lo};
                    p_wr_valid <= 1'b1;
                    state      <= STATE_WRITE;
                end

                STATE_WRITE: begin
                    if (p_wr_ready) begin
                        p_wr_valid <= 1'b0;
                        state      <= STATE_IDLE;
                    end else begin
                        state      <= STATE_WRITE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
