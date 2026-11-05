class_name Crest
extends Control
## A club's crest where a national team shows its flag (UI.badge): a shield in the club's jersey colour, edged and
## banded in its second colour, with the club's three-letter code across it. Drawn, not text in a label: it is a
## picture the size of a flag, as a flag is.

var id := ""


static func make(club: String, size := Vector2(30, 20)) -> Crest:
	var c := Crest.new()
	c.id = club
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The shield's outline in a box of w x h: a flat top, straight sides to a little past half way, then curving in to
## the point.
static func outline(w: float, h: float, at := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(at + Vector2(0, 0))
	pts.append(at + Vector2(w, 0))
	pts.append(at + Vector2(w, h * 0.5))
	for i in range(1, 9):
		var t := i / 8.0
		# A quadratic curve from the right side's foot to the point, through the bottom right corner.
		var p := (1.0 - t) * (1.0 - t) * Vector2(w, h * 0.5) + 2.0 * (1.0 - t) * t * Vector2(w, h * 0.86) + t * t * Vector2(w * 0.5, h)
		pts.append(at + p)
	for i in range(1, 8):
		var t := i / 8.0
		var p := (1.0 - t) * (1.0 - t) * Vector2(w * 0.5, h) + 2.0 * (1.0 - t) * t * Vector2(0, h * 0.86) + t * t * Vector2(0, h * 0.5)
		pts.append(at + p)
	pts.append(at + Vector2(0, h * 0.5))
	return pts


func _draw() -> void:
	var t := DB.team(id)
	if t.is_empty():
		return
	var fill: Color = t.home[0]
	var second: Color = t.home[1] if not DB._alike(t.home[1], fill) else t.trim
	if DB._alike(second, fill):
		second = fill.darkened(0.45) if fill.get_luminance() > 0.5 else fill.lightened(0.55)
	var h := size.y
	var w := minf(size.x, h * 0.92)
	var at := Vector2((size.x - w) * 0.5, 0)
	var shape := outline(w, h, at)
	draw_colored_polygon(shape, fill)
	# A band across the shield's top in the second colour.
	var band := PackedVector2Array([at + Vector2(0, 0), at + Vector2(w, 0), at + Vector2(w, h * 0.2), at + Vector2(0, h * 0.2)])
	draw_colored_polygon(band, second)
	var edge := shape.duplicate()
	edge.append(shape[0])
	draw_polyline(edge, second if fill.get_luminance() > 0.85 else fill.darkened(0.35), maxf(1.0, h * 0.07), true)
	# The code, in the scoreboard's letters.
	var font: Font = Game.font_score
	if font == null:
		return
	var fs := maxi(6, int(h * 0.44))
	var sw := font.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while sw > w * 0.86 and fs > 6:
		fs -= 1
		sw = font.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color("1f2933") if fill.get_luminance() > 0.6 else Color.WHITE
	var base := h * 0.36 + font.get_ascent(fs) * 0.5
	draw_string(font, Vector2(at.x + (w - sw) * 0.5, base), id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
