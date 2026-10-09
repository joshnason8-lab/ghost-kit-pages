class_name Crest
extends Control
## A team's crest: a shield in the franchise colours with its short name, or a country's
## flag in a rounded frame.

var team_id := ""


static func make(id: String, px := 64.0) -> Crest:
	var c := Crest.new()
	c.team_id = id
	c.custom_minimum_size = Vector2(px, px * 1.12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var t := DB.team(team_id)
	if t.is_empty():
		return
	var w := size.x
	var h := size.y
	if t.kind == "country":
		var fh := w * 0.66
		var r := Rect2(0, (h - fh) * 0.5, w, fh)
		draw_texture_rect(Flags.texture(team_id, int(w * 2), int(fh * 2)), r, false)
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.5)
		return
	var c1: Color = t.c1
	var c2: Color = t.c2
	var shield := PackedVector2Array([
		Vector2(w * 0.08, h * 0.06), Vector2(w * 0.92, h * 0.06), Vector2(w * 0.92, h * 0.52),
		Vector2(w * 0.78, h * 0.76), Vector2(w * 0.5, h * 0.96), Vector2(w * 0.22, h * 0.76), Vector2(w * 0.08, h * 0.52)])
	draw_colored_polygon(shield, c1)
	# A sash in the second colour.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.08, h * 0.36), Vector2(w * 0.92, h * 0.16),
		Vector2(w * 0.92, h * 0.3), Vector2(w * 0.08, h * 0.5)]), Color(c2, 0.85))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, c2.lightened(0.2), maxf(1.5, w * 0.04), true)
	var f: Font = Game.font_display
	var fs := int(h * 0.36)
	var tw := f.get_string_size(team_id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color.WHITE if c1.get_luminance() < 0.6 else Color("101820")
	draw_string_outline(f, Vector2((w - tw) * 0.5, h * 0.74), team_id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.18), Color(0, 0, 0, 0.45))
	draw_string(f, Vector2((w - tw) * 0.5, h * 0.74), team_id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
