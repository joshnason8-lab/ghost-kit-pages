class_name Backdrop
extends Control
## The menus' background: a coach's whiteboard on the wall of a Nordic sports hall. The board fills the screen: its
## white face with the faint grey ghosts of old erased tactics, the aluminium frame round it, the marker tray along
## the bottom with its pens, and two magnets in the corners. All drawn in code: no image ships for it.

var with_frame := true
var _ghosts := []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# Old, half-erased marker strokes: loops, arrows and crosses, very faint.
	for i in 14:
		var pts := PackedVector2Array()
		var c := Vector2(rng.randf(), rng.randf())
		var r := rng.randf_range(0.03, 0.12)
		var a0 := rng.randf() * TAU
		var n := rng.randi_range(5, 12)
		for k in n:
			var a := a0 + k * rng.randf_range(0.3, 0.7)
			pts.append(c + Vector2(cos(a) * r * 1.6, sin(a) * r) + Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.01, 0.01)))
		_ghosts.append(pts)
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	# The board's face, a touch darker toward the edges.
	draw_rect(Rect2(Vector2.ZERO, s), Game.C_BG)
	draw_rect(Rect2(s.x * 0.08, s.y * 0.08, s.x * 0.84, s.y * 0.78), Color(1, 1, 1, 0.35))
	for g in _ghosts:
		var pts := PackedVector2Array()
		for p in g:
			pts.append(p * s)
		draw_polyline(pts, Color(0.55, 0.6, 0.66, 0.1), 6.0, true)
	if not with_frame:
		return
	# The aluminium frame.
	var f := 10.0
	var frame := Game.C_FRAME
	draw_rect(Rect2(0, 0, s.x, f), frame)
	draw_rect(Rect2(0, s.y - f, s.x, f), frame.darkened(0.15))
	draw_rect(Rect2(0, 0, f, s.y), frame.darkened(0.05))
	draw_rect(Rect2(s.x - f, 0, f, s.y), frame.darkened(0.1))
	draw_line(Vector2(f, f), Vector2(s.x - f, f), Color(0, 0, 0, 0.12), 2.0)
	# The marker tray and its pens, bottom left.
	var ty := s.y - f - 6.0
	draw_rect(Rect2(s.x * 0.06, ty, s.x * 0.22, 6.0), frame.darkened(0.25))
	var pens := [Game.C_INK, Game.C_BLUE, Game.C_RED, Game.C_GREEN]
	for i in pens.size():
		var x := s.x * 0.075 + i * 46.0
		draw_rect(Rect2(x, ty - 9.0, 38.0, 9.0), Color("f4f4f2"))
		draw_rect(Rect2(x + 30.0, ty - 9.0, 8.0, 9.0), pens[i])


## A magnet: a coloured disc with a highlight and its shadow, as the board's tactics are drawn with.
static func magnet(ci: CanvasItem, at: Vector2, r: float, col: Color, label := "", font: Font = null, fs := 14) -> void:
	ci.draw_circle(at + Vector2(1.5, 3.0), r, Color(0, 0, 0, 0.22))
	ci.draw_circle(at, r, col)
	ci.draw_circle(at - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(1, 1, 1, 0.25))
	ci.draw_arc(at, r, 0, TAU, 24, col.darkened(0.3), 1.5, true)
	if label != "" and font:
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if col.get_luminance() < 0.6 else Game.C_INK)


## A marker stroke: a slightly wobbly line, as a hand draws it.
static func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 3.5, arrow := false) -> void:
	ci.draw_polyline(pts, col, w, true)
	if arrow and pts.size() >= 2:
		var a := pts[pts.size() - 1]
		var b := pts[pts.size() - 2]
		var d := (a - b).normalized()
		var n := Vector2(-d.y, d.x)
		ci.draw_polyline(PackedVector2Array([a - d * 14.0 + n * 8.0, a, a - d * 14.0 - n * 8.0]), col, w, true)
