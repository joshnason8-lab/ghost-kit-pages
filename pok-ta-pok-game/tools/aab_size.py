#!/usr/bin/env python3
"""The sizes Google Play cares about in an Android App Bundle (.aab).

Play's limit is 200 MB for the base module, compressed (assets beyond it need Play Asset Delivery). This prints the
bundle's size, each module's compressed size, and what one phone downloads (the base without the other ABI's native
libraries, plus the asset packs installed with it), and exits 1 if the base module is over the limit.

Usage: python3 tools/aab_size.py path/to/game.aab
"""
import sys
import zipfile

LIMIT = 200 * 1024 * 1024
MB = 1024 * 1024


def main() -> int:
    path = sys.argv[1]
    z = zipfile.ZipFile(path)
    modules: dict[str, int] = {}
    libs: dict[str, int] = {}
    for info in z.infolist():
        module = info.filename.split("/", 1)[0] if "/" in info.filename else "(bundle)"
        modules[module] = modules.get(module, 0) + info.compress_size
        parts = info.filename.split("/")
        if len(parts) > 3 and parts[1] == "lib":
            libs[parts[2]] = libs.get(parts[2], 0) + info.compress_size
    import os
    print(f"bundle {os.path.getsize(path) / MB:.1f} MB")
    for m, n in sorted(modules.items()):
        print(f"  module {m}: {n / MB:.1f} MB compressed")
    base = modules.get("base", 0)
    # Asset packs delivered at install (Godot puts the game's data in one) come with the base.
    packs = sum(n for m, n in modules.items() if m not in ("base", "(bundle)", "BUNDLE-METADATA"))
    for abi, n in sorted(libs.items()):
        other = sum(v for k, v in libs.items() if k != abi)
        print(f"  a {abi} phone downloads about {(base - other + packs) / MB:.1f} MB (base and asset packs)")
    ok = base <= LIMIT
    print(f"base module {base / MB:.1f} MB of Play's 200 MB: {'ok' if ok else 'OVER: needs Play Asset Delivery'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
