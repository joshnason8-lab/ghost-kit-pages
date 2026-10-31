import sys, json
from ultralytics import YOLO
model = YOLO(sys.argv[1])
out = {}
for view in ["front", "side", "left"]:
    r = model(f"{sys.argv[2]}/ortho_{view}.png", verbose=False)[0]
    if r.keypoints is None or len(r.keypoints) == 0:
        out[view] = None; continue
    i = int(r.boxes.conf.argmax())
    out[view] = {"xy": r.keypoints.xy[i].tolist(), "conf": r.keypoints.conf[i].tolist()}
json.dump(out, open(f"{sys.argv[2]}/joints2d.json", "w"), indent=1)
names = ["nose","l_eye","r_eye","l_ear","r_ear","l_sh","r_sh","l_el","r_el","l_wr","r_wr","l_hip","r_hip","l_kn","r_kn","l_an","r_an"]
for v, d in out.items():
    print(v, None if d is None else " ".join("%s(%d,%d %.2f)" % (n, x, y, c) for n, (x, y), c in zip(names, d["xy"], d["conf"])))
