#!/usr/bin/env python3
"""Build the game's clip set (assets/mocap/) from Mixamo animations converted by fbx_to_clip.gd.

Each row below takes one converted animation, keeps the part a move needs (the windows were found with
clip_events.py: a kick centred on the leg's full stretch, a dubki on the lowest point, a fall from the hit
to lying still, a get-up from the first push to standing), and saves it under the name the game looks
for: the prefix says which move it serves (game/mocap_clip.gd, FOR_STATE), so a move with several clips
gets a different one per player. "mirror" makes the left-right flip of a clip (a sidestep to the right
from one to the left).

First convert every download (file names lower-cased, spaces to underscores):
  for f in Movements/*.fbx; do n=$(basename "$f" .fbx | tr 'A-Z ' 'a-z_'); \
    godot --headless --path . res://tools/mocap/fbx_to_clip.tscn -- "$f" raw/$n.json $n; done
then:
  python3 tools/mocap/mixamo_set.py raw/ assets/mocap/
"""

import json
import os
import sys

LOOP, ONCE = True, False
# game clip, converted source, from (s), to (s), loops, mirrored
SET = [
    # Running set: whenever a player travels (move_*).
    ("move_jog", "jog_forward", None, None, LOOP, False),
    ("move_run", "fast_run", None, None, LOOP, False),
    ("move_strafe_left", "left_strafe", None, None, LOOP, False),
    ("move_strafe_right", "right_strafe", None, None, LOOP, False),
    ("move_back_jog", "jog_backward", None, None, LOOP, False),
    ("move_back_run", "running_backward", None, None, LOOP, False),
    ("move_shuffle_left", "goalkeeper_sidestep", None, None, LOOP, False),
    ("move_shuffle_right", "goalkeeper_sidestep", None, None, LOOP, True),
    # Stances.
    ("ready_goalkeeper", "goalkeeper_idle", None, None, LOOP, False),
    ("idle_breathing", "breathing_idle", None, None, LOOP, False),
    ("idle_plain", "idle", None, None, LOOP, False),
    # Raider's moves, fitted to the move's length in the game.
    ("kick_pontera", "pontera", 0.37, 0.97, ONCE, False),
    ("kick_bencao", "bencao", 0.33, 0.93, ONCE, False),
    ("kick_low", "low_kick", 0.53, 1.13, ONCE, False),
    ("backkick_chapa", "chapa_2", 0.37, 0.97, ONCE, False),
    ("dodge_right", "dodging_right", 0.28, 0.78, ONCE, False),
    ("dodge_left", "dodging_right", 0.28, 0.78, ONCE, True),
    ("evade_hop", "dodging_back", 0.40, 1.00, ONCE, False),
    ("dubki_esquiva", "esquiva_3", 0.62, 1.32, ONCE, False),
    ("dubki_low", "esquiva_4", 0.98, 1.68, ONCE, False),
    ("jump_running", "running_jump", 0.0, 0.75, ONCE, False),
    # Defender's dive (by tackle: an ankle dive stays low and hand-made); the raider dragging defenders.
    ("dive_thigh_flying", "run_to_dive", 0.40, 0.62, ONCE, False),   # launch to full reach (a pool dive after)
    ("held_pull", "pull_heavy_object", None, None, LOOP, False),
    # Brought down, and up again.
    ("fall_legs", "hit_to_the_legs", 0.45, 2.40, ONCE, False),
    ("fall_trip", "tripping", 0.80, 2.20, ONCE, False),
    ("fall_flat", "fall_flat", 0.45, 2.00, ONCE, False),
    ("fall_takedown", "double_leg_takedown_victim", 1.00, 3.40, ONCE, False),
    ("fall_shoulder", "shoulder_hit_and_fall", 0.80, 2.60, ONCE, False),
    ("getup_back", "getting_up", 0.30, 1.75, ONCE, False),
    ("getup_front", "standing_up", 0.20, 1.62, ONCE, False),
    # Celebrations by kind (0 arms up, 1 fist pump, 2 clap) and dejection.
    ("cele_0_cheer", "cheering", None, None, LOOP, False),
    ("cele_1_fist", "victory_idle", None, None, LOOP, False),
    ("cele_2_clap", "clapping", None, None, LOOP, False),
    ("slump_defeat", "defeat", None, None, ONCE, False),
    ("slump_head", "defeat_2", None, None, ONCE, False),
]
SWAP = {"sh_l": "sh_r", "sh_r": "sh_l", "el_l": "el_r", "el_r": "el_l", "hip_l": "hip_r", "hip_r": "hip_l",
        "kn_l": "kn_r", "kn_r": "kn_l"}


def cut(clip, t0, t1, loop):
    frames = clip["frames"]
    length = clip["length"]
    if t0 is not None:
        frames = [f for f in frames if t0 - 1e-4 <= f["t"] <= t1 + 1e-4]
        start = frames[0]["t"]
        frames = [dict(f, t=round(f["t"] - start, 4)) for f in frames]
        length = frames[-1]["t"]
    elif loop and len(frames) > 2 and frames[-1]["t"] >= length - 1e-3:
        frames = frames[:-1]   # the last frame repeats the first
    return frames, length


def mirror(clip, frames):
    joints = clip["joints"]
    out = []
    for f in frames:
        q = [f["q"][i * 4:i * 4 + 4] for i in range(len(joints))]
        by = dict(zip(joints, q))
        nq = []
        for j in joints:
            x, y, z, w = by[SWAP.get(j, j)]
            nq += [x, -y, -z, w]   # reflected across the body's middle (x -> -x)
        out.append(dict(f, q=nq))
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    for name, source, t0, t1, loop, flip in SET:
        path = os.path.join(src, source + ".json")
        if not os.path.exists(path):
            print("missing", path)
            continue
        clip = json.load(open(path))
        frames, length = cut(clip, t0, t1, loop)
        if flip:
            frames = mirror(clip, frames)
        out = dict(clip, name=name, frames=frames, length=length, loop=loop, source=clip.get("source", source))
        if flip:
            out["dir"] = [-clip["dir"][0], clip["dir"][1]]
        if t0 is not None and clip["speed"] > 0:
            out["speed"] = 0.0   # a cut move is placed by the game, not run
        with open(os.path.join(dst, name + ".json"), "w") as f:
            json.dump(out, f, separators=(",", ":"))
        print(f"{name:20s} {source:28s} {length:5.2f}s {len(frames):4d} frames  speed {out['speed']:.2f} {out['dir']}")


if __name__ == "__main__":
    main()
