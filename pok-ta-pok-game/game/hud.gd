extends CanvasLayer
## What is on the screen in a match. The count as it is kept at the court: rayas, tally strokes, on a board at the top
## (the word raya is the tally mark the count is kept in): eight places, the side holding the count filling them in
## its colour from its end, the urria places marked; on the classic court each side's points and the ring. Under it
## the time left. The judges' calls, the big moments, the serve coming; the pause menu; your controls (TouchControls).
## The theme is set on this layer's root: a CanvasLayer does not inherit the window's.

signal action(id: String)

var m: Node
var root: Control
var touch: TouchControls
var _board: Control
var _names: Array[Label] = []
var _time: Label
var _banner: Label
var _banner_t := 0.0
var _banner_total := 2.4
var _call: Label
var _call_t := 0.0
var _tag: Label
var _toast: Label
var _toast_t := 0.0
var _marks: Control
var _pause: Control
var _dev: Label
var _frames := PackedFloat32Array()
var _quality := -1.0
var _quality_t := 0.0
var _tips_shown := 0


func _ready() -> void:
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
	_build_board()
	_tag = _outlined("", "EyebrowLabel", 20, Game.C_INK)
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tag.offset_top = 128
	_tag.offset_left = -330
	_tag.offset_right = 330
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_tag, 1)
	root.add_child(_tag)
	_call = _outlined("", "SubLabel", 24, Game.C_GOLD)
	_call.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_call.offset_top = 160
	_call.offset_left = -440
	_call.offset_right = 440
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_call, 2)
	root.add_child(_call)
	_banner = _outlined("", "TitleLabel", 96, Game.C_GOLD)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -560
	_banner.offset_right = 560
	_banner.offset_top = -120
	_banner.offset_bottom = 10
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.shrink(_banner, 96, 0.5, 1)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_toast = _outlined("", "SubLabel", 21, Game.C_INK)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -64
	_toast.offset_bottom = -24
	_toast.offset_left = -330
	_toast.offset_right = 330
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_toast, 2)
	root.add_child(_toast)
	var sm := UI.safe_margins(root, 24.0)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_right = -sm.z
	box.offset_top = 16
	box.offset_left = -200
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(UI.round_button("camera", func(): _next_camera(), 58))
	box.add_child(UI.round_button("pause", func(): m.set_paused(not m.paused), 58))
	touch = TouchControls.new()
	root.add_child(touch)
	touch.action.connect(func(id): action.emit(id))
	touch.visible = int(m.user_team) >= 0
	_dev = UI.label("", "MutedLabel", 15, Game.C_GOLD)
	_dev.position = Vector2(sm.x + 6, 132)
	_dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev.visible = bool(Game.settings.get("dev", false))
	root.add_child(_dev)
	var stage := String(m.config.get("stage", ""))
	var place := tr("VENUE_" + String(m.venue.id).to_upper())
	toast((stage + "  ·  " if stage != "" else "") + place, 3.5)


func joystick() -> Vector2:
	return touch.joystick if touch and touch.visible else Vector2.ZERO


func set_buttons(ids: Array) -> void:
	if touch and touch.ids != ids:
		touch.set_buttons(ids)


func _outlined(text: String, variation: String, size: int, col: Color) -> Label:
	var l := UI.label(text, variation, size, col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------------------------------------------------------------- the count board

func _build_board() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.07, 0.86)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(Game.C_PAPER, 0.25)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 12
	panel.offset_left = -330
	panel.offset_right = 330
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for k in 2:
		var t := DB.team(String(m.teams[k].id))
		var chip := ColorRect.new()
		chip.color = t.c1
		chip.custom_minimum_size = Vector2(8, 34)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := UI.label(String(t.town), "SubLabel", 20)
		n.custom_minimum_size = Vector2(160, 0)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k == 0 else HORIZONTAL_ALIGNMENT_LEFT
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UI.shrink(n, 20, 0.7, 1)
		_names.append(n)
		if k == 0:
			row.add_child(n)
			row.add_child(chip)
			_board = Control.new()
			_board.custom_minimum_size = Vector2(250, 38)
			_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_board.draw.connect(_draw_board)
			row.add_child(_board)
		else:
			row.add_child(chip)
			row.add_child(n)
	_time = UI.label("", "EyebrowLabel", 15, Game.C_MUTED)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(_time, 1)
	v.add_child(_time)


## The board: eight places in a row between the two names. Ulama: the side holding the count fills them in its colour
## from its own end (team 0 from the left), a stroke a raya; the urria places notched underneath, lit red while the
## holder stands on one. Classic: each side's points as strokes from its end, the target in the middle.
func _draw_board() -> void:
	var s := _board.size
	var c: Rules.Count = m.count
	var n := Rules.target(c.rules)
	var gap := s.x / float(n + 1)
	var font: Font = Game.font_display
	if c.rules == Rules.CLASSIC:
		var half := s.x * 0.5
		for k in 2:
			var pts := c.of(k)
			var col: Color = DB.team(String(m.teams[k].id)).c1
			var txt := str(pts)
			var x := half - 40.0 if k == 0 else half + 40.0
			_board.draw_string(font, Vector2(x - 20, s.y * 0.78), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Game.C_INK)
			_board.draw_rect(Rect2(x - 14, s.y - 4, 28, 3), col)
		_board.draw_arc(Vector2(half, s.y * 0.5), 9.0, 0, TAU, 24, Game.C_PAPER, 3.0, true)
		_board.draw_string(Game.font_bold, Vector2(half - 20, s.y * 0.95), "/" + str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Game.C_MUTED)
		return
	var holder := c.holder
	var hcol: Color = DB.team(String(m.teams[holder].id)).c1 if holder >= 0 else Game.C_PAPER
	for i in n:
		# Place i (1-based raya i + 1), counted from the holder's end.
		var slot := i if holder != 1 else n - 1 - i
		var x := gap * (slot + 1)
		var filled := holder >= 0 and i < c.rayas
		var urria := (i + 1) in c.urria
		var col := hcol if filled else Color(Game.C_PAPER, 0.22)
		var w := 5.0 if filled else 3.0
		_board.draw_line(Vector2(x, 5), Vector2(x + 2, s.y - 9), col, w, true)
		if urria:
			var hot: bool = c.in_urria() and c.rayas == i + 1
			_board.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, s.y - 1), Vector2(x + 6, s.y - 1), Vector2(x + 1, s.y - 7)]),
				Game.C_DANGER if hot else Color(Game.C_SAFFRON, 0.6))
	# The analco between the two halves of the board.
	_board.draw_line(Vector2(s.x * 0.5, 0), Vector2(s.x * 0.5, s.y), Color(Game.C_PAPER, 0.15), 1.0)


func refresh() -> void:
	var delta := get_process_delta_time()
	_board.queue_redraw()
	var c: Rules.Count = m.count
	var txt := ""
	if m.limit_s > 0.0:
		var left := maxi(0, int(ceil(m.limit_s - m.clock)))
		txt = tr("TIME_LEFT").format({"t": "%d:%02d" % [left / 60, left % 60]})
	if m.sudden:
		txt = tr("NEXT_RAYA_WINS")
	elif c.in_urria():
		txt = tr("IN_URRIA").format({"team": DB.short_name(String(m.teams[c.holder].id))}) + ("  ·  " + txt if txt != "" else "")
	elif c.rules == Rules.ULAMA and c.holder < 0:
		txt = tr("COUNT_LEVEL") + ("  ·  " + txt if txt != "" else "")
	if _time.text != txt:
		_time.text = txt
	for k in 2:
		_names[k].add_theme_color_override("font_color", Game.C_GOLD if c.holder == k or c.winner == k else Game.C_INK)
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
		# A small pop as it comes up, never bigger than the screen allows.
		_banner.scale = Vector2.ONE * (1.0 + clampf(_banner_t - (_banner_total - 0.3), 0.0, 0.3) * 0.25)
		_banner.pivot_offset = _banner.size * 0.5
	if _call_t > 0.0:
		_call_t -= delta
		_call.modulate.a = clampf(_call_t / 0.5, 0.0, 1.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	if _quality_t > 0.0:
		_quality_t -= delta
	_frames.append(delta * 1000.0)
	if _frames.size() > 300:
		_frames = _frames.slice(_frames.size() - 300)
	if _dev.visible:
		var pc := frame_percentiles()
		var rs := RenderingServer
		_dev.text = "frame ms p50 %.1f  p95 %.1f  max %.1f  hitches %d\ndraws %d  prims %d  gfx %d  fps %d" % [pc[0], pc[1], pc[2], pc[3],
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), int(Game.settings.graphics),
			Engine.get_frames_per_second()]
	if m.phase == m.P.SERVE and int(m.user_team) >= 0 and bool(Game.settings.get("coach", true)) and _tips_shown < 3 and _toast_t <= 0.0:
		var keys := ["TIP_SERVE", "TIP_HIP", "TIP_DIVE"]
		toast(tr(keys[_tips_shown]), 5.0)
		_tips_shown += 1
	_marks.queue_redraw()


## The dev overlay's frame times: the median, the 95th percentile, the worst, and hitches (frames over 50 ms).
func frame_percentiles() -> Array:
	if _frames.is_empty():
		return [0.0, 0.0, 0.0, 0]
	var a := Array(_frames)
	a.sort()
	var hitches := 0
	for f in a:
		if float(f) > 50.0:
			hitches += 1
	return [a[a.size() / 2], a[mini(a.size() - 1, int(a.size() * 0.95))], a[a.size() - 1], hitches]


# ---------------------------------------------------------------- calls

func banner(text: String, col: Color = Game.C_GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	UI.refit(_banner)
	_banner_t = 2.4
	_banner_total = 2.4


func call_line(text: String) -> void:
	_call.text = text
	UI.refit(_call)
	_call_t = 3.2


func toast(text: String, secs := 2.6) -> void:
	_toast.text = text
	UI.refit(_toast)
	_toast_t = secs


func note(text: String) -> void:
	toast(text, 3.0)


func serve_tag(team: int, kind: String) -> void:
	if team < 0:
		_tag.text = ""
		return
	var who := DB.short_name(String(m.teams[team].id))
	_tag.text = tr({"abajo": "SERVE_ABAJO", "bote": "SERVE_BOTE"}.get(kind, "SERVE_ARRIBA")).format({"team": who})
	UI.refit(_tag)


## The judges' call, in words: what happened, then what it did to the count.
func call_raya(team: int, reason: String, what: String, fault: bool, who) -> void:
	var t := DB.short_name(String(m.teams[team].id))
	var o := DB.short_name(String(m.teams[1 - team].id))
	var why := tr("WHY_" + reason.to_upper()).format({"team": o, "name": (who as Player).pname if who is Player else ""})
	var how := ""
	match what:
		"add":
			how = tr("COUNT_ADD").format({"team": t, "n": m.count.of(team)}) if m.count.rules == Rules.ULAMA else tr("POINT_TO").format({"team": t})
		"cancel":
			how = tr("COUNT_CANCEL").format({"team": t, "other": o})
		"urria":
			how = tr("COUNT_URRIA").format({"team": t, "other": o})
		"win", "ring":
			how = tr("COUNT_WIN").format({"team": t})
	call_line(why + "  ·  " + how)
	if reason == "ring":
		banner(tr("BANNER_RING"), Game.C_GOLD)
	elif what == "urria":
		banner(tr("BANNER_URRIA"), Game.C_DANGER)
	elif fault:
		banner(tr("BANNER_FAULT"), Game.C_DANGER)
	else:
		banner(tr("BANNER_RAYA"), DB.team(String(m.teams[team].id)).c1.lightened(0.3))


func full_time(winner: int) -> void:
	if winner < 0:
		return
	banner(tr("WINS").format({"team": DB.short_name(String(m.teams[winner].id))}), Game.C_GOLD)
	_banner_t = 3.4
	_banner_total = 3.4


## How well you met it: a word for a moment over your player.
func strike_feedback(q: float) -> void:
	_quality = q
	_quality_t = 0.9


# ---------------------------------------------------------------- marks over the picture

func _draw_marks() -> void:
	var cam: Camera3D = m.cam.camera
	if m.user_player != null and touch.visible:
		var p: Vector3 = m.user_player.global_position
		if not cam.is_position_behind(p):
			var c := cam.unproject_position(p)
			var top := cam.unproject_position(p + Vector3(0, 1.9, 0))
			var r := maxf(10.0, (c.y - top.y) * 0.3)
			var pts := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				pts.append(cam.unproject_position(p + Vector3(cos(a) * 0.55, 0.02, sin(a) * 0.55)))
			_marks.draw_polyline(pts, Color(Game.C_GOLD, 0.9), 2.5, true)
			if _quality_t > 0.0:
				var key := "Q_PERFECT" if _quality > 0.85 else ("Q_GOOD" if _quality > 0.55 else "Q_LATE")
				var col := Game.C_GOOD if _quality > 0.85 else (Game.C_GOLD if _quality > 0.55 else Game.C_DANGER)
				_marks.draw_string(Game.font_display, top + Vector2(-80, -12), tr(key), HORIZONTAL_ALIGNMENT_CENTER, 160, 24, Color(col, clampf(_quality_t / 0.4, 0.0, 1.0)))
			r = r
	# Where a live ball will come down to hip height in your half: a ring on the earth, to read the bounce.
	if m.is_live() and touch.visible and int(m.user_team) >= 0:
		for pt in m.ball_path:
			var q: Vector3 = pt[0]
			if Rules.half_of(q.x) == int(m.user_team) and q.y < 1.0 and q.y > 0.55 and m.ball.vel.y < 0.0:
				if not cam.is_position_behind(q):
					var pts2 := PackedVector2Array()
					for i in 21:
						var a := TAU * i / 20.0
						pts2.append(cam.unproject_position(Vector3(q.x + cos(a) * 0.35, m.court.floor_y(q.x, q.z) + 0.03, q.z + sin(a) * 0.35)))
					_marks.draw_polyline(pts2, Color(Game.C_INK, 0.55), 2.0, true)
				break


func _next_camera() -> void:
	var order := [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]
	var i := order.find(int(Game.settings.camera))
	Game.settings.camera = order[(i + 1) % order.size()]
	Game.save_settings()
	m.cam.mode = int(Game.settings.camera)


# ---------------------------------------------------------------- pause

func show_pause(on: bool) -> void:
	if on and _pause == null:
		_pause = _overlay()
		var v: VBoxContainer = _pause.get_meta("col")
		var t := UI.label(tr("PAUSED"), "HeaderLabel", 44)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var s := UI.label(score_line(), "SubLabel", 21, Game.C_MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.fit(s, 2)
		v.add_child(s)
		var b1 := UI.button(tr("RESUME"), true, func(): m.set_paused(false))
		b1.custom_minimum_size = Vector2(340, 64)
		v.add_child(b1)
		var b2 := UI.button(tr("QUIT_MATCH"), false, func(): Game.goto_menu())
		b2.custom_minimum_size = Vector2(340, 56)
		v.add_child(b2)
		touch.visible = false
	elif not on and _pause != null:
		_pause.queue_free()
		_pause = null
		touch.visible = int(m.user_team) >= 0


## "Escuinapa hold 3 rayas", "Level", or the points.
func score_line() -> String:
	var c: Rules.Count = m.count
	if c.rules == Rules.CLASSIC:
		return "%s %d  ·  %s %d" % [DB.short_name(String(m.teams[0].id)), c.of(0), DB.short_name(String(m.teams[1].id)), c.of(1)]
	if c.holder < 0:
		return tr("COUNT_LEVEL")
	return Plural.word("HOLDS_RAYAS", c.rayas).format({"team": DB.short_name(String(m.teams[c.holder].id))})


func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.05, 0.03, 0.02, 0.74)
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
