extends RefCounted
## The foundation's owner-note tests' shared stage: the test hurler (the owner's own model) on the rig with the
## licensed locomotion, driven along a path as a game drives its players, a callback each frame once the pose is
## final. (Not a note itself: tests/owner_notes/ holds only notes.)

const DT := 1.0 / 30.0
const ACCEL := 9.0
const DECEL := 12.0


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
## pose.
static func drive(tree: SceneTree, body: WsgBody, loco: WsgLocomotor, segments: Array, on_frame: Callable) -> void:
	var vel := Vector2.ZERO
	var pos := body.position
	var t := 0.0
	var facing := 0.0
	for si in segments.size():
		var seg: Array = segments[si]
		var end := t + float(seg[0])
		while t < end:
			var want: Vector2 = seg[1]
			var lim := (ACCEL if want.length() > vel.length() else DECEL) * DT
			vel = vel.move_toward(want, lim)
			if is_nan(float(seg[2])):
				if vel.length() > 0.3:
					facing = atan2(vel.x, vel.y)
			else:
				facing = deg_to_rad(float(seg[2]))
			pos += Vector3(vel.x, 0, vel.y) * DT
			body.position = pos
			loco.drive(DT, Vector3(vel.x, 0, vel.y), facing, Vector3(want.x, 0, want.y))
			await tree.process_frame
			await body.skeleton.skeleton_updated
			on_frame.call(t, si)
			# (Out of skeleton_updated before the next drive: poses set inside it are undone.)
			await tree.process_frame
			t += DT


## A match's moves: standing, a walk, a jog with a quarter turn, a run, a stop, standing again.
static func match_path() -> Array:
	return [[1.5, Vector2.ZERO, 0.0], [2.5, Vector2(0, 1.3), NAN], [2.0, Vector2(0, 3.5), NAN], [2.0, Vector2(3.5, 0), NAN],
		[2.5, Vector2(6.0, 0), NAN], [1.5, Vector2.ZERO, NAN], [2.0, Vector2.ZERO, NAN]]
