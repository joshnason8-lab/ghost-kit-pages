#!/usr/bin/env python3
"""Step 1: video -> tracked 2D skeletons.

Runs a YOLO11 pose model with ByteTrack so every player keeps the same ID across
frames, then writes:
  <out>/poses.json      per frame: [{id, box, kp: [[x, y, conf] x17]}]
  <out>/overlay.mp4     the video with stick figures and player IDs drawn on
  <out>/frame0.jpg      first frame, for picking the four court corners (step 2)

Keypoints follow the COCO-17 order (see SKELETON below).

Usage:
  python extract_pose.py match.mp4 --out runs/match1 [--model yolo11m-pose.pt] [--imgsz 1280] [--start 12.5 --end 40]
"""
import argparse
import json
import pathlib

import cv2
from ultralytics import YOLO

KP_NAMES = ["nose", "l_eye", "r_eye", "l_ear", "r_ear", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow",
            "l_wrist", "r_wrist", "l_hip", "r_hip", "l_knee", "r_knee", "l_ankle", "r_ankle"]
SKELETON = [(5, 7), (7, 9), (6, 8), (8, 10), (5, 6), (5, 11), (6, 12), (11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (0, 5), (0, 6)]
PALETTE = [(31, 154, 255), (109, 51, 232), (138, 211, 76), (255, 196, 0), (255, 99, 71), (180, 105, 255), (0, 215, 255), (230, 230, 230)]


def draw(frame, people):
    for p in people:
        col = PALETTE[p["id"] % len(PALETTE)] if p["id"] >= 0 else (200, 200, 200)
        kp = p["kp"]
        for a, b in SKELETON:
            if kp[a][2] > 0.3 and kp[b][2] > 0.3:
                cv2.line(frame, (int(kp[a][0]), int(kp[a][1])), (int(kp[b][0]), int(kp[b][1])), col, 3, cv2.LINE_AA)
        for x, y, c in kp:
            if c > 0.3:
                cv2.circle(frame, (int(x), int(y)), 4, (255, 255, 255), -1, cv2.LINE_AA)
        x1, y1 = int(p["box"][0]), int(p["box"][1])
        cv2.putText(frame, f"#{p['id']}", (x1, max(18, y1 - 6)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, col, 2, cv2.LINE_AA)
    return frame


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", default="yolo11m-pose.pt")
    ap.add_argument("--start", type=float, default=0.0, help="seconds")
    ap.add_argument("--end", type=float, default=-1.0, help="seconds, -1 for the whole video")
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--imgsz", type=int, default=1280,
                    help="detection resolution; whole-court shots need 1280+ or distant players are missed")
    args = ap.parse_args()

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(args.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    cap.set(cv2.CAP_PROP_POS_MSEC, args.start * 1000.0)
    writer = cv2.VideoWriter(str(out / "overlay_raw.mp4"), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    model = YOLO(args.model)

    frames = []
    idx = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        # Real timestamps: phone and screen recordings often have a variable frame rate.
        pos = cap.get(cv2.CAP_PROP_POS_MSEC)
        t = pos / 1000.0 if pos > 0 or idx == 0 else args.start + idx / fps
        if args.end >= 0 and t > args.end:
            break
        if idx == 0:
            cv2.imwrite(str(out / "frame0.jpg"), frame)
        res = model.track(frame, persist=True, tracker="bytetrack.yaml", conf=args.conf, imgsz=args.imgsz, verbose=False)[0]
        people = []
        if res.keypoints is not None and res.boxes is not None and len(res.boxes) > 0:
            ids = res.boxes.id.int().tolist() if res.boxes.id is not None else [-1] * len(res.boxes)
            for i, box in enumerate(res.boxes.xyxy.tolist()):
                kxy = res.keypoints.xy[i].tolist()
                kc = res.keypoints.conf[i].tolist() if res.keypoints.conf is not None else [1.0] * 17
                people.append({"id": ids[i], "box": [round(v, 1) for v in box],
                               "kp": [[round(x, 1), round(y, 1), round(c, 3)] for (x, y), c in zip(kxy, kc)]})
        frames.append({"t": round(t, 3), "people": people})
        writer.write(draw(frame, people))
        idx += 1
    writer.release()
    cap.release()

    meta = {"video": str(args.video), "fps": fps, "width": w, "height": h, "keypoints": KP_NAMES, "frames": frames}
    (out / "poses.json").write_text(json.dumps(meta))
    # Re-encode to H.264 so the overlay plays on phones and in browsers.
    import subprocess
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(out / "overlay_raw.mp4"), "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-crf", "23", str(out / "overlay.mp4")], check=False)
    ids = {p["id"] for f in frames for p in f["people"] if p["id"] >= 0}
    print(f"{idx} frames at {fps:.1f} fps, {len(ids)} tracked people -> {out}")


if __name__ == "__main__":
    main()
