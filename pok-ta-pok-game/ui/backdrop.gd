class_name Backdrop
extends Control
## The menus' background: a village court in southern Sinaloa at dusk, drawn in code. The sky from deep blue to the
## last orange over the low hills of the Sierra, coconut palms and a broad rain tree against it, low flat-roofed houses,
## agave in the scrub, and the long earth court with its analco in the near ground. Dim enough to read over.

static var _sky: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func _textures() -> void:
	if _sky:
		return
	var g := Gradient.new()
	g.set_color(0, Color("1a2140"))
	g.add_point(0.5, Color("5a3d5c"))
	g.add_point(0.8, Color("c66a45"))
	g.set_color(1, Color("eea35a"))
	_sky = GradientTexture2D.new()
	_sky.gradient = g
	_sky.fill_from = Vector2(0.5, 0.0)
	_sky.fill_to = Vector2(0.5, 1.0)
	_sky.width = 8
	_sky.height = 256


func _draw() -> void:
	_textures()
	var s := size
	var horizon := s.y * 0.6
	draw_texture_rect(_sky, Rect2(0, 0, s.x, horizon + 2), false)
	# The low sun.
	draw_circle(Vector2(s.x * 0.72, horizon - s.y * 0.03), s.y * 0.035, Color(1.0, 0.82, 0.55, 0.9))
	draw_circle(Vector2(s.x * 0.72, horizon - s.y * 0.03), s.y * 0.09, Color(1.0, 0.7, 0.4, 0.12))
	# The Sierra's low hills.
	var hills := PackedVector2Array([Vector2(0, horizon)])
	for i in 31:
		var x := s.x * float(i) / 30.0
		hills.append(Vector2(x, horizon - s.y * (0.06 + 0.05 * absf(sin(i * 0.45 + 0.8)) + 0.015 * sin(i * 1.9))))
	hills.append(Vector2(s.x, horizon))
	draw_colored_polygon(hills, Color("3a2b3e"))
	var ink := Color("1c1418")
	# Low houses with flat roofs along the far side of the court.
	var hx := s.x * 0.03
	var k := 0
	while hx < s.x:
		var w := s.x * (0.06 + 0.03 * absf(sin(k * 2.3)))
		var h := s.y * (0.05 + 0.012 * absf(sin(k * 1.7)))
		draw_rect(Rect2(hx, horizon - h, w, h + 2), ink.lightened(0.04))
		draw_rect(Rect2(hx - 2, horizon - h - s.y * 0.006, w + 4, s.y * 0.008), ink)
		if k % 2 == 0:
			draw_rect(Rect2(hx + w * 0.3, horizon - h * 0.55, w * 0.12, h * 0.25), Color(1.0, 0.75, 0.4, 0.55))
		hx += w + s.x * (0.03 + 0.05 * absf(sin(k * 3.1)))
		k += 1
	# Palms and a rain tree against the sky.
	for px in [0.12, 0.17, 0.58, 0.88]:
		_palm(Vector2(s.x * px, horizon + 2), s.y * (0.3 + 0.06 * sin(px * 20.0)), ink)
	_rain_tree(Vector2(s.x * 0.36, horizon + 2), s.y * 0.22, ink)
	# The ground, and the long court of earth with its side lines and the analco across it.
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color("4a2e20"))
	var court := PackedVector2Array([Vector2(s.x * 0.05, s.y * 0.8), Vector2(s.x * 0.95, s.y * 0.8), Vector2(s.x * 1.1, s.y * 0.95),
		Vector2(-s.x * 0.1, s.y * 0.95)])
	draw_colored_polygon(court, Color("6a3e28"))
	draw_polyline(PackedVector2Array([court[0], court[1], court[2], court[3], court[0]]), Color(0.9, 0.85, 0.75, 0.35), 2.0)
	draw_line(Vector2(s.x * 0.5, s.y * 0.8), Vector2(s.x * 0.5, s.y * 0.95), Color(0.95, 0.85, 0.6, 0.6), 3.0)
	# Agave in the scrub near the court.
	for ax in [0.03, 0.26, 0.47, 0.69, 0.97]:
		_agave(Vector2(s.x * ax, s.y * 0.77), s.y * 0.05, Color("2a3a36"))
	# A darker veil, so text over it reads.
	draw_rect(Rect2(Vector2.ZERO, s), Color(Game.C_BG, 0.45))


func _palm(base: Vector2, h: float, col: Color) -> void:
	var top := base + Vector2(h * 0.12, -h)
	draw_polyline(PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(-h * 0.03, 0), top]), col, maxf(2.0, h * 0.025), true)
	for i in 9:
		var a := -PI * 0.5 + (float(i) - 4.0) * 0.38
		var tip := top + Vector2(cos(a), sin(a)) * h * 0.32 + Vector2(0, h * 0.12 * absf(float(i) - 4.0) / 4.0)
		draw_polyline(PackedVector2Array([top, top.lerp(tip, 0.5) + Vector2(0, -h * 0.05), tip]), col, maxf(1.5, h * 0.018), true)


func _rain_tree(base: Vector2, h: float, col: Color) -> void:
	draw_line(base, base + Vector2(0, -h * 0.55), col, maxf(3.0, h * 0.06))
	for i in 7:
		var c := base + Vector2((float(i) - 3.0) * h * 0.28, -h * (0.62 + 0.12 * cos(float(i) - 3.0)))
		draw_circle(c, h * 0.26, col)


func _agave(base: Vector2, h: float, col: Color) -> void:
	for i in 9:
		var a := -PI * 0.5 + (float(i) - 4.0) * 0.32
		var tip := base + Vector2(cos(a), sin(a)) * h
		var side := Vector2(-sin(a), cos(a)) * h * 0.08
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), col)
