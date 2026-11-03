# World rules

These are the rules every World Stage Games world keeps, in every game and every mode. Each comes from something the owner saw. Each is checked in every game's CI by one entry point, **wsg_world_check** (`tools/wsg/world_check.gd`). It runs on the game's own code through its `res://game/world.gd`, a `WsgWorldGame`; ADOPTING.md §5.18 covers the setup.

How a rule is judged:

- A rule the game has not wired **fails** as "not wired". An unchecked rule is not a kept one.
- The game's `exceptions()` can excuse a rule, but only by naming the owner's note that allows it. The report shows the excuse with the note.
- A measure is never loosened to make a rule pass. Fix the world, not the yardstick.

| Rule | What the owner sees | The check | Hook |
|---|---|---|---|
| **props** | "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items." | The game's `prop_audit` over Watch-AI matches at every venue fails on any body more than 2 cm into a prop and on any ball step through one. | `prop_registry()` |
| **crowd** | "make sure the crowd is sitting properly ... facing the right direction, standing properly"; "The crowd is still 'in' the seats"; "facing away from the game" | The game's `crowd_audit` audits every fan at every venue: seated on the seat (not in it), soles on the floor, facing the play, standing properly. It also writes a contact sheet. | `crowd_registry()` |
| **feet** | "The feet do not seem to slide or skate thats great" (kept so); toes up when standing (Hurling 0.20) | One of the game's players is driven along the match path: standing, walk, jog, a quarter turn at a jog, run, stop, standing. In every step the planted foot (the slower of heel and ball, as drawn) slides **2 cm at most**. A standing foot's toe is **1 cm** off the ground at most. The player is never in a T- or A-pose. | `walker()` |
| **pose** | "base position is still like an A pose"; "looks like a block figure" | Every mode is played after its loading. No body or official is drawn in a T- or A-pose (read as drawn, inside `skeleton_updated`), and none is a block figure (primitive shapes, or no skinned body). | `modes()`, `start_mode()` |
| **officials** | "Referees still look awful ... can we use the player graphics for them?" | Each mode has the officials it should. Each one is a person on the rig (a `WsgBody`, skinned, never a T- or A-pose), dressed in a kit of their own, not a player's. | `officials()` |
| **sounds** | "the post clang can't be heard" (twice) | Every key moment's sound kind (the ball off the post, a tag, the whistle, a score) stays crisp at a distance: it is in `WsgAudio.bright_kinds`, brought within `bright_distance` with its highs kept. | `key_sounds()`, `audio()` |
| **loading** | "when you click start game there is a loading delay ... users might think the game has frozen" | For every mode, the tap puts the loading overlay up in the tap's own frame (**one frame at most**), and it comes down when the mode is ready. | `modes()`, `start_mode()` |
| **joystick** | "When switching to a camera angle that is not alongside the court the joystick movement is all wrong." | On every camera of every mode, with the body at the screen's centre, edges and corners, the game's own stick mapping, pushed 8 ways, moves the body within **25°** of the camera's way. | `stick_map()`, `cameras()` |
| **tiers** | Hurling's practice forced High and the 2,400-fan Close crowd on every phone, so a start took 9.7 s. | Every mode runs at each tier the player can choose (Low, Medium, High). At each one the mode must never put the tier up, must stay within the tier's 3D crowd budget, and draws at most `full_bodies()` bodies in full. With a renderer (xvfb, opengl3), a frame also stays within `WsgFoundation.frame_budget` (triangles, draw calls). The crowd is capped at run time too: `WsgFoundation.crowd_quality`. A mode the owner lets run higher names their note in `tier_exceptions()`. | `set_tier()`, `modes()` |
| **web** | (licence) "Never ... upload them anywhere public." | Every Web preset in `export_presets.cfg` excludes `addons/wsg_foundation/data/*`. When given `--web-pck`, the exported pack must hold no licensed data: no `wsg_foundation/data/`, no `mobility.res`, no `actorcore.res`. | none |

## The numbers behind the feet rule (the foundation, 2026-11-03)

The test hurler on the licensed clips was driven along the match path. The table gives the worst step in cm, measured with `WsgNoteChecks.foot_slip` on the drawn pose.

| | walk | jog | jog, turned | run | stop |
|---|---|---|---|---|---|
| Before (planter holds the ankle only) | 1.1 | 2.4 | 3.2 | 2.4 | 1.2 |
| Now (ball held, heel-off over the ball, steps when out of reach, twist held) | 1.5 | 0.3 | 0.9 | 0.2 | 1.0 |

WsgSim's demo game is a crude AI. It snaps its facing to its velocity, turning up to 265° a second on a planted foot. Across 40 seeds (80 sampled bodies), 15 matches had a step over 2 cm: most 2.1–3.1 cm, a few up to 4.6 cm, and one 7.0 cm.

The two traced so far are steep heel strikes, the toe 7–10 cm up as the heel lands, during the turns. The toe sweeps 2–3 cm while still in the air as the foot flattens about the held ankle. The measure counts it from the frame after the heel touched, then the heel lifts. A real game turns its players at a human rate.

## Running it

```
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"
    [--only feet,pose,...] [--web-pck build/web/index.pck]
```

It writes `WORLD_CHECK.md` and `world_check.json` to `--out`, which must be outside the project. It exits 1 if any rule fails or is not wired.

The foundation's own world is `tests/world_demo/world.gd`. `tests/world_check_test.sh` shows that each fault a game could have fails its rule and only that rule.
