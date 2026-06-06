transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog arm-soc/i2s/simple_sync_fifo.v
vlog arm-soc/i2s/i2s_inmp441_rx.v
vlog arm-soc/i2s/ima_adpcm_enc.v
vlog arm-soc/i2s/i2s_adpcm_pack.v
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
vlog arm-soc/test_adpcm_top.v

vsim work.test_adpcm_top +HEX=firmware/prj/keil/output/outfile.bin

add wave -divider "clock reset gpio"
add wave sim:/test_adpcm_top/clk
add wave sim:/test_adpcm_top/u_soc/HCLK
add wave sim:/test_adpcm_top/SDRAM_CLK
add wave sim:/test_adpcm_top/resetn
add wave sim:/test_adpcm_top/key0_n
add wave sim:/test_adpcm_top/sw1_adpcm
add wave sim:/test_adpcm_top/record_led
add wave sim:/test_adpcm_top/adpcm_led

add wave -divider "I2S RX"
add wave sim:/test_adpcm_top/i2s_sck
add wave sim:/test_adpcm_top/i2s_ws
add wave sim:/test_adpcm_top/i2s_sd
add wave -radix hex sim:/test_adpcm_top/mic_sample
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_rx/sample_valid
add wave -radix hex sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_rx/sample_data

add wave -divider "ADPCM pack FIFO"
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/adpcm_enable_cfg
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/enc_ready
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/enc_valid
add wave -radix hex sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/enc_pcm
add wave -radix hex sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/pcm16
add wave -radix unsigned sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/nibble_count
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/packed_valid
add wave -radix hex sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/u_i2s_adpcm_pack/packed_data
add wave -radix unsigned sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/fifo_level
add wave -radix hex sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/fifo_wdata
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/fifo_wr_en
add wave sim:/test_adpcm_top/u_soc/u_ahb_i2s_fifo/fifo_rd_en

add wave -divider "SDRAM writes"
add wave sim:/test_adpcm_top/u_soc/hselmi2
add wave -radix hex sim:/test_adpcm_top/u_soc/haddrmi2
add wave sim:/test_adpcm_top/u_soc/hwritemi2
add wave -radix hex sim:/test_adpcm_top/u_soc/hwdatami2
add wave -radix unsigned sim:/test_adpcm_top/expected_word_count
add wave -radix unsigned sim:/test_adpcm_top/actual_word_count
add wave -radix unsigned sim:/test_adpcm_top/mismatch_count

run -all
