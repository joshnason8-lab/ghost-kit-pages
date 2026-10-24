extends Control
## Nations Cup hub: pick a country (underdogs rated 70 or below play for the Underdog Trophy), pick the squad, then
## follow the groups, what you need from your last group match, and the knockout bracket; play or simulate your
## matches. The front page and the ticker follow the tournament, and breaking news stops you until you have seen it.

var cup


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	cup = Game.get_cup()
	if cup == null:
		_pick_country()
		return
	if not cup.picked:
		Game.show_screen.call_deferred("res://ui/cup_squad.gd")
		return
	if cup.stage == "done" and _celebrate():
		return
	_hub()
	var fresh: Array = News.unseen_breaking(cup.news, cup.news_seen)
	cup.news_seen = News.last_id(cup.news)
	Game.save_cup()
	if not fresh.is_empty():
		NewsTicker.breaking(self, fresh, func(): pass)


func _reload() -> void:
	Game.show_screen("res://ui/cup_screen.gd")


func _pick_country() -> void:
	var v := UI.page(self, tr("CUP_PICK"), func(): Game.goto_menu(), tr("MENU_CUP"))
	var tags := {}
	for id in DB.country_ids:
		if Cup.is_underdog(id):
			tags[id] = UI.pill(tr("UNDERDOG").to_upper(), Game.C_GOOD)
	v.add_child(UI.team_grid(self, DB.country_ids, 4, func(id):
		Game.new_cup(id)
		Game.show_screen("res://ui/cup_squad.gd"), tags))
	var note := UI.label(tr("UNDERDOG_NOTE").format({"n": Cup.UNDERDOG}), "MutedLabel", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)


## The tournament is won: the trophy (the Underdog Trophy for an underdog) and the awards come first, once each.
## Returns true if one of them was shown.
func _celebrate() -> bool:
	var key := "cup_%d" % int(cup.seed_value)
	if cup.champion == cup.user and not bool(Game.settings.get(key + "_trophy", false)):
		Game.settings[key + "_trophy"] = true
		Game.save_settings()
		_show_trophy()
		return true
	if not cup.awards.is_empty() and not bool(Game.settings.get(key + "_awards", false)):
		Game.settings[key + "_awards"] = true
		Game.save_settings()
		_show_awards()
		return true
	return false


func _show_trophy() -> void:
	var under: bool = Cup.is_underdog(cup.user)
	Game.show_screen("res://ui/trophy_screen.gd", {"team": cup.user, "title": tr("UNDERDOG_TROPHY") if under else tr("MENU_CUP"),
		"back": "res://ui/cup_screen.gd", "underdog": under})


func _show_awards() -> void:
	Game.show_screen("res://ui/awards_screen.gd", {"awards": cup.awards, "label": tr("MENU_CUP"), "back": "res://ui/cup_screen.gd",
		"mine": cup.user, "title": tr("CUP_AWARDS"), "titles": {"mvp": "PLAYER_OF_TOURNAMENT", "raider": "GOLDEN_RAIDER", "defender": "BEST_DEFENDER"},
		"sub": "PLAYER_OF_TOURNAMENT_SUB", "note": "CUP_AWARDS_NOTE"})


func _hub() -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), cup.stage_name())
	var head: HBoxContainer = get_meta("header_right")
	var cap: Dictionary = cup.captain_player()
	if not cap.is_empty():
		var cl := HBoxContainer.new()
		cl.add_theme_constant_override("separation", 6)
		cl.add_child(Icon.make("crown", 22, Game.C_GOLD))
		cl.add_child(UI.label(String(cap.name), "SubLabel", 18))
		head.add_child(cl)
	head.add_child(Crest.make(cup.user, 46))
	var top: Dictionary = News.top_story(cup.news)
	if not top.is_empty():
		v.add_child(NewsTicker.front_page(top, true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# Left: the groups.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for g in ["A", "B"]:
		# A card a little tighter than the theme's, so both groups fit without scrolling.
		var c := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Game.C_PANEL
		csb.set_corner_radius_all(16)
		csb.border_color = Color(1, 1, 1, 0.06)
		csb.set_border_width_all(1)
		csb.content_margin_left = 18
		csb.content_margin_right = 18
		csb.content_margin_top = 6
		csb.content_margin_bottom = 8
		c.add_theme_stylebox_override("panel", csb)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cv.add_child(UI.label(tr("GROUP").format({"g": g}), "SubLabel", 18, Game.C_SAFFRON))
		cv.add_child(UI.table(self, cup.standings(g), cup.user, true))
		c.add_child(cv)
		left.add_child(c)
	left.add_child(UI.wrap(tr("QUALIFY_NOTE"), "MutedLabel", 15))
	cols.add_child(UI.scroll(left))

	# Middle: your next match, and what you need.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 0.9
	var next = cup.next_user_fixture()
	var card := UI.card()
	var cv2 := VBoxContainer.new()
	cv2.add_theme_constant_override("separation", 10)
	card.add_child(cv2)
	if cup.stage == "done":
		var champ := UI.wrap(tr("CUP_WINNER").format({"team": DB.team_name(cup.champion)}), "HeaderLabel", 36)
		champ.add_theme_color_override("font_color", Game.C_GOLD if cup.champion == cup.user else Game.C_INK)
		cv2.add_child(champ)
		if cup.champion == cup.user:
			cv2.add_child(UI.button(tr("SEE_TROPHY"), false, _show_trophy))
		if not cup.awards.is_empty():
			cv2.add_child(UI.button(tr("CUP_AWARDS"), false, _show_awards))
		cv2.add_child(UI.button(tr("CUP_RESTART"), true, func():
			Game.delete_cup()
			_reload()))
	elif next != null:
		cv2.add_child(UI.label(_stage_label(next).to_upper(), "EyebrowLabel"))
		cv2.add_child(UI.fixture_line(self, next, cup.user))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var play := UI.button(tr("PLAY_MATCH"), true, func(): _play(next))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(play)
		row.add_child(UI.button(tr("SIM_MATCH"), false, func():
			cup.simulate_user_match()
			Game.save_cup()
			_reload()))
		cv2.add_child(row)
	else:
		cv2.add_child(UI.label(tr("ELIMINATED"), "HeaderLabel", 36, Game.C_MAGENTA))
		cv2.add_child(UI.button(tr("SIM_MATCH"), true, func():
			cup.sim_everything_left()
			Game.save_cup()
			_reload()))
	mid.add_child(card)
	var sc: Dictionary = cup.scenario()
	if not sc.is_empty():
		mid.add_child(_scenario_card(sc))
	cols.add_child(mid)

	# Right: the knockouts.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.85
	right.add_child(UI.label(tr("KNOCKOUTS").to_upper(), "EyebrowLabel"))
	right.add_child(_bracket())
	cols.add_child(right)
	if not cup.news.is_empty():
		v.add_child(NewsTicker.make(News.latest(cup.news, 12)))


## What you need from your last group match.
func _scenario_card(sc: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, 0.9)
	sb.set_corner_radius_all(14)
	sb.border_color = Game.C_SAFFRON
	sb.border_width_left = 5
	sb.content_margin_left = 16
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UI.label(tr("WHAT_YOU_NEED").to_upper(), "EyebrowLabel", 14, Game.C_SAFFRON))
	var main := UI.label(News.text({"k": sc.k, "v": 1, "a": sc.a}), "SubLabel", 20)
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(main)
	if sc.has("top"):
		var t: Dictionary = sc.top
		var tl := UI.label(News.text({"k": t.k, "v": 1, "a": t.a}), "MutedLabel", 16)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)
	return p


## The semi-finals, the final and the champion, as a bracket.
func _bracket() -> Control:
	var b: Dictionary = cup.bracket()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var semis := VBoxContainer.new()
	semis.add_theme_constant_override("separation", 18)
	semis.alignment = BoxContainer.ALIGNMENT_CENTER
	semis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	semis.add_child(UI.label(tr("SEMI_FINAL").to_upper(), "EyebrowLabel", 13))
	for f in b.semis:
		semis.add_child(_tie_box(f))
	h.add_child(semis)
	var fin := VBoxContainer.new()
	fin.add_theme_constant_override("separation", 10)
	fin.alignment = BoxContainer.ALIGNMENT_CENTER
	fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fin.add_child(UI.label(tr("FINAL").to_upper(), "EyebrowLabel", 13, Game.C_GOLD))
	fin.add_child(_tie_box(b.final, true))
	if String(b.champion) != "":
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 8)
		ch.add_child(Icon.make("trophy", 30, Game.C_GOLD))
		ch.add_child(Crest.make(String(b.champion), 34))
		var nl := UI.label(DB.team_name(String(b.champion)), "SubLabel", 18, Game.C_GOLD)
		UI.fit(nl)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(nl)
		fin.add_child(ch)
	h.add_child(fin)
	return h


## One knockout tie: two sides (or the places they will come from), the winner lit.
func _tie_box(f: Dictionary, final := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.26)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(Game.C_GOLD, 0.6) if final else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	for i in 2:
		var id := String(f.home if i == 0 else f.away)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var known := not DB.team(id).is_empty()
		var won: bool = bool(f.played) and int(f.score[i]) > int(f.score[1 - i])
		if known:
			row.add_child(Crest.make(id, 24))
		var nm := UI.label(DB.team_name(id) if known else _place_name(id), "SubLabel" if won else "", 16,
			Game.C_SAFFRON if id == cup.user else (Game.C_INK if known else Game.C_MUTED))
		UI.fit(nm, 2)   # "Winner semi-final 1" in Tamil takes two lines in a narrow bracket
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if bool(f.played):
			row.add_child(UI.label(str(int(f.score[i])), "SubLabel", 16, Game.C_GOLD if won else Game.C_MUTED))
		v.add_child(row)
	return p


## "Winner Group A", "Runner-up Group B", "Winner semi-final 1".
func _place_name(code: String) -> String:
	if code.begins_with("W"):
		return tr("WINNER_SEMI").format({"n": code.substr(1)})
	return tr("GROUP_WINNER" if code.ends_with("1") else "GROUP_RUNNER_UP").format({"g": code.substr(0, 1)})


func _stage_label(f: Dictionary) -> String:
	match String(f.stage):
		"semi":
			return tr("SEMI_FINAL")
		"final":
			return tr("FINAL")
	return "%s · %s" % [tr("GROUP").format({"g": f.group}), tr("MATCHDAY").format({"n": f.round})]


func _play(f: Dictionary) -> void:
	var opp: String = f.away if f.home == cup.user else f.home
	var arenas := ["stadium", "dome", "stadium", "monsoon", "stadium"]
	Game.start_match({
		"home": cup.user, "away": opp, "arena": arenas[int(f.round) - 1] if f.stage == "group" else "stadium",
		"mode": "cup", "control": "all", "length": int(Game.settings.length),
		"difficulty": int(Game.settings.difficulty), "knockout": f.stage != "group",
		"home_squad": cup.squad, "walkout": f.stage == "final", "stage": String(f.stage),
	})
