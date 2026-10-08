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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for id in DB.league_ids:
		var t := DB.team(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 86)
		b.pressed.connect(func():
			Sfx.click()
			Game.new_season(id)
			_reload())
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -12
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stripes := VBoxContainer.new()
		stripes.add_theme_constant_override("separation", 0)
		stripes.alignment = BoxContainer.ALIGNMENT_CENTER
		stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripes.add_child(UI.swatch(t.c1, Vector2(30, 26)))
		stripes.add_child(UI.swatch(t.c2, Vector2(30, 10)))
		h.add_child(stripes)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UI.label(String(t.name), "SubLabel", 21)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rt := UI.label("%s %d · %s" % [tr("RATING"), DB.team_rating(t.squad), tr(t.state)], "MutedLabel", 16)
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		col.add_child(rt)
		h.add_child(col)
		b.add_child(h)
		grid.add_child(b)
	v.add_child(UI.scroll(grid))


func _team_header(v: VBoxContainer) -> void:
	var t := DB.team(season.team)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.swatch(t.c1, Vector2(10, 34)))
	row.add_child(UI.label("%s · %s %d" % [t.name, tr("RATING"), season.rating(season.team)], "SubLabel", 24))
	v.add_child(row)


func _auction_gate() -> void:
	var v := UI.page(self, tr("SEASON").format({"n": season.year}), func(): Game.goto_menu(), tr("MENU_SEASON"))
	_team_header(v)
	v.add_child(UI.wrap(tr("SEASON_AUCTION_INTRO"), "", 22))
	var go := UI.button(tr("ENTER_AUCTION_OWNER"), true, func(): Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"}))
	go.custom_minimum_size = Vector2(380, 70)
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
