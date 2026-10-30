# Adopting the shared foundation (one task per game)

The foundation draws your players, officials and crowd with one rig, motion-capture locomotion and a 3D crowd,
while **your game keeps everything it already does**: your player code still poses your own 17-bone body every frame
(swings, catches, dives, signals), still measures off it (where the stick head is, where the hands are), and the
foundation draws a new body that runs on mocap and takes your moves from your body. Hurling Heroes is the pilot:
`claude/hurling-foundation-pilot` shows every change below in a real game (search it for `FoundationLink`).

Kho-kho is the exception (it has a 23-bone Mixamo body with an AnimationPlayer, no 17-bone pose): skip step 4's
legacy pose and drive `WsgBody` directly; ask the foundation session.

## 0. What you get, and what stays

| | Low | Medium | High |
|---|---|---|---|
| players and officials | the rig, the low mesh | the rig | the rig |
| locomotion | mocap, feet planted | the same | the same |
| crowd | your billboards (unchanged) | 3D fans near the action (≈1,200), billboards beyond | 3D fans (≈3,000), billboards beyond |

A build without the licensed data (a fork, a computer without access) is exactly your game as it is today.

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
candy-wrap, collapsing joints, toes up, a hand that cannot close; with a long coat it may fail at the knees and
elbows - tell the foundation session).

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
`legacy.body_pose = reader.body_space(["RightShoulder", "RightArm", "RightForeArm", "RightHand"])`. And place anything
drawn in the hand when the skeleton has its final pose (`body.posed.connect(...)`): during the frame Godot reports
bones without their modifiers (the layer, the grip).

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
- `seated`: true, false, or one bool per spot (on a seat: they sit and get up; on a terrace: they stand). A spot is
  the fan's feet; a seated fan's hips go 0.34 m behind it, over the seat (a step 0.42 m above the feet is right).
- `focus`: where the camera mostly looks (the 3D fans go nearest it).
- In your `Crowd.set_excite(k)`: also `WsgCrowd3D.set_excite(k)`; in `Crowd.set_light(k)`: `WsgCrowd3D.set_light(k)`.
- Each frame: `WsgCrowd3D.set_tension(building_pressure)` (the keen ones get up before the score) and
  `crowd3d.watch_ball(ball_position)`.
- Rhythmic clapping playing: `crowd3d.clap(claps_per_second, unison_0_to_1, seconds)` (Kabaddi has these numbers).

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
