extends Control
## League Season: pick a franchise, run the auction, play the league and the playoffs.

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
			_season_done()
		_:
			_hub()


func _reload() -> void:
	Game.show_screen("res://ui/season_hub.gd")


func _pick_team() -> void:
	var v := UI.page(self, tr("SEASON_PICK"), func(): Game.goto_menu(), tr("MENU_SEASON"))
	v.add_child(UI.team_grid(self, DB.league_ids, 4, func(id):
		Game.new_season(id)
		_reload()))


func _team_header(v: VBoxContainer) -> void:
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
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	row.add_child(Crest.make(season.team, 64))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -4)
	col.add_child(UI.label(String(t.name), "HeaderLabel", 38))
	col.add_child(UI.label("%s %d · %s" % [tr("RATING"), season.rating(season.team), tr(String(t.state))], "MutedLabel", 17))
	row.add_child(col)
	v.add_child(p)


func _auction_gate() -> void:
	var v := UI.page(self, tr("SEASON").format({"n": season.year}), func(): Game.goto_menu(), tr("MENU_SEASON"))
	_team_header(v)
	v.add_child(UI.wrap(tr("SEASON_AUCTION_INTRO"), "", 22))
	var go := UI.button(tr("ENTER_AUCTION_OWNER"), true, func(): Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"}))
	go.custom_minimum_size = Vector2(420, 76)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var reset := UI.button(tr("SEASON_NEW_TEAM"), false, func():
		Game.delete_season()
		_reload())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(reset)


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
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_team_header(left)
	var next = season.next_user_fixture()
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	if next != null:
		cv.add_child(UI.label(_stage_label(next).to_upper(), "EyebrowLabel"))
		cv.add_child(UI.fixture_line(self, next, season.team))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var play := UI.button(tr("PLAY_MATCH"), true, func(): Game.start_match(season.match_config(next)))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(play)
		row.add_child(UI.button(tr("SIM_MATCH"), false, func():
			season.simulate_user_match()
			Game.save_season()
			_reload()))
		cv.add_child(row)
	else:
		cv.add_child(UI.label(tr("ELIMINATED"), "HeaderLabel", 36, Game.C_MAGENTA))
		cv.add_child(UI.button(tr("SIM_MATCH"), true, func():
			season._advance()
			Game.save_season()
			_reload()))
	left.add_child(card)
	if season.phase == "playoffs":
		left.add_child(UI.label(tr("PLAYOFFS").to_upper(), "EyebrowLabel"))
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
	left.add_child(UI.label(tr("PLAYOFF_NOTE"), "MutedLabel", 16))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label(tr("TABLE").to_upper(), "EyebrowLabel"))
	right.add_child(UI.scroll(UI.table(self, season.standings(), season.team)))
	cols.add_child(right)


func _season_done() -> void:
	if season.champion == season.team and not bool(Game.settings.get("trophy_seen_%d" % season.year, false)):
		Game.settings["trophy_seen_%d" % season.year] = true
		Game.save_settings()
		Game.show_screen("res://ui/trophy_screen.gd", {"team": season.team, "title": tr("LEAGUE_NAME"), "back": "res://ui/season_hub.gd"})
		return
	var award_args := {"awards": season.awards, "label": tr("SEASON").format({"n": season.year}), "back": "res://ui/season_hub.gd", "mine": season.team}
	if not season.awards.is_empty() and not bool(Game.settings.get("awards_seen_%d" % season.year, false)):
		Game.settings["awards_seen_%d" % season.year] = true
		Game.save_settings()
		Game.show_screen("res://ui/awards_screen.gd", award_args)
		return
	var v := UI.page(self, tr("SEASON_OVER"), func(): Game.goto_menu(), tr("SEASON").format({"n": season.year}))
	var champ: String = season.champion
	v.add_child(UI.label(tr("CHAMPIONS") if champ == season.team else tr("TEAM_WINS").format({"team": DB.team_name(champ)}), "TitleLabel", 72, Game.C_GOLD if champ == season.team else Game.C_INK))
	if champ == season.team:
		v.add_child(UI.button(tr("SEE_TROPHY"), false, func(): Game.show_screen("res://ui/trophy_screen.gd", {"team": season.team, "title": tr("LEAGUE_NAME"), "back": "res://ui/season_hub.gd"})))
	var mvp: Dictionary = season.awards.get("mvp", {})
	if not mvp.is_empty():
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 14)
		arow.add_child(UI.label(tr("AWARDS_LINE").format({"name": mvp.name, "team": DB.team_name(String(mvp.team))}), "SubLabel", 22, Game.C_GOLD))
		arow.add_child(UI.button(tr("SEE_AWARDS"), false, func(): Game.show_screen("res://ui/awards_screen.gd", award_args)))
		v.add_child(arow)
	v.add_child(UI.scroll(UI.table(self, season.standings(), season.team)))
	var go := UI.button(tr("NEXT_SEASON"), true, func():
		season.next_year()
		Game.save_season()
		_reload())
	go.custom_minimum_size = Vector2(360, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
