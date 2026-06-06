`timescale 1ns/1ns

module ahb_i2s_fifo #(
    parameter FIFO_ADDR_WIDTH = 10,
    parameter SCK_HALF_PERIOD = 16,
    parameter CAPTURE_RIGHT   = 0
) (
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    input  wire        HREADY,
    output reg  [31:0] HRDATA,
    output wire        HREADYOUT,
    output wire [1:0]  HRESP,

    input  wire        i2s_sd,
    output wire        i2s_sck,
    output wire        i2s_ws,
    output wire        irq
);

    localparam REG_CTRL       = 4'h0;
    localparam REG_STATUS     = 4'h1;
    localparam REG_DATA       = 4'h2;
    localparam REG_FIFO_LEVEL = 4'h3;
    localparam REG_CONFIG     = 4'h4;

    reg         enable;
    reg         capture_right_cfg;
    reg         adpcm_enable_cfg;
    reg         fifo_clear_req;
    reg         overflow_clear_req;
    reg         data_read_req;
    reg         write_data_phase;
    reg [3:0]   write_addr_phase;

    wire [31:0] sample_data;
    wire        sample_valid;
    wire [31:0] adpcm_packed_data;
    wire        adpcm_packed_valid;
    wire [31:0] fifo_wdata = adpcm_enable_cfg ? adpcm_packed_data : sample_data;
    wire        fifo_wr_en = adpcm_enable_cfg ? adpcm_packed_valid : sample_valid;
    wire        fifo_full;
    wire        fifo_empty;
    wire        fifo_almost_full;
    wire        fifo_almost_empty;
    wire [31:0] fifo_rdata;
    wire [FIFO_ADDR_WIDTH:0] fifo_level;
    wire        fifo_overflow;
    wire        fifo_rd_en;
    wire        ahb_access = HSEL & HREADY & HTRANS[1];
    wire [3:0]  reg_addr = HADDR[5:2];

    assign HREADYOUT = 1'b1;
    assign HRESP     = 2'b00;
    assign irq       = fifo_almost_full | fifo_overflow;
    assign fifo_rd_en = data_read_req & ~fifo_empty;

    i2s_inmp441_rx #(
        .SCK_HALF_PERIOD(SCK_HALF_PERIOD),
        .CAPTURE_RIGHT(CAPTURE_RIGHT)
    ) u_i2s_rx (
        .clk          (HCLK),
        .resetn       (HRESETn),
        .enable       (enable),
        .capture_right(capture_right_cfg),
        .i2s_sd       (i2s_sd),
        .i2s_sck      (i2s_sck),
        .i2s_ws       (i2s_ws),
        .sample_data  (sample_data),
        .sample_valid (sample_valid)
    );

    i2s_adpcm_pack u_i2s_adpcm_pack (
        .clk          (HCLK),
        .resetn       (HRESETn),
        .clear        (fifo_clear_req | ~enable | ~adpcm_enable_cfg),
        .sample_data  (sample_data),
        .sample_valid (sample_valid & adpcm_enable_cfg),
        .packed_data  (adpcm_packed_data),
        .packed_valid (adpcm_packed_valid)
    );

    simple_sync_fifo #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (FIFO_ADDR_WIDTH)
    ) u_audio_fifo (
        .clk            (HCLK),
        .resetn         (HRESETn),
        .clear          (fifo_clear_req),
        .wr_en          (fifo_wr_en),
        .wr_data        (fifo_wdata),
        .full           (fifo_full),
        .almost_full    (fifo_almost_full),
        .rd_en          (fifo_rd_en),
        .rd_data        (fifo_rdata),
        .empty          (fifo_empty),
        .almost_empty   (fifo_almost_empty),
        .level          (fifo_level),
        .overflow_clear (overflow_clear_req),
        .overflow       (fifo_overflow)
    );

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            enable             <= 1'b0;
            capture_right_cfg  <= 1'b0;
            adpcm_enable_cfg    <= 1'b0;
            fifo_clear_req     <= 1'b0;
            overflow_clear_req <= 1'b0;
            data_read_req      <= 1'b0;
            write_data_phase   <= 1'b0;
            write_addr_phase   <= 4'd0;
            HRDATA             <= 32'd0;
        end else begin
            fifo_clear_req     <= 1'b0;
            overflow_clear_req <= 1'b0;
            data_read_req      <= 1'b0;
            write_data_phase   <= ahb_access && HWRITE;

            if (ahb_access && HWRITE) begin
                write_addr_phase <= reg_addr;
            end

            if (write_data_phase) begin
                case (write_addr_phase)
                    REG_CTRL: begin
                        enable             <= HWDATA[0];
                        fifo_clear_req     <= HWDATA[1];
                        overflow_clear_req <= HWDATA[2];
                    end

                    REG_CONFIG: begin
                        capture_right_cfg <= HWDATA[0];
                        adpcm_enable_cfg   <= HWDATA[1];
                    end

                    default: begin
                    end
                endcase
            end

            if (ahb_access && !HWRITE) begin
                case (reg_addr)
                    REG_CTRL: begin
                        HRDATA <= {31'd0, enable};
                    end

                    REG_STATUS: begin
                        HRDATA <= {25'd0,
                                   adpcm_enable_cfg,
                                   capture_right_cfg,
                                   fifo_almost_full,
                                   fifo_almost_empty,
                                   fifo_overflow,
                                   fifo_full,
                                   fifo_empty};
                    end

                    REG_DATA: begin
                        HRDATA        <= fifo_empty ? 32'd0 : fifo_rdata;
                        data_read_req <= 1'b1;
                    end

                    REG_FIFO_LEVEL: begin
                        HRDATA <= {{(32-FIFO_ADDR_WIDTH-1){1'b0}}, fifo_level};
                    end

                    REG_CONFIG: begin
                        HRDATA <= {30'd0, adpcm_enable_cfg, capture_right_cfg};
                    end

                    default: begin
                        HRDATA <= 32'd0;
                    end
                endcase
            end
        end
    end

endmodule
