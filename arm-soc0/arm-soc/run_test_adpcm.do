transcript on

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog arm-soc/i2s/ima_adpcm_enc.v
vlog arm-soc/i2s/i2s_adpcm_pack.v
vlog arm-soc/test_adpcm.v

vsim work.test_adpcm

add wave -divider "clock reset"
add wave sim:/test_adpcm/clk
add wave sim:/test_adpcm/resetn
add wave sim:/test_adpcm/clear

add wave -divider "input samples"
add wave sim:/test_adpcm/sample_valid
add wave -radix hex sim:/test_adpcm/sample_data
add wave -radix decimal sim:/test_adpcm/sample_idx

add wave -divider "DUT encoder"
add wave sim:/test_adpcm/u_dut/enc_ready
add wave sim:/test_adpcm/u_dut/enc_valid
add wave -radix hex sim:/test_adpcm/u_dut/enc_pcm
add wave -radix hex sim:/test_adpcm/u_dut/pcm16
add wave -radix unsigned sim:/test_adpcm/u_dut/nibble_count
add wave -radix hex sim:/test_adpcm/u_dut/pack_shift
add wave sim:/test_adpcm/packed_valid
add wave -radix hex sim:/test_adpcm/packed_data

add wave -divider "scoreboard"
add wave -radix unsigned sim:/test_adpcm/expected_word_count
add wave -radix unsigned sim:/test_adpcm/actual_word_count
add wave -radix unsigned sim:/test_adpcm/mismatch_count

run -all
