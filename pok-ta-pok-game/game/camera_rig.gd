class_name CameraRig
extends Node3D
## The match camera, as a court-side broadcast would show it: from beside the court at the analco, high enough to
## see over the people, panning along the court with the ball and zooming out when it flies long, in when it is fought
## for low. High: the same side, higher and wider. End: low behind your own end, looking down the court, as a player
## sees it. Aim and zoom follow their targets on springs, never jumping.

var camera: Camera3D
var mode := Game.CAM_TV
var _focus := Vector3.ZERO
var _fvel := Vector3.ZERO
var _fov := 40.0
var _pos := Vector3.ZERO
var _pvel := Vector3.ZERO
var shake := 0.0


func setup(m: Node) -> void:
	camera = Camera3D.new()
	add_child(camera)
	mode = int(Game.settings.camera)
	camera.near = 0.3
	camera.far = 700.0
	camera.current = true
	_focus = _want_focus(m)
	_pos = _want_pos(_focus, m)
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov


func _side_z(m: Node) -> float:
	return 13.0 if m.court.classic() else 11.5


func _want_pos(f: Vector3, m: Node) -> Vector3:
	var court: Court = m.court
	var hl := court.half_l()
	match mode:
		Game.CAM_HIGH:
			return Vector3(clampf(f.x * 0.75, -hl * 0.6, hl * 0.6), 16.0 if not court.classic() else 20.0, _side_z(m) + 5.0)
		Game.CAM_END:
			var d := 1.0
			if int(m.user_team) >= 0:
				d = Rules.dir(int(m.user_team))
			var back := hl + 5.0 if not court.classic() else Court.END_HALF_L - 1.0
			var x := clampf(f.x - d * 16.0, -back, back)
			return Vector3(x, 4.2 if not court.classic() else 6.5, f.z * 0.3)
	var h := 9.0 if not court.classic() else 13.5
	return Vector3(clampf(f.x * 0.85, -hl * 0.8, hl * 0.8), h, _side_z(m))


## The point to look at: the ball, led toward where it is going.
func _want_focus(m: Node) -> Vector3:
	var b: Vector3 = m.ball.pos
	var f := Vector3(b.x, minf(b.y, 3.0) * 0.35 + 0.6, b.z * 0.5)
	var v: Vector3 = m.ball.vel
	f += Vector3(v.x, 0, 0) * 0.35
	return f


func _want_fov(m: Node) -> float:
	var base := 40.0 if mode == Game.CAM_TV else (40.0 if mode == Game.CAM_HIGH else 52.0)
	var sp: float = Vector2(m.ball.vel.x, m.ball.vel.z).length()
	base += clampf((sp - 6.0) * 0.6, 0.0, 9.0) + clampf(m.ball.pos.y * 0.8, 0.0, 6.0)
	return base


func follow(m: Node, delta: float) -> void:
	var dt := minf(delta, 0.05)
	var f := _want_focus(m)
	var a := (f - _focus) * (3.0 * 3.0) - _fvel * (2.0 * 3.0)
	_fvel += a * dt
	_focus += _fvel * dt
	var wp := _want_pos(_focus, m)
	var b := (wp - _pos) * (2.2 * 2.2) - _pvel * (2.0 * 2.2)
	_pvel += b * dt
	_pos += _pvel * dt
	_fov = lerpf(_fov, _want_fov(m), 1.0 - exp(-2.0 * dt))
	var jolt := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 3.0)
		jolt = Vector3(sin(Time.get_ticks_msec() * 0.09), cos(Time.get_ticks_msec() * 0.11), 0) * shake * 0.06
	camera.global_position = _pos + jolt
	camera.look_at(_focus + jolt * 0.5)
	camera.fov = _fov


func snap(m: Node) -> void:
	_focus = _want_focus(m)
	_pos = _want_pos(_focus, m)
	_fov = _want_fov(m)
	_fvel = Vector3.ZERO
	_pvel = Vector3.ZERO
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov


## Looks at a set point (the ring's moment, the store pictures).
func look_from(p: Vector3, at: Vector3, fov: float) -> void:
	_pos = p
	_focus = at
	_fov = fov
	_fvel = Vector3.ZERO
	_pvel = Vector3.ZERO
	camera.global_position = p
	camera.look_at(at)
	camera.fov = fov
