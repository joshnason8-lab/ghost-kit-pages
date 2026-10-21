class_name PitchDiagram
extends Control
## How to Play's picture of the pitch, to scale: the 13, 20, 45 and 65 m lines, the halfway line, the small and
## large rectangles, the arc, the goals, and where the fifteen stand at the throw-in.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var k := minf((s.x - 20.0) / Pitch.LENGTH, (s.y - 40.0) / Pitch.WIDTH)
	var o := (s - Vector2(Pitch.LENGTH, Pitch.WIDTH) * k) * 0.5
	var P := func(x: float, z: float) -> Vector2: return o + Vector2(x + Pitch.HALF_L, z + Pitch.HALF_W) * k
	draw_rect(Rect2(P.call(-Pitch.HALF_L, -Pitch.HALF_W), Vector2(Pitch.LENGTH, Pitch.WIDTH) * k), Color("1f5a32"))
	for i in 14:
		if i % 2 == 0:
			draw_rect(Rect2(P.call(-Pitch.HALF_L + i * 10.0, -Pitch.HALF_W), Vector2(10.0, Pitch.WIDTH) * k), Color(1, 1, 1, 0.04))
	var w := Color(1, 1, 1, 0.85)
	draw_rect(Rect2(P.call(-Pitch.HALF_L, -Pitch.HALF_W), Vector2(Pitch.LENGTH, Pitch.WIDTH) * k), w, false, 2.0)
	draw_line(P.call(0, -Pitch.HALF_W), P.call(0, Pitch.HALF_W), w, 1.5)
	var font := Game.font_bold
	for side: float in [-1.0, 1.0]:
		var ex := Pitch.HALF_L * side
		for d in Pitch.LINES:
			var x: float = ex - float(d) * side
			draw_line(P.call(x, -Pitch.HALF_W), P.call(x, Pitch.HALF_W), w, 1.2)
			draw_string(font, P.call(x, -Pitch.HALF_W) + Vector2(-8, -6), str(int(d)), HORIZONTAL_ALIGNMENT_CENTER, 16, 13, Color(1, 1, 1, 0.8))
		for r in [[Pitch.SMALL_W, Pitch.SMALL_D], [Pitch.LARGE_W, Pitch.LARGE_D]]:
			var a: Vector2 = P.call(ex - float(r[1]) * side, -float(r[0]) * 0.5)
			var b: Vector2 = P.call(ex, float(r[0]) * 0.5)
			draw_rect(Rect2(Vector2(minf(a.x, b.x), a.y), Vector2(absf(b.x - a.x), b.y - a.y)), w, false, 1.2)
		var c: Vector2 = P.call(ex - 20.0 * side, 0)
		var a0 := PI * 0.5 if side > 0 else -PI * 0.5
		draw_arc(c, Pitch.ARC_R * k, a0, a0 + PI, 24, w, 1.2)
		draw_line(P.call(ex, -Pitch.POST_GAP * 0.5), P.call(ex, Pitch.POST_GAP * 0.5), Game.C_GOLD, 4.0)
	# The fifteen, at their places when the ball is thrown in: one side gold, one cream.
	for t in 2:
		var dirx := 1.0 if t == 0 else -1.0
		for n in range(1, 16):
			var sh: Array = DB.SHIRTS[n]
			var line := int(sh[0])
			var depth: float = TeamAI.LINE_X.get(line, 70.0)
			var x := (depth - Pitch.HALF_L) * dirx
			var z := -float(sh[1]) * (TeamAI.LANE_Z if line != DB.POS_MF else 14.0) * dirx
			var p: Vector2 = P.call(x + (2.0 * dirx if line == DB.POS_MF else 0.0), z)
			draw_circle(p, 7.0, Game.C_GOLD if t == 0 else Game.C_PAPER)
			draw_string(font, p + Vector2(-8, 4), str(n), HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Game.C_PRINT)
