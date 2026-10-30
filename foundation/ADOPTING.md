# Adopting the shared foundation (one task per game)

The foundation draws your players, officials and crowd with one rig, motion-capture locomotion and a 3D crowd,
while **your game keeps everything it already does**: your player code still poses your own 17-bone body every frame
(swings, catches, dives, signals), still measures off it (where the stick head is, where the hands are), and the
foundation draws a new body that runs on mocap and takes your moves from your body. Hurling Heroes is the pilot:
`claude/hurling-foundation-pilot` shows every change below in a real game (search it for `FoundationLink`).

Kho-kho is the exception (it has a 23-bone Mixamo body with an AnimationPlayer, no 17-bone pose): skip step 4's
legacy pose and drive `WsgBody` directly; ask the foundation session.

## 0. What you get, and what stays

Your game is made for one class of phone, and the foundation spends what that class can pay (`WsgFoundation`, step
0.5 below):

| | premium (Hurling, Floorball, Netball) | budget (Kabaddi, Kho Kho, Sepak Takraw, Pok Ta Pok) |
|---|---|---|
| renderer | Mobile (Vulkan), GL Compatibility as the fallback | GL Compatibility |
| first start (the phone decides) | weak phone Low, ordinary phone Medium, flagship High | weak phone Low, ordinary phone Low, flagship High |
| players and officials | the rig and mocap, every body in full detail (Low: the light mesh) | the rig and mocap; on Low and Medium full detail (helpers, fingers, full mesh) on the 6 bodies nearest the camera, the light mesh and plain joints on the rest; on High every body in full |
| crowd, Low | your billboards (unchanged) | your billboards (unchanged) |
| crowd, Medium | 3D fans near the action (400 full + 800 light), billboards beyond | 150 3D fans near the action, billboards beyond |
| crowd, High | 3D fans (700 full + 1,300 light), billboards beyond | 3D fans (400 full + 800 light), billboards beyond |
| a close mode (a practice, a shoot-out) | 3,000 3D fans behind that goal (2,000 full) | 600 (400 full) |

A build without the licensed data (a fork, a computer without access) is exactly your game as it is today.

## 0.5 Your profile, your phones' starting tier, your renderer

In your boot (an autoload's `_ready`, before anything is built):
```gdscript
WsgFoundation.profile = "budget"                    # or "premium"
if settings.graphics < 0:                           # the first run: the player has not chosen
	settings.graphics = WsgFoundation.starting_tier()   # the phone decides: weak Low, flagship High, else your default
WsgFoundation.tier = settings.graphics              # and again whenever the player changes it
```
The player's own choice in Settings always wins, and every tier is offered: a flagship running a budget game gets
High (still on GL Compatibility). `WsgFoundation.device_class()` says
which phones are weak (under 4.5 GB, or a Galaxy A0x/A1x-class GPU - Mali-G5x/G6x, Adreno 5xx and 61x, PowerVR:
a Galaxy A16 is here) and which are flagships (6 GB and Adreno 640+, Mali-G710+, Immortalis, Xclipse); it is what
Hurling learnt from its players' phones.

A premium (Vulkan) game also, in project.godot: `rendering/rendering_device/fallback_to_opengl3=true` (a phone that
cannot start Vulkan gets OpenGL) and `application/config/project_settings_override="user://renderer.cfg"`; and in the
boot `WsgFoundation.guard_renderer()` - a phone on the blocklists, or whose last Vulkan start crashed before the home
screen, starts on GL Compatibility from then on - with `WsgFoundation.boot_ok()` once the home screen is up. Block
phones of your own: `WsgFoundation.block_vulkan("sm-s92")` (a model name: Kabaddi's Galaxy S24 crash) or a GPU name.
(Hurling has had all this since 0.11: `Ultra.boot`; the foundation's is the same, for the other games.)

A budget game draws on GL Compatibility from project.godot (`renderer/rendering_method="gl_compatibility"`, and
`.mobile` the same) and every half second gives the foundation its bodies: `WsgFoundation.rank_detail(bodies,
camera_position)` (the pilot's `match.gd` `_rank_detail`; a premium game may call it too, it keeps all in full).

## 1. Bring the addon in

```
git fetch origin claude/shared-foundation
git checkout origin/claude/shared-foundation -- foundation
foundation/tools/vendor.sh <your-game-dir>        # e.g. netball-game
git rm -r --cached foundation && rm -rf foundation  # keep only what vendor.sh copied
```
This puts `addons/wsg_foundation/` (code, shaders, the authored crowd) and `tools/wsg/` (bake and fetch scripts,
the crowd's fan models) in your game, and adds `addons/wsg_foundation/data/` to your `.gitignore`. Re-run it to
update; `addons/wsg_foundation/VERSION` says which foundation commit you have.

## 2. The licensed data in CI

In your `.github/workflows/<game>-android.yml`, after "Put Godot on PATH" and before "Import project":
```yaml
      # The shared foundation's licensed animation, from the private assets repository with a read-only token,
      # baked into addons/wsg_foundation/data/ (git-ignored) and shipped only inside the APK. Without the secret the
      # game builds on its own animation.
      - name: Licensed animation (the private assets, baked for this build)
        env:
          ASSETS_REPO_TOKEN: ${{ secrets.ASSETS_REPO_TOKEN }}
        run: sh ${PROJECT_DIR}/tools/wsg/fetch_assets.sh
```
It adds about 6 minutes (download 620 MB, import, bake). The secret is the owner's to make (step 6). Locally:
`sh tools/wsg/fetch_assets.sh` with your own `gh` login (it needs read access to the private repository).
**Never commit `addons/wsg_foundation/data/`, never upload it anywhere, never put it in a cache or an artifact.**
Check your workflow's publish steps only run on your own branch (Hurling's ran on every branch: see the pilot).

## 3. Your characters on the rig

Your players' and officials' meshes are probably baked on the 17 bones already (`assets/...*.res` + a json with
"offsets"). For each:
```
godot --headless --path <game> -s tools/wsg/toonbody_to_scene.gd -- res://assets/player/hero_hi.res res://assets/player/hero.json /tmp/hero.scn
tools/wsg/bake_character.sh /tmp/hero.scn assets/foundation hero 6000 2000
```
or straight from a rigged model (Mixamo names, a Meshy auto-rig, a Mixamo or ActorCore character):
`tools/wsg/bake_character.sh model.glb assets/foundation hero`. It writes `hero_hi.res`, `hero_lo.res`, `hero_rig.json`
(the owner's models, not licensed: commit them). It finds the fingers, flattens feet modelled pitched up, spreads the
limb weights over the twist and joint helpers. Check one with
`xvfb-run -a godot --path <foundation> --rendering-driver opengl3 -s tests/pose_view.gd -- <dir> hero <albedo.jpg> out.png`
and run the rig test on it: `godot --headless --path <foundation> -s tests/rig_test.gd -- <dir> hero` (it fails on
candy-wrap, collapsing joints, toes up, a hand that cannot close, loose clothes that hang from an arm held out or
rise with the arms up; with a long coat it may fail at the knees and elbows - tell the foundation session).

Loose clothes (a coat, a jacket) modelled arms-down: posed into the rig's T they stretch from the side into the sleeve
(a wing) and the side lifts with a raised arm. Fix both, then make the light mesh again from the fixed one:
```
godot --headless --path <game> -s tools/wsg/cloth_drape.gd -- res://assets/foundation umpire          # the webbing
godot --headless --path <game> -s tools/wsg/cloth_weights.gd -- res://assets/foundation umpire res://assets/foundation/hero_hi.res
tools/wsg/blender/make_lod.sh <game> res://assets/foundation/umpire_hi.res assets/foundation/umpire_lo.res 1600
```
(cloth_weights takes the weights of a well-skinned body in the same T - your player - for everything outside a
sleeve.) A garment whose sleeves are fused into its body (a generated model with the arms at the sides) cannot be
fixed this way: generate it again in an A-pose.

**Clean light meshes**: `tools/wsg/blender/make_lod.sh <game> res://.../hero_hi.res .../hero_lo.res 2000` replaces the
cut bake_character makes with Blender's (a quarter of the surface error; tools/blender/README.md).

Your material keeps working: the vertex colour holds the rest position and the below-knee flag as your games' kit
shaders expect, and the UVs are your mesh's own.

## 4. The link (the only code change in your player)

Copy `game/foundation_link.gd` from the pilot branch and adjust its few game-specific lines (marked below):
```gdscript
# player.gd
var link: FoundationLink

func _ready() -> void:
	...                                  # after your body is added
	if FoundationLink.enabled():
		link = FoundationLink.new(self, body)
		add_child(link)

func animate(now: float) -> void:
	...
	body.apply(p)                        # your pose, as before
	if link:
		link.update(now)                 # the foundation draws it
```
`FoundationLink.update` reads, per frame: your player's `vel`, `want_vel` (the velocity it is steering to: a sharp
change of it makes a cut, and it picks the walk, jog or run start and stop), `yaw` (where it faces: keep facing away
from the way it moves for backpedals and side-steps), and `action` (a move of your own → your pose on the whole body;
carrying or soloing → your arms, the mocap legs; nothing → the mocap). Game-specific lines: which actions are
"carrying" (`CARRY`), the stick (Hurling draws its hurley in the new hand: copy `_place_stick` for your stick or ball),
and the grip radius (`body.grip("Right", r)`).

**A hand that holds something** (a hurley, a stick, a ball) must be where your body has it, not just turned like it:
the mocap's chest leans and twists differently from yours, and turns copied onto it moved Hurling's hurley hand by
up to 40 cm and 130 degrees. Put that arm in body space each frame:
`legacy.body_pose = reader.body_space(["RightShoulder", "RightArm", "RightForeArm", "RightHand"])`, with
`legacy.arms = reader` so that arm is made anatomical under the mocap's chest. And place anything
drawn in the hand when the skeleton has its final pose (`body.posed.connect(...)`): during the frame Godot reports
bones without their modifiers (the layer, the grip).

**A stick or ball held close up** (a practice, a shoot-out): close the hand on the handle as you draw it, not on
the rig's own palm line: `body.grip("Right", handle_radius, 1.0, [point, direction])` (the handle's axis in the hand's
rest, the joints' space; the pilot's `_line_r`), and the fingers curl till they touch it, the thumb opening or lying
along it if it must. Mark that hand held (`reader.held = {"Right": true}`): its turn stays yours exactly. A second hand
on the handle (Hurling's top hand in a swing): `legacy.hold = {"Left": ["RightHand", the hand in the right hand's
frame, weight, the handle's direction there, the grip point in the left hand]}` - the arm reaches it (two-bone IK),
slides along the handle to where it can reach, rolls round it to spare the wrist. Take hold at once and let go
slowly (`_two_hands` in the pilot): a hand eased half way onto a handle goes through it.
The free hand kept off the handle (a runner's swinging fist, from the motion capture, went through it): `legacy.clear
= {"Left": ["RightHand", a point on the handle's axis and its direction in the right hand's frame, half its length,
its radius]}` - a fist that would meet it is moved straight off it, its turn kept (not while that hand is held).

Your arms are rebuilt from where you put the hands (`WsgLegacyPose.sound_arm`): 17-bone poses often bend an elbow
backwards or turn the upper arm so the elbow points where no elbow can (Hurling's hurley arm does, most of the time),
which a toon mesh hides but the rig's hinge cannot follow. The hand stays where yours is; the elbow bends forward and
points at most 95 degrees from the way an arm in that place bends, and the hand turns at most 95 degrees about the
forearm (a held hand: the arm swivels to keep it so; a free one gives a little). The pilot's `tests/elbow_audit.gd` plays a whole
match (and `-- practice`, `-- shootout`: every swing close up) and fails on any elbow bent backwards, pointing the
wrong way, or straightened against your pose, a wrist wrung past 110 degrees, or a finger more than 5 mm into the
handle: copy it.

Your own fixes for your old mesh (Hurling's officials had arm twists and a foot pitch) must be taken back out:
`reader.undo` (see the pilot). Footstep sounds: `link.loco.step.connect(func(foot): ...)`.

## 5. The crowd

Where you build your billboard crowd (your `Crowd.build(spots, ...)`):
```gdscript
if int(Game.settings.graphics) > Game.GFX_LOW and WsgCrowd3D.available():
	crowd3d = WsgCrowd3D.new()
	add_child(crowd3d)
	var facings := spots.map(func(p): return Crowd.facing_at(p))
	var used := crowd3d.build(spots, facings, density, seed, seated, int(Game.settings.graphics), focus)
	crowd3d.set_teams(home_colour, away_colour)
	# your billboards: every spot not in used
```
**Make the two crowds one crowd** (Hurling's Stadium.build_crowd): decide each spot's shirt once (a Color a spot, by
the spot: your county colours and anything else, as your billboards do) and give the same array to both -
`crowd3d.build(..., room, shirts, lights)` and your billboards (`WsgCrowd3D.shirt_code(colour)` is the code to put
in their shader, decoded `fract(code * vec3(7.13, 3.77, 5.31))`, 30% greyed, times 0.9). A fan then keeps their
shirt when the crowd is built again round another focus, and the line where the 3D fans meet the cut-outs goes.
`WsgCrowd3D.set_sun(to_sun)`: the fans are lit as the games light their people (a cel light, not the scene's: no
sky colour cast, the same on every renderer) and written to the screen as the cut-outs write theirs (colour^2.2).
`lights`: each seat's baked light (`WsgLightBake.probes(mesh, base, spots.size())`, after a bake with "probes": the
fans' heads) - under a roof darker; give it to your billboards too. Measured on Hurling's main stand: mean colour
3D 0.39 0.33 0.33 against cut-outs 0.37 0.33 0.33, luma 0.34 both, saturation 0.31 both (before: 3D blue-grey,
0.37 0.38 0.44, saturation 0.26 against 0.34).
- `seated`: true, false, one bool per spot, or one number per spot: the seat's height over the feet (m; 0 for a
  terrace, where they stand; true means 0.44). A spot is the fan's feet; each seated fan is lifted so the seat of
  their trousers is on the seat, never in it. Give the stand seats to sit on (Hurling: a bench 0.40 m high and
  0.35 m deep along the back of each step).
- `room` (after `focus`): how far behind the feet the step behind (or a back wall) rises above the seat, one number
  or one per spot (INF: it does not). A fan who would sit back into it comes forward.
- `focus`: where the camera mostly looks (the 3D fans go nearest it). Build again when that changes: a close mode
  at one goal (a practice, a shoot-out) builds with `quality` 3 (Close) behind that goal. How many fans each tier
  draws is the profile's (`WsgFoundation.crowd_budget`).
- In your `Crowd.set_excite(k)`: also `WsgCrowd3D.set_excite(k)`; in `Crowd.set_light(k)`: `WsgCrowd3D.set_light(k)`.
- Each frame: `WsgCrowd3D.set_tension(building_pressure)` (the keen ones get up before the score) and
  `crowd3d.watch_ball(ball_position)`.
- Rhythmic clapping playing: `crowd3d.clap(claps_per_second, unison_0_to_1, seconds)` (Kabaddi has these numbers).

## 5.5 Baked light on your stadium (GL Compatibility; Low and Medium)

If you build your arena in code (Hurling's `Geo`: each quad its own four vertices), its stands are lit per vertex
with no shadows on the cheaper tiers. Bake their light once per arena and time of day:

1. A small scene (Hurling's `tools/env/bake_light.gd`) builds each arena as the game does at Medium and calls
   `WsgLightBake.export(structure_mesh, {"sun_dir", "sun_colour", "sun_energy", "sky_colour", "sky_energy",
   "ground": [x0, z0, x1, z1, y], "size": 2048, "scale": 2.0}, out_dir/<arena>_<time>)` with the sun and ambient
   light it actually sets.
2. `blender -b --python tools/wsg/blender/bake_light.py -- --base out_dir/<arena>_<time> --samples 64` for each
   (Hurling: `tools/env/bake_light.sh` does both and copies the maps to assets/env/light). About 2 minutes each.
3. Import the PNGs VRAM-compressed (mode 2), no mipmaps.
4. At run time, after building the arena, when the tier has no real-time shadows:
   `var lm := WsgLightBake.load_for(structure.mesh, "res://assets/env/light/%s_%s" % [arena, time])` - empty if
   there is none or the geometry changed since (bake again) - then `structure.mesh = lm.mesh` and
   `structure.material_override = WsgLightBake.material(lm)`. `lm.ground` is the shadow on the ground (the light as
   a share of open ground's, seen from above over `lm.ground_rect`): multiply your grass by it.

Cost: about 2 MB of video memory per arena (the 2048 map, compressed) and a cheaper shader than per-vertex lighting.

## 6. What the owner does once (all games share it)

The token: GitHub → your avatar → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** →
Generate new token. Name "assets read for CI"; Resource owner **joshnason8-lab**; Expiration up to a year (note the
date: builds fall back to the old animation when it expires); Repository access → **Only select repositories** →
`world-stage-games-assets`; Permissions → Repository permissions → **Contents: Read-only** (Metadata: Read-only comes
with it); nothing else. Generate, copy it. Then in **ghost-kit-pages** → Settings → Secrets and variables → Actions →
New repository secret: name `ASSETS_REPO_TOKEN`, paste, Add secret. One secret serves every game's workflow.

## 7. Check before you push

```
godot --headless --path <game> res://tests/compile_check.tscn     # or your compile check
<your test runner>                                                # nothing of yours should change
```
and look at it: a run, a stop, a backpedal, your signature move, the crowd at a score. The foundation's own tests
(`foundation/tools/run_tests.sh` on its branch) cover the rig, the locomotion's foot slide, the crowd and officials.
