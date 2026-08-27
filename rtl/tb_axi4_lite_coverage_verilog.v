`timescale 1ns / 1ps

// synopsys coverage off
module tb_axi4_lite_coverage_verilog;

    parameter DATA_WIDTH     = 32;
    parameter ADDR_WIDTH     = 4;
    parameter AXI_ADDR_WIDTH = 4;
    parameter FIFO_DEPTH     = 1 << ADDR_WIDTH;

    // Clock and Reset Signals
    reg s_axi_aclk;
    reg s_axi_aresetn;
    reg p_clk;
    reg p_aresetn;

    // AXI4-Lite Write Channel
    reg  [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;
    reg  [DATA_WIDTH-1:0]     s_axi_wdata;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;
    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    // AXI4-Lite Read Channel
    reg  [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;
    wire [DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;

    // -------------------------------------------------------------------------
    // Top-Level DUT Instantiation
    // -------------------------------------------------------------------------
    // synopsys coverage on
    axi4_lite_bidir_system_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) dut (
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
        .p_aresetn     (p_aresetn)
    );

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_axi4_lite_coverage_verilog);
    end

    // FIX: instance path corrected to match the actual module name
    // (tb_axi4_lite_coverage_verilog) and actual instance name (dut).
    // The previous version referenced tb_axi4_lite_coverage.u_dut, which
    // does not exist -- neither the module name nor the instance name
    // matched, so toggle collection would never have attached correctly.
    initial begin
        $set_toggle_region(tb_axi4_lite_coverage_verilog);
        $toggle_start;
    end

    // synopsys coverage off
    always #4.0 s_axi_aclk = ~s_axi_aclk;   // 125 MHz -> period 8 ns, toggle every 4 ns
    always #5.0 p_clk      = ~p_clk;        // 100 MHz -> period 10 ns, toggle every 5 ns

    task axi_write;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0]     data;
        input integer              mode;
        input integer              bready_delay;
        output [1:0]               resp;
        reg aw_done, w_done;
        begin
            @(posedge s_axi_aclk);
            s_axi_bready <= 1'b0;

            if (mode == 0) begin
                s_axi_awaddr  <= addr;
                s_axi_awvalid <= 1'b1;
                s_axi_wdata   <= data;
                s_axi_wvalid  <= 1'b1;
                aw_done        = 1'b0;
                w_done         = 1'b0;

                while (aw_done == 1'b0 || w_done == 1'b0) begin
                    @(posedge s_axi_aclk);
                    if (s_axi_awready && s_axi_awvalid) begin
                        s_axi_awvalid <= 1'b0;
                        aw_done        = 1'b1;
                    end
                    if (s_axi_wready && s_axi_wvalid) begin
                        s_axi_wvalid <= 1'b0;
                        w_done        = 1'b1;
                    end
                end
            end else if (mode == 1) begin
                s_axi_awaddr  <= addr;
                s_axi_awvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (s_axi_awready == 1'b0) @(posedge s_axi_aclk);
                s_axi_awvalid <= 1'b0;

                repeat (2) @(posedge s_axi_aclk);
                s_axi_wdata  <= data;
                s_axi_wvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (s_axi_wready == 1'b0) @(posedge s_axi_aclk);
                s_axi_wvalid <= 1'b0;
            end else begin
                s_axi_wdata  <= data;
                s_axi_wvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (s_axi_wready == 1'b0) @(posedge s_axi_aclk);
                s_axi_wvalid <= 1'b0;

                repeat (2) @(posedge s_axi_aclk);
                s_axi_awaddr  <= addr;
                s_axi_awvalid <= 1'b1;
                @(posedge s_axi_aclk);
                while (s_axi_awready == 1'b0) @(posedge s_axi_aclk);
                s_axi_awvalid <= 1'b0;
            end

            while (s_axi_bvalid == 1'b0) @(posedge s_axi_aclk);

            if (bready_delay > 0) begin
                s_axi_awvalid <= 1'b1;
                s_axi_wvalid  <= 1'b1;
                repeat (bready_delay) @(posedge s_axi_aclk);
                s_axi_awvalid <= 1'b0;
                s_axi_wvalid  <= 1'b0;
            end

            s_axi_bready <= 1'b1;
            resp = s_axi_bresp;
            @(posedge s_axi_aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task axi_read;
        input  [AXI_ADDR_WIDTH-1:0] addr;
        input  integer              rready_delay;
        output [DATA_WIDTH-1:0]     data;
        output [1:0]                resp;
        begin
            @(posedge s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b0;

            @(posedge s_axi_aclk);
            while (s_axi_arready == 1'b0) @(posedge s_axi_aclk);
            s_axi_arvalid <= 1'b0;

            while (s_axi_rvalid == 1'b0) @(posedge s_axi_aclk);

            if (rready_delay > 0) begin
                s_axi_arvalid <= 1'b1;
                repeat (rready_delay) @(posedge s_axi_aclk);
                s_axi_arvalid <= 1'b0;
            end

            s_axi_rready <= 1'b1;
            data = s_axi_rdata;
            resp = s_axi_rresp;
            @(posedge s_axi_aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

    reg [DATA_WIDTH-1:0] rdata;
    reg [1:0]            resp;
    reg [DATA_WIDTH-1:0] pat;
    integer              i, b;

    initial begin
        s_axi_aclk    = 1'b0;
        s_axi_aresetn = 1'b0;
        p_clk         = 1'b0;
        p_aresetn     = 1'b0;
        s_axi_awaddr  = {AXI_ADDR_WIDTH{1'b0}};
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = {DATA_WIDTH{1'b0}};
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = {AXI_ADDR_WIDTH{1'b0}};
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        #40;
        @(posedge s_axi_aclk); s_axi_aresetn = 1'b1;
        @(posedge p_clk);      p_aresetn     = 1'b1;
        #30;

        // 1. Address Line Toggles & Illegal Address Decode Errors (DECERR)
        for (i = 0; i < 16; i = i + 1) begin
            if (i != 0) begin
                axi_write(i[3:0], 32'hDEAD_0000 | i, 0, 0, resp);
                axi_read(i[3:0], 0, rdata, resp);
            end
        end

        // 2. Empty FIFO Read SLVERR
        axi_read(4'h0, 4, rdata, resp);

        // 3. FSM Skew Handshakes & Stalls
        axi_write(4'h0, 32'h8000_000A, 1, 3, resp);
        axi_write(4'h0, 32'd20,        2, 2, resp);
        #150;
        axi_read(4'h0, 3, rdata, resp);
        axi_read(4'h0, 0, rdata, resp);

        // 4. Exhaustive 32-Bit Toggle Patterns
        pat = 32'h0000_0000; axi_write(4'h0, pat, 0, 0, resp); #100; axi_read(4'h0, 0, rdata, resp);
        pat = 32'hFFFF_FFFF; axi_write(4'h0, pat, 0, 0, resp); #100; axi_read(4'h0, 0, rdata, resp);
        pat = 32'hAAAA_AAAA; axi_write(4'h0, pat, 0, 0, resp); #100; axi_read(4'h0, 0, rdata, resp);
        pat = 32'h5555_5555; axi_write(4'h0, pat, 0, 0, resp); #100; axi_read(4'h0, 0, rdata, resp);

        for (b = 0; b < 32; b = b + 1) begin
            pat = (1 << b);
            axi_write(4'h0, pat, 0, 0, resp);
            #100;
            axi_read(4'h0, 0, rdata, resp);
        end

        for (b = 0; b < 32; b = b + 1) begin
            pat = ~(1 << b);
            axi_write(4'h0, pat, 0, 0, resp);
            #100;
            axi_read(4'h0, 0, rdata, resp);
        end

        // 5. FIFO1 Full Saturation & Write SLVERR
        @(posedge p_clk);
        p_aresetn = 1'b0;

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            axi_write(4'h0, 32'h100 + i, 0, 0, resp);
        end

        axi_write(4'h0, 32'hFFFF_0001, 0, 0, resp);
        axi_write(4'h4, 32'hFFFF_0002, 0, 0, resp);

        @(posedge p_clk);
        p_aresetn = 1'b1;
        #350;

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            axi_read(4'h0, 0, rdata, resp);
        end

        // 6. Force STATE_WRITE Stall
        for (i = 0; i < FIFO_DEPTH + 2; i = i + 1) begin
            axi_write(4'h0, (i % 2 == 0) ? (32'h8000_0000 | (32'd50 + i)) : (32'd50 + i), 0, 0, resp);
            #20;
        end
        #300;

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            axi_read(4'h0, 0, rdata, resp);
        end

        // 7. Hit STATE_PROCESS -> STATE_IDLE FSM Arc via Targeted Async Reset
        axi_write(4'h0, 32'h5A5A_1234, 0, 0, resp);
        @(posedge (dut.u_peripheral.state == 2'd1));
        #1.0;
        p_aresetn = 1'b0;
        #20;
        @(posedge p_clk);
        p_aresetn = 1'b1;
        #30;

        // 8. Pointer Wrap-around Dual-Domain Stream
        for (i = 0; i < 32; i = i + 1) begin
            pat = (i * 32'h0402_0101) ^ 32'h5A5A_5A5A;
            axi_write(4'h0, pat, 0, 0, resp);
            #100;
            axi_read(4'h0, 0, rdata, resp);
        end

        #200;

        // FIX: SAIF generation moved out of the nested (illegal) initial
        // block and placed here, at the top level of the main test-sequence
        // initial block, right before $finish. This runs exactly once,
        // after the full test sequence genuinely completes -- not at an
        // arbitrary guessed time (#100000) that could cut activity capture
        // short or run needlessly long past the real end of the test.
        $toggle_stop;
        $toggle_report("activity.saif", 1.0e-9, tb_axi4_lite_coverage_verilog);

        $finish;
    end

endmodule
// synopsys coverage on
