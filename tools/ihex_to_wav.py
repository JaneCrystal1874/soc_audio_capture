#!/usr/bin/env python3
import argparse
import struct
import wave

DEFAULT_SAMPLE_RATE = 12207
DEFAULT_PCM_RAW24_LAYOUT = "bytes-1-3-be"
DEFAULT_ADPCM_ENDIAN = "little"

IMA_INDEX_TABLE = (-1, -1, -1, -1, 2, 4, 6, 8)
IMA_STEP_TABLE = (
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
)

# 解析HEX文件的每一行，校验校验和，提取数据内容，支持扩展线性地址 
# 将所有数据按地址拼接成原始二进制流，返回数据和起始地址。
def read_ihex(path):
    data = {}
    upper = 0

    with open(path, "r", encoding="ascii") as f:
        for line_no, raw_line in enumerate(f, 1):
            line = raw_line.strip()
            if not line:
                continue
            if not line.startswith(":"):
                raise ValueError(f"line {line_no}: not an Intel HEX record")

            count = int(line[1:3], 16)
            offset = int(line[3:7], 16)
            rectype = int(line[7:9], 16)
            payload = bytes.fromhex(line[9:9 + count * 2])
            checksum = int(line[9 + count * 2:11 + count * 2], 16)

            total = count + (offset >> 8) + (offset & 0xFF) + rectype
            total += sum(payload) + checksum
            if (total & 0xFF) != 0:
                raise ValueError(f"line {line_no}: checksum mismatch")

            if rectype == 0x00:
                base = upper + offset
                for i, b in enumerate(payload):
                    data[base + i] = b
            elif rectype == 0x01:
                break
            elif rectype == 0x04:
                upper = int.from_bytes(payload, "big") << 16
            else:
                pass

    if not data:
        return b"", 0

    start = min(data)
    end = max(data)
    return bytes(data.get(addr, 0) for addr in range(start, end + 1)), start


def sign_extend(value, bits):
    sign = 1 << (bits - 1)
    return (value ^ sign) - sign

# 将原始二进制流按4字节为单位解析为24位有符号样本，应用增益，裁剪到16位范围，返回PCM16样本列表。
def decode_raw24_word(raw, offset, endian, layout):
    b0, b1, b2, b3 = raw[offset:offset + 4]

    if layout == "word-low24":
        fmt = "<I" if endian == "little" else ">I"
        word = struct.unpack_from(fmt, raw, offset)[0]
        return sign_extend(word & 0xFFFFFF, 24)
    if layout == "word-high24":
        fmt = "<I" if endian == "little" else ">I"
        word = struct.unpack_from(fmt, raw, offset)[0]
        return sign_extend((word >> 8) & 0xFFFFFF, 24)
    if layout == "bytes-0-2-le":
        return sign_extend(b0 | (b1 << 8) | (b2 << 16), 24)
    if layout == "bytes-1-3-le":
        return sign_extend(b1 | (b2 << 8) | (b3 << 16), 24)
    if layout == "bytes-0-2-be":
        return sign_extend((b0 << 16) | (b1 << 8) | b2, 24)
    if layout == "bytes-1-3-be":
        return sign_extend((b1 << 16) | (b2 << 8) | b3, 24)

    raise ValueError(f"unsupported raw24 layout: {layout}")


def convert_raw24_samples(raw, endian, skip_words, max_words, gain, raw_output=False,
                          raw24_layout="word-low24"):
    if len(raw) < 4:
        return []

    word_count = len(raw) // 4
    if skip_words:
        raw = raw[skip_words * 4:]
        word_count = max(0, word_count - skip_words)
    if max_words is not None:
        word_count = min(word_count, max_words)

    if raw_output:
        # 输出原始24位样本，返回list of int（-8388608~8388607）
        pcm24 = []
        for i in range(word_count):
            sample24 = decode_raw24_word(raw, i * 4, endian, raw24_layout)
            pcm24.append(sample24)
        return pcm24
    else:
        pcm16 = []
        for i in range(word_count):
            sample24 = decode_raw24_word(raw, i * 4, endian, raw24_layout)
            sample16 = int((sample24 / 256) * gain)
            if sample16 > 32767:
                sample16 = 32767
            elif sample16 < -32768:
                sample16 = -32768
            pcm16.append(sample16)
        return pcm16


def decode_ima_nibble(nibble, predictor_samp, step_index):
    """Mirror the Verilog decoder's scaled predictor math."""
    step = IMA_STEP_TABLE[step_index]
    dequant = step
    if nibble & 0x4:
        dequant += step << 3
    if nibble & 0x2:
        dequant += step << 2
    if nibble & 0x1:
        dequant += step << 1

    if nibble & 0x8:
        predictor_samp -= dequant
    else:
        predictor_samp += dequant

    predictor_samp = max(-262144, min(262143, predictor_samp))
    step_index = max(0, min(88, step_index + IMA_INDEX_TABLE[nibble & 0x7]))

    # Hardware keeps predictor_samp scaled by 3 fractional bits and rounds bit2.
    sample = (predictor_samp >> 3) + ((predictor_samp >> 2) & 0x1)
    sample = max(-32768, min(32767, sample))
    return sample, predictor_samp, step_index


def convert_ima_adpcm_samples(raw, endian, skip_words, max_words, max_samples=None):
    if len(raw) < 4:
        return []

    word_count = len(raw) // 4
    if skip_words:
        raw = raw[skip_words * 4:]
        word_count = max(0, word_count - skip_words)
    if max_words is not None:
        word_count = min(word_count, max_words)

    fmt = "<I" if endian == "little" else ">I"
    predictor_samp = 0
    step_index = 0
    pcm16 = []

    for i in range(word_count):
        word = struct.unpack_from(fmt, raw, i * 4)[0]
        # Hardware stores sample0 in bits[3:0], sample7 in bits[31:28].
        for shift in range(0, 32, 4):
            sample, predictor_samp, step_index = decode_ima_nibble(
                (word >> shift) & 0xF,
                predictor_samp,
                step_index,
            )
            pcm16.append(sample)
            if max_samples is not None and len(pcm16) >= max_samples:
                return pcm16

    return pcm16


def write_wav(path, pcm, sample_rate, raw_output=False):
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        if raw_output:
            # 24位WAV输出
            wav.setsampwidth(3)
            wav.setframerate(sample_rate)
            # 24位WAV每个样本3字节小端
            for s in pcm:
                # 裁剪到24位范围
                s = max(-8388608, min(8388607, s))
                wav.writeframes(struct.pack('<i', s)[0:3])
        else:
            wav.setsampwidth(2)
            wav.setframerate(sample_rate)
            wav.writeframes(b"".join(struct.pack("<h", s) for s in pcm))


def main():
    parser = argparse.ArgumentParser(
        description="Convert Keil SAVE Intel HEX SDRAM audio dump to mono WAV."
    )
    parser.add_argument("input_hex")
    parser.add_argument("output_wav")
    parser.add_argument("--mode", choices=("pcm", "adpcm"), default="pcm",
                        help="Input dump type. pcm is raw microphone PCM; adpcm is hardware-packed IMA ADPCM.")
    parser.add_argument("--rate", type=int, default=DEFAULT_SAMPLE_RATE)
    args = parser.parse_args()

    raw, start_addr = read_ihex(args.input_hex)
    if args.mode == "adpcm":
        pcm = convert_ima_adpcm_samples(
            raw,
            endian=DEFAULT_ADPCM_ENDIAN,
            skip_words=0,
            max_words=None,
            max_samples=None,
        )
        # ADPCM decodes to linear PCM16.
        write_wav(args.output_wav, pcm, args.rate, raw_output=False)
    else:
        pcm = convert_raw24_samples(
            raw,
            endian=DEFAULT_ADPCM_ENDIAN,
            skip_words=0,
            max_words=None,
            gain=1.0,
            raw_output=True,
            raw24_layout=DEFAULT_PCM_RAW24_LAYOUT,
        )
        write_wav(args.output_wav, pcm, args.rate, raw_output=True)

    print(f"input start address: 0x{start_addr:08X}")
    print(f"mode: {args.mode}")
    print(f"input bytes: {len(raw)}")
    print(f"output samples: {len(pcm)}")
    print(f"output sample rate: {args.rate}")
    print(f"output duration: {len(pcm) / args.rate:.6f} s")
    print(f"output wav: {args.output_wav}")


if __name__ == "__main__":
    main()
