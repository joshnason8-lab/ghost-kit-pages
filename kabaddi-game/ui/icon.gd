class_name Icon
extends Control
## Small vector icons drawn in code, so they stay crisp at any size and need no font glyphs.

var kind := "play"
var color := Game.C_INK
var stroke := 0.09   # line width as a fraction of the icon size


static func make(p_kind: String, px := 28.0, p_color := Game.C_INK) -> Icon:
	var i := Icon.new()
	i.kind = p_kind
	i.color = p_color
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _ready() -> void:
	resized.connect(queue_redraw)


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	return o + Vector2(x, y) * s


func _w() -> float:
	return maxf(1.5, minf(size.x, size.y) * stroke)


func _line(pts: Array) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_p(p[0], p[1]))
	draw_polyline(v, color, _w(), true)


func _fill(pts: Array, c := Color(0, 0, 0, 0)) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(_p(p[0], p[1]))
	draw_colored_polygon(v, color if c.a == 0.0 else c)


func _circle(x: float, y: float, r: float, filled := false) -> void:
	var s := minf(size.x, size.y)
	if filled:
		draw_circle(_p(x, y), r * s, color)
	else:
		draw_arc(_p(x, y), r * s, 0, TAU, 32, color, _w(), true)


func _draw() -> void:
	match kind:
		"back":
			_line([[0.62, 0.2], [0.32, 0.5], [0.62, 0.8]])
		"next":
			_line([[0.38, 0.2], [0.68, 0.5], [0.38, 0.8]])
		"play":
			_fill([[0.3, 0.18], [0.82, 0.5], [0.3, 0.82]])
		"check":
			_line([[0.2, 0.52], [0.42, 0.74], [0.82, 0.28]])
		"close":
			_line([[0.25, 0.25], [0.75, 0.75]])
			_line([[0.75, 0.25], [0.25, 0.75]])
		"gear":
			var s := minf(size.x, size.y)
			for k in 8:
				var a := TAU * k / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(_p(0.5, 0.5) + d * s * 0.26, _p(0.5, 0.5) + d * s * 0.44, color, _w() * 1.6, true)
			_circle(0.5, 0.5, 0.27)
			_circle(0.5, 0.5, 0.1)
		"book":
			_line([[0.5, 0.26], [0.5, 0.82]])
			_line([[0.5, 0.26], [0.16, 0.2], [0.16, 0.76], [0.5, 0.82], [0.84, 0.76], [0.84, 0.2], [0.5, 0.26]])
		"whistle":
			_circle(0.42, 0.6, 0.22)
			_line([[0.5, 0.39], [0.86, 0.39], [0.86, 0.53], [0.62, 0.53]])
			_line([[0.3, 0.28], [0.22, 0.14]])
		"trophy":
			_line([[0.3, 0.18], [0.7, 0.18], [0.66, 0.5], [0.5, 0.6], [0.34, 0.5], [0.3, 0.18]])
			_line([[0.3, 0.24], [0.14, 0.26], [0.2, 0.42], [0.33, 0.44]])
			_line([[0.7, 0.24], [0.86, 0.26], [0.8, 0.42], [0.67, 0.44]])
			_line([[0.5, 0.6], [0.5, 0.74]])
			_line([[0.34, 0.82], [0.66, 0.82]])
		"globe":
			_circle(0.5, 0.5, 0.34)
			_line([[0.16, 0.5], [0.84, 0.5]])
			var s2 := minf(size.x, size.y)
			draw_arc(_p(0.5, 0.5), s2 * 0.34, -PI / 2, PI / 2, 24, color, _w(), true)
			draw_set_transform(_p(0.5, 0.5), 0, Vector2(0.45, 1))
			draw_arc(Vector2.ZERO, s2 * 0.34, 0, TAU, 32, color, _w() * 1.5, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"mic":
			_line([[0.4, 0.2], [0.4, 0.52], [0.5, 0.6], [0.6, 0.52], [0.6, 0.2], [0.5, 0.14], [0.4, 0.2]])
			_line([[0.28, 0.46], [0.3, 0.6], [0.5, 0.72], [0.7, 0.6], [0.72, 0.46]])
			_line([[0.5, 0.72], [0.5, 0.86]])
		"lock":
			_line([[0.24, 0.46], [0.76, 0.46], [0.76, 0.86], [0.24, 0.86], [0.24, 0.46]])
			_line([[0.34, 0.46], [0.34, 0.32], [0.5, 0.18], [0.66, 0.32], [0.66, 0.46]])
		"star":
			var pts := []
			for k in 10:
				var a := -PI / 2 + TAU * k / 10.0
				var r := 0.42 if k % 2 == 0 else 0.18
				pts.append([0.5 + cos(a) * r, 0.52 + sin(a) * r])
			_fill(pts)
		"gavel":
			_line([[0.2, 0.84], [0.56, 0.48]])
			_fill([[0.44, 0.22], [0.66, 0.0 + 0.12], [0.88, 0.34], [0.66, 0.56]])
			_line([[0.12, 0.92], [0.5, 0.92]])
		"people":
			_circle(0.36, 0.3, 0.12)
			_circle(0.68, 0.34, 0.1)
			_line([[0.14, 0.84], [0.18, 0.6], [0.36, 0.5], [0.54, 0.6], [0.58, 0.84]])
			_line([[0.6, 0.56], [0.68, 0.52], [0.84, 0.6], [0.88, 0.8]])
		"bolt":
			_fill([[0.56, 0.08], [0.22, 0.56], [0.48, 0.56], [0.4, 0.92], [0.78, 0.4], [0.52, 0.4]])
		"sound":
			_fill([[0.14, 0.38], [0.32, 0.38], [0.52, 0.2], [0.52, 0.8], [0.32, 0.62], [0.14, 0.62]])
			var s3 := minf(size.x, size.y)
			draw_arc(_p(0.52, 0.5), s3 * 0.2, -0.9, 0.9, 12, color, _w(), true)
			draw_arc(_p(0.52, 0.5), s3 * 0.34, -0.9, 0.9, 16, color, _w(), true)
		"display":
			_line([[0.12, 0.2], [0.88, 0.2], [0.88, 0.68], [0.12, 0.68], [0.12, 0.2]])
			_line([[0.36, 0.84], [0.64, 0.84]])
			_line([[0.5, 0.68], [0.5, 0.84]])
		"flag":
			_line([[0.24, 0.9], [0.24, 0.12]])
			_fill([[0.27, 0.14], [0.82, 0.24], [0.62, 0.38], [0.82, 0.52], [0.27, 0.5]])
		_:
			_circle(0.5, 0.5, 0.3, true)
