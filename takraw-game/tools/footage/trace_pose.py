"""MediaPipe pose over a folder of frames: the 33 landmarks per frame (image and world), and a contact sheet.

usage: trace_pose.py MODEL "FRAMES_GLOB" OUT.json SHEET.jpg [fps]
"""
import glob
import json
import sys

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

model, pattern, out_json, sheet = sys.argv[1:5]
fps = float(sys.argv[5]) if len(sys.argv) > 5 else 30.0
files = sorted(glob.glob(pattern))
opts = vision.PoseLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path=model),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=1,
    min_pose_detection_confidence=0.3,
    min_pose_presence_confidence=0.3,
    min_tracking_confidence=0.3,
)
EDGES = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
         (23, 25), (25, 27), (27, 31), (24, 26), (26, 28), (28, 32), (0, 11), (0, 12)]
frames = []
thumbs = []
with vision.PoseLandmarker.create_from_options(opts) as lm:
    for i, f in enumerate(files):
        img = cv2.imread(f)
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        res = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(i * 1000 / fps))
        rec = {"file": f.split("/")[-1], "img": None, "world": None}
        if res.pose_landmarks:
            rec["img"] = [[p.x, p.y, p.z, p.visibility] for p in res.pose_landmarks[0]]
            rec["world"] = [[p.x, p.y, p.z] for p in res.pose_world_landmarks[0]]
        frames.append(rec)
        if i % 3 == 0:
            t = img.copy()
            h, w = t.shape[:2]
            if rec["img"]:
                pts = [(int(p[0] * w), int(p[1] * h)) for p in rec["img"]]
                for a, b in EDGES:
                    cv2.line(t, pts[a], pts[b], (0, 255, 0) if a % 2 else (0, 128, 255), 2)
                for j in (15, 16, 19, 20):
                    cv2.circle(t, pts[j], 4, (255, 0, 255), -1)
            cv2.putText(t, "%d" % i, (6, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            thumbs.append(cv2.resize(t, (w // 2, h // 2)))
json.dump({"fps": fps, "frames": frames}, open(out_json, "w"))
cols = 8
rows = []
for r in range(0, len(thumbs), cols):
    row = thumbs[r:r + cols]
    while len(row) < cols:
        row.append(row[0] * 0)
    rows.append(cv2.hconcat(row))
if rows:
    cv2.imwrite(sheet, cv2.vconcat(rows), [cv2.IMWRITE_JPEG_QUALITY, 85])
print("frames", len(frames), "found", sum(1 for f in frames if f["img"]))
