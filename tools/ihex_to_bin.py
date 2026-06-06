#!/usr/bin/env python3
import argparse


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

    if not data:
        return b"", 0

    start = min(data)
    end = max(data)
    return bytes(data.get(addr, 0) for addr in range(start, end + 1)), start


def main():
    parser = argparse.ArgumentParser(description="Convert an Intel HEX memory dump to a raw binary file.")
    parser.add_argument("input_hex")
    parser.add_argument("output_bin")
    args = parser.parse_args()

    raw, start_addr = read_ihex(args.input_hex)
    with open(args.output_bin, "wb") as f:
        f.write(raw)

    print(f"input start address: 0x{start_addr:08X}")
    print(f"output bytes: {len(raw)}")
    print(f"output file: {args.output_bin}")


if __name__ == "__main__":
    main()
