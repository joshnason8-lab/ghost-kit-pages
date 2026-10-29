class_name CameraRig
extends Camera3D
## The match camera. Broadcast: as floorball is shown on television, high in the stand on the near side (the
## secretariat's side, so the benches are across the picture), level with the ball, panning along the rink as it
## goes and leaning in a little toward the goal it nears. High: further up and back, more of the rink. End: behind
## the goal your team attacks, looking up the rink.

var mode := Game.CAM_TV
var _look := Vector3.ZERO
var _pos := Vector3.ZERO
var _m: Node
var _close := false        # on a penalty shot's close camera


func setup(m: Node) -> void:
	_m = m
	mode = int(Game.settings.camera)
	fov = 38.0
	near = 0.2
	far = 220.0
	_pos = _want_pos(Vector3.ZERO)
	_look = _want_look(Vector3.ZERO)
	global_position = _pos
	look_at(_look)
	current = true


func _want_pos(b: Vector3) -> Vector3:
	var x := clampf(b.x * 0.82, -13.5, 13.5)
	match mode:
		Game.CAM_HIGH:
			return Vector3(clampf(b.x * 0.6, -9.0, 9.0), 17.0, 27.0)
		Game.CAM_END:
			var s := _attack_dir()
			return Vector3(-s * 27.0, 7.5, clampf(b.z * 0.3, -3.0, 3.0))
	return Vector3(x, 11.0, 23.5)


func _want_look(b: Vector3) -> Vector3:
	match mode:
		Game.CAM_HIGH:
			return Vector3(clampf(b.x * 0.75, -12.0, 12.0), 0.0, -0.5)
		Game.CAM_END:
			return Vector3(clampf(b.x, -12.0, 12.0) * 0.6 + _attack_dir() * 4.0, 0.0, b.z * 0.5)
	return Vector3(clampf(b.x * 0.92, -15.0, 15.0), 0.0, -0.8 + clampf(b.z * 0.18, -1.5, 1.5))


func _attack_dir() -> float:
	if _m and _m.has_method("attack_dir"):
		return _m.attack_dir(maxi(0, int(_m.user_team)))
	return 1.0


func follow(b: Vector3, delta: float, _match: Node) -> void:
	var want := _want_pos(b)
	var look := _want_look(b)
	var rate := 2.0
	# A penalty shot: the close camera low behind the shooter (match.gd penalty_view), wider; cut to it, then held.
	var pv: Array = _m.penalty_view() if _m and _m.has_method("penalty_view") else []
	if not pv.is_empty():
		want = pv[0]
		look = pv[1]
		if not _close:
			_close = true
			_pos = want
			_look = look
		rate = 5.0
		fov = lerpf(fov, 50.0, minf(1.0, 4.0 * delta))
	elif _close:
		_close = false
		_pos = want   # and cut back
		_look = look
		fov = 38.0
	# A camera operator's pan: smooth, a little behind the ball, never a jump.
	_pos = _pos.lerp(want, minf(1.0, rate * delta))
	_look = _look.lerp(look, minf(1.0, rate * 1.3 * delta))
	global_position = _pos
	look_at(_look)


## The camera button: broadcast, high, behind the goal, round again.
func toggle() -> void:
	mode = {Game.CAM_TV: Game.CAM_HIGH, Game.CAM_HIGH: Game.CAM_END}.get(mode, Game.CAM_TV)
	Game.settings.camera = mode
	Game.save_settings()
