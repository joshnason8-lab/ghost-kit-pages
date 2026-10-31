#!/usr/bin/env python3
"""The auction's player figures: outlines of real kabaddi players, traced from footage (0.13.1).

Each figure is a real person cut out of a frame of the owner's two kabaddi videos (a raider drilling his bonus and back
kick; a Pro Kabaddi skills explainer) with YOLO11's person segmentation, cleaned (its largest piece, holes filled,
edges smoothed) and drawn as an outline: a white line round the figure over a faint fill, so the game can tint it in a
team's colours. Only the outline is kept, nothing of the person's look: no face, no kit, no picture.

Writes assets/ui/auction/fig_NN.png (transparent, 360 px tall) and assets/ui/auction/figures.json: each figure's file,
its kind ("raid": reaching, lunging, kicking; "defend": crouched ready) and where it came from.

    python3 tools/ui_art/make_silhouettes.py VIDEO_1 VIDEO_2
Needs: python3 with ultralytics (yolo11m-seg.pt is downloaded on first use), opencv, numpy.
"""
import json
import os
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "ui", "auction"))
HEIGHT = 360
LINE = 5          # px, the outline at HEIGHT
PAD = 12

# [video (1 or 2), frame, kind, the person's box in the frame (x1, y1, x2, y2), or none for the largest person]
FIGURES = [
    [2, 217, "defend", [434, 214, 805, 842]],
    [2, 237, "defend", [440, 223, 792, 833]],
    [2, 246, "defend", [1035, 187, 1506, 938]],
    [2, 256, "defend", [441, 222, 766, 814]],
    [2, 5, "defend", [86, 144, 679, 953]],
    [1, 1904, "defend", None],
    [1, 826, "defend", None],
    [1, 866, "defend", None],
    [1, 3040, "defend", None],
    [2, 337, "raid", [793, 245, 1516, 840]],
    [2, 361, "raid", [978, 306, 1627, 854]],
    [2, 382, "raid", [1159, 256, 1897, 872]],
    [2, 751, "raid", [496, 270, 884, 1011]],
    [2, 792, "raid", [500, 175, 884, 994]],
    [2, 906, "raid", [666, 286, 1137, 968]],
    [2, 149, "raid", [1600, 249, 1910, 875]],
    [2, 423, "raid", [554, 215, 891, 1027]],
    [1, 1072, "raid", None],
    [1, 1605, "raid", None],
    [1, 3144, "raid", None],
    [1, 3163, "raid", None],
    [1, 343, "raid", None],
]


def person_mask(model, img, box):
    r = model(img, imgsz=1280, classes=[0], verbose=False, retina_masks=True)[0]
    if r.masks is None:
        return None
    masks = r.masks.data.cpu().numpy() > 0.5
    if box is None:
        return masks[int(np.argmax(masks.reshape(len(masks), -1).sum(1)))]
    bx = r.boxes.xyxy.cpu().numpy()

    def iou(a, b):
        x1, y1, x2, y2 = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
        i = max(0, x2 - x1) * max(0, y2 - y1)
        return i / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - i)
    return masks[int(np.argmax([iou(box, b) for b in bx]))]


def clean(mask):
    m = mask.astype(np.uint8) * 255
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
    if n > 1:
        m = np.where(lab == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA])), 255, 0).astype(np.uint8)
    # Holes filled (between an arm and the body stays open: only holes with no way out).
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    m = np.zeros_like(m)
    cv2.drawContours(m, cnts, -1, 255, -1)
    k = max(3, int(round(m.shape[0] / 180)) | 1)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    m = cv2.GaussianBlur(m, (0, 0), k * 0.6)
    return (m > 127).astype(np.uint8) * 255


def outline(m):
    ys, xs = np.where(m > 0)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    s = (HEIGHT - 2 * PAD) / m.shape[0]
    w = max(1, int(round(m.shape[1] * s)))
    big = cv2.resize(m, (w * 4, (HEIGHT - 2 * PAD) * 4), interpolation=cv2.INTER_LINEAR)
    big = cv2.copyMakeBorder((big > 127).astype(np.uint8) * 255, PAD * 4, PAD * 4, PAD * 4, PAD * 4,
                             cv2.BORDER_CONSTANT, value=0)
    cnts, _ = cv2.findContours(big, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    line = np.zeros_like(big)
    cv2.drawContours(line, cnts, -1, 255, LINE * 4, lineType=cv2.LINE_AA)
    fill = big
    small = lambda a: cv2.resize(a, (big.shape[1] // 4, big.shape[0] // 4), interpolation=cv2.INTER_AREA)
    line, fill = small(line).astype(np.float32) / 255, small(fill).astype(np.float32) / 255
    alpha = np.clip(np.maximum(line, fill * 0.16), 0, 1)
    rgba = np.zeros(line.shape + (4,), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    return rgba


def main():
    from ultralytics import YOLO
    videos = {1: sys.argv[1], 2: sys.argv[2]}
    model = YOLO("yolo11m-seg.pt")
    os.makedirs(OUT, exist_ok=True)
    caps = {k: cv2.VideoCapture(v) for k, v in videos.items()}
    out = []
    for i, (v, frame, kind, box) in enumerate(FIGURES):
        cap = caps[v]
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame)
        ok, img = cap.read()
        mask = person_mask(model, img, box) if ok else None
        if mask is None:
            print("no person in video %d frame %d" % (v, frame))
            continue
        name = "fig_%02d.png" % len(out)
        cv2.imwrite(os.path.join(OUT, name), cv2.cvtColor(outline(clean(mask)), cv2.COLOR_RGBA2BGRA))
        out.append({"file": name, "kind": kind, "source": "video %d, frame %d" % (v, frame)})
        print(name, kind, v, frame)
    json.dump({"figures": out}, open(os.path.join(OUT, "figures.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
