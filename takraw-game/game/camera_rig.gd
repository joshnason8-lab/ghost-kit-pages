class_name CameraRig
extends Camera3D
## The match camera. Broadcast: high in the stand, off to your end of the side line and looking across the court at an
## angle, as takraw is shown on TV, so the net is seen as a net and not edge on; it slides with the ball. Side on:
## level with the net, the whole court square to the screen. End: behind your own back line, looking over the net.
## Replays: low beside the net, slow.

var mode := Game.CAM_TV
var _look := Vector3.ZERO
var _pos := Vector3.ZERO
var _shake := 0.0
var _replay := false
var _replay_pos := Vector3.ZERO
var _user_side := 0
var rng := RandomNumberGenerator.new()   # its shake (seeded by the match: the stick's way is read from the camera)


func setup(m: Node) -> void:
	mode = int(Game.settings.camera)
	fov = 42.0
	near = 0.1
	far = 300.0
	_user_side = m._user_side() if m.has_method("_user_side") else 1
	if _user_side < 0:
		_user_side = 1   # nobody's match: from the side on the left of the picture
	_pos = _want_pos(Vector3.ZERO)
	_look = _want_look(Vector3.ZERO)
	global_position = _pos
	look_at(_look)
	current = true


func _want_pos(b: Vector3) -> Vector3:
	var s := Court.sgn(_user_side)
	if mode == Game.CAM_END:
		return Vector3(s * (Court.HALF + 7.0), 4.4, b.z * 0.15)
	if mode == Game.CAM_SIDE:
		return Vector3(clampf(b.x * 0.35, -3.0, 3.0), 7.2, -15.5)
	# Broadcast: over your half, about 30 degrees round from square to the net.
	return Vector3(s * 6.8 + clampf(b.x * 0.2, -1.5, 1.5), 7.0, -13.2)


func _want_look(b: Vector3) -> Vector3:
	if mode == Game.CAM_END:
		return Vector3(-Court.sgn(_user_side) * 1.5, 1.0, clampf(b.z * 0.25, -1.0, 1.0))
	if mode == Game.CAM_SIDE:
		return Vector3(clampf(b.x * 0.5, -4.0, 4.0), 0.6 + clampf(b.y * 0.12, 0.0, 0.6), 0.5)
	return Vector3(clampf(b.x * 0.45, -3.5, 3.5) - Court.sgn(_user_side) * 0.6, 0.6 + clampf(b.y * 0.12, 0.0, 0.6), 0.6)


func follow(b: Vector3, delta: float, m: Node) -> void:
	if _replay:
		return
	if m.has_method("_user_side") and m._user_side() >= 0:
		_user_side = m._user_side()
	var want := _want_pos(b)
	var look := _want_look(b)
	_pos = _pos.lerp(want, minf(1.0, 2.2 * delta))
	_look = _look.lerp(look, minf(1.0, 3.0 * delta))
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		shake = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * _shake * 0.08
	global_position = _pos + shake
	look_at(_look)


## Straight to where it should be (after a cut).
func snap() -> void:
	_pos = _want_pos(Vector3.ZERO)
	_look = _want_look(Vector3.ZERO)
	global_position = _pos
	look_at(_look)


func shake(k := 1.0) -> void:
	_shake = maxf(_shake, k)


## The camera button: broadcast, side on, behind your end, round again.
func toggle() -> void:
	mode = {Game.CAM_TV: Game.CAM_SIDE, Game.CAM_SIDE: Game.CAM_END}.get(mode, Game.CAM_TV)
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


# ---------------------------------------------------------------- the stick on the floor

## The stick's way on the floor at p for camera c (0.14.4; Match._cam_dir, and the world check's joystick rule through
## game/world.gd): the way that, where p is drawn, goes the stick's way on the screen (up the stick is up the screen
## there), in every camera, its length the stick's push. The floor's way for a step right and a step down on the screen
## at p (axes; from screen_axes when not given) is mixed as the stick is pushed. By the camera's turn alone (before) it
## was out by the perspective: 24-33 degrees at the picture's middle (the diagonals, foreshortened) and 50-56 at its
## edges, in all three cameras (the owner found it wrong in other games). j: x right, y down (Input.get_vector's).
static func stick_world(j: Vector2, c: Camera3D, p: Vector3, axes := []) -> Vector3:
	if axes.is_empty():
		axes = screen_axes(c, p)
	var w := Vector3.ZERO
	if axes.size() == 2:
		w = (axes[0] as Vector3) * j.x + (axes[1] as Vector3) * j.y
	else:
		# (p off the picture: the camera's turn.)
		var bz := c.global_transform.basis.z
		var right := c.global_transform.basis.x
		var up := -bz if absf(bz.y) < 0.9 else c.global_transform.basis.y
		w = Vector3(right.x, 0, right.z).normalized() * j.x - Vector3(up.x, 0, up.z).normalized() * j.y
	w.y = 0.0
	return w.normalized() * minf(j.length(), 1.0) if w.length() > 1e-6 else Vector3.ZERO


## The floor's way for a step right and for a step down on the screen where p (on the floor) is drawn by c: the
## camera's rays a little either side of it, met with the floor, per pixel. [] if p is off the picture or the floor is
## edge on.
static func screen_axes(c: Camera3D, p: Vector3) -> Array:
	var f := Vector3(p.x, 0.0, p.z)
	if c.is_position_behind(f):
		return []
	var sp := c.unproject_position(f)
	var d := maxf(4.0, c.get_viewport().get_visible_rect().size.y * 0.03)
	var r1 := floor_at(c, sp + Vector2(d, 0))
	var r0 := floor_at(c, sp - Vector2(d, 0))
	var d1 := floor_at(c, sp + Vector2(0, d))
	var d0 := floor_at(c, sp - Vector2(0, d))
	if not (r1.is_finite() and r0.is_finite() and d1.is_finite() and d0.is_finite()):
		return []
	return [(r1 - r0) / (2.0 * d), (d1 - d0) / (2.0 * d)]


## Where c's ray through a point of the screen meets the floor; INF if it doesn't (at or above the horizon).
static func floor_at(c: Camera3D, s: Vector2) -> Vector3:
	var o := c.project_ray_origin(s)
	var n := c.project_ray_normal(s)
	if n.y > -0.01 or o.y <= 0.0:
		return Vector3.INF
	return o + n * (-o.y / n.y)
