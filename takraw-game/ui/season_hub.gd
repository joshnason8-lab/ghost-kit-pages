extends Control
## League Season: pick a league and a club (men's or women's), then the season's home: the table, your next match
## (play it, or let it be played), the round's results, the Final Four, the news, and at the end the champions and the
## awards.

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
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 24)
	top.add_theme_constant_override("v_separation", 10)
	body.add_child(top)
	var lids := ["MY", "TH", "ID"]
	top.add_child(UI.chips([tr("LEAGUE_MY"), tr("LEAGUE_TH"), tr("LEAGUE_ID")], lids.find(_league), func(i):
		_league = lids[i]
		_refresh()))
	top.add_child(UI.chips([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_refresh()))
	body.add_child(UI.wrap(tr("LEAGUE_NOTE_" + _league), "MutedLabel", 17))
	body.add_child(UI.label(tr("PICK_CLUB").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	var ids := DB.league_clubs(_league)
	var grid := UI.team_grid(self, ids, 4, func(id):
		Game.new_season(_league, id, _women)
		Game.show_screen("res://ui/season_hub.gd"))
	body.add_child(UI.scroll(grid))


func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	UI.screen(self)
	_choose()


# ---------------------------------------------------------------- the season

func _hub(s: Season) -> void:
	var v := UI.page(self, tr(DB.LEAGUES[s.league].name), func(): Game.goto_menu(), tr("SEASON_YEAR").format({"y": s.year}) + " · " + s.stage_name())
	var right: HBoxContainer = get_meta("header_right")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	cols.add_child(left)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(side)
	# The table, the top four in gold (they make the Final Four).
	var tc := UI.card()
	var tv := VBoxContainer.new()
	tc.add_child(tv)
	tv.add_child(UI.label(tr("TABLE").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	tv.add_child(UI.table(self, s.table(), s.team, s.rounds.size() > 0 and DB.league_clubs(s.league).size() > 8, 4))
	left.add_child(UI.scroll(tc))
	if s.phase == "done":
		_done(s, side, right)
		return
	# Your next match.
	var f := s.next_fixture()
	if not f.is_empty():
		var card := UI.card()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(UI.label(tr("NEXT_MATCH").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
		cv.add_child(UI.fixture_line(self, f, s.team))
		var venue := DB.home_venue(String(f.home))
		cv.add_child(UI.label(tr(DB.venue(venue)[1]), "MutedLabel", 17))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var stage := s.stage_name() if s.phase == "regular" else tr("FINAL" if s.phase == "final" else "SEMI_FINAL")
		row.add_child(UI.button(tr("PLAY"), true, func():
			Game.start_match({"home": f.home, "away": f.away, "venue": venue, "event": "regu", "sets": 3, "points": 15,
				"difficulty": int(Game.settings.difficulty), "mode": "season", "user_team": 0 if f.home == s.team else 1,
				"women": s.women, "stage": stage})))
		row.add_child(UI.button(tr("SIM_MATCH"), false, func():
			s.sim_round()
			Game.save_season()
			Game.show_screen("res://ui/season_hub.gd")))
		cv.add_child(row)
		side.add_child(card)
	else:
		# Out of the playoffs: play them out.
		side.add_child(UI.button(tr("SIM_REST"), true, func():
			while s.phase != "done":
				s.sim_round()
			Game.save_season()
			Game.show_screen("res://ui/season_hub.gd")))
	# The playoffs so far, or the last round's results.
	var rc := UI.card()
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rc.add_child(rv)
	if s.phase != "regular":
		rv.add_child(UI.label(tr("FINAL_FOUR").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
		for pf in s.playoff:
			rv.add_child(UI.fixture_line(self, pf, s.team))
	elif s.round > 0:
		rv.add_child(UI.label(tr("LAST_ROUND").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
		for lf in s.rounds[s.round - 1]:
			rv.add_child(UI.fixture_line(self, lf, s.team))
	if rv.get_child_count() > 0:
		side.add_child(UI.scroll(rc))
	right.add_child(UI.button(tr("ABANDON"), false, func(): _confirm_abandon()))


func _done(s: Season, side: VBoxContainer, right: HBoxContainer) -> void:
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	cv.add_child(UI.label(tr("CHAMPIONS").to_upper(), "EyebrowLabel", 16, Game.C_GOLD))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(Crest.make(s.champion, 56))
	var champ := UI.fit(UI.label(DB.team_name(s.champion), "HeaderLabel", 40, Game.C_GOLD if s.champion == s.team else Game.C_INK), 2)
	champ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(champ)
	cv.add_child(h)
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
