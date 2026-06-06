# ARM SoC Audio Capture Project

ARM Cortex-M3 SoC project for DE10-Lite / MAX 10. The hardware integrates APB peripherals, SRAM/SDRAM access, I2S microphone capture, and IMA ADPCM audio compression support.

## Overview

- Cortex-M3 based SoC RTL with AHB/APB interconnect.
- SDRAM controller for external memory capture.
- I2S receive path for INMP441-style microphone input.
- Optional IMA ADPCM compression path for reduced SDRAM storage usage.
- Firmware project for basic SoC bring-up and SDRAM data export.
- Python utilities for converting exported memory data into WAV audio.

## Project Layout

```text
.
|-- arm-soc/                 # Active RTL and simulation files
|   |-- apb/                 # APB timer, UART, GPIO and bridge modules
|   |-- i2s/                 # I2S receive path and ADPCM packer
|   |-- matrix/              # AHB bus matrix modules
|   |-- sdram_controller/    # AHB-Lite SDRAM controller and PLL IP
|   `-- sram/                # AHB SRAM wrapper and SRAM IP files
|-- quartus/                 # Active Quartus project
|-- firmware/            # Cortex-M3 firmware project for Keil/IAR
|-- ima_adpcm_enc_dec/       # Upstream IMA ADPCM codec submodule
|-- tools/                   # Intel HEX, PCM, ADPCM and WAV conversion tools
|-- arm-soc0/                # Older RTL snapshot kept for comparison
|-- quartus0/                # Older Quartus snapshot kept for comparison
`-- readme.txt               # Original SDRAM export notes
```

## Version Notes

- Treat `arm-soc/` and `quartus/` as the active hardware project.
- `arm-soc0/arm-soc/` is an older hardware snapshot. The file names match `arm-soc/`; current content differences are mainly in:
  - `top.v`
  - `i2s/i2s_adpcm_pack.v`
  - `sdram_controller/ahb_lite_sdram.v`
- `quartus0/quartus/` is an older Quartus snapshot.
- `ima_adpcm_enc_dec/` is kept as an upstream codec reference module. The active encoder RTL is also copied into `arm-soc/i2s/ima_adpcm_enc.v` for integration.

## SDRAM Export / Audio Conversion

Original PCM mode, `SW1=0`:

```text
SAVE E:\SEU\M-spring\SOC\soc-wuxi-arm\sdram_audio.hex 0x60000000,0x6012A05F
python ./tools/ihex_to_wav.py sdram_audio.hex sdram_pcm.wav --mode pcm
```

IMA ADPCM mode, `SW1=1`:

```text
SAVE E:\SEU\M-spring\SOC\soc-wuxi-arm\sdram_audio_adpcm.hex 0x60000000,0x6002540B
python ./tools/ihex_to_wav.py sdram_audio_adpcm.hex sdram_adpcm.wav --mode adpcm
```

Offline hardware ADPCM simulation:

```text
python ./tools/pcm_hex_to_adpcm_hex.py sdram_audio.hex sim_adpcm.hex --max-words 305176
python ./tools/ihex_to_wav.py sim_adpcm.hex sim_adpcm.wav --mode adpcm
```
