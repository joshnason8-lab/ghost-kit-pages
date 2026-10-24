#!/usr/bin/env python3
"""Check that an APK's or AAB's 64-bit native libraries load on phones with 16 KB memory pages, as Google Play
requires of apps targeting Android 15 and later: every LOAD segment of every arm64-v8a and x86_64 library must be
aligned to at least 16 KB (32-bit libraries may stay at 4 KB).

Usage: python3 tools/check_pages.py build/kabaddi-raid.aab   (or an .apk)
Exits 1 if a 64-bit library is aligned to less than 16 KB.
"""
import struct
import sys
import zipfile

PAGE = 16 * 1024


def load_aligns(data: bytes) -> list:
    if data[:4] != b"\x7fELF":
        return []
    if data[4] == 2:   # 64-bit
        phoff = struct.unpack_from("<Q", data, 0x20)[0]
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
        out = []
        for i in range(phnum):
            p_type = struct.unpack_from("<I", data, phoff + i * phentsize)[0]
            if p_type == 1:
                out.append(struct.unpack_from("<Q", data, phoff + i * phentsize + 48)[0])
        return out
    return []


def main() -> int:
    path = sys.argv[1]
    bad = 0
    seen = 0
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if not name.endswith(".so") or not ("/arm64-v8a/" in name or "/x86_64/" in name):
                continue
            seen += 1
            aligns = load_aligns(z.read(name))
            ok = bool(aligns) and min(aligns) >= PAGE
            bad += 0 if ok else 1
            print(f"{'ok ' if ok else 'BAD'} {name}: LOAD alignment {', '.join(hex(a) for a in aligns)}")
    print(f"{seen} 64-bit libraries, {bad} not aligned to 16 KB")
    return 1 if bad or not seen else 0


if __name__ == "__main__":
    sys.exit(main())
