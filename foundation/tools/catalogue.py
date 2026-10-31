#!/usr/bin/env python3
"""Writes docs/CATALOGUE.md: the licensed clip library by name only (its length, loop or once, a line on what it
is, and which games use it) - for the game sessions to choose from. The clips themselves stay private and build-only
(addons/wsg_foundation/data/, from the private assets repo): this reads that folder's *.json for names and lengths
and writes nothing else from it.
  python3 tools/catalogue.py            (with the licensed data fetched: tools/fetch_assets.sh)
"""
import json
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE.parent / "addons" / "wsg_foundation" / "data"
OUT = HERE.parent / "docs" / "CATALOGUE.md"

# Which games use a clip (by name, or a prefix ending in *). The locomotion set drives every game's runner.
USED = {
    "Walk_*": "all (WsgLocomotor)", "Jog_*": "all (WsgLocomotor)", "Run_*": "all (WsgLocomotor)",
    "Stand_Relaxed_To_*": "all (WsgLocomotor: starts)", "Stand_Relaxed_Idle*": "all (WsgLocomotor: standing)",
    "Stand_Relaxed_L_*": "all (WsgLocomotor: turns)", "Stand_Relaxed_R_*": "all (WsgLocomotor: turns)",
    "Stand_Rlx_Turn_*": "all (WsgLocomotor: turns)", "Sprint_F_Loop": "all (WsgLocomotor: sprint)",
    "Crowd_*": "all (WsgCrowd3D)", "Ready_Stance": "Hurling", "Dive_Forward": "Hurling",
    "Celebrate_*": "Hurling (scorer)", "Disappointed_HandsOnHead": "Hurling",
}

WORDS = {
    "F": "forward", "B": "backward", "L": "left", "R": "right", "FL": "forward-left", "FR": "forward-right",
    "BL": "back-left", "BR": "back-right", "BkPd": "backpedal", "CIR": "circling", "Rlx": "relaxed",
    "LU": "left foot up", "RU": "right foot up", "Conv": "conversation", "Fgt": "fidget", "D90": "down",
    "U90": "up", "LD45": "down-left", "LU45": "up-left", "RD45": "down-right", "RU45": "up-right",
}


def used_by(name):
    for k, v in USED.items():
        if (k.endswith("*") and name.startswith(k[:-1])) or k == name:
            return v
    return ""


def describe(name):
    parts = [p for p in re.split(r"_", name) if p and p != "Loop"]
    out = []
    for p in parts:
        out.append(WORDS.get(p, p.lower() if not re.fullmatch(r"v\d", p) else "(" + p + ")"))
    text = " ".join(out).replace("stand relaxed", "standing").replace(" to ", " to ")
    return text[0].upper() + text[1:] if text else name


def main():
    rows = []
    for f in sorted(DATA.glob("*.json")):
        d = json.loads(f.read_text())
        clips = d.get("clips", {}) if isinstance(d, dict) else {}
        if not isinstance(clips, dict) or not clips:
            continue
        src = d.get("source", f.stem) if isinstance(d.get("source"), str) else f.stem
        for name, c in sorted(clips.items()):
            if not isinstance(c, dict) or "length" not in c:
                continue
            rows.append((f.stem, name, float(c["length"]), "loop" if c.get("kind") == "loop" else "once", describe(name),
                         used_by(name)))
    lines = [
        "# The clip library (names only)",
        "",
        "The motion capture the owner bought, as the foundation's builds have it: the MoCap Online Mobility pack and the",
        "ActorCore moves baked so far. **Names only**: the animation is licensed and lives only in the private assets",
        "repo and inside compiled APKs (addons/wsg_foundation/data/, fetched at build time). A game session that wants a",
        "clip wired in asks the foundation session by name. Written by tools/catalogue.py.",
        "",
        "More ActorCore takes are in the private zip than are baked here (tools/bake_actorcore.gd's CLIPS picks them):",
        "the foundation's CI prints the zip's take names (names only) in the licensed-assets step's log.",
        "",
        "| Set | Clip | Length (s) | Kind | What | Used by |",
        "|---|---|---:|---|---|---|",
    ]
    for r in rows:
        lines.append("| %s | `%s` | %.2f | %s | %s | %s |" % r)
    lines.append("")
    lines.append("%d clips." % len(rows))
    OUT.write_text("\n".join(lines) + "\n")
    print("catalogue: %d clips -> %s" % (len(rows), OUT))


if __name__ == "__main__":
    main()
