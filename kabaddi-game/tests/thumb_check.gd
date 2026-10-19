extends Node
## How often the players are where a thumb on the touch controls would cover them, in AI matches from the broadcast
## camera at a phone's shape. Run at the phone's shape in the game's units (a 19.5:9 phone is 1560 x 720, 16:9 is
## 1280 x 720, a 3:2 tablet 1280 x 853):
##   godot --headless --path . --fixed-fps 30 --resolution 1560x720 res://tests/thumb_check.tscn -- [matches]
## The right thumb covers the buttons of the side you are on (raid or defend), with a finger's width round each, and
## the thumb itself from the button pressed to the screen's corner; the left one the joystick where it usually sits
## and the thumb down to its corner. A player counts as covered when his middle is.

const FINGER := 26.0       # px beyond a button's edge that a finger also covers
const THUMB_W := 46.0      # px: half the width of a thumb lying from the button to the corner
const STICK_AT := Vector2(170, 170)   # px from the bottom-left corner: where a left thumb usually holds the joystick
const STICK_COVER := 105.0

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
	var matches := int(args[0]) if args.size() > 0 else 2
	for k in matches:
		await _play(k + 1)
	var s := get_viewport().get_visible_rect().size
	print("thumb_check at %dx%d, %d raid frames over %d matches" % [s.x, s.y, _frames, matches])
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


## Team 0 is yours: its buttons are the raid ones while it raids, the defence ones while it defends.
func _measure(m: Node) -> void:
	var c: Camera3D = m.cam.cam
	var s := get_viewport().get_visible_rect().size
	var tc = m.controls
	var was: String = tc.context
	tc.context = "raid" if m.raiding == 0 else "defend"
	var buttons: Array = tc._buttons().filter(func(b): return String(b.id) not in ["pause", "camera"])
	tc.context = was
	var main: Vector2 = buttons[0].pos if not buttons.is_empty() else Vector2(s.x - 150, s.y - 150)
	var corner_r := Vector2(s.x, s.y) if not Game.settings.left_handed else Vector2(0, s.y)
	var stick := Vector2(STICK_AT.x, s.y - STICK_AT.y) if not Game.settings.left_handed else Vector2(s.x - STICK_AT.x, s.y - STICK_AT.y)
	var corner_l := Vector2(0, s.y) if not Game.settings.left_handed else Vector2(s.x, s.y)
	_frames += 1
	var any := false
	var yours: Athlete = null
	var yd := INF
	for a in m.on_mat(0) + m.on_mat(1):
		var p: Vector3 = a.model.anchor("waist")
		if c.is_position_behind(p):
			continue
		var q := c.unproject_position(p)
		var right := false
		for b in buttons:
			if q.distance_to(b.pos) < float(b.r) + FINGER:
				right = true
		right = right or Geometry2D.get_closest_point_to_segment(q, main, corner_r).distance_to(q) < THUMB_W
		var left := q.distance_to(stick) < STICK_COVER or Geometry2D.get_closest_point_to_segment(q, stick, corner_l).distance_to(q) < THUMB_W
		_player_frames += 1
		if right or left:
			_hid_players += 1
			any = true
			if a == m.raider:
				_raider_hid += 1
		if right:
			_by_zone.right += 1
		elif left:
			_by_zone.left += 1
		if a.team == 0 and a != m.raider:
			var d: float = a.global_position.distance_to(m.raider.global_position)
			if d < yd:
				yd = d
				yours = a
	if any:
		_any_hid += 1
	if yours:
		var q2 := c.unproject_position(yours.model.anchor("waist"))
		var hid := q2.distance_to(stick) < STICK_COVER
		for b in buttons:
			hid = hid or q2.distance_to(b.pos) < float(b.r) + FINGER
		if hid:
			_yours_hid += 1
