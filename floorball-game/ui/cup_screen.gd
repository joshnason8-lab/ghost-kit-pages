extends Control
## The World Finals on the board: choose your country (and men's or women's) to start; then the groups' tables, your
## next match with Play, and the knockout draw as it fills; at the end, the medals.

var _women := false
var _pick := "SWE"


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var cup = Game.get_cup()
	if cup == null:
		_choose()
	else:
		_hub(cup)


func _choose() -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("CUP_NEW"))
	v.add_child(UI.wrap(tr("CUP_INTRO"), "MutedLabel", 18))
	v.add_child(UI.field(tr("DIVISION"), UI.chips([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1)))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var ids: Array = DB.team_ids()
	ids.sort_custom(func(a, b): return DB.rating(a, false) > DB.rating(b, false))
	for id in ids:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -6
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := UI.badge(id, Vector2(36, 24))
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(f)
		var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", 17), 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(nm)
		b.add_child(h)
		var grow := func(): b.custom_minimum_size.y = maxf(64.0, h.get_combined_minimum_size().y + 8.0)
		h.minimum_size_changed.connect(grow)
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			Game.new_cup(pick, _women)
			Game.show_screen("res://ui/cup_screen.gd"))
		grid.add_child(b)
	v.add_child(UI.scroll(grid))


func _hub(cup) -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("WOMEN") if cup.women else tr("MEN"))
	var right_head: HBoxContainer = get_meta("header_right")
	right_head.add_child(UI.button(tr("CUP_ABANDON"), false, func():
		Game.delete_cup()
		Game.show_screen("res://ui/cup_screen.gd")))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	cols.add_child(left)
	var tables := VBoxContainer.new()
	tables.add_theme_constant_override("separation", 14)
	left.add_child(UI.scroll(tables))
	var order := [cup.user_group()]
	for g in 4:
		if g != order[0]:
			order.append(g)
	for g in order:
		var sec: Array = UI.section(tr("GROUP_X").format({"x": ["A", "B", "C", "D"][g]}))
		var rows := []
		for r in cup.group_table(g):
			rows.append([r.id, r.p, r.w, r.d, r.l, "%d–%d" % [r.gf, r.ga], r.pts])
		sec[1].add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_GOALS"), tr("COL_PTS")], rows, cup.user, 2 if g < 2 else 2, 0, true))
		tables.add_child(sec[0])
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var next := UI.card()
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 10)
	next.add_child(nv)
	right.add_child(next)
	var f: Dictionary = cup.user_fixture()
	if cup.stage == "done":
		nv.add_child(UI.label(tr("CUP_OVER"), "HeaderLabel", 44, Game.C_BLUE))
		for k in ["gold", "silver", "bronze"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(UI.label(tr("MEDAL_" + k.to_upper()), "SubLabel", 20, {"gold": Game.C_GOLD, "silver": Game.C_MUTED, "bronze": Color("a8652f")}[k]))
			row.add_child(UI.badge(cup.medals[k], Vector2(33, 22)))
			row.add_child(UI.fit(UI.label(DB.team_name(cup.medals[k]), "SubLabel", 20)))
			nv.add_child(row)
		nv.add_child(UI.button(tr("CUP_AGAIN"), true, func():
			Game.delete_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	elif f.is_empty():
		nv.add_child(UI.wrap(tr("CUP_OUT"), "SubLabel", 20))
		nv.add_child(UI.button(tr("CUP_SIM_NEXT"), true, func():
			cup.sim_next()
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	else:
		nv.add_child(UI.label(tr("STAGE_" + String(cup.stage).to_upper()).to_upper(), "EyebrowLabel", 16, Game.C_RED))
		var vs := HBoxContainer.new()
		vs.add_theme_constant_override("separation", 10)
		vs.add_child(UI.badge(f.home, Vector2(42, 28)))
		var a := UI.fit(UI.label(DB.team_name(f.home), "SubLabel", 22), 2)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vs.add_child(a)
		vs.add_child(UI.label(tr("VS"), "MutedLabel", 18))
		var b := UI.fit(UI.label(DB.team_name(f.away), "SubLabel", 22), 2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vs.add_child(b)
		vs.add_child(UI.badge(f.away, Vector2(42, 28)))
		nv.add_child(vs)
		nv.add_child(UI.wrap(tr("KNOCKOUT_NOTE") if cup.knockout() else tr("GROUP_NOTE"), "MutedLabel", 16))
		nv.add_child(UI.button(tr("PLAY_MATCH"), true, func():
			var user_side := 0 if f.home == cup.user else 1
			Game.start_match({"home": f.home, "away": f.away, "venue": "arena", "user_team": user_side, "mode": "cup", "women": cup.women,
				"knockout": cup.knockout(), "rules": 0, "difficulty": int(Game.settings.difficulty), "stage": tr("STAGE_" + String(cup.stage).to_upper())})))
		nv.add_child(UI.button(tr("SIM_MATCH"), false, func():
			cup.sim_next()
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	# The knockout draw so far.
	var ko := VBoxContainer.new()
	ko.add_theme_constant_override("separation", 6)
	for st in ["playoffs", "qf", "sf", "medals"]:
		if not cup.fixtures.has(st):
			continue
		ko.add_child(UI.label(tr("STAGE_" + st.to_upper()), "EyebrowLabel", 15))
		for fx in cup.fixtures[st][0]:
			var line := "%s %s %s" % [DB.team_name(fx.home), ("%d–%d" % [int(fx.goals[0]), int(fx.goals[1])]) if bool(fx.played) else tr("VS"), DB.team_name(fx.away)]
			if bool(fx.so):
				line += " " + tr("SO_SHORT")
			elif bool(fx.ot):
				line += " " + tr("OT_SHORT")
			ko.add_child(UI.fit(UI.label(line, "SubLabel" if bool(fx.user) else "", 17, Game.C_BLUE if bool(fx.user) else Game.C_INK), 2))
	if ko.get_child_count() > 0:
		right.add_child(UI.scroll(ko))
