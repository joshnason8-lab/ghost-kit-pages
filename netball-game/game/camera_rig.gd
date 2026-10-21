class_name CameraRig
extends Camera3D
## The broadcast camera. TV: high in the stand on the side line opposite the officials' bench, as netball is shown,
## panning along the court with the ball and leading it toward the goal it is going to. Low: courtside and lower.
## End: behind the goal your team attacks. Its movement is smoothed, never cut, except between plays.

var mode := Game.CAM_TV
var focus := Vector2.ZERO        # where it looks (court x, z), smoothed
var lead := 0.0                  # metres ahead of the ball toward the attacked goal
var end_dir := 1                 # CAM_END: the end it sits behind (the goal your team attacks)


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
			eye = Vector3(focus.x * 0.78, 10.5, Court.HALF_W + 15.5)
			fov = 38.0
	global_position = eye
	look_at(look, Vector3.UP)


## The court direction a stick pushed in screen direction v points (x right, y down on the screen).
func court_dir(v: Vector2) -> Vector2:
	var right := global_transform.basis.x
	var fwd := -global_transform.basis.z
	var r2 := Vector2(right.x, right.z).normalized()
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	return (r2 * v.x - f2 * v.y)
