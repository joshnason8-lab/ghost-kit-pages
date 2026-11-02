class_name CameraRig
extends Node3D
## The match camera, as a court-side broadcast would show it (CAM_TV): from beside the court, framing the play: the
## ball and everyone near it (and your own player), the whole width of the court from its near edge to the far wall,
## at any screen's shape (a 20:9 phone, 16:9, a 4:3 tablet: the angle of view is worked out for the screen it is on).
## On the earth court it stands back over the heads of the near crowd; on the stone court it hangs just out from the
## top of the near wall, in front of the people on its terraces, so neither the wall nor the crowd hides the alley.
## High: the same side, higher and wider. End: low behind your own end, looking down the court, as a player sees it.
## Aim, distance and zoom follow their targets on springs, never jumping.

## The court-side camera, per court: how steeply it looks down (degrees), its narrowest and widest angle of view
## (vertical, degrees), the least and most court it frames to either side of the play (m), and, on the stone court,
## the line it stays on (just out from the near wall's top, in front of the terraces).
const TV_ULAMA := {"pitch": 30.0, "fov_lo": 34.0, "fov_hi": 52.0, "w_lo": 8.0, "w_hi": 15.0, "d_lo": 11.0, "d_hi": 22.0}
const TV_CLASSIC := {"pitch": 47.0, "fov_lo": 46.0, "fov_hi": 64.0, "w_lo": 9.0, "w_hi": 15.0, "d_lo": 10.0, "d_hi": 18.0, "z": 7.0}
const NEAR := 13.0      # m along the court from the ball: the players it keeps in the picture
const MARGIN := 2.5     # m of court kept beyond the outermost of them

var camera: Camera3D
var mode := Game.CAM_TV
var _focus := Vector3.ZERO
var _fvel := Vector3.ZERO
var _fov := 40.0
var _pos := Vector3.ZERO
var _pvel := Vector3.ZERO
var shake := 0.0
var aspect_override := 0.0   # a screen's shape to frame for instead of this one's (tests)
var _tv_w := 10.0         # the court-side camera's half-width of court framed, smoothed (m)


func setup(m: Node) -> void:
	camera = Camera3D.new()
	add_child(camera)
	mode = int(Game.settings.camera)
	camera.near = 0.3
	camera.far = 700.0
	camera.current = true
	_focus = _want_focus(m)
	_tv_w = _tv_half_width(m)
	_pos = _want_pos(_focus, m)
	_fov = _want_fov(m)
	camera.global_position = _pos
	camera.look_at(_focus)
	camera.fov = _fov


func _side_z(m: Node) -> float:
	return 13.0 if m.court.classic() else 10.0


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
	return _tv_pos(f, m)


## The court-side camera's place for a point of focus: on the line that looks down at the court's pitch, as far back
## as frames the play (the earth court) or on the stone court's line.
func _tv_pos(f: Vector3, m: Node) -> Vector3:
	var court: Court = m.court
	var hl := court.half_l()
	var x := clampf(f.x, -hl * 0.85, hl * 0.85)
	var c: Dictionary = TV_CLASSIC if court.classic() else TV_ULAMA
	var pitch := deg_to_rad(float(c.pitch))
	var d := _tv_dist(m)
	if court.classic():
		# It cannot stand further back (the terraces), so it rises to take in more of the alley: as high as frames the
		# play, never so low that the near wall hides the near edge of the alley, nor that it comes down behind the
		# wall when the play (or the copal elder) is at the near side.
		var zc := float(c.z)
		var dz := zc - minf(f.z, 0.5)
		var clear := Court.WALL_H * (zc - Court.ALLEY_HALF_W) / (Court.TALUD_Z - Court.ALLEY_HALF_W) + 0.4
		var y := maxf(f.y + maxf(dz * tan(pitch), sqrt(maxf(0.0, d * d - dz * dz))), clear)
		return Vector3(x, y, zc)
	return Vector3(x, f.y + d * sin(pitch), f.z + d * cos(pitch))


## How much court to either side of the focus the picture must hold (m): the ball, the players near it, yours.
func _tv_half_width(m: Node) -> float:
	var c: Dictionary = TV_CLASSIC if m.court.classic() else TV_ULAMA
	if m.has_method("in_ritual") and m.in_ritual():
		return float(c.w_lo)
	var bx: float = m.ball.pos.x
	var lo := bx
	var hi := bx
	for t in m.teams:
		for p in t.players:
			var px: float = (p as Player).global_position.x
			if absf(px - bx) < NEAR or (p as Player).user:
				lo = minf(lo, px)
				hi = maxf(hi, px)
	var w := maxf(hi - _focus.x, _focus.x - lo) + MARGIN
	# A ball flying long opens the picture ahead of it.
	w += clampf((absf(float(m.ball.vel.x)) - 6.0) * 0.4, 0.0, 4.0)
	return clampf(w, float(c.w_lo), float(c.w_hi))


## The screen's width over its height.
func _aspect() -> float:
	if aspect_override > 0.0:
		return aspect_override
	var sz := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	return clampf(sz.x / maxf(1.0, sz.y), 1.2, 2.6)


## How far (m) the camera stands from the play to frame it at its usual angle of view.
func _tv_dist(m: Node) -> float:
	var c: Dictionary = TV_CLASSIC if m.court.classic() else TV_ULAMA
	var mid := deg_to_rad((float(c.fov_lo) + float(c.fov_hi)) * 0.5 * 0.5)
	return clampf(_tv_w / (tan(mid) * _aspect()), float(c.d_lo), float(c.d_hi))


## The angle of view (vertical, Godot's) that frames the play from where the camera is, on this screen.
func _tv_fov(m: Node) -> float:
	var c: Dictionary = TV_CLASSIC if m.court.classic() else TV_ULAMA
	var d := maxf(1.0, _pos.distance_to(_focus))
	var v := rad_to_deg(2.0 * atan(_tv_w / (d * _aspect())))
	return clampf(v, float(c.fov_lo), float(c.fov_hi))


## The point to look at: the ball, led toward where it is going.
func _want_focus(m: Node) -> Vector3:
	if m.has_method("in_ritual") and m.in_ritual():
		return m.ritual.focus()
	var b: Vector3 = m.ball.pos
	var f := Vector3(b.x, minf(b.y, 3.0) * 0.35 + 0.6, b.z * 0.5)
	var v: Vector3 = m.ball.vel
	f += Vector3(v.x, 0, 0) * 0.35
	return f


func _want_fov(m: Node) -> float:
	if mode == Game.CAM_TV:
		return _tv_fov(m)
	var base := 40.0 if mode == Game.CAM_HIGH else 52.0
	var sp: float = Vector2(m.ball.vel.x, m.ball.vel.z).length()
	base += clampf((sp - 6.0) * 0.6, 0.0, 9.0) + clampf(m.ball.pos.y * 0.8, 0.0, 6.0)
	return base


func follow(m: Node, delta: float) -> void:
	var dt := minf(delta, 0.05)
	_tv_w = lerpf(_tv_w, _tv_half_width(m), 1.0 - exp(-1.5 * dt))
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


## Where the camera is looking (the play, eased).
func focus_point() -> Vector3:
	return _focus


func snap(m: Node) -> void:
	_focus = _want_focus(m)
	_tv_w = _tv_half_width(m)
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
