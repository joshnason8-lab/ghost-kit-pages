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
| crowd, Medium | 700 3D fans near the action, cards beyond | 150 3D fans near the action, cards beyond |
| crowd, High | 1,200 3D fans, cards beyond | 700 3D fans, cards beyond |
| a close mode (a practice, a shoot-out) | 2,400 3D fans behind that goal | 500 |

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
camera_position)` (the pilot's `match.gd` `_rank_detail`; a premium game too: its nearest 8, 14 and 22 in full
detail on Low, Medium and High - every body in full cost the CPU the same on Low as on High).

**"Lower the graphics by itself"**: `WsgAutoTier` watches your frames in play and says when to step down - within a
few seconds of sustained stutter, slow on average or hitching (3 frames in 1.5 s over 2.5 times the middle one and
45 ms, two such windows running). Apply the step at once, everything your tiers build (the pilot's
`Match.lower_graphics` and `Stadium.apply_graphics`: the setting, the picture, the sun's shadows, the sky, the crowd
built again, the flags, the men's own shadows, the bodies' detail), then `reset()`. Hurling's first try only watched
the first ten seconds, only the average, and only lowered the picture's resolution: the owner's High stuttered on.

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
**The skeleton's modifiers run when you say** (`body.set_manual(true)` once, `body.advance(dt)` at the end of
each update): a far player your game poses every second or third frame then pays for his pose layers, planter,
grips and helpers only then, and shows what they made of him in between. Every frame, they cost a phone's CPU more
than all the rest of Hurling's match (38 bodies: 8 ms a frame on a desktop, 2.0 without the foundation; 5.4 with this,
3.0 on Low). Pose your far players on frames of their own, not all on the same one (the pilot's `Player._lod_skip`
starts at each man's own count), and anything drawn in a hand (a stick, a flag) a child of the body, so it moves
with him between those frames.

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

**Your crowd's people** (no draw calls, no CPU: all in the crowd's shader). The six shared fans are fan2 and fan5
(women), fan, fan3 (older), fan4 and fan6 (men). Two calls make them many people and your sport's crowd:
```gdscript
crowd3d.fan_weights = {"fan2": 4.0, "fan5": 4.0}     # before build(): how often each is picked (Netball: mostly women)
crowd3d.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
```
`set_looks(skin, hair, legs)` gives each fan their own skin tone, hair colour (a beard with it) and trousers, skirt or
shorts, picked from your lists (Colors, sRGB, dark to light, up to 8 each); the fan's own shading is kept. A darker
skin mostly gets the darker half of the hair list. `WsgCrowd3D.LOOKS` is a broad set: give your own lists for your
crowd (Kabaddi's or Kho Kho's mostly darker skin and black hair; Netball's more fair and blonde). An empty list keeps
that part as made; never calling either leaves the crowd exactly as it was. Shirts are unchanged (`set_teams`,
`shirts`). The parts are marked by `bake_crowd.gd` (each vertex skin, hair or legs, by its bones, place and colour)
in the committed crowd and in your licensed one when `tools/wsg/fetch_assets.sh` bakes it: **run fetch_assets again
after the sync** (a crowd baked before has no parts, and the looks then do nothing). Since this bake, long hair down
a fan's back (fan2's, fan5's) no longer takes the shirt's team colour.

**Flags in the stands** (`WsgFlags`): `flags.build([[spot, facing, first colour, second colour], ...])` - fans
holding a two-colour flag, flying harder with the crowd's excitement (WsgCrowd3D's: nothing more to call), two draw
calls for all of them; `WsgFlags.count_for(want)` keeps a budget phone to half and none on its Low. Hurling puts
eight at each end behind the goals, in that end's county colours, and leans those ends' shirts to it (Stadium._shirts).

Your fans' feet: `bake_crowd.gd` measures each fan's soles on its mesh and turns a foot made pitched up (toes to
the sky, as Meshy's officials were) down about the ankle till only a shoe's toe spring is left, before the bake;
it prints each foot's pitch. (Five of the six shared fans were 10 to 36 degrees up.)

## 5.1 Your venues' crowds: WsgCrowdVenue (every game, every venue)

The owner's rule: in every venue every fan sits on their seat (not in it, not floating), stands with their soles on
the floor, never inside a seat, a row or a rail, and faces the play. Your spots and facings are no longer worked out
by hand: **declare each venue** and the foundation places, fits and checks the fans.

**1. Declare the venue** (where you build its crowd today):
```gdscript
var v := WsgCrowdVenue.new(court_centre, Vector2(court_length, court_width), court_yaw)
v.add({"name": "main stand", "a": Vector3(-15, 0, 9), "b": Vector3(15, 0, 9),   # the first row's front edge, at its floor
	"rows": 8, "tread": 0.8, "rise": 0.4, "seat": "plastic"})
v.add({"name": "east terrace", "a": Vector3(17, 0, -7), "b": Vector3(17, 0, 7),
	"rows": 6, "tread": 0.45, "rise": 0.18, "seat": "terrace", "barrier": {"height": 1.0, "gap": 0.4}})
```
A section is a strip of rows: `a` to `b` is the front edge of its first row (world, at that row's floor), the rows go
back away from the play, each `tread` deep and `rise` higher. Which side is "away" is worked out from the play area.
- `seat`: `bench`, `chair`, `plastic`, `bleacher`, `stool`, `wall` (a wall top), `step` (sitting on the step behind:
  stone steps, a kerb) - or standing: `terrace`, `floor`, `rail`. Each kind has a height, depth and back
  (WsgCrowdVenue.KINDS); give your own where yours differ: `"height"` (the seat over the floor the feet are on),
  `"depth"`, `"back"` (the seat back's height over the seat; 0 none), `"setback"` (row front to seat front; default: the
  seat at the back of the tread).
- `pitch`: one fan every so many m along a row (0.5 seated, 0.55 standing). `stand`: the share of a seated
  section on its feet. `barrier`: a rail, boards or a fence in front of the first row. `facing`: only if the section
  must look somewhere else than the play.
- Stools and wall tops let the legs hang; every other seat has the soles on the floor.

**2. Build from it** (Medium and High):
```gdscript
var used := crowd3d.build_venue(v, quality, focus, density, seed, shirts, lights)
var placed := crowd3d.placed          # spots, facings, seat heights...: give your billboards the spots not in used
```
Each fan faces the play (turned toward its nearest part, at most 50 degrees off square to the row) and their head and
shoulders follow the ball (`watch_ball`). A seated fan is sized to the seat (soles on the floor, the seat of the
trousers on the seat; the shins reach the last few cm), sits back as far as the seat back or the step behind allows,
keeps their toes on the tread, and when the crowd gets up they step forward off the seat. Heads follow the ball in a
ripple (each fan between the ball and where it was a moment ago), never all at once.

**Low (and the stands the 3D fans do not reach): `WsgCrowdCards`** - the same places as flat cards of the shared
fans, in ONE draw call for the whole venue:
```gdscript
var cards := WsgCrowdCards.new()
add_child(cards)
cards.build(v.place(seed), PackedInt32Array(), seed, shirts, lights)    # Low: every place
# Medium/High: cards.build(crowd3d.placed, the indices not in used, ...) for the far stands
cards.set_teams(home, away)
cards.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
```
Each card's fan is sized to their seat (the seat of the trousers on it; lifted onto a stool or a wall top, the legs
hanging), stands just in front of the seat so it never cuts through, and turns toward the camera at most 35 degrees
off the way the fan faces (the play). They get up and cheer with `WsgCrowd3D.set_excite` like the 3D fans and wear
the same shirts and looks. Your own card art instead: `cards.use_art(atlas, mask, layout)` before `build` (layout as
`crowd/cards.json`; the cards are baked by `tools/bake_cards.gd` from the authored crowd). This replaces your own
billboard crowd: drop it, or keep its art through `use_art`.

**3. Register it for the audit**: `res://game/crowd_venues.gd`:
```gdscript
extends RefCounted
static func venues() -> Array:
	return [{"name": "National Arena", "venue": Arena.crowd_venue(), "scene": "res://venues/national_arena.tscn"}, ...]
```
(`scene` optional: drawn instead of the plain boxes; it must not build its own crowd.) Then
```
xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd /tmp/audit
```
measures every fan (WsgCrowdVenue.audit: the seat of the trousers within -2..+3 cm of the seat, the soles within
-2..+4 cm of the floor, nothing more than 2.5 cm into a seat, seat back, step or barrier, every fan within 35 degrees
of the play, none backwards) and every Low card (seated at their seat's height, in front of it, facing the play), and
writes a contact sheet per venue (each section close up from in front and from the side, seated and on their feet,
in 3D and as Low cards) and crowd_audit.json. It exits 1 on any failure: fix the declaration (a seat height,
a tread) until it passes, and send the owner the sheets. The foundation's own test grounds (every kind) pass it:
`tests/crowd_venues.gd`. Put it in CI with the clips fetched (your licensed crowd is the one shipped).

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

## 5.6 Your game on real phones (Firebase Test Lab)

1. Copy Hurling's `testlab/testlab_run.gd/.tscn` into your game and change the match it starts (your AI against
   itself, your biggest venue); it plays 60 s at each tier with a `WsgPerfLog` running.
2. In your main scene's `_ready`, first: `if OS.has_feature("testlab"): get_tree().change_scene_to_file.call_deferred("res://testlab/testlab_run.tscn"); return`.
3. An export preset "Android TestLab": your Android preset with custom feature `testlab` (and add `testlab/*` to
   your normal presets' exclude filter).
4. `.github/workflows/<game>-testlab.yml`: `uses: ./.github/workflows/wsg-testlab.yml` with `game-dir: <your dir>`,
   `secrets: inherit` (copy Hurling's). Run it from the Actions tab; docs/TESTLAB.md has the owner's one-time steps
   and the free plan's limits.

## 5.7 Television: replays, cut-aways, names on the screen (addons/wsg_foundation/broadcast, replay.gd)

- **The replay** (`WsgReplay`): add one to your match, call `record(now)` every live frame, and in your replay
  `play(t0, t1)`, `seek(t)` each frame, `stop()`. It keeps every foundation body exactly as drawn (bodies join by
  themselves) - without it your bodies freeze in their last pose while your replay moves your old ones (the pilot
  had that). Kept: 4 to 7 s by tier (`WsgFoundation.replay_spec()`), 0.6 KB a body a frame.
- **Cut-aways** (`WsgDirector`): `await director.run([{"shot": "close", "target": body, "secs": 1.9}, {"shot":
  "crowd", "at": stand, "from": touchline, "secs": 1.7}], live_camera)` - a close-up from your camera's side of the
  play, round anyone in the way; the stand going up; `"orbit"` for a flight round the ground before kick-off.
  `WsgDirector.packages()` is false on a budget phone's Low (no cut-aways: its replay ring is short). Keep your
  replay's own buffer as long as the package plus your replay's lead-in (Hurling: 7.5 s), and hold your restart for it.
- **Names on the screen** (`WsgLowerThird`, in your HUD's root so it takes your font): `show_card(name, line,
  colour, secs)`; **a score bug** (`WsgScorebug`) if you have none: `setup([short, c1, c2], [...])`,
  `set_score("1-07", "0-09")`, `set_clock("23:41", period)`. Your look: a `WsgBroadcastTheme` (colours, type,
  timing, `reduce_motion` to fade instead of slide). Text goes through tr(): give keys or words in the player's
  language (Hurling: TALLY_TODAY "%s today" / "%s inniu").

## 5.8 Sound (addons/wsg_foundation/audio)

`WsgAudio` mixes your own recordings as a broadcast does. Make one when a match starts (Hurling: `Sfx._mixer()`):
- **The crowd's bed**: `crowd_layers({"murmur": {"stream": loop, "db": [-26, -6], "by": "base"}, "applause":
  {..., "by": "excite"}, "tension": {..., "by": "tension"}})` and `base` = the ground's size. Excitement and tension
  are the ones you already give the 3D fans (`WsgCrowd3D.set_excite` / `set_tension`): the stand and its sound move
  together. Layers can be one recording twice, out of step ("from") and a little higher ("pitch"). Give a looping
  copy (`stream.duplicate()`, `loop = true`) if the same file is also a one-off.
- **Where it happened**: `play_at(stream, position, db, pitch, kind, priority)` - heard from the camera; at most
  the tier's voices (`WsgFoundation.voices()`: a budget phone's Low 8, a premium High 24) and each kind's own limit
  (`kind_limits`); when all are busy the lowest priority, then the farthest, then the oldest gives way, and a
  newcomer that would lose to all of them is not played. Keep a flat fall-back for builds without the foundation.
- **Ducking**: `duck(db, secs)` - the crowd under the whistle, a replay, a commentary line; the deepest wins and
  eases back. **Haptics**: `haptic([[ms, strength], gap, ...])` behind your vibration setting (`haptics_on`),
  never two within 60 ms.
- **One-offs** from the crowd: `react([take_1, take_2, take_3])` never repeats the take just played.

## 5.9 Known gaps (a dry run of this guide on Kho Kho, a budget game)

Vendoring, compiling, baking the player onto the rig (tools/wsg/bake_character.sh: fixed to run from a game) and
the rig test all work as written. What this guide does not cover yet:
- **A Mixamo AnimationPlayer game** (Kho Kho: `ModelBody`, the `mixamorig:` 23-bone skeleton, its own clips played
  by an AnimationPlayer, three modifiers of its own - head turn, the pole grip, the dive). Section 4's link reads the
  six games' 17-bone ToonBody (WsgLegacyPose); a Mixamo skeleton needs its own reader (the names are the rig's,
  without the prefix: each bone's turn, rest-corrected, as tools/models/retarget.gd does) - to be written before Kho
  Kho adopts.
- **Holding something that is not in a hand** (Kho Kho's pole turn: both hands on a post in the ground):
  `WsgPoseLayer.hold` anchors a hand to a bone, not to a point in the world. (Since the pilots:
  `WsgPoseLayer.hold_point`, section 5.10.)
- **The game's own fans**: the 3D crowd's fans are Hurling's (an Irish crowd). Kho Kho needs its own (its cut-outs
  are drawn from its player model) and its bleachers' seat height.
- **Indoor light**: tools/blender/bake_light.py bakes a sun and a sky; Kho Kho's halls are lit by strip lights.
- **Indic type**: give WsgBroadcastTheme the game's font (Kho Kho ships Tamil, Telugu, Marathi, Odia and more).
- **Its automatic graphics** (Kho Kho's `auto_gfx` lowers the tier when a match runs slowly): set
  `WsgFoundation.tier` there too.
- **No replay of its own** yet: WsgReplay and WsgDirector are there for an out, but the game has to call them.

## 5.10 Lessons from the pilots (Floorball, Netball, Kabaddi, Sepak Takraw, Kho Kho, Pok Ta Pok)

What the six pilots after Hurling found, short. Every new switch named here is off by default: a game that does not
set it behaves as before.

**The licence: a Web build never carries the licensed data.** A Web export (a Netlify page, any public download) is
not an APK: its .pck is downloadable by anyone. Every game's **Web** preset in export_presets.cfg must list
`addons/wsg_foundation/data/*` in its `exclude_filter` (the game then runs on its own animation there, as a build
without the clips does). A session can now fetch the clips locally (tools/wsg/fetch_assets.sh through `gh api`), so a
Web export made by hand from that checkout would otherwise ship them. Kabaddi's preset is the model.

**Held things and measuring**
- **A held item (a ball, a flag, a stick) is placed in the body's `posed` callback** (`body.posed.connect(...)`), not
  after `advance()`: `posed` fires at the skeleton's deferred update, once its modifiers (the layers, the grips) have
  run. Placed earlier it is a frame behind the hand (Netball's ball, `_on_posed`).
- **Measure bones in `posed` too** (a test's hand-to-ball gap, a foot's height): read anywhere else, they are the
  pose without its modifiers.
- **A ball in the hand**: `body.grip_sphere(side, r)` closes the fingers on the ball itself and
  `body.ball_point(side, r)` is where its centre goes (`WsgGrip.solve_sphere` / `sphere_point`). A ball closed as a
  ball-sized handle (`grip`) left fingers up to 10 mm inside it.
- **Holds against the hips**: `layer.hips_first = true` (the hips laid once, before the holds), `layer.hold_weight_own
  = true` (each hold at its own weight, not the layer's fade) and `layer.make_holds = link.holds` (your
  `holds(sk, hips, lift)`, called once the hips and body are laid). Floorball's StickLayer laid the hips itself and the
  layer laid them again: in a fade its holds drifted up to 4 cm. Netball's BallLayer did it right by hand.
- **A hand on a point in the world** (a pole, a rail): `layer.hold_point = {side: [point, weight, axis, radius]}`,
  with `layer.arms = WsgLegacyPose.arm_maker(body.joints)` if you have no 17-bone reader. It is aimed lower by
  `lift_after` itself; `layer.hold_point_reach` says when a hand cannot reach (Kho Kho's pole turn).

**Your pose over the whole body**
- **A body you pose from its first frame never runs the locomotor**, so nothing switches its planter for you. Set it
  every update: under your whole-body pose, `loco.planter.keep_pose = true` (the legs exactly as you pose them, the
  hips' lift kept, so `lift_after` stays `hips_offset`); `false` again under the capture. `planter.enabled = false`
  alone still lifts ankles to its floor by IK and eases a released foot only on the locomotor's steps: it bent Sepak
  Takraw's legs by up to 10 cm and held Kho Kho's feet where the last stride left them (kneeling ankles lifted).
  Before keep_pose the pilots used `planter.active = false` with `lift_after = 0` (Sepak Takraw, Pok Ta Pok) or
  `reset()` + `tick(dt)` each update and a low `ground_y` (Kho Kho): both still work.
- **Handing the body back to the capture**: `loco.resume(velocity, facing)` and `loco.planter.reset()` (the
  locomotor's smoothing still had the speed from before your pose: bogus cuts and starts).
- **Meshy A-pose legs and elbows**: a game rigged with the legs splayed (or the arms in an A) gives turns that,
  corrected from their own rest, put the rig's knee or elbow off its hinge, and the drivers straighten it. Rebuild
  the limbs from the joint positions instead: each thigh (upper arm) turned so its hinge is square to the plane of
  your thigh and shin, the shin bending in it (Kabaddi `FoundationLink._legs`, Kho Kho `_limbs`, Sepak Takraw `_legs`).
- **A pose kept in a dictionary** (no 17-bone skeleton to read): build a 17-bone proxy skeleton, rests the identity
  with each joint where your model's is, pose it with your turns, and give it to WsgLegacyPose (Sepak Takraw
  `FoundationLink._make_proxy`).

**The locomotor**
- **It ignores the body node's scale**: after `WsgLocomotor.attach`, `loco.leg_scale *= scale` with the scale you gave the body (strides and
  hips for a body you scaled to a player's height; Pok Ta Pok).
- **Seeded matches**: `loco.rng = RandomNumberGenerator.new()`. The idle fidgets drew on the global `randf()`, which
  changed what Pok Ta Pok's seeded matches did.
- **No `want_velocity`?** Pass it if you have it. If you drive with velocity alone (Kho Kho, Sepak Takraw, Kabaddi),
  set `loco.cut_from_heading = true`: otherwise a cut is measured from where the velocity already swung to, never
  comes round, and its clip crawls while the body runs on (Kho Kho's chasers glided at 8 m/s).

**Replays**
- **WsgReplay records only foundation bodies**: run it on your own replay's clock and frames (Pok Ta Pok: on the
  game's replay clock), and keep drawing your own things (the ball, the game's bodies on Low) from your replay.
- **After a replay, resume your phase where it paused**, not at the phase's end: the match then plays exactly as it
  would have without the replay (Pok Ta Pok, tested).

**Budget games and comparing frames**
- **Gate the foundation to Medium and High** in a budget game and prove Low unchanged: the same draw calls and
  pixel-identical frames against the beta. Pin anything driven by the wall clock (a flag's wave, a shader's
  `TIME`, a crowd's sway) for pixel comparisons, or two runs never match.

**CI**
- **Guard every publish step to the game's own branch** (`if: github.ref == 'refs/heads/<game branch>'`, a pilot's
  own step to its pilot branch) and give the workflow a concurrency group (`concurrency: {group:
  <game>-android-${{ github.ref }}, cancel-in-progress: true}`): Netball's beta publish had no guard, and an older run
  published over a newer one in Floorball's. Give each pilot its own pre-release tag (`<game>-foundation-pilot`),
  never the beta's.

**Tests**
- **"Planted" needs both** the planter's contact flag (`loco.planter.contact[i] > 0.5`) **and** a low ankle
  (`planter.ankle_world[i].y` within a few cm of a standing one's): the flag alone counts a foot lifting through
  the release easing, the height alone a swinging foot skimming the ground (Pok Ta Pok's and Sepak Takraw's runners).
- **Bakes**: `tools/wsg/bake_character.sh` now stops on a script error (and after `BAKE_TIMEOUT` s) instead of
  hanging; it warns when a body gets no LOD levels (Kabaddi's player_10 kept its 5,207 triangles far away too), maps
  the older Meshy spine (Hips > Spine02 > Spine01 > Spine) by its hierarchy, and writes the bake's stance
  `{shift, scale}` into `<name>_rig.json` (`character.stance`: rig = (skeleton point - shift) * scale) for a game that
  maps its own skeleton onto the rig (Kho Kho worked them out again).

**Screens**
- **Never `RichTextLabel.threaded = true`** (a Licences, Help or Privacy page included). On Godot 4.7.2 a label laid
  out on a worker thread while the main thread draws, sizes (`fit_content`), scrolls or frees it crashes the engine
  now and then, with no script error: signal 11 in `RichTextLabel::_shape_line` and `TextServerAdvanced`'s shaped
  text, on a worker thread (Netball's input_test, 0.8.5) or on the main thread as it draws (Sepak Takraw's
  test_runner screen tour, 0.13.0); Kho Kho's fit_audit and Kabaddi's Licences page hit it too. It is not the
  foundation's and not the licensed data's: CI simply runs with the data, and the race is rare. Lay a long text out on
  the main thread in pieces, one label of a few paragraphs a frame (Kabaddi's `licences_screen.gd`, 54a964d), and
  have a test wait for the page to be built before it reads the words.

## 5.11 Watch mode: WsgSpectator (addons/wsg_foundation/broadcast/spectator.gd)

Your AI against itself, shown as television shows it. Your match flow stays yours (the menu entry, the team pick,
the rules, the AI); `WsgSpectator` gives the picture and the controls. Nothing changes until you make one.

**The API**
- `start(game_camera: Camera3D = null)` / `stop()`: takes the picture (its own camera current); `stop()` puts
  `Engine.time_scale`, `physics_ticks_per_second` and `max_physics_steps_per_frame` back exactly, frees its camera
  and makes yours current again. Make one per Watch match (or `start()` it again).
- The follow camera: `set_focus(ball_pos: Vector3, players: Array)` each frame (Vector3s, or Node3Ds), or
  `focus_source = func(): return [ball_pos, players]`. It frames the ball and the `nearest` (4) players from a
  rail along one touchline (`rail`, `rail_follow`, `rail_limit`; `rail = false`: fixed at halfway), eased
  (critically damped, `smooth_time` 0.7 s) with a `dead_zone` (2.5 m), and never crosses the line. Set
  `pitch_center`, `long_axis` (your pitch's length, world), `side` (1 / -1: which touchline), `height`, `distance`,
  `fov_min` / `fov_max`.
- `moment(kind: String, data := {}) -> bool` at a score or a big moment: a `WsgDirector` package (a close-up of
  `data.target`, the crowd at `crowd_at`; or your own `data.shots`) where `WsgDirector.packages()` allows it, then
  a replay of the last `replay_secs` (4 s, at `replay_rate` 0.5) if you set `replay` (your `WsgReplay`), then the
  follow camera. False (nothing run) while one runs, within `cooldown` (20 real s from the last one's end), past
  `max_moments` (8; 0: no cap) or paused. Signals `moment_started(kind, data)`, `moment_finished(kind)`, and
  `replay_frame(t)` each replay frame (draw your ball as it was at t). Moments run at 1x, then your speed again.
- Speed: `set_speed(2.0)`, `cycle_speed()` through `speeds` ([1, 2]; give more if you like); `speed_changed`.
- `pause()` / `resume()` / `toggle_pause()`: the camera holds still and a running moment ends cleanly; `paused(on)`
  is your cue to pause your AI and clock (or set `pause_tree = true`: the spectator keeps running over a paused tree).
- `exit_requested`: Back (Android), Escape (`exit_action`, ui_cancel) or the overlay's Exit. Call `stop()` there.
- `hud_visible(visible)`: connect it to your HUD (hidden during moments; `toggle_hud()`).
- `make_overlay(theme := null)`: an optional minimal HUD for a game without one: a `WsgScorebug`
  (`spec.scorebug.setup(...)`, `set_score`, `set_clock`), Pause, speed and Exit buttons (texts through tr(): "Pause",
  "Play", "Exit"), and a lower third over a moment's replay (`data.title`, `data.sub`, `data.colour`).

**Wiring**
```gdscript
func start_watch() -> void:                      # your menu's Watch: your teams picked, both on AI
	spec = WsgSpectator.new(); add_child(spec)
	spec.long_axis = Vector3.RIGHT; spec.pitch_center = pitch.global_position; spec.replay = replay
	spec.crowd_at = main_stand.global_position
	spec.focus_source = func(): return [ball.global_position, players.map(func(p): return p.global_position)]
	spec.hud_visible.connect(func(v): hud.visible = v)
	spec.paused.connect(func(on): match_paused = on)
	spec.exit_requested.connect(func(): spec.stop(); spec.queue_free(); back_to_menu())
	spec.start(camera)
	scored.connect(func(by): spec.moment("score", {"target": by}))
```

**Notes**
- Budget games: Low still works. `WsgDirector.packages()` is false there, so a moment is the replay alone (or
  nothing without a `WsgReplay`) and the follow camera does the rest; nothing in it costs more at Low.
- 2x on a Low phone is fine: the AI runs the same steps (the physics ticks double with the time scale, so a
  step is as long in game time as at 1x), only twice as many a real second; the camera's easing
  is in real seconds, so it looks the same at either speed.
- The director takes its close-up's side from the spectator's camera, so cut-aways keep to the same side of the line.
- Your own camera stays in the scene, untouched; your replay's own camera work (if any) can run instead of the
  spectator's moment: just don't call `moment()`.

## 5.12 A stick through the body (WsgBody.torso_capsule, WsgPoseLayer.clear_segment)

Hurling's free-take ends with the hurley through the torso: the hands are held on the stick, but nothing keeps the
stick out of the chest. Two calls do:
- `body.torso_capsule(skeleton_space := false) -> [a, b, radius]`: the torso as drawn now (hips to neck, moved to the
  middle of the chest; the radius is the chest's half-depth, measured once from your baked mesh - 138 mm on the hurler
  - else 0.3 of the hips-to-neck length), moved and scaled with the body.
- `WsgPoseLayer.clear_segment(seg_a, seg_b, pivot, capsule, margin := 0.03) -> Quaternion`: the least turn about
  `pivot` that takes the segment clear of the capsule by `margin` (put the stick's radius in it); `IDENTITY` when it
  is clear already (or the pivot itself is inside). About 15 us a call.

Use it where your holds are made (your `make_holds`, or your own modifier after the layer), in skeleton space: turn
the stick, and so both hands on it, about the top fist; the holds then re-solve the arms to where the stick went.
```gdscript
func holds(sk: Skeleton3D, hips: Transform3D, lift: Vector3) -> Dictionary:
	var stick := _stick_xf(sk, hips)                     # yours: the stick in skeleton space (top fist at its origin)
	var cap := body.torso_capsule(true)
	var q := WsgPoseLayer.clear_segment(stick * BUTT, stick * TIP, stick.origin, cap, 0.03 + STICK_R)
	if q != Quaternion.IDENTITY:
		stick = Transform3D(Basis(q), stick.origin - q * stick.origin) * stick
	return _hands_on(stick, hips, lift)                  # yours: each hand's hold from the stick, as before
```
The drawn stick, placed from the top hand in `posed` as before, follows. (There is no switch on the layer for this: the
stick's tip read back from the world is where last frame's turn put it, so it would flicker clear and back.)

The torso is not all a stick can go through. Hurling's free, just after contact, put the hurley through the lead upper
arm (5-6 cm, two frames), which the torso's capsule cannot see:
- `body.limb_capsule(upper_bone, lower_bone, skeleton_space := false) -> [a, b, radius]`: a limb from one joint to the
  next (`"LeftArm", "LeftForeArm"`: the upper arm; `"LeftForeArm", "LeftHand"`: the forearm), its radius measured once
  from your baked mesh (most of the girth, the sleeve included: 76 mm on the hurler's upper arm), else 0.18 of its
  length; `[]` for a bone not on the rig.

For the arm that holds the stick, move the arm, not the stick: turning the stick about the top fist clear of both
the torso and the lead upper arm (which close round it from either side) took the hurley 40-70 degrees off its
swing, pointing at the grass. Hurling's prototype turns the stick clear of the torso only, then swivels the lead
elbow about the shoulder-to-wrist line (the hand stays on the handle) till the upper arm and forearm are clear of the
stick by the stick's radius + 1 cm. Both run after your holds solve (the held arm moves with its hold, so the limb
capsules are only right then): a modifier of your own just after the layer. Measure the result in `posed`.

The layer keeps the forearms out of the chest round the hips-to-neck joint line (`torso_r`), which sits toward the
back: a forearm across the front of a deep chest still sank in (Hurling's follow-through, 2-4 cm). Set
`layer.torso_from_body = true` (the layer under a WsgBody's skeleton) to keep them out of `body.torso_capsule()`
instead - the chest as drawn; `torso_r` is then not used. An arm whose hand is held keeps `torso_r` (swung out of the
deeper chest, the hand came off what it holds), and an arm it swings out is made sound again (the elbow pointing
where an elbow can). Measure what it does to a stick in that hand: Hurling's striking arm, swung out, put the hurley
into the chest on the next frame, and the turn that took it out left the top hand short of the handle, so Hurling
leaves it off.

## 5.13 Low tier: WsgToonDriver (the capture on your own cheap body)

On Low a budget game keeps its own 17-bone toon (its own mesh: the same draw calls, nothing new to skin) - and
until now its own procedural cycle, which glides and swings the arms out. `WsgToonDriver` poses that toon from the
foundation's motion capture instead: a hidden, mesh-less rig body (never in the scene) driven by a `WsgLocomotor`,
each of your bones turned to lie along the rig's matching segment with the rig bone's twist. No second mesh, no IK,
no modifiers; about 0.1 ms a body on a desktop (14 bodies: 1.5 ms, 0.65 ms posed every 3rd frame). Without the
licensed clips `WsgToonDriver.available()` is false and `update()` does nothing: your own cycle stays (CI, forks).
```gdscript
# player.gd (Low only; Medium/High keep the FoundationLink)
var toon: WsgToonDriver
func _ready() -> void:
	...
	if int(Game.settings.graphics) == Game.GFX_LOW and WsgToonDriver.available():
		toon = WsgToonDriver.new(body.skeleton, {}, {"offset": index % 3})   # bone_map {"hips": "pelvis", ...}
func _animate(dt: float) -> void:
	body.apply(your_pose)                       # your pose first, every frame, as now
	if toon:
		if act in ["shoot", "leap", "catch"]:
			toon.set_override(1.0, [], 0.15)    # the whole body yours (the capture pauses, costs nothing)
		elif act in ["hold", "pass", "mark"]:
			toon.set_override(1.0, WsgToonDriver.ARMS, 0.15)   # your arms over its legs
		else:
			toon.set_override(0.0, [], 0.2)     # all the capture's (resumed at her speed: WsgLocomotor.resume)
		toon.every = pose_every                 # 1 near the camera, 2-3 far (the last pose is laid in between)
		toon.update(dt, Vector3(vel.x, 0, vel.y), facing, Vector3(want_vel.x, 0, want_vel.y))
```
- **API**: `WsgToonDriver.new(skeleton, bone_map := {}, options := {})`; `update(dt, velocity, facing, want_velocity
  := Vector3.INF) -> bool` (facing: a world yaw or a Vector3; true when it posed afresh); `set_override(weight, bones
  := [], fade := 0.0)`, `override(bone)`; `pose() -> {your bone: local Quaternion, "@hips": offset from the rest}`;
  `apply(weight := 1.0, bones := [])`; `phase()`; `loco` (`play()`, `jump()`, the `step` signal for footsteps).
  Groups: `ARMS`, `LEGS`, `TORSO`, `HEAD`. Options: `every`, `offset` (which of `every` frames: by default the
  bodies take turns), `face` (your body built facing -Z: `PI`), `scale` (0: the skeleton's world scale), `auto_apply`
  (false: take `pose()` and blend it with your own pose dictionaries), `facing_from_node`, `auto_resume`, `rng`,
  `cut_from_heading`. `WsgToonDriver.off = true` turns it off everywhere.
- **Your rest is read from your skeleton**, not assumed: identity rests with the arms hanging (ToonBody), an A-pose
  with the legs apart (Kabaddi's rigged bodies: the hips are lifted by what the splayed legs lose in height), any
  rest rotations. A bone you do not map (or do not have) is left alone; bones between mapped ones are carried.
- **Feet**: the hips move by the clip's, scaled by your leg against the rig's, so the feet come to the ground; the
  root motion stays yours (you move the body); the cadence is the locomotor's own (`leg_scale` = your leg in the
  world over the rig's). With no planter a stance foot still slides a little (Netball, HeroBody: 22 cm/s at 2 m/s,
  37 at 4.5, against the beta's own clips' 110 and 248); the sprint is worse (the ActorCore sprint's feet cover a
  third less ground than its root: about 2 m/s at a full sprint - the planter hides it on Medium/High). A body posed
  every 2nd/3rd frame is carried along whole in between, as the FoundationLink's are.
- **Kabaddi**: the drawn body on Low is `RiggedBody`'s Skeleton3D (the 17 names already: no bone_map), built facing
  -Z: `WsgToonDriver.new(rig.skeleton, {}, {"face": PI})`, updated after `rig.drive(h)` (its grounding, plants and
  turn limits are then the driver's, except under an override). Its fingers hang under the hands and are left alone.
  `HumanModel`'s placeholder joints are plain Node3Ds, not a skeleton: drive the rigged body, not them (or make a
  17-bone proxy skeleton of them and copy `pose()` back).
- Draw calls and triangles are unchanged (Netball's perf_probe, Low, same with and without); a test:
  `tests/toon_driver_test.gd`.

## 6. What the owner does once (all games share it)

The token: GitHub → your avatar → Settings → Developer settings → Personal access tokens → **Fine-grained tokens** →
Generate new token. Name "assets read for CI"; Resource owner **joshnason8-lab**; Expiration up to a year (note the
date: builds fall back to the old animation when it expires); Repository access → **Only select repositories** →
`world-stage-games-assets`; Permissions → Repository permissions → **Contents: Read-only** (Metadata: Read-only comes
with it); nothing else. Generate, copy it. Then in **ghost-kit-pages** → Settings → Secrets and variables → Actions →
New repository secret: name `ASSETS_REPO_TOKEN`, paste, Add secret. One secret serves every game's workflow.

## 6.5 How the foundation's updates reach your game

Every game carries its own copy of the foundation (`addons/wsg_foundation/`, and its scripts in `tools/wsg/`), so
a game builds without the foundation's branch and a change there never breaks a game unasked. To take an update:
```sh
sh <game>/tools/wsg/sync_foundation.sh     # fetches claude/shared-foundation, replaces only the foundation's files
```
then run the game's suites and commit on the game's branch. It replaces `addons/wsg_foundation/` (keeping the
licensed `data/` folder) and the foundation's own scripts in `tools/wsg/` - never your link, players, tests,
assets or workflow - and writes the foundation commit to `addons/wsg_foundation/VERSION`.

Your workflow warns (never fails) when your copy is behind - a step after checkout:
```yaml
      - name: Shared foundation up to date? (a warning only)
        run: sh <game>/tools/wsg/check_foundation.sh
```
The foundation's own session pushes each update to every adopted game's pilot or game branch, under that game's
rules (a pilot branch until the owner has passed the game's pilot), and says so to the lead, who checks each release.

## 7. Check before you push

```
godot --headless --path <game> res://tests/compile_check.tscn     # or your compile check
<your test runner>                                                # nothing of yours should change
```
and look at it: a run, a stop, a backpedal, your signature move, the crowd at a score. The foundation's own tests
(`foundation/tools/run_tests.sh` on its branch) cover the rig, the locomotion's foot slide, the crowd and officials.
