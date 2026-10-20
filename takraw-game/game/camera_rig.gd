class_name CameraRig
extends Camera3D
## The match camera. Broadcast: high in the stand on the side line, as takraw is shown on TV, sliding with the ball
## and leaning in at the net. End: behind your own back line, looking over the net (the way you face it). Replays:
## low beside the net, slow.

var mode := Game.CAM_TV
var _look := Vector3.ZERO
var _pos := Vector3.ZERO
var _shake := 0.0
var _replay := false
var _replay_pos := Vector3.ZERO
var _user_side := 0


func setup(m: Node) -> void:
	mode = int(Game.settings.camera)
	fov = 42.0
	near = 0.1
	far = 300.0
	_user_side = maxi(0, m._user_side()) if m.has_method("_user_side") else 0
	_pos = _want_pos(Vector3.ZERO)
	_look = Vector3(0, 0.8, 0.5)
	global_position = _pos
	look_at(_look)
	current = true


func _want_pos(b: Vector3) -> Vector3:
	if mode == Game.CAM_END:
		var s := Court.sgn(_user_side)
		return Vector3(s * (Court.HALF + 7.0), 4.4, b.z * 0.15)
	return Vector3(clampf(b.x * 0.35, -3.0, 3.0), 7.2, -15.5)


func follow(b: Vector3, delta: float, m: Node) -> void:
	if _replay:
		return
	if m.has_method("_user_side") and m._user_side() >= 0:
		_user_side = m._user_side()
	var want := _want_pos(b)
	var look := Vector3(clampf(b.x * 0.5, -4.0, 4.0), 0.6 + clampf(b.y * 0.12, 0.0, 0.6), 0.5)
	if mode == Game.CAM_END:
		look = Vector3(-Court.sgn(_user_side) * 1.5, 1.0, clampf(b.z * 0.25, -1.0, 1.0))
	_pos = _pos.lerp(want, minf(1.0, 2.2 * delta))
	_look = _look.lerp(look, minf(1.0, 3.0 * delta))
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.08
	global_position = _pos + shake
	look_at(_look)


func shake(k := 1.0) -> void:
	_shake = maxf(_shake, k)


func toggle() -> void:
	mode = Game.CAM_END if mode == Game.CAM_TV else Game.CAM_TV
	Game.settings.camera = mode
	Game.save_settings()


## The replay's angle: low, beside the net, on the far side of the ball from the stand.
func replay_angle(focus: Vector3) -> void:
	_replay = true
	_replay_pos = Vector3(focus.x * 0.4 - 3.5, 1.6, -5.5)
	global_position = _replay_pos
	fov = 38.0
	look_at(focus + Vector3(0, 0.4, 0))


func replay_follow(b: Vector3, delta: float) -> void:
	_replay_pos = _replay_pos.lerp(Vector3(b.x * 0.4 - 3.5, 1.4 + b.y * 0.2, -5.5), minf(1.0, 1.5 * delta))
	global_position = _replay_pos
	look_at(b + Vector3(0, 0.2, 0))


func replay_end() -> void:
	_replay = false
	fov = 42.0
	global_position = _pos
	look_at(_look)
