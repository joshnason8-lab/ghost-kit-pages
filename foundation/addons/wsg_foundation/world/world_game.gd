class_name WsgWorldGame
extends RefCounted
## A game's side of wsg_world_check (docs/WORLD_RULES.md: the rules every game's world keeps, checked in its CI):
## res://game/world.gd extends this and fills in its hooks from its own code - the real game, not a stand-in. A rule
## whose hook is not filled in FAILS as "not wired" (an unchecked rule is not a kept one), unless exceptions() names
## the owner's note that excuses it. ADOPTING.md §5.18.
##
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"


## The game's name in the report.
func game_name() -> String:
	return "game"


## Rules put off for this game until a time, each with the lead's or the owner's word: {"feet": ["2026-11-06T12:00Z",
## "the lead, 2026-11-03: foundation planter on our walker, Foundation owns"]}. Until then a failure of that rule is
## reported as deferred (with the reason), not failed; from then on it fails again. For a foundation fault the game
## cannot fix itself (WsgSimGame.deferred is the same for WsgSim's checks).
func deferred() -> Dictionary:
	return {}


## Rules the owner has excused for this game: {rule id: "the owner's note that allows it (date, words)"}. Reported as
## excused, with the note; never silently skipped.
func exceptions() -> Dictionary:
	return {}


## props: the game's tools/prop_audit.gd registry (res://..., its venues() and run()); "" not wired.
func prop_registry() -> String:
	return ""


## props: [matches, seconds] a venue (CI's budget).
func prop_args() -> Array:
	return [2, 60]


## crowd: the game's tools/crowd_audit.gd registry (res://..., its venues()); "" not wired.
func crowd_registry() -> String:
	return ""


## Every way the game starts play from its menus ("match", "practice", "shoot-out", "tutorial", "watch AI"...): each is
## started, its loading watched, its bodies, officials and cameras checked.
func modes() -> Array:
	return []


## Starts MODE as the player's tap on its button does - this call is the tap, made in the tap's frame and not awaited:
## the game's own start code, under PARENT (a 1280x720 SubViewport standing in for the screen). The loading overlay
## (WsgLoading.cover) must be up when it returns.
func start_mode(_mode: String, _parent: Node) -> void:
	pass


## Seconds of each mode played after its loading ends (bodies, officials, poses watched).
func play_seconds(_mode: String) -> float:
	return 6.0


## officials: how many match officials MODE has on the field (0: none); -1 not wired.
func officials(_mode: String) -> int:
	return -1


## The officials now under ROOT (default: every WsgOfficial, and every node in the group "wsg_official").
func find_officials(root: Node) -> Array:
	var out := root.find_children("*", "WsgOfficial", true, false)
	for n in root.get_tree().get_nodes_in_group("wsg_official"):
		if root.is_ancestor_of(n) and not out.has(n):
			out.append(n)
	return out


## The players (and every other body) now under ROOT (default: every WsgBody not inside an official). Return only the
## bodies drawn now: one hidden on purpose (a substitute off the field) has no drawn person and reads as a block figure
## (Floorball).
func find_bodies(root: Node) -> Array:
	var offs := find_officials(root)
	return root.find_children("*", "WsgBody", true, false).filter(func(b: Node) -> bool:
		for o: Node in offs:
			if o == b or o.is_ancestor_of(b):
				return false
		return true)


## pose: why BODY's T- or A-pose now is by design ("pole turn: one hand on the pole, the other arm out"), or "" if it is
## not - as WsgSimGame.bodies()' "pose_excuse". Counted with its reason in the pose rule, not failed. Only for a pose
## the lead or owner ruled designed.
func pose_excuse(_body: Node) -> String:
	return ""


## feet: one of the game's players as it plays (its character, scale and locomotor set up as in a match), standing
## at the origin under PARENT: [WsgBody, WsgLocomotor]; [] not wired. It is driven along the match path (walk, jog,
## a turn, a run, a stop).
func walker(_parent: Node) -> Array:
	return []


## feet_low: what draws the players at Low (the owner plays at Low): "foundation" if it is the same WsgBody the walker
## measures, or the game's own body there - [body (Node3D, standing at the origin under PARENT), drive (Callable(dt:
## float, velocity: Vector3, facing: float): moves and poses it one frame, as the game does), feet (Callable() -> [left
## ankle, left toe, right ankle, right toe], world, as drawn)]. null: not wired (deferred until 2026-11-08 12:00 UTC,
## failed from then). The feet rule's path and bounds, on that body.
func walker_low(_parent: Node) -> Variant:
	return null


## sounds: the kinds of sound the game plays at its key moments (the ball off the post, a tag, the whistle, a score):
## each must stay crisp at a distance (WsgAudio.bright_kinds). [] not wired.
func key_sounds() -> Array:
	return []


## The game's WsgAudio as it sets it up (default: the foundation's).
func audio(parent: Node) -> WsgAudio:
	var au := WsgAudio.new()
	parent.add_child(au)
	return au


## tiers: puts the game at graphics tier T as the player's Settings choice does (default: WsgFoundation.tier = T; a game
## that keeps its own setting sets that too, and must hand it to WsgFoundation.tier).
func set_tier(t: int) -> void:
	WsgFoundation.tier = t


## tiers: modes the owner lets run above the player's tier: {mode: "the owner's note (date, words)"}.
func tier_exceptions() -> Dictionary:
	return {}


## joystick: the game's own stick-to-world mapping, Callable(stick: Vector2 (x right, y down), camera: Camera3D,
## at: Vector3 (the body)) -> Vector3 (world direction); Callable() not wired.
func stick_map() -> Callable:
	return Callable()


## The cameras MODE uses under ROOT, each set as in play (its broadcast, end-on, overhead, behind-the-player... views):
## the stick must move the body the camera's way on every one.
func cameras(_mode: String, _root: Node) -> Array:
	return []
