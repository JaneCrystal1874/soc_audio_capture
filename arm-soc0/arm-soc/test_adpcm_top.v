`timescale 1ns/1ns
`define PERIOD 20

module test_adpcm_top;

localparam CHECK_WORDS      = 16;
localparam SAMPLES_PER_WORD = 8;
localparam CHECK_SAMPLES    = CHECK_WORDS * SAMPLES_PER_WORD;

reg clk;
reg resetn;
reg tdi;
reg tck;
wire tms;
wire tdo;
wire [7:0] b_pad_gpio_porta;
reg  key0_n;
reg  sw1_adpcm;
wire record_led;
wire adpcm_led;
wire uart1_rxd;
wire uart2_rxd;
wire timer0_extin;
wire timer1_extin;

reg  i2s_sd;
wire i2s_sck;
wire i2s_ws;

wire        SDRAM_CLK;
wire        SDRAM_CKE;
wire        SDRAM_CSn;
wire        SDRAM_RASn;
wire        SDRAM_CASn;
wire        SDRAM_WEn;
wire [12:0] SDRAM_ADDR;
wire [1:0]  SDRAM_BA;
wire [15:0] SDRAM_DQ;
wire [1:0]  SDRAM_DQM;

reg [23:0] mic_sample;
reg [5:0]  i2s_bit_cnt;
reg        i2s_ws_d;
reg [8*256-1:0] hex_file;

reg [31:0] expected_words [0:CHECK_WORDS-1];
reg [31:0] actual_words [0:CHECK_WORDS-1];
integer expected_word_count;
integer actual_word_count;
integer captured_sample_count;
integer mismatch_count;
integer predictor;
integer step_index;
integer nibble_count;
reg [31:0] pack_word;

assign record_led = b_pad_gpio_porta[0];
assign adpcm_led  = b_pad_gpio_porta[2];

// GPIOA[1] = SW1 ADPCM select, GPIOA[4] = KEY0 active-low.
assign b_pad_gpio_porta[1] = sw1_adpcm;
assign b_pad_gpio_porta[4] = key0_n;

assign uart1_rxd = 1'b0;
assign uart2_rxd = 1'b0;
assign timer0_extin = 1'b0;
assign timer1_extin = 1'b0;
assign tms = 1'b0;

top u_soc (
    .CLK              (clk),
    .RESETn           (resetn),
    .TDI              (tdi),
    .TCK              (tck),
    .TMS              (tms),
    .TDO              (tdo),
    .b_pad_gpio_porta (b_pad_gpio_porta[7:0]),
    .uart1_rxd        (uart1_rxd),
    .uart1_txd        (),
    .uart2_rxd        (uart2_rxd),
    .uart2_txd        (),
    .timer0_extin     (timer0_extin),
    .timer1_extin     (timer1_extin),
    .i2s_sd           (i2s_sd),
    .i2s_sck          (i2s_sck),
    .i2s_ws           (i2s_ws),
    .SDRAM_CLK        (SDRAM_CLK),
    .SDRAM_CKE        (SDRAM_CKE),
    .SDRAM_CSn        (SDRAM_CSn),
    .SDRAM_RASn       (SDRAM_RASn),
    .SDRAM_CASn       (SDRAM_CASn),
    .SDRAM_WEn        (SDRAM_WEn),
    .SDRAM_ADDR       (SDRAM_ADDR),
    .SDRAM_BA         (SDRAM_BA),
    .SDRAM_DQ         (SDRAM_DQ),
    .SDRAM_DQM        (SDRAM_DQM)
);

always #(`PERIOD/2) clk = ~clk;

initial begin
    $timeformat(-9, 3, " ns", 12);

    clk = 1'b1;
    resetn = 1'b0;
    tdi = 1'b0;
    tck = 1'b0;
    key0_n = 1'b1;
    sw1_adpcm = 1'b1;
    i2s_sd = 1'b0;
    mic_sample = 24'h001234;
    i2s_bit_cnt = 6'd0;
    i2s_ws_d = 1'b0;
    expected_word_count = 0;
    actual_word_count = 0;
    captured_sample_count = 0;
    mismatch_count = 0;
    predictor = 0;
    step_index = 0;
    nibble_count = 0;
    pack_word = 32'd0;

    if (!$value$plusargs("HEX=%s", hex_file)) begin
        hex_file = "firmware/prj/keil/output/outfile.bin";
    end

    $readmemh(hex_file, u_soc.U_SRAM.memory);
    $display("* ram loaded successfully: %0s", hex_file);

    #(`PERIOD*20);
    resetn = 1'b1;

    // Press and release KEY0. main.c starts recording after the release.
    #2000;
    key0_n = 1'b0;
    $display("* KEY0 pressed with SW1=ADPCM");
    #2000;
    key0_n = 1'b1;
    $display("* KEY0 released, ADPCM recording should start");
end

// INMP441-like source. The DUT samples SD on SCK rising edges, so update on falling edges.
always @(negedge i2s_sck or negedge resetn) begin
    if (!resetn) begin
        i2s_sd <= 1'b0;
        i2s_bit_cnt <= 6'd0;
        i2s_ws_d <= 1'b0;
        mic_sample <= 24'h001234;
    end else begin
        if (i2s_ws != i2s_ws_d) begin
            i2s_bit_cnt <= 6'd0;
            i2s_ws_d <= i2s_ws;
            i2s_sd <= (i2s_ws == 1'b0) ? mic_sample[23] : 1'b0;
        end else begin
            i2s_bit_cnt <= i2s_bit_cnt + 1'b1;

            if (i2s_ws == 1'b0 && i2s_bit_cnt <= 6'd22) begin
                i2s_sd <= mic_sample[22 - i2s_bit_cnt];
            end else begin
                i2s_sd <= 1'b0;
            end
        end

        if (i2s_ws == 1'b0 && i2s_bit_cnt == 6'd31) begin
            mic_sample <= next_mic_sample(mic_sample);
        end
    end
end

function [23:0] next_mic_sample;
    input [23:0] sample;
    begin
        // Deterministic ramp with occasional slope changes to exercise ADPCM state.
        if (sample[7:0] == 8'hf0) begin
            next_mic_sample = sample - 24'h000980;
        end else if (sample[8:0] == 9'h055) begin
            next_mic_sample = sample + 24'h001710;
        end else begin
            next_mic_sample = sample + 24'h000111;
        end
    end
endfunction

// Build theoretical ADPCM words from the exact samples captured by the I2S RX block.
always @(posedge u_soc.HCLK) begin
    if (resetn &&
        u_soc.u_ahb_i2s_fifo.enable &&
        u_soc.u_ahb_i2s_fifo.adpcm_enable_cfg &&
        u_soc.u_ahb_i2s_fifo.u_i2s_rx.sample_valid &&
        captured_sample_count < CHECK_SAMPLES) begin
        add_expected_sample(u_soc.u_ahb_i2s_fifo.u_i2s_rx.sample_data[15:0]);
        captured_sample_count = captured_sample_count + 1;
    end
end

// Observe CPU writes to SDRAM and compare with theoretical ADPCM words.
always @(posedge u_soc.HCLK) begin
    if (resetn &&
        u_soc.hselmi2 &&
        u_soc.hreadymuxmi2 &&
        u_soc.hreadyoutmi2 &&
        u_soc.htransmi2[1] &&
        u_soc.hwritemi2 &&
        actual_word_count < CHECK_WORDS) begin
        actual_words[actual_word_count] <= u_soc.hwdatami2;
        $display("* %0t SDRAM ADPCM write[%0d] addr=0x%08h data=0x%08h",
                 $time, actual_word_count, u_soc.haddrmi2, u_soc.hwdatami2);
        actual_word_count = actual_word_count + 1;
    end
end

always @(posedge u_soc.HCLK) begin
    if (resetn && actual_word_count == CHECK_WORDS && expected_word_count == CHECK_WORDS) begin
        repeat (4) @(posedge u_soc.HCLK);
        check_words;

        if (mismatch_count == 0) begin
            $display("[PASS] top ADPCM SDRAM writes match theoretical compression: %0d words",
                     CHECK_WORDS);
        end else begin
            $display("[FAIL] top ADPCM mismatch count = %0d", mismatch_count);
            $stop;
        end

        $finish;
    end
end

task add_expected_sample;
    input [15:0] pcm16_bits;
    reg signed [15:0] pcm16;
    reg [3:0] nibble;
    begin
        pcm16 = pcm16_bits;
        encode_ref_sample(pcm16, predictor, step_index, nibble);
        pack_word = pack_word | ({28'd0, nibble} << (nibble_count * 4));
        nibble_count = nibble_count + 1;

        if (nibble_count == SAMPLES_PER_WORD) begin
            expected_words[expected_word_count] = pack_word;
            $display("* %0t expected ADPCM word[%0d] = 0x%08h",
                     $time, expected_word_count, pack_word);
            expected_word_count = expected_word_count + 1;
            pack_word = 32'd0;
            nibble_count = 0;
        end
    end
endtask

task encode_ref_sample;
    input signed [15:0] sample16;
    inout integer predictor_ref;
    inout integer step_index_ref;
    output reg [3:0] nibble;
    integer step;
    integer diff;
    integer dequant;
    begin
        step = step_size(step_index_ref);
        diff = (sample16 * 8) - predictor_ref;
        nibble = 4'd0;

        if (diff < 0) begin
            nibble[3] = 1'b1;
            diff = -diff;
        end

        dequant = step;
        if (diff >= (step * 8)) begin
            nibble[2] = 1'b1;
            diff = diff - (step * 8);
            dequant = dequant + (step * 8);
        end
        if (diff >= (step * 4)) begin
            nibble[1] = 1'b1;
            diff = diff - (step * 4);
            dequant = dequant + (step * 4);
        end
        if (diff >= (step * 2)) begin
            nibble[0] = 1'b1;
            dequant = dequant + (step * 2);
        end

        if (nibble[3]) begin
            predictor_ref = predictor_ref - dequant;
        end else begin
            predictor_ref = predictor_ref + dequant;
        end

        if (predictor_ref > 262143) begin
            predictor_ref = 262143;
        end else if (predictor_ref < -262144) begin
            predictor_ref = -262144;
        end

        step_index_ref = step_index_ref + step_delta(nibble[2:0]);
        if (step_index_ref < 0) begin
            step_index_ref = 0;
        end else if (step_index_ref > 88) begin
            step_index_ref = 88;
        end
    end
endtask

function integer step_delta;
    input [2:0] code;
    begin
        case (code)
            3'd0, 3'd1, 3'd2, 3'd3: step_delta = -1;
            3'd4: step_delta = 2;
            3'd5: step_delta = 4;
            3'd6: step_delta = 6;
            default: step_delta = 8;
        endcase
    end
endfunction

function integer step_size;
    input integer index;
    begin
        case (index)
            0: step_size = 7;       1: step_size = 8;       2: step_size = 9;
            3: step_size = 10;      4: step_size = 11;      5: step_size = 12;
            6: step_size = 13;      7: step_size = 14;      8: step_size = 16;
            9: step_size = 17;      10: step_size = 19;     11: step_size = 21;
            12: step_size = 23;     13: step_size = 25;     14: step_size = 28;
            15: step_size = 31;     16: step_size = 34;     17: step_size = 37;
            18: step_size = 41;     19: step_size = 45;     20: step_size = 50;
            21: step_size = 55;     22: step_size = 60;     23: step_size = 66;
            24: step_size = 73;     25: step_size = 80;     26: step_size = 88;
            27: step_size = 97;     28: step_size = 107;    29: step_size = 118;
            30: step_size = 130;    31: step_size = 143;    32: step_size = 157;
            33: step_size = 173;    34: step_size = 190;    35: step_size = 209;
            36: step_size = 230;    37: step_size = 253;    38: step_size = 279;
            39: step_size = 307;    40: step_size = 337;    41: step_size = 371;
            42: step_size = 408;    43: step_size = 449;    44: step_size = 494;
            45: step_size = 544;    46: step_size = 598;    47: step_size = 658;
            48: step_size = 724;    49: step_size = 796;    50: step_size = 876;
            51: step_size = 963;    52: step_size = 1060;   53: step_size = 1166;
            54: step_size = 1282;   55: step_size = 1411;   56: step_size = 1552;
            57: step_size = 1707;   58: step_size = 1878;   59: step_size = 2066;
            60: step_size = 2272;   61: step_size = 2499;   62: step_size = 2749;
            63: step_size = 3024;   64: step_size = 3327;   65: step_size = 3660;
            66: step_size = 4026;   67: step_size = 4428;   68: step_size = 4871;
            69: step_size = 5358;   70: step_size = 5894;   71: step_size = 6484;
            72: step_size = 7132;   73: step_size = 7845;   74: step_size = 8630;
            75: step_size = 9493;   76: step_size = 10442;  77: step_size = 11487;
            78: step_size = 12635;  79: step_size = 13899;  80: step_size = 15289;
            81: step_size = 16818;  82: step_size = 18500;  83: step_size = 20350;
            84: step_size = 22385;  85: step_size = 24623;  86: step_size = 27086;
            87: step_size = 29794;  default: step_size = 32767;
        endcase
    end
endfunction

task check_words;
    integer i;
    begin
        for (i = 0; i < CHECK_WORDS; i = i + 1) begin
            if (actual_words[i] !== expected_words[i]) begin
                $display("[FAIL] word[%0d] expected=0x%08h actual=0x%08h",
                         i, expected_words[i], actual_words[i]);
                mismatch_count = mismatch_count + 1;
            end
        end
    end
endtask

always @(record_led or adpcm_led) begin
    if (resetn) begin
        $display("* %0t record_led=%0b adpcm_led=%0b", $time, record_led, adpcm_led);
    end
end

initial begin
    #50_000_000;
    $display("[FAIL] simulation timeout: expected_words=%0d actual_words=%0d captured_samples=%0d",
             expected_word_count, actual_word_count, captured_sample_count);
    $stop;
end

endmodule
