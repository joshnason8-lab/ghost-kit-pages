class_name MatchHud
extends CanvasLayer
## What is on the screen in a match: the scoreboard (sets, points, who serves, set and match point), the referee's
## calls, the big call-outs (ROLL SPIKE!, BLOCKED!, ACE!), the timing ring that closes on the ball when a touch is
## yours, the video challenge and its review, the replay, the set break and the pause menu.

var m: Node   # the match
var root: Control
var _score_l: Array = []      # per screen side: {panel, name, pts, sets (HBox), serve}
var _mid_set: Label
var _mid_tag: Label
var _call: Label
var _banner: Label
var _banner_t := 0.0
var _ring: Control
var _ring_plan := {}
var _ring_result := ""
var _ring_result_t := 0.0
var _challenge: Button
var _review: Control
var _review_data := {}
var _review_t := 0.0
var _replay_tag: Control
var _pause: Control
var _break: Control
var _intro: Control
var _intro_t := 0.0


func setup(p_match: Node) -> void:
	m = p_match
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	add_child(root)
	_build_scoreboard()
	_call = UI.label("", "SubLabel", 22, Game.C_GOLD)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_call.offset_top = 128
	_call.offset_left = -400
	_call.offset_right = 400
	_call.add_theme_constant_override("outline_size", 8)
	_call.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.09, 0.85))
	root.add_child(_call)
	_banner = UI.label("", "TitleLabel", 96, Game.C_SAFFRON)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -560
	_banner.offset_right = 560
	_banner.offset_top = -150
	_banner.offset_bottom = -40
	_banner.add_theme_constant_override("outline_size", 22)
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.09, 0.95))
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.shrink(_banner, 96, 0.5, 1)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	root.add_child(_ring)
	# Top right: the challenge (when there is a call to challenge), the camera and pause.
	var tr_box := HBoxContainer.new()
	tr_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(root, 26.0)
	tr_box.offset_right = -sm.z
	tr_box.offset_top = 22
	tr_box.offset_left = -560
	tr_box.alignment = BoxContainer.ALIGNMENT_END
	tr_box.add_theme_constant_override("separation", 12)
	root.add_child(tr_box)
	_challenge = UI.button(tr("BTN_CHALLENGE"), true, func(): m.challenge_by_user())
	_challenge.visible = false
	_challenge.custom_minimum_size = Vector2(0, 62)
	tr_box.add_child(_challenge)
	tr_box.add_child(UI.round_button("camera", func(): m.cam.toggle(), 62))
	tr_box.add_child(UI.round_button("pause", func(): m.set_paused(not m.paused), 62))
	_replay_tag = _make_replay_tag()
	root.add_child(_replay_tag)


func _build_scoreboard() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 16
	bar.offset_left = -380
	bar.offset_right = 380
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for side in 2:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.07, 0.12, 0.9)
		sb.set_corner_radius_all(14)
		sb.border_color = Color(1, 1, 1, 0.1)
		sb.set_border_width_all(1)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
		panel.custom_minimum_size = Vector2(250, 104)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		panel.add_child(h)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		var crest := Crest.make("", 30)
		name_row.add_child(crest)
		var nm := UI.label("", "HeaderLabel", 40)
		name_row.add_child(nm)
		col.add_child(name_row)
		var sets_row := HBoxContainer.new()
		sets_row.add_theme_constant_override("separation", 6)
		col.add_child(sets_row)
		var pts := UI.label("0", "ScoreLabel", 0)
		pts.add_theme_font_size_override("font_size", 78)
		pts.custom_minimum_size = Vector2(70, 0)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var serve := Icon.make("ball", 22, Game.C_GOLD)
		serve.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if side == 0:
			h.add_child(col)
			h.add_child(serve)
			h.add_child(pts)
		else:
			h.add_child(pts)
			h.add_child(serve)
			h.add_child(col)
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			name_row.alignment = BoxContainer.ALIGNMENT_END
			sets_row.alignment = BoxContainer.ALIGNMENT_END
		_score_l.append({"panel": panel, "sb": sb, "name": nm, "crest": crest, "pts": pts, "sets": sets_row, "serve": serve})
		bar.add_child(panel)
		if side == 0:
			var mid := PanelContainer.new()
			var msb: StyleBoxFlat = sb.duplicate()
			mid.add_theme_stylebox_override("panel", msb)
			mid.custom_minimum_size = Vector2(150, 104)
			var mv := VBoxContainer.new()
			mv.alignment = BoxContainer.ALIGNMENT_CENTER
			mv.add_theme_constant_override("separation", 0)
			mid.add_child(mv)
			_mid_set = UI.label("", "EyebrowLabel", 17)
			_mid_set.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI.shrink(_mid_set, 17, 0.7)
			mv.add_child(_mid_set)
			_mid_tag = UI.label("", "HeaderLabel", 30, Game.C_SAFFRON)
			_mid_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI.shrink(_mid_tag, 30, 0.6)
			mv.add_child(_mid_tag)
			bar.add_child(mid)


## The scoreboard as the broadcast camera shows the court: side 1 (x > 0) on the left of the screen.
func set_score() -> void:
	for panel_i in 2:
		var side := 1 - panel_i
		var team: int = m.side_team[side]
		var t: Dictionary = m.teams[team]
		var s: Dictionary = _score_l[panel_i]
		(s.name as Label).text = String(t.short)
		var cr: Crest = s.crest
		cr.team_id = String(t.id)
		cr.queue_redraw()
		(s.pts as Label).text = str(int(m.points[team]))
		(s.sb as StyleBoxFlat).border_color = Color(t.c1, 0.9)
		(s.sb as StyleBoxFlat).border_width_left = 7 if panel_i == 0 else 1
		(s.sb as StyleBoxFlat).border_width_right = 7 if panel_i == 1 else 1
		var sets_row: HBoxContainer = s.sets
		for c in sets_row.get_children():
			c.queue_free()
		for i in int(m.sets_to_win):
			var dot := Icon.make("dot" if i < int(m.sets[team]) else "ring", 16, t.c1.lightened(0.2))
			sets_row.add_child(dot)
		(s.serve as Control).modulate.a = 1.0 if int(m.server) == team else 0.0
	_mid_set.text = tr("SET_N_TO").format({"n": m.set_no, "p": m.set_points})
	var mp: int = m.match_point_for()
	var sp: int = m.set_point_for()
	_mid_tag.text = tr("MATCH_POINT") if mp >= 0 else (tr("SET_POINT") if sp >= 0 else "")
	UI.refit(_mid_tag)


func call_line(text: String) -> void:
	_call.text = text
	_call.modulate.a = 1.0


func banner(text: String, col: Color = Game.C_SAFFRON) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col.lightened(0.15) if col.get_luminance() < 0.45 else col)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.25, 1.25)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_t = 1.6
	UI.refit(_banner)


func intro(text: String) -> void:
	_intro = PanelContainer.new()
	_intro.theme_type_variation = "GlassPanel"
	_intro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_intro.offset_left = -420
	_intro.offset_right = 420
	_intro.offset_top = 40
	_intro.offset_bottom = 230
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	_intro.add_child(v)
	var ey := UI.label(text.to_upper(), "EyebrowLabel", 18, Game.C_SAFFRON)
	ey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ey.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ey)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for k in 2:
		var t: Dictionary = m.teams[k]
		if k == 1:
			row.add_child(UI.label(tr("VS"), "HeaderLabel", 34, Game.C_MUTED))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var cr := Crest.make(String(t.id), 56)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(cr)
		var nm := UI.fit(UI.label(DB.team_name(String(t.id)), "SubLabel", 24), 2)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(300, 0)
		col.add_child(nm)
		row.add_child(col)
	v.add_child(row)
	root.add_child(_intro)
	_intro_t = 2.4
	set_score()


func set_break() -> void:
	_break = PanelContainer.new()
	_break.theme_type_variation = "GlassPanel"
	_break.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_break.offset_left = -360
	_break.offset_right = 360
	_break.offset_top = -40
	_break.offset_bottom = 160
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_break.add_child(v)
	var t := UI.label(tr("SET_BREAK").to_upper(), "EyebrowLabel", 18, Game.C_SAFFRON)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 1 + (m.set_scores as Array).size()
	g.add_theme_constant_override("h_separation", 26)
	for k in 2:
		var nm := UI.fit(UI.label(DB.team_name(String(m.teams[k].id)), "SubLabel", 24))
		nm.custom_minimum_size = Vector2(300, 0)
		g.add_child(nm)
		for sc in m.set_scores:
			var won: bool = int(sc[k]) > int(sc[1 - k])
			g.add_child(UI.label(str(int(sc[k])), "HeaderLabel", 36, Game.C_INK if won else Game.C_MUTED))
	v.add_child(g)
	var ce := UI.label(tr("CHANGE_ENDS"), "MutedLabel", 18)
	ce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ce)
	root.add_child(_break)
	set_score()


func tick(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.scale = _banner.scale.lerp(Vector2.ONE, minf(1.0, 10.0 * delta))
		_banner.pivot_offset = _banner.size * 0.5
		if _banner_t < 0.4:
			_banner.modulate.a = maxf(0.0, _banner_t / 0.4)
	if _intro and is_instance_valid(_intro):
		_intro_t -= delta
		if _intro_t < 0.3:
			_intro.modulate.a = maxf(0.0, _intro_t / 0.3)
		if _intro_t <= 0.0:
			_intro.queue_free()
			_intro = null
	if _break and is_instance_valid(_break) and int(m.state) != 4:
		_break.queue_free()
		_break = null
	if _ring_result_t > 0.0:
		_ring_result_t -= delta
	_ring.queue_redraw()
	if not _review_data.is_empty():
		_review_t += delta
		_review.queue_redraw()


# ---------------------------------------------------------------- a cut

var _cut: ColorRect


## A broadcast cut: the picture fades to black and back, and what jumps (the teams changing ends) does it in the dark.
func cut(in_dark: Callable) -> void:
	if _cut == null:
		_cut = ColorRect.new()
		_cut.color = Color(0.02, 0.04, 0.07)
		_cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_cut)
		root.move_child(_cut, 0)   # under the scoreboard and the banners
	_cut.modulate.a = 0.0
	var tw := _cut.create_tween()
	tw.tween_property(_cut, "modulate:a", 1.0, 0.25)
	tw.tween_callback(in_dark)
	tw.tween_interval(0.15)
	tw.tween_property(_cut, "modulate:a", 0.0, 0.35)


# ---------------------------------------------------------------- the timing ring

func timing_open(p: Dictionary) -> void:
	_ring_plan = p


func timing_done() -> void:
	_ring_plan = {}


func timing_result(label: String) -> void:
	_ring_result = label
	_ring_result_t = 0.8


func _draw_ring() -> void:
	var cam: Camera3D = m.cam
	if not _ring_plan.is_empty() and cam:
		_draw_spot(cam)
		var pos: Vector3 = _ring_plan.pos
		if not cam.is_position_behind(pos):
			var sp := cam.unproject_position(pos)
			var left := float(_ring_plan.t) - float(m.now)
			var k := clampf(left / 1.1, 0.0, 1.0)
			var r := 26.0 + 74.0 * k
			var w: Array = m.timing_windows()
			var good := left <= float(w[1])
			_ring.draw_arc(sp, 26.0, 0, TAU, 40, Color(Game.C_GOLD, 0.85), 3.0, true)
			_ring.draw_arc(sp, r, 0, TAU, 48, Game.C_GOOD if good else Color(Game.C_INK, 0.8), 4.0, true)
	if _ring_result_t > 0.0:
		var key := "TIMING_" + _ring_result
		var col: Color = {"PERFECT": Game.C_GOLD, "GOOD": Game.C_GOOD, "EARLY": Game.C_MUTED, "LATE": Game.C_MUTED, "MISS": Game.C_DANGER}.get(_ring_result, Game.C_INK)
		var f: Font = Game.font_display
		var fs := Game.ts(48)
		var txt := tr(key)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# Under the referee's calls, clear of the play (the players are in the lower half of the picture).
		var at := Vector2(_ring.size.x * 0.5 - tw * 0.5, 172.0 + float(fs))
		_ring.draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.02, 0.05, 0.09, minf(1.0, _ring_result_t * 2.0)))
		_ring.draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, minf(1.0, _ring_result_t * 2.0)))


## Where your player must stand to play it: a ring on the floor, gold, green once he is near enough; a line to it from
## his feet while he is not.
func _draw_spot(cam: Camera3D) -> void:
	if not _ring_plan.has("player") or not _ring_plan.has("stand") or String(_ring_plan.get("kind", "")) == "serve":
		return
	var st: Vector3 = _ring_plan.stand
	if st == Vector3.INF or cam.is_position_behind(st):
		return
	var near: bool = m._off_spot(_ring_plan) <= m._reach(_ring_plan)
	var col := Game.C_GOOD if near else Game.C_GOLD
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(cam.unproject_position(st + Vector3(cos(a) * 0.42, 0.02, sin(a) * 0.42)))
	_ring.draw_polyline(pts, Color(0.02, 0.05, 0.09, 0.6), 7.0, true)
	_ring.draw_polyline(pts, col, 4.0, true)
	if not near:
		var pl: Node3D = _ring_plan.player
		var a2 := cam.unproject_position(Vector3(pl.position.x, 0.02, pl.position.z))
		var b2 := cam.unproject_position(st + Vector3(0, 0.02, 0))
		var n := int(a2.distance_to(b2) / 18.0)
		for i in n:
			if i % 2 == 0:
				_ring.draw_line(a2.lerp(b2, float(i) / n), a2.lerp(b2, float(i + 1) / n), Color(col, 0.75), 3.0, true)


# ---------------------------------------------------------------- challenge and review

func challenge_prompt(on: bool) -> void:
	if on:
		_challenge.text = tr("BTN_CHALLENGE_N").format({"n": int(m.challenges[m.user_team])})
	_challenge.visible = on


## The review: the ball's mark on the floor beside the line, magnified, then the verdict.
func show_review(c: Dictionary, team: int) -> void:
	_review_data = c.merged({"team": team}, true)
	_review_t = 0.0
	_review = PanelContainer.new()
	_review.theme_type_variation = "GlassPanel"
	_review.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_review.offset_left = -330
	_review.offset_right = 330
	_review.offset_top = -170
	_review.offset_bottom = 190
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_review.add_child(v)
	var t := UI.label(tr("REVIEW_TITLE").to_upper(), "EyebrowLabel", 18, Game.C_SAFFRON)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var who := UI.label(tr("REVIEW_BY").format({"t": DB.team_name(String(m.teams[team].id))}), "MutedLabel", 18)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(600, 220)
	canvas.draw.connect(_draw_review.bind(canvas))
	v.add_child(canvas)
	_review.draw.connect(func(): canvas.queue_redraw())
	root.add_child(_review)


func _draw_review(c: Control) -> void:
	var d := _review_data
	if d.is_empty():
		return
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color("2b6cc4"))
	# The line: 4 cm, drawn 600 px for 30 cm (the view is 30 cm across).
	var px := s.x / 0.3
	var p: Vector3 = d.p
	var margin := Court.line_margin(p, 0.0)   # the ball's centre from the line's outer edge
	var line_x := s.x * 0.5
	c.draw_rect(Rect2(line_x - Court.LINE * px, 0, Court.LINE * px, s.y), Color("f6f4ee"))
	c.draw_string(Game.font_bold, Vector2(8, 24), tr("REVIEW_IN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	c.draw_string(Game.font_bold, Vector2(s.x - 70, 24), tr("REVIEW_OUT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	# The ball's contact patch slides in over the first second.
	var k := clampf(_review_t / 1.0, 0.0, 1.0)
	var bx := line_x + margin * px
	var r := 0.02 * px   # the patch of the ball that touches the floor, about 4 cm across
	c.draw_circle(Vector2(lerpf(-40.0, bx, k), s.y * 0.5), r, Color("f2c14e"))
	c.draw_arc(Vector2(lerpf(-40.0, bx, k), s.y * 0.5), Ball.RADIUS * px, 0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
	if _review_t > 1.6:
		var inside: bool = bool(d.true_in)
		var txt := tr("REVIEW_IN" if inside else "REVIEW_OUT")
		var dist := absf(margin + Ball.RADIUS) * 1000.0
		var sub := tr("REVIEW_MM").format({"n": int(dist)})
		var f: Font = Game.font_display
		var fs := 64
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string_outline(f, Vector2((s.x - tw) * 0.5, s.y * 0.8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.7))
		c.draw_string(f, Vector2((s.x - tw) * 0.5, s.y * 0.8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Game.C_GOOD if inside else Game.C_DANGER)
		var sw := Game.font_bold.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_string(Game.font_bold, Vector2((s.x - sw) * 0.5, s.y * 0.95), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func hide_review() -> void:
	_review_data = {}
	if _review:
		_review.queue_free()
		_review = null


# ---------------------------------------------------------------- the replay

func _make_replay_tag() -> Control:
	var b := Button.new()
	b.flat = true
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.pressed.connect(func(): m.end_replay())
	var tag := HBoxContainer.new()
	tag.position = Vector2(UI.safe_margins(root, 30.0).x, 140)
	tag.add_theme_constant_override("separation", 10)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(Icon.make("dot", 22, Game.C_DANGER))
	tag.add_child(UI.label(tr("REPLAY"), "HeaderLabel", 40))
	tag.add_child(UI.label(tr("TAP_TO_SKIP"), "MutedLabel", 18))
	b.add_child(tag)
	b.visible = false
	return b


func replay(on: bool) -> void:
	_replay_tag.visible = on
	m.controls.visible = not on and m.user_team >= 0


# ---------------------------------------------------------------- pause

func show_pause(on: bool) -> void:
	if not on:
		if _pause:
			_pause.queue_free()
			_pause = null
		return
	if _pause:
		return
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	card.add_child(v)
	var t := UI.label(tr("PAUSED"), "HeaderLabel", 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# Big buttons for a thumb, Resume the biggest; Quit apart and in red, so it is not hit by mistake.
	var resume := _big(UI.button(tr("RESUME"), true, func(): m.set_paused(false)), 96, 32)
	v.add_child(resume)
	v.add_child(_big(UI.button(tr("CAMERA") + ": " + tr({Game.CAM_TV: "CAM_TV", Game.CAM_SIDE: "CAM_SIDE"}.get(m.cam.mode, "CAM_END")), false, func():
		m.cam.toggle()
		show_pause(false)
		show_pause(true)), 80, 26))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)
	var quit := _big(UI.button(tr("QUIT_MATCH"), false, func(): m.quit_match()), 80, 26)
	quit.add_theme_color_override("font_color", Game.C_DANGER)
	quit.add_theme_color_override("font_hover_color", Game.C_DANGER.lightened(0.2))
	v.add_child(quit)
	root.add_child(_pause)
	UI.keep_on_screen(card)


func _big(b: Button, h: float, fs: int) -> Button:
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", Game.ts(fs))
	return b
