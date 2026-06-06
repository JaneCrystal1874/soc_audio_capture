`timescale 1ns/1ns

module test_adpcm;

localparam CLK_PERIOD_NS = 40;      // 25 MHz HCLK
localparam SAMPLE_GAP    = 2048;    // 2 * SCK_HALF_PERIOD * 64
localparam SAMPLE_COUNT  = 128;
localparam WORD_COUNT    = SAMPLE_COUNT / 8;

reg         clk;
reg         resetn;
reg         clear;
reg [31:0]  sample_data;
reg         sample_valid;
wire [31:0] packed_data;
wire        packed_valid;

reg signed [15:0] pcm_samples [0:SAMPLE_COUNT-1];
reg [31:0] expected_words [0:WORD_COUNT-1];
reg [31:0] actual_words [0:WORD_COUNT-1];

integer sample_idx;
integer expected_word_count;
integer actual_word_count;
integer mismatch_count;
integer out_fd;

i2s_adpcm_pack u_dut (
    .clk          (clk),
    .resetn       (resetn),
    .clear        (clear),
    .sample_data  (sample_data),
    .sample_valid (sample_valid),
    .packed_data  (packed_data),
    .packed_valid (packed_valid)
);

always #(CLK_PERIOD_NS/2) clk = ~clk;

initial begin
    $timeformat(-9, 3, " ns", 12);

    clk = 1'b0;
    resetn = 1'b0;
    clear = 1'b0;
    sample_data = 32'd0;
    sample_valid = 1'b0;
    sample_idx = 0;
    expected_word_count = 0;
    actual_word_count = 0;
    mismatch_count = 0;

    init_pcm_samples;
    build_expected_words;

    repeat (10) @(posedge clk);
    resetn <= 1'b1;
    repeat (4) @(posedge clk);

    for (sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx = sample_idx + 1) begin
        drive_sample(pcm_samples[sample_idx]);
        repeat (SAMPLE_GAP - 1) @(posedge clk);
    end

    wait (actual_word_count == WORD_COUNT);
    repeat (10) @(posedge clk);

    write_actual_words;
    check_words;

    if (mismatch_count == 0) begin
        $display("[PASS] ADPCM hardware output matches reference model: %0d words", WORD_COUNT);
    end else begin
        $display("[FAIL] ADPCM mismatch count = %0d", mismatch_count);
        $stop;
    end

    $finish;
end

always @(posedge clk) begin
    if (resetn && packed_valid) begin
        if (actual_word_count < WORD_COUNT) begin
            actual_words[actual_word_count] <= packed_data;
            $display("* %0t packed[%0d] = 0x%08h", $time, actual_word_count, packed_data);
        end else begin
            $display("[FAIL] unexpected extra packed word: 0x%08h", packed_data);
            mismatch_count = mismatch_count + 1;
        end

        actual_word_count = actual_word_count + 1;
    end
end

task drive_sample;
    input signed [15:0] pcm16;
    begin
        @(posedge clk);
        sample_data  <= {{16{pcm16[15]}}, pcm16};
        sample_valid <= 1'b1;
        @(posedge clk);
        sample_valid <= 1'b0;
        sample_data  <= 32'd0;
    end
endtask

task init_pcm_samples;
    integer i;
    begin
        /*
         * Deterministic audio-like waveform with sign changes and transients.
         * Values are kept in 16-bit range and fed into sample_data[15:0],
         * matching the current ADPCM wrapper input slice.
         */
        for (i = 0; i < SAMPLE_COUNT; i = i + 1) begin
            case (i[4:0])
                5'd0:  pcm_samples[i] = 16'sd0;
                5'd1:  pcm_samples[i] = 16'sd600;
                5'd2:  pcm_samples[i] = 16'sd1800;
                5'd3:  pcm_samples[i] = 16'sd3600;
                5'd4:  pcm_samples[i] = 16'sd6200;
                5'd5:  pcm_samples[i] = 16'sd9200;
                5'd6:  pcm_samples[i] = 16'sd12000;
                5'd7:  pcm_samples[i] = 16'sd14000;
                5'd8:  pcm_samples[i] = 16'sd15000;
                5'd9:  pcm_samples[i] = 16'sd14000;
                5'd10: pcm_samples[i] = 16'sd11800;
                5'd11: pcm_samples[i] = 16'sd8500;
                5'd12: pcm_samples[i] = 16'sd4200;
                5'd13: pcm_samples[i] = 16'sd500;
                5'd14: pcm_samples[i] = -16'sd2600;
                5'd15: pcm_samples[i] = -16'sd6200;
                5'd16: pcm_samples[i] = -16'sd9800;
                5'd17: pcm_samples[i] = -16'sd12800;
                5'd18: pcm_samples[i] = -16'sd14800;
                5'd19: pcm_samples[i] = -16'sd15500;
                5'd20: pcm_samples[i] = -16'sd14600;
                5'd21: pcm_samples[i] = -16'sd12000;
                5'd22: pcm_samples[i] = -16'sd7600;
                5'd23: pcm_samples[i] = -16'sd2400;
                5'd24: pcm_samples[i] = 16'sd1800;
                5'd25: pcm_samples[i] = 16'sd5200;
                5'd26: pcm_samples[i] = 16'sd8200;
                5'd27: pcm_samples[i] = 16'sd10100;
                5'd28: pcm_samples[i] = 16'sd7200;
                5'd29: pcm_samples[i] = -16'sd1200;
                5'd30: pcm_samples[i] = -16'sd9000;
                default: pcm_samples[i] = -16'sd3000;
            endcase

            if ((i % 37) == 0) begin
                pcm_samples[i] = 16'sd22000;
            end else if ((i % 53) == 0) begin
                pcm_samples[i] = -16'sd21000;
            end
        end
    end
endtask

task build_expected_words;
    integer i;
    integer nibble_count;
    integer word_idx;
    integer predictor;
    integer step_index;
    reg [3:0] nibble;
    reg [31:0] pack_word;
    begin
        nibble_count = 0;
        word_idx = 0;
        predictor = 0;
        step_index = 0;
        pack_word = 32'd0;

        for (i = 0; i < SAMPLE_COUNT; i = i + 1) begin
            encode_ref_sample(pcm_samples[i], predictor, step_index, nibble);
            pack_word = pack_word | ({28'd0, nibble} << (nibble_count * 4));
            nibble_count = nibble_count + 1;

            if (nibble_count == 8) begin
                expected_words[word_idx] = pack_word;
                word_idx = word_idx + 1;
                pack_word = 32'd0;
                nibble_count = 0;
            end
        end

        expected_word_count = word_idx;
    end
endtask

task encode_ref_sample;
    input signed [15:0] sample16;
    inout integer predictor;
    inout integer step_index;
    output reg [3:0] nibble;
    integer step;
    integer diff;
    integer dequant;
    begin
        step = step_size(step_index);
        diff = (sample16 * 8) - predictor;
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
            predictor = predictor - dequant;
        end else begin
            predictor = predictor + dequant;
        end

        if (predictor > 262143) begin
            predictor = 262143;
        end else if (predictor < -262144) begin
            predictor = -262144;
        end

        step_index = step_index + step_delta(nibble[2:0]);
        if (step_index < 0) begin
            step_index = 0;
        end else if (step_index > 88) begin
            step_index = 88;
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
        if (actual_word_count != expected_word_count) begin
            $display("[FAIL] word count mismatch: expected %0d actual %0d",
                     expected_word_count, actual_word_count);
            mismatch_count = mismatch_count + 1;
        end

        for (i = 0; i < WORD_COUNT; i = i + 1) begin
            if (actual_words[i] !== expected_words[i]) begin
                $display("[FAIL] word[%0d] expected=0x%08h actual=0x%08h",
                         i, expected_words[i], actual_words[i]);
                mismatch_count = mismatch_count + 1;
            end
        end
    end
endtask

task write_actual_words;
    integer i;
    begin
        out_fd = $fopen("adpcm_hw_words.hex", "w");
        if (out_fd == 0) begin
            $display("[WARN] could not open adpcm_hw_words.hex for writing");
        end else begin
            for (i = 0; i < WORD_COUNT; i = i + 1) begin
                $fdisplay(out_fd, "%08h", actual_words[i]);
            end
            $fclose(out_fd);
            $display("* wrote adpcm_hw_words.hex");
        end
    end
endtask

initial begin
    #(CLK_PERIOD_NS * SAMPLE_GAP * SAMPLE_COUNT * 4);
    $display("[FAIL] simulation timeout: actual_word_count=%0d expected=%0d",
             actual_word_count, WORD_COUNT);
    $stop;
end

endmodule
