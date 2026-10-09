# Rigging a generated player model

These tools turn a static humanoid mesh, such as a model made with Meshy or another
image-to-3D service, into the realistic player body the game uses
(`assets/characters/rigged_athlete.json`). The model needs no skeleton or animations. The game drives it
from its own code-built skeleton (`game/rigged_body.gd`), so every move (crouch, dubki, lion
jump, holds, dives) works straight away.

A model in a clear pose works best: arms and legs apart from the body, both feet on the floor.
An A-pose or T-pose is ideal.

A textured model keeps its texture: the face, skin and the kit's folds come from it, and the
game paints the kit in each team's colours and tints the skin to each player's tone.

## Steps

You need Python with `trimesh fast-simplification ultralytics opencv-python pillow` (the mocap
venv from `tools/mocap` works) and Godot 4.7.

1. **Shrink it** if it has more than about 15,000 triangles (generated models often have
   500,000 or more). Skip this for a game-ready export.

   ```sh
   python decimate.py model.obj model.glb 14000 1.5
   ```

2. **Prepare it.** This bakes the node transform, keeps the model's own normals and UVs, and
   with `--turn` faces it to -Z as the rig tools expect (glTF models usually face +Z).

   ```sh
   python prepare.py model.glb model_prep.glb --turn
   ```

3. **Render three views.** Make an empty Godot project containing the prepared model as
   `model.glb` and `render_views.gd` (attach it to a Node3D scene), then run, with the centre
   at about half the model's height:

   ```sh
   xvfb-run -a godot --path proj --rendering-driver opengl3 --resolution 1024x1024 res://render_views.tscn -- OUT_DIR 0.95
   ```

   This writes `ortho_front.png`, `ortho_side.png` and `ortho_left.png`. The camera is orthographic
   and 2 m tall. The whole body, head included, must be in the picture.

4. **Find the joints.**

   ```sh
   python joints2d.py yolo11m-pose.pt OUT_DIR    # writes OUT_DIR/joints2d.json
   ```

   Check that the front view's keypoints are confident (above 0.8); if the nose is not found,
   the model is probably facing away.

5. **Rig it.** Pass the same centre as step 3, and the height of the shirt's hem if it hangs
   below the default (a little above the hips):

   ```sh
   python autorig.py model_prep.glb OUT_DIR/joints2d.json ../../assets/characters/rigged_athlete.json --center-y 0.95 --hem 1.0
   ```

   It prints how many vertices each bone got and the region counts (skin, jersey, shorts,
   hair). Vertices split along UV seams are rigged together, so the seams stay closed.

6. **Make the kit textures** (textured models only). Give it the original file, which holds
   the texture:

   ```sh
   python kit_texture.py model.glb ../../assets/characters/rigged_athlete.json \
       ../../assets/characters/athlete_albedo.webp ../../assets/characters/athlete_kit.webp
   ```

   It paints out the kit's logos and numbers, marks the kit's main colour (blue by default,
   `--main-hue`) and trim (red, `--trim-hue`), and adds the texture entry to the JSON. In
   Godot, import both textures as **Lossy** with **mipmaps** on and **Detect 3D** off (see
   their `.import` files); this keeps the APK small.

Check the result with `res://tests/rig_view.tscn` (see the comment at its top), and in a match
with `res://tests/screenshots.tscn -- OUT dome`.

Players can switch between these bodies and the classic code-built ones in Settings →
Players.
