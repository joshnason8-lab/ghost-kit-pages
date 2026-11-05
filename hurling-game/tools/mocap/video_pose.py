#!/usr/bin/env python3
"""A video of a hurler -> MediaPipe's pose landmarks, frame by frame (for tools/mocap/video_clip.py).

  pip install mediapipe   (and libegl1 on Linux)
  curl -o pose_heavy.task https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task
  python3 tools/mocap/video_pose.py <video.mp4> <landmarks.json> <pose_heavy.task>

Each frame: "w", the 33 landmarks in metres about the middle of the hips (x right, y down, z away from the camera,
with each one's visibility), and "n", the same on the picture (0-1), or null where no one was found.
"""
import json
import sys

import cv2
import mediapipe as mp
from mediapipe.tasks.python import BaseOptions, vision


def main():
    src, out, model = sys.argv[1], sys.argv[2], sys.argv[3]
    opts = vision.PoseLandmarkerOptions(base_options=BaseOptions(model_asset_path=model),
                                        running_mode=vision.RunningMode.VIDEO, num_poses=1,
                                        min_pose_detection_confidence=0.4, min_tracking_confidence=0.4)
    lm = vision.PoseLandmarker.create_from_options(opts)
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30
    frames = []
    i = 0
    while True:
        ok, img = cap.read()
        if not ok:
            break
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        r = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(i * 1000 / fps))
        if r.pose_world_landmarks:
            frames.append({"i": i, "w": [[p.x, p.y, p.z, p.visibility] for p in r.pose_world_landmarks[0]],
                           "n": [[p.x, p.y] for p in r.pose_landmarks[0]]})
        else:
            frames.append({"i": i, "w": None, "n": None})
        i += 1
    json.dump({"fps": fps, "frames": frames}, open(out, "w"))
    print(src, i, "frames,", sum(1 for f in frames if f["w"]), "with a pose")


if __name__ == "__main__":
    main()
