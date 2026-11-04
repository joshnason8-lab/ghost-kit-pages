class_name Backdrop
extends Control
## The menus' background: the deep indigo of an arena with its lights down, a glow of court blue, and a netball
## court's lines seen from high above one end: the side lines running away, the two transverse lines across, the
## centre circle and the far goal circle, so every screen sits on the court.

var glow := Game.C_COURT
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
	g.set_color(0, Color("2a1f57"))
	g.set_color(1, Color("0b0818"))
	_base = GradientTexture2D.new()
	_base.gradient = g
	_base.fill = GradientTexture2D.FILL_RADIAL
	_base.fill_from = Vector2(0.7, 0.15)
	_base.fill_to = Vector2(-0.1, 1.1)
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
	draw_texture_rect(_glow, Rect2(Vector2(s.x * 0.35, s.y * 0.35), s * 0.95), false, Color(glow, 0.22))
	if not lines:
		return
	# The court in perspective: a point on the court (u across 0-1, v along 0 near .. 1 far) to the screen.
	var to_screen := func(u: float, v: float) -> Vector2:
		var depth := 1.0 + v * 2.4
		var cx := s.x * 0.62
		var y := s.y * 1.08 - (s.y * 0.95) * (1.0 - 1.0 / depth) * 1.25
		var half := s.x * 0.62 / depth
		return Vector2(cx + (u - 0.5) * 2.0 * half, y)
	var col := Color(1, 1, 1, 0.07)
	var w := 2.0
	var line := func(pts: Array):
		var pv := PackedVector2Array()
		for p in pts:
			pv.append(to_screen.call(p[0], p[1]))
		draw_polyline(pv, col, w, true)
	line.call([[0.0, 0.0], [0.0, 1.0]])
	line.call([[1.0, 0.0], [1.0, 1.0]])
	line.call([[0.0, 1.0], [1.0, 1.0]])
	for v: float in [1.0 / 3.0, 2.0 / 3.0]:
		line.call([[0.0, v], [1.0, v]])
	# The centre circle (at the middle third's middle) and the far goal circle (a semicircle on the far goal line).
	var circle := func(cu: float, cv: float, ru: float, rv: float, a0: float, a1: float):
		var pts := []
		for i in 33:
			var a := lerpf(a0, a1, i / 32.0)
			pts.append([cu + cos(a) * ru, cv + sin(a) * rv])
		line.call(pts)
	circle.call(0.5, 0.5, 0.03, 0.015, 0.0, TAU)
	circle.call(0.5, 1.0, 0.32, 0.16, PI, TAU)
	circle.call(0.5, 0.0, 0.32, 0.16, 0.0, PI)
