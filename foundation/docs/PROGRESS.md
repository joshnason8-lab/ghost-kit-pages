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
- **Floorball pilot (done, waits on the owner)**: claude/floorball-foundation-pilot at 962f73c, 0.9.1-pilot code 16,
  pre-release floorball-foundation-pilot (CI run 41196987431 green: 150 clips, test_runner 716/0, signed 6F:23:A9:36);
  draft PR #13 into claude/floorball-game (subscribed). FoundationLink full/stick/referee modes, the stick in both
  fists, goal replay, WsgAutoTier, rank_detail, far players posed every 2nd/3rd frame (Low 4.6 / Medium 6.3 /
  High 7.3 ms). Keeper saves stay on the game's procedural poses (no keeper clips in the library: the gap).
  Found on the way: the claw fist was bake_character putting the first finger joint where Meshy's joined fingers
  split (near the tip) - fixed in the foundation (30a3970: fingers from their knuckles); Hurling's bakes predate it
  (a re-bake may help the hurler: untested, ask the owner). The workflow had no concurrency group (an older run
  published over a newer): add `concurrency: {group: <game>-android-${{ github.ref }}, cancel-in-progress: true}`
  to every pilot's workflow. Open: arena/crowd not rebuilt on a mid-match step down; no replay label; mode changes
  snap. Comparison frames: scratchpad fb_cmp/ (beta vs pilot via tools/player/grip_view and breakaway_view).
- **Next**: Netball (the lead: go). Hurling: HOLD the tooling sync (be73cbf, 30a3970) - a push to claude/hurling-game republishes its beta; bundle it with the next real Hurling change. The hurler finger re-bake waits on the owner (the lead asks).
- **Netball pilot (done, waits on the owner)**: claude/netball-foundation-pilot at 0109e47, 0.8.2-pilot code 14,
  pre-release netball-foundation-pilot (CI run 41209540502 green: test_runner 1453/0); draft PR #14 (subscribed).
  Netball's beta publish had NO branch guard (fixed on the pilot: guard + concurrency in the first pushed commit - check
  every game's workflow before the first push). Medium/High only; Low keeps the game's bodies (draws identical).
  Umpires and reserves on the hero; the ball placed in the `posed` callback; goal replay after the post close-up,
  intercept replay at the stoppage. No 3D crowd (Netball's toon crowd faces the play; the authored fans are Hurling's)
  and no WsgLightBake (cel-lit venues). The licences screen credits MoCap Online and ActorCore (Floorball and Hurling
  don't yet: asked the lead/owner). To port (from the Netball helper): ADOPTING - a held ball is placed in the body's
  `posed` callback (else a frame behind); WsgPoseLayer - lay the hips once before the holds, a weight per hold
  (Floorball's StickLayer lays them twice in a fade: holds drift up to 4 cm); WsgGrip - a sphere grip; rig_test - the
  right elbow at 140 deg keeps 85% girth on the Netball bake (at the limit).
- **Next**: Kabaddi (budget profile: Low default on the A16; Indic fonts).
- **Kabaddi pilot (done, waits on the owner)**: claude/kabaddi-foundation-pilot at b1ccbb4, 0.13.1-pilot code 37,
  pre-release kabaddi-foundation-pilot (CI run 41220305241 green); draft PR #15 (subscribed). Ten Meshy bodies (.krb ->
  tools/rig/krb_to_scene.gd -> bake), game's kit shader kept; every kabaddi move is the game's pose over the rig; mocap
  only walking/standing/officials/roar/slump; Low pixel-identical; one replay per raid, prioritised, label in 8
  languages. Ported to the foundation (bdd4071): WsgLegacyPose p_face, UV2 through bake_character/lod_from_obj.
  Still to port as ADOPTING notes: set planter.enabled every update (a body posed by the game from frame one never
  runs the locomotor); A-pose legs rebuilt from joint positions (FoundationLink._legs); measure bones in `posed`;
  bake_character should warn when a body gets no LODs.
- **Syncs held**: Floorball and Netball pilots are behind bdd4071 (tooling + a default-compatible legacy_pose) and
  Hurling behind be73cbf/30a3970/bdd4071 - send with each game's next real change (a push republishes the APK).
- **Sepak Takraw (in progress)**: claude/sepak-takraw-foundation-pilot from e74d4ec (the session's own publish
  guards), worktree /home/user/takraw-pilot, 956e2c4 vendor, bd5b7a9 CI + 0.12.4-pilot code 21; helper integrating.
  Then Kho Kho (no new derived animation data), Pok Ta Pok.
- **Sepak Takraw pilot (done, waits on the owner)**: claude/sepak-takraw-foundation-pilot at 347be33, 0.12.4-pilot
  code 21, APK 139 MB, CI green (test_runner 1659/0); PR #16. Game's moves for every rally action; mocap walking,
  fetching, judges; Low identical; user_bot unchanged; A16 Low via the game's detect_graphics ("mali-g5"/"mali-g6").
- **Kho Kho pilot (done, waits on the owner)**: claude/kho-kho-foundation-pilot at 7b9eede, 0.10.4-pilot code 21, APK
  100.5 MB, CI green (722/0); PR #17. The six on-hold Mixamo .res untouched, no new derived data; match_sim identical;
  A16 test added; the media kit skipped on the pilot branch (job-level `if`).
- **Pok Ta Pok pilot (done, waits on the owner)**: claude/pok-ta-pok-foundation-pilot at 261ddc0, 0.5.4-pilot code 11,
  APKs 135/137 MB, CI green (697/0); PR #18. Replay cap set with the game's session (ring always + max 3, 90 s apart);
  step-down tested; owner phone test listed (A16 on Medium, stone night, 5 min, 30+ fps else High only).
- **ROLL-OUT COMPLETE**: Hurling shipped; six pilots (PRs #13-#18) wait on the owner. Every pilot: Low unchanged, A16
  starts Low, beta tag untouched, licensed data never committed.
- **To port next (from the pilots)**: locomotor own RNG (Pok Ta Pok), locomotor cut-from-heading + resume() (Kho Kho,
  in its vendored copy), bake_character Meshy spine by hierarchy (Pok Ta Pok) and stance shift/scale into rig.json
  (Kho Kho), a world-point hand-hold WsgPoseLayer (Kho Kho), WsgFootPlanter: `enabled=false` still bends legs -
  document `active=false` + lift_after 0 or fix (Takraw), a sphere grip (Netball), ADOPTING notes (posed callback for
  held items, planter.enabled/tick/reset under a game pose, A-pose legs via joints, leg_scale by height, resume after
  replay where paused, 17-bone proxy for dictionary poses), bake_character.sh hangs on a script error.
- **Ported from the pilots** (all opt-in, defaults unchanged; foundation tests identical before and after plus new
  checks): WsgLocomotor `rng`, `cut_from_heading`, `resume()`; bake_character older Meshy spine by hierarchy, stance
  `{shift, scale}` in rig.json (`character.stance`), a no-LOD warning; bake_character.sh stops on a script error or
  BAKE_TIMEOUT; WsgFootPlanter `keep_pose` (`enabled` unchanged: every game relies on it); WsgPoseLayer `hips_first`,
  `hold_weight_own`, `make_holds`, `hold_point` (+ `WsgLegacyPose.arm_maker`); WsgGrip `solve_sphere`/`sphere_point`,
  WsgBody `grip_sphere`/`ball_point`; ADOPTING 5.10 "Lessons from the pilots"; CATALOGUE "all 7" and gaps by sport.
  Games pick them up on their next sync by opting in (ADOPTING 5.10); nothing changes for a game that does not.
- **SYNC WARNING (after the ports, 2026-11-02)**: the new behaviours are opt-in. When syncing a pilot, set in its
  FoundationLink in the same change: Pok Ta Pok `loco.rng = RandomNumberGenerator.new()` (else its seeded matches
  change); Kho Kho `loco.cut_from_heading = true` (else the 8 m/s glide returns); advisable for Kabaddi and Sepak
  Takraw too. Optional clean-ups: Netball grip_sphere/ball_point and hips_first/hold_weight_own/make_holds (also
  Floorball, fixes its 4 cm hold drift); Sepak Takraw and Kho Kho planter.keep_pose; Kho Kho hold_point + arm_maker.
- **WsgToonDriver (opt-in, 2026-11-02)**: the capture on a game's own 17-bone toon for the Low tier (ADOPTING 5.13):
  a hidden mesh-less rig + WsgLocomotor, retargeted by segment direction and twist onto the game's bones (its rest
  read from its skeleton; bone_map, face), overrides per bone for the game's moves (or `pose()` as a dictionary),
  staggering, no-op without the clips. ~0.1 ms a body desktop headless (14: 1.5 ms; every 3rd frame 0.65 ms). Tried
  in Netball's worktree (not committed there): Low draws identical, beta-vs-driver strips, the reference wiring as a
  patch for the Netball session. WsgLocomotor._stride now caches its rings (results identical, loco_test output
  byte-for-byte; a third of the locomotor's own time). Found: the ActorCore sprint's feet cover ~2.6 m a cycle
  against its root's (meta stride) 3.6 m - the planter hides it (the sprint is loco_test's worst planted segment);
  a toon without one slides ~2 m/s at a full sprint. Fixing it (a foot-measured stride) would speed the sprint's
  legs by a third: left for the owner's eye. Games opt in on their next sync; nothing changes for one that does not.
- **Overnight 2026-11-02 (owner's playtest round)** - the pilots are merged by the game sessions (they own their
  branches again; push only when a session asks). Done in the foundation: fetch_assets via `gh api` (945719b; a cloud
  session needs world-stage-games-assets added); WsgSpectator (Watch AI, ADOPTING 5.11); torso_capsule/clear_segment
  and limb_capsule/torso_from_body (5.12); WsgLightBake thin faces get texels (0d249ce: Hurling's black posts -
  Hurling re-baked in 4432d62); WsgToonDriver (Low tier on a game's own body, 5.13); never a threaded RichTextLabel
  (5.10: the CI signal 11s in Netball/Sepak/Kabaddi were Godot 4.7.2's threaded-label race, not the foundation).
  Game-side, sent as patches: Floorball's lean/shift controller (it made its own), Netball's Licences un-threaded,
  Hurling's StickClear (the hurley out of the lead arm; needs the sync to e739a95). Open: the ActorCore sprint clip's
  feet travel 2.6 m a cycle against 3.6 m stride (slides on Low without a planter); Hurling's score_check (35) is
  noisy over long matches (0.7-1.7 sideline cuts on one commit) - Hurling is chasing unseeded randomness.
- **Web exports never carry the licensed data** (ADOPTING 5.10, 79b346e): each game's Web preset lists
  `addons/wsg_foundation/data/*` in exclude_filter. Done: Kabaddi (the lead checked the live Netlify .pck), Pok Ta
  Pok, Netball (9597dfe), Kho Kho (f005432), Floorball, Hurling (c28aa4f), Sepak Takraw (5b7f028): all seven. No CI
  job exports Web; no game reports a Web export made with data/ present.
- **Crowd looks** (Netball's owner: "the crowd isn't real people"; the lead's go for the no-credit option, Meshy fans
  wait on the owner): bake_crowd marks each fan vertex skin, hair (and beard) or legs' clothes (UV.y; by bones, place,
  hue - the face is 3-4 vertices, so skin is the hands' hue, not their RGB; long hair grown from the head's along the
  mesh's edges; the beige-trouser trap closed by brightness), crowd_vat.gdshader recolours them per fan from a
  game's palettes keeping the shading (`WsgCrowd3D.set_looks`, `LOOKS`), and `fan_weights` sets each fan's share
  (fan2 and fan5 are the women). No draw calls, no CPU; nothing changes without the calls. Found: fan2's and fan5's
  long hair was weighted to the spine and so took the shirt's team colour - hair is never shirt now. crowd_test checks
  the parts, hair-not-shirt, set_looks and the weights (0.68 against 0.67). ADOPTING §5.
- **Meshy: spend NO credits** without the owner's own OK (not the lead's alone): the owner's standing rule, relayed
  by Netball 2026-11-02. Balance then 59 (a fan costs 35: preview 20, refine 10, rig 5).
- **Crowd placement, every game (owner's directive via the lead, 2026-11-03)**: M1 + the audit done.
  `WsgCrowdVenue` (crowd_venue.gd): a venue = its play area + sections (strips of rows: seat kinds bench, chair,
  plastic, bleacher, stool, wall, step; standing terrace, floor, rail; barriers); place() gives spots (a seated
  fan's: the floor under the middle of their seat), facings (toward the play's nearest part, <= 50 deg off square),
  seat heights, back room, toe room, obstacles. `WsgCrowd3D.build_venue`: each seat's fan picked by leg fit, sized to
  it (0.86-1.14), hips as far back as the back/step behind allows, toes on the tread; the shins reach down (REACH
  0.08) unless the legs hang (stool, wall: custom.r + 2); getting up they step forward off the seat (stand_fwd per
  fan model). The bake now grounds every frame (the licensed crowd's seated soles were 1-6 cm under the floor,
  standing up to 5 cm over). `WsgCrowdVenue.audit` (hips, soles, inside seats/backs/steps/barriers, facing,
  backwards; placed transforms recorded: a MultiMesh gives none back headless) and `tools/crowd_audit.gd` (contact
  sheet per venue + JSON; vendored). Test grounds (every kind): tests/crowd_venues.gd, crowd_venue_test - all
  1,210 fans pass: hips -0.5..+1.5 cm, soles 0..-0.9 cm (hanging on stools/walls), inside <= 2.3 cm, facing <= 7 deg.
  Next: M2 ripple/lag of heads, M3 WsgCrowdCards (Low), then each game's venues.
- Crowd placement M2 + M3: heads follow the ball in a ripple (ball_lag; each fan between it and the ball). Low:
  `WsgCrowdCards` (crowd_cards.gd, crowd_card.gdshader) - the venue's places as flat cards of the six fans (seated,
  standing, cheering: crowd/cards.png + cards_mask.png - shirt/skin/hair/legs shares - baked by tools/bake_cards.gd
  from the authored crowd), one draw call a venue; sized to the seat (lifted onto stools and wall tops), in front of
  it, turned to the camera at most 35 deg off the fan's facing; get up and cheer with set_excite; team colours,
  per-spot shirts, set_looks. Audited (hips, in front of the seat, facing) in crowd_venue_test and crowd_audit
  (whose sheet now has a Low row a section). ADOPTING 5.1.
- **Hurling's live bug, seated 3D fans "sheared, T-pose arms, far LOD at 5 m"** (the lead's priority, 2026-11-03):
  not a regression and not the bake - it is the light (far) figure (a third of the triangles: ImporterMesh LOD on
  the welded fan) given to every 3D fan past the first 700 by nearness to the focus; a camera near the stand sees
  them metres off. Reproduced in Hurling's own crowd_view with its own bake (worktree /home/user/hurling-wt);
  forcing full figures fixes it. Profiles now all full figures at the same triangles (premium 700 / 1,200 / 2,400;
  budget 150 / 700 / 500); near < all brings the light one back.
- Adoption feedback, 2026-11-03: **Pok Ta Pok** (all 4 venues pass; ships cards) and **Kho Kho** (16 venue/level
  entries pass; audit in its CI) adopted. Fixed from them: cards from the fans' whole textured models (faces; the
  crowd figure's 3-4-vertex faces read as backs) with a face check (skin + detail >= 0.055) - ca57ce7; cards take
  exact shirt RGB and `brightness`; 3D shirts via WsgCrowd3D.shirt_palette (16 greys + 20 hues x 3 sats x 4 values,
  code 1 + index; the old hash code < 1 still decodes for games' cut-outs - Hurling's cut-outs and 3D fans may now
  differ a little in a shirt's tone at their border until it moves to cards) - 6a59b52; getting up steps off the
  seat in the first half (smoothstep 0..0.5; Kho Kho's fan4 in a chair). Kabaddi briefed with venue notes.
  Hurling's 0.20 playtest (toes up, free follow-through, glide) measured on its head with the licensed data in a
  local worktree (/home/user/hurling-wt, never pushed): toes up only in its own moves (falls/lifts to 68 deg), the
  follow-through identical with WSG_OFF (its choreography), side-steps to 5.9 m/s exist - all reported to Hurling.
- Later 2026-11-03: Hurling's FootFlat upstreamed as WsgFootFlat (b073334; Pok Ta Pok's stocky player and judges
  take it, Takraw's 0.28 deg none); card variety and colour-gated recolour (5914b7c, Kho Kho's long-haired cards);
  vendor.sh keeps a game's .import files (b628ab2); bake version checked by the audit, flat rows' toe room, cards'
  optional clap and look poses (5f9c31d, Kabaddi's four). Adopted: Pok Ta Pok 0.6.6, Kho Kho 0.12.0, Sepak Takraw
  0.15.1, Kabaddi 80d7bdf; Hurling synced to 5914b7c and adopting the venues; Floorball and Netball not yet heard.
- Loading overlay (the owner, via the lead: "a loading delay ... users might think the game has frozen"):
  `loading.gd` (WsgLoading.cover/request/step/run/checkpoint/done): up in the tap's own frame, buttons off, work
  held two frames, threaded file load driving the bar, main-thread steps sliced by checkpoint (slice_ms 50), the
  longest slice and frame in a `WSG_LOADING {json}` line (warning over 250 ms), themeable, portrait and landscape,
  spinner in its shader. `tests/loading_test.gd` (a real tap in a 1280x720 SubViewport: the headless window is 64
  px), ADOPTING §5.14.
- WsgLoading v2 (the lead's three inputs and Takraw's measurements):
  - `warm()`/`warm_scene()`: 3D off (disable_3d) from the first step, every look drawn once, a batch a frame, from
    its own camera.
  - `done()` holds until the frames settle.
  - `prewarm()` for the menu.
  - Quick loads close at once.
  - Cold bench (software GL, 66 looks, no shader cache): before, one 48–50 s frame; after, 57–66 covered frames,
    the longest 1.1–1.8 s.
  - Doubling batches after one quick frame merged compiles (2.6 s), so batches now grow only after three quick
    frames in a row.
- 2cd59a7: play_at bright_kinds (a 4 kHz ping at 50 m: a step -16.8 dB, a post 0.0); WsgCrowd3D.build_async /
  build_venue_async (the same crowd, a checkpoint every 64 fans); deep seats: the legs' outline below the seat in
  front of its edge, square to the seat (seat_dir; Kabaddi's dome fan5); sole_tilt on the full mesh.
- WsgSolidProps (the owner's "nobody walks through a table or bench; the ball bounces off"): solid_props.gd (add /
  register / skip; push_out, penetration, free_spot, steer with a per-body memo, move, path; sweep / bounce with
  materials and the floor as a prop; make_bodies; debug_mesh), prop_audit.gd (WsgPropAudit), tools/prop_audit.gd
  (a game's registry: venues() + run(); JSON + close-up sheets; refuses an output inside the project),
  tests/solid_props_test.gd, tests/prop_runs.gd, ADOPTING §5.15. Inventories in from Kho Kho, Pok Ta Pok, Floorball.
- Owner-approved items:
  - **7 (8f688ff): REQUIRED manifest.** check_foundation fails a game's CI without a required commit.
  - **4 (ed3c181): owner notes as permanent tests.** WsgOwnerNote, WsgNoteChecks, the runner and the history guard;
    the foundation's 16 notes all pass.
- **877bcd9: WsgLoading settles a device that is slow but even** (last 6 frames within 20%; Netball's software GL).
- **WsgSim (owner-approved, before item 5): the shared match simulator.**
  - What it is:
    - WsgSimGame adapter, WsgSim runner and generic checks;
    - WsgSimLog (a Logger: script errors), WsgSimInput (human fuzz), WsgSimMenu (menus and saves);
    - tools/sim.gd (batch, replay, determinism, menu, merge, adopt), sim_shard.sh (freeze and crash), rng_lint.sh,
      sim_ci.yml;
    - the demo game tests/sim_demo and the self-test tests/sim_test.gd.
  - Found while building it:
    - Godot's first frames after start are not on the fixed step even with --fixed-fps, so 30 warm-up frames run
      first and a per-frame step check guards it.
    - A rig's rest heights are not its standing bone heights, so foot_slip now takes each foot's lowest point.
    - Demo bugs found by the sim: shooters re-catching their own shots (no goals); a 30 m vertical shot from inside
      the goal; the scenario generator always favouring away; update-order bias (equal sides home 22% / away 47%,
      now 32/44).
  - Measured:
    - nightly 2,000 matches in 422 s on 4 cores (x165); smoke 62 in 25 s;
    - with 6 animated WsgBodies x21;
    - the demo's foot slip with retargeting AI is 7-8.5 cm a step (for item 5's planter work).
    - (The 7-8.5 cm was the clip's, not the drawn feet: WsgSim read poses after the frame. Fixed in 1ef240f.)
- **5 (1ef240f + the world-check commit): the world rules.** docs/WORLD_RULES.md, one entry point
  tools/world_check.gd (wsg_world_check) on a game's res://game/world.gd (WsgWorldGame hooks), WsgWorldRules (feet,
  pose, officials, sounds, loading, joystick, web; props and crowd through the game's own audits). An unwired rule
  fails; an excused one needs the owner's note. tests/world_demo/world.gd passes all; tests/world_check_test.sh shows
  each fault (no overlay, a T-posed player, an official in a player's kit, the planter off, a dulled post, a
  world-fixed stick, a Web preset or pack with licensed data, an unwired game) fails its own rule only. ADOPTING §5.18.
  - Planter (1ef240f): the ball held once down, heel-off over the ball, a step of its own when beyond the leg's reach,
    40 degrees of twist held. Match path worst step (cm) walk 1.1->1.5, jog 2.4->0.3, turned 3.2->0.9, run 2.4->0.2,
    stop 1.2->1.0 (the world rule: 2). With the planter's own contacts 12.1/2.4/6.9/6.3/5.0 -> 2.7/0.3/1.7/0.2/1.0.
  - WsgSim's demo (crude AI: facing snapped to velocity, up to 265 deg/s on a planted foot), 40 seeds, 80 bodies:
    15 matches with a step over 2 cm (2.1-4.6, one 7.0). The ones traced are steep heel strikes in sharp turns: the toe
    7-10 cm up sweeps 2-3 cm while it flattens about the held ankle, then the heel lifts. Not loosened; a heel pivot
    tried for it made the match path worse (walk 2.05) and was dropped.
  - Tried and dropped: easing the toe back on release (kept it low and sliding: walk 3.75).
- **3 (graphics tiers enforced).** WsgFoundation.BUDGETS (frame triangles and draw calls per profile and tier),
  CROWD_AT_TIER and crowd_quality(): WsgCrowd3D never builds more than the player's tier allows (premium Low none,
  budget Low its band, Close only at High; requests over it recorded in over_tier). The world check's `tiers` rule
  plays every mode at Low, Medium and High: the tier never put up, the crowd and full-detail bodies within the tier,
  and with a renderer the frame budget (the demo under xvfb/opengl3: Low 11,730 triangles / 3 calls, Medium and High
  273,454 / 9). An owner-excused mode names its note in tier_exceptions(). The demo's --bad tiers (forces High and the
  Close crowd, as Hurling's practice did) fails at Low and Medium. Crowd tests and notes set High first.
- **1, part 1: the release gate** (tools/release_gate.py; tests/release_gate_test.py; ADOPTING §5.19). Signature
  (apksigner, else the v1/v2/v3 certificates read), version (project.binary vs the release, the file name), licensed
  (mobility/actorcore in the APK, none in the Web build), clean, textures (no non-GPU-compressed one over 2 MB), files
  (non-game types, duplicates over 64 KB), size diff (top 20 grown; no cap); --allow with the owner's note. Kho Kho
  0.12.4-beta's release APK passes every check. Part 2 next: WsgAssetPack (the downloadable High pack).
- **1, part 2: WsgAssetPack** (asset_pack.gd; tests/asset_pack_test.gd with tests/asset_pack_server.py; ADOPTING
  §5.20): the High pack as a public release .pck - follows GitHub's redirect, resumes with Range, SHA-256, mounted
  with load_resource_pack(replace), behind WsgLoading's bar; res://wsg_pack.json written by CI; the gate's --pack
  fails a pack holding licensed data. Found: get_response_headers_as_dictionary() comes back empty on 4.7.2 (parsed
  by hand). Credits for the pack's assets: item 8.
- **8 (common UI)**: addons/wsg_foundation/ui/ - WsgCredits (chunked, never threaded; the pack's, the foundation's
  and Godot's notices), WsgWatchSetup (Watch AI entry and picker) plus WsgSpectator's Skip button and tap-to-skip,
  WsgHaptics (named patterns, "bonus" the double pulse, the setting), WsgSettings and its screen (tier, bus volumes,
  joystick side and size, vibration; user://wsg_settings.cfg), WsgTutorial (prompts once, Skip tips); all themed by
  WsgBroadcastTheme. tests/ui_test.gd. ADOPTING §5.21. Found: a lambda left in a static var corrupts the heap at exit.
- **9 (asset lint)**: WsgAssetLint (textures as the release gate at import, mipmaps warning; lods; licensed files in
  git and the data folder ignored; toe_up from the game's walker; unregistered props from its prop registry);
  tools/asset_lint.gd (CI, ASSET_LINT.md, asset_lint_allow.txt with the owner's note); the editor plugin
  (plugin.cfg, lint_plugin.gd: checks at import, a toast). tests/asset_lint_test.gd plants each fault. ADOPTING §5.22.
  The owner-approved programme (7, 4, WsgSim, 5, 3, 1, 8, 9) is done.
- **Feet at every size (8dc70d9, e5bd515):** the feet rule holds at most 2 cm a step on the hurler scaled 0.85-1.15 (worst
  1.9). Fixes: the locomotor no longer starts a walk mid-stop (it read the body's speed as asked-for); a released toe
  and a step's toe keep their place on the floor. tests/feet_scale_test.gd. Also f151f52: the T/A-pose check uses
  bands and sideways arms (Netball's overhead catches were flagged).
- **Nightly for every game (draft PR #19 to main, branch claude/wsg-nightly-dispatcher):** `.github/workflows/wsg-nightly.yml`
  on main dispatches each game branch's `*-sim.yml` (workflow_dispatch, ref the branch) at 03:43 UTC. Scheduled runs
  fire only from the default branch, so the games' own crons never ran. A game without a sim workflow, or one without
  workflow_dispatch, is skipped with a warning. Today only Kho Kho has one. Remove a branch from GAME_BRANCHES once
  that game is merged into main.
- **Sepak Takraw's frozen fetcher (back and forth in front of a bench):**
  - WsgSim's **no progress** check: moving, but no closer to a target that stays put, for 10 s.
  - The **fetch behind a prop** case (`targeted:fetch_behind_prop`, in every smoke batch). The ball is placed behind
    one of the venue's 3 largest props, and the fetcher must get there in time without going into a prop. It needs
    the game's `WsgSimGame.fetch`; until then the report notes "not wired".
  - WsgSolidProps' **steer-flip warning**: 4 changes of side round one prop in 90 calls, reported under Warnings.
  - The demo's `bug:fetch_dither` is caught by all three.
  - ADOPTING §5.17. The tiers rule now reports triangles left outside start_mode's parent (Hurling's trap; §5.18).
  - The demo smoke's one failure, `extreme#40` out of bounds, predates this change: the previous commit fails it too.
- **Kho Kho's "T-pose" kneelers, Hurling's 6.6 cm lift-to-run slide (2026-11-03):**
  - The 90/90 T-pose was a reading artefact. WsgSim's sampled pose switches off every modifier on three bodies in
    four, the game-pose layer included, so a body in FoundationLink "full" mode shows the rig's rest T. Kho Kho's
    diag_pose read every body; WsgSim reads only the sampled quarter and never flagged a kneel.
  - In the real game the kneeling arms read 13-37 degrees.
  - Pole turns are a designed move. `bodies()` may carry a `pose_excuse` with its reason: counted, not failed.
  - `WsgSimGame.deferred()`: a check put off until a time with the lead's note (warned, not failed).
  - Planter: a foot let go is held across while the planter tells whether the clip lifts it (at most 3 ticks). It
    had eased 7 cm over the ground toward the clip's foot (29f4829's wait). Gliding note 6.6 -> 4.0 (limit 4); feet
    sweep and cadence unchanged.
  - The fetch hook is enforced from 2026-11-04 12:00 UTC (`FETCH_ENFORCED_FROM`; REQUIRED from then).
- **Later on 2026-11-03:**
  - **9c461ca:** a footstep (landed/step) needs the foot to have left the ground. A stance foot let go at reach
    re-planted and fired again; Kho Kho's run cadence was 5.3/s, now 4.41/s on its branch.
  - **b5ba195:** world_check stops and hides each played mode (Kabaddi: over 50 min on software GL).
  - **4dc2e3c:** a mode's freed bodies no longer stop the rules, and a rule's error fails it by name (Hurling and
    Floorball's CI hung until timeout).
  - **63b8d62:** WsgFootFlat keeps a planted toe where it was (Floorball's SoleFlat). Floorball's model: jog
    2.1 -> 0.7. Hurling's gliding note: 4.0 -> 2.8.
  - **Open:**
    - Kho Kho AI slips 2-4 cm, deferred to 2026-11-06 12:00 (repro /home/user/wt-khokho, targeted:fair 101/103);
    - Pok Ta Pok hard stops and pivots (awaiting replays);
    - stop 2.1 cm on Floorball's model.
- **Planter under game AI (due 2026-11-06 12:00; Kho Kho, Floorball refs, Pok Ta Pok, Takraw carry walk):**
  - Reproduced on the foundation's own hero with no game: a straight walk driven every frame, as games do.
    - Feet are read once per frame (the last pose; skeleton_updated fires twice a frame).
    - Worst step: 1.3 m/s 2.6 cm, 1.8 m/s 3.5, 2.2+ m/s about 1.2.
  - The world rule's drive() drives every other frame and reads 1.5 at the walk: optimistic. It will need to drive
    every frame once the planter holds there (that changes the rule's numbers: decide with the lead).
  - Found: landing frames skate the last 2.6-3.6 cm along the ground (contact 0->1 with the foot already under 1 cm).
    Locking at the previous drawn ankle removed those, but the walk still read 2.7 (a slow creep in stance, under 3 mm
    a frame), and 2.2 m/s got worse (a self-step's end toe skating). Reverted.
  - Probes kept in the scratchpad (planter_probes/_brisk.gd, _brisk2.gd).
- **Feet measure, frame by frame (the lead's go, 2026-11-03; REQUIRED from 2026-11-05 12:00 UTC):**
  - `WsgNoteChecks.foot_slip` adds up, each frame a foot is down, the smaller of the heel's and the ball's move. A
    heel-to-toe roll reads ~0; a slide reads in full. The old one took each end's drift since the step began: a roll
    read 1-3 cm that was not there, and the planter off (the clips' own feet) read 2.7 cm at a walk (now 8.0).
  - `tests/foot_slip_test.gd` pins it: a pure roll under 0.5 cm, a planted foot pushed 3 cm (as the toe comes down,
    flat, as the heel lifts) 3 cm or more, the planter off 5 cm or more at 1.3/1.8/2.2/3.0 m/s (8.0-10.7). The old
    measure fails it (roll 0.9, planter off at 1.3 m/s 2.7). Limit: the frame a foot comes down in is its arrival,
    not counted.
  - `WsgWorldRules.drive` drives every frame. It took two frames a step; the hurler's numbers are identical either
    way (the pose advances only inside drive). The earlier note above ("reads 1.5: optimistic") was the measure,
    not the cadence.
  - What the new measure showed, both fixed:
    - The planter's roll over the ball lowered the heel below where it was planted when a stop's clip pitched its
      foot back toe-up; the floor took it back and the toe was dragged 1 cm off its lock and back. The hero's stop
      read 2.3-3.2 cm at every scale; now 0.0 (the roll never goes lower than the foot was held).
    - WsgFootFlat's toe shift came on in the frame the toe touched, the heel already planted: the heel jumped 3.3 cm
      (Hurling's walker: walk 2.6, jog 2.4, jog turned 2.3). Now in full while the planter holds the foot, else by the
      heel's or the toe's height (made in the air): Hurling 1.0 / 0.3 / 1.3. The hero (flat) does not show it even
      with FootFlat forced on (feet_scale_test now runs two scales with it).
  - Every game's walker (world_check --only feet), foundation 5d33d5a9 (old measure) -> this commit, worst slip cm:
    Hurling walk 1.7->1.0, jog 0.4->0.3, turned 1.9->1.3; Floorball walk 1.5->0.8, jog 1.3->0.7, stop 1.5->0.2;
    Kabaddi all <= 0.9 both; Kho Kho walk 2.6 (FAIL) -> 0.6; Netball walk 1.6->0.6, turned 1.1->1.2; Pok Ta Pok walk
    2.1 (FAIL) -> 0.3, jog 0.4->0.7; Takraw walk 1.8->0.3. All pass after.
  - Still open, not measured by either measure: a hard stop from a run lands with the clip snapping the foot back 7-8
    cm in one frame at ground height (the planter plants the frame after; the swing gate reads it as swinging).
  - Owner notes on 4cae13ae: Hurling, Kabaddi, Kho Kho, Pok Ta Pok and Takraw all pass; Netball has no INDEX.json.
    Floorball (head 27a66b6f) fails 3 hand and pose notes (up-close fist 31/519 frames, penalty twist 64°, thumbs
    7497/8779), identically on 5d33d5a9: theirs, not this change. Announced to the lead and the 7 games 13:5x UTC.
- **73abc139:** the ball audit takes an optional per-frame `path` (WsgSimGame.ball's "path";
  WsgPropAudit.ball(pos, r, who, path)), each step swept. Takraw's mall tripod: the chord between frames cut 2.3 cm
  into it, the bounce path never touched it. Pinned in solid_props_test on their numbers.
- **The hard-stop snap (the lead's go, 13:47): 4b1dc42c + 86a3644e, REQUIRED from 2026-11-05 12:00 UTC.**
  - Measured: `foot_slip`'s `skid_cm`, the most a foot flat on the floor (heel and toe within 2 cm, this frame and
    the last) moves in a frame, whatever the swing gate says; the feet rule and WsgSim fail it over 2 cm. The lead's
    literal "within 3 cm" flagged every walk's swing toe (8-12 cm a frame, heel up); at 3 cm a foot still coming down
    read 11 cm. Pinned in foot_slip_test (a snap reads 23 cm, a skimming swing and a roll 0) and feet_scale_test (the
    old planter fails it at every scale: stop 8.7-23.9, walk 3.3-4.5).
  - Fixed in the planter: a foot flat on the floor (2 cm) is planted however fast; a self-step is planted where it
    was drawn down, turned and pitched as drawn until its toe is down; a let-go foot held across eases across over
    `release` when the hold ends (it jumped up to 72 cm in a frame at Hurling's walk start, unmeasured), lifting over
    the floor when the clip's foot is some way off.
  - Every game's walker, old planter -> fixed (skid, cm): Hurling walk 7.4 -> 0.2 (stop 9.8 -> 0.1); Floorball stop
    2.1 -> ok; Kho Kho walk 3.6 -> 0.0; Netball walk 3.8 -> ok; Pok Ta Pok jog turned 13.8 -> ok; Takraw walk 3.7 -> ok.
    All pass; slips unchanged or lower.
- **29212ba4 (the lead, 14:00): the release gate's `newer`**: versionName and versionCode above the APK on the tag
  (read from both manifests; Kabaddi's published: 0.14.7-beta, 47). REQUIRED from 2026-11-04 18:00 UTC.
- **The low-foot jump (the lead, 14:23-14:48): measured, 25 cm, and the stop teleports fixed** (71269a55..68a16daa).
  - Calibration (`tools/feet_calibrate.gd`, every game's walker: walk 1.3, jog 3.5, run 6, sprint 8, cuts at 8 and 6,
    stops from 8 and 6). A low foot's honest move reaches 37 cm a frame (a cut), so plain displacement cannot tell
    a glitch; the jump - the smaller of the change into the frame and out of it - reads 15.4 cm at most honestly. The
    lead chose 25 (1.6x). Flat-foot landings move up to 16.8 cm into the frame they land in (sprinting), so a "flat
    foot moved 2 cm" rule would fail every sprint; the jump covers the glitches (the lead agreed).
  - Planter: a foot down again while still easing or catching up is planted where drawn (it was re-planted a stride
    on: 50-95 cm in a frame); a released foot closes an even share of the gap to the clip's foot each frame the
    release has left, catching up no faster than max(25 cm, the clip's move + 10) a frame.
  - Worst jump, before (13f00e20) -> after (68a16daa), cm: hurler stop from 8 82.5 -> 13.2; Kho Kho 88.1 -> 12.6;
    Netball 73.6 -> 0.0; Floorball 71.4 -> 13.1 (walk start 54.8 -> 3.3, cut 180 29.6 -> 8.6); Pok Ta Pok walk start
    32.9 -> 3.7; Kabaddi cut 180 26.8 -> 6.4; Takraw 28.1 -> 20.9 (its stop clip's own foot); Hurling 20.4 -> 18.2.
  - feet_jump_test: a 56 cm shuffle fails, a sprint swing reads 8, the hurler through the calibration path at most
    14 (the 13f00e20 planter fails it, 82.5).
  - Next: AI seeds. Floorball ref0 targeted:completion 6 - a 44 cm jump in the planter's own step (its path a
    smoothstep to an aim that moves with the body: 30ff2759, an even share a frame, WIP) and a 4.1 cm slip at the
    let-go (unexplained yet; FootFlat's shift fading with the release did not change it).
  - Landed (80420f64), all 7 games' own suites run on it first: Hurling 706/0, Floorball 736/0, Netball 2487/0, Kho
    Kho 714/0, Pok Ta Pok 813/0, Kabaddi all passed, Sepak Takraw clean once its planted-foot check reads the drawn
    heel and toe in skeleton_updated (bone_world read outside it is the clip's pose; its 595bec1 read the clip's toe,
    4.0 cm, on its own pushed 13f00e2 tree too; drawn: 0.4 cm).
- **WsgSim and WsgReplay, three fixes the games traced** (on 80420f64):
  - A prop failure dated by the sim's own frame (WsgPropAudit.frame): it was int(summed frame times x 30), one or two
    frames early for most frames, and a replay stopped there before the crossing - Hurling's "ball through the low
    wall", batch yes, replay no (seed 3: dated 2638, now 2640, replays). sim_test: a shot through the bench at 0.4 s.
  - WsgReplay keeps no skeleton still at its rest pose: a body posed only once the camera sees it was kept at its
    first update and drawn a frame in a T-pose (Hurling's home 13). replay_test.
  - WsgSim reads no pose from a body under an active replay (each frame was read live; Kho Kho's replayed pole turn,
    one arm out by design, read as an A-pose).
- **The 11-06 feet batch (the AI seeds) and the world check under 15 minutes** (the lead and the owner, 2026-11-03).
  - Measure, WsgSim: a body posed every 2nd or 3rd frame read per frame (each sample's frame gap: skid and jump per
    frame, the cut's bound scaled - Kabaddi's officials read three frames as one, 2.7 cm); a planter.reset() a cut,
    not a slide (Hurling's umpires snapped 20-35 cm), reset counts per body; the skid counts only a foot the planter
    holds (WsgFootPlanter.holding - a clip's own low swing before landing, posed every 2nd frame, read 13.3 cm: Pok Ta
    Pok fair#102); no pose read under an active replay.
  - Planter: a foot's own step crosses an even share of what is left each frame (Floorball ref0's 44 cm jump in it);
    a let-go foot lifts over the release's time from its first frame (Sepak Takraw's 7.3 cm flat landing move).
    Tried and dropped: a held foot past its reach stepping (Takraw's stop 20.9 -> 36.5, Pok Ta Pok's walk 3.7 -> 21.3);
    a chase lift off the floor (Takraw's stop -> 37.9).
  - Walkers (jump, cm, 68a16daa -> this): Kabaddi stop from 8 21.7 -> 3.1 (the lead's under-20); Hurling cut 180 12.7
    -> 8.1; Kho Kho cut 180 9.6 -> 4.6; Takraw 20.9 -> 20.9; every feet rule passes; owner notes unchanged.
  - AI seeds (Pok Ta Pok, its game on this machine, pushed -> this): completion#101 ESC_2 jump 33.0 -> clean;
    random#17 COP_2 skid 26.6 -> clean (jump 25.8 stays), VAL_2 skid 13.2 / jump 25.5 -> slip 5.1 (seen now that a
    far body's samples are not cut every frame). fair#102 CHL_1 13.3 skid / 3.2 slip -> clean.
  - Open (calibration-only, the same on 68a16daa): Hurling jog 2 skid 5.5, Netball sprint skid 10.0, Kho Kho jog slip
    4.0; Kabaddi's official whose drawn foot misses its hold by 35 cm (extreme#16: the IK, not the drag); Kho Kho's
    57-60 cm AI jumps; Floorball's refs - for the games' re-smoke on this batch.
  - World check: modes undrawn (Kabaddi 918 -> 17 s, every rule's result the same), tiers the worst of 5 frames with
    no warm-up (633 -> 158 s, the same counts and verdicts), props capped at [1, 30 s], --reuse, --merge (parallel
    jobs), per-rule seconds; a reading near its bound warns; no Web build is N/A. Kabaddi's modes and tiers 1551 ->
    175 s on this machine.
- **Low, what the owner sees (the lead, 2026-11-03 17:53)**: Hurling and Floorball draw the foundation's WsgBody at
  every tier; Netball (HeroBody, its Gait planter), Kho Kho (ModelBody, clip foot locks), Kabaddi (RiggedBody, its
  planter), Sepak Takraw (RealBody, its planter: 35 cm re-plants) draw their own at Low; Pok Ta Pok (WsgToonDriver)
  to answer. WsgWorldGame.walker_low() and the feet_low rule (deferred to 2026-11-08 12:00 UTC, then failed; unwired
  reads DEFERRED, never skipped); WsgSim's "feet" callable for a body the game draws; WsgFootPlanter.bone_map - the
  planter on a game's own skeleton (planter_bone_map_test). ADOPTING 5.21.
- **The planter under game AI: Floorball's referees and Kho Kho's 57-60 cm jumps (the lead, 2026-11-03 18:12)**
  (7def933a). Reproduced on the games' own trees with the deferrals lifted (WSG_NOW past 11-06):
  - Floorball extreme#2 ref0 slide 3.6 / jump 27.3 -> clean; completion#6 slide 3.4 -> clean; random#3 ref1 8 jumps
    over 25 cm (worst 51.2, hidden by the deferral: the match line read "ok") -> clean.
  - Kho Kho #103: scoring ump_b 3.2, defender 2 4.1 / 27.6 -> slide 2.1; dream defender 9 55.7, defender 6 48.5 /
    30.6 skid -> slide 2.5; fair, fouls -> slides 2.1. No jump or skid left.
  - Causes: a landing planted a 60 Hz tick after the rule reads it down; a clip change carrying a landing foot 28-40
    cm; the planter's own step dumping 28-54 cm in its last tick or swinging 33 cm round; a foot left 1.5 legs
    behind a 7 m/s stop re-planted 66-85 cm away (Kho Kho's jumps); a let-go foot eased along the floor after its hold
    ran out (7.6-30.6 cm skids; Sepak Takraw's flat let-go). Tried and dropped: planting every landing where drawn
    (new 3-4 cm slides at reach), a toe aim that lifts (Takraw's walker toes 0.5 cm up, a 14.2 cm skid), ending a
    step's move at 0.8 (Kho Kho's running cadence 4.75 -> 5.0 steps a second, its suite's check).
  - Walkers (the feet rule): Kabaddi's stop 20.7 -> 8.9 cm (my earlier "3.1" was feet_calibrate's stop from 8, not
    the rule's: corrected to the lead); the other six unchanged. Every game's feet rule, owner notes (Floorball's 3
    pre-existing on my older copy) and suite pass; the foundation's tests pass.
  - Left: planted slides 2.1-2.5 cm (a locked toe creeping 1 mm a frame over an 80-frame ball-of-foot stance at the
    leg's reach) - the lead: Floorball and Kho Kho defer only "planted slip" up to 2.5 cm until 2026-11-13 12:00 UTC,
    jumps and skids enforced from 11-06 12:00; the fix before 11-13 with a targeted test.
  - Also: WsgFootPlanter.bone_prefix and contact_fn (Takraw's Low); WsgSim cuts a run at a body unposed for over 3
    frames (Hurling's metre "slides" - not reproduced in the demo) and at a "feet" callable returning nothing
    (Takraw's Low replay); "planted slip" deferral with a bound; ADOPTING 5.19 publishes in place (the token is
    refused new tags since about 17:00) with the gate skipping its own commit's build (Sepak Takraw's race).
  - World check on CI: Kabaddi 829 s, Takraw 574, Floorball 332 (--reuse), Kho Kho 649 locally - all under 15 min.
- **Planted slides, first round (task before 2026-11-13 12:00; 055f39f8)**: reproduced on Sepak Takraw 0.15.16 (its
  deferrals lifted, `--input`):
  - extreme#14 player 7.0 + official 2.4 -> clean; random#21 7.0 + 3.6 -> clean. Of its other listed seeds,
    extreme#34, #24, #20, random#5, #7, #25, scoring#103, human#103 clean; completion#103 6.1 + official 5.6 -> 4.2;
    extreme#4's official 5.8 (the same on 582bc163: not from this change; 4.9 on the game's older build).
  - Causes: a planter switched off under the game's whole pose (`active = false`) came back on with its old contacts
    and last-drawn ankles - the feet planted 1.5 m behind and let go, sliding with the pose fading out; the planter's
    own step skimmed a toe-down foot over the floor in its last frames (3-4 cm a frame).
  - Fixes: `reset()` forgets what it drew; a planter not run for over 3 frames starts afresh; a step keeps its toe
    3.5 cm up until it lands (STEP_CLEAR). tests/planter_restart_test.gd (fails on 582bc163).
  - WsgSim: feet failures name the foot and frames of the worst reading, and the failure's frame is that one (it was
    the match's last - Kabaddi's 26 cm jump, Hurling's 39.6 cm skid had nothing to go on); the written replay command
    carries `--input`.
  - Dropped: a rest-height override for Takraw's own Low body (their bench: walk 19.3 cm, glide 41%).
  - Left: Takraw extreme#4 official 5.8, completion#103 4.2; Kabaddi Medium, Floorball extreme#3/#6, Kho Kho toe
    creep, Hurling 2.6-8.4 slides and 29-40 cm flat skids (its failure files in hand), Pok Ta Pok LLA_1 25.1 jump.
- **Planted slides, second round (Kabaddi Medium)**: a planter run's time is every tick's since its last run (a game
  ticking without drawing read its feet too fast); a landing foot touches at 4 cm over its floor (TOUCH_H, never less
  on a body scaled down) - over the feet rule's 3 cm, whose ankle floor (where a heel-up stance plants it) is higher
  than the planter's rest floor: the rule read landings down a draw before the planter planted them. Kabaddi 328d7dd,
  --input: of 12 slides, knockout#103 OFFICIAL_1 7.6, extreme#14 IND_8 4.6, extreme#16 OFFICIAL_2 #18 4.4, extreme#44
  POL_10 3.5 and OFFICIAL_2 4.1, random#39 KEN_9 4.5, random#41 PUN_9 6.4 -> clean. Left: POL_11 6.0, OFFICIAL_2 #45
  8.3, IND_7 4.6, OFFICIAL_1 3.8, PUN_9 5.6; CI's IND_11 31.4 jump and OFFICIAL_0 14.9 sideways start (not reproduced
  locally). All 7 suites, feet rules and owner notes as before (Floorball's 3 old stick notes); cadence unchanged.
- **Planted slides, third round (Kabaddi's sidestep, Kho Kho's defender jumps, Kabaddi's Low walk)**:
  - A let-go foot the clip stands down a step off where it is held steps there (Kabaddi extreme#10 OFFICIAL_0 14.9
    cm, handed back into a sidestep -> clean). tests/sidestep_test.gd: 2 m/s at 74 degrees off facing, posed every
    frame or every 3rd, handed back at speed (the lead: Kabaddi keeps its 1 m/s cap; the planter passes on its own).
  - A released foot's catch-up changes its move by at most CHASE_OVER over the clip's own change, once it moves over
    25 cm a frame (Kho Kho: a defender starting hard, the ease's last frame took a 40 cm lead at once): of Kho Kho's 9
    defender jumps (25-34 cm) 7 gone; extreme#34 27.1 and fouls#101 25.5 left (unchanged: another cause).
  - The 4 cm touch only for a foot already slow (toe and ankle): a40a95e's Low walk jump 2.8 -> 12.6 cm on Kabaddi's
    walker (the lead's gate) -> 2.8, slip 0.5 (0.14.16: 0.9); Kabaddi extreme#42's 16.0 cm skid -> clean.
  - WsgSim: --kinds is honoured on every tenth seed ("--kinds extreme --from 10" ran a targeted case: smoke failures
    on seeds 10, 20... could not be run again).
  - All 7 suites, feet rules, owner notes as before (Floorball's 3 old stick notes); foundation tests pass.
  - Fade handback (a game's whole pose fading out under the capture): keep_pose and enabled=false both leave those
    frames unmeasured by WsgSim - the planter is to handle it measured (next).
- **Correction to 3b700012 (four regressions the games found)**: 3b700012 was checked without feet_low; Kho Kho's Low
  body (its contact_fn) regressed (walk 6.1, stop 7.5 cm), Takraw's Low officials (contact_fn) and completion#103,
  Kabaddi's IND_11 jump came back on CI, Floorball extreme#3 gained a 26.6 cm jump. Fixed:
  - the let-go step: never under a game's contact rule; only on a body moving 0.5-2.5 m/s and a step's way off
    (2-30 cm) - a nearly still referee stepped a stride's way, and his sprint's next strides jumped (Floorball);
  - the release rate limit only while the body speeds up over 4 m/s^2 across 0.2 s (Kho Kho's stop and walk);
  - the 3-4 cm touch band needs only a slow ankle (completion#103 clean again; Kabaddi's Low gate holds).
  Measured: Kho Kho Low = its a40a95e figures; Kabaddi Low = 0.14.16's; Floorball extreme#3 no jump; Kabaddi
  extreme#10 clean, extreme#16 on 0.14.17 clean locally (IND_11's jump was CI-only); Takraw completion#103 clean,
  Low officials not affected by these paths (contact_fn) - Takraw to confirm with its probe; Kho Kho extreme#28 jump
  stays fixed. Pok Ta Pok's collisions#101 44.0 / fair#101 45.7 jumps read the same on a40a95e: older, not from this.
  The pre-push check now runs feet_low on every game.
  - 31f60da3: Takraw's probe found its Low officials slipping more (skids >2 cm 3 -> 5, p90 4.7 -> 6.0): the release
    rate limit fired on their dodge starts. The rate limit is now off under a game's contact rule too. Confirmed by the
    games: Takraw's probe dumps (seeds 7, 11) byte-identical to a40a95e, completion#103 / extreme#14 / random#21 /
    extreme#20 clean; Kho Kho Low feet_low = a40a95e. All four regressions cleared (lead told 2026-11-04).
    Still open, older: Takraw extreme#4 official 5.8; Kho Kho extreme#34 / fouls#101 jumps; Kabaddi OFFICIAL_2 8.3.
- **b91fadce + fd879f98: two scale-shrink faults from 9ad1c8ab/3b700012 (Kho Kho's smoke on 0.12.12, Kabaddi random#13)**:
  - the 3-4 cm touch band wanted a slow ankle: a standing referee's idle hovered a foot 3.8 cm up (toe slow), never
    planted, drifting 9.2 cm (Kho Kho extreme#28). A body under 0.5 m/s takes a slow toe or flat foot there again; the
    3 cm band never shrinks under 3 cm (defenders at 0.95: 3.2 cm). Test: planter_restart_test's hovering foot.
  - the release rate limit's 25 cm threshold shrank with body scale: on BAN_5 (under 0.95) a 23.8 cm catch-up was held
    back and snapped, a 26.6 cm jump (Kabaddi random#13 on 0.14.19). Now 25 cm or more.
  - Measured on every game's current head (the bench copies were stale; all refreshed; suites at each CI's fps): all 7
    suites 0 failures, owner notes PASS, feet_low PASS in 6 (Pok Ta Pok's own Low toon bodies fail as deferred to 11-08,
    the same on its shipped foundation - WsgToonDriver task). Kho Kho smoke (--smoke --input, 81 matches, 0 failed) on
    9406eac: slides >2.5 21 -> 13 against CI on 31f60da; shard 0 side by side with a40a95e and 31f60da: nothing new,
    extreme#28 ref 7.3 / hd10 3.2, #10, #12, #34 slides gone, and a40a95e's extreme#28 33.1 / #42 29.7 jumps stay gone.
    Older, still open: extreme#16 (ump_a 35.9 jump in the smoke, 6.2/6.7 slides), dream#103 9.3, dream#101 ump_b 6.6-7.4,
    extreme#44 4.5, human#103 4.3; Kho Kho's 5 CI jumps (collisions#101 31.0, random#29 29.9, extreme#34 27.1,
    fouls#101 25.5, dream#101 25.2).
- **706e3a6d: the planter's metre tolerances by the body's size, not the skeleton's world scale (rigs not in metres)**:
  Sepak Takraw's RealBody sits under a 0.01 node (rests in cm): its skeleton's world scale 0.0101 made every metre
  tolerance 100 times too small and a standing foot was never planted. The planter finds the rig's unit from the leg's
  rest length (a power of ten; unit_scale overrides) and scales its tolerances by sc / unit; rest heights keep sc.
  planter_restart_test runs every case on a cm copy of its rig too (on the old planter: a standing foot never planted).
  Measured on Takraw c5ac572 (sim, no deferrals, --input) - officials planted/flat/jump cm, before -> after: random#1
  16.9/8.5/0 -> 0/0/0; extreme#28 37.6/30.1/30.0 -> 0/3.8/0; #30 7.4/7.3/0 -> 0; #44 10.3/8.3/0 -> 3.2/0/0; #48
  38.0/22.8/0 -> 0. Takraw's probe (seeds 7, 11): officials skids >2 cm 3 -> 0, p90 4.7 -> 0.2 (one jump >25 both,
  41.1 now: Takraw's pose throws a stepping official's foot 19-32 cm a frame - Takraw gating its contact_fn); players on
  the planter (Takraw's wsg modes, its production flag) jumps >25 / skids >2 / p90: own 9/11/2.3, wsg 2/0/0.4, wsgown
  0/5/0.2 - the switch is the lead's call. Other games: suites, notes, feet as before; Low bodies built from a game's
  own glb also gain (Kho Kho Low walk 1.5 -> 0.4 cm, jump 8.6 -> 4.9; Takraw Low standing 1.3 -> 0.7).
