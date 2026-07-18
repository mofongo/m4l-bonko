#!/usr/bin/env python3
"""Build an .amxd by transplanting patcher JSON into a reference .amxd's
binary chunk header.

An .amxd is a chunked binary container whose final chunk holds the patcher
JSON. Rather than hard-coding the chunk layout, this script finds where the
JSON payload begins in a known-good reference file, checks that the 4 bytes
immediately before it encode that payload's length (trying both endiannesses),
and rewrites that length for the new payload.

Usage: python3 tools/make_amxd.py <reference.amxd> <input.maxpat> <output.amxd>
"""
import json
import struct
import sys


def build(ref_path, maxpat_path, out_path):
    with open(ref_path, "rb") as f:
        ref = f.read()
    idx = ref.find(b'{')
    if idx < 8:
        sys.exit(f"error: no JSON payload found in reference {ref_path}")
    ref_json_len = len(ref) - idx
    header = bytearray(ref[:idx])
    size_bytes = bytes(header[-4:])
    endian = None
    for fmt in ("<I", ">I"):
        if struct.unpack(fmt, size_bytes)[0] == ref_json_len:
            endian = fmt
            break
    if endian is None:
        sys.exit(
            "error: could not confirm payload-length field in reference header "
            f"(last-4-bytes={size_bytes.hex()}, json_len={ref_json_len}). "
            "Use the manual fallback (paste patch into a blank device in Max)."
        )
    with open(maxpat_path) as f:
        payload = json.dumps(json.load(f)).encode("utf-8")
    header[-4:] = struct.pack(endian, len(payload))
    with open(out_path, "wb") as f:
        f.write(bytes(header) + payload)
    # round-trip check: extracted JSON must parse and match input
    with open(out_path, "rb") as f:
        out = f.read()
    extracted = out[out.find(b'{'):]
    assert json.loads(extracted) == json.loads(payload), "round-trip mismatch"
    print(f"OK: wrote {out_path} ({len(payload)} bytes JSON, endian {endian})")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    build(*sys.argv[1:4])
