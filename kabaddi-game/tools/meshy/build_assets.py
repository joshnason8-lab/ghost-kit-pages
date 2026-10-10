#!/usr/bin/env python3
"""Build tools/meshy/assets.json and the "Full prompts to paste" appendix of docs/MESHY_BRIEF.md from the
brief's tables, so the prompts live in one place.

Usage: python3 tools/meshy/build_assets.py
"""

import json
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
BRIEF = HERE.parent.parent / "docs" / "MESHY_BRIEF.md"
OUT = HERE / "assets.json"

KIT = ("Photorealistic kabaddi player wearing a fitted royal blue short-sleeve jersey shirt covering his chest and "
       "shoulders, red collar, red shoulder panels and red side stripes, fitted royal blue shorts with red side "
       "stripes, bare feet without shoes or socks, no logos, no text, no numbers.")
POSE = "Full body A-pose, arms 45 degrees out, open hands, feet flat, neutral face, mouth closed."
CROWD_END = ("Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, "
             "no logos, no text.")
TEXTURE = {
    "player": ("Photorealistic skin with pores and natural tone variation, realistic short hair, matte stretch sports "
               "fabric with fine stitching, flat solid royal blue and red kit, no logos, no text, no numbers, even "
               "studio lighting, no baked shadows, no ambient occlusion."),
    "referee": ("Photorealistic skin and hair, crisp white cotton polo shirt, matte black trousers, polished black "
                "shoes, no logos, no text, no badges, even studio lighting, no baked shadows."),
    "crowd": "Photorealistic skin, hair and everyday fabrics, even studio lighting, no baked shadows, no logos, no text.",
    "gear": "Realistic product materials, matte fabric and neoprene, even studio lighting, no baked shadows, no logos, no text.",
}
FACES = {"player": 6000, "referee": 6000, "gear": 2000, "crowd": 30000}
PICTURE = "Full-body studio photo, front view, plain light-grey background,"


def main():
    text = BRIEF.read_text()
    body = text.split("\n## Full prompts to paste")[0]
    assets = []
    section = ""
    for line in body.splitlines():
        if line.startswith("## "):
            section = line
        m = re.match(r"\| `([a-z0-9_]+)` \|(.*)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        name = m.group(1)
        if section.startswith("## Players"):
            kind, height, prompt = "player", cells[1], f"{KIT} He is {cells[-1]} {POSE}"
        elif section.startswith("## Pads"):
            kind, height, prompt = "gear", None, cells[-1]
        elif section.startswith("## Referees"):
            kind, height, prompt = "referee", cells[0], cells[-1]
        elif section.startswith("## Crowd"):
            kind, height, prompt = "crowd", cells[0], f"{cells[-1]} {CROWD_END}"
        else:
            continue
        a = {"name": name, "kind": kind, "prompt": prompt, "texture_prompt": TEXTURE[kind], "faces": FACES[kind]}
        if height:
            a["height_m"] = float(height.split()[0])
        if len(prompt) > 600:
            raise SystemExit(f"{name}: prompt is {len(prompt)} characters; Meshy takes 600")
        assets.append(a)
    OUT.write_text(json.dumps({"note": "Built from docs/MESHY_BRIEF.md by tools/meshy/build_assets.py.",
                               "assets": assets}, indent=1, ensure_ascii=False) + "\n")

    out = ["", "## Full prompts to paste", "",
           "Built from the tables above by `tools/meshy/build_assets.py`. For players and referees: the picture prompt",
           "(Text to Image), then the 3D prompt (Text to 3D, or the description on Image to 3D).", ""]
    heads = {"player": "### Players", "gear": "### Pads and wraps", "referee": "### Referees", "crowd": "### Crowd"}
    seen = set()
    for a in assets:
        if a["kind"] not in seen:
            out += [heads[a["kind"]], ""]
            seen.add(a["kind"])
        out += [f"**{a['name']}**" + (f" (rig height {a['height_m']:.2f} m)" if "height_m" in a else ""), ""]
        if a["kind"] in ("player", "referee"):
            pic = PICTURE + " " + a["prompt"].replace("Photorealistic ", "", 1)
            out += ["Picture:", "", "```text", pic, "```", "", "3D:", ""]
        out += ["```text", a["prompt"], "```", ""]
    BRIEF.write_text(body.rstrip("\n") + "\n" + "\n".join(out).rstrip("\n") + "\n")
    longest = max(assets, key=lambda a: len(a["prompt"]))
    print(f"{len(assets)} assets; longest prompt {len(longest['prompt'])} characters ({longest['name']})")


if __name__ == "__main__":
    main()
