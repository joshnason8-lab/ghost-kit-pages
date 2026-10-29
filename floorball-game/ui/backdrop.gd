class_name Backdrop
extends Control
## The menus' background: the hall with its lights down before a match. Deep navy, lit from above in the middle; the
## rink's lines faint on the floor, in perspective; two slanted streaks of the icon's colours (flame orange, electric
## blue) across it. All drawn in code: no image ships for it.

var with_frame := true   # kept for the screens that ask; the hall has no frame


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Game.C_BG)
	# The lights over the middle of the hall: soft rings of a lighter navy.
	var c := Vector2(s.x * 0.62, -s.y * 0.15)
	for i in 10:
		var r := s.length() * (0.95 - i * 0.08)
		draw_circle(c, r, Color(0.16, 0.24, 0.42, 0.05))
	# The rink on the floor below, in perspective: its outline and centre line, faint electric blue.
	var horizon := s.y * 0.42
	var line := Color(Game.C_CYAN, 0.07)
	var pts := PackedVector2Array([Vector2(s.x * 0.18, s.y * 1.05), Vector2(s.x * 0.36, horizon), Vector2(s.x * 0.88, horizon),
		Vector2(s.x * 1.12, s.y * 1.05)])
	draw_polyline(pts, line, 3.0, true)
	draw_line(Vector2(s.x * 0.62, horizon), Vector2(s.x * 0.65, s.y * 1.05), line, 3.0, true)
	var mid := Vector2(s.x * 0.635, horizon + (s.y * 1.05 - horizon) * 0.42)
	_ellipse(mid, Vector2(s.x * 0.09, s.y * 0.06), line)
	# Two slanted streaks: the icon's flame and blade.
	_streak(Vector2(-s.x * 0.05, s.y * 0.92), Vector2(s.x * 0.55, s.y * 0.58), s.y * 0.05, Color(Game.C_MAGNET, 0.10))
	_streak(Vector2(-s.x * 0.05, s.y * 1.0), Vector2(s.x * 0.62, s.y * 0.62), s.y * 0.02, Color(Game.C_CYAN, 0.10))
	# Darker at the edges.
	draw_rect(Rect2(0, s.y * 0.88, s.x, s.y * 0.12), Color(0, 0, 0, 0.18))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, 3.0, true)


## A band from a to b, w thick, fading out at both ends.
func _streak(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var steps := 12
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var k := sin(PI * (t0 + t1) * 0.5)
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		draw_colored_polygon(PackedVector2Array([p0 - n, p1 - n, p1 + n, p0 + n]), Color(col, col.a * k))


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
