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
