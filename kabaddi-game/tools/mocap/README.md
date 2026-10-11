# Real movement from kabaddi video

Turns match footage into stick figures, court positions, movement stats for the AI, and
animation clips the game plays. All of it runs on a normal computer, no GPU needed.

```
video ─► extract_pose.py ─► poses.json + overlay.mp4 (stick figures with player IDs)
                │
                ├─► court_map.py ─► tracks.json + topdown.mp4 (positions in metres)
                │        └─► analyze.py ─► motion_stats.json (numbers for the game AI)
                │
                └─► to_clip.py ─► assets/mocap/<move>.json (animation the game plays)
```

## Setup

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install ultralytics opencv-python-headless lap numpy
# ffmpeg must be installed for the .mp4 outputs
```

The first run downloads the pose model (`yolo11m-pose.pt`, 42 MB).

## 1. Stick figures

```sh
python extract_pose.py match.mp4 --out runs/match1 --start 30 --end 90
```

Open `runs/match1/overlay.mp4` to check the skeletons. Every player gets a number that
stays with them. Write down the numbers of the players you care about.

`--imgsz 1280` is the default. For a whole court filmed from far away, try `--imgsz 1920`.
At the model's standard 640 px, distant players are missed entirely.

## 2. Court positions

Open `runs/match1/frame0.jpg` and read the pixel position of the four corners of the playing
field (the end lines and side lines, not the lobbies). Go round in this order:
**far-left, far-right, near-right, near-left.**

```sh
python court_map.py runs/match1 --corners "412,233 1508,240 1830,690 95,682"
```

`topdown.mp4` replays everyone as dots on a court diagram. The camera must stay still for
the whole clip: a tripod, or a broadcast segment with no camera moves.

### Moving camera (broadcast footage)

When the camera pans or zooms, run two more steps before `court_map.py`:

```sh
# Follow the camera. Mask on-screen graphics (scorebug, logo, watermark) as x0,y0,x1,y1.
python camera_track.py clip.mov runs/clip --ref 0 --mask "110,655,300,785 640,590,900,630" --crop "50,28,1446,815"
# Lock the court to every frame using the visible lines. Give 4+ known points from frame 0:
python court_lock.py clip.mov runs/clip --points "699,306=-5,0 711,597=5,0 1077,308=-5,3.75 1202,597=5,3.75" \
    --crop "50,28,1446,815" --mask "110,655,300,785 640,590,900,630"
python court_map.py runs/clip --video clip.mov     # --video splits teams by jersey colour
```

`--points` lets you use whichever lines are in shot (midline and baulk-line ends, for
example) when the field corners aren't visible. Court x runs across (far side −5, near side
+5) and z runs along (midline 0).

### Analysis video

```sh
python render_analysis.py clip.mov runs/clip --raider 5 --labels "left=Iran right=India"
```

This draws the locked court lines, team-coloured skeletons, the raider with live depth and
speed, and a bird's-eye mini-map with trails.

## 3. Stats for the game AI

```sh
python analyze.py runs/match1
```

This finds raids (one player alone in the other half) and measures:

- raid length
- how deep raiders go
- raider and player speeds
- how close defenders let the raider come
- chain width
- where the defensive line stands

These replace the guessed numbers in `game/match.gd` (`formation_spot`, tackle range,
`max_speed`).

## 4. Animation clips

Pick one player and the seconds where they do the move:

```sh
python to_clip.py runs/match1 --id 7 --start 41.2 --end 42.6 --name tackle_dive \
    --out ../../assets/mocap/tackle_dive.json
```

Any clip in `assets/mocap/` replaces the hand-made animation for that move:

| Clip name | When it plays |
|---|---|
| `tackle_dive` | defender dives for a tackle |
| `hold` | defender holding the raider |
| `struggle` | raider dragging defenders to the midline (loops) |
| `hand_touch` | raider's hand touch |
| `toe_touch` | raider's toe touch |
| `raid_idle` | raider's stance (loops) |
| `defend_idle` | defender's ready crouch (loops) |
| `celebrate` | after winning a point (loops) |

Clips store joint angles measured in the camera's plane, so **side-on footage gives the
best clips.** Moves toward or away from the camera come out flattened.

## Filming tips

- **Camera.** Tripod, high up, side-on, with the whole court in frame. 1080p, 60 fps if possible.
- **Second phone.** A second phone from the end line helps a lot with pile-ups, where bodies hide each other.
- **Light.** Good light, and players in contrasting jerseys.
- **Permission.** Film with the players' permission. Broadcast footage (PKL on TV or YouTube) is someone
  else's copyright. It's fine for studying how the pipeline behaves, but don't ship clips or
  stats taken from it.

## How well it works

Tested on a rendered match with exact ground truth (`tests/record_footage.tscn` and
`eval_truth.py`):

- **Court positions.** Median error 0.23 m; 90% of positions within 1.2 m.
- **Detection.** The game's placeholder mannequins are only half-detected: the model is trained on real
  people. On real people (OpenCV's sample street video) every walker was tracked with a steady ID.

## Licences

The pose model and Ultralytics library are AGPL-3.0. That's fine for an offline tool you run
yourself. The game doesn't include or link them, and the clips and stats are your own data.
To ship pose tracking *inside* the app, switch to an Apache-licensed model such as RTMPose.

## Next steps

- **3D.** Lift to full 3D bodies (WHAM, 4DHumans) for clips that work from any angle and can
  drive a rigged character directly.
- **Corner picking.** Click the court corners in a small viewer instead of typing coordinates.
- **Moving cameras.** Find the court lines automatically, so broadcast shots with camera moves can be used.

## Animations from Mixamo or Meshy

`fbx_to_clip.gd` turns a ready-made animation into a clip: a Mixamo download (FBX Binary, Without Skin,
30 fps, no keyframe reduction, In Place ticked for moves that travel) or one of Meshy's rig animations (FBX
or GLB). It matches the skeleton to the game's joints by bone name, keeps each joint's full 3D rotation
(clip version 2), and measures how fast and which way a travelling move goes.

```sh
godot --headless --path . res://tools/mocap/fbx_to_clip.tscn -- Running.fbx assets/mocap/move_run.json move_run --loop
```

Name a clip `move_*` to add it to the running set (run, jog, walk, strafes, backpedal, crouched shuffle):
whenever a player travels, the clip nearest his direction, speed and crouch carries the body, at the rate
that keeps the planted foot still, and the right arm stays free for a hand touch. Other clips serve a move
by their name's prefix (`MocapClip.FOR_STATE`): `kick_*`, `backkick_*`, `dodge_left_*`/`dodge_right_*`,
`evade_*`, `dubki_*`, `jump_*`, `dive_<tackle>_*`, `held_*`, `fall_*`, `getup_*`, `ready_*`, `idle_*`,
`cele_<kind>_*`, `slump_*`. A move with several clips gives each player his own, and of the get-ups he takes
the one that starts nearest the way he is lying. Quick moves are cut to their action and stretched over the
move's length in the game.

`mixamo_set.py` builds the game's set from the Mixamo downloads: which part of which animation serves each
move (and left-right flips of one-sided ones). `clip_events.py` finds those parts: it poses the game's
skeleton through a clip and reports when a foot reaches furthest, the hips are lowest or highest, and so on.
`res://tests/clip_sheet.tscn` draws clips as strips of poses on the game's body, for choosing and checking.
