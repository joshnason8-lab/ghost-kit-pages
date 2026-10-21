extends Control
## League Season: pick a league and a club, then the season's home, laid out for the league's real format: the STL's
## Grand Prix standings and the Grand Prix being played; the Thai league's table of ties; Indonesia's region and the
## national finals. Your next match (play it, or let it be played), the latest results, and at the end the champions,
## who went up or down, and the awards.

var _league := "MY"
var _women := false


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var s = Game.get_season()
	if s == null:
		_choose()
	else:
		_hub(s)


# ---------------------------------------------------------------- a new season

func _choose() -> void:
	var v := UI.page(self, tr("MENU_SEASON"), func(): Game.goto_menu(), tr("NEW_SEASON"))
	var parts := UI.pick_layout(v, tr("PICK_CLUB"))
	var left: VBoxContainer = parts[0]
	for lid in ["MY", "TH", "ID"]:
		var id: String = lid
		left.add_child(UI.option_card(tr(DB.LEAGUES[id].name), tr("LEAGUE_NOTE_" + id), UI.badge(String(DB.LEAGUES[id].country), Vector2(54, 36)),
			id == _league, func():
				_league = id
				_refresh()))
	if bool(DB.LEAGUES[_league].get("women", false)):
		var gender := UI.chips_row([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
			_women = i == 1
			_refresh())
		(parts[1] as HBoxContainer).add_child(gender)
	else:
		(parts[1] as HBoxContainer).add_child(UI.label(tr("MEN_ONLY"), "MutedLabel", 16))
	var ids: Array = DB.league_clubs(_league)
	if _league == "MY":
		ids = ids + DB.league_clubs("MY", 2)   # Division 1's clubs after the Premier League's
	var tags := {}
	for id in ids:
		if _league == "MY":
			tags[id] = UI.pill(tr("STL_PREMIER" if id in DB.league_clubs("MY", 1) else "STL_DIV1"), Game.C_GOLD if id in DB.league_clubs("MY", 1) else Game.C_MUTED)
		elif _league == "ID":
			tags[id] = UI.pill(tr(DB.zone_of(id)), Game.C_TEAL)
	var grid := UI.team_grid(self, ids, 2, func(id):
		Game.new_season(_league, id, _women)
		Game.show_screen("res://ui/season_hub.gd"), tags)
	(parts[2] as VBoxContainer).add_child(UI.scroll(grid))


func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	UI.screen(self)
	_choose()


# ---------------------------------------------------------------- the season

func _hub(s: Season) -> void:
	var title := tr(DB.LEAGUES[s.league].name)
	if s.league == "MY":
		title = tr("STL_DIV1" if s.division == 2 else "STL_PREMIER")
	var v := UI.page(self, title, func(): Game.goto_menu(), tr("SEASON_YEAR").format({"y": s.year}) + " · " + s.stage_name())
	var right: HBoxContainer = get_meta("header_right")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45 if s.format() == "ties" else 1.1
	cols.add_child(left)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(side)
	# Left: the season's table; under it, for a tournament (a Grand Prix, Division 1, the finals), where it stands.
	var lc := UI.card()
	lc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 14)
	lc.add_child(lv)
	_main_table(s, lv)
	left.add_child(UI.scroll(lc))
	# Right: your next match, then the latest results (or the season's end).
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	if s.phase == "done":
		_done(s, rv, right)
	else:
		_next(s, rv)
		_latest(s, rv)
		right.add_child(UI.button(tr("ABANDON"), false, func(): _confirm_abandon()))
	side.add_child(UI.scroll(rv))


## The table the season is decided on.
func _main_table(s: Season, lv: VBoxContainer) -> void:
	var ev := s.event()
	match s.format():
		"gp":
			if s.division == 1 and not s.standings.is_empty():
				lv.add_child(_eyebrow(tr("STANDINGS") + " · " + tr("GPS_PLAYED").format({"n": s.gps_done(), "of": DB.STL_GPS.size()})))
				var rows := []
				for r in s.gp_table():
					rows.append([r.id, int(r.w), int(r.titles), int(r.pts)])
				lv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_W"), tr("COL_GP_WINS"), tr("COL_PTS")], rows, s.team, 1, 2, true))
				lv.add_child(UI.wrap(tr("STL_POINTS_NOTE"), "MutedLabel", 15))
			if not ev.is_empty() and s.phase != "done":
				_tournament(s, ev, lv)
		"ties":
			lv.add_child(_eyebrow(tr("TABLE")))
			var rows2 := []
			for r in s.table():
				rows2.append([r.id, int(r.p), int(r.w), int(r.d), int(r.l), UI.signed(int(r.sd)), int(r.pts)])
			lv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_SD"), tr("COL_PTS")], rows2, s.team, 1))
		"zones":
			if String(ev.get("kind", "")) == "finals" or s.phase == "done":
				var fin: Dictionary = s.events[s.events.size() - 1] if String(s.events[s.events.size() - 1].kind) == "finals" else ev
				_tournament(s, fin, lv)
			var zone: Dictionary = s.events[0]
			lv.add_child(_eyebrow(tr(String(zone.name))))
			var rows3 := []
			for r in s.table_of(zone.stages[0]):
				rows3.append([r.id, int(r.p), int(r.w), int(r.l), UI.signed(int(r.sd)), int(r.pts)])
			lv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_L"), tr("COL_SD"), tr("COL_PTS")], rows3, s.team, 2))


## A tournament as it stands: its groups, then its knockouts.
func _tournament(s: Season, ev: Dictionary, lv: VBoxContainer) -> void:
	var name := Season.title(ev)
	if String(ev.get("arena", "")) != "":
		name += " · " + String(ev.arena)
	lv.add_child(_eyebrow(name))
	var gs: Dictionary = ev.stages[0]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	for gi in (gs.groups as Array).size():
		var gv := VBoxContainer.new()
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gv.add_child(UI.label(tr("GROUP_N").format({"g": "ABCD"[gi]}), "EyebrowLabel", 14, Game.C_MUTED))
		var rows := []
		for r in s.group_table(gs, gi):
			rows.append([r.id, int(r.w)])
		gv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_W")], rows, s.team, 2, 0, true))
		grid.add_child(gv)
	lv.add_child(grid)
	for si in range(1, (ev.stages as Array).size()):
		var st: Dictionary = ev.stages[si]
		lv.add_child(UI.label(tr(String(st.key)), "EyebrowLabel", 14, Game.C_MUTED))
		for f in st.rounds[0]:
			lv.add_child(UI.fixture_line(self, f, s.team))


func _next(s: Season, rv: VBoxContainer) -> void:
	var f := s.next_fixture()
	if f.is_empty():
		return
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	cv.add_child(_eyebrow(tr("NEXT_MATCH") + " · " + s.match_stage()))
	cv.add_child(UI.fixture_line(self, f, s.team))
	var venue := s.next_venue()
	var where := String(s.event().get("arena", ""))
	cv.add_child(UI.wrap(where if where != "" else tr(DB.venue(venue)[1]), "MutedLabel", 17))
	if bool(f.get("tie", false)):
		cv.add_child(UI.wrap(tr("TIE_TWO_REGUS"), "MutedLabel", 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.button(tr("PLAY"), true, func():
		var cfg := {"home": f.home, "away": f.away, "venue": venue, "event": "regu", "sets": 3, "points": 15,
			"difficulty": int(Game.settings.difficulty), "mode": "season", "user_team": 0 if f.home == s.team else 1,
			"women": s.women, "stage": s.match_stage()}
		if bool(f.get("tie", false)):
			cfg.tie = {"results": [], "used": [[], []], "regus": 2, "play_all": true, "set_scores": []}
		Game.start_match(cfg)))
	row.add_child(UI.button(tr("SIM_MATCH"), false, func():
		s.sim_round()
		Game.save_season()
		Game.show_screen("res://ui/season_hub.gd")))
	cv.add_child(row)
	rv.add_child(card)


## The latest: the last round's results, and the last Grand Prix's (or region's) outcome.
func _latest(s: Season, rv: VBoxContainer) -> void:
	var last := s.last_event()
	if not last.is_empty() and String(last.kind) in ["gp", "div1"]:
		var card := UI.card()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		cv.add_child(_eyebrow(Season.title(last)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Icon.make("trophy", 28, Game.C_GOLD))
		h.add_child(Crest.make(String(last.champion), 30))
		var nm := UI.fit(UI.label(DB.team_name(String(last.champion)), "SubLabel", 20, Game.C_GOLD))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		cv.add_child(h)
		var mine := String((last.place as Dictionary).get(s.team, ""))
		if mine != "":
			var pts := " (+%d)" % int(DB.GP_POINTS[mine]) if String(last.kind) == "gp" else ""
			cv.add_child(UI.wrap(tr("YOUR_FINISH").format({"p": tr("FINISH_" + mine.to_upper())}) + pts, "", 18))
		rv.add_child(card)
	if s.recent.is_empty():
		return
	var rc := UI.card()
	var rl := VBoxContainer.new()
	rl.add_theme_constant_override("separation", 6)
	rc.add_child(rl)
	rl.add_child(_eyebrow(tr("LAST_ROUND")))
	for f in s.recent:
		rl.add_child(UI.fixture_line(self, f, s.team))
	rv.add_child(rc)


func _done(s: Season, side: VBoxContainer, right: HBoxContainer) -> void:
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	cv.add_child(_eyebrow(tr("CHAMPIONS"), Game.C_GOLD))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(Crest.make(s.champion, 56))
	var champ := UI.fit(UI.label(DB.team_name(s.champion), "HeaderLabel", 40, Game.C_GOLD if s.champion == s.team else Game.C_INK), 2)
	champ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(champ)
	cv.add_child(h)
	if s.format() == "gp":
		if s.division == 1 and s.relegated.size() == 2:
			var down := tr("RELEGATED_N").format({"a": DB.team_name(s.relegated[0]), "b": DB.team_name(s.relegated[1])})
			cv.add_child(UI.wrap(down, "", 18))
		if s.promoted.size() == 2:
			cv.add_child(UI.wrap(tr("PROMOTED_N").format({"a": DB.team_name(s.promoted[0]), "b": DB.team_name(s.promoted[1])}), "", 18))
		if s.team in s.relegated:
			cv.add_child(UI.wrap(tr("YOU_RELEGATED"), "SubLabel", 20))
		elif s.division == 2 and not (s.team in s.promoted):
			cv.add_child(UI.wrap(tr("YOU_STAY_DIV1"), "SubLabel", 20))
	for a in s.awards():
		var ps: Dictionary = a[1]
		var line := UI.fit(UI.label("%s: %s (%s) · %d" % [tr(a[0]), String(ps.get("name", "")), DB.team_name(String(ps.get("team", ""))), int(ps.get(a[2], 0))], "", 18), 2)
		cv.add_child(line)
	side.add_child(card)
	right.add_child(UI.button(tr("NEXT_SEASON"), true, func():
		Game.season = s.next_season()
		Game.save_season()
		Game.show_screen("res://ui/season_hub.gd")))
	right.add_child(UI.button(tr("NEW_SEASON"), false, func():
		Game.delete_season()
		Game.show_screen("res://ui/season_hub.gd")))


func _eyebrow(text: String, col := Game.C_SAFFRON) -> Label:
	var l := UI.label(text.to_upper(), "EyebrowLabel", 16, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _confirm_abandon() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = tr("ABANDON_SEASON_Q")
	dlg.ok_button_text = tr("YES")
	dlg.cancel_button_text = tr("NO")
	dlg.confirmed.connect(func():
		Game.delete_season()
		Game.show_screen("res://ui/season_hub.gd"))
	add_child(dlg)
	dlg.popup_centered()
