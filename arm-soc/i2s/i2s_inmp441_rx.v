`timescale 1ns/1ns

module i2s_inmp441_rx #(
    parameter SCK_HALF_PERIOD = 16,
    parameter CAPTURE_RIGHT   = 0
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        enable,
    input  wire        capture_right,
    input  wire        i2s_sd,
    output reg         i2s_sck,
    output reg         i2s_ws,
    output reg [31:0]  sample_data,
    output reg         sample_valid
);

    reg [15:0] sck_div;
    reg [5:0]  bit_cnt;
    reg [23:0] shift;

    wire selected_slot = capture_right ? i2s_ws : ~i2s_ws;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sck_div      <= 16'd0;
            i2s_sck      <= 1'b0;
            i2s_ws       <= 1'b0;
            bit_cnt      <= 6'd0;
            shift        <= 24'd0;
            sample_data  <= 32'd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            if (!enable) begin
                sck_div <= 16'd0;
                i2s_sck <= 1'b0;
                i2s_ws  <= 1'b0;
                bit_cnt <= 6'd0;
            end else if (sck_div == SCK_HALF_PERIOD - 1) begin
                sck_div <= 16'd0;
                i2s_sck <= ~i2s_sck;

                if (!i2s_sck) begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 6'd31) begin
                        bit_cnt <= 6'd0;
                        i2s_ws  <= ~i2s_ws;
                    end

                    if (selected_slot && bit_cnt <= 6'd23) begin
                        shift <= {shift[22:0], i2s_sd};
                    end

                    if (selected_slot && bit_cnt == 6'd23) begin
                        sample_data  <= {{8{shift[22]}}, shift[22:0], i2s_sd};
                        sample_valid <= 1'b1;
                    end
                end
            end else begin
                sck_div <= sck_div + 1'b1;
            end
        end
    end

endmodule
