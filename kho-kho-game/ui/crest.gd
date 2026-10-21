class_name Crest
extends Control
## A team's crest: a country's flag in a rounded frame, or, for a state side, a shield in its colours with its
## three letters (no real association's badge).

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
	var w := size.x
	var h := size.y
	if not DB.is_state(team_id):
		var fh := w * 0.66
		var r := Rect2(0, (h - fh) * 0.5, w, fh)
		draw_texture_rect(Flags.texture(team_id, int(w * 2), int(fh * 2)), r, false)
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.5)
		return
	var k := DB.kit(team_id)
	var c1: Color = k[0]
	var c2: Color = k[1]
	var shield := PackedVector2Array([
		Vector2(w * 0.08, h * 0.06), Vector2(w * 0.92, h * 0.06), Vector2(w * 0.92, h * 0.52),
		Vector2(w * 0.78, h * 0.76), Vector2(w * 0.5, h * 0.96), Vector2(w * 0.22, h * 0.76), Vector2(w * 0.08, h * 0.52)])
	draw_colored_polygon(shield, c1)
	# Two poles and the lane between them, in the second colour.
	draw_rect(Rect2(w * 0.18, h * 0.18, w * 0.64, h * 0.07), Color(c2, 0.9))
	draw_rect(Rect2(w * 0.18, h * 0.12, w * 0.06, h * 0.2), Color(c2, 0.9))
	draw_rect(Rect2(w * 0.76, h * 0.12, w * 0.06, h * 0.2), Color(c2, 0.9))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, c2.lightened(0.2), maxf(1.5, w * 0.04), true)
	var f: Font = Game.font_display
	var fs := int(h * 0.32)
	var code := team_id
	var tw := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color.WHITE if c1.get_luminance() < 0.6 else Color("101820")
	draw_string_outline(f, Vector2((w - tw) * 0.5, h * 0.7), code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.18), Color(0, 0, 0, 0.45))
	draw_string(f, Vector2((w - tw) * 0.5, h * 0.7), code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
