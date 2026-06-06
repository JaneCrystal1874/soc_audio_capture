#!/usr/bin/env python3
import argparse
import os
import struct
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from ihex_to_wav import IMA_INDEX_TABLE, IMA_STEP_TABLE, read_ihex, sign_extend


DEFAULT_BASE_ADDR = 0x60000000


def clamp(value, low, high):
    return max(low, min(high, value))


def encode_ima_sample(sample16, predictor_samp, step_index):
    """Mirror ima_adpcm_enc.v for one signed 16-bit input sample."""
    step = IMA_STEP_TABLE[step_index]
    diff = (sample16 << 3) - predictor_samp

    nibble = 0
    if diff < 0:
        nibble |= 0x8
        diff = -diff

    dequant = step
    if diff >= (step << 3):
        nibble |= 0x4
        diff -= step << 3
        dequant += step << 3
    if diff >= (step << 2):
        nibble |= 0x2
        diff -= step << 2
        dequant += step << 2
    if diff >= (step << 1):
        nibble |= 0x1
        dequant += step << 1

    if nibble & 0x8:
        predictor_samp -= dequant
    else:
        predictor_samp += dequant
    predictor_samp = clamp(predictor_samp, -262144, 262143)

    step_index = clamp(step_index + IMA_INDEX_TABLE[nibble & 0x7], 0, 88)
    return nibble, predictor_samp, step_index


def iter_pcm16_from_words(raw, endian, skip_words, max_words, attenuate_shift):
    word_count = len(raw) // 4
    if skip_words:
        raw = raw[skip_words * 4:]
        word_count = max(0, word_count - skip_words)
    if max_words is not None:
        word_count = min(word_count, max_words)

    fmt = "<I" if endian == "little" else ">I"
    for i in range(word_count):
        word = struct.unpack_from(fmt, raw, i * 4)[0]
        sample16 = sign_extend((word >> 8) & 0xFFFF, 16)
        if attenuate_shift:
            sample16 >>= attenuate_shift
        yield sample16


def encode_samples_to_adpcm_words(samples):
    predictor_samp = 0
    step_index = 0
    packed_words = []
    pack_word = 0
    nibble_count = 0
    sample_count = 0

    for sample16 in samples:
        nibble, predictor_samp, step_index = encode_ima_sample(
            sample16,
            predictor_samp,
            step_index,
        )
        pack_word |= nibble << (nibble_count * 4)
        nibble_count += 1
        sample_count += 1

        if nibble_count == 8:
            packed_words.append(pack_word)
            pack_word = 0
            nibble_count = 0

    return packed_words, sample_count, nibble_count


def ihex_record(addr16, rectype, payload):
    data = bytes(payload)
    total = len(data) + ((addr16 >> 8) & 0xFF) + (addr16 & 0xFF) + rectype
    total += sum(data)
    checksum = (-total) & 0xFF
    return ":{:02X}{:04X}{:02X}{}{:02X}".format(
        len(data),
        addr16,
        rectype,
        data.hex().upper(),
        checksum,
    )


def write_ihex(path, data, base_addr, record_size=16):
    current_upper = None
    with open(path, "w", encoding="ascii", newline="\n") as f:
        for offset in range(0, len(data), record_size):
            addr = base_addr + offset
            upper = addr >> 16
            if upper != current_upper:
                f.write(ihex_record(0, 0x04, upper.to_bytes(2, "big")) + "\n")
                current_upper = upper

            chunk = data[offset:offset + record_size]
            f.write(ihex_record(addr & 0xFFFF, 0x00, chunk) + "\n")
        f.write(ihex_record(0, 0x01, b"") + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Encode raw PCM SDRAM Intel HEX into hardware-like packed IMA ADPCM HEX."
    )
    parser.add_argument("input_hex")
    parser.add_argument("output_hex")
    parser.add_argument("--input-endian", choices=("little", "big"), default="little",
                        help="Endian used to parse 32-bit PCM words from the input HEX.")
    parser.add_argument("--base-addr", type=lambda x: int(x, 0), default=DEFAULT_BASE_ADDR,
                        help="Base address for the output Intel HEX.")
    parser.add_argument("--skip-words", type=int, default=0)
    parser.add_argument("--max-words", type=int)
    parser.add_argument("--attenuate-shift", type=int, default=0,
                        help="Arithmetic right shift applied to signed pcm16 before ADPCM encoding.")
    args = parser.parse_args()

    if args.attenuate_shift < 0:
        raise ValueError("--attenuate-shift must be >= 0")

    raw, start_addr = read_ihex(args.input_hex)
    samples = iter_pcm16_from_words(
        raw,
        endian=args.input_endian,
        skip_words=args.skip_words,
        max_words=args.max_words,
        attenuate_shift=args.attenuate_shift,
    )
    words, sample_count, trailing_nibbles = encode_samples_to_adpcm_words(samples)
    out_raw = b"".join(struct.pack("<I", word) for word in words)
    write_ihex(args.output_hex, out_raw, args.base_addr)

    print(f"input start address: 0x{start_addr:08X}")
    print(f"input bytes: {len(raw)}")
    print(f"input endian: {args.input_endian}")
    print(f"encoded samples: {sample_count}")
    print(f"output words: {len(words)}")
    print(f"output bytes: {len(out_raw)}")
    print(f"output base address: 0x{args.base_addr:08X}")
    print(f"attenuate shift: {args.attenuate_shift}")
    if trailing_nibbles:
        print(f"dropped trailing samples: {trailing_nibbles}")
    print(f"output hex: {args.output_hex}")


if __name__ == "__main__":
    main()
