
# keil中导出SDRAM数据
# SW1=0 原始PCM模式: 25MHz HCLK下25s录音, 305176 samples * 4 bytes = 0x12A060 bytes
SAVE E:\SEU\M-spring\SOC\soc-wuxi-arm\sdram_audio.hex 0x60000000,0x6012A05F
# 当前arm-soc/quartus硬件实际采样率约为 12207.03125Hz；WAV头只能写整数采样率，这里取最接近的12207Hz
python ./tools/ihex_to_wav.py sdram_audio.hex sdram_pcm.wav --mode pcm


# SW1=1 IMA ADPCM模式: 25MHz HCLK下25s录音, 305176 samples / 8 = 38147 words = 0x2540C bytes
SAVE E:\SEU\M-spring\SOC\soc-wuxi-arm\sdram_audio_adpcm.hex 0x60000000,0x6002540B
python ./tools/ihex_to_wav.py sdram_audio_adpcm.hex sdram_adpcm.wav --mode adpcm

# 离线模拟硬件ADPCM压缩: 先用SW1=0录PCM并导出pcm_record.hex，再模拟i2s_adpcm_pack.v + ima_adpcm_enc.v
python ./tools/pcm_hex_to_adpcm_hex.py sdram_audio.hex sim_adpcm.hex --max-words 305176
python ./tools/ihex_to_wav.py sim_adpcm.hex sim_adpcm.wav --mode adpcm
