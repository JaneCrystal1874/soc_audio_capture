transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog arm-soc/i2s/simple_sync_fifo.v
vlog arm-soc/i2s/i2s_inmp441_rx.v
vlog arm-soc/i2s/ahb_i2s_fifo.v

vlog "D:/Download/Quartus/quartus/eda/sim_lib/altera_primitives.v"
vlog "D:/Download/Quartus/quartus/eda/sim_lib/220model.v"
vlog "D:/Download/Quartus/quartus/eda/sim_lib/altera_mf.v"
vlog arm-soc/sdram_controller/pll.v
vlog arm-soc/sdram_controller/ahb_lite_sdram.v

vlog arm-soc/matrix/BusMatrix4x4/BusMatrix4x4_default_slave.v
vlog arm-soc/matrix/BusMatrix4x4/InputStage.v
vlog arm-soc/matrix/BusMatrix4x4/OutputArbiter.v
vlog arm-soc/matrix/BusMatrix4x4/OutputStage.v
vlog arm-soc/matrix/BusMatrix4x4/DecoderS0.v
vlog arm-soc/matrix/BusMatrix4x4/DecoderS1.v
vlog arm-soc/matrix/BusMatrix4x4/DecoderS2.v
vlog arm-soc/matrix/BusMatrix4x4/DecoderS3.v
vlog arm-soc/matrix/BusMatrix4x4/BusMatrix4x4.v

vlog arm-soc/AHB2MEM.v

vlog arm-soc/apb/cmsdk_ahb_to_apb.v
vlog arm-soc/apb/cmsdk_apb_slave_mux.v
vlog arm-soc/apb/cmsdk_apb_timer.v
vlog arm-soc/apb/cmsdk_apb_uart.v
vlog arm-soc/apb/gpio_apbif.v
vlog arm-soc/apb/gpio_ctrl.v
vlog arm-soc/apb/gpio.v
vlog arm-soc/apb/apb_subsystem.v

vlog arm-soc/cortexm3ds_logic.v
vlog arm-soc/CORTEXM3INTEGRATIONDS.v
vlog arm-soc/top.v
vlog arm-soc/test.v

vsim work.test +HEX=firmware/prj/keil/output/outfile.bin

add wave -divider "clock reset"
add wave sim:/test/clk
add wave sim:/test/u_soc/HCLK
add wave sim:/test/SDRAM_CLK
add wave sim:/test/resetn

add wave -divider "GPIO key and LED"
add wave sim:/test/key0_n
add wave sim:/test/record_led
add wave -radix binary sim:/test/b_pad_gpio_porta
add wave -radix binary sim:/test/u_soc/u_apb_subsystem/b_pad_gpio_porta

add wave -divider "CPU system AHB"
add wave -radix hex sim:/test/u_soc/haddrs
add wave -radix binary sim:/test/u_soc/htranss
add wave -radix binary sim:/test/u_soc/hwrites
add wave -radix hex sim:/test/u_soc/hwdatas
add wave -radix hex sim:/test/u_soc/hrdatas
add wave sim:/test/u_soc/hreadys

add wave -divider "SRAM MI0"
add wave sim:/test/u_soc/hselmi0
add wave -radix hex sim:/test/u_soc/haddrmi0
add wave sim:/test/u_soc/hwritemi0
add wave -radix hex sim:/test/u_soc/hwdatami0
add wave -radix hex sim:/test/u_soc/hrdatami0

add wave -divider "SDRAM MI2"
add wave sim:/test/u_soc/hselmi2
add wave -radix hex sim:/test/u_soc/haddrmi2
add wave sim:/test/u_soc/hwritemi2
add wave -radix hex sim:/test/u_soc/hwdatami2
add wave sim:/test/u_soc/hreadyoutmi2
add wave sim:/test/SDRAM_CSn
add wave sim:/test/SDRAM_RASn
add wave sim:/test/SDRAM_CASn
add wave sim:/test/SDRAM_WEn
add wave -radix hex sim:/test/SDRAM_ADDR
add wave -radix hex sim:/test/SDRAM_BA
add wave -radix hex sim:/test/SDRAM_DQ
add wave -radix unsigned sim:/test/sdram_write_count

add wave -divider "I2S FIFO MI3"
add wave sim:/test/u_soc/hselmi3
add wave -radix hex sim:/test/u_soc/haddrmi3
add wave sim:/test/u_soc/hwritemi3
add wave -radix hex sim:/test/u_soc/hwdatami3
add wave -radix hex sim:/test/u_soc/hrdatami3
add wave sim:/test/u_soc/u_ahb_i2s_fifo/enable
add wave -radix unsigned sim:/test/u_soc/u_ahb_i2s_fifo/fifo_level
add wave sim:/test/u_soc/u_ahb_i2s_fifo/fifo_empty
add wave sim:/test/u_soc/u_ahb_i2s_fifo/fifo_rd_en
add wave -radix hex sim:/test/u_soc/u_ahb_i2s_fifo/fifo_rdata

add wave -divider "I2S pins and stimulus"
add wave sim:/test/i2s_sck
add wave sim:/test/i2s_ws
add wave sim:/test/i2s_sd
add wave -radix hex sim:/test/mic_sample

run 2 ms
