class_name CourtThird
extends Button
## One third of the court on the home screen: the court's blue, its white lines (the side lines, the transverse
## line, the goal circle at an end third, the centre circle in the middle one, which pulses: the centre pass, Play),
## a title and a line of description, sized to fit in every language.

var kind := "centre"     # centre, goal_left, goal_right; goal_left_top and _bottom (the left third, halved)
var _t := 0.0


static func make(title: String, desc: String, p_kind: String, cb: Callable) -> CourtThird:
	var b := CourtThird.new()
	b.kind = p_kind
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.15 if p_kind == "centre" else 1.0
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_END if p_kind == "centre" else BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var half := p_kind.begins_with("goal_left_")
	if half:
		v.offset_top = 10
		v.offset_bottom = -10
	var t := UI.label(title, "HeaderLabel", 46 if p_kind == "centre" else (34 if half else 40))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if p_kind == "centre" else HORIZONTAL_ALIGNMENT_LEFT
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_constant_override("line_spacing", -8)
	UI.shrink(t, 46 if p_kind == "centre" else (34 if half else 40), 0.62, 2)
	v.add_child(t)
	var d := UI.label(desc, "", 16 if half else 17, Color(Game.C_INK, 0.85))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = t.horizontal_alignment
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(d, 3)
	v.add_child(d)
	if p_kind == "centre":
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 8)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
	return b


func _ready() -> void:
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		add_theme_stylebox_override(k, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	if kind == "centre":
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s := size
	var court := Color(Game.C_COURT, 0.8 if not is_hovered() else 0.92)
	if button_pressed or is_hovered():
		court = court.lightened(0.08)
	draw_rect(Rect2(Vector2.ZERO, s), court, true)
	var line := Color(1, 1, 1, 0.85)
	var lw := 3.0
	# Where the left third's two halves meet, a white line like the court's own: each half draws it whole along its
	# edge, and the halves overlap (MainMenu), so no dark seam shows between them.
	draw_line(Vector2(0, lw * 0.5), Vector2(s.x, lw * 0.5), line, lw)
	draw_line(Vector2(0, s.y - lw * 0.5), Vector2(s.x, s.y - lw * 0.5), line, lw)
	match kind:
		"centre":
			# The transverse lines either side, and the centre circle, pulsing.
			draw_line(Vector2(lw * 0.5, 0), Vector2(lw * 0.5, s.y), line, lw)
			draw_line(Vector2(s.x - lw * 0.5, 0), Vector2(s.x - lw * 0.5, s.y), line, lw)
			var c := Vector2(s.x * 0.5, s.y * 0.36)
			var r := minf(s.x, s.y) * 0.17
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			draw_circle(c, r + 10.0 + 6.0 * pulse, Color(Game.C_ACCENT, 0.18 * (1.0 - pulse) + 0.06))
			draw_circle(c, r, Game.C_ACCENT)
			draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.9), lw, true)
			# The play mark, in the circle.
			var k := r * 0.42
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.7, -k), c + Vector2(k, 0), c + Vector2(-k * 0.7, k)]), Game.C_ON_ACCENT)
		"goal_left":
			draw_line(Vector2(lw * 0.5, 0), Vector2(lw * 0.5, s.y), line, lw)
			_goal_circle(Vector2(0, s.y * 0.5), s, line, lw, -1.0)
		"goal_left_top", "goal_left_bottom":
			draw_line(Vector2(lw * 0.5, 0), Vector2(lw * 0.5, s.y), line, lw)
			# The goal circle of the whole third, centred where the halves meet.
			var cy := s.y if kind == "goal_left_top" else 0.0
			var faint := Color(line, line.a * 0.32)
			var r := s.y * 0.84
			draw_arc(Vector2(0, cy), r, -PI * 0.5, PI * 0.5, 48, faint, lw, true)
		"goal_right":
			draw_line(Vector2(s.x - lw * 0.5, 0), Vector2(s.x - lw * 0.5, s.y), line, lw)
			_goal_circle(Vector2(s.x, s.y * 0.5), s, line, lw, 1.0)


func _goal_circle(c: Vector2, s: Vector2, col: Color, lw: float, side: float) -> void:
	var r := s.y * 0.42
	var a0 := PI * 0.5 if side > 0.0 else -PI * 0.5
	# Faint: the title and the words run across it (playtest: a full-strength line cut through them).
	var faint := Color(col, col.a * 0.32)
	draw_arc(c, r, a0, a0 + PI, 40, faint, lw, true)
	draw_circle(c + Vector2(-side * 6.0, 0), 5.0, faint)
