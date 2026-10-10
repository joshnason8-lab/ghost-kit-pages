"""Make the textures for a textured player model, so every team can wear its own kit.

A generated model comes with one team's kit painted into its texture, logos and numbers
included. This script:

1. Paints out the logos, sponsor names and numbers on the kit (light or orange marks with
   kit colour around them, and red marks in the middle of them, such as a crest).
2. Marks which texels are the kit's main colour and which its trim (saturated blue and red
   by default; see --main-hue and --trim-hue), leaving out the head.
3. Pads the texture's islands so mipmaps don't bleed the black gaps between them.

It writes ALBEDO (the cleaned texture) and KIT (red: main colour, green: trim, blue: the kit's
shading as a multiplier, halved, in linear light) and adds a "texture" entry to the rigged
model's JSON with the files and the texture's skin colour. game/rigged_body.gd then paints
the kit in the team's colours, keeping its folds, and tints the skin to each player's tone.
Use .webp names: the albedo is saved lossy, the kit map lossless.

Usage:
  python kit_texture.py MODEL.glb RIGGED.json ALBEDO.webp KIT.webp [--res-path res://assets/characters/]
"""

import argparse
import io
import json
import struct

import cv2
import numpy as np
from PIL import Image


def base_color_image(path):
    """The base colour texture of the first material in a GLB."""
    b = open(path, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    data = b[28 + jlen:28 + jlen + blen]
    tex = j["textures"][j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    src = tex.get("source", tex.get("extensions", {}).get("EXT_texture_webp", {}).get("source"))
    bv = j["bufferViews"][j["images"][src]["bufferView"]]
    raw = data[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB"))


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def save(path, arr, lossless):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    if path.endswith(".webp"):
        im.save(path, lossless=lossless, quality=100 if lossless else 92, method=6)
    else:
        im.save(path, optimize=True)


def hue_near(h, centre, width):
    d = np.abs((h - centre + 180.0) % 360.0 - 180.0)
    return d < width


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("rigged")
    ap.add_argument("albedo_out")
    ap.add_argument("kit_out")
    ap.add_argument("--main-hue", type=float, default=230.0)
    ap.add_argument("--trim-hue", type=float, default=355.0)
    ap.add_argument("--res-path", default="res://assets/characters/")
    a = ap.parse_args()

    img = base_color_image(a.model)
    H, W = img.shape[:2]
    rig = json.load(open(a.rigged))
    uv = np.array(rig["uvs"], dtype=np.float64).reshape(-1, 2)
    tri = np.array(rig["indices"], dtype=np.int64).reshape(-1, 3)
    names = [b["name"] for b in rig["bones"]]
    top_bone = np.array(rig["bones4"], dtype=np.int64).reshape(-1, 4)[:, 0]
    # Never kit: the head and the hands (pink palms and fingertips read as red trim otherwise).
    head_v = np.isin(top_bone, [names.index(n) for n in ("head", "neck", "hand_l", "hand_r")])

    # Which texels the mesh uses, and which belong to the head.
    px = np.round(uv * np.array([W, H]) * 16).astype(np.int32)   # 4 bits of sub-pixel precision
    used = np.zeros((H, W), np.uint8)
    head = np.zeros((H, W), np.uint8)
    for t in tri:
        poly = px[t].reshape(-1, 1, 2)
        cv2.fillPoly(used, [poly], 1, lineType=cv2.LINE_8, shift=4)
        if head_v[t].any():
            cv2.fillPoly(head, [poly], 1, lineType=cv2.LINE_8, shift=4)
    used = cv2.dilate(used, np.ones((3, 3), np.uint8)).astype(bool)
    head = cv2.dilate(head, np.ones((5, 5), np.uint8)).astype(bool)

    def classes(rgb):
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
        h, s, v = hsv[..., 0] * 360.0 / 256.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
        main = used & ~head & hue_near(h, a.main_hue, 35) & (s > 0.35)
        trim = used & ~head & hue_near(h, a.trim_hue, 22) & (s > 0.5) & (v > 0.25)
        return h, s, v, main, trim

    h, s, v, main, trim = classes(img)
    skin_like = hue_near(h, 25, 20) & (s > 0.15) & (s < 0.6) & (v > 0.45)
    # Logos and numbers: light or orange marks with kit colour around them and little skin.
    kitness = cv2.blur((main | trim).astype(np.float32), (17, 17))
    skinness = cv2.blur((used & ~main & ~trim & skin_like).astype(np.float32), (17, 17))
    light = (s < 0.3) & (v > 0.5)
    orange = hue_near(h, 30, 18) & (s > 0.6)
    marks = used & ~head & (light | orange) & (kitness > 0.35) & (skinness < 0.25)
    marks = cv2.dilate(marks.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    # Whatever else is in and around a mark (a crest's red, outlines) goes with it.
    near = cv2.dilate(marks.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
    marks |= near & ~main & ~skin_like
    marks &= used & ~head
    print(f"painted out {marks.mean() * 100:.1f}% of the texture")
    # Specks: odd texels in the middle of the kit (anti-aliasing, dark seams) join it.
    other = used & ~head & ~main & ~trim & ~marks
    main_specks = other & (cv2.blur(main.astype(np.float32), (7, 7)) > 0.6)
    trim_specks = other & ~main_specks & (cv2.blur(trim.astype(np.float32), (7, 7)) > 0.6)

    ref = {
        "skin": (np.median(img[used & ~head & skin_like & ~main & ~trim], axis=0) / 255.0).round(4).tolist(),
        "main_v": round(float(np.median(v[main & ~marks])), 4),
        "trim_v": round(float(np.median(v[trim & ~marks])), 4) if (trim & ~marks).any() else 1.0,
    }
    # Shading: each kit texel's brightness against its colour's typical brightness; a mark
    # takes the shading around it.
    shade = np.ones((H, W), np.float32)
    shade[main] = to_linear(v[main]) / to_linear(ref["main_v"])
    shade[trim] = to_linear(v[trim]) / to_linear(ref["trim_v"])
    shade8 = np.clip(np.clip(shade, 0.3, 1.25) * 0.5 * 255.0, 0, 255).astype(np.uint8)
    # Under a mark, and just around it (outlines), the shading comes from further out.
    redo = cv2.dilate(marks.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool) & used & ~head
    redo |= main_specks | trim_specks
    shade8 = cv2.inpaint(shade8, redo.astype(np.uint8), 5, cv2.INPAINT_TELEA)
    main = (main | marks | main_specks)
    trim = (trim | trim_specks) & ~marks
    print("main", round(main.mean() * 100, 1), "% trim", round(trim.mean() * 100, 1), "%", ref)

    # Raised shapes (a number moulded into the shirt) have small walls whose texture is
    # something else: a piece of the body that is not kit, with kit on most sides, joins it.
    V = np.array(rig["vertices"], dtype=np.float64).reshape(-1, 3)
    _, weld = np.unique(np.round(V / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    edges = {}
    for fi, t in enumerate(weld[tri]):
        for e in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            edges.setdefault((min(e), max(e)), []).append(fi)
    nbrs = [[] for _ in range(len(tri))]
    for fs in edges.values():
        for f1 in fs:
            nbrs[f1].extend(f2 for f2 in fs if f2 != f1)
    cen = np.clip((uv[tri].mean(axis=1) * np.array([W, H])).astype(int), 0, [W - 1, H - 1])
    is_main = main[cen[:, 1], cen[:, 0]].copy()
    is_kit = is_main | trim[cen[:, 1], cen[:, 0]]
    not_head = ~head_v[tri].any(axis=1)
    walls = 0
    for _ in range(3):
        grow = [fi for fi in range(len(tri)) if not is_kit[fi] and not_head[fi] and len(nbrs[fi]) >= 2
                and sum(is_main[n] for n in nbrs[fi]) >= len(nbrs[fi]) - 1]
        for fi in grow:
            area = np.zeros((H, W), np.uint8)
            cv2.fillPoly(area, [px[tri[fi]].reshape(-1, 1, 2)], 1, lineType=cv2.LINE_8, shift=4)
            area = area.astype(bool)
            main |= area
            trim &= ~area
            shade8[area] = 110   # a little darker than flat kit: a wall in shadow
            is_main[fi] = is_kit[fi] = True
        walls += len(grow)
        if not grow:
            break
    print("kit pieces joined to the kit around them:", walls)

    clean = cv2.inpaint(img, marks.astype(np.uint8), 5, cv2.INPAINT_TELEA)   # under the kit colour
    kit = np.zeros((H, W, 3), np.float32)
    kit[..., 0] = main
    kit[..., 1] = trim
    kit[..., 2] = shade8 / 255.0

    # Pad the islands outwards so filtering never reaches the black gaps.
    def pad(im, mask, steps=12):
        im = im.astype(np.float32).copy()
        m = mask.astype(np.float32)
        for _ in range(steps):
            num = cv2.blur(im * m[..., None], (3, 3))
            den = cv2.blur(m, (3, 3))
            grow = (m == 0) & (den > 0)
            im[grow] = num[grow] / den[grow][:, None]
            m[grow] = 1.0
        return im

    clean = pad(clean, used)
    kit = pad(kit, used)
    save(a.albedo_out, clean, lossless=False)
    save(a.kit_out, kit * 255.0, lossless=True)

    rig["texture"] = {
        "albedo": a.res_path + a.albedo_out.split("/")[-1],
        "kit": a.res_path + a.kit_out.split("/")[-1],
        "skin_ref": ref["skin"],
    }
    json.dump(rig, open(a.rigged, "w"), separators=(",", ":"))
    print("wrote", a.albedo_out, a.kit_out, "and the texture entry in", a.rigged)


if __name__ == "__main__":
    main()
