class_name CameraRig
extends Node3D
## The match camera, as hurling is shown on television: high on the gantry of the stand at the halfway line,
## panning along with the play and zooming in and out, so the sliotar (small and fast) is always in the picture:
## wider when it is struck long and high, closer when it is fought for on the ground. High: the same seat, higher and
## wider. End: behind the goal your side attacks. It moves smoothly: aim and zoom follow their targets with a
## spring, never jumping.

var camera: Camera3D
var mode := Game.CAM_TV
var _focus := Vector3.ZERO
var _fvel := Vector3.ZERO
var _fov := 38.0
var _fovv := 0.0
var _pos := Vector3.ZERO
var _pvel := Vector3.ZERO

const GANTRY_Z := Pitch.HALF_W + 34.0
const GANTRY_H := 24.0


func setup(m: Node) -> void:
	camera = Camera3D.new()
	add_child(camera)
	mode = int(Game.settings.camera)
	camera.near = 0.5
	camera.far = 900.0
	camera.current = true
	_focus = Vector3.ZERO
	_pos = _want_pos(_focus, m)
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov


func _want_pos(f: Vector3, m: Node) -> Vector3:
	match mode:
		Game.CAM_HIGH:
			return Vector3(clampf(f.x * 0.75, -Pitch.HALF_L * 0.7, Pitch.HALF_L * 0.7), GANTRY_H + 16.0, GANTRY_Z + 14.0)
		Game.CAM_END:
			var d := 1.0
			if int(m.user_team) >= 0:
				d = m.dir(int(m.user_team))
			return Vector3(f.x - d * 34.0, 13.0, f.z * 0.6)
	return Vector3(clampf(f.x * 0.82, -Pitch.HALF_L * 0.75, Pitch.HALF_L * 0.75), GANTRY_H, GANTRY_Z)


## The point to look at: the ball, led a little toward where it is going (where it will land when it is in the air).
func _want_focus(m: Node) -> Vector3:
	var b: Vector3 = m.ball.global_position
	var f := Vector3(b.x, minf(b.y, 6.0) * 0.4, b.z)
	if m.ball.state == Sliotar.FREE and m.ball.vel.length() > 12.0:
		var ahead: Vector3 = Sliotar.predict(b, m.ball.vel, 0.8)
		f = f.lerp(Vector3(ahead.x, 0, ahead.z), 0.55)
	elif m.carrier != null:
		f += Vector3(m.dir(m.carrier.team) * 6.0, 0, 0)
	if m.phase == m.P.SHOOTOUT:
		f = Vector3(Pitch.HALF_L - 10.0, 0, 0)
	return f


func _want_fov(m: Node) -> float:
	var base := 34.0 if mode == Game.CAM_TV else (40.0 if mode == Game.CAM_HIGH else 50.0)
	if m.ball.state == Sliotar.FREE:
		var sp: float = m.ball.vel.length()
		base += clampf((sp - 10.0) * 0.35, 0.0, 10.0) + clampf(m.ball.global_position.y * 0.5, 0.0, 6.0)
	if m.phase in [m.P.SETUP, m.P.SET]:
		base += 4.0
	return base


func follow(m: Node, delta: float) -> void:
	var dt := minf(delta, 0.05)
	var f := _want_focus(m)
	var a := (f - _focus) * (3.2 * 3.2) - _fvel * (2.0 * 3.2)
	_fvel += a * dt
	_focus += _fvel * dt
	var wp := _want_pos(_focus, m)
	var b := (wp - _pos) * (2.4 * 2.4) - _pvel * (2.0 * 2.4)
	_pvel += b * dt
	_pos += _pvel * dt
	var want_fov := _want_fov(m)
	var k := 1.0 - exp(-2.2 * dt)
	_fov = lerpf(_fov, want_fov, k)
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov


## For a still (the store screenshots): straight to the wanted view.
func snap(m: Node) -> void:
	_focus = _want_focus(m)
	_pos = _want_pos(_focus, m)
	_fov = _want_fov(m)
	_fvel = Vector3.ZERO
	_pvel = Vector3.ZERO
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov
