# World Stage Games: the shared foundation

One rig, one locomotion system, one 3D crowd and one set of officials for all seven games. It is a Godot 4.7 addon
(`addons/wsg_foundation/`) that each game copies in (`ADOPTING.md`), with the tools that bake characters and clips for
it and the tests that keep it honest.

| Part | What | Files |
|---|---|---|
| **Rig** | 70 bones named as Mixamo / HumanIK: body, three-joint fingers, and 18 helpers (twist bones and joint correctives) driven at run time. Canonical rest: T-pose, every rest rotation the identity, facing +Z. Elbows and knees kept true hinges inside their range, ankles inside theirs, whatever poses them. | `rig.gd`, `rig_driver.gd`, `body.gd`, `grip.gd` |
| **Characters** | Any Mixamo-named model (the owner's hurler, Meshy auto-rigs, Mixamo, ActorCore) baked onto the rig: posed into the T, fingers found on the mesh it really has, weights spread along each limb over the helpers, cut down for phones. | `tools/bake_character.sh`, `tools/bake_character.gd` |
| **Locomotion** | (M2) | |
| **Crowd** | (M3) | |
| **Officials** | (M4) | |

## Licensed data

The motion capture (MoCap Online *Mobility*, and the ActorCore motions) is licensed: it and anything made from it
(Godot `.res`/`.tres`/`.anim`, baked textures) live only in the private repository
`joshnason8-lab/world-stage-games-assets` and ship only inside built APKs/AABs. `tools/fetch_assets.sh` puts it in
`addons/wsg_foundation/data/`, which git ignores. Everything in this repository (code, shaders, tools, the owner's own
models) is not licensed data. Without the data every game still builds and runs on its current animation.

## Tests

```
tools/run_tests.sh                                   # everything below, as CI runs it
godot --headless --path . -s tests/compile_check.gd  # every script compiles
godot --headless --path . -s tests/rig_test.gd       # extreme poses: candy-wrap, collapsing joints, inverted elbows and knees, toes up, grip
xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/pose_view.gd -- res://tests/character hero <albedo.jpg> out.png [poses] [bone]
```

`tests/rig_test.gd` skins the mesh on the CPU exactly as the GPU does and measures how much of its girth (distance
from the bones) the skin keeps at each joint in each extreme pose; every check is also run with the helpers off and
must find the fault there, which proves it can.
