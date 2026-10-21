extends Control
## The Club Season: pick your club; then your next match (play it or let it be played), the table with the top four
## marked for the finals, the round's results, the semi-finals and the grand final; at the end the champions.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var league = Game.get_league()
	if league == null:
		_pick()
	else:
		_hub(league)


func _pick() -> void:
	var v := UI.page(self, tr("MENU_LEAGUE"), func(): Game.goto_menu(), tr("LEAGUE_PICK"))
	v.add_child(UI.wrap(tr("LEAGUE_ABOUT"), "MutedLabel", 18))
	var box := VBoxContainer.new()
	v.add_child(UI.scroll(box))
	var ids: Array = DB.club_ids()
	box.add_child(UI.team_grid(self, ids, 4, func(id):
		Game.new_league(id)
		Game.show_screen("res://ui/league_screen.gd")))


func _hub(league) -> void:
	var v := UI.page(self, tr("MENU_LEAGUE"), func(): Game.goto_menu(), _stage_title(league))
	var right: HBoxContainer = get_meta("header_right")
	right.add_child(UI.button(tr("LEAGUE_NEW"), false, func():
		Game.delete_league()
		Game.show_screen("res://ui/league_screen.gd")))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	if league.stage == "done":
		body.add_child(_champions(league))
	else:
		var nm: Dictionary = league.next_user_match()
		var card := UI.card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		if nm.is_empty():
			var out := UI.wrap(tr("LEAGUE_OUT"), "SubLabel", 22)
			out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(out)
			h.add_child(UI.button(tr("CUP_PLAY_ON"), true, func():
				league.advance()
				Game.save_league()
				Game.show_screen("res://ui/league_screen.gd")))
		else:
			h.add_child(UI.badge(nm.home, Vector2(48, 40)))
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_child(UI.label(_stage_name(nm).to_upper(), "EyebrowLabel", 14, Game.C_ACCENT))
			mid.add_child(UI.fit(UI.label("%s %s %s" % [DB.team_name(nm.home), tr("VS"), DB.team_name(nm.away)], "SubLabel", 24), 2))
			h.add_child(mid)
			h.add_child(UI.badge(nm.away, Vector2(48, 40)))
			var bv := VBoxContainer.new()
			bv.add_child(UI.button(tr("PLAY"), true, func(): _play(league, nm)))
			bv.add_child(UI.button(tr("SIMULATE"), false, func():
				league.sim_next()
				Game.save_league()
				Game.show_screen("res://ui/league_screen.gd")))
			h.add_child(bv)
		body.add_child(card)
	if not league.finals.is_empty():
		var kc := UI.card()
		var kv := VBoxContainer.new()
		kv.add_theme_constant_override("separation", 8)
		kc.add_child(kv)
		kv.add_child(UI.label(tr("KNOCKOUT"), "SubLabel", 22))
		for k in league.finals:
			kv.add_child(_fixture(k, league.user, tr("STAGE_" + String(k.stage).to_upper())))
		body.add_child(kc)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	body.add_child(cols)
	# The table: the top four (gold) go to the finals.
	var tc := UI.card()
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.size_flags_stretch_ratio = 1.2
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	tc.add_child(tv)
	tv.add_child(UI.label(tr("LEAGUE_TABLE"), "SubLabel", 22))
	var rows := []
	for r in league.table():
		rows.append([r.id, int(r.p), int(r.w), int(r.d), int(r.l), "%d" % roundi(float(r.pct)), int(r.pts)])
	tv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_PCT"), tr("COL_PTS")], rows, league.user, 4, 0, true))
	tv.add_child(UI.wrap(tr("LEAGUE_TOP_FOUR"), "MutedLabel", 15))
	cols.add_child(tc)
	# The last round's results.
	var last := mini(int(league.round), League.ROUNDS) - 1
	if last >= 0:
		var rc := UI.card()
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 8)
		rc.add_child(rv)
		rv.add_child(UI.label(tr("ROUND_N").format({"n": last + 1}), "SubLabel", 22))
		for f in league.fixtures:
			if int(f.round) == last and f.played:
				rv.add_child(_fixture(f, league.user, ""))
		cols.add_child(rc)


func _stage_title(league) -> String:
	if league.stage == "season":
		return tr("ROUND_N_OF").format({"n": int(league.round) + 1, "of": League.ROUNDS})
	if league.stage == "final":
		return tr("STAGE_GRAND_FINAL")
	return tr("STAGE_" + String(league.stage).to_upper())


func _stage_name(nm: Dictionary) -> String:
	var s := String(nm.stage)
	if s == "ROUND_N":
		return tr("ROUND_N").format({"n": int(nm.get("n", 1))})
	return tr("STAGE_" + s)


func _fixture(f: Dictionary, user: String, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var mine: bool = f.home == user or f.away == user
	var col := Game.C_INK if mine else Game.C_MUTED
	if label != "":
		var l := UI.label(label, "EyebrowLabel", 13)
		l.custom_minimum_size = Vector2(150, 0)
		UI.fit(l, 2)
		h.add_child(l)
	h.add_child(UI.badge(f.home, Vector2(30, 24)))
	var a := UI.fit(UI.label(DB.team_name(f.home), "", 17, col), 2)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.custom_minimum_size = Vector2(80, 0)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	var mid := UI.label("%d – %d" % [f.score[0], f.score[1]] if f.played else tr("VS"), "SubLabel", 18, Game.C_ACCENT if mine else Game.C_INK)
	mid.custom_minimum_size = Vector2(76, 0)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mid)
	var b := UI.fit(UI.label(DB.team_name(f.away), "", 17, col), 2)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(80, 0)
	h.add_child(b)
	h.add_child(UI.badge(f.away, Vector2(30, 24)))
	return h


func _champions(league) -> Control:
	var card := UI.card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var won: bool = league.champion == league.user
	v.add_child(UI.label(tr("LEAGUE_WON") if won else tr("LEAGUE_OVER"), "TitleLabel", 52, Game.C_GOLD if won else Game.C_INK))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(Icon.make("star", 26, Game.C_GOLD))
	h.add_child(UI.badge(league.champion, Vector2(40, 34)))
	h.add_child(UI.label(tr("LEAGUE_CHAMPIONS").format({"team": DB.team_name(league.champion)}), "SubLabel", 22, Game.C_GOLD))
	v.add_child(h)
	return card


func _play(league, nm: Dictionary) -> void:
	# Clubs play in their own halls; the grand final fills the arena.
	var venue := "arena" if String(nm.stage) == "GRAND_FINAL" else "hall"
	Game.start_match({"home": nm.home, "away": nm.away, "venue": venue, "quarter": Game.quarter_minutes(),
		"difficulty": int(Game.settings.difficulty), "mode": "league", "user_team": 0 if nm.home == league.user else 1,
		"stage": _stage_name(nm), "need_winner": bool(nm.need_winner), "double_zone": false})
