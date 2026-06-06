`timescale 1ns/1ns
`define PERIOD 20

module test1;

localparam CAPTURE_WORDS = 16;
localparam DBG_DONE_WORD = 14'h1000;  // 0x00004000 >> 2
localparam DBG_INDEX_WORD = 14'h1001;
localparam DBG_SAMPLE_WORD = 14'h1002;
localparam DBG_STATUS_WORD = 14'h1003;
localparam DBG_DONE_VALUE = 32'h33333333;

reg clk;
reg resetn;
reg tdi;
reg tck;
wire tms;
wire tdo;
wire [7:0] b_pad_gpio_porta;
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
reg [31:0] expected_samples [0:CAPTURE_WORDS-1];
integer expected_count;
integer i2s_data_read_count;
integer sdram_write_count;
integer check_done;
reg [8*256-1:0] hex_file;

assign uart1_rxd = 1'b0;
assign uart2_rxd = 1'b0;
assign timer0_extin = 1'b0;
assign timer1_extin = 1'b0;
assign tms = 1'b0;
assign b_pad_gpio_porta = 8'hzz;

top u_soc (
    .CLK              (clk),
    .RESETn           (resetn),
    .TDI              (tdi),
    .TCK              (tck),
    .TMS              (tms),
    .TDO              (tdo),
    .b_pad_gpio_porta (b_pad_gpio_porta),
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

test1_sdram_model u_sdram_model (
    .CLK  (SDRAM_CLK),
    .CKE  (SDRAM_CKE),
    .CSn  (SDRAM_CSn),
    .RASn (SDRAM_RASn),
    .CASn (SDRAM_CASn),
    .WEn  (SDRAM_WEn),
    .ADDR (SDRAM_ADDR),
    .BA   (SDRAM_BA),
    .DQ   (SDRAM_DQ),
    .DQM  (SDRAM_DQM)
);

always #(`PERIOD/2) clk = ~clk;

initial begin
    $timeformat(-9, 3, " ns", 12);

    clk = 1'b1;
    resetn = 1'b0;
    tdi = 1'b0;
    tck = 1'b0;
    i2s_sd = 1'b0;
    mic_sample = 24'h001234;
    i2s_bit_cnt = 6'd0;
    i2s_ws_d = 1'b0;
    expected_count = 0;
    i2s_data_read_count = 0;
    sdram_write_count = 0;
    check_done = 0;

    if (!$value$plusargs("HEX=%s", hex_file)) begin
        hex_file = "firmware/prj/keil/output/outfile.bin";
    end

    $readmemh(hex_file, u_soc.U_SRAM.memory);
    $display("* ram loaded successfully: %0s", hex_file);

    #(`PERIOD*20);
    resetn = 1'b1;
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
            mic_sample <= mic_sample + 24'h000111;
        end
    end
end

always @(posedge u_soc.HCLK) begin
    if (resetn && u_soc.u_ahb_i2s_fifo.u_i2s_rx.sample_valid) begin
        if (expected_count < CAPTURE_WORDS) begin
            expected_samples[expected_count] <= u_soc.u_ahb_i2s_fifo.u_i2s_rx.sample_data;
        end
        expected_count = expected_count + 1;
    end
end

always @(posedge u_soc.HCLK) begin
    if (resetn &&
        u_soc.hselmi3 &&
        u_soc.hreadymuxmi3 &&
        u_soc.hreadyoutmi3 &&
        u_soc.htransmi3[1] &&
        !u_soc.hwritemi3 &&
        u_soc.haddrmi3[7:0] == 8'h08) begin
        i2s_data_read_count = i2s_data_read_count + 1;
        #1;
        $display("* %0t: I2S DATA read[%0d] = 0x%08h, fifo_level = %0d",
                 $time, i2s_data_read_count, u_soc.hrdatami3,
                 u_soc.u_ahb_i2s_fifo.fifo_level);
    end
end

always @(posedge u_soc.HCLK) begin
    if (resetn &&
        u_soc.hselmi2 &&
        u_soc.hreadymuxmi2 &&
        u_soc.hreadyoutmi2 &&
        u_soc.htransmi2[1] &&
        u_soc.hwritemi2) begin
        sdram_write_count = sdram_write_count + 1;
        $display("* %0t: SDRAM write[%0d] addr=0x%08h data=0x%08h",
                 $time, sdram_write_count, u_soc.haddrmi2, u_soc.hwdatami2);
    end
end

always @(posedge u_soc.HCLK) begin
    if (resetn && !check_done && u_soc.U_SRAM.memory[DBG_DONE_WORD] == DBG_DONE_VALUE) begin
        check_done = 1;
        check_sdram_contents;
        $finish;
    end
end

task check_sdram_contents;
    integer idx;
    reg [31:0] actual;
    reg [31:0] expected;
    begin
        $display("* DBG_DONE observed, checking SDRAM model contents");

        if (i2s_data_read_count < CAPTURE_WORDS) begin
            $display("[FAIL] only observed %0d I2S DATA reads, expected %0d",
                     i2s_data_read_count, CAPTURE_WORDS);
            $stop;
        end

        if (sdram_write_count < CAPTURE_WORDS) begin
            $display("[FAIL] only observed %0d SDRAM writes, expected %0d",
                     sdram_write_count, CAPTURE_WORDS);
            $stop;
        end

        if (expected_count < CAPTURE_WORDS) begin
            $display("[FAIL] only captured %0d expected I2S samples, expected %0d",
                     expected_count, CAPTURE_WORDS);
            $stop;
        end

        for (idx = 0; idx < CAPTURE_WORDS; idx = idx + 1) begin
            expected = expected_samples[idx];
            actual = {u_sdram_model.mem[(idx * 2) + 1], u_sdram_model.mem[idx * 2]};

            if (actual !== expected) begin
                $display("[FAIL] SDRAM mismatch at index %0d", idx);
                $display("       model halfword index = %0d/%0d", idx * 2, (idx * 2) + 1);
                $display("       expected = 0x%08h, actual = 0x%08h", expected, actual);
                $display("       DBG_INDEX=0x%08h DBG_SAMPLE=0x%08h DBG_STATUS=0x%08h",
                         u_soc.U_SRAM.memory[DBG_INDEX_WORD],
                         u_soc.U_SRAM.memory[DBG_SAMPLE_WORD],
                         u_soc.U_SRAM.memory[DBG_STATUS_WORD]);
                $stop;
            end
        end

        $display("[PASS] I2S FIFO SDRAM CHECK PASS: %0d words matched", CAPTURE_WORDS);
    end
endtask

initial begin
    #2_000_000;
    $display("[FAIL] simulation timeout");
    $display("       expected_count=%0d i2s_reads=%0d sdram_writes=%0d DBG_DONE=0x%08h",
             expected_count, i2s_data_read_count, sdram_write_count,
             u_soc.U_SRAM.memory[DBG_DONE_WORD]);
    $stop;
end

endmodule

module test1_sdram_model (
    input              CLK,
    input              CKE,
    input              CSn,
    input              RASn,
    input              CASn,
    input              WEn,
    input  [12:0]      ADDR,
    input  [ 1:0]      BA,
    inout  [15:0]      DQ,
    input  [ 1:0]      DQM
);

reg [15:0] mem [0:65535];
reg [15:0] dq_out;
reg        dq_oe;
reg [12:0] active_row;
reg [ 1:0] active_bank;
reg [ 9:0] active_col;
reg [15:0] write_first;
reg [15:0] write_addr_idx;
reg        write_phase;
reg [ 1:0] read_count;
reg        read_pending;

assign DQ = dq_oe ? dq_out : 16'hzzzz;

function [15:0] addr_index;
    input [1:0] bank;
    input [12:0] row;
    input [9:0] col;
    reg [24:0] temp;
    begin
        temp = {bank, row, col};
        addr_index = temp[15:0];
    end
endfunction

integer init_i;
initial begin
    dq_oe = 1'b0;
    read_pending = 1'b0;
    write_phase = 1'b0;
    for (init_i = 0; init_i < 65536; init_i = init_i + 1) begin
        mem[init_i] = 16'h0000;
    end
end

always @(posedge CLK) begin
    if (!CKE || CSn) begin
        dq_oe <= 1'b0;
        read_pending <= 1'b0;
        write_phase <= 1'b0;
    end else begin
        if (!RASn && CASn && WEn) begin
            active_row <= ADDR;
            active_bank <= BA;
            read_pending <= 1'b0;
            write_phase <= 1'b0;
        end

        if (RASn && !CASn && WEn) begin
            active_col <= ADDR[9:0];
            read_pending <= 1'b1;
            read_count <= 0;
            dq_oe <= 1'b0;
        end

        if (RASn && !CASn && !WEn) begin
            active_col <= ADDR[9:0];
            write_first <= DQ;
            write_addr_idx <= addr_index(BA, active_row, ADDR[9:0]);
            write_phase <= 1'b1;
            dq_oe <= 1'b0;
        end else if (write_phase) begin
            if (!DQM[0]) begin
                mem[write_addr_idx][7:0] <= write_first[7:0];
            end
            if (!DQM[1]) begin
                mem[write_addr_idx][15:8] <= write_first[15:8];
            end
            if (!DQM[0]) begin
                mem[write_addr_idx + 1][7:0] <= DQ[7:0];
            end
            if (!DQM[1]) begin
                mem[write_addr_idx + 1][15:8] <= DQ[15:8];
            end
            write_phase <= 1'b0;
        end

        if (read_pending) begin
            case (read_count)
                0: begin
                    dq_out <= mem[addr_index(active_bank, active_row, active_col)];
                    dq_oe <= 1'b1;
                    read_count <= 1;
                end
                1: begin
                    dq_out <= mem[addr_index(active_bank, active_row, active_col) + 1];
                    dq_oe <= 1'b1;
                    read_count <= 2;
                end
                default: begin
                    dq_oe <= 1'b0;
                    read_pending <= 1'b0;
                end
            endcase
        end
    end
end

endmodule
