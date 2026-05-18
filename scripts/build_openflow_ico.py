#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import struct
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: build_openflow_ico.py <png_dir> <output_ico>",
            file=sys.stderr,
        )
        return 1

    png_dir = pathlib.Path(sys.argv[1])
    output_path = pathlib.Path(sys.argv[2])
    sizes = [16, 32, 48, 64, 128, 256]

    images: list[tuple[int, bytes]] = []
    for size in sizes:
        data = (png_dir / f"icon-{size}.png").read_bytes()
        images.append((size, data))

    output_path.parent.mkdir(parents=True, exist_ok=True)

    header = struct.pack("<HHH", 0, 1, len(images))
    entries = bytearray()
    offset = 6 + len(images) * 16
    payload = bytearray()

    for size, data in images:
        width_byte = 0 if size >= 256 else size
        height_byte = 0 if size >= 256 else size
        entries.extend(
            struct.pack(
                "<BBBBHHII",
                width_byte,
                height_byte,
                0,
                0,
                1,
                32,
                len(data),
                offset,
            )
        )
        payload.extend(data)
        offset += len(data)

    output_path.write_bytes(header + entries + payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
