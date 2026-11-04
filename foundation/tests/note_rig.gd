extends RefCounted
## The foundation's owner-note tests' shared stage: the test hurler (the owner's own model) on the rig with the
## licensed locomotion, driven along a path as a game drives its players, a callback each frame once the pose is
## final. (Not a note itself: tests/owner_notes/ holds only notes.)


static func have_clips() -> bool:
	return FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res")


## [body, locomotor], the hurler standing at the origin, in the tree.
static func hurler(tree: SceneTree) -> Array:
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var body := WsgBody.new(ch)
	tree.root.add_child(body)
	var loco := WsgLocomotor.attach(body)
	await tree.process_frame
	return [body, loco]


## Drives BODY along SEGMENTS - [seconds, velocity wanted (Vector2: x, z; m/s), facing (degrees; NAN: the way it
## moves)] - accelerating and stopping as a player does; ON_FRAME(t: float, segment: int) after each frame's final
## pose (WsgWorldRules.drive, the world check's own driver).
static func drive(tree: SceneTree, body: WsgBody, loco: WsgLocomotor, segments: Array, on_frame: Callable) -> void:
	await WsgWorldRules.drive(tree, body, loco, segments, on_frame)


## A match's moves: standing, a walk, a jog with a quarter turn, a run, a stop, standing again.
static func match_path() -> Array:
	return [[1.5, Vector2.ZERO, 0.0], [2.5, Vector2(0, 1.3), NAN], [2.0, Vector2(0, 3.5), NAN], [2.0, Vector2(3.5, 0), NAN],
		[2.5, Vector2(6.0, 0), NAN], [1.5, Vector2.ZERO, NAN], [2.0, Vector2.ZERO, NAN]]
