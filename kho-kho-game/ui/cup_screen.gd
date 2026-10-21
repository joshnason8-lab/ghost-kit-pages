extends Control
## Championships: pick one (the nations' world championship, to the fast rules; the states' national championship, to
## the classic rules), men's or women's, and your side; then the championship's hub: your group's table and the other
## groups', your next match (play it, or let the AI play it), the knockout rounds as they are drawn, and the champion.

var _kind := "world"
var _women := false


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var c = Game.get_cup()
	if c == null:
		_pick()
	else:
		_hub(c)


func _clear() -> void:
	for ch in get_children():
		ch.queue_free()
	UI.screen(self)


func _pick() -> void:
	var v := UI.page(self, tr("CUP_TITLE"), func(): Game.goto_menu())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(UI.scroll(left))
	(left.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in Cup.KINDS:
		var kk: String = k
		var key := "CUP_WORLD" if k == "world" else "CUP_NATIONAL"
		left.add_child(UI.option_card(tr(key), tr(key + "_DESC"), FieldIcon.make(KhoRules.FAST if k == "world" else KhoRules.CLASSIC), _kind == k, func():
			_kind = kk
			_clear()
			_pick()))
	left.add_child(UI.chips_row([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_clear()
		_pick()))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.label(tr("CUP_PICK_TEAM").to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	var ids: Array = DB.nation_ids() if _kind == "world" else DB.state_ids()
	for id in ids:
		var b := Button.new()
		b.theme_type_variation = "LaneButton"
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -6
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cr := Crest.make(id, 30)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
		var nm := UI.label(DB.team_name(id), "", 17)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(nm, 2, 0.62)   # a long one-word name (Malayalam's Andhra Pradesh) gets smaller rather than broken
		h.add_child(nm)
		b.add_child(h)
		var pid: String = id
		b.pressed.connect(func():
			Sfx.click()
			var c = Game.new_cup(_kind, pid, _women)
			_clear()
			_hub(c))
		g.add_child(b)
	right.add_child(UI.scroll(g))


func _hub(c) -> void:
	var v := UI.page(self, c.title(), func(): Game.goto_menu(), c.stage_name())
	var right_h: HBoxContainer = get_meta("header_right")
	right_h.add_child(UI.button(tr("CUP_NEW"), false, func():
		Game.delete_cup()
		_clear()
		_pick()))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# Your next match, or the champion.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var card := UI.card()
	left.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	if String(c.stage) == "done":
		var t := UI.label(tr("CUP_CHAMPIONS").format({"team": DB.team_name(c.champion)}), "HeaderLabel", 36, Game.C_GOLD)
		UI.fit(t, 2)
		cv.add_child(t)
		cv.add_child(Crest.make(c.champion, 80))
	elif c.user_out():
		cv.add_child(UI.wrap(tr("CUP_OUT"), "SubLabel", 22))
		cv.add_child(UI.button(tr("CONTINUE"), true, func():
			c.sim_round(true)
			Game.save_cup()
			_clear()
			_hub(c)))
	else:
		var p: Array = c.user_fixture()
		cv.add_child(UI.label(tr("CUP_NEXT_MATCH").to_upper(), "EyebrowLabel", 14, Game.C_SAFFRON))
		if not p.is_empty():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			for k in 2:
				row.add_child(Crest.make(p[k], 40))
				var nm := UI.label(DB.team_name(p[k]), "SubLabel", 22, Game.C_GOLD if p[k] == c.user else Game.C_INK)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				UI.fit(nm, 2)
				row.add_child(nm)
				if k == 0:
					row.add_child(UI.label(tr("VS"), "SubLabel", 20, Game.C_MUTED))
			cv.add_child(row)
			cv.add_child(UI.button(tr("CUP_PLAY_MATCH"), true, func(): _play(c, p)))
			cv.add_child(UI.button(tr("CUP_SIM_MATCH"), false, func():
				c.sim_round(true)
				Game.save_cup()
				_clear()
				_hub(c)))
	# The knockout results so far.
	for r in c.ko_results:
		var line := UI.label("%s · %s %d – %d %s" % [_stage_word(String(r[0])), DB.team_name(r[1]), int(r[3]), int(r[4]), DB.team_name(r[2])],
			"", 17, Game.C_INK if c.user in [r[1], r[2]] else Game.C_MUTED)
		UI.fit(line, 2)
		left.add_child(line)
	# The groups.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	cols.add_child(UI.scroll(right))
	(right.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var order := [c.user_group()]
	for gi in 4:
		if gi != order[0]:
			order.append(gi)
	for gi in order:
		right.add_child(UI.label(tr("CUP_GROUP_N").format({"n": String.chr(65 + gi)}), "SubLabel", 20, Game.C_SAFFRON))
		var rows := []
		for row in c.group_table(gi):
			rows.append([row.id, int(row.p), int(row.w), int(row.d), int(row.l), UI.signed(int(row.pf) - int(row.pa)), int(row.pts)])
		right.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_PD"), tr("COL_PTS")],
			rows, c.user, 2, 0, true))


func _stage_word(s: String) -> String:
	return tr({"qf": "CUP_STAGE_QF", "sf": "CUP_STAGE_SF", "f": "CUP_STAGE_F"}.get(s, "CUP_STAGE_GROUPS"))


func _play(c, p: Array) -> void:
	# Your side is always the first named (home) in the match; the toss is the referee's, held at random.
	var home: String = c.user
	var away: String = p[1] if p[0] == c.user else p[0]
	var venue: String = "arena" if c.kind == "world" else ["maidan", "floodlit", "school"][c.round % 3]
	Game.start_match({"home": home, "away": away, "venue": venue, "format": c.fmt(), "turn_len": [180.0, 300.0, KhoRules.real_turn(c.fmt())][int(Game.settings.turn_len)],
		"difficulty": int(Game.settings.difficulty), "mode": "cup", "user_team": 0, "women": c.women, "chase_first": randi() % 2,
		"knockout": c.knockout(), "stage": c.stage_name(), "follow_on": bool(Game.settings.follow_on), "powerplay": bool(Game.settings.powerplay)})
