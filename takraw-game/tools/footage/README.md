# Moves traced from match footage

The broadcasts and their frames are not kept in this repository; only what is measured from them is.

1. Cut the frames of a moment from the video, cropped around the player and scaled up 2x, as PNGs (ffmpeg).
2. `trace_pose.py pose_landmarker_heavy.task "frames/*.png" pose.json sheet.jpg 30`: MediaPipe's pose landmarker
   (`pose_landmarker_heavy.task`, from Google's MediaPipe models) on every frame, in video mode. It writes the 33
   landmarks per frame and a contact sheet with the skeleton drawn every third frame, to check the tracking.
3. `pose_angles.py pose.json r [--csv T0]`: the joint angles per frame (the trunk's lean, the shoulder, elbow and
   knees, the wrist's height and reach), measured the way `tests/pose_probe.gd` measures the game's own poses.
4. Set the move's keys (`game/moves.gd`) and check them with `tests/pose_probe.tscn` beside the footage's numbers.

| File | What |
|---|---|
| `serve_toss_world_cup.csv` | The serve's throw (regu), the thrower's right arm: World Cup broadcast (Thailand v the Philippines), 308.5-311.5 s, 30 fps, every frame tracked. 0-2 s: the ball held out in front, then lowered into the crouch; 2.0 s on: the swing, the release (about 2.2 s), the follow-through. Used for `Moves.LOW_HOLD`, `HOLD`, `toss_low`, `toss` (0.14.3). |
