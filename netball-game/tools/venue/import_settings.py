#!/usr/bin/env python3
"""Sets the import options of the venue textures (assets/venue): VRAM-compressed with mipmaps for everything drawn
in 3D, no mipmaps for the sky panorama, the HDRs kept lossless but limited to 512 px (light and blurred reflections
only), the block wall's normal map kept as RGB. Run after a first `godot --headless --path . --import`, then import
again. Usage (from netball-game/): python3 tools/venue/import_settings.py"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "venue"


def setp(text, key, value):
    return re.sub(r"(?m)^%s=.*$" % re.escape(key), "%s=%s" % (key, value), text)


for imp in sorted(ROOT.rglob("*.import")):
    name = imp.name[:-len(".import")]
    t = imp.read_text()
    if 'importer="texture"' not in t:
        continue
    t = setp(t, "detect_3d/compress_to", "0")
    t = setp(t, "mipmaps/generate", "true")
    if name.endswith(".hdr"):
        t = setp(t, "compress/mode", "0")
        t = setp(t, "process/size_limit", "512")
    else:
        t = setp(t, "compress/mode", "2")
    if "_normal_" in name:
        t = setp(t, "compress/normal_map", "2")
    if "_sky_" in name:
        t = setp(t, "mipmaps/generate", "false")
    imp.write_text(t)
    print("set", imp.relative_to(ROOT))
