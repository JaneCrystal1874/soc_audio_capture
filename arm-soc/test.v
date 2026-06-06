`timescale 1ns/1ns
`define PERIOD 20

module test;

reg clk;
reg resetn;
reg tdi;
reg tck;
wire tms;
wire tdo;
wire [7:0] b_pad_gpio_porta;
reg  key0_n;
wire record_led;
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
integer    sdram_write_count;

assign record_led = b_pad_gpio_porta[0];

// GPIO bit4 在软件中作为 KEY0 输入，DE10-Lite KEY 按下为低电平。
// 其他 GPIO 位由 DUT 或板外电路决定，testbench 不主动驱动。
assign b_pad_gpio_porta[4] = key0_n;

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

assign uart1_rxd = 1'b0;
assign uart2_rxd = 1'b0;
assign timer0_extin = 1'b0;
assign timer1_extin = 1'b0;

always #(`PERIOD/2) clk = ~clk;

initial begin
    clk = 1'b1;
    resetn = 1'b0;
    tdi = 1'b0;
    tck = 1'b0;
    key0_n = 1'b1;
    i2s_sd = 1'b0;
    mic_sample = 24'h001234;
    i2s_bit_cnt = 6'd0;
    i2s_ws_d = 1'b0;
    sdram_write_count = 0;

    if (!$value$plusargs("HEX=%s", hex_file)) begin
        hex_file = "firmware/prj/keil/output/outfile.bin";
    end

    $readmemh(hex_file, u_soc.U_SRAM.memory);
    $display("* ram loaded successfully: %0s", hex_file);

    #(`PERIOD*20) resetn = 1'b1;

    // 复位释放后等待一小段时间，再模拟按下 KEY0 触发录音。
    #2000 key0_n = 1'b0;
    $display("* KEY0 pressed, recording should start");
end

// 简单的 INMP441-like I2S 激励。
// DUT 在 SCK 上升沿采样 SD，所以 testbench 在 SCK 下降沿更新 SD。
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

// 观察录音指示灯。
always @(record_led) begin
    if (resetn) begin
        $display("* %0t ns: record_led = %0b", $time, record_led);
    end
end

// 观察 CPU 从 I2S FIFO 读样本。
always @(posedge clk) begin
    if (resetn &&
        u_soc.hselmi3 &&
        u_soc.hreadymuxmi3 &&
        u_soc.hreadyoutmi3 &&
        (u_soc.htransmi3[1] == 1'b1) &&
        (u_soc.hwritemi3 == 1'b0) &&
        (u_soc.haddrmi3[7:0] == 8'h08)) begin
        $display("* %0t ns: I2S DATA read = 0x%08h, fifo_level = %0d",
                 $time, u_soc.hrdatami3, u_soc.u_ahb_i2s_fifo.fifo_level);
    end
end

// 观察 CPU 向 SDRAM 地址空间发起写事务。
// 当前 testbench 没有接 SDRAM memory model，因此这里验证的是 AHB 写事务和 SDRAM 控制器响应。
always @(posedge clk) begin
    if (resetn &&
        u_soc.hselmi2 &&
        u_soc.hreadymuxmi2 &&
        u_soc.hreadyoutmi2 &&
        (u_soc.htransmi2[1] == 1'b1) &&
        (u_soc.hwritemi2 == 1'b1)) begin
        sdram_write_count = sdram_write_count + 1;
        $display("* %0t ns: SDRAM write[%0d] addr=0x%08h data=0x%08h",
                 $time, sdram_write_count, u_soc.haddrmi2, u_soc.hwdatami2);

        if (sdram_write_count == 16) begin
            $display("* observed 16 SDRAM writes, I2S -> FIFO -> CPU -> SDRAM path is active");
        end
    end
end

initial begin
    #20_000_000;
    $display("* simulation timeout, observed SDRAM writes = %0d", sdram_write_count);
    $stop;
end

endmodule
