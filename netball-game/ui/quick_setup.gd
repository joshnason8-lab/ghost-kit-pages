extends Control
## Quick Match: the team sheet. Your nation and theirs (by flag), the venue, the quarters' length, how good the
## other side is, and the league rules if you want them; then the umpires toss for the first centre pass.

var _home := "ENG"
var _away := "JAM"
var _venue := "arena"
var _pick_side := 0          # which team the grid picks: 0 yours, 1 theirs
var _grid_box: VBoxContainer
var _sides: Array = []
var _scroll: ScrollContainer


func setup(args: Dictionary) -> void:
	_home = String(args.get("home", Game.settings.get("last_home", "ENG")))
	_away = String(args.get("away", Game.settings.get("last_away", "JAM")))
	if DB.team(_home).is_empty():
		_home = "ENG"
	if DB.team(_away).is_empty() or _away == _home:
		_away = "JAM" if _home != "JAM" else "AUS"


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_QUICK"), func(): Game.goto_menu(), tr("TEAM_SHEET"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# Left: the two sides, and the flags to pick from.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	cols.add_child(left)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 12)
	left.add_child(sides)
	for t in 2:
		var b := _side_button(t)
		sides.add_child(b)
		_sides.append(b)
	_grid_box = VBoxContainer.new()
	_scroll = UI.scroll(_grid_box)
	left.add_child(_scroll)
	_fill_grid()
	# Right: the match's settings and Play.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rs := UI.scroll(right)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rs)
	var vnames := []
	var vids := []
	for ven in DB.VENUES:
		vids.append(ven[0])
		vnames.append(tr(String(ven[1])))
	right.add_child(UI.field(tr("VENUE"), UI.chips(vnames, vids.find(_venue), func(i): _venue = vids[i])))
	var qn := []
	for qm in Game.QUARTERS:
		qn.append(tr("MINUTES_N").format({"n": qm}))
	right.add_child(UI.field(tr("QUARTERS"), UI.chips(qn, int(Game.settings.quarter), func(i):
		Game.settings.quarter = i
		Game.save_settings())))
	right.add_child(UI.wrap(tr("QUARTERS_NOTE"), "MutedLabel", 16))
	right.add_child(UI.difficulty_field(self))
	right.add_child(UI.field(tr("DOUBLE_ZONE"), UI.chips_row([tr("ON"), tr("OFF")], 0 if Game.settings.double_zone else 1, func(i):
		Game.settings.double_zone = i == 0
		Game.save_settings())))
	right.add_child(UI.wrap(tr("DOUBLE_ZONE_NOTE"), "MutedLabel", 16))
	for opt in [["timeouts", "TIMEOUTS"], ["rolling", "ROLLING"]]:
		var key: String = opt[0]
		right.add_child(UI.field(tr(opt[1]), UI.chips_row([tr("ON"), tr("OFF")], 0 if Game.settings[key] else 1, func(i):
			Game.settings[key] = i == 0
			Game.save_settings())))
		right.add_child(UI.wrap(tr(opt[1] + "_NOTE"), "MutedLabel", 16))
	var play := UI.button(tr("PLAY"), true, _play)
	play.custom_minimum_size = Vector2(0, 70)
	v.add_child(play)


func _side_button(t: int) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 84)
	b.toggle_mode = true
	b.button_pressed = t == _pick_side
	b.pressed.connect(func():
		Sfx.click()
		_pick_side = t
		_refresh())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	b.set_meta("box", h)
	_fill_side(b, t)
	return b


func _fill_side(b: Button, t: int) -> void:
	var h: HBoxContainer = b.get_meta("box")
	for c in h.get_children():
		c.queue_free()
	var id := _home if t == 0 else _away
	var flag := UI.badge(id, Vector2(54, 36))
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(flag)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	col.add_child(UI.label((tr("YOUR_TEAM") if t == 0 else tr("OPPONENT")).to_upper(), "EyebrowLabel", 14, Game.C_ACCENT if t == _pick_side else Game.C_MUTED))
	var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", 24), 1)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(nm)
	for c in h.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fill_grid() -> void:
	for c in _grid_box.get_children():
		c.queue_free()
	var ids: Array = DB.team_ids()
	var grid := UI.team_grid(self, ids, 2, func(id):
		if _pick_side == 0:
			if id == _away:
				_away = _home
			_home = id
			_pick_side = 1
		else:
			if id == _home:
				_home = _away
			_away = id
		_refresh())
	_grid_box.add_child(grid)


func _refresh() -> void:
	for t in 2:
		(_sides[t] as Button).button_pressed = t == _pick_side
		_fill_side(_sides[t], t)


func _play() -> void:
	Game.settings.last_home = _home
	Game.settings.last_away = _away
	Game.save_settings()
	Game.start_match({"home": _home, "away": _away, "venue": _venue, "quarter": Game.quarter_minutes(),
		"difficulty": int(Game.settings.difficulty), "mode": "quick", "user_team": 0, "control": int(Game.settings.control),
		"bib": String(Game.settings.bib), "double_zone": bool(Game.settings.double_zone), "timeouts": bool(Game.settings.timeouts),
		"rolling": bool(Game.settings.rolling), "need_winner": false})
