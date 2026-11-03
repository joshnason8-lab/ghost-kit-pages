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
## "active": bool (in play and meant to be moving), "target": Vector3 (where its AI sends it; INF: none)}].
func bodies() -> Array:
	return []


## The ball now: {"pos": Vector3, "radius": float, "live": bool} (empty: no ball, or none in play).
func ball() -> Dictionary:
	return {}


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
