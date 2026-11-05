#!/usr/bin/env python3
"""The HD pack's export preset ("Android HD pack" in export_presets.cfg): the Android preset's options, exporting
only the files under ultra/ (the Ultra graphics content; the APK leaves them out). Writes or refreshes the preset with
every file there now, then the pack is exported with
  godot --headless --path . --export-pack "Android HD pack" build/hurling-heroes-hd-<PACK>.pck
(tools/ultra/build_pack.sh does both and writes the manifest.)
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
P = ROOT / "export_presets.cfg"


def main():
    s = P.read_text()
    files = sorted("res://" + str(f.relative_to(ROOT)) for f in (ROOT / "ultra").rglob("*")
                   if f.is_file() and f.suffix not in (".import", ".uid") and not f.name.startswith("."))
    # The Android preset's options block, to copy.
    m = re.search(r"\[preset\.0\.options\]\n(.*?)(?=\n\[preset\.|\Z)", s, re.S)
    opts = m.group(1).rstrip("\n")
    # Any earlier HD pack preset goes; the new one is added at the end.
    s = re.sub(r"\n\[preset\.(\d+)\]\n\nname=\"Android HD pack\".*?(?=\n\[preset\.(?!\1\.options)|\Z)", "", s, flags=re.S)
    n = len(re.findall(r"^\[preset\.\d+\]$", s, re.M))
    lst = ", ".join('"%s"' % f for f in files)
    s = s.rstrip("\n") + f'''

[preset.{n}]

name="Android HD pack"
platform="Android"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray({lst})
include_filter=""
exclude_filter=""
export_path="build/hurling-heroes-hd.pck"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{n}.options]

{opts}
'''
    P.write_text(s)
    print(f"export_presets.cfg: the HD pack preset with {len(files)} files")


if __name__ == "__main__":
    main()
