class_name Colours
extends Control
## A county's colours, drawn as a little jersey in its kit design (no crest: the counties' crests are their
## boards'): the body in the first colour, the trim, hoop, sash or sleeves in the second.

var id := ""


static func make(p_id: String, px := 30) -> Colours:
	var c := Colours.new()
	c.id = p_id
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void:
	var t := DB.team(id)
	var c1: Color = t.c1
	var c2: Color = t.c2
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# The jersey's outline: shoulders, sleeves, body.
	var body := PackedVector2Array([p.call(0.3, 0.12), p.call(0.42, 0.08), p.call(0.5, 0.16), p.call(0.58, 0.08),
		p.call(0.7, 0.12), p.call(0.96, 0.32), p.call(0.84, 0.46), p.call(0.76, 0.4), p.call(0.76, 0.92),
		p.call(0.24, 0.92), p.call(0.24, 0.4), p.call(0.16, 0.46), p.call(0.04, 0.32)])
	draw_colored_polygon(body, Color(0.05, 0.05, 0.05, 0.6))
	var inner := PackedVector2Array()
	var cen: Vector2 = p.call(0.5, 0.5)
	for v in body:
		inner.append(cen + (v - cen) * 0.9)
	draw_colored_polygon(inner, c1)
	match int(t.design):
		1:
			draw_rect(Rect2(p.call(0.27, 0.42), Vector2(0.46, 0.14) * s), c2)
		2:
			draw_colored_polygon(PackedVector2Array([p.call(0.3, 0.16), p.call(0.42, 0.14), p.call(0.72, 0.86), p.call(0.6, 0.88)]), c2)
		3:
			draw_colored_polygon(PackedVector2Array([p.call(0.12, 0.3), p.call(0.27, 0.16), p.call(0.27, 0.42), p.call(0.18, 0.43)]), c2)
			draw_colored_polygon(PackedVector2Array([p.call(0.88, 0.3), p.call(0.73, 0.16), p.call(0.73, 0.42), p.call(0.82, 0.43)]), c2)
	# The collar.
	draw_polyline(PackedVector2Array([p.call(0.42, 0.1), p.call(0.5, 0.2), p.call(0.58, 0.1)]), c2, maxf(1.5, s * 0.06), true)
