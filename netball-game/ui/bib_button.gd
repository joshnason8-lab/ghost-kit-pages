class_name BibButton
extends Button
## A netball bib on the home screen's rail: the tabard's shape, its position's letters big on it, lit lime when it is
## the one you play. "TEAM" is the bib-less choice: you play whoever has the ball.

var code := ""
var letters := ""
var on := false


static func make(p_code: String, p_letters: String, p_on: bool, cb: Callable) -> BibButton:
	var b := BibButton.new()
	b.code = p_code
	b.letters = p_letters
	b.on = p_on
	b.custom_minimum_size = Vector2(66 if p_code != "TEAM" else 104, 76)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(cb)
	b.tooltip_text = p_letters
	return b


func _ready() -> void:
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(k, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var w := minf(s.x - 6.0, s.y * 0.9) if code != "TEAM" else s.x - 6.0
	var x0 := (s.x - w) * 0.5
	var top := 6.0
	var h := s.y - 10.0
	var fill := Game.C_ACCENT if on else Color(Game.C_PANEL_HI, 0.92)
	if is_hovered() and not on:
		fill = fill.lightened(0.12)
	var ink := Game.C_ON_ACCENT if on else Game.C_INK
	# The tabard: shoulders with a scooped neck, straight down, a rounded hem.
	var neck := w * 0.22
	var pts := PackedVector2Array([
		Vector2(x0 + w * 0.12, top), Vector2(x0 + w * 0.5 - neck, top), Vector2(x0 + w * 0.5, top + h * 0.16),
		Vector2(x0 + w * 0.5 + neck, top), Vector2(x0 + w * 0.88, top), Vector2(x0 + w, top + h * 0.2),
		Vector2(x0 + w, top + h * 0.9), Vector2(x0 + w * 0.9, top + h), Vector2(x0 + w * 0.1, top + h),
		Vector2(x0, top + h * 0.9), Vector2(x0, top + h * 0.2)])
	if code == "TEAM":
		pts = PackedVector2Array([Vector2(x0, top + 8), Vector2(x0 + 8, top), Vector2(x0 + w - 8, top), Vector2(x0 + w, top + 8),
			Vector2(x0 + w, top + h - 8), Vector2(x0 + w - 8, top + h), Vector2(x0 + 8, top + h), Vector2(x0, top + h - 8)])
	draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1, 1, 1, 0.25) if not on else Game.C_ACCENT.lightened(0.3), 2.0, true)
	# The letters, as big as fit.
	var font: Font = Game.font_display
	var fs := 34 if code != "TEAM" else 24
	var room := w * 0.8
	while fs > 12 and font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	var tw := font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	draw_string(font, Vector2(x0 + (w - tw) * 0.5, top + h * 0.6 + asc * 0.32), letters, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## For the fit audit: the letters' width at the size drawn, and the room.
func label_fit() -> Dictionary:
	var w := size.x - 6.0
	return {"text": letters, "room": w * 0.8}
