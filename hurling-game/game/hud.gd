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
var _bug: Control              # the scorebug, top left (hidden in free-taking practice)
var _practice: Control         # free-taking practice: the free, the score, the marks (in the scorebug's place)
var _cam_button: Control       # the match cameras (none in free-taking practice: its camera is its own)
var _intro: Control
var _intro_t := 0.0
var _dev: Label
var _active: Player = null
var _coach: Control
var _subs: Control
var _coach_text: Label
var _coach_t := 0.0
var _drop := Vector3.INF     # where a high ball near your player comes down to catching height (INF none)
var _drop_t := 0.0
var _replay: Control = null   # "Replay", over the whole screen while one plays: a tap anywhere skips it
var _sub_board: Control = null   # the fourth official's board: a substitution, its county, who comes on and off
var _sub_queue: Array = []       # [team id, on, off] still to show, one after another
var _sub_t := 0.0


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
	_cam_button = UI.round_button("camera", func(): _next_camera(), 60)
	box.add_child(_cam_button)
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


func _drop_spot() -> Vector3:
	var b: Sliotar = m.ball
	if m.user_team < 0 or _active == null or b.state != Sliotar.FREE or b.global_position.y < 4.0:
		return Vector3.INF
	var hit: Array = Sliotar.first_at_height(b.global_position, b.vel, m.CATCH_H)
	if hit.is_empty():
		return Vector3.INF
	var at: Vector3 = hit[1]
	at.y = 0.0
	var me := _active.global_position
	if Vector2(at.x - me.x, at.z - me.z).length() > 35.0:
		return Vector3.INF
	return at


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
	_bug = panel
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
	_sub_step(delta)
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = 0.15
		_drop = _drop_spot()
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


## The replay's tag at the top and its tap-to-skip over everything (on), or gone.
func replay(on: bool, skip: Callable) -> void:
	if _replay != null:
		_replay.queue_free()
		_replay = null
	_tag.visible = not on
	_call.visible = not on
	if not on:
		return
	_replay = Control.new()
	_replay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replay.mouse_filter = Control.MOUSE_FILTER_STOP
	_replay.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			skip.call())
	root.add_child(_replay)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 60
	box.offset_left = -300
	box.offset_right = 300
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_replay.add_child(box)
	var head := _outlined(tr("REPLAY").to_upper(), "SubLabel", 30, Game.C_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(head, 1)
	box.add_child(head)
	var hint := _outlined(tr("REPLAY_SKIP"), "MutedLabel", 18, Game.C_INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(hint, 1)
	box.add_child(hint)


## Redraws the marks (the replay steps the picture while the match, and so tick, stands still).
## Where a high ball near your player comes down to catching height (Vector3.INF when there is none).
func drop_spot() -> Vector3:
	return _drop


func redraw_marks() -> void:
	_marks.queue_redraw()


func call_line(text: String) -> void:
	_call.text = text
	UI.refit(_call)
	_call_t = 2.6
	_call.modulate.a = 1.0


## A substitution on the fourth official's board, below the score: the county's colours, the man coming on (green)
## and the man going off (red), four seconds each; two or three at once are shown in turn.
func substitution(team_id: String, on_name: String, off_name: String) -> void:
	_sub_queue.append([team_id, on_name, off_name])
	if _sub_board == null:
		_show_next_sub()


func _show_next_sub() -> void:
	if _sub_queue.is_empty():
		return
	var it: Array = _sub_queue.pop_front()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.05, 0.92)
	sb.set_corner_radius_all(8)
	sb.border_color = Game.C_GOLD
	sb.border_width_left = 4
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var sm := UI.safe_margins(root, 24.0)
	panel.position = Vector2(sm.x, 112)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var chip := Colours.make(String(it[0]), 40)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UI.label(tr("SUB_BOARD").to_upper() + "  ·  " + DB.short_name(String(it[0])), "EyebrowLabel", 14, Game.C_GOLD))
	v.add_child(UI.label("↑  " + String(it[1]), "SubLabel", 21, Color("6fdc7a")))
	v.add_child(UI.label("↓  " + String(it[2]), "SubLabel", 21, Color("ff6b5e")))
	root.add_child(panel)
	_sub_board = panel
	_sub_t = 4.0


func _sub_step(delta: float) -> void:
	if _sub_board == null:
		return
	_sub_t -= delta
	_sub_board.modulate.a = clampf(_sub_t / 0.4, 0.0, 1.0)
	_sub_board.visible = _replay == null
	if _sub_t <= 0.0:
		_sub_board.queue_free()
		_sub_board = null
		_show_next_sub()


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
	# Where a high ball comes down, for him, now (not at the next look): his buttons come with it.
	_drop = _drop_spot()
	_drop_t = 0.15


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
	# Through whichever camera is showing (a replay has its own): the ball's marker follows the ball on the screen.
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	if cam == null:
		cam = m.cam.camera
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
	# A high ball dropping near your player: a ring on the grass where it comes down to hand height, so a ball in the
	# air against the crowd or the sky can be judged and caught.
	if _drop != Vector3.INF and m.controls.visible and not cam.is_position_behind(_drop):
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(cam.unproject_position(_drop + Vector3(cos(a) * 1.3, 0.03, sin(a) * 1.3)))
		_marks.draw_polyline(pts, Color(Game.C_GOLD, 0.85), 2.5, true)
	# Your player's ring and number (none in free-taking practice: he is the only one, and close).
	if _active != null and is_instance_valid(_active) and _active.visible and m.controls.visible and not m.is_practice():
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
		var line := "%s %s  ·  %s %s" % [DB.short_name(String(m.teams[0].id)), m.score_text(0), DB.short_name(String(m.teams[1].id)), m.score_text(1)]
		if m.is_practice():
			line = _practice_line(m.practice)
		var s := UI.label(line, "SubLabel", 22, Game.C_MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.fit(s, 2)
		v.add_child(s)
		var b1 := UI.button(tr("RESUME"), true, func(): m.set_paused(false))
		b1.custom_minimum_size = Vector2(320, 64)
		v.add_child(b1)
		if m.is_practice():
			var ba := UI.button(tr("PRACTICE_RESTART"), false, func(): m.again())
			ba.custom_minimum_size = Vector2(320, 56)
			v.add_child(ba)
		if m.user_team >= 0 and not m.is_practice():
			var bs := UI.button(tr("SUBS") + "  ·  " + (Plural.word("SUBS_LEFT", m.subs_left(m.user_team)) if m.subs_left(m.user_team) > 0 else tr("SUBS_NONE")), false, func(): open_subs())
			bs.custom_minimum_size = Vector2(320, 56)
			v.add_child(bs)
		if m.user_team >= 0 and not m.is_practice():
			var bt := UI.button(tr("TACTICS"), false, func(): open_tactics())
			bt.custom_minimum_size = Vector2(320, 56)
			v.add_child(bt)
		if m.user_team >= 0 and m.phase != m.P.SHOOTOUT and not m.is_practice():
			var bsim := UI.button(tr("SIM_TO_END"), false, func(): m.sim_to_end())
			bsim.custom_minimum_size = Vector2(320, 56)
			v.add_child(bsim)
		var b2 := UI.button(tr("PRACTICE_QUIT") if m.is_practice() else tr("QUIT_MATCH"), false, func(): m.quit_match())
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


# ---------------------------------------------------------------- free-taking practice

## The practice in the scorebug's place, top left: which free of the ten, the score, a mark for each one taken
## (gold a point, green a goal, a cross for the rest), the best so far. first: the match's intro and scorebug go.
func practice(st: Dictionary, first := false) -> void:
	if first:
		_bug.visible = false
		_cam_button.visible = false
		if _intro != null and is_instance_valid(_intro):
			_intro.queue_free()
			_intro = null
		_added.visible = false
	if _practice == null:
		var sm := UI.safe_margins(root, 24.0)
		_practice = PanelContainer.new()
		_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.07, 0.05, 0.88)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		_practice.add_theme_stylebox_override("panel", sb)
		_practice.position = Vector2(sm.x, 16)
		root.add_child(_practice)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_practice.add_child(v)
		var head := UI.label("", "EyebrowLabel", 15, Game.C_SAFFRON)
		v.add_child(head)
		var score := UI.label("", "ScoreLabel", 30, Game.C_INK)
		v.add_child(score)
		var marks := HBoxContainer.new()
		marks.add_theme_constant_override("separation", 5)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(marks)
		_practice.set_meta("parts", [head, score, marks])
	var parts: Array = _practice.get_meta("parts")
	var n := mini(int(st.n) + (1 if String(st.get("state", "")) in ["walk", "aim", "struck"] else 0), m.FREES)
	var head := tr("MENU_PRACTICE") + "  ·  " + tr("PRACTICE_FREE_N").format({"n": n, "of": m.FREES})
	if String(st.get("challenge", "")) != "" and String(st.get("state", "")) in ["walk", "aim", "struck"]:
		head += "  ·  " + tr("PRACTICE_CHALLENGE")
	(parts[0] as Label).text = head.to_upper()
	(parts[1] as Label).text = _practice_line(st)
	_fill_marks(parts[2], st.marks, m.FREES, 14)


## "Score 4  ·  Best 7".
func _practice_line(st: Dictionary) -> String:
	var line := tr("PRACTICE_SCORE_N").format({"n": int(st.points)})
	if int(st.get("best", -1)) >= 0:
		line += "  ·  " + tr("PRACTICE_BEST_N").format({"n": int(st.best)})
	return line


## A row of round marks: gold a point, green a goal, red-brown a miss, hollow one to come.
func _fill_marks(row: HBoxContainer, marks: Array, total: int, px: int) -> void:
	for c in row.get_children():
		c.queue_free()
	for i in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(px, px)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(px)
		if i < marks.size():
			match String(marks[i]):
				"P":
					sb.bg_color = Game.C_GOLD
				"G":
					sb.bg_color = Color(0.35, 0.85, 0.45)
				"C":
					sb.bg_color = Color(1.0, 0.95, 0.72)
					sb.border_color = Game.C_GOLD
					sb.set_border_width_all(3)
				_:
					sb.bg_color = Color(0.75, 0.3, 0.25)
		else:
			sb.bg_color = Color(1, 1, 1, 0.0)
			sb.border_color = Color(1, 1, 1, 0.55)
			sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)


## The ten taken: the score, how it stands, the best (a new one marked), and go again or home.
func practice_done(st: Dictionary, best: int, new_best: bool) -> void:
	if _practice != null:
		_practice.visible = false
	_card = _overlay()
	var v: VBoxContainer = _card.get_meta("col")
	var t := UI.label(tr("PRACTICE_DONE"), "HeaderLabel", 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shrink(t, 38, 0.6, 1)
	v.add_child(t)
	var big := UI.label(str(int(st.points)), "TitleLabel", 96, Game.C_GOLD)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_marks(row, st.marks, m.FREES, 20)
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var pts := int(st.points)
	var rate := tr("PRACTICE_RATE_3" if pts >= 12 else ("PRACTICE_RATE_2" if pts >= 9 else ("PRACTICE_RATE_1" if pts >= 6 else "PRACTICE_RATE_0")))
	var r := UI.label(rate, "SubLabel", 22)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(r, 2)
	v.add_child(r)
	var b := UI.label(tr("PRACTICE_NEW_BEST") if new_best else tr("PRACTICE_BEST_WAS").format({"n": best}), "SubLabel", 22,
		Game.C_GOLD if new_best else Game.C_MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var again := UI.button(tr("PRACTICE_AGAIN"), true, func(): m.again())
	again.custom_minimum_size = Vector2(320, 64)
	v.add_child(again)
	var home := UI.button(tr("HOME"), false, func(): m.quit_match())
	home.custom_minimum_size = Vector2(320, 56)
	v.add_child(home)
