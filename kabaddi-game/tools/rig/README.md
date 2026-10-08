# Rigging a generated player model

These tools turn a static humanoid mesh, such as a model made with Meshy or another
image-to-3D service, into the realistic player body the game uses
(`assets/characters/rigged_athlete.json`). The model needs no skeleton or animations. The game drives it
from its own code-built skeleton (`game/rigged_body.gd`), so every move (crouch, dubki, lion
jump, holds, dives) works straight away.

A model in a clear pose works best: arms and legs apart from the body, both feet on the floor.

## Steps

You need Python with `trimesh fast-simplification ultralytics` (the mocap venv from
`tools/mocap` works) and Godot 4.7.

1. **Shrink it.** The model needs about 14,000 triangles; generated models often have
   500,000 or more.

   ```sh
   python decimate.py model.obj model.glb 14000 1.5
   ```

2. **Render three views.** Make an empty Godot project containing `model.glb` and
   `render_views.gd` (attach it to a Node3D scene), then run:

   ```sh
   xvfb-run -a godot --path proj --rendering-driver opengl3 --resolution 1024x1024 res://render_views.tscn -- OUT_DIR
   ```

   This writes `ortho_front.png`, `ortho_side.png` and `ortho_left.png`. The camera is orthographic
   and 2 m tall.

3. **Find the joints.**

   ```sh
   python joints2d.py yolo11m-pose.pt OUT_DIR    # writes OUT_DIR/joints2d.json
   ```

4. **Rig it.**

   ```sh
   python autorig.py model.glb OUT_DIR/joints2d.json ../../assets/characters/rigged_athlete.json
   ```

   It prints how many vertices each bone got and the region counts (skin, jersey, shorts,
   hair). Check the result with `res://tests/rig_view.tscn` (see the comment at its top).

Players can switch between these bodies and the classic code-built ones in Settings →
Players.
