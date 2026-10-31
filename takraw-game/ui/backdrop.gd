class_name Backdrop
extends Control
## The menus' background: deep navy, a warm glow low on the right, and the faint lines of a
## takraw court in perspective, so every screen feels like it sits in an arena.

var glow := Game.C_SAFFRON
var lines := true

static var _base: GradientTexture2D
static var _glow: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func _textures() -> void:
	if _base:
		return
	var g := Gradient.new()
	g.set_color(0, Color("1b3a5c"))
	g.set_color(1, Color("08121e"))
	_base = GradientTexture2D.new()
	_base.gradient = g
	_base.fill = GradientTexture2D.FILL_RADIAL
	_base.fill_from = Vector2(0.25, 0.1)
	_base.fill_to = Vector2(1.15, 1.1)
	_base.width = 256
	_base.height = 256
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	_glow = GradientTexture2D.new()
	_glow.gradient = gg
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128


func _draw() -> void:
	_textures()
	var s := size
	draw_texture_rect(_base, Rect2(Vector2.ZERO, s), false)
	draw_texture_rect(_glow, Rect2(s.x * 0.45, s.y * 0.35, s.x * 0.9, s.y * 1.2), false, Color(glow, 0.13))
	draw_texture_rect(_glow, Rect2(-s.x * 0.25, -s.y * 0.5, s.x * 0.7, s.y * 1.0), false, Color(0.35, 0.6, 1.0, 0.07))
	if not lines:
		return
	# A takraw court seen from the stands: the back lines, the centre line under the net, the side lines, the quarter
	# circles at the net and the service circles.
	var near_y := s.y * 1.08
	var far_y := s.y * 0.5
	var near_w := s.x * 1.5
	var far_w := s.x * 0.62
	var cx := s.x * 0.58
	var at := func(d: float, u: float) -> Vector2:
		var k := d / (d + 0.6 * (1.0 - d))
		return Vector2(cx + (u - 0.5) * lerpf(near_w, far_w, k), lerpf(near_y, far_y, k))
	var c := Color(1, 1, 1, 0.045)
	var hi := Color(Game.C_GOLD, 0.06)
	for d in [0.0, 0.5, 1.0]:
		draw_line(at.call(d, 0.0), at.call(d, 1.0), hi if d == 0.5 else c, 3.0 if d == 0.5 else 2.0, true)
	for u in [0.0, 1.0]:
		draw_line(at.call(0.0, u), at.call(1.0, u), c, 2.0, true)
	# Quarter circles (0.9 m of a 13.4 m court) and service circles (2.45 m from each back line).
	for d0 in [0.5]:
		for u0 in [0.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * 0.5 * float(i) / 12.0
				var dd := (0.9 / 13.4) * cos(a)
				var uu := (0.9 / 6.1) * sin(a)
				pts.append(at.call(d0 - dd, absf(u0 - uu)))
			draw_polyline(pts, c, 1.5, true)
			var pts2 := PackedVector2Array()
			for i in 13:
				var a := PI * 0.5 * float(i) / 12.0
				pts2.append(at.call(d0 + (0.9 / 13.4) * cos(a), absf(u0 - (0.9 / 6.1) * sin(a))))
			draw_polyline(pts2, c, 1.5, true)
	for d in [2.45 / 13.4, 1.0 - 2.45 / 13.4]:
		var ring := PackedVector2Array()
		for i in 25:
			var a := TAU * float(i) / 24.0
			ring.append(at.call(d + (0.3 / 13.4) * cos(a), 0.5 + (0.3 / 6.1) * sin(a)))
		draw_polyline(ring, c, 1.5, true)
