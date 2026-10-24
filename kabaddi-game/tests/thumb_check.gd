extends Node
## How often the players are where a thumb on the touch controls would cover them, in AI matches from the broadcast
## camera at a phone's shape, given as the screen's width by its height (2340x1080 for a 19.5:9 phone, 1920x1080 for
## 16:9, 1800x1200 for a 3:2 tablet):
##   godot --headless --path . --fixed-fps 30 res://tests/thumb_check.tscn -- 2340x1080 [matches]
## A headless run has no screen of that shape, so the camera's view is worked out for it here (it keeps its height,
## the screen's shape only showing more or less of the sides) and the buttons laid out as on it. The right thumb
## covers the buttons of the side you are on (raid or defend), with a finger's width round each, and the thumb itself
## from the button pressed to the screen's corner; the left one the joystick where it usually sits and the thumb down
## to its corner. A player counts as covered when his middle is.

const FINGER := 26.0       # px beyond a button's edge that a finger also covers
const THUMB_W := 46.0      # px: half the width of a thumb lying from the button to the corner
const STICK_AT := Vector2(170, 170)   # px from the bottom-left corner: where a left thumb usually holds the joystick
const STICK_COVER := 105.0

var size := Vector2(1560, 720)   # the screen in the game's units (1280 x 720 stretched to keep its shape)
var _frames := 0
var _raider_hid := 0
var _yours_hid := 0
var _any_hid := 0
var _player_frames := 0
var _hid_players := 0
var _by_zone := {"right": 0, "left": 0}


func _ready() -> void:
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var shape := (String(args[0]) if args.size() > 0 else "2340x1080").split("x")
	var px := Vector2(float(shape[0]), float(shape[1]))
	size = px / minf(px.x / 1280.0, px.y / 720.0)
	var matches := int(args[1]) if args.size() > 1 else 2
	for k in matches:
		await _play(k + 1)
	print("thumb_check at %s (%dx%d in the game's units), %d raid frames over %d matches" % [
		"x".join(shape), size.x, size.y, _frames, matches])
	print("  raider covered %.1f%% of the time, your nearest defender %.1f%%, anyone on the mat %.1f%%" % [
		100.0 * _raider_hid / maxf(_frames, 1), 100.0 * _yours_hid / maxf(_frames, 1), 100.0 * _any_hid / maxf(_frames, 1)])
	print("  of all players on the mat, %.1f%% of the time (right thumb %.1f%%, left %.1f%%)" % [
		100.0 * _hid_players / maxf(_player_frames, 1), 100.0 * _by_zone.right / maxf(_player_frames, 1),
		100.0 * _by_zone.left / maxf(_player_frames, 1)])
	get_tree().quit()


func _play(sd: int) -> void:
	seed(sd)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "seed": sd}
	add_child(m)
	var guard := 0
	while m.phase != "fulltime" and guard < 30 * 60 * 8:
		await get_tree().process_frame
		guard += 1
		if m.phase == "raid" and m.raider:
			_measure(m)
	m.queue_free()
	await get_tree().process_frame


## Where a point is on the phone's screen, or none behind the camera.
func _screen(c: Camera3D, p: Vector3) -> Variant:
	var v: Vector3 = c.global_transform.affine_inverse() * p
	if v.z > -c.near:
		return null
	var proj := Projection.create_perspective(c.fov, size.x / size.y, c.near, c.far, false)
	var q: Vector4 = proj * Vector4(v.x, v.y, v.z, 1.0)
	return Vector2((q.x / q.w * 0.5 + 0.5) * size.x, (0.5 - q.y / q.w * 0.5) * size.y)


## Team 0 is yours: its buttons are the raid ones while it raids, the defence ones while it defends.
func _measure(m: Node) -> void:
	var c: Camera3D = m.cam.cam
	var tc = m.controls
	var was: String = tc.context
	tc.context = "raid" if m.raiding == 0 else "defend"
	var laid: Array = tc._buttons().filter(func(b): return String(b.id) not in ["pause", "camera"])
	tc.context = was
	# They are laid out from the bottom right corner of the screen they were laid out on: moved to the phone's.
	var shift: Vector2 = size - tc.get_viewport_rect().size
	if Game.settings.left_handed:
		shift.x = 0.0
	var buttons := laid.map(func(b): return {"pos": b.pos + shift, "r": float(b.r)})
	var main: Vector2 = buttons[0].pos if not buttons.is_empty() else size - Vector2(150, 150)
	var corner_r := size if not Game.settings.left_handed else Vector2(0, size.y)
	var stick := Vector2(STICK_AT.x, size.y - STICK_AT.y) if not Game.settings.left_handed else Vector2(size.x - STICK_AT.x, size.y - STICK_AT.y)
	var corner_l := Vector2(0, size.y) if not Game.settings.left_handed else size
	var under := func(q: Vector2) -> int:   # 1 the right thumb, 2 the left, 0 neither
		for b in buttons:
			if q.distance_to(b.pos) < float(b.r) + FINGER:
				return 1
		if Geometry2D.get_closest_point_to_segment(q, main, corner_r).distance_to(q) < THUMB_W:
			return 1
		if q.distance_to(stick) < STICK_COVER or Geometry2D.get_closest_point_to_segment(q, stick, corner_l).distance_to(q) < THUMB_W:
			return 2
		return 0
	if _frames == 0:
		# The projection worked out here, for the screen this run has, is the engine's own.
		var keep := size
		size = c.get_viewport().get_visible_rect().size
		var p: Vector3 = m.raider.model.anchor("waist")
		print("  projection check: %.2f px off the engine's" % (_screen(c, p) as Vector2).distance_to(c.unproject_position(p)))
		size = keep
	_frames += 1
	var any := false
	var yours: Athlete = null
	var yd := INF
	for a in m.on_mat(0) + m.on_mat(1):
		var q = _screen(c, a.model.anchor("waist"))
		if q == null:
			continue
		_player_frames += 1
		var z: int = under.call(q)
		if z > 0:
			_hid_players += 1
			any = true
			_by_zone["right" if z == 1 else "left"] += 1
			if a == m.raider:
				_raider_hid += 1
		if a.team == 0 and a != m.raider:
			var d: float = a.global_position.distance_to(m.raider.global_position)
			if d < yd:
				yd = d
				yours = a
	if any:
		_any_hid += 1
	if yours:
		var q2 = _screen(c, yours.model.anchor("waist"))
		if q2 != null and under.call(q2) > 0:
			_yours_hid += 1
