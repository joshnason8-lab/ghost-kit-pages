class_name RinkSketch
extends Control
## A floorball rink drawn in marker on the whiteboard, to scale (40 x 20 m, the creases and goalkeeper areas, the
## face-off dots), with a team's magnets on it in a formation and the coach's arrows. The home screen's moves its
## magnets slowly between a 2-1-2 defence and an attacking shape, as a coach talks a team through it.

var home := Game.C_BLUE
var away := Game.C_RED
var animate := true
var formation := "212"
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if animate:
		_t += delta
		queue_redraw()


## Floor metres to this control's pixels: the rink fills its width (or height) keeping 2:1.
func _to(p: Vector2) -> Vector2:
	var k := minf(size.x / 42.0, size.y / 22.0)
	var o := size * 0.5
	return o + p * k


func _k() -> float:
	return minf(size.x / 42.0, size.y / 22.0)


func _draw() -> void:
	var ink := Color(Game.C_INK, 0.85)
	var k := _k()
	# The boards: a rounded rectangle.
	var pts := PackedVector2Array()
	for p in Arena.outline(0.0, 6):
		pts.append(_to(p))
	pts.append(pts[0])
	Backdrop.stroke(self, pts, ink, 3.5)
	# Centre line and spot.
	Backdrop.stroke(self, PackedVector2Array([_to(Vector2(0, -10)), _to(Vector2(0, 10))]), Color(ink, 0.6), 2.0)
	draw_circle(_to(Vector2.ZERO), 3.0, ink)
	for end: int in [-1, 1]:
		var c0 := _to(Vector2(Rules.CREASE_FRONT * end, -Rules.CREASE_HALF_W))
		var c1 := _to(Vector2(Rules.CREASE_BACK * end, Rules.CREASE_HALF_W))
		draw_rect(Rect2(c0, c1 - c0).abs(), Color(ink, 0.7), false, 2.0)
		var g0 := _to(Vector2(Rules.GOAL_LINE * end, -Rules.GOAL_W * 0.5))
		var g1 := _to(Vector2((Rules.GOAL_LINE + Rules.GOAL_D) * end, Rules.GOAL_W * 0.5))
		draw_rect(Rect2(g0, g1 - g0).abs(), Game.C_RED, false, 2.5)
	for d in Rules.faceoff_dots().slice(1):
		var p := _to(d)
		draw_line(p - Vector2(4, 0), p + Vector2(4, 0), ink, 2.0)
		draw_line(p - Vector2(0, 4), p + Vector2(0, 4), ink, 2.0)
	# The magnets: our five and keeper attacking right, their five in a 2-1-2 in front of their goal.
	var w := 0.5 + 0.5 * sin(_t * 0.6)
	var ours := [Vector2(-15.8, 0), Vector2(lerpf(2.0, 9.0, w), 0.5), Vector2(lerpf(-2.0, 11.0, w), -6.0), Vector2(lerpf(-2.0, 11.0, w), 6.0),
		Vector2(lerpf(-9.0, 1.0, w), -3.8), Vector2(lerpf(-9.0, 1.0, w), 3.8)]
	var theirs := [Vector2(15.8, 0), Vector2(lerpf(7.0, 9.5, w), 0.0), Vector2(lerpf(4.0, 8.0, w), -4.2), Vector2(lerpf(4.0, 8.0, w), 4.2),
		Vector2(12.0, -2.2), Vector2(12.0, 2.2)]
	var r := clampf(k * 0.85, 7.0, 15.0)
	var font := Game.font_bold
	var fs := int(r * 1.0)
	for i in 6:
		Backdrop.magnet(self, _to(theirs[i]), r, away if i > 0 else away.darkened(0.4), "G" if i == 0 else "", font, fs)
	var labels := ["G", "C", "F", "F", "D", "D"]
	for i in 6:
		Backdrop.magnet(self, _to(ours[i]), r, home if i > 0 else home.darkened(0.4), labels[i], font, fs)
	# The coach's arrows: the wingers' runs and a pass into the slot.
	var a := _to(ours[2])
	Backdrop.stroke(self, PackedVector2Array([a + Vector2(r, 0), a + Vector2(r * 3.0, r * 0.6), a + Vector2(r * 5.0, r * 2.2)]), Color(Game.C_GREEN, 0.85), 3.0, true)
	var b := _to(ours[3])
	Backdrop.stroke(self, PackedVector2Array([b + Vector2(r, 0), b + Vector2(r * 3.0, -r * 0.6), b + Vector2(r * 5.0, -r * 2.2)]), Color(Game.C_GREEN, 0.85), 3.0, true)
	var c := _to(ours[1])
	var dash_from := _to(ours[4])
	var steps := 7
	for i in steps:
		if i % 2 == 0:
			draw_line(dash_from.lerp(c, float(i) / steps), dash_from.lerp(c, float(i + 1) / steps), Color(Game.C_INK, 0.6), 2.0, true)
