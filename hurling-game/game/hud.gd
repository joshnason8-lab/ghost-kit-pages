class_name MatchHud
extends CanvasLayer
## What is on the screen in a match, the way hurling is shown on television: the score bug in the top corner (each
## side's colours, goals-points and the total, the clock counting up from 0:00 to the half's 35 minutes, the added
## time when it is shown), the referee's calls, the big moments (POINT, GOAL, WIDE, FREE, 65 ...), the restart
## coming, and the pause menu. The sliotar is small and fast, so it is marked: a bright dot over it, and an arrow at
## the screen's edge when it is out of the picture. Your player has a ring and, with the ball in his hand, his steps.
## The theme is set on this layer's root: a CanvasLayer does not inherit the window's.

var m: Node
var root: Control
var _rows: Array = []        # [{chip, name, score, total}]
var _clock: Label
var _half: Label
var _added: Label
var _call: Label
var _call_t := 0.0
var _banner: Label
var _banner_t := 0.0
var _tag: Label
var _toast: Label
var _toast_t := 0.0
var _marks: Control
var _pause: Control
var _card: Control
var _shoot: Control
var _intro: Control
var _intro_t := 0.0
var _dev: Label
var _active: Player = null
var _coach: Control
var _subs: Control
var _coach_text: Label
var _coach_t := 0.0


func setup(p_match: Node) -> void:
	m = p_match
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	add_child(root)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	root.add_child(_marks)
	_build_scorebug()
	_call = _outlined("", "SubLabel", 24, Game.C_GOLD)
	_call.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_call.offset_top = 96
	_call.offset_left = -420
	_call.offset_right = 420
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_call, 2)
	root.add_child(_call)
	_tag = _outlined("", "EyebrowLabel", 20, Game.C_INK)
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tag.offset_top = 64
	_tag.offset_left = -300
	_tag.offset_right = 300
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_tag, 1)
	root.add_child(_tag)
	_banner = _outlined("", "TitleLabel", 92, Game.C_GOLD)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -560
	_banner.offset_right = 560
	_banner.offset_top = -170
	_banner.offset_bottom = -50
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.shrink(_banner, 92, 0.5, 1)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_toast = _outlined("", "SubLabel", 20, Game.C_INK)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -60
	_toast.offset_bottom = -28
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_toast, 1)
	root.add_child(_toast)
	# Top right: the camera and pause.
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(root, 24.0)
	box.offset_right = -sm.z
	box.offset_top = 18
	box.offset_left = -300
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(UI.round_button("camera", func(): _next_camera(), 60))
	box.add_child(UI.round_button("pause", func(): m.set_paused(not m.paused), 60))
	_build_coach()
	_dev = UI.label("", "MutedLabel", 15, Game.C_GOLD)
	_dev.position = Vector2(sm.x + 6, 150)
	_dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev.visible = bool(Game.settings.get("dev", false))
	root.add_child(_dev)


## The coach's card: low in the middle, between the joystick and the buttons, where the eye is during play.
func _build_coach() -> void:
	_coach = PanelContainer.new()
	_coach.theme_type_variation = "GlassPanel"
	_coach.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_coach.offset_left = -300
	_coach.offset_right = 300
	_coach.offset_top = -196
	_coach.offset_bottom = -76
	_coach.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	_coach.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Icon.make("whistle", 22, Game.C_GOLD))
	var who := UI.label(tr("COACH").to_upper(), "EyebrowLabel", 16, Game.C_GOLD)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	v.add_child(head)
	_coach_text = UI.label("", "SubLabel", 20, Game.C_INK)
	_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_text.custom_minimum_size.x = 560
	_coach_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(_coach_text, 3)
	v.add_child(_coach_text)
	_coach.visible = false
	root.add_child(_coach)


## The coach's card sits between the joystick's side and the nearest button (wherever you have put them, whatever
## their size, either hand), never over a button.
func _place_coach() -> void:
	var vp := root.get_viewport_rect().size
	var c: TouchControls = m.controls
	var lh := bool(Game.settings.get("left_handed", false))
	var edge := vp.x if not lh else 0.0
	for i in 4:
		var p := c.slot_pos(i)
		var r := c.slot_radius(i)
		if p.y + r < vp.y - 200.0:
			continue     # a button moved up out of the card's way
		edge = minf(edge, p.x - r - 16.0) if not lh else maxf(edge, p.x + r + 16.0)
	var thumb := vp.x * 0.23
	var left := thumb if not lh else edge
	var right := edge if not lh else vp.x - thumb
	var w := clampf(right - left, 360.0, 640.0)
	var cx := (left + right) * 0.5
	_coach.anchor_left = 0.0
	_coach.anchor_right = 0.0
	_coach.offset_left = cx - w * 0.5
	_coach.offset_right = cx + w * 0.5
	_coach_text.custom_minimum_size.x = w - 40.0


## Show a coach's tip (game/coach.gd), by its id; "" leaves what is shown.
func coach(id: String) -> void:
	if id == "":
		return
	_coach_text.text = tr(Coach.text_key(id))
	_place_coach()
	UI.refit(_coach_text)
	_coach.visible = true
	_coach.modulate.a = 1.0
	_coach_t = Coach.SHOW_S


func _outlined(text: String, variation: String, size: int, col: Color) -> Label:
	var l := UI.label(text, variation, size, col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.03, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The score bug: two rows, each a colour chip, the county's short name, goals-points and the total; the clock
## beside them.
func _build_scorebug() -> void:
	var sm := UI.safe_margins(root, 24.0)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.05, 0.88)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(sm.x, 16)
	root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rows)
	for k in 2:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(10, 30)
		chip.color = m.teams[k].c1
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(chip)
		var nm := UI.label(DB.short_name(String(m.teams[k].id)), "SubLabel", 22, Game.C_INK)
		nm.custom_minimum_size = Vector2(62, 0)
		r.add_child(nm)
		var sc := UI.label("0-0", "ScoreLabel", 30, Game.C_INK)
		sc.custom_minimum_size = Vector2(70, 0)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(sc)
		var tot := UI.label("(0)", "MutedLabel", 18, Game.C_MUTED)
		tot.custom_minimum_size = Vector2(40, 0)
		r.add_child(tot)
		rows.add_child(r)
		_rows.append({"name": nm, "score": sc, "total": tot})
	var tc := VBoxContainer.new()
	tc.alignment = BoxContainer.ALIGNMENT_CENTER
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tc)
	_clock = UI.label("0:00", "ScoreLabel", 30, Game.C_GOLD)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_clock)
	_half = UI.label("", "EyebrowLabel", 14, Game.C_MUTED)
	_half.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(_half)
	_added = UI.label("", "SubLabel", 20, Color("1a1a1a"))
	var asb := StyleBoxFlat.new()
	asb.bg_color = Game.C_GOLD
	asb.set_corner_radius_all(4)
	asb.content_margin_left = 6
	asb.content_margin_right = 6
	_added.add_theme_stylebox_override("normal", asb)
	_added.visible = false
	tc.add_child(_added)
	for c in [panel, h, rows, tc]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in [_clock, _half, _added]:
		(l as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_score()


func set_score() -> void:
	for k in 2:
		var s: Array = m.score[k]
		_rows[k].score.text = Rules.fmt(int(s[0]), int(s[1]))
		_rows[k].total.text = "(%d)" % Rules.total(int(s[0]), int(s[1]))


func added_time(mins: int) -> void:
	_added.text = "+%d" % mins
	_added.visible = true


func tick(delta: float) -> void:
	var secs := int(m.clock)
	var limit := int(m.half_len_now())
	var shown := mini(secs, limit + int(m.added))
	var base := 0
	if m.half == 2:
		base = int(m.half_len)
	elif m.half >= 3:
		base = int(m.half_len) * 2 + (0 if m.half == 3 else Rules.EXTRA_HALF * 60)
	var t := base + shown
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	_half.text = tr(["HALF_1", "HALF_2", "HALF_ET1", "HALF_ET2"][clampi(int(m.half) - 1, 0, 3)])
	if m.phase == m.P.SHOOTOUT:
		_half.text = tr("SHOOTOUT")
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
		_banner.scale = Vector2.ONE * (1.0 + maxf(0.0, _banner_t - 1.6) * 0.3)
	if _call_t > 0.0:
		_call_t -= delta
		_call.modulate.a = clampf(_call_t / 0.5, 0.0, 1.0)
	if _coach_t > 0.0:
		_coach_t -= delta
		_coach.modulate.a = clampf(_coach_t / 0.5, 0.0, 1.0)
		_coach.visible = _coach_t > 0.0
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	if _intro != null and is_instance_valid(_intro):
		_intro_t -= delta
		_intro.modulate.a = clampf(_intro_t / 0.6, 0.0, 1.0)
		if _intro_t <= 0.0:
			_intro.queue_free()
			_intro = null
	if _dev.visible:
		var pc: Array = m.frame_percentiles()
		var rs := RenderingServer
		_dev.text = "frame ms p50 %.1f  p95 %.1f  max %.1f  hitches %d\ndraws %d  prims %d  gfx %d  fps %d" % [pc[0], pc[1], pc[2], pc[3],
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), int(Game.settings.graphics),
			Engine.get_frames_per_second()]
	_marks.queue_redraw()


func call_line(text: String) -> void:
	_call.text = text
	UI.refit(_call)
	_call_t = 2.6
	_call.modulate.a = 1.0


func banner(text: String, col: Color = Game.C_GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	UI.refit(_banner)
	_banner_t = 2.0
	_banner.pivot_offset = _banner.size * 0.5


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.0


func restart_tag(r: Dictionary) -> void:
	if r.is_empty():
		_tag.text = ""
		return
	var team := DB.short_name(String(m.teams[int(r.team)].id))
	_tag.text = tr("RESTART_" + String(r.kind).to_upper()) + " · " + team


func set_active(pl: Player) -> void:
	_active = pl


func intro(text: String, how := "") -> void:
	_intro = PanelContainer.new()
	_intro.theme_type_variation = "GlassPanel"
	_intro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_intro.offset_left = -360
	_intro.offset_right = 360
	_intro.offset_top = -40
	_intro.offset_bottom = 110
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(v)
	var l := UI.label(DB.team_name(String(m.teams[0].id)) + "  " + tr("VS") + "  " + DB.team_name(String(m.teams[1].id)), "HeaderLabel", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shrink(l, 40, 0.6, 1)
	v.add_child(l)
	var s := UI.label(text, "MutedLabel", 19)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(s, 2)
	v.add_child(s)
	if how != "":
		# Your first match: the game in three lines before the throw-in.
		_intro.offset_top = -60
		_intro.offset_bottom = 170
		var h := UI.label(how, "SubLabel", 20, Game.C_GOLD)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size.x = 640
		UI.fit(h, 3)
		v.add_child(h)
	root.add_child(_intro)
	_intro_t = 6.7 if how != "" else 3.2


func _next_camera() -> void:
	var order := [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]
	var i := order.find(int(Game.settings.camera))
	Game.settings.camera = order[(i + 1) % order.size()]
	Game.save_settings()
	m.cam.mode = int(Game.settings.camera)


## The marks drawn over the 3D picture: the sliotar's dot (or an arrow to it), your player's ring and steps.
func _draw_marks() -> void:
	var cam: Camera3D = m.cam.camera
	var vp := root.get_viewport_rect().size
	var b: Vector3 = m.ball.global_position
	if m.ball.state != Sliotar.HELD or m.carrier == null:
		if not cam.is_position_behind(b):
			var sp := cam.unproject_position(b)
			if Rect2(Vector2.ZERO, vp).grow(-4).has_point(sp):
				_marks.draw_circle(sp, 5.5, Color(0.05, 0.05, 0.05, 0.75))
				_marks.draw_circle(sp, 3.8, Color(1, 1, 0.92))
			else:
				_edge_arrow(sp, vp)
		else:
			_edge_arrow(vp - cam.unproject_position(b), vp)
	if _active != null and is_instance_valid(_active) and _active.visible and m.controls.visible:
		var p := _active.global_position
		if not cam.is_position_behind(p):
			var c := cam.unproject_position(p)
			var top := cam.unproject_position(p + Vector3(0, 2.1, 0))
			var r := maxf(10.0, (c.y - top.y) * 0.32)
			_marks.draw_arc(c, r, 0, TAU, 32, Color(Game.C_GOLD, 0.95), 3.0, true)
			_marks.draw_string(Game.font_bold, top + Vector2(-12, -6), str(_active.num), HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Game.C_GOLD)
			if _active == m.carrier and _active.ball_hand:
				var c2: Rules.Carry = m.carry_of(_active)
				for i in Rules.MAX_STEPS:
					var col := Game.C_DANGER if i < c2.steps and c2.steps >= 3 else (Game.C_GOLD if i < c2.steps else Color(1, 1, 1, 0.35))
					_marks.draw_circle(top + Vector2(-15 + i * 10, -30), 3.6, col)


func _edge_arrow(sp: Vector2, vp: Vector2) -> void:
	var c := vp * 0.5
	var d := (sp - c)
	if d.length() < 1.0:
		return
	d = d.normalized()
	var k := minf((vp.x * 0.5 - 30.0) / maxf(0.001, absf(d.x)), (vp.y * 0.5 - 30.0) / maxf(0.001, absf(d.y)))
	var at := c + d * k
	var n := Vector2(-d.y, d.x)
	_marks.draw_colored_polygon(PackedVector2Array([at + d * 14.0, at - d * 6.0 + n * 9.0, at - d * 6.0 - n * 9.0]), Color(1, 1, 0.92, 0.9))


# ---------------------------------------------------------------- overlays

func show_pause(on: bool) -> void:
	if on and _pause == null:
		_pause = _overlay()
		var v: VBoxContainer = _pause.get_meta("col")
		var t := UI.label(tr("PAUSED"), "HeaderLabel", 44)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var s := UI.label(m.score_text(0) + "  ·  " + m.score_text(1), "SubLabel", 22, Game.C_MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.fit(s, 2)
		v.add_child(s)
		var b1 := UI.button(tr("RESUME"), true, func(): m.set_paused(false))
		b1.custom_minimum_size = Vector2(320, 64)
		v.add_child(b1)
		if m.user_team >= 0:
			var bs := UI.button(tr("SUBS") + "  ·  " + (Plural.word("SUBS_LEFT", m.subs_left(m.user_team)) if m.subs_left(m.user_team) > 0 else tr("SUBS_NONE")), false, func(): open_subs())
			bs.custom_minimum_size = Vector2(320, 56)
			v.add_child(bs)
		if m.user_team >= 0:
			var bt := UI.button(tr("TACTICS"), false, func(): open_tactics())
			bt.custom_minimum_size = Vector2(320, 56)
			v.add_child(bt)
		var b2 := UI.button(tr("QUIT_MATCH"), false, func(): m.quit_match())
		b2.custom_minimum_size = Vector2(320, 56)
		v.add_child(b2)
	elif not on and _pause != null:
		_pause.queue_free()
		_pause = null
		close_subs()


## Your substitutions (ui/subs_panel.gd), over the pause menu.
func open_subs() -> void:
	if _subs != null and is_instance_valid(_subs):
		return
	_subs = SubsPanel.new()
	_subs.m = m
	root.add_child(_subs)


func open_tactics() -> void:
	if _subs != null and is_instance_valid(_subs):
		return
	_subs = TacticsPanel.new()
	_subs.m = m
	root.add_child(_subs)


## Back closes the substitutions (or the tactics) first.
func close_subs() -> bool:
	if _subs != null and is_instance_valid(_subs):
		_subs.close()
		_subs = null
		return true
	return false


func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.04, 0.03, 0.72)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(o)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(c)
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.custom_minimum_size = Vector2(460, 0)
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	o.set_meta("col", v)
	return o


## Half time (and the break before extra time): the score, and the scorers so far.
func half_time(h: int) -> void:
	_card = _overlay()
	var v: VBoxContainer = _card.get_meta("col")
	var t := UI.label(tr("HALF_TIME") if h == 1 else (tr("FULL_TIME_LEVEL") if h == 2 else tr("EXTRA_HALF_TIME")), "HeaderLabel", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shrink(t, 40, 0.6, 1)
	v.add_child(t)
	for k in 2:
		var l := UI.label(DB.team_name(String(m.teams[k].id)) + "   " + m.score_text(k), "SubLabel", 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.fit(l, 2)
		v.add_child(l)
	if h == 2:
		var e := UI.label(tr("EXTRA_TIME_NOTE"), "MutedLabel", 18)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(e)
	_added.visible = false


func end_half_time() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


func full_time(winner: int) -> void:
	end_half_time()
	_card = _overlay()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: VBoxContainer = _card.get_meta("col")
	var t := UI.label(tr("FULL_TIME"), "HeaderLabel", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for k in 2:
		var l := UI.label(DB.team_name(String(m.teams[k].id)) + "   " + m.score_text(k), "SubLabel", 28, Game.C_GOLD if k == winner else Game.C_INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.fit(l, 2)
		v.add_child(l)


func shootout(so: Dictionary) -> void:
	if _shoot == null:
		_shoot = PanelContainer.new()
		_shoot.theme_type_variation = "GlassPanel"
		_shoot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_shoot.offset_top = -150
		_shoot.offset_bottom = -110
		_shoot.offset_left = -260
		_shoot.offset_right = 260
		_shoot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := GridContainer.new()
		g.columns = 2
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shoot.add_child(g)
		_shoot.set_meta("grid", g)
		root.add_child(_shoot)
	var grid: GridContainer = _shoot.get_meta("grid")
	for c in grid.get_children():
		c.queue_free()
	for k in 2:
		var n := UI.label(DB.short_name(String(m.teams[k].id)), "SubLabel", 22)
		n.custom_minimum_size = Vector2(70, 0)
		grid.add_child(n)
		var marks := ""
		for e in so.get("log", []):
			if int(e[0]) == k:
				marks += "• " if bool(e[1]) else "× "
		var l := UI.label(marks + "  %d" % int(so.goals[k]), "SubLabel", 22, Game.C_GOLD)
		grid.add_child(l)
