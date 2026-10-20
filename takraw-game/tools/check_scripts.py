#!/usr/bin/env python3
"""Parse every script on its own and print any errors, with where they are.

A script that fails to parse can stall Godot rather than fail, so run this first when something hangs. Autoloads
are not loaded here, so their names (Game, DB, Sfx) are not errors.

Usage: python3 tools/check_scripts.py [godot binary]
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
IGNORE = re.compile(r"Identifier not found: (Game|DB|Sfx)\b|Failed to compile depended")


def main() -> int:
    godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
    bad = 0
    files = sorted(p for d in ["autoload", "game", "ui", "tests"] for p in (ROOT / d).rglob("*.gd")) + [ROOT / "main.gd"]
    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        out = subprocess.run([godot, "--headless", "--path", str(ROOT), "--check-only", "--script", rel],
                             capture_output=True, text=True, timeout=60).stderr + ""
        lines = out.splitlines()
        errs = []
        for i, line in enumerate(lines):
            if "SCRIPT ERROR" in line and not IGNORE.search(line):
                where = lines[i + 1].strip() if i + 1 < len(lines) else ""
                errs.append(f"{line.strip()}\n      {where}")
        if errs:
            bad += 1
            print(f"== {rel}")
            print("\n".join(errs))
    print(f"check_scripts: {len(files)} scripts, {bad} with errors")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
