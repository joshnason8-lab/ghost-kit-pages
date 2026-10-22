extends Control
## Match setup, laid out as the match is: the rules on the left (Classic or Fast, each drawn as its field), the two
## sides facing each other at the top right with the teams to pick from under them, then the ground, the turn's length
## and the difficulty. Then the toss, as the referee holds it: call it, and the winner chooses to chase or to defend
## first. From Watch a Match the same screen picks two sides for the AI, and there is no toss to call.

var watch := false
var _fmt := 0
var _sides := ["MAH", "ODI"]
var _editing := 1           # which side the grid sets: 0 yours, 1 the opponent
var _pool := "states"
var _women := false
var _venue := "maidan"
var _len := 0
var _grid: GridContainer
var _side_cards: Array = []
var _toss: Control
var _rng := RandomNumberGenerator.new()


func setup(args: Dictionary) -> void:
	watch = bool(args.get("watch", false))


func _ready() -> void:
	_rng.randomize()
	_fmt = int(Game.settings.format)
	_len = int(Game.settings.turn_len)
	_pool = "nations" if _fmt == KhoRules.FAST else "states"
	_sides = ["IND", "NEP"] if _pool == "nations" else ["MAH", "ODI"]
	_venue = "arena" if _fmt == KhoRules.FAST else "maidan"
	_build_again()


func _build_left(left: VBoxContainer) -> void:
	left.add_child(UI.label(tr("SETUP_STEP_FORMAT").to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	for f in [KhoRules.CLASSIC, KhoRules.FAST]:
		var key := "FORMAT_CLASSIC" if f == KhoRules.CLASSIC else "FORMAT_FAST"
		var fv: int = f
		left.add_child(UI.option_card(tr(key), tr(key + "_DESC"), FieldIcon.make(f), _fmt == f, func():
			_fmt = fv
			Game.settings.format = fv
			Game.save_settings()
			_rebuild()))
	left.add_child(UI.label(tr("SETUP_STEP_GROUND").to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	var vg := GridContainer.new()
	vg.columns = 2
	vg.add_theme_constant_override("h_separation", 10)
	vg.add_theme_constant_override("v_separation", 10)
	for vid in DB.venue_ids():
		var vk := String(DB.venue(vid)[1])
		var idv: String = vid
		var b := UI.option_card(tr(vk), tr(vk + "_DESC"), Icon.make("flag", 26, Game.C_SAFFRON), _venue == vid, func():
			_venue = idv
			_rebuild())
		vg.add_child(b)
	left.add_child(vg)
	var real := int(KhoRules.real_turn(_fmt) / 60.0)
	left.add_child(UI.field(tr("TURN_LENGTH"), UI.chips([tr("TURN_MIN").format({"n": 3}), tr("TURN_MIN").format({"n": 5}),
		tr("TURN_REAL").format({"n": real})], _len, func(i):
			_len = i
			Game.settings.turn_len = i
			Game.save_settings())))
	left.add_child(UI.wrap(tr("TURN_NOTE"), "MutedLabel", 16))
	if not watch:
		left.add_child(UI.difficulty_field(self))


func _build_right(right: VBoxContainer) -> void:
	right.add_child(UI.label(tr("SETUP_STEP_TEAMS").to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	var vs := HBoxContainer.new()
	vs.add_theme_constant_override("separation", 12)
	right.add_child(vs)
	_side_cards = []
	for side in 2:
		var b := Button.new()
		b.theme_type_variation = "LaneButton"
		b.toggle_mode = true
		b.button_pressed = _editing == side
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 92)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -12
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cr := Crest.make(_sides[side], 50)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var who := UI.label((tr("YOUR_SIDE") if side == 0 and not watch else tr("OPPONENT") if not watch else "").to_upper(), "EyebrowLabel", 13, Game.C_GOLD)
		UI.fit(who)
		col.add_child(who)
		var nm := UI.label(DB.team_name(_sides[side]), "SubLabel", 22)
		UI.fit(nm, 2)
		col.add_child(nm)
		col.add_child(UI.stat_bar(tr("RATING"), DB.team_rating(_sides[side], _women), DB.kit(_sides[side])[0].lightened(0.2)))
		h.add_child(col)
		b.add_child(h)
		var sv := side
		b.pressed.connect(func():
			_editing = sv
			_rebuild())
		vs.add_child(b)
		_side_cards.append(b)
		if side == 0:
			var l := UI.label(tr("VS"), "HeaderLabel", 30, Game.C_SAFFRON)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			vs.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var pools := ["states", "nations", "cities"]
	row.add_child(UI.chips_row([tr("TEAMS_STATES"), tr("TEAMS_NATIONS"), tr("TEAMS_CITIES")], pools.find(_pool), func(i):
		_pool = pools[i]
		var ids := _pool_ids()
		_sides = [ids[0], ids[1]]
		_rebuild()))
	row.add_child(UI.chips_row([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_rebuild()))
	right.add_child(row)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var ids := _pool_ids()
	for id in ids:
		var b := Button.new()
		b.theme_type_variation = "LaneButton"
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -6
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cr := Crest.make(id, 30)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
		var nm := UI.label(DB.team_name(id), "", 16, Game.C_GOLD if id in _sides else Game.C_INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(nm, 2, 0.62)   # a long one-word name (Malayalam's Andhra Pradesh) gets smaller rather than broken
		h.add_child(nm)
		b.add_child(h)
		var pid: String = id
		b.pressed.connect(func():
			Sfx.click()
			if _sides[1 - _editing] == pid:
				_sides[1 - _editing] = _sides[_editing]
			_sides[_editing] = pid
			_editing = 1 - _editing if _editing == 0 else 1
			_rebuild())
		_grid.add_child(b)
	right.add_child(UI.scroll(_grid))


func _pool_ids() -> Array:
	match _pool:
		"nations":
			return DB.nation_ids()
		"cities":
			return DB.club_ids()
	return DB.state_ids()


func _rebuild() -> void:
	var keep := [_fmt, _sides.duplicate(), _editing, _pool, _women, _venue, _len]
	for c in get_children():
		c.queue_free()
	_fmt = keep[0]
	_sides = keep[1]
	_editing = keep[2]
	_pool = keep[3]
	_women = keep[4]
	_venue = keep[5]
	_len = keep[6]
	_build_again.call_deferred()


func _build_again() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_WATCH") if watch else tr("SETUP_TITLE"), func(): Game.goto_menu(), tr("MENU_QUICK") if not watch else "")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ls := UI.scroll(left)
	ls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.size_flags_stretch_ratio = 0.9
	cols.add_child(ls)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.1
	cols.add_child(right)
	_build_left(left)
	_build_right(right)
	v.add_child(UI.button(tr("NEXT") if not watch else tr("PLAY"), true, _on_go))


func turn_seconds() -> float:
	return [180.0, 300.0, KhoRules.real_turn(_fmt)][clampi(_len, 0, 2)]


func config(chase_first: int) -> Dictionary:
	return {"home": _sides[0], "away": _sides[1], "venue": _venue, "format": _fmt, "turn_len": turn_seconds(),
		"difficulty": int(Game.settings.difficulty), "mode": "quick", "user_team": -1 if watch else 0, "women": _women,
		"chase_first": chase_first, "follow_on": bool(Game.settings.follow_on), "powerplay": bool(Game.settings.powerplay)}


func _on_go() -> void:
	if watch:
		Game.start_match(config(_rng.randi() % 2))
		return
	_show_toss()


## The toss: call it; the coin spins; the winner chooses.
func _show_toss() -> void:
	_toss = Control.new()
	_toss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toss.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toss.add_child(dim)
	add_child(_toss)
	set_meta("back", func():
		_toss.queue_free()
		set_meta("back", func(): Game.goto_menu()))
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toss.add_child(c)
	var card := UI.card()
	card.custom_minimum_size = Vector2(560, 0)
	c.add_child(card)
	UI.keep_on_screen(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := UI.label(tr("TOSS"), "HeaderLabel", 40, Game.C_SAFFRON)
	UI.fit(t)
	v.add_child(t)
	var coin := Coin.new()
	coin.custom_minimum_size = Vector2(0, 150)
	v.add_child(coin)
	var msg := UI.label(tr("TOSS_CALL"), "SubLabel", 22)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(msg, 2)
	v.add_child(msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for call in [0, 1]:
		var cv: int = call
		var b := UI.button(tr("TOSS_HEADS") if call == 0 else tr("TOSS_TAILS"), call == 0, func():
			for ch in row.get_children():
				ch.queue_free()
			var land := _rng.randi() % 2
			coin.spin(land)
			await get_tree().create_timer(1.3).timeout
			if not is_instance_valid(msg):
				return
			if land == cv:
				msg.text = tr("TOSS_WON") + ". " + tr("TOSS_CHOOSE")
				UI.refit(msg)
				for ch in [[tr("CHASE_FIRST"), 0], [tr("DEFEND_FIRST"), 1]]:
					var first: int = ch[1]
					var cb := UI.button(String(ch[0]), first == 0, func(): Game.start_match(config(first)))
					cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(cb)
			else:
				# The other captain mostly chooses to defend first, so as to know the target (docs/AI.md).
				var they_chase := _rng.randf() < 0.35
				msg.text = tr("TOSS_LOST").format({"team": DB.team_name(_sides[1])}) + ". " + (tr("TOSS_THEY_CHOSE_CHASE") if they_chase else tr("TOSS_THEY_CHOSE_DEFEND"))
				UI.refit(msg)
				var sb := UI.button(tr("START_MATCH"), true, func(): Game.start_match(config(1 if they_chase else 0)))
				sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(sb))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


## The coin, spinning and landing. Heads is a lion's head, as the lion side is "heads" on the coins of India; tails is
## the coin's value, 1 in the currency of the player's language (rupee, Nepali rupee, taka, Sri Lankan rupee), in a
## wreath. Its face is named under it when it lands.
class Coin extends Control:
	var _t := -1.0
	var _land := 0
	var _name: Label

	func _ready() -> void:
		_name = UI.label("", "SubLabel", 20, Game.C_GOLD)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_name.offset_top = -26
		add_child(_name)

	func spin(land: int) -> void:
		_land = land
		_t = 0.0
		_name.text = ""
		Sfx.play("whoosh", -8.0)

	func _process(delta: float) -> void:
		if _t >= 0.0 and _t < 1.2:
			_t += delta
			if _t >= 1.2:
				_name.text = tr("TOSS_HEADS") if _land == 0 else tr("TOSS_TAILS")
		queue_redraw()

	static func currency(lang: String) -> String:
		return {"ne": "रू", "bn": "৳", "si": "රු"}.get(lang, "₹")

	func _draw() -> void:
		var c := size * 0.5 - Vector2(0, 12)
		var r := minf(size.y * 0.38, 50.0)
		var k := 1.0
		var face := _land
		var lift := 0.0
		if _t >= 0.0 and _t < 1.2:
			var turns := 6.0 * (1.0 - pow(1.0 - _t / 1.2, 2.0))
			k = absf(cos(turns * PI))
			face = int(floor(turns)) % 2 if _t < 1.15 else _land
			lift = sin(PI * _t / 1.2) * 34.0
		var metal := Color("d9b45a")
		var dark := Color(0.36, 0.24, 0.07)
		draw_set_transform(c - Vector2(0, lift), 0.0, Vector2(1.0, maxf(0.06, k)))
		draw_circle(Vector2.ZERO, r, metal.darkened(0.25))
		draw_circle(Vector2.ZERO, r * 0.93, metal)
		draw_arc(Vector2.ZERO, r * 0.86, 0, TAU, 48, Color(dark, 0.6), 2.0, true)
		if face == 0:
			_lion(r, dark, metal)
		else:
			_value(r, dark)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A lion's head, face on: the mane in petals, the face, the ears, the eyes, the nose and the mouth.
	func _lion(r: float, ink: Color, metal: Color) -> void:
		for i in 14:
			var a := TAU * i / 14.0
			var p := Vector2(cos(a), sin(a)) * r * 0.5
			draw_circle(p, r * 0.2, metal.darkened(0.18 + 0.06 * (i % 2)))
		draw_circle(Vector2(0, 0.02 * r), r * 0.4, metal.lightened(0.08))
		for sx in [-1.0, 1.0]:
			draw_circle(Vector2(sx * r * 0.3, -r * 0.3), r * 0.1, metal.darkened(0.1))
			draw_circle(Vector2(sx * r * 0.15, -r * 0.06), r * 0.05, ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.1, r * 0.08), Vector2(r * 0.1, r * 0.08), Vector2(0, r * 0.2)]), ink)
		draw_line(Vector2(0, r * 0.2), Vector2(0, r * 0.27), ink, 2.0, true)
		draw_arc(Vector2(-r * 0.07, r * 0.27), r * 0.07, 0.0, PI, 8, ink, 2.0, true)
		draw_arc(Vector2(r * 0.07, r * 0.27), r * 0.07, 0.0, PI, 8, ink, 2.0, true)

	## The value: 1 and the currency sign, over two ears of wheat.
	func _value(r: float, ink: Color) -> void:
		var font: Font = Game.font_bold
		var cur := currency(Game.language())
		var txt := "1"
		var fs := int(r * 0.78)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-w * 0.5, r * 0.34), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		var ss := int(r * 0.32)
		var sw := font.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		draw_string(font, Vector2(-sw * 0.5, -r * 0.3), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, ink)
		# The wreath: a grain every few degrees round the lower rim, each side.
		for i in 9:
			var a := PI * (0.08 + 0.045 * i)
			for sx in [-1.0, 1.0]:
				var p := Vector2(sx * cos(a) * r * 0.68, sin(a) * r * 0.68)
				draw_circle(p, r * 0.055, Color(ink, 0.85))
