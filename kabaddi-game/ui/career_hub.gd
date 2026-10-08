extends Control
## Career home: your player, training, next fixture, and the league table.

var career


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	career = Game.get_career()
	if career == null:
		_no_career()
		return
	match String(career.phase):
		"auction":
			_auction_gate()
		"over":
			_season_over()
		_:
			_season()


func _reload() -> void:
	Game.show_screen("res://ui/career_hub.gd")


func _no_career() -> void:
	var v := UI.page(self, tr("MENU_CAREER"), func(): Game.goto_menu())
	v.add_child(UI.wrap(tr("MENU_CAREER_DESC"), "SubLabel", 26))
	var b := UI.button(tr("CAREER_NEW"), true, func(): Game.show_screen("res://ui/create_player.gd"))
	b.custom_minimum_size = Vector2(360, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)


func _player_card(with_training: bool) -> PanelContainer:
	var card := UI.card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var p: Dictionary = career.player
	var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}[p.role]
	var home_state := tr(String(career.profile.get("state", "STATE_HARYANA")))
	v.add_child(UI.label(("%s · %s" % [tr(role_key), home_state]).to_upper(), "EyebrowLabel"))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 16)
	name_row.add_child(UI.label(String(p.name), "HeaderLabel", 44))
	var ovr := UI.label(str(career.overall()), "TitleLabel", 60, Game.C_SAFFRON)
	name_row.add_child(ovr)
	v.add_child(name_row)
	if career.team != "":
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 10)
		trow.add_child(UI.swatch(DB.team(career.team).c1, Vector2(8, 26)))
		trow.add_child(UI.label("%s · %s %s" % [DB.team_name(career.team), tr("CONTRACT"), Game.fmt_money(career.price)], "", 20))
		v.add_child(trow)
	var keys := {"speed": "ATTR_SPEED", "agility": "ATTR_AGILITY", "strength": "ATTR_STRENGTH", "reach": "ATTR_REACH", "tackle": "ATTR_TACKLE", "stamina": "ATTR_STAMINA"}
	if with_training:
		v.add_child(UI.label(tr("SKILL_POINTS").format({"n": career.skill_points}), "SubLabel", 20, Game.C_GOLD if career.skill_points > 0 else Game.C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 4 if with_training else 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	for k in DB.ATTRS:
		var key: String = k
		grid.add_child(UI.label(tr(keys[key]), "MutedLabel", 18))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 12)
		bar.max_value = 99
		bar.value = int(p.attrs[key])
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		grid.add_child(UI.label(str(int(p.attrs[key])), "SubLabel", 18))
		if with_training:
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(44, 40)
			plus.disabled = career.skill_points <= 0
			plus.pressed.connect(func():
				if career.train(key):
					Sfx.click()
					Game.save_career()
					_reload())
			grid.add_child(plus)
	v.add_child(grid)
	# Raiding moves: the signature is starred, and each can be practised.
	v.add_child(UI.label(DB.moves_line(p), "EyebrowLabel", 15, Game.C_GOLD))
	var mg := GridContainer.new()
	mg.columns = 4 if with_training else 3
	mg.add_theme_constant_override("h_separation", 14)
	mg.add_theme_constant_override("v_separation", 4)
	var mv_ratings := DB.moves(p)
	var sig := DB.signature(p)
	for mv in DB.MOVES:
		var mkey: String = mv
		mg.add_child(UI.label(("★ " if mkey == sig else "") + tr(DB.MOVE_KEYS[mkey]), "MutedLabel", 18))
		var mbar := ProgressBar.new()
		mbar.custom_minimum_size = Vector2(150, 12)
		mbar.max_value = 99
		mbar.value = int(mv_ratings[mkey])
		mbar.show_percentage = false
		mbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mg.add_child(mbar)
		mg.add_child(UI.label(str(int(mv_ratings[mkey])), "SubLabel", 18))
		if with_training:
			var mplus := Button.new()
			mplus.text = "+"
			mplus.custom_minimum_size = Vector2(44, 40)
			mplus.disabled = career.skill_points <= 0
			mplus.pressed.connect(func():
				if career.train("move:" + mkey):
					Sfx.click()
					Game.save_career()
					_reload())
			mg.add_child(mplus)
	v.add_child(mg)
	# Defensive skills, the same way.
	var dg := GridContainer.new()
	dg.columns = 4 if with_training else 3
	dg.add_theme_constant_override("h_separation", 14)
	dg.add_theme_constant_override("v_separation", 4)
	var d_ratings := DB.def_moves(p)
	var dsig := DB.def_signature(p)
	for dm in DB.STYLES:
		var dkey: String = dm
		dg.add_child(UI.label(("★ " if dkey == dsig else "") + tr(DB.STYLE_KEYS[dkey]), "MutedLabel", 18))
		var dbar := ProgressBar.new()
		dbar.custom_minimum_size = Vector2(150, 12)
		dbar.max_value = 99
		dbar.value = int(d_ratings[dkey])
		dbar.show_percentage = false
		dbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dg.add_child(dbar)
		dg.add_child(UI.label(str(int(d_ratings[dkey])), "SubLabel", 18))
		if with_training:
			var dplus := Button.new()
			dplus.text = "+"
			dplus.custom_minimum_size = Vector2(44, 40)
			dplus.disabled = career.skill_points <= 0
			dplus.pressed.connect(func():
				if career.train("dmove:" + dkey):
					Sfx.click()
					Game.save_career()
					_reload())
			dg.add_child(dplus)
	v.add_child(UI.label(tr("DEF_SKILLS").to_upper(), "EyebrowLabel", 15, Game.C_MAGENTA.lightened(0.3)))
	v.add_child(dg)
	return card


func _auction_gate() -> void:
	var v := UI.page(self, tr("SEASON").format({"n": career.season}), func(): Game.goto_menu(), tr("MENU_CAREER"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.add_child(_player_card(false))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label(tr("AUCTION_SEASON").format({"n": career.season}), "HeaderLabel"))
	right.add_child(UI.label("%s · %s %s" % [tr("CATEGORY").format({"c": career.category()}), tr("BASE_PRICE"), Game.fmt_money(Career.CATEGORIES[career.category()])], "MutedLabel", 20))
	var go := UI.button(tr("ENTER_AUCTION"), true, func(): Game.show_screen("res://ui/auction_screen.gd"))
	go.custom_minimum_size = Vector2(360, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(go)
	row.add_child(right)
	v.add_child(row)
	_footer(v)


func _season() -> void:
	var eyebrow := tr("PLAYOFFS") if career.phase == "playoffs" else tr("LEAGUE_NAME")
	var v := UI.page(self, tr("SEASON").format({"n": career.season}), func(): Game.goto_menu(), eyebrow)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(500, 0)
	left.add_child(_player_card(true))
	var ss: Dictionary = career.season_stats
	left.add_child(UI.label("%s · %s %d · %s %d · %s %d" % [tr("YOUR_SEASON"), tr("MATCHES"), ss.matches, tr("STAT_RAID_PTS"), ss.raid, tr("STAT_TACKLE_PTS"), ss.tackle], "MutedLabel", 18))
	cols.add_child(UI.scroll(left))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var next = career.next_user_fixture()
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	if next != null:
		var stage_key: String = {"league": "", "semi": "SEMI_FINAL", "final": "FINAL"}[String(next.stage)]
		var eb := tr("MATCHDAY").format({"n": next.round}) if stage_key == "" else tr(stage_key)
		cv.add_child(UI.label(eb.to_upper(), "EyebrowLabel"))
		cv.add_child(UI.fixture_line(self, next, career.team))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var play := UI.button(tr("PLAY_MATCH"), true, func(): Game.start_match(career.match_config(next)))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sim := UI.button(tr("SIM_MATCH"), false, func():
			career.simulate_user_match()
			Game.save_career()
			_reload())
		row.add_child(play)
		row.add_child(sim)
		cv.add_child(row)
	else:
		cv.add_child(UI.label(tr("MISSED_PLAYOFFS"), "SubLabel", 24, Game.C_MAGENTA))
		cv.add_child(UI.button(tr("CONTINUE"), true, func():
			career._advance()
			Game.save_career()
			_reload()))
	right.add_child(card)
	if career.phase == "playoffs":
		var po := VBoxContainer.new()
		po.add_theme_constant_override("separation", 6)
		for f in career.fixtures:
			if f.stage != "league":
				po.add_child(UI.fixture_line(self, f, career.team))
		right.add_child(po)
	right.add_child(UI.label(tr("TABLE").to_upper(), "EyebrowLabel"))
	right.add_child(UI.scroll(UI.table(self, career.standings(), career.team)))


func _season_over() -> void:
	var award_args := {"awards": career.awards, "label": tr("SEASON").format({"n": career.season}), "back": "res://ui/career_hub.gd", "mine": "CAREER"}
	if not career.awards.is_empty() and not bool(Game.settings.get("career_awards_seen_%d" % career.season, false)):
		Game.settings["career_awards_seen_%d" % career.season] = true
		Game.save_settings()
		Game.show_screen("res://ui/awards_screen.gd", award_args)
		return
	var v := UI.page(self, tr("SEASON_OVER"), func(): Game.goto_menu(), tr("SEASON").format({"n": career.season}))
	var champ: String = career.champion()
	var title := tr("CHAMPIONS") if champ == career.team else tr("TEAM_WINS").format({"team": DB.team_name(champ)})
	v.add_child(UI.label(title, "TitleLabel", 72, Game.C_GOLD if champ == career.team else Game.C_INK))
	var ss: Dictionary = career.season_stats
	v.add_child(UI.label("%s: %s %d · %s %d · %s %d" % [tr("YOUR_SEASON"), tr("MATCHES"), ss.matches, tr("STAT_RAID_PTS"), ss.raid, tr("STAT_TACKLE_PTS"), ss.tackle], "SubLabel", 24))
	var mvp: Dictionary = career.awards.get("mvp", {})
	if not mvp.is_empty():
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 14)
		arow.add_child(UI.label(tr("AWARDS_LINE").format({"name": mvp.name, "team": DB.team_name(String(mvp.team))}), "SubLabel", 22, Game.C_GOLD))
		arow.add_child(UI.button(tr("SEE_AWARDS"), false, func(): Game.show_screen("res://ui/awards_screen.gd", award_args)))
		v.add_child(arow)
	v.add_child(_player_card(true))
	var go := UI.button(tr("NEXT_SEASON"), true, func():
		career.next_season()
		Game.save_career()
		_reload())
	go.custom_minimum_size = Vector2(360, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)


func _footer(v: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var reset := UI.button(tr("CAREER_DELETE"), false, func():
		Game.delete_career()
		_reload())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(reset)
