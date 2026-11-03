#!/usr/bin/env python3
"""Our crowd's sprite sheets (tools/crowd/render_crowd.gd) repacked as the shared foundation's crowd cards
(WsgCrowdCards.use_art, ADOPTING 5.1): a cell a pose, fan by fan - sitting, standing, cheering (arms up) - from the
front and from behind, with a mask (R: the shirt the game recolours; G, B, A empty: skin, hair and legs keep the
people's own), and the layout (cards.json: cols, rows, size of a cell in m, poses, each fan's seat height in the cell).

    python3 tools/crowd/pack_cards.py [crowd dir] [seats json]

Writes assets/crowd/cards{,_back,_mask,_back_mask}.webp/.png and cards.json (Low: the eight people) and the same with
_hi (Medium and High: the sixteen, the eight again in other clothes). seats json: a crowd_atlas.json written by
render_crowd.gd since it records each person's "seat" (default: the crowd dir's own).

The cells are moved down the 2 cm the renders leave under the feet (the card's foot is the floor). The cards seat
each fan on a seat by the fan whose legs fit it best: so that the adults are all picked (not one of them every time),
each adult's sitting cell is scaled about the feet to a common seat height (SEAT) - the size the cards would have
drawn them at on a seat anyway - and the children keep theirs (too short for a stand's seat: they stand).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CROWD = os.path.join(HERE, "..", "..", "assets", "crowd")
FRAMES_USED = {"sit": 0, "stand": 3, "cheer": 6}   # rows of render_crowd's FRAMES
POSES = ["sit", "stand", "cheer"]
SEAT = 0.42          # m: every adult's seat in the cell (a stand's seat is 0.44-0.45 m)
UNDER_FEET = 0.02    # m under the feet in render_crowd's cells


def cells(img, cw, ch, col, row):
    return img.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))


def place(cell, scale, down_px):
    """The cell scaled about its bottom middle and moved down down_px."""
    w, h = cell.size
    if abs(scale - 1.0) > 1e-3:
        sw, sh = round(w * scale), round(h * scale)
        big = cell.resize((sw, sh), Image.LANCZOS)
        out = Image.new(cell.mode, (w, h), 0)
        out.paste(big, ((w - sw) // 2, h - sh))
        cell = out
    out = Image.new(cell.mode, (w, h), 0)
    out.paste(cell.crop((0, 0, w, h - down_px)), (0, down_px))
    return out


def pack(dirn, info, seats, people, sources, suffix):
    cw, ch = info["cell"]
    cell_h = float(info["cell_height_m"])
    cell_w = cell_h * cw / ch
    n = len(people) * len(POSES)
    cols = 6 if n <= 24 else 8
    rows = (n + cols - 1) // cols
    down = round(UNDER_FEET / cell_h * ch)
    sheets = {k: Image.new("RGBA" if not k.endswith("mask") else "L", (cols * cw, rows * ch), 0) for k in
              ("front", "back", "mask", "back_mask")}
    fans = {}
    for fi, p in enumerate(people):
        src, col = sources[fi]
        own_seat = float(seats.get(p["file"], seats.get(p.get("base_file", ""), 0.0)))
        adult = own_seat > 0.3
        scale = SEAT / own_seat if adult else 1.0
        recolour = float(p.get("top_luminance", 0.0)) > 0.0
        for pi, pose in enumerate(POSES):
            k = fi * len(POSES) + pi
            at = ((k % cols) * cw, (k // cols) * ch)
            s = scale if pose == "sit" else 1.0
            r = FRAMES_USED[pose]
            sheets["front"].paste(place(cells(src["front"], cw, ch, col, r), s, down), at)
            sheets["back"].paste(place(cells(src["back"], cw, ch, col, r), s, down), at)
            if recolour:
                sheets["mask"].paste(place(cells(src["mask"], cw, ch, col, r), s, down), at)
                sheets["back_mask"].paste(place(cells(src["back_mask"], cw, ch, col, r), s, down), at)
        name = os.path.splitext(os.path.basename(p["file"]))[0].replace("_rigged", "")
        fans[name] = {"seat": round(SEAT if adult else own_seat, 3)}
    sheets["front"].save(os.path.join(dirn, "cards%s.webp" % suffix), quality=92, method=6)
    sheets["back"].save(os.path.join(dirn, "cards%s_back.webp" % suffix), quality=92, method=6)
    for k, name in (("mask", "cards%s_mask.png"), ("back_mask", "cards%s_back_mask.png")):
        # R the shirt; G, B (skin, hair) and A (legs) empty: kept as drawn.
        m = np.array(sheets[k])
        rgba = np.zeros(m.shape + (4,), np.uint8)
        rgba[..., 0] = m
        Image.fromarray(rgba, "RGBA").save(os.path.join(dirn, name % suffix), optimize=True)
    layout = {"cols": cols, "rows": rows, "size": [round(cell_w, 4), cell_h], "poses": POSES, "fans": fans}
    with open(os.path.join(dirn, "cards%s.json" % suffix), "w") as f:
        json.dump(layout, f, indent=1)
    return layout


def main():
    dirn = sys.argv[1] if len(sys.argv) > 1 else CROWD
    seats_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(dirn, "crowd_atlas.json")
    seats = {p["file"]: p["seat"] for p in json.load(open(seats_path))["people"]}
    info = json.load(open(os.path.join(dirn, "crowd_atlas.json")))
    hi = json.load(open(os.path.join(dirn, "crowd_atlas_hi.json")))
    load = lambda f, mode: Image.open(os.path.join(dirn, f)).convert(mode)
    base = {"front": load("crowd_atlas.webp", "RGBA"), "back": load("crowd_atlas_back.webp", "RGBA"),
            "mask": load("crowd_mask.png", "L"), "back_mask": load("crowd_mask_back.png", "L")}
    second = {"front": load("crowd_atlas_hi.webp", "RGBA"), "back": load("crowd_atlas_hi_back.webp", "RGBA"),
              "mask": Image.new("L", base["mask"].size, 0), "back_mask": Image.new("L", base["mask"].size, 0)}
    low = info["people"]
    print("Low:", pack(dirn, info, seats, low, [(base, i) for i in range(len(low))], ""))
    # The sixteen: the eight, then the eight again in other clothes (variants.py: "base" the person they are).
    people = hi["people"]
    first = int(hi.get("columns", 8))
    for p in people[first:]:
        p["base_file"] = low[int(p["base"])]["file"]
    srcs = [(base, i) if i < first else (second, i - first) for i in range(len(people))]
    print("Medium/High:", pack(dirn, info, seats, people, srcs, "_hi"))


if __name__ == "__main__":
    main()
