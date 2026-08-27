`timescale 1ns / 1ps
module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter DEPTH      = 1 << ADDR_WIDTH
)(
    // Write Domain
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,
    // Read Domain (FWFT Mode)
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_valid,
    output wire                  rd_empty
);
    // Memory Array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    // Pointer Registers
    reg [ADDR_WIDTH:0] wptr_bin, rptr_bin;
    reg [ADDR_WIDTH:0] wptr_gray, rptr_gray;
    reg [ADDR_WIDTH:0] wptr_gray_s1, wptr_gray_s2;
    reg [ADDR_WIDTH:0] rptr_gray_s1, rptr_gray_s2;
    // Gated Memory Write
    always @(posedge wr_clk) begin
        if (wr_en && !wr_full) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end
    // Binary & Gray Write Pointers
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            wptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_en && !wr_full) begin
            wptr_bin  <= wptr_bin + 1'b1;
            wptr_gray <= (wptr_bin + 1'b1) ^ ((wptr_bin + 1'b1) >> 1);
        end
    end
    // Binary & Gray Read Pointers
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else if (rd_en && !rd_empty) begin
            rptr_bin  <= rptr_bin + 1'b1;
            rptr_gray <= (rptr_bin + 1'b1) ^ ((rptr_bin + 1'b1) >> 1);
        end
    end
    // CDC Synchronizer: Read Pointer to Write Domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rptr_gray_s1 <= {(ADDR_WIDTH+1){1'b0}};
            rptr_gray_s2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rptr_gray_s1 <= rptr_gray;
            rptr_gray_s2 <= rptr_gray_s1;
        end
    end
    // CDC Synchronizer: Write Pointer to Read Domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wptr_gray_s1 <= {(ADDR_WIDTH+1){1'b0}};
            wptr_gray_s2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wptr_gray_s1 <= wptr_gray;
            wptr_gray_s2 <= wptr_gray_s1;
        end
    end
    // Status Flags
    assign wr_full  = (wptr_gray == {~rptr_gray_s2[ADDR_WIDTH:ADDR_WIDTH-1], rptr_gray_s2[ADDR_WIDTH-2:0]});
    assign rd_empty = (rptr_gray == wptr_gray_s2);
    assign rd_valid = !rd_empty;
    assign rd_data  = mem[rptr_bin[ADDR_WIDTH-1:0]];
endmodule
