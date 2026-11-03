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
the same shirts and looks. Seen from behind (a camera behind a stand, a third-person camera round a ring) a card
shows the fan's back (`crowd/cards_back.png`), turned toward the camera from behind, never the front mirrored. Your
own card art instead: `cards.use_art(atlas, mask, layout, back, back_mask)` before `build` (layout as
`crowd/cards.json`; back and back_mask optional, the same cells from behind; the shared cards are baked by
`tools/bake_cards.gd` from each fan's whole textured model in the authored crowd poses). `cards.brightness` matches
your old crowd's; each spot's shirt Color is drawn exactly; `cards.fan_weights` as WsgCrowd3D's (each seat takes a
fan at random among those whose legs fit it). Your own art may add poses after sit, stand and cheer in its layout's
`"poses"`: `sit_clap`, `stand_clap` (on the beat while `cards.clap(rate, unison, seconds)` plays), `sit_look_l`,
`sit_look_r`, `stand_look_l`, `stand_look_r` (toward the side the ball is on: `cards.watch_ball(p)` every frame).

**After a sync that re-bakes the crowd, bake your licensed crowd again** (`FORCE=1 tools/wsg/fetch_assets.sh`; CI
fetches fresh). A crowd baked before the foundation's current crowd.json version (`WsgCrowd3D.BAKE_VERSION`) has
ungrounded frames (seated soles up to 7 cm under the floor), and `crowd_audit` says so and fails. This replaces your own
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

Write the sheets **outside the project**, for example `"${{ runner.temp }}/crowd_audit"`, never a path under your game.
Also add `crowd_audit/*` to every export preset's exclude_filter as a backstop. Floorball wrote them into its tree:
the export imported and packed them (26 MB, 34 MB and 5 MB of textures), and its APK went from 89 MB to 155 MB. The
same goes for every audit tool's output.

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
- **Key hits stay crisp at a distance.** Godot's 3D players take up to 24 dB off above 5 kHz with distance, so a high
  ping becomes a thud. The owner twice missed Hurling's post clang, 30–65 m from the camera.
  - These kinds play with no distance filter, and from no farther than `bright_distance` (30 m): `hit`, `strike`,
    `post`, `bar`, `crossbar`, `net`, `ring`, `whistle`, `tag`, `bat`, `stick`, `ball`, `bounce`, `catch`, `kick`,
    `clang`, `buzzer`.
  - Add your own kinds to `bright_kinds`, or pass `bright = true` (the argument after priority).
  - Steps, ambience and anything else still dull and fade.
  - The test plays a 500 Hz + 4 kHz ping 50 m away. A step's 4 kHz comes out 17 dB under its 500 Hz; a post's is
    level with it.
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

**Boots resting toe-up** (`WsgFootFlat`): a model whose soles rise from heel to toe at rest (Hurling's HD hurler by
10.6 degrees after its bake) shows the toes off the ground in every move. Call `WsgFootFlat.attach(body)` once your
body's modifiers are all in place (the locomotor, the layers, your own): it measures the model's sole tilt from its
mesh (`WsgFootFlat.sole_tilt(body)`, a boot's 1.5 degrees of toe spring allowed) and, if it is 2 degrees or more, adds
itself as the skeleton's LAST modifier, turning each foot down by it and setting a planted heel back on the ground.
A model standing flat gets none. (From Hurling's FootFlat, 0.21.1: its match audit's ankle frames 86 -> 7.) It finds
the body's `WsgFootPlanter` on the skeleton and keeps a foot the planter holds down shifted in full, so the turn's toe
shift is made in the air, not on the ground (until 2026-11-04 it came on as the toe touched down: the planted heel
jumped 3.3 cm a step on Hurling's walker).

**Your pose over the whole body**
- **A body you pose from its first frame never runs the locomotor**, so nothing switches its planter for you. Set it
  every update: under your whole-body pose, `loco.planter.keep_pose = true` (the legs exactly as you pose them, the
  hips' lift kept, so `lift_after` stays `hips_offset`); `false` again under the capture. `planter.enabled = false`
  alone still lifts ankles to its floor by IK and eases a released foot only on the locomotor's steps: it bent Sepak
  Takraw's legs by up to 10 cm and held Kho Kho's feet where the last stride left them (kneeling ankles lifted).
  Before keep_pose the pilots used `planter.active = false` with `lift_after = 0` (Sepak Takraw, Pok Ta Pok) or
  `reset()` + `tick(dt)` each update and a low `ground_y` (Kho Kho): both still work.
- **Handing the body back to the capture**: `loco.resume(velocity, facing)` and `loco.planter.reset()` (the
  locomotor's smoothing still had the speed from before your pose: bogus cuts and starts). Only after a pose of the
  whole body: from an arms-only layer (your "upper" mode, the legs the capture's all along) do not reset the planter -
  every reset snapped the held feet to the clip's, 3-5 cm (Pok Ta Pok's judges, WsgSim).
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

## 5.14 The loading overlay: WsgLoading (every game, every start button)

The owner: "when you click start game there is a loading delay ... long enough on the slow phone that users might
think the game has frozen." `WsgLoading` (addons/wsg_foundation/loading.gd) answers the tap in the same frame: the
menu dims, "Loading…" and a bar come up with a spinner, and the start buttons go dead, so a second tap can't start a
second load. The heavy work waits two frames, so the overlay is on screen before it starts.

- **Files** load on the loader's thread (`ResourceLoader.load_threaded_request`), and the bar follows
  `load_threaded_get_status`.
- **Building** that must run on the main thread runs in your steps, with a drawn frame after each. That covers
  instantiate(), the venue, the crowd and the light.
- **Nothing is made on the thread but resources.** No node is instantiated there (the RichTextLabel thread bug).

```gdscript
const LOAD_LOOK := {"bar": Color("#f5c400"), "spinner": Color("#f5c400"), "logo": preload("res://ui/logo.png"),
	"tips": ["Hold to charge a shot, release to strike.", "Swipe up to lob."]}
var _built := {}                       # a step's results (a lambda can't set your function's locals)

func _on_play_pressed() -> void:
	var ld := WsgLoading.cover(self, [play_button, watch_button, practice_button], LOAD_LOOK)
	ld.log_label = "match"
	ld.request(["res://game/match.tscn", "res://venues/%s.glb" % venue])
	ld.step("Match", func(): _built.match = ld.res("res://game/match.tscn").instantiate())
	ld.step("Venue", func(): _built.match.set_venue(ld.res("res://venues/%s.glb" % venue)), 2.0)
	ld.step("Crowd", func(): await _built.match.build_crowd(ld), 3.0)   # weight 3: the bar's biggest share
	ld.step("Light", func(): _built.match.apply_light())
	ld.warm(func():                    # your swap, inside the warm-up (the overlay sits on the viewport: it stays up)
		Game.swap_to(_built.match)
		return _built.match)
	if not await ld.run():             # false: a file failed; the overlay has gone, the buttons are back
		return
	await ld.done()                    # holds until the frames settle, then fades out
	_built.match.kick_off()            # start the clock here: the first frame the player sees is smooth play
```

Your match's clock, AI and cut-scenes should start on `kick_off()` (or on `ld.finished`), not in `_ready()`. They run
behind the overlay during the warm-up and the settle.

**Cut a long step.** Anything over about 250 ms on the A16 (Low) reads as frozen. Between chunks of a long build,
`await ld.checkpoint(i / float(n))`: it moves the bar within the step's share, and once 50 ms of work have run
(`slice_ms`) it lets a frame draw. Code deep in a build can reach the overlay without being handed it:

```gdscript
func build_crowd(ld: WsgLoading = WsgLoading.current()) -> void:
	for i in sections.size():
		_build_section(i)
		if ld: await ld.checkpoint(float(i + 1) / sections.size())
```

A coroutine called this way must itself be awaited by its caller (`await _built.match.build_crowd(ld)`). Without an
overlay, `ld` is null and the build runs straight through as before.

**The 3D crowd builds in slices too:** `await crowd.build_venue_async(venue, quality, focus, density, seed, shirts,
lights)` (or `build_async`). It makes the very crowd `build_venue` makes, the same draws in the same order, with a
checkpoint every 64 fans. Hurling's practice, 2,400 full figures, was 784 ms in one slice.

**A big scene's instantiate() is one call, and its `_ready()`s run when you add it.** If either alone is over budget,
split the scene. Request the parts (`venue.tscn`, `teams.tscn`, `stands.tscn`) and instantiate each in its own step.
Keep `_ready()` light, and move the heavy setup into a method a step calls.

**Shaders: the warm-up (`ld.warm`).** On GL Compatibility, every new material's shader compiles on the main thread
the first time it is drawn. Sepak Takraw measured 5.5–12 s from tap to first frame with no shader cache, all of it in
one frame. A bar can't move through that. `ld.warm(node or callable)` handles it like this:

- From the first step until the warm-up, the viewport draws no 3D (`disable_3d`). So a scene added by an earlier step
  is not drawn whole, every shader in one frame.
- The warm-up hides everything under the node: render layers 0, visibility ranges off.
- It then draws the scene's looks a batch a frame from its own camera, aimed so each batch is in view. A look is a
  mesh and its materials, by kind: mesh, multimesh or particles.
- Each new shader compiles in a frame of its own, and the bar moves after each one.
- Batches double while frames stay quick, and drop to one look after a slow frame.
- It then puts back every layer, every range and your camera.

Do your swap inside the callable you pass to warm, as above. A deferred swap (`change_scene_to_node`) is waited for,
up to 3 frames. The report's `warm` gives `{nodes, looks, frames, ms}`. A boot screen can call
`await WsgLoading.warm_scene(node)` on a venue, a player and the crowd, so the first match finds them compiled.

The warm-up spreads the compiles out but doesn't make them shorter. One shader that takes 400 ms to compile on the
A16 is still a 400 ms frame behind the overlay. A cold bench on software GL (66 looks, the foundation's crowd and
flag shaders among them, no shader cache) measured:

| | while covered | after the overlay goes |
|---|---|---|
| Before | | one frozen first frame of 48–50 s |
| After | 57–66 frames, the longest 1.1–1.8 s | frames of 60–330 ms |

On the software renderer:

- each shader compiles in about 0.75 s, far slower than on a phone;
- the total time was the same, about 50 s;
- its frames swing between 60 and 330 ms even without the overlay's fade.

The A16 numbers have to come from your own WSG_LOADING line.

**In headless tests, wait on the clock, not on frames.** Under `--fixed-fps` a headless run turns hundreds of frames a
second, so a test that waits a fixed number of frames times out before the load finishes (Kabaddi). Wait for
`finished`, or for a time.

**Frames settle before play (`done()`).** The first frames after a load still stall on cold resources and leftover
shader variants: Floorball measured 0.3–1 s on the A16. So `await ld.done()` keeps the overlay up, opaque with the bar
at its last step, until `settle_frames` (3) frames in a row come in under `settle_ms` (50). It stops waiting after
`settle_cap` (3 s) either way.

A phone that is slow on every frame passes too:
- a frame within 30% of its quickest frame counts, up to twice `settle_ms`;
- or the last 6 frames all fall within 20% of each other, however slow. Netball's software renderer, steady at 250–450
  ms, used to wait the full cap.

Compile stalls are uneven, so they never pass. A load under `quick_ms` (300 ms, such as a rematch) closes at once, with no
fade.

**Pre-warm on the menu (`WsgLoading.prewarm(paths)`).** While the menu is up, start the likely next match's files:
the last-used or default venue, the players, the crowd, and your copy of the motion-capture library. They load on the
loader's thread, and the menu keeps its frame rate. A later `run()` that requests the same paths takes them as they
are, loaded or part way, without asking again; the report's `prewarmed` lists them.

This pre-warms files, not shaders. A compile on the menu would be a menu stall, so do shader warm-up in your boot
screen with `warm_scene`.

**The look.** Every key is optional:

| Key | Type | Default |
|---|---|---|
| `dim`, `text`, `bar`, `bar_back`, `spinner` | Color | |
| `title` | String | "Loading…" |
| `logo` | Texture2D | |
| `tips` | Array of String | one at a time |
| `tip_seconds` | float | 4 |
| `font` | Font | |
| `font_size` | int | the short side / 24 |
| `show_spinner` | bool | true |
| `show_percent` | bool | false |

It lays itself out from the screen's short side, so it fits portrait and landscape and follows a rotation.
`ld.parts()` hands you its controls to restyle further. Nothing licensed is in it. The spinner turns in its shader
(TIME), so it keeps moving with no script work. No frame is drawn while the main thread is busy, though, and that is
why the steps are cut.

**Measure it on the phone.** Every run prints one line, which Test Lab's logcat keeps alongside WSG_PERF:

```
WSG_LOADING {"label":"match","total_ms":2310.4,"load_ms":820.1,"longest_frame_ms":181.0,"longest_slice_ms":163.2,
             "longest_slice":"Crowd","steps":{"(loading files)":4.1,"Match":96.0,"Venue":140.2,"Crowd":702.5,...},
             "frames":41,"failed":[],"prewarmed":[],"warm":{"nodes":412,"looks":57,"frames":31,"ms":2900.0},
             "settle_ms":180.2,"settled":true,"settle_longest_frame_ms":61.0}
```

`done()` prints it, so call done() on every path.

- `longest_slice_ms` and `longest_slice` give the longest stretch of main-thread work between two frames, and the
  step it was in.
- `longest_frame_ms` gives the longest gap between frames: what the player saw. With a warm-up, this includes its
  compiles.
- `settle_longest_frame_ms` gives the longest of the first frames after the match is in.
- A slice over 250 ms also logs a warning naming the step. Cut that step.

The foundation's test (`tests/loading_test.gd`) checks the following, with timings from a desktop rather than a phone:

- a real tap puts the overlay up and turns the buttons off in the tap's own frame;
- the load starts two frames later;
- a second tap starts nothing;
- the bar only goes forward and reaches the end;
- a sliced step holds the main thread about 60 ms, and an unsliced 300 ms one is reported by name;
- a missing file brings the menu back;
- the overlay fits 720×1280, 1280×720 and 480×854;
- settle:
  - five 150 ms frames are waited out;
  - endless ones stop at the cap, reported as not settled;
  - a steady 70 ms phone settles at once;
- warm-up:
  - 12 nodes in 9 looks, each one drawn inside the warm-up camera's view;
  - layers, ranges and the camera are put back;
  - 3D is off from the first step to the warm-up;
- a prewarmed file is taken without a second request;
- a 20 ms load closes at once.

## 5.15 Solid props: WsgSolidProps (every game, every venue)

The owner: "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should
also bounce off these items. Every asset was built to be a tangible object."

`WsgSolidProps` (addons/wsg_foundation/solid_props.gd) is a venue's props as simple solid shapes, plus the questions
your own movement code asks of them. Your bodies and ball move by your own integrators, not Godot physics, so it is a
query set. It is cheap on Low: a 2 m grid, with boxes, upright cylinders and capsules only.

**1. Declare every prop where your builder puts it.** This is the same code that places the mesh or MultiMesh
instance:
```gdscript
var solid := WsgSolidProps.new()
solid.add({"name": "officials' table", "kind": "box", "position": base, "yaw": yaw, "size": Vector3(1.8, 0.76, 0.8), "material": "wood"})
solid.add({"name": "pole", "kind": "cylinder", "position": base, "radius": 0.0475, "height": 1.225, "material": "wood"})
solid.add({"name": "crossbar", "kind": "capsule", "a": left_top, "b": right_top, "radius": 0.024, "material": "metal"})
solid.add({"name": "plexiglass", "kind": "panel", "xf": Transform3D(basis, centre), "size": Vector3(2, 0.95, 0.01), "material": "glass"})
solid.add({"name": "court", "kind": "floor", "y": 0.0, "material": "wood"})   # the ball's floor: see 3
solid.skip("centre logo", "a decal on the floor")                              # not solid, and why
```
- A box takes `xf` (its centre and turn), or `position` (its base's centre) plus `yaw`.
- Use `"ball": false` or `"walk": false` when only one of the two applies, such as a net that bodies may brush.
- Materials, as restitution and friction, with the hit sound's kind:

  | material | restitution | friction | hit sound |
  |---|---|---|---|
  | wood | 0.55 | 0.30 | hit |
  | metal | 0.70 | 0.15 | clang |
  | plastic | 0.60 | 0.25 | hit |
  | padding | 0.25 | 0.55 | bounce |
  | net | 0.10 | 0.80 | net |
  | fabric | 0.15 | 0.70 | bounce |
  | stone | 0.60 | 0.35 | hit |
  | concrete | 0.60 | 0.40 | hit |
  | glass | 0.75 | 0.10 | hit |
  | plaster | 0.50 | 0.40 | hit |
  | earth | 0.35 | 0.60 | bounce |
  | chainlink | 0.30 | 0.50 | clang |

A ring (netball, basketball, a stone ring on a wall) is `solid.add_ring({"centre": c, "radius": 0.2, "tube": 0.011,
"axis": Vector3.UP})`, a loop of capsules. A ball through its middle passes; one onto the tube comes off it.

`solid.register(root)` takes the props from a scene instead. Each MeshInstance3D, and each MultiMesh instance, becomes
its own turned box. It guesses the material from the name.
- It leaves out anything flat (lines, decals), anything wider than 20 m (the ground, a stadium shell), and names like
  ground, floor, pitch or crowd.
- A node opts out with meta `wsg_solid` = false and a `wsg_solid_reason` (or the group `wsg_not_solid`). The reason is
  kept in `solid.skipped` and the audit reports it.

**2. Bodies (players, officials, substitutes, coaches): every body's movement step goes through it.**
```gdscript
var m := solid.move(pos, vel, dt, RADIUS, HEIGHT, goal, memo)   # steered round, moved, pushed out
pos = m[0]
locomotor.drive(dt, m[1], facing)                               # WsgLocomotor animates what really moved
target = solid.free_spot(target, RADIUS)                        # an AI spot inside a bench: the nearest free one
var way := solid.path(pos, bench_seat, RADIUS)                  # out-of-play walks: waypoints round the props
```
- `move()` is `steer()`, then the step, then `push_out()`.
- `steer()` turns the velocity, keeping its speed, toward whichever of 12 directions goes most your way with nothing
  in reach for 1.6 m (or less, if the goal is nearer).
- `memo` is one Dictionary per body that you keep between frames. It holds the side the body chose round what's in its
  way, so it goes on round a 5 m bench instead of dithering at its middle.
- **With your own acceleration, steer the velocity you want, not the one you have** (Kabaddi). Calling `steer()` (or
  `move()`) after `vel = vel.move_toward(desired, ...)` left a walker crawling along a bench at 0.45 m/s: the
  acceleration kept pulling `vel` back toward the blocked way, and steering kept its small speed. Steer `desired`,
  then accelerate toward it, then step and `push_out()`; the walker goes round at full speed.
- **A body seated on a prop** (a substitute on the bench) is audited with `audit.body(who, pos, r, h, true)`: counted,
  not checked. When it gets up, move it toward `free_spot()` until it is out.
- `push_out()` is the final resolve: whatever else moved the body (a tackle, a celebration), it ends outside every
  prop.
- A prop whose top is under 12 cm above the feet does not stop anyone (a mat, a cable cover). A crossbar over the head
  doesn't either.
- Where your rules let a body cross something, mark that part `"walk": false`. Floorball's substitution zone is a
  step-over.

**3. The ball, at any speed.** Call this instead of `pos += vel * dt`:
```gdscript
var r := solid.bounce(ball_pos, ball_vel, BALL_R, dt, func(hit): au.play_at(knock, hit.pos, -4.0, 1.0, hit.sound))
ball_pos = r.pos
ball_vel = r.vel
```
It sweeps the ball along its whole step, so a 60 m/s shot at a 2 cm pane bounces back. At each prop it meets, it
applies that material's restitution and friction, and passes your callback the `material`, its `sound` kind (crisp
at a distance, §5.8), `speed` and `pos`.

**Register your floor (`"kind": "floor"`)** rather than clamping after `bounce()`. A clamp after it can lift a ball
that went under a prop's base up through the prop. That was the only way the test's 3,000 throws got through anything.

**4. Godot physics.** `solid.make_bodies(parent)` builds the same props as StaticBody3D colliders on layer 9
(`PROPS_LAYER`), each with its material's bounce and friction. Give your bodies' masks that layer, and turn on
`continuous_cd` on your ball's RigidBody3D.

**5. The audit: tools/prop_audit.gd.** Your registry (see `tests/prop_runs.gd`) gives `static func venues()` and a
coroutine `run(venue, seed, seconds, audit, tree)`. The coroutine plays a Watch-AI match at that venue at sim speed,
and on every frame calls:
- `audit.body(who, pos, radius, height)`;
- `audit.ball(pos, radius)`; if your ball takes several physics steps a frame, `audit.ball(pos, radius, "ball", path)`
  with the places it went through since the last frame, in order (a bounce off a wall inside a frame: the straight
  line between frames cuts the corner past a prop by the wall);
- `audit.ball_reset()` when you put the ball somewhere new;
- `audit.tick(dt)`.

Then run:
```
xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" 2 120
```
- It fails on any body more than 2 cm into a prop, and on any ball step that passed through one.
- It writes prop_audit.json and a sheet per venue: close-ups of the worst cases from two sides, with the props' wire
  boxes in yellow and the body or ball in red.
- **It refuses an output folder inside the project.** Put it in CI.

**What the foundation's test shows** (`tests/solid_props_test.gd`):
- 24 walkers sent at goals straight through a bench, table, pole, pane or net all arrive, with none ever inside;
- paths round the bench and the table are clear;
- 3,000 random throws up to 50 m/s produce 15,049 bounces and none through a prop;
- the net gives back 2 of 20 m/s;
- the audit catches a walk through the bench and balls through the props when nothing stops them;
- 38 bodies moving among the props cost 1.1 ms a frame on a desktop.

**Next step:** measure that cost on your A16. It only climbs when bodies are near props; far from them, a `steer()` is a
grid lookup.

## 5.16 The owner's notes, kept as tests for good (every game)

The owner: "the regressions are getting worse." So every note the owner gives becomes a test that never goes away. It
checks the very symptom they saw, across its whole range (the joystick at the screen's centre, edges and corners on
every camera, not just the middle of the sideline view), and it carries their words, the date and the version.

**Where they live.** Your notes go in `tests/owner_notes/`, one script each, plus `INDEX.json`, which lists them all:
```gdscript
# tests/owner_notes/2026-11-02_joystick_cameras.gd
extends WsgOwnerNote
const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "netball", "date": "2026-11-02", "version": "0.8.4",
	"words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}

func check() -> void:                     # may await; tree is the SceneTree
	var cams := await _my_cameras()       # every camera the game has, in a viewport
	for f in WsgNoteChecks.joystick(Callable(Player, "stick_to_world"), cams):
		fail(f)
```
- `fail()` and `expect()` record failures. `info()` prints the numbers.
- `skip(why)` is only for when the data a note needs isn't there. CI runs with `WSG_NOTES_STRICT=1`, which fails any
  skip.

**Shared checkers (`WsgNoteChecks`) for the notes that keep coming back:**
- `joystick(map, cameras)`: the stick pushed 8 ways with the body at 9 places on the screen, on every camera. It passes
  within 25° of a camera-relative way: the camera's own flat forward (`stick_world`, which you can use as your
  mapping), or the camera-to-body direction. A world-fixed mapping fails on end-on, overhead, corner and
  behind-the-player cameras.
- `foot_slip(frames, ankle_rest, toe_rest)`: each step's planted-foot slip in cm, from `feet(body)` every frame. A
  planted foot is one on the ground and not swinging through; pass the planter's own flags as items 4 and 5 if you
  have them. **Since 2026-11-04 it adds up, frame by frame, the smaller of the heel's and the ball's move**: a
  heel-to-toe roll (one end still at a time) reads near 0, a foot sliding (both ends moving) reads in full. Before, it
  took each end's drift since the step began: a roll read 1-3 cm that was not there, and a slide that came back read
  less than it went (the planter off, a walk's 8 cm read 2.7). Your numbers move both ways - re-check your feet items.
  It also returns `skid_cm`: the most a foot **flat on the floor** (heel and toe both within 2 cm of standing, this
  frame and the last) moved in one frame, whatever the swing gate or your flags say. The feet rule and WsgSim's foot
  slip fail over 2 cm (from the foundation commit that adds it). It catches the glide the slip cannot: a foot brought
  in flat and fast, or snapped back as it lands (a hard stop from a run: 23 cm a frame, then 7 back, on the floor). A
  walk's swing toe skimming the grass with its heel up is not flat and never counts.
- `t_or_a_pose(body)` and `arms(body)`: an A-pose or T-pose, how far out the arms are, how bent the elbows.
- `block_figure(node)`: no skinned body, or primitive shapes standing in for one.
- `pose(body)` and `jitter(body, poses)`: twitching while standing.
- `bright(au, kinds)`: key sounds kept crisp at a distance.
- The crowd: `WsgCrowdVenue.audit`. Props: `WsgPropAudit`.

**Run and guard them in CI:**
```yaml
      - run: sh <game>/tools/wsg/owner_notes_guard.sh   # reads INDEX.json's history (deepens a shallow checkout)
      - run: WSG_NOTES_STRICT=1 godot --headless --path <game> --fixed-fps 30 -s res://tools/wsg/owner_notes.gd
```
The runner fails on:
- any failed note;
- a file not in the index;
- a listed note whose file is gone.

The guard fails if any id that was ever in `INDEX.json` has been removed.

**Back-fill your history.** Write one note per owner remark, using the owner's own words. Sources:
- your PROGRESS.md, BETA.md, PLAYTEST.md, AI.md and MOCAP.md;
- code comments that say "the owner saw…";
- your session transcript, because the owner talks to you directly.

The foundation's own 16 (`foundation/tests/owner_notes/`, all passing) show the pattern:
- the feet not sliding (each step's slip at most 4 cm, 1.5 on average);
- arms not bending the wrong way;
- no A-pose, no block figures and no twitching while standing;
- runners stepping, with their arms bent;
- referees drawn from the players' model, holding the flag;
- the crowd not feet-up, not in the seats, not facing away, and seated properly;
- the joystick on every camera;
- the auto tier lowering when it stutters;
- the loading overlay in the tap's own frame;
- props solid;
- the post clang crisp at 50 m.

## 5.17 WsgSim: thousands of simulated matches (every game)

The owner: "Please build an automated simulation and testing system ... so you can find and fix bugs without relying
on me to manually play every build ... I want it to take hours not days."

WsgSim runs your matches with your **production code**: your movement, AI, ball, rules, and animation-driven logic
such as root motion, the locomotor and contact timing. Only the drawing is skipped. It runs headless, on a fixed step
(`--fixed-fps 30`, each frame 1/30 s of game time) and as fast as the computer allows. Every match comes from a seed,
and any failure replays from it.

The foundation provides:
- the runner, the batch tool, sharding and the CI template;
- the human-input fuzzer and the menu fuzzer;
- the generic checks.

You provide one adapter, `res://game/sim.gd`. Build it on what you already have (match_sim, user_bot, score_check,
test_runner); it is not a second copy of your game.

**1. The adapter** (extends `WsgSimGame`; `tests/sim_demo/demo_sim.gd` is a full one):

| Method | What it gives the harness |
|---|---|
| `scenarios()` | `"random"`, `"extreme"` and your targeted kinds (`"targeted:scoring"`, `"targeted:timer"`, `"targeted:possession"`, `"targeted:collisions"`, `"targeted:completion"`, …) |
| `config(kind, rng)` | one match's conditions, drawn only from `rng`: team strengths, player attributes, AI strategies, settings, venue, the human's side |
| `start(config, seed, tree)` | builds the match with your own code, every random roll from `seed`, and returns its root; shortens the halves if `config.short` |
| `state()` | `{score, clock, clock_running, phase, possession, finished}` |
| `events()` | what happened since the last call |
| `bodies()` | `[{name, pos, radius, height, body (WsgBody), active, target}]`, the same order all match (the sampled quarter is picked by place in the list); optionally `pose_excuse`: why the arms are out straight by design now (counted, not failed) |
| `ball()` | the ball's position, radius and whether it's in play; optional `"path"`: the places a sub-stepped ball went through this frame, in order, each swept by the audit |
| `solid()` | your WsgSolidProps |
| `fetch(spot)` | the ball dead at `spot` (behind a big prop) and one body sent for it: `{who, seconds, arrive}` |
| `bounds()` | where anything may ever be |
| `score_steps()` | how much one side's score may go up at once (e.g. `[1, 3]`) |
| `max_seconds(config)` | the most simulated time a match may take |
| `rules()` | your sport's own checks, every frame |
| `result()` | `{winner, score}` |
| `balance_keys(config)` | `{fair, strategy_home, …}` |
| `stop()` | frees the match |

For the human and the menus:

| Method | What it gives the harness |
|---|---|
| `human_team()` | which side a person plays |
| `input_actions()` | the input actions a person uses |
| `stick(v)` | your touch joystick, if you have one |
| `cameras()`, `set_camera(i)` | the cameras the fuzzer switches between |
| `menu_start(tree)` | your main menu |
| `in_match()` | whether a match is under way |
| `menu_check()` | your menu invariants |
| `save_paths()`, `old_saves()` | the saves the fuzzer corrupts, and old versions' saves to load |

**2. What every match is checked for** (WsgSim). A match that finishes is not a pass. It fails on:
- **Errors:** any script or engine error during the match. A `Logger` catches them; a GDScript error doesn't stop the
  game, it carries on wrong.
- **Bad positions:** NaN, or anything outside `bounds()`.
- **The score:** going down, or up by a step not in `score_steps()`.
- **The clock:** running backwards within a phase, jumping, or standing still while running.
- **Stuck bodies:** a body that is active, with its target more than 1.5 m away, and has hardly moved for 6 s.
- **No progress:** a body that is active and moving (over 2 m), but has got no closer to its target (by 0.5 m) for
  10 s. The target must stay put (within 1 m) and be a spot a body can stand on, in the bounds and clear of props.
  This is a body turning back and forth in front of a prop, which "stuck" does not see because it keeps moving.
  Sepak Takraw's fetcher froze this way in front of a bench.
- **The fetch behind a prop** (`targeted:fetch_behind_prop`, added to every smoke batch and nightly rotation):
  1. At 1 s, WsgSim picks a spot behind one of the venue's 3 largest props, in turn by seed. The spot is on the side
     away from the field's middle, or round it if that side is out or blocked, and clear of every prop.
  2. It calls your `fetch(spot)`. You put the ball there, dead, as a ball gone out would be (report it as not live in
     `ball()`), and send one body for it as your AI would.
  3. You return `{"who": that body's name, "seconds": the time it may take (default 20), "arrive": metres from the
     spot that count as there (default 1)}`.
  4. The body must get there in time, and never go into a prop on the way.

  Not wired (`{}`, the default), the match ends at once. Until **2026-11-04 12:00 UTC** the report notes it under
  Warnings; from then on it fails (`fetch: not wired`; the lead's decision). REQUIRED carries it from that time.

  Only spots a body can reach are offered: a flood fill from the field's middle over the floor, clear of the props, in
  the bounds and where `fetch_reach(p)` says yes. So a stadium whose stands ring the bowl is not asked to fetch from
  behind them (Hurling), and a court-bound game says its court in `fetch_reach` and is tested round the props on it
  (Pok Ta Pok). A game that cannot fetch at all returns `{"exempt": "<why, with the lead's word>"}`: noted, never
  failed. A targeted kind of your own can run the same case by setting `fetch_behind_prop: true` in its config.
- **Steering back and forth** (a warning, not a failure): WsgSolidProps counts a body changing sides round one prop
  4 times within 90 `steer` calls. It warns once per body and prop (`flip_warnings`, and a `push_warning`), and the
  report lists it under Warnings. The usual cause is a goal straight behind a long prop with the body's `memo` lost
  or rebuilt every frame (keep one `memo` per body for good), or a goal flipping sides. Walk such a body round the
  prop with `path()`.
- **Endless matches:** past `max_seconds`.
- **Props:** a body more than 2 cm into a prop, or the ball through one.
- **Feet and poses:** a planted foot slipping more than 2 cm in a step, or a T-pose or A-pose. A quarter of your
  WsgBodies are followed every frame.
- **Your `rules()`.**

A freeze, meaning an endless loop that no in-game check can interrupt, and a crash are caught by `sim_shard.sh`. It
records the match the batch was on and carries on from the next seed.

**3. Every random roll from the seed.** `sh tools/wsg/rng_lint.sh [folders]` (default `game/`) fails on any bare
`randf`, `randi`, `randf_range`, `randi_range`, `randfn`, `randomize`, `shuffle` or `pick_random` in gameplay code.
A call on a seeded generator (`rng.randf()`) passes. Hurling was bitten by one unseeded `randf`. Cosmetic-only lines
can be marked `# wsg-rng-ok: <why>`.

`sim.gd -- determinism --seeds N [--realtime]` runs each seed twice, the second at 1× real time with `--realtime`.
The states must match frame for frame, checked every 15 frames. A decision made on the wall clock is caught.

**4. Run it:**
```
sh tools/wsg/sim_shard.sh . "$OUT" --smoke --input                                # every push: minutes
sh tools/wsg/sim_shard.sh . "$OUT/3" --from 1 --count 2400 --shard 3/8 --input    # nightly, one of 8 shards
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- merge --out "$OUT" "$OUT"/*/
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- replay --failure "$OUT/failures/<sig>/<seed>.json"
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- menu --seeds 20 --steps 400 --saves
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- adopt "$OUT/failures/<sig>/<seed>.json"
```
- **Smoke:** 50 seeds of the general kinds, every targeted kind × 3 seeds, and every adopted case.
- **Nightly:** every tenth seed is a targeted case.
- `--input` lets WsgSimInput play the human side through your own input path:
  - stick sweeps, holds, circles and jitter;
  - taps, mashes and double taps;
  - pause and resume;
  - the app sent to the background and back;
  - the screen turned;
  - camera switches.

`$OUT` must be outside the project (`$RUNNER_TEMP`); the tool refuses a path inside it. `tools/wsg/sim_ci.yml` is the
workflow: a smoke job on push, and 8 nightly shards plus a merge job. Copy it, then set your game's folder.

**5. The report** is `SIM_REPORT.md` and `sim_report.json`. It gives:
- what ran: the count, the kinds, and seeds and configs in `results.jsonl`;
- failures grouped by signature (the message with its numbers taken out), ranked by how often × how bad, with example
  seeds and a replay command for each;
- balance: win rates, draws, scoring and length by each `balance_keys` value, with flags for the owner (equal sides
  far from 50/50, a dominant strategy, too many draws, hardly any scoring);
- speed: simulated seconds per wall second;
- what it cannot see.

**Change no balance without the owner's OK.**

**6. The fix-and-retest loop:**
1. Triage by the ranking. Fix the top signatures first and list the rest in your report.
2. For each one, replay it, find the root cause and fix it.
3. `adopt` the failing match into `res://tests/sim_cases.json`, so every smoke batch runs it from now on.
4. Write an owner-note test (§5.16) if the owner saw it.
5. Rerun smoke, then a broad batch.

Never weaken a check or bypass game logic to make it pass.

**7. Report to the lead after each batch:**
- what ran;
- bugs found;
- bugs fixed, with commits;
- remaining issues, ranked;
- balance flags;
- coverage gaps;
- speed.

Don't claim a pass you didn't run.

**What it cannot see:** how the game looks (animation quality), on-device stutter, frame and load times on the A16,
touch feel, audio as heard, and anything on the GPU. Those need a person, or the on-device diagnostics screen
(item #2, deferred).

**Speed target:** a 2,000-match nightly batch in under 2 hours wall-clock, and smoke under 10 minutes. These are the
defaults, so every game gets there without deciding separately:
- **16 nightly shards** (`sim_ci.yml`). A public repository runs 20 jobs at once, which leaves room for push CI.
- **Sampled pose** (`--full-pose` turns it off). Each match, a quarter of the bodies, a different quarter each seed,
  are posed in full: the planter's IK, the pose layers and the helpers. The others keep everything gameplay reads:
  - the animation, so root motion and the locomotor's state;
  - their bones;
  - their feet's contacts, and the footsteps those fire.

  This is `WsgBody.set_sim_full`. The feet and pose checks follow the full quarter. On the demo with 6 animated
  bodies, it took speed from 18× to 26×.
- **The match-length mix** (`--full-length` turns it off). A quarter of the matches play full length, so the ends of
  matches, extra time and penalties stay covered. The rest arrive with `config.short = true`: your `start()`
  shortens the halves, to a fifth on the demo, with every rule unchanged. Targeted matches play as you set them.
  Together with sampled pose, a match costs about a third as much on the demo.
- **The step.** `sim.gd -- fps-probe --seeds 12` plays the same seeds at 30, 20, 15 and 10 frames a second. It names
  the coarsest step whose outcomes all match 30's. If it names a coarser one, run batches with
  `FPS=<n> sim_shard.sh ... --fps <n>`. The demo's outcomes change at 20, so it stays at 30. A coarser step that
  changes outcomes is simulating a different game.

Measure and report your per-process speed (`speed` in the report) and the nightly wall-clock that results. Logic that
only advances with animation playback can't run faster than 1×; if that caps you, report it, and move that logic onto
the game clock.

**Adapter pitfalls (from Kho Kho and Hurling adopting it).**
- **Never change the config `start()` is given.** Shorten a copy. Kho Kho's first adapter shortened `cfg.turn_len` in
  place, so the saved config held the short length and its replay shortened it again; the replay diverged. WsgSim now
  hands `start()` a copy anyway. Read `config.short` in `max_seconds()` too.
- **`res://game/sim.gd` may already be taken** by your own numbers-only championship sim (Kho Kho, Hurling). Move it
  (Kho Kho: `game/score_sim.gd`; Hurling: `game/result_sim.gd`). A kept `class_name` means nothing else changes.
- **Say whether the match is paused** (`paused()`: 1, 0, or -1 for unknown). The input fuzzer then resumes a match
  your game paused when it was sent to the background, as a person taps Resume, and presses its own pause pair only
  from a known state. Pok Ta Pok's toggling pause key, pressed between a background pause and its resume, left 5 of
  13 matches paused for good ("endless").
- **Your own frame-rate auto tier must stand down in the sim.** At a fixed 30 frames a second it reads 30, below
  the threshold, and steps every match down. `WsgAutoTier` does this itself (`WsgAutoTier.off`, set by WsgSim and the
  world check). A game with its own auto tier checks `WsgAutoTier.off` too, or turns it off in its adapter (Pok Ta
  Pok does).
- **Long matches print a heartbeat.** A match prints `sim: <kind> seed N still playing` every 30 s of wall-clock, so
  `sim_shard.sh`'s HANG (120 s of silence = frozen) only catches real freezes. Before this, a 2,170 s Kho Kho match,
  127 s of wall-clock, was called frozen.

**Read poses inside `skeleton_updated` (since 1ef240f).** After a frame, the bones are back to the clip's pose: no
planted feet, no hips' lift, no pose layers. On the test hurler that is 14 cm out. Before this fix, WsgSim read the
feet and the T/A-pose there, so every slip it reported was the clip's own. It now reads them as the skeleton finishes
the drawn pose. Your own checks must do the same: connect to `body.skeleton.skeleton_updated`, or use
`WsgWorldRules.drive`.

**Pass your AI's asked-for velocity to `WsgLocomotor.drive`.** Pass the AI's wanted velocity, not the body's own. The
demo passed the body's own velocity as the wanted one, so a start from standing picked the walk's start clip up to a
jog. Its stride was too short for the body, and the feet slid 3–5 cm a step.

## 5.18 The world rules: wsg_world_check (every game, in CI)

`docs/WORLD_RULES.md` is the list. In every game and every mode:
- props are solid;
- the crowd sits or stands properly, facing the play;
- planted feet slide 2 cm a step at most, with no toe-up;
- no T-pose, A-pose or block figure appears;
- officials are real people, dressed as officials;
- key sounds stay crisp at a distance;
- the loading overlay is up in the tap's frame;
- the joystick is camera-relative on every camera;
- nothing licensed is in a Web build.

One entry point checks them all on your own code: `tools/wsg/world_check.gd`, vendored by `sync_foundation.sh`. Its
hooks are `res://game/world.gd`:

```gdscript
# res://game/world.gd
extends WsgWorldGame

func game_name() -> String: return "netball"
func prop_registry() -> String: return "res://game/prop_runs.gd"        # your prop_audit registry (§5.15)
func crowd_registry() -> String: return "res://game/crowd_venues.gd"    # your crowd_audit registry (§5.1)
func modes() -> Array: return ["match", "practice", "shoot-out", "watch AI"]
func start_mode(mode: String, parent: Node) -> void:                   # this call IS the tap: not awaited
	var menu := Main.new()                                              # your real start code, under PARENT
	parent.add_child(menu)
	menu.start(mode)                                                    # must put WsgLoading.cover up at once
func officials(mode: String) -> int: return 0 if mode == "practice" else 2
func walker(parent: Node) -> Array:                                     # one of your players, as in a match
	var p := Player.new(Team.HOME, 4)
	parent.add_child(p)
	return [p.body, p.loco]
func key_sounds() -> Array: return ["post", "whistle", "net", "score"]
func audio(parent: Node) -> WsgAudio: return Sound.make_audio(parent)  # yours, as you set it up
func stick_map() -> Callable: return Callable(Player, "stick_to_world")   # (stick, camera, body pos) -> world dir
func cameras(mode: String, root: Node) -> Array: return root.find_children("*", "Camera3D", true, false)
func set_tier(t: int) -> void:                                          # as the Settings screen does
	Game.settings.graphics = t
	WsgFoundation.tier = t
```

Some hooks have defaults:
- `find_bodies` and `find_officials` find every `WsgBody` and `WsgOfficial`, plus nodes in the group `wsg_official`.
- `play_seconds` is 6.

**From 2026-11-03 12:00 UTC a failing rule fails your build.** Before then the check reports the same failures but
exits 0 with a warning. That gives you the morning to write `world.gd` without turning a beta already in CI red.

**A rule you leave unwired fails** ("not wired"). A rule the owner has excused goes in `exceptions()` with their note:
`{"crowd": "2026-11-05: no crowd in practice (the owner)"}`. The report prints it.

**CI** (after your export, so the Web pack can be read):

```yaml
      - run: xvfb-run -a godot --path <game> --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world" --web-pck build/web/index.pck
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: world-check, path: "${{ runner.temp }}/world" }
```

Use `--only feet,pose,...` for a quick local run. `--web-pck` is only needed if you export for the Web.

The check writes `WORLD_CHECK.md`: one line a rule with what broke it, and what it measured. What each rule measures:

| Rule | What it measures |
|---|---|
| feet | Your walker driven along the match path (walk, jog, a quarter turn, run, stop). Each step's worst slip must be 2 cm at most. |
| pose | Every mode played after its loading, every body and official read as drawn. |
| officials | The count, a `WsgBody`, and a kit of their own (not a player's material or colour). |
| sounds | `WsgAudio.bright_kinds`. |
| loading | The overlay in the tap's own frame, then down. |
| joystick | `WsgNoteChecks.joystick` on each mode's cameras. |
| web | The Web presets' `exclude_filter`, plus the pack's file table. |
| props, crowd | Your `prop_audit` and `crowd_audit`, run by the check. |
| tiers | Every mode at Low, Medium and High. Each must keep the player's tier (never put it up), stay within the tier's 3D crowd and full-detail bodies, and, with a renderer, within `WsgFoundation.frame_budget` (triangles, draw calls). |

**Graphics tiers are enforced (item 3).** WsgFoundation owns the budgets:
- `BUDGETS` holds the triangles and draw calls a frame may draw, per profile and tier. `frame_budget()` returns them.
- `CROWD_AT_TIER` holds the 3D crowd quality each tier may build.
- `full_bodies()` is the number of bodies drawn in full.

`WsgCrowd3D` now asks `WsgFoundation.crowd_quality(quality)` and never builds more than the player's tier allows:
- a premium game's Low builds no 3D crowd (billboards only);
- a budget game's Low builds its small band;
- Close (3) is built only at High;
- a request above the tier is built at the tier's most, and recorded in `WsgFoundation.over_tier` with a warning.

So **a mode must not raise the tier itself.** Hurling's practice forced High and the 2,400-fan crowd: a 9.7 s start
on any phone. Build what the player's tier allows. If the owner lets a mode run higher, name their note in
`tier_exceptions()`. Tests that build a High or Close crowd set `WsgFoundation.tier = WsgFoundation.HIGH` first (the
foundation's crowd tests and notes now do). The frame budgets are set from Hurling's national stadium with about 15%
room (docs/BUDGET.md); send me your numbers if a venue of yours needs more.

**Turn off your own graphics step-down in world.gd.** world_check holds WsgAutoTier off, but a game's own guard (a
frame-rate check that lowers the tier) fires on a slow CI machine mid-check: Kabaddi's dropped to Low after the modes
had played, released its foundation bodies, and the walker read a toe 9.4 cm up. Switch it off where world.gd sets up
(Kabaddi: `Game.settings.auto_gfx = false`).

**Deferring a rule (only for a foundation fault, with the lead's or owner's word).** `deferred()` in your world.gd:
`{"feet": ["2026-11-06T12:00Z", "the lead, 2026-11-03: <why>"]}`. Until that time a failure of that rule is reported
DEFERRED with the reason, not failed; from it, it fails again. `WsgSimGame.deferred()` is the same for WsgSim's
checks. The feet rule itself is enforced for every game from **2026-11-04 12:00 UTC** (`RULE_FROM`; the walker's walk
read 2.1-2.2 cm on three games' rigs on 888e222, a foundation fault).

**`start_mode` must replace whatever the last call started, as a real tap does.** The tiers rule starts every mode
three times, one after another. Hurling's `start_mode` left the previous match drawing while the next one started, so
the tiers rule measured both: 524k triangles and 154 draw calls at Low. Free or replace the previous mode in your own
start code, as your menu does when a player taps. Better still, build everything under the `parent` you are given:
the rule frees that parent after each mode. Each tiers line now says how many triangles were left outside that parent.
A number that grows from mode to mode is the last mode still drawing.

Each mode the pose, officials, loading and joystick rules play is stopped and hidden once played (its cameras kept),
so it no longer runs and draws under the later rules (Kabaddi's run passed 50 minutes on software GL). A `cameras()`
that stopped the match itself to work round it can go.

The foundation's own world is `tests/world_demo/world.gd`. It passes every rule, and `tests/world_check_test.sh` shows
that each fault fails its own rule and only that rule.

**The planter keeps feet to 2 cm a step (since 1ef240f). Sync before you wire `feet`.**
- It holds the ball of the foot once it is down.
- Heel-off rolls over the ball.
- A foot beyond the leg's reach takes a step of its own rather than sliding.
- A planted foot holds its direction up to 40° of twist.

On the test hurler's match path, the worst step is now:

| | walk | jog | jog, turned | run | stop |
|---|---|---|---|---|---|
| Worst step (cm) | 1.5 | 0.3 | 0.9 | 0.2 | 1.0 |

## 5.19 The release gate (every game, before every release)

`tools/wsg/release_gate.py` checks the built APK (and the Web build) before a release goes up, and fails the job if
any of these fail:

| Check | What it requires |
|---|---|
| signature | Every signer's certificate SHA-256 is the owner's key `6F:23:A9:…:7B:A3`. apksigner verifies when the runner's Android build-tools have it; otherwise the certificates are read from the APK's v1/v2/v3 signatures. |
| version | `project.binary`'s `application/config/version` is the release's version, and the APK's file name carries it. |
| licensed | `mobility.res` and `actorcore.res` are in the APK. Nothing licensed is in the Web build or pack, or in the downloadable High pack (`--pack`). |
| clean | No tests, docs, tools, audit output or contact sheets in the export. |
| textures | No texture over 2 MB that isn't GPU-compressed (ETC2/ASTC). |
| files | No non-game files (`.blend`, `.psd`, `.fbx`, `.zip`, `.py`, `.sh`, `.md`, `.log`…), and no file of 64 KB or more twice. |
| size | Never fails. The size against the previous release, and the 20 files that grew most. |

```yaml
      - name: Release gate
        run: |
          gh release download <your-beta-tag> -p '*.apk' -O "$RUNNER_TEMP/previous.apk" || true
          python3 <game>/tools/wsg/release_gate.py --apk build/<game>-$VERSION.apk --version "$VERSION" \
            --web build/web/index.pck --previous "$RUNNER_TEMP/previous.apk" --out "$RUNNER_TEMP/gate"
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: release-gate, path: "${{ runner.temp }}/gate" }
```

It runs on GitHub's Ubuntu runner (`python3`, `cryptography` and the Android SDK's apksigner are already there).
`--allow gate_allow.txt` excuses paths; each line is `<glob>`, a tab, then the owner's note. The report lists them.

Warnings name the foundation's test-time scripts in your export: `prop_audit`, `note_checks`, `owner_note`, `sim/`
and `world/`. Exclude them in your Android preset's `exclude_filter` unless your game uses them. Keep `note_checks`
if you map the stick with `WsgNoteChecks.stick_world`.

Checked on Kho Kho Rush 0.12.4-beta (the release APK): every check passes. The key is the owner's in v1, v2 and v3;
the largest texture that isn't GPU-compressed is 1.6 MB; there are no duplicates.

## 5.20 The downloadable High pack: WsgAssetPack (games with a High pack)

High's extra assets (8K skies, 4K pitch textures, the HD player textures) can come as a separate download instead of
in the APK. The pack is a Godot `.pck`, published as a public GitHub release asset next to the APK; the owner has
OK'd this, since the same assets ship in the APK today. **The pack may carry only our own, Meshy and CC assets: never
licensed MoCap Online, ActorCore or Mixamo-derived data, which ship only inside the APK.** The release gate fails a
pack that holds any (`--pack`).

**CI**, before the APK is exported, because the APK carries the pack's checksum:

```yaml
      - name: High pack
        run: |
          godot --headless --path <game> --export-pack "High pack" build/<game>-$VERSION-high.pck
          SHA=$(sha256sum build/<game>-$VERSION-high.pck | cut -d' ' -f1)
          SIZE=$(stat -c %s build/<game>-$VERSION-high.pck)
          URL="https://github.com/joshnason8-lab/ghost-kit-pages/releases/download/<tag>/<game>-$VERSION-high.pck"
          printf '{"url":"%s","sha256":"%s","size":%s,"name":"high-%s.pck"}' "$URL" "$SHA" "$SIZE" "$VERSION" > <game>/wsg_pack.json
      # ... export the APK (wsg_pack.json goes in it), run the release gate with --pack, upload both to the release
```

The "High pack" preset includes only the High assets (its `include_filter`), and your Android preset excludes them.
Name the file `*.pck`: Obtainium's default filter takes the `.apk` from the release and leaves the pack, which the
game fetches itself.

**In the game**, when the player picks High (or at the first start on a High phone):

```gdscript
var pack := WsgAssetPack.from_manifest()            # res://wsg_pack.json
if pack and not pack.mount():                       # here and checked already: mounted
	var ld := WsgLoading.cover(menu, [high_button], {"title": "Downloading High graphics"})
	ld.step("Downloading", func(): await pack.fetch(ld))
	await ld.run()
	await ld.done()
	if pack.error != "":
		show_message(pack.error)                    # stay on Medium; it resumes next time
```

How `fetch` behaves:
- It follows GitHub's redirect.
- It resumes a part already downloaded (a Range request), so a dropped connection or a closed app costs nothing.
- It checks the SHA-256 and mounts the pack with `load_resource_pack(..., replace_files = true)`, so its files
  replace the APK's.
- On a bad checksum, it deletes the download and starts again next time.

Call `mount()` at every start, before anything High is loaded. `remove()` frees the space (Settings).

The pack's assets' licences go in the shared credits screen (item 8).

`tests/asset_pack_test.gd` runs against a local server: a download dropped halfway resumes with a Range request and
fetches only the rest; the pack mounts and its file reads; the next start finds it without downloading; a wrong
checksum is refused and the download deleted.

## 5.21 The common UI (every game; themed with your WsgBroadcastTheme)

The same screens and feel in every game, each wearing your game's `WsgBroadcastTheme` (colours, type):

| What | How |
|---|---|
| **Licences and credits** | `WsgCredits.new(theme, your_sections)`, where your sections are `[{"title", "body"}]`; paragraphs are split on a blank line. It adds the High pack's credits (`res://wsg_pack.json` `"credits"`), the foundation's (the motion capture) and the Godot Engine's notices. It is built a few paragraphs a frame and never on a thread: Kabaddi's threaded one froze and sometimes crashed. On this machine: 453 paragraphs over 106 frames, the longest 11 ms. |
| **Watch AI** | `WsgWatchSetup.entry_button(theme)` on the home screen opens `WsgWatchSetup.new(theme, teams, venues)`, which emits `watch(home, away, venue)`. Show the match with `WsgSpectator` (§5.11): its overlay now has a **Skip** button over every cut-away and replay, and a tap anywhere skips (`tap_to_skip`). A game with its own HUD calls `spec.skip_button(theme)`. |
| **Haptics** | `WsgHaptics.play("tagged" / "teammate_tagged" / "tag" / "score" / "bonus" / "hit" / "whistle" / "win" / "tap")`: one pattern for each moment, the same in every game. `"bonus"` is the quick double pulse. Add your own with `WsgHaptics.patterns["dive"] = [[30, 0.7]]`. |
| **Settings** | `WsgSettings.load_all()` at boot: the tier, haptics and volumes, from `user://wsg_settings.cfg`. `WsgSettings.screen(theme, {"buses": ["Effects", "Crowd", "Music"]})` covers Graphics (Low, Medium, High), a slider per bus, the joystick (side, size), Vibration and Back. `applied(key, value)` tells you what changed (a new tier: rebuild); read `WsgSettings.get_value("joystick_side")` for your stick. |
| **Tutorial prompts** | `var tips := WsgTutorial.new(theme)`, then `tips.add(id, text, show_when, done_when)`. A tip shows when its moment comes and goes when the player has done it or taps "Got it". It never shows again; "Skip tips" turns them all off. `WsgTutorial.reset()` is "Show tips again". |

`tests/ui_test.gd` covers it all:
- the credits are built over many frames with every section in;
- the bonus is a double pulse, and haptics off is silent;
- the settings are applied, saved and read back, and wear the theme;
- Skip shows over a moment and ends it, and a tap skips;
- a tip shows at its moment, goes when done and never comes back;
- Watch starts the match that was picked.

**Note:** a test that sets `WsgHaptics.sink` to a lambda must set it back to `Callable()`. A lambda left in a static
var outlives its script and corrupted Godot's heap on quit.

## 5.22 The asset lint (every game: at import and in CI)

What is wrong with an asset is found when it is imported, not at the release gate or by a player.

| Check | Fails on |
|---|---|
| textures | An imported texture over 2 MB that isn't GPU-compressed (the release gate's rule, earlier). A warning for a texture on a model of 512 px or more without mipmaps. |
| lods | An imported model with `meshes/generate_lods=false` and over 5,000 triangles. |
| licensed | A raw FBX committed; anything under `addons/wsg_foundation/data/`; files named mobility, actorcore or mixamo (`.res`, `.tres`, `.anim`, `.exr`, `.png`); and the data folder not git-ignored. |
| toe_up | Your player's model (world.gd's `walker()`) rests toe-up (`WsgFootFlat.sole_tilt` ≥ 2°) and its body has no `WsgFootFlat`. |
| props | A prop-shaped mesh in a venue (on the ground, 0.3–3.5 m tall, under 12 m across) that no solid prop covers and that isn't opted out (`wsg_solid` false with a reason). Your prop registry builds each venue. |

**In the editor:** Project Settings → Plugins → **WSG Foundation** checks each texture and model as it is imported and
shows a toast.

**In CI:**

```yaml
      - run: godot --headless --fixed-fps 30 --path <game> -s res://tools/wsg/asset_lint.gd -- --out "$RUNNER_TEMP/lint"
```

It writes `ASSET_LINT.md`. An owner-excused asset goes in `res://asset_lint_allow.txt`: a glob, a tab, then the
owner's note.

`tests/asset_lint_test.gd` plants each fault in fixtures and shows that its check finds it and passes the fixed one.
The foundation itself lints clean: 10 imports, 333 committed files with the data folder ignored, the test hurler at
1.9° (flat), and the test court's props all registered.

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

Your workflow checks your copy in a step after checkout:
```yaml
      - name: Shared foundation (fails without a required commit)
        run: sh <game>/tools/wsg/check_foundation.sh
```
**It fails when you lack a required commit.** These are the foundation commits listed in `foundation/REQUIRED` on its
branch. Today they are:
- 2cd59a7: key hits crisp at a distance;
- 0422175: solid props;
- ad83891: loading v2;
- a24408b: the warm-up fix.

You pass if your `VERSION` comes from that commit or later, or if your code carries the commit's marker line (a fix
you took another way). Kabaddi nearly shipped on edebcd5 without loading v2.

If you truly must ship without one, set `FOUNDATION_REQUIRED_SKIP: "<commit>:<the reason>"` on the step; the log prints
the reason. Being merely behind the branch's latest is still only a warning.
The foundation's own session pushes each update to every adopted game's pilot or game branch, under that game's
rules (a pilot branch until the owner has passed the game's pilot), and says so to the lead, who checks each release.

**A required commit can take effect later.** If its date in REQUIRED is a UTC time, such as `2026-11-03T12:00Z`, it
is required from then. Before that, `check_foundation.sh` only warns, so a beta already in flight isn't turned red;
sync the commit into your next build. Until its time the line starts with `#from` and a tab, which an older copy of
`check_foundation.sh` skips as a comment; at its time it becomes a plain line. 1ef240f (the planter, and WsgSim reading the drawn pose) is required from
2026-11-03 12:00 UTC.

## 7. Check before you push

```
godot --headless --path <game> res://tests/compile_check.tscn     # or your compile check
<your test runner>                                                # nothing of yours should change
```
and look at it: a run, a stop, a backpedal, your signature move, the crowd at a score. The foundation's own tests
(`foundation/tools/run_tests.sh` on its branch) cover the rig, the locomotion's foot slide, the crowd and officials.
