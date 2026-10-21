extends Control
## Quick match: the team sheet on the whiteboard. Two slots at the top, your team and the opponents, each a magnet
## with its flag; tap one, then a country from the grid of magnets below to put it there. On the right, the match:
## men's or women's, the venue, the length of a period (the laws' 20 minutes is one choice), the difficulty, the
## clock (the IFF's effective time, or a league's running clock), and whether a draw stands or goes to overtime and
## penalty shots. FACE-OFF starts it.

var _side := 0
var _teams := ["SWE", "FIN"]
var _slots: Array = []
var _grid: GridContainer
var _women := false
var _venue := "arena"
var _knockout := false


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("QUICK_TITLE"), func(): Game.goto_menu(), tr("MENU_QUICK"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	cols.add_child(left)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	left.add_child(slots)
	for side in 2:
		var b := _slot(side)
		slots.add_child(b)
		_slots.append(b)
		if side == 0:
			var vs := UI.label(tr("VS"), "HeaderLabel", 40, Game.C_MUTED)
			vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slots.add_child(vs)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(UI.scroll(_grid))
	_fill_grid()
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 14)
	right.add_child(UI.scroll(opts))
	opts.add_child(UI.field(tr("DIVISION"), UI.chips([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_fill_grid())))
	var venues := ["arena", "hall", "school"]
	opts.add_child(UI.field(tr("VENUE"), UI.chips([tr("VENUE_ARENA"), tr("VENUE_HALL"), tr("VENUE_SCHOOL")], venues.find(_venue), func(i): _venue = venues[i])))
	var mins := []
	for p in Game.PERIODS:
		mins.append(Game.plural("MINUTES", p))
	opts.add_child(UI.field(tr("PERIOD_LENGTH"), UI.chips(mins, int(Game.settings.period), func(i):
		Game.settings.period = i
		Game.save_settings())))
	opts.add_child(UI.wrap(tr("PERIOD_NOTE"), "MutedLabel", 16))
	opts.add_child(UI.difficulty_field(self))
	var clock_note := UI.wrap(tr("CLOCK_IFF_NOTE") if int(Game.settings.rules) == 0 else tr("CLOCK_LEAGUE_NOTE"), "MutedLabel", 16)
	opts.add_child(UI.field(tr("CLOCK"), UI.chips([tr("CLOCK_IFF"), tr("CLOCK_LEAGUE")], int(Game.settings.rules), func(i):
		Game.settings.rules = i
		Game.save_settings()
		clock_note.text = tr("CLOCK_IFF_NOTE") if i == 0 else tr("CLOCK_LEAGUE_NOTE"))))
	opts.add_child(clock_note)
	opts.add_child(UI.field(tr("A_DRAW"), UI.chips([tr("DRAW_STANDS"), tr("DRAW_DECIDED")], 1 if _knockout else 0, func(i): _knockout = i == 1)))
	var go := UI.button(tr("FACE_OFF_GO"), true, _start)
	go.custom_minimum_size = Vector2(0, 70)
	right.add_child(go)
	_refresh()


func _slot(side: int) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	b.toggle_mode = false
	b.pressed.connect(func():
		Sfx.click()
		_side = side
		_refresh())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -10
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var eb := UI.label(tr("YOUR_TEAM") if side == 0 else tr("OPPONENT"), "EyebrowLabel", 15, Game.C_BLUE if side == 0 else Game.C_RED)
	eb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(eb)
	var nm := UI.fit(UI.label("", "HeaderLabel", 38), 1)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	b.set_meta("name", nm)
	b.set_meta("box", h)
	h.add_child(col)
	return b


func _refresh() -> void:
	for side in 2:
		var b: Button = _slots[side]
		var nm: Label = b.get_meta("name")
		nm.text = DB.team_name(_teams[side])
		UI.refit(nm)
		var h: HBoxContainer = b.get_meta("box")
		if h.get_child_count() > 1:
			h.get_child(0).queue_free()
		var flag := UI.badge(_teams[side], Vector2(66, 44))
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(flag)
		h.move_child(flag, 0)
		var col := Game.C_BLUE if side == 0 else Game.C_RED
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(8)
		sb.border_color = col if side == _side else Color(Game.C_INK, 0.15)
		sb.set_border_width_all(4 if side == _side else 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## The countries, strongest first by the division's ranking, each a magnet with its flag and its rating.
func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array = DB.team_ids()
	ids.sort_custom(func(a, b): return DB.rating(a, _women) > DB.rating(b, _women))
	for id in ids:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 74)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -8
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var f := UI.badge(id, Vector2(40, 27))
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(f)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", -2)
		var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", 18), 2)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		var r := UI.label(tr("RATING_N").format({"n": DB.rating(id, _women)}), "MutedLabel", 14)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(r)
		h.add_child(col)
		var grow := func(): b.custom_minimum_size.y = maxf(74.0, h.get_combined_minimum_size().y + 10.0)
		h.minimum_size_changed.connect(grow)
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			_teams[_side] = pick
			if _teams[0] == _teams[1]:
				_teams[1 - _side] = ids[0] if ids[0] != pick else ids[1]
			_side = 1 - _side if _side == 0 else _side
			_refresh())
		_grid.add_child(b)


func _start() -> void:
	Game.start_match({"home": _teams[0], "away": _teams[1], "venue": _venue, "user_team": 0, "mode": "quick", "women": _women,
		"knockout": _knockout, "rules": int(Game.settings.rules), "difficulty": int(Game.settings.difficulty),
		"stage": tr("FRIENDLY")})
