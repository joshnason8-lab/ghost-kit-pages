extends Control
## The club season on the board: choose your club (and men's or women's) to start; then the league table counted
## 3-2-1-0 with its key, the last round's results, your next match with Play, and the play-offs as they fill; at the
## end, the champions and how your season went.

var _women := false


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var season = Game.get_season()
	if season == null:
		_choose()
	else:
		_hub(season)


func _choose() -> void:
	var v := UI.page(self, tr("MENU_SEASON"), func(): Game.goto_menu(), tr("SEASON_NEW"))
	v.add_child(UI.wrap(tr("SEASON_INTRO"), "MutedLabel", 18))
	v.add_child(UI.field(tr("DIVISION"), UI.chips([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1)))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in DB.club_ids():
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -6
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := UI.badge(id, Vector2(36, 36))
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(f)
		var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", 17), 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(nm)
		b.add_child(h)
		var grow := func(): b.custom_minimum_size.y = maxf(72.0, h.get_combined_minimum_size().y + 8.0)
		h.minimum_size_changed.connect(grow)
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			Game.new_season(pick, _women)
			Game.show_screen("res://ui/season_screen.gd"))
		grid.add_child(b)
	v.add_child(UI.scroll(grid))


func _hub(season) -> void:
	var v := UI.page(self, tr("MENU_SEASON"), func(): Game.goto_menu(), DB.team_name(season.user) + " · " + (tr("WOMEN") if season.women else tr("MEN")))
	var right_head: HBoxContainer = get_meta("header_right")
	right_head.add_child(UI.button(tr("CUP_ABANDON"), false, func():
		Game.delete_season()
		Game.show_screen("res://ui/season_screen.gd")))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# Left: the table and the last round's results.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	cols.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 14)
	left.add_child(UI.scroll(lv))
	var sec: Array = UI.section(tr("SEASON_TABLE"))
	var rows := []
	for r in season.table():
		rows.append([r.id, r.p, r.w, r.otw, r.otl, r.l, "%d–%d" % [r.gf, r.ga], r.pts])
	sec[1].add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_OTW"), tr("COL_OTL"), tr("COL_L"), tr("COL_GOALS"), tr("COL_PTS")],
		rows, season.user, 4, 0, true))
	sec[1].add_child(UI.wrap(tr("SEASON_KEY"), "MutedLabel", 15))
	lv.add_child(sec[0])
	var last: int = season.last_league_round()
	if last >= 0:
		var res: Array = UI.section(tr("SEASON_RESULTS").format({"n": last + 1}))
		res[1].add_theme_constant_override("separation", 6)
		for fx in season.fixtures.league[last]:
			res[1].add_child(_line(fx))
		lv.add_child(res[0])
	# Right: your next match (or how the season ended), then the play-offs.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	right.add_child(UI.scroll(rv))
	var next := UI.card()
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 10)
	next.add_child(nv)
	rv.add_child(next)
	var me: int = season.place(season.user)
	var my_pts := 0
	for r in season.table():
		if String(r.id) == String(season.user):
			my_pts = int(r.pts)
	var standing := UI.bits([tr("SEASON_PLACE").format({"n": me}), Game.plural("SEASON_POINTS", my_pts)])
	var f: Dictionary = season.user_fixture()
	if season.stage == "done":
		nv.add_child(UI.label(tr("SEASON_OVER"), "HeaderLabel", 44, Game.C_BLUE))
		nv.add_child(_team_row(String(season.champion), Game.C_GOLD, 24))
		var ru := UI.label(tr("SEASON_RUNNER_UP").to_upper(), "EyebrowLabel", 15)
		nv.add_child(ru)
		nv.add_child(_team_row(String(season.runner_up), Game.C_MUTED, 20))
		var how := {"champion": "SEASON_WON", "final": "SEASON_LOST_FINAL", "sf": "SEASON_LOST_SF", "missed": "SEASON_MISSED"}
		nv.add_child(UI.wrap(tr(String(how.get(season.user_finish(), "SEASON_MISSED"))), "SubLabel", 20))
		nv.add_child(UI.wrap(standing, "MutedLabel", 17))
		nv.add_child(UI.button(tr("SEASON_NEW"), true, func():
			Game.delete_season()
			Game.show_screen("res://ui/season_screen.gd")))
	elif not f.is_empty():
		var eyebrow := ""
		match String(season.stage):
			"league":
				eyebrow = tr("SEASON_ROUND").format({"n": int(season.round) + 1, "total": Season.ROUNDS})
			"sf":
				eyebrow = tr("STAGE_SF")
			_:
				eyebrow = tr("STAGE_FINAL")
		nv.add_child(UI.label(eyebrow.to_upper(), "EyebrowLabel", 16, Game.C_RED))
		var vs := HBoxContainer.new()
		vs.add_theme_constant_override("separation", 10)
		vs.add_child(UI.badge(f.home, Vector2(32, 32)))
		var a := UI.fit(UI.label(DB.team_name(f.home), "SubLabel", 22), 2)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vs.add_child(a)
		vs.add_child(UI.label(tr("VS"), "MutedLabel", 18))
		var b := UI.fit(UI.label(DB.team_name(f.away), "SubLabel", 22), 2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vs.add_child(b)
		vs.add_child(UI.badge(f.away, Vector2(32, 32)))
		nv.add_child(vs)
		nv.add_child(UI.wrap(tr("SEASON_NOTE") if season.stage == "league" else tr("KNOCKOUT_NOTE"), "MutedLabel", 16))
		var stage_name := eyebrow
		nv.add_child(UI.button(tr("PLAY_MATCH"), true, func():
			var user_side := 0 if f.home == season.user else 1
			Game.start_match({"home": f.home, "away": f.away, "venue": "arena" if season.stage == "final" else "hall", "user_team": user_side,
				"mode": "season", "women": season.women, "knockout": true, "rules": int(Game.settings.rules),
				"difficulty": int(Game.settings.difficulty), "stage": stage_name})))
		nv.add_child(UI.button(tr("SIM_MATCH"), false, func():
			season.sim_next()
			Game.save_season()
			Game.show_screen("res://ui/season_screen.gd")))
		var left_n := 0
		for rnd in season.fixtures.league:
			for fx in rnd:
				if bool(fx.user) and not bool(fx.played):
					left_n += 1
		var info := standing
		if season.stage == "league":
			info = UI.bits([standing, Game.plural("SEASON_LEFT", left_n)])
		nv.add_child(UI.wrap(info, "MutedLabel", 16))
	else:
		# Not reached in play (a season without your match simulates itself on), but a saved file could say so.
		nv.add_child(UI.button(tr("CUP_SIM_NEXT"), true, func():
			season.sim_next()
			Game.save_season()
			Game.show_screen("res://ui/season_screen.gd")))
	# The play-offs.
	var po: Array = UI.section(tr("SEASON_PLAYOFFS"))
	po[1].add_theme_constant_override("separation", 6)
	if not season.fixtures.has("sf"):
		po[1].add_child(UI.wrap(tr("SEASON_PLAYOFF_NOTE"), "MutedLabel", 16))
	for st in ["sf", "final"]:
		if not season.fixtures.has(st):
			continue
		po[1].add_child(UI.label(tr("STAGE_" + st.to_upper()).to_upper(), "EyebrowLabel", 15))
		for fx in season.fixtures[st][0]:
			po[1].add_child(_line(fx))
	rv.add_child(po[0])


## One match on a line: home, the score (or v), away, and OT or the penalty shots' mark; yours in blue.
func _line(fx: Dictionary) -> Label:
	var line := "%s %s %s" % [DB.team_name(fx.home), ("%d–%d" % [int(fx.goals[0]), int(fx.goals[1])]) if bool(fx.played) else tr("VS"), DB.team_name(fx.away)]
	if bool(fx.played):
		if bool(fx.so):
			line += " " + tr("SO_SHORT")
		elif bool(fx.ot):
			line += " " + tr("OT_SHORT")
	return UI.fit(UI.label(line, "SubLabel" if bool(fx.user) else "", 17, Game.C_BLUE if bool(fx.user) else Game.C_INK), 2)


func _team_row(id: String, col: Color, fs: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var c := UI.badge(id, Vector2(30, 30))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", fs, col))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	return row
