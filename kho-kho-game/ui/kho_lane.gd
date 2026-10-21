class_name KhoLane
extends Control
## The home screen's menu: a kho kho lane across the screen, pole to pole, with a chaser seated in each square, each
## facing the other way from the one beside him. Each menu choice sits on the side its chaser faces. Tap one and the
## active chaser runs up behind him, gives the kho (a palm on the back, "KHO!"), and the seated chaser springs up and
## away toward his side: the chase runs on into that screen. Drawn in 2D (no 3D in the menu's own cost).

signal picked(id: String)

## [id, title key, icon] for each square, left to right; "" leaves a square as only a seated chaser.
var items: Array = []
var squares := 8
var _buttons := {}           # id -> Button
var _anim := {}              # the kho being given: {i, t}
var _runner := Vector2.ZERO  # the active chaser, in lane units (x 0-1 along, y -1..1 across)
var _runner_side := 1.0
var _t := 0.0
var _risen := -1             # the square whose chaser has risen
var _rise_t := 0.0


func _init(p_items: Array, p_squares := 8) -> void:
	items = p_items
	squares = p_squares


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 250)
	_runner = Vector2(-0.03, 0.5)
	for i in items.size():
		var it: Array = items[i]
		if String(it[0]) == "":
			continue
		var b := Button.new()
		b.theme_type_variation = "LaneButton"
		b.clip_text = false
		b.focus_mode = Control.FOCUS_NONE
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Icon.make(String(it[2]), 26.0, Game.C_SAFFRON)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UI.label(tr(String(it[1])), "SubLabel", 21)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(l, 2)
		v.add_child(l)
		b.add_child(v)
		var idx := i
		b.pressed.connect(func(): kho(idx))
		add_child(b)
		_buttons[String(it[0])] = b
	resized.connect(_layout)
	_layout()


func face(i: int) -> int:
	return -1 if i % 2 == 0 else 1   # -1: faces up the screen (his side is above the lane), 1: down


## Where square i is, in px.
func square_pos(i: int) -> Vector2:
	var m := 0.07 * size.x
	return Vector2(m + (size.x - 2.0 * m) * (float(i) + 0.5) / float(squares), size.y * 0.5)


func _layout() -> void:
	var w := (size.x * 0.86) / float(squares) * 1.9
	for i in items.size():
		var id := String(items[i][0])
		if not _buttons.has(id):
			continue
		var b: Button = _buttons[id]
		var c := square_pos(i)
		var h := size.y * 0.36
		b.size = Vector2(w, h)
		b.position = Vector2(c.x - w * 0.5, (c.y - size.y * 0.13 - h) if face(i) < 0 else (c.y + size.y * 0.13))


## The kho to square i: the active chaser runs up behind him; when the palm is on his back the choice is made.
func kho(i: int) -> void:
	if not _anim.is_empty():
		return
	Sfx.click()
	_anim = {"i": i, "t": 0.0, "from": _runner}
	_runner_side = -float(face(i))   # behind him: on the side his back is to


func _process(delta: float) -> void:
	_t += delta
	if not _anim.is_empty():
		_anim.t = float(_anim.t) + delta
		var i: int = _anim.i
		var c := square_pos(i)
		var to := Vector2(c.x / size.x - 0.02, 0.5 + _runner_side * 0.16)
		var k := clampf(float(_anim.t) / 0.32, 0.0, 1.0)
		_runner = (_anim.from as Vector2).lerp(to, k * k * (3.0 - 2.0 * k))
		if float(_anim.t) >= 0.32 and _risen != i:
			_risen = i
			_rise_t = 0.0
			Sfx.voice("hup", -6.0, 1.3)
		if float(_anim.t) >= 0.55:
			var id := String(items[i][0])
			_anim = {}
			picked.emit(id)
	if _risen >= 0:
		_rise_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var y := s.y * 0.5
	var m := 0.07 * s.x
	# The ground: a band of beaten earth, darker at its edges.
	var band := Rect2(0, y - s.y * 0.13, s.x, s.y * 0.26)
	draw_rect(band, Color(Game.C_CLAY, 0.78))
	draw_rect(Rect2(band.position, Vector2(s.x, 3)), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(band.position + Vector2(0, band.size.y - 3), Vector2(s.x, 3)), Color(0, 0, 0, 0.25))
	var chalk := Color(Game.C_CHALK, 0.9)
	# The central lane from pole to pole, and the cross lanes through it.
	draw_line(Vector2(m, y - 5), Vector2(s.x - m, y - 5), chalk, 2.0, true)
	draw_line(Vector2(m, y + 5), Vector2(s.x - m, y + 5), chalk, 2.0, true)
	for i in squares:
		var c := square_pos(i)
		draw_line(Vector2(c.x - 7, band.position.y), Vector2(c.x - 7, band.end.y), Color(chalk, 0.5), 1.5, true)
		draw_line(Vector2(c.x + 7, band.position.y), Vector2(c.x + 7, band.end.y), Color(chalk, 0.5), 1.5, true)
	for px in [m, s.x - m]:
		draw_line(Vector2(px, band.position.y), Vector2(px, band.end.y), Color(chalk, 0.6), 2.0, true)
		# The pole, standing.
		draw_rect(Rect2(px - 4, y - 46, 8, 46), Color("d8b07a"))
		draw_rect(Rect2(px - 7, y - 3, 14, 6), Color("8a5a2b"))
	# The seated chasers.
	for i in squares:
		if i == _risen:
			_draw_riser(i)
		else:
			_draw_sitter(square_pos(i), face(i), i)
	# The active chaser, on his feet.
	var rp := Vector2(_runner.x * s.x, y + (_runner.y - 0.5) * s.y * 0.9)
	_draw_runner(rp, 1.0 if _anim.is_empty() else 1.0)
	if not _anim.is_empty() and float(_anim.t) > 0.26:
		var c2 := square_pos(int(_anim.i))
		var f: Font = Game.font_display
		var fs := 44
		var txt := tr("CALL_KHO")
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := c2 + Vector2(-tw * 0.5, -s.y * 0.2 * float(face(int(_anim.i))) * -1.0 - 20)
		draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.1, 0.04, 0.02, 0.9))
		draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Game.C_SAFFRON)


## A chaser squatting on his toes in his square: from the side his face or his back, in the home side's colours.
func _draw_sitter(c: Vector2, fc: int, i: int) -> void:
	var shirt := Game.C_SAFFRON if i % 2 == 0 else Game.C_SAFFRON.darkened(0.12)
	var skin := Color("a86b45")
	var bob := sin(_t * 2.0 + i) * 1.2
	var base := c + Vector2(0, 2 + bob)
	draw_circle(base + Vector2(0, 6), 13, Color(0, 0, 0, 0.25))
	# Knees up and the body bent over them, seen across the lane.
	draw_colored_polygon(PackedVector2Array([base + Vector2(-11, 0), base + Vector2(11, 0), base + Vector2(8, -22), base + Vector2(-8, -22)]), shirt)
	draw_circle(base + Vector2(0, -30), 8.5, skin)
	draw_circle(base + Vector2(0, -33), 8.5, Color("1a120d"))   # hair over the crown
	if fc > 0:
		draw_circle(base + Vector2(0, -28), 6.5, skin)          # his face toward us
		draw_circle(base + Vector2(-2.5, -29), 1.2, Color("1a120d"))
		draw_circle(base + Vector2(2.5, -29), 1.2, Color("1a120d"))
	else:
		var f: Font = Game.font_bold
		draw_string(f, base + Vector2(-5, -6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.05, 0.02))
	draw_rect(Rect2(base + Vector2(-12, -2), Vector2(24, 4)), skin.darkened(0.15))


## The chaser given the kho: up and away toward his side.
func _draw_riser(i: int) -> void:
	var c := square_pos(i)
	var k := clampf(_rise_t / 0.25, 0.0, 1.0)
	var p := c + Vector2(_rise_t * 160.0, float(face(i)) * _rise_t * 220.0)
	_draw_runner(p, 1.0 - clampf(_rise_t - 0.3, 0.0, 1.0), Game.C_SAFFRON, k)


func _draw_runner(p: Vector2, alpha := 1.0, shirt := Game.C_SAFFRON, _k := 1.0) -> void:
	if alpha <= 0.0:
		return
	var skin := Color("a86b45")
	var ph := _t * 12.0
	draw_circle(p + Vector2(0, 10), 12, Color(0, 0, 0, 0.25 * alpha))
	var hip := p + Vector2(0, -16)
	draw_line(hip, hip + Vector2(sin(ph) * 9, 22), Color(skin, alpha), 5.0, true)
	draw_line(hip, hip + Vector2(-sin(ph) * 9, 22), Color(skin, alpha), 5.0, true)
	draw_colored_polygon(PackedVector2Array([hip + Vector2(-9, 2), hip + Vector2(9, 2), hip + Vector2(12, -24), hip + Vector2(-6, -26)]), Color(shirt, alpha))
	draw_circle(hip + Vector2(4, -33), 8.5, Color(skin, alpha))
	draw_line(hip + Vector2(6, -20), hip + Vector2(20, -10 + cos(ph) * 5), Color(skin, alpha), 4.0, true)
