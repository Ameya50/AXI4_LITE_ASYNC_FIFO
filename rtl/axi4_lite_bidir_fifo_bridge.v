`timescale 1ns / 1ps

module axi4_lite_bidir_fifo_bridge #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH = 4
)(
    input  wire                      s_axi_aclk,
    input  wire                      s_axi_aresetn,
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
    output reg  [1:0]                s_axi_bresp,
    output reg                       s_axi_bvalid,
    input  wire                      s_axi_bready,
    input  wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
    output reg  [DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                s_axi_rresp,
    output reg                       s_axi_rvalid,
    input  wire                      s_axi_rready,

    input  wire                      p_clk,
    input  wire                      p_aresetn,
    input  wire [DATA_WIDTH-1:0]     p_wr_data,
    input  wire                      p_wr_valid,
    output wire                      p_wr_ready,
    output wire                      p_wr_full,
    output wire [DATA_WIDTH-1:0]     p_rd_data,
    output wire                      p_rd_valid,
    input  wire                      p_rd_ready,
    output wire                      p_rd_empty
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;
    localparam [1:0] RESP_DECERR = 2'b11;
    localparam [AXI_ADDR_WIDTH-1:0] FIFO_DATA_REG_ADDR = {AXI_ADDR_WIDTH{1'b0}};

    wire                  fifo1_wr_en;
    wire [DATA_WIDTH-1:0] fifo1_wr_data;
    wire                  fifo1_wr_full;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_fifo1 (
        .wr_clk   (s_axi_aclk),
        .wr_rst_n (s_axi_aresetn),
        .wr_en    (fifo1_wr_en),
        .wr_data  (fifo1_wr_data),
        .wr_full  (fifo1_wr_full),
        .rd_clk   (p_clk),
        .rd_rst_n (p_aresetn),
        .rd_en    (p_rd_ready),
        .rd_data  (p_rd_data),
        .rd_valid (p_rd_valid),
        .rd_empty (p_rd_empty)
    );

    wire                  fifo2_rd_en;
    wire [DATA_WIDTH-1:0] fifo2_rd_data;
    wire                  fifo2_rd_valid;
    wire                  fifo2_rd_empty;
    wire                  fifo2_wr_full;

    assign p_wr_ready = !fifo2_wr_full;
    assign p_wr_full  = fifo2_wr_full;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_fifo2 (
        .wr_clk   (p_clk),
        .wr_rst_n (p_aresetn),
        .wr_en    (p_wr_valid),
        .wr_data  (p_wr_data),
        .wr_full  (fifo2_wr_full),
        .rd_clk   (s_axi_aclk),
        .rd_rst_n (s_axi_aresetn),
        .rd_en    (fifo2_rd_en),
        .rd_data  (fifo2_rd_data),
        .rd_valid (fifo2_rd_valid),
        .rd_empty (fifo2_rd_empty)
    );

    // --- AXI4-Lite Write FSM ---
    localparam [1:0] W_IDLE = 2'd0, W_RESP = 2'd1;

    reg [1:0]                w_state;
    reg                      aw_hs, w_hs;
    reg [AXI_ADDR_WIDTH-1:0] awaddr_reg;
    reg [DATA_WIDTH-1:0]     wdata_reg;

    assign s_axi_awready = (w_state == W_IDLE) && !aw_hs;
    assign s_axi_wready  = (w_state == W_IDLE) && !w_hs;

    wire [AXI_ADDR_WIDTH-1:0] waddr_now = aw_hs ? awaddr_reg : s_axi_awaddr;
    wire [DATA_WIDTH-1:0]     wdata_now = w_hs  ? wdata_reg  : s_axi_wdata;

    wire aw_avail    = aw_hs || (s_axi_awvalid && s_axi_awready);
    wire w_avail     = w_hs  || (s_axi_wvalid  && s_axi_wready);
    wire do_commit   = (w_state == W_IDLE) && aw_avail && w_avail;
    wire waddr_valid = (waddr_now == FIFO_DATA_REG_ADDR);

    assign fifo1_wr_data = wdata_now;
    assign fifo1_wr_en   = do_commit && waddr_valid;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            w_state      <= W_IDLE;
            aw_hs        <= 1'b0;
            w_hs         <= 1'b0;
            awaddr_reg   <= {AXI_ADDR_WIDTH{1'b0}};
            wdata_reg    <= {DATA_WIDTH{1'b0}};
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_reg <= s_axi_awaddr;
                        aw_hs      <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        wdata_reg <= s_axi_wdata;
                        w_hs      <= 1'b1;
                    end
                    if (do_commit) begin
                        w_state      <= W_RESP;
                        s_axi_bvalid <= 1'b1;
                        if (!waddr_valid)
                            s_axi_bresp <= RESP_DECERR;
                        else if (fifo1_wr_full)
                            s_axi_bresp <= RESP_SLVERR;
                        else
                            s_axi_bresp <= RESP_OKAY;
                    end
                end

		
                W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        aw_hs        <= 1'b0;
                        w_hs         <= 1'b0;
                        w_state      <= W_IDLE;
                    end
                end
                default: begin
                    w_state      <= W_IDLE;
                    s_axi_bvalid <= 1'b0;
                end
            endcase
        end
    end

    // --- AXI4-Lite Read FSM ---
    localparam [1:0] R_IDLE = 2'd0, R_DATA = 2'd1;

    reg [1:0] r_state;
    assign s_axi_arready = (r_state == R_IDLE);

    wire raddr_valid = (s_axi_araddr == FIFO_DATA_REG_ADDR);

    assign fifo2_rd_en = (r_state == R_IDLE) && s_axi_arvalid && s_axi_arready && raddr_valid;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            r_state      <= R_IDLE;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rdata  <= {DATA_WIDTH{1'b0}};
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_rvalid <= 1'b1;
                        r_state      <= R_DATA;
                        if (!raddr_valid) begin
                            s_axi_rresp <= RESP_DECERR;
                            s_axi_rdata <= {DATA_WIDTH{1'b0}};
                        end else if (!fifo2_rd_valid) begin
                            s_axi_rresp <= RESP_SLVERR;
                            s_axi_rdata <= {DATA_WIDTH{1'b0}};
                        end else begin
                            s_axi_rresp <= RESP_OKAY;
                            s_axi_rdata <= fifo2_rd_data;
                        end
                    end
                end
                R_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        r_state      <= R_IDLE;
                    end
                end
                default: begin
                    r_state      <= R_IDLE;
                    s_axi_rvalid <= 1'b0;
                end
            endcase
        end
    end

endmodule
