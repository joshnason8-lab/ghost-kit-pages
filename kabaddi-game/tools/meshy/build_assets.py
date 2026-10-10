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

KIT = ("Photorealistic kabaddi player wearing a fitted royal blue short-sleeve jersey covering his torso, red "
       "collar, shoulder panels and side stripes, fitted royal blue shorts with red side stripes, black kabaddi "
       "shoes, no logos, no text, no numbers.")
# Hands: palms down in the A-pose (the rigging standard) hang palms-to-thighs when the arms drop; the first test's
# palms faced up and its fingers were fused.
# The A-pose was not held: two of the first three players came back with bent or raised arms. A T-pose
# (Meshy's pose_mode "t-pose") is the other rigging standard; with palms down, lowered arms hang palms-in.
HANDS = "palms down, realistic hands with five separate fingers slightly spread"
POSE = f"Full body T-pose, arms out sideways, {HANDS}, feet flat, neutral face, mouth closed."
CROWD_END = f"Full body, T-pose, arms out sideways, {HANDS}, feet flat, neutral face, mouth closed, no logos, no text."
TEXTURE = {
    "player": ("Photorealistic skin with pores and natural tone variation, realistic short hair, matte stretch sports "
               "fabric with fine stitching, flat solid royal blue and red kit, no logos, no text, no numbers, even "
               "studio lighting, no baked shadows, no ambient occlusion."),
    "referee": ("Photorealistic skin and hair, crisp white cotton polo shirt, matte black trousers, polished black "
                "shoes, no logos, no text, no badges, even studio lighting, no baked shadows."),
    "crowd": "Photorealistic skin, hair and everyday fabrics, even studio lighting, no baked shadows, no logos, no text.",
    "gear": "Realistic product materials, matte fabric and neoprene, even studio lighting, no baked shadows, no logos, no text.",
}
# The texture step paints by its own prompt, not the shape: a generic one gave a sleeveless vest on a t-shirt.
# So each texture prompt spells out the outfit and the person.
KIT_TEXTURE = ("Royal blue short-sleeve jersey covering the whole torso and upper arms, red collar, cuffs, shoulder "
               "panels and side stripes; royal blue shorts to above the knee with red side stripes; bare lower legs; "
               "plain black kabaddi shoes; no logos, no text, no numbers.")
QUALITY = ("Photorealistic skin, face and hands with natural smooth palms and fingernails, matte fabric, even "
           "lighting, no baked shadows.")
# About 16,000 triangles for players and referees: enough for separate fingers. The game shows a lighter
# version of players far from the camera.
FACES = {"player": 8000, "referee": 8000, "gear": 2000, "crowd": 30000}
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
            kind, height, prompt = "referee", cells[0], cells[-1].replace("open hands", HANDS)
        elif section.startswith("## Crowd"):
            kind, height, prompt = "crowd", cells[0], f"{cells[-1]} {CROWD_END}"
        else:
            continue
        if kind == "player":
            texture = f"{KIT_TEXTURE} Player: {cells[-1]} {QUALITY}"
        elif kind in ("referee", "crowd"):
            texture = f"{prompt.split(' Full body')[0].rstrip(', .')}. {QUALITY}"
        else:
            texture = TEXTURE[kind]
        if kind in ("player", "referee", "crowd"):
            prompt = prompt.replace("Full body A-pose, palms down", "Full body T-pose, arms out sideways, palms down")
        a = {"name": name, "kind": kind, "prompt": prompt, "texture_prompt": texture, "faces": FACES[kind]}
        if kind != "gear":
            a["pose"] = "t-pose"
        if height:
            a["height_m"] = float(height.split()[0])
        for label, t in (("prompt", prompt), ("texture prompt", texture)):
            if len(t) > 600:
                raise SystemExit(f"{name}: {label} is {len(t)} characters; Meshy takes 600")
        assets.append(a)
    first = re.search(r"## First batch.*?(?=\n## )", body, re.S)
    names_first = set(re.findall(r"`([a-z0-9_]+)`", first.group(0))) if first else set()
    for a in assets:
        if a["name"] in names_first:
            a["batch"] = 1
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
