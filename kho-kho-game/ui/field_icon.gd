class_name FieldIcon
extends Control
## A rule book's field, drawn small to its proportions: the lane, the squares (eight or six), the poles and the free
## zones, with the seated chasers as dots facing their sides.

var fmt := KhoRules.CLASSIC


static func make(p_fmt: int, px := 96.0) -> FieldIcon:
	var f := FieldIcon.new()
	f.fmt = p_fmt
	f.custom_minimum_size = Vector2(px, px * 0.62)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var f := KhoRules.field(fmt)
	var k := minf(size.x / 27.0, size.y / 16.0)
	var o := size * 0.5
	var L: float = f.length * 0.5 * k
	var W: float = f.width * 0.5 * k
	var r := Rect2(o.x - L, o.y - W, L * 2.0, W * 2.0)
	draw_rect(r, Game.C_CLAY if fmt == KhoRules.CLASSIC else Color("2f86c9"))
	var chalk := Color(Game.C_CHALK, 0.9)
	draw_rect(r, chalk, false, 1.5)
	var pg: float = f.pole_gap * 0.5 * k
	for s in [-1.0, 1.0]:
		draw_line(Vector2(o.x + s * pg, o.y - W), Vector2(o.x + s * pg, o.y + W), Color(chalk, 0.6), 1.0)
		draw_circle(Vector2(o.x + s * pg, o.y), 2.5, Color("d8b07a"))
	draw_line(Vector2(o.x - pg, o.y), Vector2(o.x + pg, o.y), chalk, 1.5)
	for i in int(f.squares):
		var x: float = o.x + float(f.square_x[i]) * k
		draw_line(Vector2(x, o.y - W), Vector2(x, o.y + W), Color(chalk, 0.35), 1.0)
		draw_circle(Vector2(x, o.y + 2.5 * KhoRules.square_face(i)), 2.2, Game.C_SAFFRON)
