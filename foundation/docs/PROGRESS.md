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
- [x] M4 officials: `official.gd` (WsgOfficial: follow(delta, velocity, play, want) faces the play and side-steps/
  backpedals/jogs; signal_gesture whistle/point/score/foul/both_arms_up/arm_out - placeholder poses, ActorCore
  clips by the same names when they arrive), `pose_layer.gd` (WsgPoseLayer: poses over the clips, first modifier).
  tests/officials_test.gd PASS (faces play within 27 deg moving; raised arms 9-11 deg off vertical, elbows 3 deg,
  collarbones lifted 18; point 2 deg off target). Hurling's referee/umpire bake with toonbody_to_scene + bake_character.
  Locomotor fixes found here: a new body takes its facing at once; asked to move during a turn-on-the-spot, it sets off.
- [x] ActorCore (Actorcore.moves.zip on the same release): tools/bake_actorcore.gd -> data/actorcore.res (+json),
  merged by WsgClips. Sprint = top gait (1.2x its root speed). Crowd re-baked from mocap (tools/crowd_mocap.gd) into
  data/crowd (build only). Gotcha: the takes start on a T-pose frame; "stand-to-sit-chair" sits for 10 s and gets up
  at the end (that is our sit_to_stand). Missing from the owner: catches, tackle/get-up, official gestures (authored).
- [x] ADOPTING.md, tools/vendor.sh, tools/fetch_assets.sh (both zips, both libraries, the crowd), legacy_pose.gd.
- [x] Pilot (claude/hurling-foundation-pilot, PR #12; CI green; pre-release hurling-foundation-pilot built WITHOUT the
  licensed data until the owner adds ASSETS_REPO_TOKEN - then re-run the workflow on the branch). Videos sent to the
  owner (run/crowd/official x before/after/side-by-side). perf_probe (stadium): Low 95->97 calls 161k->164k tris;
  Medium 96->108, 232k->443k; High 141->159, 373k->1.13M. Earlier notes:
  (claude/hurling-foundation-pilot, worktree /home/user/hurling-pilot): game/foundation_link.gd,
  player.gd (link), stadium.gd (3D crowd, seats), crowd.gd/match.gd (excite, tension, ball), workflow (fetch step;
  publish beta/HD ONLY from claude/hurling-game; pilot -> pre-release "hurling-foundation-pilot"),
  tests/foundation_pilot.tscn (videos: run/crowd/official, WSG_OFF=1 for "before"). Hurling test_runner: 651 checks, 0
  failures with the link on. Next: videos -> MP4s (<20 MB), perf_probe numbers, push, FOUNDATION PILOT READY.
- Push access to the private repo: add_repo "push" refused twice by the auto-mode classifier; not needed (videos via
  SendUserFile; data baked in CI).
