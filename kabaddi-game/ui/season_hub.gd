extends Control
## League Season: pick a franchise, keep your retentions, run the auction, then play the league and the playoffs.
## The front page and the news ticker follow the season; breaking news stops you until you have seen it.

var season


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	season = Game.get_season()
	if season == null:
		_pick_team()
		return
	match String(season.phase):
		"auction":
			_auction_gate()
		"done":
			if _season_done():
				return
		_:
			_hub()
	_breaking()


func _reload() -> void:
	Game.show_screen("res://ui/season_hub.gd")


## Breaking news the player has not seen yet, over the screen.
func _breaking() -> void:
	var fresh: Array = News.unseen_breaking(season.news, season.news_seen)
	season.news_seen = News.last_id(season.news)
	Game.save_season()
	if not fresh.is_empty():
		NewsTicker.breaking(self, fresh, func(): pass)


func _pick_team() -> void:
	var v := UI.page(self, tr("SEASON_PICK"), func(): Game.goto_menu(), tr("MENU_SEASON"))
	v.add_child(UI.team_grid(self, DB.league_ids, 4, func(id):
		Game.new_season(id)
		_reload()))


func _team_header(v: Control, compact := false) -> void:
	var t := DB.team(season.team)
	var c1: Color = t.c1
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c1.darkened(0.7).lerp(Game.C_PANEL, 0.3), 0.95)
	sb.set_corner_radius_all(18)
	sb.border_color = c1
	sb.border_width_left = 6
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	row.add_child(Crest.make(season.team, 52 if compact else 64))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(t.name), "HeaderLabel", 32 if compact else 38)
	UI.fit(nm)
	col.add_child(nm)
	col.add_child(UI.label("%s %d · %s" % [tr("RATING"), season.rating(season.team), tr(String(t.state))], "MutedLabel", 17))
	row.add_child(col)
	if not season.goal.is_empty():
		row.add_child(_goal_box())
	v.add_child(p)


## The board's goal and how it looks.
func _goal_box() -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.add_child(UI.label(tr("BOARD_GOAL").to_upper(), "EyebrowLabel", 13, Game.C_GOLD))
	var g := UI.label(tr(String(season.goal.key)), "SubLabel", 17)
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.custom_minimum_size = Vector2(170, 0)
	col.add_child(g)
	var st: String = season.goal_status()
	if st != "":
		var good: bool = st in ["GOAL_STATUS_ON", "GOAL_STATUS_MET"]
		col.add_child(UI.pill(tr(st).to_upper(), Game.C_GOOD if good else Game.C_MAGENTA))
	return col


func _front_page(v: Control, small := false) -> void:
	var top: Dictionary = News.top_story(season.news)
	if not top.is_empty():
		v.add_child(NewsTicker.front_page(top, small))


func _ticker(v: Control) -> void:
	if not season.news.is_empty():
		v.add_child(NewsTicker.make(News.latest(season.news, 14)))


func _auction_gate() -> void:
	var v := UI.page(self, tr("SEASON").format({"n": season.year}), func(): Game.goto_menu(), tr("MENU_SEASON"))
	_header_buttons()
	_front_page(v)
	_team_header(v)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(col)
	col.add_child(UI.wrap(tr("SEASON_RETAIN_INTRO"), "", 21))
	if not is_zero_approx(season.purse_bonus):
		var plus: bool = season.purse_bonus > 0.0
		col.add_child(UI.label(tr("BOARD_BUDGET_UP" if plus else "BOARD_BUDGET_DOWN").format({"price": Game.fmt_money(absf(season.purse_bonus))}),
			"SubLabel", 19, Game.C_GOOD if plus else Game.C_MAGENTA))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	if not season.retain_done:
		var go := UI.button(tr("CHOOSE_RETENTIONS"), true, func(): Game.show_screen("res://ui/retention_screen.gd"))
		go.custom_minimum_size = Vector2(420, 76)
		row.add_child(go)
	else:
		var go := UI.button(tr("WAR_ROOM"), true, func(): Game.show_screen("res://ui/war_room.gd"))
		go.custom_minimum_size = Vector2(360, 76)
		row.add_child(go)
		row.add_child(UI.button(tr("CHANGE_RETENTIONS"), false, func(): Game.show_screen("res://ui/retention_screen.gd")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var reset := UI.button(tr("SEASON_NEW_TEAM"), false, func():
		Game.delete_season()
		_reload())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(reset)
	_ticker(v)


func _header_buttons() -> void:
	var head: HBoxContainer = get_meta("header_right")
	if not season.history.is_empty() or not season.records.is_empty():
		var hof := UI.button(tr("HALL_OF_FAME"), false, func(): Game.show_screen("res://ui/hall_of_fame.gd"))
		hof.custom_minimum_size = Vector2(0, 54)
		head.add_child(hof)


func _stage_label(f: Dictionary) -> String:
	match String(f.stage):
		"eliminator":
			return tr("ELIMINATOR")
		"semi":
			return tr("SEMI_FINAL")
		"final":
			return tr("FINAL")
	return tr("MATCHDAY").format({"n": f.round})


func _hub() -> void:
	var eyebrow := tr("PLAYOFFS") if season.phase == "playoffs" else tr("LEAGUE_NAME")
	var v := UI.page(self, tr("SEASON").format({"n": season.year}), func(): Game.goto_menu(), eyebrow)
	_header_buttons()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	_front_page(left, true)
	_team_header(left, true)
	var next = season.next_user_fixture()
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	if next != null:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.add_child(UI.label(_stage_label(next).to_upper(), "EyebrowLabel"))
		var opp: String = next.away if next.home == season.team else next.home
		var derby: String = season.derby_of(season.team, opp)
		if derby != "":
			top.add_child(UI.pill(tr(derby).to_upper(), Game.C_MAGENTA, true))
		cv.add_child(top)
		cv.add_child(UI.fixture_line(self, next, season.team))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var play := UI.button(tr("MATCH_DAY"), true, func(): Game.show_screen("res://ui/match_day.gd"))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(play)
		row.add_child(UI.button(tr("SIM_MATCH"), false, func():
			season.simulate_user_match()
			Game.save_season()
			_reload()))
		cv.add_child(row)
	else:
		cv.add_child(UI.label(tr("ELIMINATED"), "HeaderLabel", 34, Game.C_MAGENTA))
		cv.add_child(UI.button(tr("SIM_MATCH"), true, func():
			season._advance()
			Game.save_season()
			_reload()))
	left.add_child(card)
	if season.phase == "playoffs":
		for f in season.fixtures:
			if f.stage != "league":
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 10)
				var tag := UI.label(_stage_label(f), "MutedLabel", 16)
				tag.custom_minimum_size = Vector2(130, 0)
				line.add_child(tag)
				var fl := UI.fixture_line(self, f, season.team)
				fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(fl)
				left.add_child(line)
	else:
		left.add_child(UI.wrap(tr("PLAYOFF_NOTE"), "MutedLabel", 15))
	cols.add_child(UI.scroll(left))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not season.week.is_empty():
		right.add_child(_week_card())
	right.add_child(UI.label(tr("TABLE").to_upper(), "EyebrowLabel"))
	right.add_child(UI.scroll(UI.table(self, season.standings(), season.team)))
	cols.add_child(right)
	_ticker(v)


## The last league round's awards: raider, defender and team of the week.
func _week_card() -> PanelContainer:
	var w: Dictionary = season.week
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.92)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(Game.C_GOLD, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	v.add_child(UI.label(tr("WEEK_AWARDS").format({"n": int(w.get("round", 0))}).to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var r: Dictionary = w.get("raider", {})
	if not r.is_empty():
		v.add_child(_week_line(tr("RAIDER_OF_WEEK"), String(r.name), String(r.team), "%d %s" % [int(r.raid), tr("STAT_RAID_PTS")]))
	var d: Dictionary = w.get("defender", {})
	if not d.is_empty():
		v.add_child(_week_line(tr("DEFENDER_OF_WEEK"), String(d.name), String(d.team), "%d %s" % [int(d.tackle), tr("STAT_TACKLE_PTS")]))
	var t: Dictionary = w.get("team", {})
	if not t.is_empty():
		v.add_child(_week_line(tr("TEAM_OF_WEEK"), DB.team_name(String(t.team)), String(t.team), "%s %s %s" % [String(t.score), tr("VS"), String(t.team2)]))
	return card


func _week_line(title: String, who: String, team_id: String, what: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var tl := UI.label(title, "MutedLabel", 14)
	tl.custom_minimum_size = Vector2(150, 0)
	UI.fit(tl)
	h.add_child(tl)
	h.add_child(Crest.make(team_id, 22))
	var nm := UI.label(who, "SubLabel" if team_id != season.team else "SubLabel", 17, Game.C_SAFFRON if team_id == season.team else Game.C_INK)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.fit(nm)
	h.add_child(nm)
	h.add_child(UI.label(what, "MutedLabel", 14))
	return h


## The season is over. The trophy and the awards come first, once each; returns true if one of them was shown.
func _season_done() -> bool:
	if season.champion == season.team and not bool(Game.settings.get("trophy_seen_%d" % season.year, false)):
		Game.settings["trophy_seen_%d" % season.year] = true
		Game.save_settings()
		Game.show_screen("res://ui/trophy_screen.gd", {"team": season.team, "title": tr("LEAGUE_NAME"), "back": "res://ui/season_hub.gd"})
		return true
	var award_args := {"awards": season.awards, "label": tr("SEASON").format({"n": season.year}), "back": "res://ui/season_hub.gd", "mine": season.team}
	if not season.awards.is_empty() and not bool(Game.settings.get("awards_seen_%d" % season.year, false)):
		Game.settings["awards_seen_%d" % season.year] = true
		Game.save_settings()
		Game.show_screen("res://ui/awards_screen.gd", award_args)
		return true
	var v := UI.page(self, tr("SEASON_OVER"), func(): Game.goto_menu(), tr("SEASON").format({"n": season.year}))
	_header_buttons()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var champ: String = season.champion
	var cl := UI.label(tr("CHAMPIONS") if champ == season.team else tr("TEAM_WINS").format({"team": DB.team_name(champ)}), "TitleLabel", 64, Game.C_GOLD if champ == season.team else Game.C_INK)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(cl)
	if champ == season.team:
		left.add_child(UI.button(tr("SEE_TROPHY"), false, func(): Game.show_screen("res://ui/trophy_screen.gd", {"team": season.team, "title": tr("LEAGUE_NAME"), "back": "res://ui/season_hub.gd"})))
	var mvp: Dictionary = season.awards.get("mvp", {})
	if not mvp.is_empty():
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 14)
		var al := UI.label(tr("AWARDS_LINE").format({"name": mvp.name, "team": DB.team_name(String(mvp.team))}), "SubLabel", 20, Game.C_GOLD)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(al)
		arow.add_child(UI.button(tr("SEE_AWARDS"), false, func(): Game.show_screen("res://ui/awards_screen.gd", award_args)))
		left.add_child(arow)
	# The board's verdict.
	if not season.goal.is_empty():
		var met: bool = season.goal_met()
		var card := UI.card()
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 4)
		card.add_child(gv)
		gv.add_child(UI.label(tr("BOARD_VERDICT").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
		gv.add_child(UI.label(tr("BOARD_GOAL_WAS").format({"goal": tr(String(season.goal.key))}), "SubLabel", 19))
		var verdict := tr("BOARD_MET" if met else "BOARD_MISSED").format({"price": Game.fmt_money(absf(season.purse_bonus))})
		var vl := UI.label(verdict, "HeaderLabel", 28, Game.C_GOOD if met else Game.C_MAGENTA)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gv.add_child(vl)
		left.add_child(card)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	var go := UI.button(tr("NEXT_SEASON"), true, func():
		season.next_year()
		Game.save_season()
		_reload())
	go.custom_minimum_size = Vector2(360, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(go)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label(tr("TABLE").to_upper(), "EyebrowLabel"))
	right.add_child(UI.scroll(UI.table(self, season.standings(), season.team)))
	cols.add_child(right)
	_ticker(v)
	return false
