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
  Data: addons/wsg_foundation/crowd/ (Hurling's Meshy fans 1 to 6; fan3 generated again in a T-pose, below).
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
- [x] Owner's review of the pilot (relayed by the lead): "running looks good"; "the arm bending the wrong way a few
  times"; "the crowd is still 'in' the seats"; does free-taking still look right.
  - Elbows: the hinge limit was applied (no rig elbow ever past 3 deg backwards); the fault was Hurling's own poses.
    Its 17-bone hurley arm is bent backwards or turned so the elbow points the wrong way most of the time (the toon
    mesh hid it), the rig's hinge straightened what it could not follow, and the arm snapped straight and back
    (99,000 body-frames in 3 match minutes straightened by over 30 deg, up to 66). WsgLegacyPose now rebuilds each
    arm through the game's shoulder and hand (`sound_arm`): the elbow bent forward in its hinge, swivelled about the
    shoulder-wrist line until it points within TURN_MAX (95 deg) of the way an arm in that place bends; the hand
    exactly where the game has it (the hurley grip unchanged). WsgPoseLayer.arms re-applies it under the body's own
    chest for body_pose arms. The pilot's tests/elbow_audit.tscn plays a whole match (runs, cuts, stops, swings,
    catches, solos, frees, puck-outs, signals): PASS on two seeds (worst 96 deg turned, nothing backwards, nothing
    straightened); `raw` (rebuilding off) FAILS. elbow_turn() is the shared measure.
  - Seats: the fans had nothing to sit on - their seat 0.31-0.42 m off the step, the step behind 0.38-0.6 m high
    and 0.44 m behind their feet - so the seat of their trousers was 0.2-0.3 m into it. bake_crowd now records each
    fan's seat (height, how far back) from the vertices weighted to the hips and thighs (crowd.json "seat",
    "seat_vertices"; data without it is measured off the VAT); WsgCrowd3D.place lifts each seated fan onto the seat
    height the game gives (seated: a number a spot), brings forward one who would sit back into a taller step
    (`room`), and draws sizes toward ones that fit. crowd_test.gd checks every seated frame of every fan on three seats:
    nothing below the seat or in the step behind (the old placement must fail: 0.21-0.33 m in). The pilot's stands
    have benches (0.40 m, 0.35 m deep) along the back of each step.
- [x] Owner: "add the change to the mini game as well" (practice frees and the shoot-out, close camera):
  - The crowd: Stadium.build_crowd(focus, quality) built again behind the goal they shoot at, quality 3 (Close:
    2,000 full figures of 3,000; the players not drawn pay for it); the national stadium's seated end has seats too.
  - The hands, close up: WsgGrip closes on the handle as drawn (`line`), the thumb opening or lying along it till it
    is clear; WsgLegacyPose.held keeps a held hand's turn exact (the arm swivels so the wrist stays within 95 deg);
    a free hand is turned back about its forearm; WsgPoseLayer.hold puts the top hand on the hurley's handle (two-bone
    IK, sliding along the handle into reach, rolling round it to spare the wrist). A forearm made a true hinge
    before the wrist is measured (else the rig driver handed the rest on to the hand).
  - The pilot's elbow audit (-- practice, -- shootout, a match): elbows never backwards past 2 deg, pointing within
    95 of the way an arm bends, wrists within 107 (the hurley hand; 95 the others), fingers 0.0 mm (right) and 3.4 mm
    (left) into the handle; PASS in all three. Found on the way: the game's arm poses are out of a forearm's range in
    its swings (its own wrists to 127 deg, elbows inverted to 179) - the rig makes them sound.
- [x] Owner decision (via the lead): per-game profiles. `WsgFoundation` (foundation.gd): profile "premium"
  (Hurling, Floorball, Netball: Vulkan, Medium default, High for flagships) or "budget" (Kabaddi, Kho Kho, Sepak
  Takraw, Pok Ta Pok: GL Compatibility, Low default, Medium at most); starting_tier() from the phone (device_class:
  Hurling's tested weak/flagship lists), allowed() caps the player's choice; guard_renderer()/boot_ok()/use_gl() and
  block_vulkan() (the Vulkan blocklist hook, a crash at start sends the phone to GL Compatibility); crowd_budget()
  (budget Medium: 150 3D fans; premium High trimmed to 700 + 1,300 = 2,000, about 510,000 triangles from 750,000);
  rank_detail() + WsgBody.set_detail (budget: full detail on the 6 bodies nearest the camera). tests/profile_test.gd.
  Perf probe for both profiles x both renderers: docs/BUDGET.md.
- [x] Found filming the practice close: the bodies floated in the game's own moves - the foot planter's hips_offset
  (the clips' hips fitted to this body) went on top of the game's own hips (WsgPoseLayer.lift_after takes it off),
  a pose without hips kept the last pose's (set_pose clears them), and the planter held the feet in the game's own
  moves (off in "full": the game plants its own); after a teleport the held feet pointed the legs sideways (a lock
  past 1.5 reach is planted afresh) and a foot drawn on and on climbed to the hips (let go past 20 cm). The elbow
  audit checks the feet too. Loco test still 6.4 cm/s.
- [x] Owner: "the phone should decide if it can handle better or worse graphics ... a new phone and Kabaddi should go
  to high quality". starting_tier(): weak Low, flagship High, else the profile's default (premium Medium, budget
  Low); every tier can be chosen (budget High: GL still, 400 + 800 3D fans, every body in full; 674,000 triangles).
  WsgFoundation.tier (set by the game) picks the full-detail bodies per tier.
- [~] Blender (the owner's list, in order): 1 normal maps - tools/blender (export_obj.gd, bake_normals.py/.sh;
  Ubuntu's Blender 4.0.2: denoising off or bakes are zeros). The pilot's hurler is now the HD model's own cuts
  (hero_hd: 5,866 / 1,758 triangles, tangents from the bake) with its sculpt as a normal map (1024) and its
  textures scaled for the game (albedo 2048, mask 1024); Hurling's kit shader bends its cel light and rim by it (and
  the cloth weave on High). Found baking it: bake_character left a finger joint at the origin when a band of the
  finger had no vertices (the old hurler too: LeftHandIndex3 1.6 m from the hand), now placed along the finger, and a
  bake with a joint over 0.7 m from its parent is refused; WsgGrip checks the middle of each bone too, and
  clear_axis_point keeps a handle out of a hand whose knuckles sit low. Audits: practice and shoot-out PASS with it.
  The officials too: the HD pack's referee and umpire cut for the rig (referee_hd, umpire_hd: about 4,200
  triangles each) with 1024 normal maps and 512 roughness; on High lit by the scene (normal and roughness maps), on
  Medium/Low cel-shaded as the game's officials with their relief (PersonBody's shader: nmap). The old umpire cut's
  spiked finger is gone with it. (White specks on the umpire's trousers and the referee's sock are in the HD pack's
  own textures: before and after alike.)
  Found in a whole match (seed 3): a runner's free fist, swinging in the motion capture, went 7.4 mm through the
  hurley's handle for 3 frames. WsgPoseLayer.clear moves a free fist straight off a handle it would meet (same frame,
  its turn kept); worst now 0.5 mm. Match audits (seeds 1 and 3), practice and shoot-out PASS.
  2 Baked light: WsgLightBake (light_bake.gd) gives a game's built stadium second UVs (each quad its own patch,
  packed in rows, made the same at run time so only the maps ship; a signature refuses a map baked for other
  geometry) and exports it with the game's sun and sky; tools/blender/bake_light.py bakes it in Cycles (sun, sky,
  shadows, two bounces) and the stands' shadow on the ground. Hurling: all four venues (parish dusk, county day,
  national stadium day, county night), 2048 + 1024 maps, on Low and Medium (and GL): the stands drawn unshaded,
  vertex colour times the map; the grass multiplied by the ground map. Before/after stills sent. LightmapGI ruled out
  (its baker is editor-only, on saved scenes; these stadiums are built at run time). tests/light_bake_test.gd.
  Found: the 3D crowd and the cut-outs stay as bright under a roof as in the sun - for item 5 (light probes at the
  seats from the same bake).
  3 Clean LODs: tools/blender/decimate_lod.py + lod_from_obj.gd (make_lod.sh). The light meshes were meshoptimizer's
  nearest level: 8.8 mm off the detailed surface on average, 100 mm at worst (fingers and the helmet's rim
  collapsed). Blender's edge collapse (symmetric, hands and head denser) at the same 1,758 triangles: 2.2 mm, 16 mm,
  skinned from the nearest point of the detailed surface. Hurling: the HD hurler's, and the officials' (1,600
  triangles where they had none: the full 4,200 at every distance). Rounder helmet and shoulders on Low. test_runner
  652 checks, 0 failures.
  4 Loose clothes: the umpire's coat, modelled arms-down, was stretched in the rig's T from its side into the
  sleeve (17 cm below the arm, a shirt stops at 8) - a wing whenever an arm is out - and its side, skinned to the
  shoulder helper, rose 13 cm with the arms up. tools/cloth_drape.gd takes the webbing out (sleeve's underside up to
  the sleeve, the rest straight down the side); tools/cloth_weights.gd skins everything outside a sleeve as a
  well-skinned body in the same T (the hurler: nearest point of its surface, without its arm bones). Umpire: 7 cm,
  0 cm. The rig test checks both now (SLEEVE_MAX 14 cm, LIFT_MAX 6 cm; the hurler 8 and 5, the crowd's fans 4-9
  and 3). Left: with an arm straight out the coat still hangs a clean panel from the sleeve - the coat's sleeve and
  side are one sheet in the source; a seam there needs the model cut again.
  fan3: the Meshy blazer's sleeves are fused into its body (generated arms-down): 37 cm of webbing, rising 25 cm;
  weights fix the rise (0 cm) but not the cape. Stays out of the crowd; the fix is generating it again in an A-pose
  (Meshy, about 35 credits: asked the lead).
  5 The crowds matched: the 3D fans read blue-grey and pastel beside the cut-outs' county colours (measured on the
  main stand: 0.37 0.38 0.44, saturation 0.26, against 0.41 0.35 0.35, 0.34). Now each spot's shirt is decided once
  (Stadium._shirts: both county colours, sections leaning one way, the rest anything) and both crowds wear it (the
  cut-outs' code, WsgCrowd3D.shirt_code); the 3D fans are lit as the game lights its people (unshaded, a cel light
  from the sun, crowd_vat.gdshader) and written as the cut-outs are: 0.39 0.33 0.33 against 0.37 0.33 0.33, luma
  and saturation equal; the line between them is gone. Each seat's baked light: WsgLightBake probes (Blender ray
  casts from each fan's head: the sky through the half facing the pitch, the sun's disc; 5 s for all four venues),
  on both crowds - under the roofs darker. Found: under GL Compatibility a MultiMesh's custom data is half floats
  (a light packed with a shirt code turned the shirts purple): small numbers only (g: the light, signed seated).
  Close up, the lower shirts of many 3D fans were pale (old and new alike): the crowd bake's shirt mask stopped 5 cm
  above the hip joint and these fans' shirts go lower. bake_crowd now takes the shirt's colour from the chest and
  counts what matches it down to 12 cm under the hip joint (not the trousers): solid to the waist. Crowd re-baked
  (authored, committed; the licensed one in data/ only). Caught on the way: with the licensed clips present,
  bake_crowd baked them into whatever folder it was given - the committed crowd/ included (it was restored before
  anything was staged); it now refuses an ActorCore bake outside addons/wsg_foundation/data/ (AUTHORED=1 for crowd/).
  The one-frame feet glitch (57 cm, a runner, default seed at t 60): no longer there - the default seed's worst is
  28.5 cm (a sprint's flight, under 30) and a 6-minute seed 2 match passes too (the planter's fixes since).
- [x] A. Firebase Test Lab: .github/workflows/wsg-testlab.yml (reusable): builds a game's "Android TestLab" preset
  (the "testlab" feature: a match that plays itself, 60 s at Low, Medium and High, each logged as a WSG_PERF line by
  WsgPerfLog, addon perf_log.gd), picks a budget, a mid-range and a flagship phone from Test Lab's catalogue that day
  (preference lists, then names), runs it there (robo; the build ignores taps and Back), reads each phone's logcat
  back into a table in the run's summary and a JSON artifact. Skips green without FIREBASE_TESTLAB_KEY. Spark: about
  5 physical tests a day, a run is 3: manual (workflow_dispatch). docs/TESTLAB.md: the owner's steps (project,
  two APIs, a service account with Test Lab Admin + Storage Object Viewer, the JSON key as the secret). Hurling:
  testlab/, the preset, hurling-testlab.yml. Tried here: the scene on this machine (software GL) prints all three
  tiers; the summary parser on its lines. Not run on Test Lab yet: needs the owner's key.
- [x] fan3 again (the lead's go-ahead): generated anew through Meshy in a T-pose (sleeves apart from the body),
  the same look (navy blazer, grey scarf, white shirt, beige trousers, grey beard, glasses): 35 credits (159 to
  124; tools/meshy/tasks.json "fan3b" in Hurling). Baked onto the rig: 15 and 13 cm under the arms, rising 9 cm
  (the old one 37, 31 and 25); after cloth_drape and cloth_weights 8, 7 and 0 - the rig test's cloth checks pass.
  Back in the crowd (six fans; authored crowd re-baked, the licensed one in data/ only).
- [x] B. Television (addons/wsg_foundation/broadcast + replay.gd): WsgReplay keeps every body as drawn (each bone's
  final turn, 16-bit, and its place; 0.6 KB a body a frame; 4 to 7 s by tier) and plays it back through a last
  modifier (tests/replay_test.gd: bones within 0.06 degrees and 0 mm of what was drawn). Found: Hurling's replay
  moved its old bodies while the foundation's froze in their last pose (the match stands still in a replay, so the
  link was never called) - now they replay exactly. WsgDirector: a score's cut-aways (the scorer close, from the
  camera's side of the play, round anyone in the line; the stand going up), the flight round the ground before the
  throw-in; none on a budget phone's Low. WsgLowerThird, WsgScorebug, WsgBroadcastTheme (colours, type, timing,
  reduced motion); text through tr(). tests/broadcast_test.gd. Hurling: a score is the scorer close with their name
  and the day's tally (TALLY_TODAY, English and Irish), after a goal the stand behind it, then the replay (the
  restart waits; a tap skips); the replay's camera up to 9.5 m (cheering fans on the terrace had filled it); the
  opening flight under the title card on Medium and High. Hurling keeps its own score bug. Demo filmed.
- [x] C. Sound (addons/wsg_foundation/audio): WsgAudio mixes a game's own recordings - the crowd a bed of layers
  driven by the excitement and tension the 3D fans already follow (one call moves the stand and its sound), each
  "smooth" or "linear"; sounds where they happened (AudioStreamPlayer3D pool, the tier's voices: budget Low 8 to
  premium High 24, each kind's own limit, the lowest priority / farthest / oldest giving way, a losing newcomer not
  played); ducking (the crowd bus, the deepest wins, eased back; on the game's clock); haptics behind the game's
  setting, never two within 60 ms; crowd one-offs never the same take twice running. Buses WsgCrowd/WsgSfx/WsgVoice.
  tests/audio_test.gd. Hurling (Sfx): the bed is the owner's crowd_loop (the ground's size), applause swelling with a
  score and dying with it, and the crowd again out of step and higher building with an attack (_hype); strikes,
  shoulders, the post, the bounces and the referee's whistle where they happen (the old flat fall-off kept without
  the foundation); the crowd dips under each whistle (5 dB) and under the replay (6 dB). Measured in the demo
  (scripted attack and goal): tension layer -34 to -11.5 dB over the attack, applause to -8 dB at the goal and back
  in 3 s, the crowd bus -6 dB through the replay; overall loudness -45 calm, -35 building, -12 at the goal.
- [x] The lead's three quick wins (IDEAS), in Hurling: "Watch it back" after a score (a button 4 s after its replay:
  slow motion 0.4 from behind the scorer, then low on the touchline; a clip kept apart, WsgReplay.clip; not on Low;
  the touchline camera moved out of the stand and off the linesman); a sweet-spot pulse (a placed ball struck with
  the bar in the middle of the green, a pull met well inside the reach; behind the vibration setting); the ends
  behind the goals in their counties' colours (90%) with eight flags each (WsgFlags: pole and two-colour cloth,
  rippling by shader, harder with the excitement; two draw calls; half on a budget phone, none on its Low).
  Next: the dry run of ADOPTING.md against a budget game; then the roll-out (after the owner's phone test).
- [x] The owner's notes on the licensed pilot (run 41115702159):
  - **The free's strike** ("the shin looks very odd, the body seems to break" at the end of the swing). Two causes.
    (1) In the game's own moves the rig took HeroBody's turned-down feet (foot_pitch 32, for its old model) on top
    of a model already standing flat: the feet pointed at the grass, about 50 degrees. Undone in the link
    (reader.undo), as the officials' were. (2) The free's clip (the owner's video, through MediaPipe) loses the legs
    and the head after contact: a knee bent 35 degrees sideways, the trailing boot spun half round and back between
    frames, the neck and the head each tipped back 20. Limited after contact (Player.FREE_LIMITS: a knee is a
    hinge, a foot turns a little from its shin, the head back about 30 in all), the feet throughout. And a knee is a
    hinge on the rig in every game move (FoundationLink: only the shin's bend about its own axis, never past straight).
    The pilot's elbow audit now checks knees (backwards, off the hinge), ankles (pointed, tipped up), the back
    (leaning back, to a side, turned) and the head (back) on the rig and on the game's body: practice PASS.
  - **The planter bent standing knees backwards** (the officials, 29 degrees): its two-bone IK bent the knee "the way
    it was", and a standing clip's locked knee is a hair past straight. Now always forward of the thigh.
  - **The crowd's feet** (toes up, as the officials' were): five of the six fans' models were made with the feet
    pitched up 10 to 36 degrees. bake_crowd now measures each sole and turns the foot down before the bake (the
    committed authored crowd and the licensed one rebaked).
  - **"Lower the graphics by itself" did not.** Hurling watched only the first ten seconds of play, only the
    average (over half the frames under 36 a second), and lowered only the picture's resolution. WsgAutoTier:
    1.5 s windows, bad when slow on average or with 3 hitches (over 2.5 times the middle frame and 45 ms), two in a
    row - steps within about 5 s; the pilot applies the step at once (Stadium.apply_graphics: shadows, sky, crowd,
    flags; the men's shadows; the bodies' detail). Hurling's beta (claude/hurling-game 0.17.0) has the same code.
  - **The stutter**: the foundation's per-body work, every frame, for every body: 8 ms a frame here for 38 bodies
    (2 ms without the foundation; Low cost the same as High - every body in full on every tier). Now: a body's
    modifiers run only when the game poses it (WsgBody.set_manual / advance: far men every second or third frame),
    those frames staggered, the nearest 8/14/22 in full detail by tier (premium), the pose rate's distances by tier.
    Measured (tests/hitch_probe.gd, the national stadium, AI v AI, headless): High 10.5 -> 5.4 ms middle, 19.8 ->
    13.4 worst 1%; Low 9.7 -> 3.0 ms, 16.8 -> 7.5.
  - **The officials on the player's model** (the owner: "can we use the player model for them?"): the referee and
    the linesmen in black, the umpires in white with their caps, each with their own head (tools/player/
    official_body.gd: the HD hurler from the collar down, the official's head and neck moved onto his rig, the
    collar painted as skin); no number. The flag held: the pole across the palm as a hammer's handle, the fingers
    closed round it (WsgGrip on that line), the pole on along the arm, the cloth hanging from it; a child of the
    body. The separate officials' models are no longer drawn (their heads are the source).
  - Then (the lead's three): **the arm through the chest** at the end of a free's swing (92 mm into the HD chest:
    the clip's follow-through sweeps it across, as a slimmer body takes): WsgPoseLayer.torso_r - a forearm inside the
    chest swings the arm out about the shoulder (a held hand too, when well in); rig_test checks it (71 mm -> 0).
    **The shoot-out**: a goalkeeper's dive bent his knees 50 degrees off the hinge (the game's own move: its shins
    held to a hinge now, Hurling); the planter's IK left a knee off its hinge (the thigh now rolled so the hinge is
    square to the leg's plane); an open hand on the handle (a body made full detail after it was posed: ranked
    first now, Hurling). The shin above the ankle: rig_test's feet_turned (the caps: shin 25, foot 20) keeps 99%.
    Hurling's bench checked (test_runner). Practice and shoot-out audits PASS.
- [x] The owner on 0.17.1-pilot (c60ddf4): "looks better". Open polish: the sprint looks "a touch awkward" (works;
  may change later; logged in IDEAS, not touched). The roll-out to the other games waits for the owner's go.

## Roll-out (the owner's go, 2026-10-31) - the state, for whoever picks it up
- **Sync path (step 0, done)**: every game vendors its own copy. `tools/sync_foundation.sh` (in each game's
  `tools/wsg/`) fetches claude/shared-foundation and replaces only the foundation's files (keeps `data/`), stamping
  `addons/wsg_foundation/VERSION`; `tools/check_foundation.sh` is a CI step that warns (never fails) when behind
  (Hurling's workflow has it, after checkout). ADOPTING 6.5. When the foundation changes: run the sync in each adopted
  game's pilot or game branch, its suites, push, tell the lead.
- **Hurling**: claude/hurling-foundation-pilot merged with claude/hurling-game (its 0.17.1 auto graphics deduplicated:
  WsgAutoTier kept, with the beta's frame-cap allowance and its fuller step) as 0.18.0-beta, code 27; the beta releases
  from claude/hurling-game. The Hurling session (session_014hG8tsaKWnsFdAR9yvDKpG) was asked not to push meanwhile:
  tell it when the merge is in and green.
- **Order after Hurling**: Floorball (session_01Q7qyfqeBNtBfV9E7m7BncT, claude/floorball-game, 0.9.1-beta code 14,
  premium/mobile renderer), Netball (session_017CzG23FxV2MAZaGUFTP3f3, claude/netball-game), Kabaddi
  (session_01S3UdqNS9Fi1bujUaZ33MrC, claude/kabaddi-game-concept-asnz07), Sepak Takraw (session_01LRwBAmvSWewkk6NNucZTDd:
  no branch found by name - ask it), Kho Kho (session_01VV6bXvTsWtNsbEvdksa2xw, claude/kho-kho-game; its committed
  Mixamo .res await the owner: add no new derived animation), Pok Ta Pok (session_01HdsmiiHaiy9fT5QbiA2oUY,
  claude/pok-ta-pok-game). Each: message its session first; pilot branch claude/<game>-foundation-pilot from the game's
  branch; pre-release tag <game>-foundation-pilot, title not starting with the game's name, version code above its
  beta; never its beta tag; merge only after the owner passes it. Each gets its fans (existing/authored, no new Meshy
  without asking), officials from its player model in the sport's kit, venue light (indoor halls: Floorball,
  Netball, Kabaddi, Kho Kho), fonts (Indic: Kabaddi, Kho Kho), replays at the sport's moments, WsgAutoTier; full
  suites + audits; close-ups and the pilot's CI to the lead. The A16 is the test phone: budget games start on Low there.
- **Floorball's shape** (begun: worktree /home/user/floorball-pilot, branch claude/floorball-foundation-pilot):
  like Hurling - the game poses its own 17-bone `Body` (hips, spine, chest, neck, head, upperarm_l...: the same names
  as Hurling's ToonBody) and `RiggedBody` follows it on the owner's Meshy man/woman (assets/characters/*.scn,
  Mixamo-named). Plan: vendor; bake_character.sh the man and woman onto the rig; a FoundationLink from Hurling's
  (the stick in the hand, its actions); WsgCrowd3D in the hall; referees on the man model in their kit; the hall's
  light; WsgReplay at goals; WsgAutoTier; the workflow's licensed-assets step, check_foundation, a pilot publish step.
