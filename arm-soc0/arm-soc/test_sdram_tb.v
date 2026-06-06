`timescale 1ns/1ns
`define PERIOD 20

module test_sdram_tb;

reg clk;
reg resetn;
reg tdi;
reg tck;
reg [15:0] dq_driver;  // TB 驱动 DQ 的寄存器
reg        dq_en;      // 开关：1 时 TB 往总线写，0 时释放总线（由模型写）

wire tms;
wire tdo;
wire [7:0] b_pad_gpio_porta;
wire uart1_rxd;
wire uart2_rxd;
wire timer0_extin;
wire timer1_extin;

wire [12:0] DRAM_ADDR;
wire [ 1:0] DRAM_BA;
wire        DRAM_CAS_N;
wire        DRAM_CKE;
wire        DRAM_CS_N;
wire [15:0] DRAM_DQ;
wire        DRAM_LDQM;
wire        DRAM_RAS_N;
wire        DRAM_UDQM;
wire        DRAM_WE_N;

// tie unused inputs low
assign uart1_rxd = 1'b0;
assign uart2_rxd = 1'b0;
assign timer0_extin = 1'b0;
assign timer1_extin = 1'b0;
assign tms = 1'b0;
assign b_pad_gpio_porta = 8'hzz;
// 这一行逻辑：如果 dq_en 为高，就把 dq_driver 的值放到总线上，否则悬空
assign DRAM_DQ = dq_en ? dq_driver : 16'hzzzz;

// Drive the DUT
 top u_soc (
    .CLK               (clk),
    .RESETn            (resetn),
    .TDI               (tdi),
    .TCK               (tck),
    .TMS               (tms),
    .TDO               (tdo),
    .b_pad_gpio_porta  (b_pad_gpio_porta),
    .uart1_rxd         (uart1_rxd),
    .uart1_txd         (),
    .uart2_rxd         (uart2_rxd),
    .uart2_txd         (),
    .timer0_extin      (timer0_extin),
    .timer1_extin      (timer1_extin),
    .DRAM_ADDR         (DRAM_ADDR),
    .DRAM_BA           (DRAM_BA),
    .DRAM_CAS_N        (DRAM_CAS_N),
    .DRAM_CKE          (DRAM_CKE),
    .DRAM_CS_N         (DRAM_CS_N),
    .DRAM_DQ           (DRAM_DQ),
    .DRAM_LDQM         (DRAM_LDQM),
    .DRAM_RAS_N        (DRAM_RAS_N),
    .DRAM_UDQM         (DRAM_UDQM),
    .DRAM_WE_N         (DRAM_WE_N)
 );

sdram_model u_sdram_model (
    .CLK    (clk),
    .CKE    (DRAM_CKE),
    .CSn    (DRAM_CS_N),
    .RASn   (DRAM_RAS_N),
    .CASn   (DRAM_CAS_N),
    .WEn    (DRAM_WE_N),
    .ADDR   (DRAM_ADDR),
    .BA     (DRAM_BA),
    .DQ     (DRAM_DQ),
    .DQM    ({DRAM_UDQM, DRAM_LDQM})
 );

always #(`PERIOD/2) clk = ~clk;

initial 
    begin
        // 初始化信号状态
        dq_driver = 0;
        dq_en = 0;
        resetn = 0;
        clk = 0;

        $readmemh("E:/SOC_design/firmware/prj/keil/output/outfile.bin", u_soc.U_SRAM.memory);
        $display("*\  ram loaded successfully !");

        #200;
        resetn = 1;      //释放复位
        #20000;         //运行一段时间观察行为
        $display("[TB] Checking SDRAM memory at the end of software execution...");
    if (u_sdram_model.mem[0] !== 0)
        $display("[SUCCESS] Software successfully wrote to SDRAM: %h", u_sdram_model.mem[0]);
    else
        $display("[FAILURE] SDRAM is still empty. Did the software run?");
        $finish;
    end

endmodule

module sdram_model (
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

integer i;
initial begin
    dq_oe = 1'b0;
    read_pending = 1'b0;
    write_phase = 1'b0;
    for (i = 0; i < 65536; i = i + 1) begin
        mem[i] = 16'h0000;   //全部刷新成0
    end
end

always @(posedge CLK) begin
    if (!CKE || CSn) begin
        dq_oe <= 1'b0;
        read_pending <= 1'b0;
        write_phase <= 1'b0;
    end 
    else begin
        // --- 增加对预充电和刷新的识别 ---
        if (!RASn && !CASn && !WEn) begin
            $display("    [Model] Mode Register Set Detected: %h", ADDR);
        end
        
        if (!RASn && !CASn && WEn) begin
            $display("    [Model] Auto Refresh Detected");
        end

        if (!RASn && CASn && !WEn) begin
            $display("    [Model] Precharge Detected (Bank: %b, All: %b)", BA, ADDR[10]);
        end
        // ------------------------------

        if (!RASn && CASn && WEn) begin // ACTIVATE
            active_row <= ADDR;
            active_bank <= BA;
        end

        //读写逻辑
        if (!CSn && !RASn && CASn && WEn) begin
            active_row <= ADDR;
            active_bank <= BA;
            read_pending <= 1'b0;
            write_phase <= 1'b0;
        end

        if (!CSn && RASn && !CASn && WEn) begin
            active_col <= ADDR[9:0];
            read_pending <= 1'b1;
            read_count <= 0;
            dq_oe <= 1'b0;
        end

        if (!CSn && RASn && !CASn && !WEn) begin
            active_col <= ADDR[9:0];
            write_first <= DQ;
            write_addr_idx <= addr_index(BA, active_row, ADDR[9:0]);
            write_phase <= 1'b1;
            dq_oe <= 1'b0;
        end else if (write_phase) begin
            mem[write_addr_idx] <= write_first;
            mem[write_addr_idx + 1] <= DQ;
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

