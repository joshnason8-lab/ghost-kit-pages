class_name HurlerArt
extends Control
## The programme cover's picture, printed in two inks the way a county board's programme would be: a hurler at
## full stretch striking the sliotar, the hurley swung through, over a halftone sun going down behind the posts.
## Drawn in code (no image to ship); pose 0 the strike, 1 the high catch.

var pose := 0
var ink := Game.C_PRINT
var red := Game.C_MAGENTA
var paper := Game.C_PAPER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10 or h < 10:
		return
	var s := minf(w, h * 1.3)
	var o := Vector2((w - s) * 0.5, h - s / 1.3)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# The sun: halftone dots in red, bigger toward the middle.
	var sun: Vector2 = P.call(0.62, 0.42)
	var r := s * 0.3
	var step := maxf(5.0, s * 0.028)
	var y := sun.y - r
	while y < sun.y + r:
		var x := sun.x - r
		while x < sun.x + r:
			var d := Vector2(x, y).distance_to(sun) / r
			if d < 1.0:
				draw_circle(Vector2(x, y), step * 0.48 * (1.0 - d * 0.75), red)
			x += step
		y += step
	# The posts, far off, and the ground.
	var gy: float = P.call(0, 0.74).y
	for px in [0.78, 0.86]:
		draw_line(P.call(px, 0.2), Vector2(P.call(px, 0).x, gy), ink, maxf(2.0, s * 0.008))
	draw_line(P.call(0.78, 0.6), P.call(0.86, 0.6), ink, maxf(2.0, s * 0.008))
	draw_rect(Rect2(Vector2(o.x, gy), Vector2(s, maxf(2.0, s * 0.01))), ink)
	for i in 9:
		var gx: float = P.call(0.05 + i * 0.11, 0).x
		draw_line(Vector2(gx, gy + s * 0.03), Vector2(gx + s * 0.06, gy + s * 0.03), Color(ink, 0.5), 2.0)
	var lw := maxf(5.0, s * 0.045)
	if pose == 0:
		_striker(P, lw)
	else:
		_catcher(P, lw)


func _limb(a: Vector2, b: Vector2, c: Vector2, lw: float) -> void:
	draw_polyline(PackedVector2Array([a, b, c]), ink, lw, true)
	draw_circle(b, lw * 0.5, ink)
	draw_circle(c, lw * 0.45, ink)


func _striker(P: Callable, lw: float) -> void:
	var hip: Vector2 = P.call(0.36, 0.5)
	var neck: Vector2 = P.call(0.3, 0.27)
	var head: Vector2 = P.call(0.27, 0.2)
	# Legs: the left forward and bent, the right driving back.
	_limb(hip, P.call(0.46, 0.6), P.call(0.47, 0.73), lw)
	_limb(hip, P.call(0.3, 0.62), P.call(0.2, 0.72), lw)
	# The body, leaning into the strike.
	draw_line(hip, neck, ink, lw * 1.5)
	draw_circle(hip, lw * 0.8, ink)
	# The helmet, its guard.
	draw_circle(head, s_of(P) * 0.055, ink)
	draw_arc(head + Vector2(s_of(P) * 0.03, s_of(P) * 0.01), s_of(P) * 0.045, -0.9, 0.9, 8, paper, maxf(1.5, lw * 0.2))
	# Arms swung through, the hurley following round and up.
	var hands: Vector2 = P.call(0.5, 0.3)
	_limb(neck, P.call(0.4, 0.33), hands, lw * 0.8)
	_limb(neck, P.call(0.38, 0.27), hands + Vector2(-lw * 0.6, -lw * 0.2), lw * 0.8)
	var bas: Vector2 = P.call(0.66, 0.12)
	draw_line(hands, bas, ink, lw * 0.6)
	var dir := (bas - hands).normalized()
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([bas - n * lw * 0.4, bas + dir * lw * 2.4 - n * lw * 0.9, bas + dir * lw * 3.0 + n * lw * 0.3, bas + n * lw * 0.5]), ink)
	# The sliotar, away, and its flight.
	var ball: Vector2 = P.call(0.86, 0.06)
	for i in 3:
		draw_line(ball - Vector2(s_of(P) * (0.06 + i * 0.04), -s_of(P) * (0.01 + i * 0.012)), ball - Vector2(s_of(P) * (0.1 + i * 0.05), -s_of(P) * (0.014 + i * 0.016)), Color(ink, 0.6), 2.0)
	draw_circle(ball, s_of(P) * 0.024, ink)
	draw_circle(ball, s_of(P) * 0.017, paper)
	draw_arc(ball, s_of(P) * 0.017, 0.4, 2.6, 8, ink, 1.5)


func _catcher(P: Callable, lw: float) -> void:
	var hip: Vector2 = P.call(0.42, 0.42)
	var neck: Vector2 = P.call(0.42, 0.2)
	_limb(hip, P.call(0.5, 0.55), P.call(0.48, 0.68), lw)
	_limb(hip, P.call(0.36, 0.52), P.call(0.34, 0.64), lw)
	draw_line(hip, neck, ink, lw * 1.5)
	draw_circle(P.call(0.42, 0.13), s_of(P) * 0.055, ink)
	_limb(neck, P.call(0.47, 0.1), P.call(0.5, 0.0), lw * 0.8)
	var hand: Vector2 = P.call(0.36, 0.3)
	_limb(neck, P.call(0.34, 0.25), hand, lw * 0.8)
	draw_line(hand, P.call(0.18, 0.6), ink, lw * 0.6)
	draw_circle(P.call(0.5, -0.03), s_of(P) * 0.024, ink)
	draw_circle(P.call(0.5, -0.03), s_of(P) * 0.017, paper)


func s_of(P: Callable) -> float:
	return (P.call(1, 0) as Vector2).x - (P.call(0, 0) as Vector2).x
