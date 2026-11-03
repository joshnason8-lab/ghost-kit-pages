class_name WsgSimGame
extends RefCounted
## A game's side of WsgSim (the automated match simulator): its matches built and run by its own production code
## (its movement, AI, ball, rules and animation-driven logic: only the drawing is skipped), its varied conditions,
## its sport's rules. The game writes one of these (res://game/sim.gd, extends WsgSimGame), building on what it
## already has (match_sim, user_bot, score_check, test_runner) - not a second copy of its game. ADOPTING.md §5.17.
## Everything has a default except start(), state() and config(); fill in what the game has.

## The game's name in reports.
func game_name() -> String:
	return "game"


## The kinds of match the game can set up: "random" (anything goes), "extreme" (the edges: the strongest against the
## weakest, every attribute at its limit, the longest and shortest matches, every setting at its end), and its
## targeted cases ("targeted:scoring", "targeted:timer", "targeted:possession", "targeted:collisions",
## "targeted:completion"...: situations that test one rule hard). The smoke batch runs every targeted kind.
func scenarios() -> Array:
	return ["random"]


## One match's conditions for KIND, drawn from RNG only (team strengths, players' attributes, AI strategies, match
## settings, venue, weather, the human's team...). Reported with every failure: the seed and this replay it.
func config(_kind: String, _rng: RandomNumberGenerator) -> Dictionary:
	return {}


## Builds the match from CONFIG and starts it, every random roll of it from SEED (its own RandomNumberGenerator(s),
## seeded here: tools/wsg/rng_lint.sh finds bare randf/randi/shuffle in gameplay code). In the tree; may await.
## Returns its root (freed by stop()).
func start(_config: Dictionary, _seed: int, _tree: SceneTree) -> Node:
	return null


## The match now: {"score": [home, away], "clock": seconds shown, "clock_running": bool, "phase": String (a half, a
## break, a shoot-out...), "possession": int (-1 none), "finished": bool}. Any other keys are logged.
func state() -> Dictionary:
	return {}


## What happened since the last call (logged; the last few hundred kept with a failure): [{"type": "goal", ...}].
func events() -> Array:
	return []


## Every body on the field now: [{"name", "pos": Vector3 (feet), "radius", "height", "body": WsgBody (or null),
## "active": bool (in play and meant to be moving), "target": Vector3 (where its AI sends it; INF: none)}], and
## optionally "pose_excuse": why this body's arms are out straight by design now (a pole turn: one hand on the pole,
## the other out) - its T/A-pose readings are counted in the result, not failed. Keep the order the same all match: the
## sampled quarter is chosen by place in this list.
func bodies() -> Array:
	return []


## The ball now: {"pos": Vector3, "radius": float, "live": bool} (empty: no ball, or none in play).
func ball() -> Dictionary:
	return {}


## Checks put off for this game until a time, each with the lead's or owner's note: {"foot slip": ["2026-11-06T12:00Z",
## "the lead, 2026-11-03: planter slips 3.5-4.1 cm under our AI; foundation fix pending"]}. Until then a failure of
## that check is reported as deferred (under Warnings, with its reason), not failed; from then on it fails again. Only
## for a foundation fault the game cannot fix itself, and only with the lead's or owner's word.
func deferred() -> Dictionary:
	return {}


## The fetch-behind-prop case (WsgSim.FETCH_KIND, in every smoke batch): WsgSim puts SPOT behind one of the venue's
## largest props (the side away from the field's middle, where a body can stand) and the game sends the ball (or what
## its bodies fetch) there, dead, as a ball gone out would be, and one of its bodies to fetch it as its AI would.
## Returns {"who": that body's name (as bodies() gives it), "seconds": how long it may take (WsgSim.FETCH_S),
## "arrive": m from SPOT that counts as there (WsgSim.FETCH_ARRIVE_M)}; {}: not wired (the match ends, noted, no fail).
## The body must get there within the time, never into a prop on the way (Sepak Takraw's fetcher froze, turning back
## and forth in front of a bench).
func fetch(_spot: Vector3) -> Dictionary:
	return {}


## Where this game's bodies may go to fetch (the fetch case offers only spots reachable from the field's middle, over
## the floor, clear of the props, where this says yes): a court-bound game says its court, so it is tested round the
## props on it. A game that cannot fetch at all returns {"exempt": "<why, with the lead's word>"} from fetch(): noted,
## never failed.
func fetch_reach(_p: Vector3) -> bool:
	return true


## The venue's solid props (WsgSolidProps), or null.
func solid() -> WsgSolidProps:
	return null


## Where anything may ever be (a body or the ball outside it is a bug).
func bounds() -> AABB:
	return AABB(Vector3(-200, -5, -200), Vector3(400, 60, 400))


## How much one side's score may go up at once (hurling: [1, 3]; netball: [1]); it never goes down.
func score_steps() -> Array:
	return [1]


## A match must be finished by this many simulated seconds (an endless match fails).
func max_seconds(_config: Dictionary) -> float:
	return 3600.0


## The sport's own rules, checked every frame: what is wrong now ([] if nothing).
func rules() -> Array:
	return []


## The match's outcome, at its end: {"winner": 0 | 1 | -1 (a draw), "score": [..], ...anything worth totting up}.
func result() -> Dictionary:
	return {}


## What the balance report groups by for this match (team strengths equal or not, each side's AI strategy, the
## venue...): {"fair": bool (equal sides: a win rate far from half is a flag), "strategy_home": "press", ...}.
func balance_keys(_config: Dictionary) -> Dictionary:
	return {}


## Frees the match.
func stop() -> void:
	pass


## Is the match paused now (the pause menu up)? 1 yes, 0 no, -1 the game does not say. The input fuzzer resumes a
## match the game paused when sent to the background, as a person taps Resume on coming back, and presses its own
## pause and resume only from a state it knows (Pok Ta Pok: its pause key toggles, and a background pause in between
## left the match paused for good - "endless").
func paused() -> int:
	return -1


## The human's side (WsgSimInput plays it): -1 for an AI-only match.
func human_team() -> int:
	return -1


## The input actions a human uses (InputMap names), for the input fuzzer.
func input_actions() -> Array:
	return []


## The human's stick, as the game's own joystick would give it (x right, y down; length 0..1). True if the game took
## it (a touch joystick the game draws); false: WsgSimInput sends it as a gamepad's left stick instead.
func stick(_v: Vector2) -> bool:
	return false


## The match's cameras, and switching to one (the joystick on every camera).
func cameras() -> Array:
	return []


func set_camera(_i: int) -> void:
	pass


## The menus: the root screen built (main menu), in the tree; whether a match is on now; any invariant broken.
func menu_start(_tree: SceneTree) -> Node:
	return null


func in_match() -> bool:
	return false


func menu_check() -> Array:
	return []


## The save files the game reads at start (the fuzzer corrupts them, and swaps in old versions' samples).
func save_paths() -> Array:
	return []


func old_saves() -> Array:
	return []
