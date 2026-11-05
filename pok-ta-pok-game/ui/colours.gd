class_name Colours
extends Control
## A town's colours as the players carry them: a faja, the cloth belt tied over the leather, drawn as a short band in
## the first colour with a woven stripe of the second and its ends hanging from the knot.

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
	var edge := Color(0.05, 0.04, 0.03, 0.7)
	# The band, gently curved as it sits round the hips.
	var band := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		band.append(p.call(0.04 + 0.92 * u, 0.3 + 0.06 * sin(u * PI)))
	for i in 9:
		var u := 1.0 - float(i) / 8.0
		band.append(p.call(0.04 + 0.92 * u, 0.6 + 0.06 * sin(u * PI)))
	draw_colored_polygon(band, edge)
	var inner := PackedVector2Array()
	for v in band:
		inner.append(p.call(0.5, 0.48) + (v - p.call(0.5, 0.48)) * 0.92)
	draw_colored_polygon(inner, c1)
	# The woven stripe.
	var stripe := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		stripe.append(p.call(0.08 + 0.84 * u, 0.43 + 0.06 * sin(u * PI)))
	draw_polyline(stripe, c2, maxf(1.5, s * 0.07), true)
	# The knot and the hanging ends.
	draw_circle(p.call(0.74, 0.5), s * 0.09, c1.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([p.call(0.7, 0.55), p.call(0.78, 0.55), p.call(0.74, 0.95), p.call(0.66, 0.92)]), c1.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([p.call(0.76, 0.55), p.call(0.84, 0.56), p.call(0.88, 0.9), p.call(0.8, 0.93)]), c1.darkened(0.2))
