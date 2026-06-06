`timescale 1ns/1ns

/*
 * Convert the 24-bit signed INMP441 sample stream into packed IMA ADPCM words.
 *
 * The referenced IMA encoder accepts 16-bit linear PCM.  Current board captures
 * show the useful audio energy in sample_data[15:0], so this wrapper feeds that
 * slice into the encoder.  Every encoded sample is a 4-bit nibble; eight nibbles
 * are packed into one 32-bit AHB word:
 *
 *   word[3:0]    = sample0
 *   word[7:4]    = sample1
 *   ...
 *   word[31:28]  = sample7
 */
module i2s_adpcm_pack (
    input  wire        clk,
    input  wire        resetn,
    input  wire        clear,
    input  wire [31:0] sample_data,
    input  wire        sample_valid,
    output reg  [31:0] packed_data,
    output reg         packed_valid
);

    wire        enc_ready;
    wire [3:0]  enc_pcm;
    wire        enc_valid;
    wire signed [23:0] sample24 = sample_data[23:0];
    wire signed [24:0] pcm_gain = sample24 >>> 7;
    wire [15:0] pcm16 = (pcm_gain > 25'sd32767)  ? 16'h7fff :
                         (pcm_gain < -25'sd32768) ? 16'h8000 :
                                                     pcm_gain[15:0];

    reg [2:0]  nibble_count;
    reg [31:0] pack_shift;

    wire reset_enc = ~resetn | clear;

    ima_adpcm_enc u_ima_adpcm_enc (
        .clock          (clk),
        .reset          (reset_enc),
        .inSamp         (pcm16),
        .inValid        (sample_valid & enc_ready),
        .inReady        (enc_ready),
        .outPCM         (enc_pcm),
        .outValid       (enc_valid),
        .outPredictSamp (),
        .outStepIndex   ()
    );

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            nibble_count <= 3'd0;
            pack_shift   <= 32'd0;
            packed_data  <= 32'd0;
            packed_valid <= 1'b0;
        end else begin
            packed_valid <= 1'b0;

            if (clear) begin
                nibble_count <= 3'd0;
                pack_shift   <= 32'd0;
                packed_data  <= 32'd0;
            end else if (enc_valid) begin
                if (nibble_count == 3'd7) begin
                    packed_data  <= pack_shift | ({28'd0, enc_pcm} << {nibble_count, 2'b00});
                    packed_valid <= 1'b1;
                    nibble_count <= 3'd0;
                    pack_shift   <= 32'd0;
                end else begin
                    pack_shift   <= pack_shift | ({28'd0, enc_pcm} << {nibble_count, 2'b00});
                    nibble_count <= nibble_count + 1'b1;
                end
            end
        end
    end

endmodule
