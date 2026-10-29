# Progress (resume from here)

Branch `claude/shared-foundation` (public: code only). Private data: `joshnason8-lab/world-stage-games-assets`
(release `mocap-source` holds `FBX_Mobility_27B_Pro.zip`; download with
`gh api -H "Accept: application/octet-stream" repos/joshnason8-lab/world-stage-games-assets/releases/assets/689900709 > mobility.zip`).
Lead session: session_016XKAyHkTQRNMGEgZbjNK28. Pilot branch: `claude/hurling-foundation-pilot` (from claude/hurling-game).

## Facts found
- Mobility: 223 clips in `Animation/IPC` (in place) and `Animation/Root_Motion`, 18 aim offsets, the MotusMan mesh.
  73-bone HumanIK skeleton (Root, Hips, Spine, Spine1, Spine2, Neck, Head, fingers 1-4, `Leaf*Roll1` twist leaves,
  `hand_*_wep`). Bind pose: T-pose facing +Z. 30 fps. Clips animate ForeArmRoll and LegRoll leaves, not ArmRoll/UpLegRoll.
- Owner's hurler (`player.glb`, Google Drive id 1WDmggD62izAKyLWvZ6bbfaVwRIKf9pg8): Meshy auto-rig, 23 mixamorig bones,
  A-pose, no fingers, 106k vertices; its hands are modelled with separate, slightly curled fingers.
- Six of seven games use the same 17-bone pose dictionary (ToonBody convention); Kho-kho uses a 23-bone Mixamo
  AnimationPlayer. All have `Crowd.build(spots, density, palette, seed, ...)` and `Crowd.set_excite(k)` (not Kabaddi).
  Quality: `Game.settings.graphics` 0/1/2, `Game.crowd_density()`.
- Godot 4.7 has native TwoBoneIK3D, LookAtModifier3D, BoneTwistDisperser3D.
- Gotcha: never set bone poses from inside `skeleton_updated` (Godot restores the pre-modifier poses after it).
- Gotcha: each Mobility FBX has its OWN "rest" (not a T-pose; the run's hips at 0.84 m, arms swept back). Clips must
  be measured from one reference T-pose: the pack's MotusMan_v55.fbx bind pose. Doing otherwise is what made
  "Mobility clips float ~25 cm"; measured against MotusMan the grounding correction is at most 2.3 cm.
- Mobility natural speeds (canonical 0.85 m leg): walk 1.30, jog 3.51, run 6.39 m/s; a body's strides scale with its
  leg length (WsgLocomotor.leg_scale; the hurler's is 0.906).
- Gotcha: skeleton modifiers can run several times per game frame; WsgFootPlanter does its contact logic once per
  WsgLocomotor.drive() (tick) and its IK every update. Manual skeleton advance did not see the mixer's pose: not used.

## Milestones
- [x] M1 rig: `rig.gd`, `rig_driver.gd`, `body.gd`, `grip.gd`, `tools/bake_character.*`, `tests/rig_test.gd` (PASS).
- [x] M2 locomotion: `tools/bake_clips.*` (150 clips, 5 s, data/mobility.res 7.5 MB + .json), `clips.gd`,
  `locomotor.gd` (AnimationTree built in code: idle, 8-direction walk/jog/run blend space, circle loops for curves,
  two one-off slots; starts by direction and intended speed, stops by distance and lifted foot, cuts angle-matched,
  turn-in-place, split jumps, look-at), `foot_planter.gd` (contacts found on the shown pose, lock on landing, drag
  to reach, ease up-then-across), `tests/loco_test.gd` (PASS: planted slide 5.3 cm/s mean, 0.4 p90; raw clips
  49.9 / 137.8), `tests/media/loco_video.tscn` (MP4 of the path).
  Open: the 90 degree cut still drags 25 cm/s; the curving jog 25 cm/s; ActorCore sprint not here yet.
- [x] M3 crowd: `crowd3d.gd` (WsgCrowd3D: build/set_excite/set_tension/watch_ball/clap/set_teams, near+far
  MultiMeshes, budgets in docs/BUDGET.md), `crowd_vat.gdshader` (all behaviour on the GPU), `crowd_clips.gd`
  (authored placeholder motions: sit idle/clap, sit-to-stand, stand idle/clap, cheer), `tools/bake_crowd.gd`
  (weld + vertex colours + simplify + VAT), `tools/toonbody_to_scene.gd` (17-bone game meshes -> rig).
  Data: addons/wsg_foundation/crowd/ (Hurling's Meshy fans 1,2,4,5,6; fan3's jacket balloons: left out).
  tests/crowd_test.gd PASS; tests/media/crowd_video.tscn. Not measured on a phone yet (no GPU here).
- [ ] M4 officials
- [ ] Pilot in Hurling, MP4s, ADOPTING.md, CI private-asset step
