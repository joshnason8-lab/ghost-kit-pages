class_name Backdrop
extends Control
## The menus' background: a parish field at dusk, drawn in code. The sky going from deep blue to the last orange
## over the hills, the floodlight masts coming on, the tall H of the goalposts and the ball-stop net behind them,
## the line of trees, the grass in the near ground. Dim enough to read over.

static var _sky: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func _textures() -> void:
	if _sky:
		return
	var g := Gradient.new()
	g.set_color(0, Color("142042"))
	g.add_point(0.55, Color("4a3a5e"))
	g.add_point(0.8, Color("c4644a"))
	g.set_color(1, Color("f0a050"))
	_sky = GradientTexture2D.new()
	_sky.gradient = g
	_sky.fill_from = Vector2(0.5, 0.0)
	_sky.fill_to = Vector2(0.5, 1.0)
	_sky.width = 8
	_sky.height = 256


func _draw() -> void:
	_textures()
	var s := size
	var horizon := s.y * 0.62
	draw_texture_rect(_sky, Rect2(0, 0, s.x, horizon + 2), false)
	# Hills, then trees, along the horizon.
	var hills := PackedVector2Array([Vector2(0, horizon)])
	var n := 24
	for i in n + 1:
		var x := s.x * float(i) / n
		hills.append(Vector2(x, horizon - s.y * (0.05 + 0.04 * absf(sin(i * 0.9 + 0.4)) + 0.02 * sin(i * 2.7))))
	hills.append(Vector2(s.x, horizon))
	draw_colored_polygon(hills, Color("2a2a3e"))
	var trees := PackedVector2Array([Vector2(0, horizon + 4)])
	for i in 61:
		var x := s.x * float(i) / 60.0
		trees.append(Vector2(x, horizon - s.y * (0.012 + 0.025 * absf(sin(i * 1.7)) + 0.012 * absf(sin(i * 4.1)))))
	trees.append(Vector2(s.x, horizon + 4))
	draw_colored_polygon(trees, Color("161c1c"))
	# The field.
	draw_rect(Rect2(0, horizon, s.x, s.y - horizon), Color("17301f"))
	for i in 6:
		var y := horizon + (s.y - horizon) * pow(float(i + 1) / 6.0, 1.6)
		draw_rect(Rect2(0, y, s.x, (s.y - horizon) * 0.05), Color(0.12, 0.25, 0.15, 0.55))
	# The goalposts on the right, the ball-stop net behind.
	var gx := s.x * 0.8
	var post_h := s.y * 0.42
	var gap := s.x * 0.075
	var net := Color(0.85, 0.85, 0.9, 0.08)
	for i in 14:
		var x := gx - gap * 1.6 + i * gap * 0.25
		draw_line(Vector2(x, horizon - post_h * 0.75), Vector2(x, horizon), net, 1.0)
	for j in 10:
		var y := horizon - post_h * 0.75 + j * post_h * 0.075
		draw_line(Vector2(gx - gap * 1.6, y), Vector2(gx + gap * 1.65, y), net, 1.0)
	var post := Color("e8e4dc")
	draw_line(Vector2(gx - gap * 0.5, horizon - post_h), Vector2(gx - gap * 0.5, horizon + 6), post, 4.0)
	draw_line(Vector2(gx + gap * 0.5, horizon - post_h), Vector2(gx + gap * 0.5, horizon + 6), post, 4.0)
	draw_line(Vector2(gx - gap * 0.5, horizon - post_h * 0.22), Vector2(gx + gap * 0.5, horizon - post_h * 0.22), post, 4.0)
	# Floodlight masts with their lamps on.
	for mx in [0.12, 0.55]:
		var x: float = s.x * mx
		var top := horizon - s.y * 0.5
		draw_line(Vector2(x, top), Vector2(x, horizon + 4), Color("2a2c34"), 3.0)
		draw_rect(Rect2(x - 18, top - 10, 36, 14), Color("2a2c34"))
		for k in 4:
			draw_circle(Vector2(x - 13 + k * 8.7, top - 3), 3.2, Color(1.0, 0.95, 0.8))
		draw_circle(Vector2(x, top - 3), 40.0, Color(1.0, 0.9, 0.7, 0.05))
	# A darker veil, so text over it reads.
	draw_rect(Rect2(Vector2.ZERO, s), Color(Game.C_BG, 0.45))
