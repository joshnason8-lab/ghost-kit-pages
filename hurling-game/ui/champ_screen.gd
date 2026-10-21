extends Control
## The Summer Championship: pick your county to start; then your next game (and Play), the group tables, and every
## result and fixture, group games and knock-out. A champion at the end, and a new year.

var _c: Championship = null
var _tab := 0
var _body: VBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	_c = Game.get_champ()
	if _c == null:
		_pick()
	else:
		_hub()


## No championship yet: the counties to choose from, as jerseys.
func _pick() -> void:
	var v := UI.page(self, tr("CHAMP_PICK"), func(): Game.goto_menu(), tr("CHAMP_NAME_1"))
	v.add_child(UI.wrap(tr("CHAMP_PICK_NOTE"), "MutedLabel", 18))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(UI.scroll(grid))
	for id in DB.counties_ranked():
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 84)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -8
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var j := Colours.make(id, 44)
		j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(j)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UI.label(DB.team_name(id), "SubLabel", 19)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		col.add_child(nm)
		var tier := tr("TIER_1") if String(DB.COUNTIES[id][4]) != "" else tr("TIER_2")
		var sub := UI.label(tier, "MutedLabel", 14)
		UI.fit(sub, 1)
		col.add_child(sub)
		h.add_child(col)
		b.add_child(h)
		var grow := func():
			b.custom_minimum_size.y = maxf(84.0, h.get_combined_minimum_size().y + 10.0)
		h.minimum_size_changed.connect(grow)
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			Game.new_champ(pick)
			Game.show_screen("res://ui/champ_screen.gd"))
		grid.add_child(b)


func _hub() -> void:
	var v := UI.page(self, tr(_c.name_key()), func(): Game.goto_menu(), str(_c.year))
	var right: HBoxContainer = get_meta("header_right")
	var f := _c.next_fixture()
	if _c.phase == "done" or _c.user_out():
		right.add_child(UI.button(tr("NEW_CHAMP"), true, func():
			Game.delete_champ()
			Game.show_screen("res://ui/champ_screen.gd")))
	elif not f.is_empty():
		# Start again (another county, the other competition): a second tap to be sure, as the season is lost.
		var again := UI.button(tr("START_AGAIN"), false)
		again.custom_minimum_size = Vector2(0, 56)
		again.pressed.connect(func():
			if again.has_meta("sure"):
				Game.delete_champ()
				Game.show_screen("res://ui/champ_screen.gd")
			else:
				again.set_meta("sure", true)
				again.text = tr("START_AGAIN_SURE"))
		right.add_child(again)
		right.add_child(UI.button(tr("PLAY"), true, func(): _play(f)))
	v.add_child(UI.chips([tr("CHAMP_NEXT"), tr("CHAMP_TABLES"), tr("CHAMP_RESULTS")], _tab, func(i):
		_tab = i
		_fill()))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	v.add_child(UI.scroll(_body))
	_fill()


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	match _tab:
		0:
			_next()
		1:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			_body.add_child(row)
			for g in _c.groups:
				var card := UI.card()
				card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var cv := VBoxContainer.new()
				card.add_child(cv)
				cv.add_child(UI.label(tr("GROUP_" + String(g)), "SubLabel", 22, Game.C_GOLD))
				var rows := []
				for r in _c.table(g):
					rows.append([r.id, r.p, r.w, r.d, r.l, UI.signed(int(r.diff)), r.pts])
				cv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_DIFF"), tr("COL_PTS")],
					rows, _c.user, 3 if _c.tier == 1 else 2, 0, true))
				row.add_child(card)
			_body.add_child(UI.wrap(tr("CHAMP_TABLE_NOTE_%d" % _c.tier), "MutedLabel", 16))
		2:
			var stages := []
			for f in _c.fixtures:
				var key := String(f.stage)
				if not (key in stages):
					stages.append(key)
			for st in stages:
				_body.add_child(UI.label(tr(st), "SubLabel", 20, Game.C_GOLD))
				for f in _c.fixtures:
					if String(f.stage) == st:
						_body.add_child(UI.fixture_line(self, f, _c.user))


func _next() -> void:
	var card := UI.card()
	_body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	if _c.phase == "done":
		v.add_child(UI.label(tr("CHAMPIONS").format({"team": DB.team_name(_c.champion)}), "HeaderLabel", 38, Game.C_GOLD))
		v.add_child(UI.wrap(tr("CHAMP_WON") if _c.champion == _c.user else tr("CHAMP_OVER"), "", 18))
		return
	var f := _c.next_fixture()
	if f.is_empty():
		v.add_child(UI.wrap(tr("CHAMP_OUT"), "", 18))
		return
	v.add_child(UI.label(tr(String(f.stage)).to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for k in 2:
		var id := String(f.home if k == 0 else f.away)
		if k == 1:
			row.add_child(UI.label(tr("VS"), "SubLabel", 22, Game.C_MUTED))
		row.add_child(Colours.make(id, 46))
		var nm := UI.label(DB.team_name(id), "HeaderLabel", 32)
		UI.shrink(nm, 32, 0.6, 1)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
	var venue := "county" if String(f.stage) == "STAGE_GROUP" else ("stadium" if String(f.stage) in ["STAGE_SEMI", "STAGE_FINAL"] else "county")
	v.add_child(UI.label(tr(String(DB.venue(venue)[0])), "MutedLabel", 17))
	if bool(f.knockout):
		v.add_child(UI.wrap(tr("KNOCKOUT_NOTE"), "MutedLabel", 16))


func _play(f: Dictionary) -> void:
	var home := String(f.home)
	var away := String(f.away)
	var user := 0 if home == _c.user else 1
	var stage := String(f.stage)
	var venue := "county" if stage == "STAGE_GROUP" else ("stadium" if stage in ["STAGE_SEMI", "STAGE_FINAL"] else "county")
	Game.start_match({"home": home, "away": away, "venue": venue, "mode": "champ", "user_team": user,
		"knockout": bool(f.knockout), "stage": tr(stage), "grade": int(Game.settings.grade)})
