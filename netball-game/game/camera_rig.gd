class_name CameraRig
extends Camera3D
## The broadcast camera. TV: high in the stand on the side line opposite the officials' bench, as netball is shown,
## panning along the court with the ball and leading it toward the goal it is going to. Low: courtside and lower.
## End: behind the goal your team attacks. Its movement is smoothed, never cut, except between plays and for the
## close-up: as a netball broadcast does, the TV camera cuts to a close shot of the post (close_dir) and back. In an
## AI v AI match (the home screen's, a demo) for every shot, from the shot to just after it lands; in yours only once
## the ball is through the ring (the goal), while nothing is in play, so it never takes the court from under your
## thumb mid-play. Your stick keeps steering as on the wide shot (court_dir) through a close-up.

const CLOSE_TAIL := 0.6         # seconds the close shot holds after its reason has passed

var mode := Game.CAM_TV
var focus := Vector2.ZERO        # where it looks (court x, z), smoothed
var lead := 0.0                  # metres ahead of the ball toward the attacked goal
var end_dir := 1                 # CAM_END: the end it sits behind (the goal your team attacks)
var close_dir := 0               # on the close shot of the post at this end (0: the wide shot)
var _close_hold := 0.0           # seconds the close shot stays on once there is no more reason for it
var _wide := Basis()             # the wide shot's turn (the stick steers by it)


func _ready() -> void:
	fov = 40.0
	near = 0.2
	far = 220.0
	current = true


func set_mode(m: int) -> void:
	mode = m


## ball: the ball's court position; attack_dir: the end the side with the ball attacks (0 if no one has it).
func track(ball: Vector2, attack_dir: int, dt: float, snap := false) -> void:
	lead = lerpf(lead, 2.2 * attack_dir, 1.0 - exp(-1.5 * dt))
	var want := Vector2(clampf(ball.x + lead, -Court.HALF_L + 6.0, Court.HALF_L - 6.0), ball.y * 0.35)
	if snap:
		focus = want
	else:
		focus = focus.lerp(want, 1.0 - exp(-2.6 * dt))
	var look := Vector3(focus.x, 0.6, focus.y)
	var eye: Vector3
	match mode:
		Game.CAM_LOW:
			eye = Vector3(focus.x * 0.85, 4.2, Court.HALF_W + 9.0)
			fov = 46.0
		Game.CAM_END:
			eye = Vector3(-end_dir * (Court.HALF_L + 9.0) + focus.x * 0.25, 8.5, focus.y * 0.4)
			look = Vector3(focus.x * 0.6 + end_dir * 2.0, 0.3, focus.y * 0.5)
			fov = 50.0
		_:
			eye = Vector3(focus.x * 0.78, 9.4, Court.HALF_W + 14.0)
			fov = 36.0
	var to := _close_want()
	if to != 0:
		close_dir = to
		_close_hold = CLOSE_TAIL
	elif close_dir != 0:
		_close_hold -= dt
		if _close_hold <= 0.0:
			close_dir = 0
	_wide = Transform3D.IDENTITY.looking_at(look - eye, Vector3.UP).basis
	if close_dir != 0:
		# Courtside in front of the post, a little above head height, tight on the ring and the circle under it.
		var d := float(close_dir)
		eye = Vector3(d * (Court.HALF_L - 7.2), 3.3, Court.HALF_W + 2.4)
		look = Vector3(d * (Court.HALF_L - 1.6), 1.85, 0.4)
		fov = 27.0
	global_position = eye
	look_at(look, Vector3.UP)

## The end whose post the close shot wants now (0 for none), from the match (the camera's parent) as it stands.
func _close_want() -> int:
	var m := get_parent()
	if mode != Game.CAM_TV or m == null or not ("shot_info" in m):
		return 0
	if m.phase == "goal":
		var ball: Vector2 = m.ball.court_pos()
		return int(signf(ball.x)) if m.phase_t < 1.9 and absf(ball.x) > Court.HALF_L - 3.0 else 0
	var shooter = m.shot_info.get("by")
	if m.demo and shooter != null and is_instance_valid(shooter) and m.phase == "live":
		return int(shooter.dir)
	return 0


## The court direction a stick pushed in screen direction v points (x right, y down on the screen).
func court_dir(v: Vector2) -> Vector2:
	var b := _wide if close_dir != 0 else global_transform.basis
	var right := b.x
	var fwd := -b.z
	var r2 := Vector2(right.x, right.z).normalized()
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	return (r2 * v.x - f2 * v.y)
