# Rigging a generated player model

These tools turn a static humanoid mesh, such as a model made with Meshy or another
image-to-3D service, into one of the realistic bodies the game uses
(`assets/characters/bodies/`, listed in `bodies.json`). The model needs no skeleton or animations.
The game drives it from its own code-built skeleton (`game/rigged_body.gd`), so every move (crouch,
dubki, lion jump, holds, dives) works straight away, and gives each player the body nearest his skin
tone and build; officials get the referee bodies.

A model in a clear pose works best: arms and legs apart from the body, both feet on the floor.
A T-pose is ideal.

A textured model keeps its texture: the face, skin and the kit's folds come from it, and the
game paints the kit in each team's colours and tints the skin to each player's tone. Referees keep
their own outfit colours.

## One command

`make_body.py` runs every step below and adds the body to the game:

```sh
python make_body.py player_10 ../../assets/meshy/player_10_x.glb --kind player --build 1.0 \
    --yolo yolo11m-pose.pt --work /tmp/body_player_10
```

`--kind referee` for officials. `--build` is the body's build on the game's scale (0.92 lean to
1.1 stocky). It writes `NAME.krb` (the packed rig), `NAME_albedo.webp` and `NAME_kit.webp` with
their import settings, and lists the body in `bodies.json`. After changing only the rig or texture
scripts, `--keep-joints` reuses the joints found last time in `--work`.

Then check every body side by side (full figure, a raid stance, the face, the hand gripping):

```sh
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 384x384 res://tests/body_gallery.tscn -- /tmp/gallery.png
```

## The steps, one by one

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
   python autorig.py model_prep.glb OUT_DIR/joints2d.json rigged.json --center-y 0.95 --hem 1.0
   ```

   It prints how many vertices each bone got and the region counts (skin, jersey, shorts,
   hair). Vertices split along UV seams are rigged together, so the seams stay closed. If the
   pose model swapped left and right (it can take a faceless front render for a back view) or
   lost the arms of a wide T-pose, it says so and puts them right; palms are turned down, two
   finger bones are added to each hand, and the face and beard go wholly with the head.

6. **Make the kit textures** (textured models only). Give it the original file, which holds
   the texture:

   ```sh
   python kit_texture.py model.glb rigged.json NAME_albedo.webp NAME_kit.webp \
       --res-path res://assets/characters/bodies/
   ```

   It paints out the kit's logos and numbers, marks the kit's main colour (blue by default,
   `--main-hue`) and trim (red, `--trim-hue`), and adds the texture entry to the JSON. In
   Godot, import both textures as **Lossy** with **mipmaps** on and **Detect 3D** off (see
   their `.import` files); this keeps the APK small.

7. **Pack it** for the phone, and list it in `assets/characters/bodies/bodies.json`
   (`{"file", "kind", "build", "skin"}`; `skin` is the texture entry's `skin_ref`):

   ```sh
   python pack_body.py rigged.json ../../assets/characters/bodies/NAME.krb
   ```

Check the result with `res://tests/body_gallery.tscn` or `res://tests/rig_view.tscn` (see the comments at their tops), and in a match
with `res://tests/screenshots.tscn -- OUT dome`.

Players can switch between these bodies and the classic code-built ones in Settings →
Players.
