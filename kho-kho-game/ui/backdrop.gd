class_name Backdrop
extends Control
## The menus' background: dusk over a beaten-earth ground, warm low on the left where the sun has gone, and the faint
## chalk of a kho kho field in perspective: the central lane running away between its two poles, the cross lanes over
## it, so every screen sits on a ground.

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
	g.set_color(0, Color("3a2018"))
	g.set_color(1, Color("120b09"))
	_base = GradientTexture2D.new()
	_base.gradient = g
	_base.fill = GradientTexture2D.FILL_RADIAL
	_base.fill_from = Vector2(0.2, 0.9)
	_base.fill_to = Vector2(1.2, 0.0)
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
	draw_texture_rect(_glow, Rect2(-s.x * 0.3, s.y * 0.3, s.x * 1.0, s.y * 1.1), false, Color(glow, 0.12))
	draw_texture_rect(_glow, Rect2(s.x * 0.5, -s.y * 0.6, s.x * 0.8, s.y * 1.0), false, Color(0.35, 0.4, 0.95, 0.06))
	if not lines:
		return
	# The field seen from behind one pole: the lane runs away to the far pole; the cross lanes cross it.
	var near_y := s.y * 1.1
	var far_y := s.y * 0.46
	var near_w := s.x * 1.7
	var far_w := s.x * 0.5
	var cx := s.x * 0.5
	var at := func(d: float, u: float) -> Vector2:
		var k := d / (d + 0.55 * (1.0 - d))
		return Vector2(cx + (u - 0.5) * lerpf(near_w, far_w, k), lerpf(near_y, far_y, k))
	var c := Color(Game.C_CHALK, 0.05)
	var hi := Color(Game.C_CHALK, 0.08)
	for u in [0.0, 1.0]:
		draw_line(at.call(0.0, u), at.call(1.0, u), c, 2.0, true)
	draw_line(at.call(0.0, 0.0), at.call(0.0, 1.0), c, 2.0, true)
	draw_line(at.call(1.0, 0.0), at.call(1.0, 1.0), c, 2.0, true)
	# The lane (30 cm of a 16 m width) from pole to pole, and the cross lanes.
	for u in [0.49, 0.51]:
		draw_line(at.call(0.06, u), at.call(0.94, u), hi, 1.5, true)
	for i in 8:
		var d := 0.06 + (0.88 / 9.0) * float(i + 1)
		draw_line(at.call(d, 0.0), at.call(d, 1.0), c, 1.5, true)
	for d in [0.06, 0.94]:
		var top: Vector2 = at.call(d, 0.5)
		draw_line(top, top - Vector2(0, lerpf(60.0, 18.0, d)), Color(Game.C_GOLD, 0.14), lerpf(7.0, 2.5, d), true)
