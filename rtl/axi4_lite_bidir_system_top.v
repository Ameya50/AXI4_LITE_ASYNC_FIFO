`timescale 1ns / 1ps
module axi4_lite_bidir_system_top #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH = 4
)(
    // AXI4-Lite Interface
    input  wire                      s_axi_aclk,
    input  wire                      s_axi_aresetn,
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
    output wire [1:0]                s_axi_bresp,
    output wire                      s_axi_bvalid,
    input  wire                      s_axi_bready,
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
    output wire [DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                s_axi_rresp,
    output wire                      s_axi_rvalid,
    input  wire                      s_axi_rready,
    // Peripheral Domain
    input  wire                      p_clk,
    input  wire                      p_aresetn
);
    wire [DATA_WIDTH-1:0] p_rd_data, p_wr_data;
    wire                  p_rd_valid, p_rd_ready, p_rd_empty;
    wire                  p_wr_valid, p_wr_ready, p_wr_full;
    // Bridge Instance
    axi4_lite_bidir_fifo_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) u_bridge (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .p_clk         (p_clk),
        .p_aresetn     (p_aresetn),
        .p_wr_data     (p_wr_data),
        .p_wr_valid    (p_wr_valid),
        .p_wr_ready    (p_wr_ready),
        .p_wr_full     (p_wr_full),
        .p_rd_data     (p_rd_data),
        .p_rd_valid    (p_rd_valid),
        .p_rd_ready    (p_rd_ready),
        .p_rd_empty    (p_rd_empty)
    );
    // Downstream Peripheral Instance
    dsp_coprocessor_peripheral #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_peripheral (
        .p_clk      (p_clk),
        .p_aresetn  (p_aresetn),
        .p_rd_data  (p_rd_data),
        .p_rd_valid (p_rd_valid),
        .p_rd_ready (p_rd_ready),
        .p_rd_empty (p_rd_empty),
        .p_wr_data  (p_wr_data),
        .p_wr_valid (p_wr_valid),
        .p_wr_ready (p_wr_ready),
        .p_wr_full  (p_wr_full)
    );
endmodule
