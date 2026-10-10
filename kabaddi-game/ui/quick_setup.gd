extends Control
## Quick match: the two teams face off across the screen, the grounds are picture cards,
## and Play is one big button.

var source := 0   # 0 league, 1 countries
var home := "MUM"
var away := "DEL"
var arena := "dome"
var _teams_row: HBoxContainer
var _ground_cards := {}


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_QUICK"), func(): Game.goto_menu())
	var right: HBoxContainer = get_meta("header_right")
	var src := UI.chips_row([tr("LEAGUE_NAME"), tr("TEAMS_COUNTRIES")], source, func(i):
		source = i
		var ids := _ids()
		home = ids[0]
		away = ids[1]
		arena = "dome" if i == 0 else "stadium"
		_rebuild_teams()
		_mark_ground())
	right.add_child(src)

	_teams_row = HBoxContainer.new()
	_teams_row.add_theme_constant_override("separation", 18)
	_teams_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_teams_row)
	_rebuild_teams()

	# Grounds as picture cards.
	var grounds := HBoxContainer.new()
	grounds.add_theme_constant_override("separation", 12)
	grounds.custom_minimum_size = Vector2(0, 118)
	for a in DB.ARENAS:
		var card := _ground_card(String(a.id), tr(a.name))
		grounds.add_child(card)
		_ground_cards[String(a.id)] = card
	v.add_child(grounds)
	_mark_ground()

	# Length, difficulty and Play.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 26)
	foot.add_child(UI.field(tr("MATCH_LENGTH"), UI.chips_row([tr("LEN_SHORT_S"), tr("LEN_MEDIUM_S"), tr("LEN_FULL_S")], int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))
	var keys := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_PRO", "DIFF_LEGEND"]
	var dn := []
	for k in keys:
		dn.append(tr(k))
	foot.add_child(UI.field(tr("DIFFICULTY"), UI.chips_row(dn, int(Game.settings.difficulty), func(i):
		Game.settings.difficulty = i
		Game.save_settings())))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var play := UI.button(tr("PLAY"), true, _play)
	play.custom_minimum_size = Vector2(300, 76)
	play.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(play)
	v.add_child(foot)


func _ids() -> Array:
	return DB.league_ids if source == 0 else DB.country_ids


func _rebuild_teams() -> void:
	for c in _teams_row.get_children():
		c.queue_free()
	_teams_row.add_child(_team_card(home, tr("YOUR_TEAM"), true))
	var vs := UI.label(tr("VS"), "TitleLabel", 64, Game.C_SAFFRON)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_teams_row.add_child(vs)
	_teams_row.add_child(_team_card(away, tr("OPPONENT"), false))


## One side: crest, name and rating, with arrows to change team.
func _team_card(id: String, role: String, mine: bool) -> PanelContainer:
	var t := DB.team(id)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	var c1: Color = t.c1
	sb.bg_color = Color(c1.darkened(0.7).lerp(Game.C_PANEL, 0.3), 0.95)
	sb.set_corner_radius_all(20)
	sb.border_color = Color(c1, 0.8)
	sb.border_width_bottom = 6
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var prev := UI.round_button("back", func(): _cycle(mine, -1), 52)
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(prev)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 18)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	var crest := Crest.make(id, 130)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(crest)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(role.to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON if mine else Game.C_MUTED))
	var nm := UI.label(DB.team_name(id), "HeaderLabel", 40)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(nm)
	var sub := "%s %d" % [tr("RATING"), DB.team_rating(t.squad)]
	if t.has("state") and String(t.get("state", "")) != "":
		sub += " · " + tr(String(t.state))
	info.add_child(UI.label(sub, "MutedLabel", 17))
	# The stars of the side.
	var seven: Array = DB.starting_seven(t.squad.duplicate())
	seven.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
	var stars := VBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	for k in mini(3, seven.size()):
		var pl: Dictionary = seven[k]
		var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}.get(String(pl.role), "ROLE_RAIDER")
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var ov := UI.label(str(DB.overall(pl)), "SubLabel", 17, Game.C_GOLD)
		ov.custom_minimum_size = Vector2(28, 0)
		line.add_child(ov)
		line.add_child(UI.label(String(pl.name), "", 17))
		line.add_child(UI.label(tr(role_key), "MutedLabel", 15))
		stars.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	info.add_child(gap)
	info.add_child(stars)
	mid.add_child(info)
	var nxt := UI.round_button("next", func(): _cycle(mine, 1), 52)
	nxt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nxt)
	return p


func _cycle(mine: bool, d: int) -> void:
	var ids := _ids()
	var cur := home if mine else away
	var other := away if mine else home
	var i := ids.find(cur)
	for k in ids.size():
		i = (i + d + ids.size()) % ids.size()
		if ids[i] != other:
			break
	if mine:
		home = ids[i]
	else:
		away = ids[i]
	_rebuild_teams()


func _ground_card(id: String, name: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PANEL
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var path := "res://assets/ui/ground_%s.jpg" % id
	if ResourceLoader.exists(path):
		var img := TextureRect.new()
		img.texture = load(path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(img)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -38
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade)
	var l := UI.label(name, "SubLabel", 18)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -36
	l.offset_left = 12
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.set_corner_radius_all(14)
	rs.border_color = Game.C_SAFFRON
	rs.set_border_width_all(4)
	ring.add_theme_stylebox_override("panel", rs)
	ring.name = "Ring"
	b.add_child(ring)
	b.pressed.connect(func():
		Sfx.click()
		arena = id
		_mark_ground())
	return b


func _mark_ground() -> void:
	for id in _ground_cards:
		var card: Button = _ground_cards[id]
		card.get_node("Ring").visible = id == arena
		card.modulate = Color.WHITE if id == arena else Color(0.75, 0.75, 0.8)


func _play() -> void:
	if home == away:
		var ids := _ids()
		away = ids[(ids.find(home) + 1) % ids.size()]
	Game.start_match({
		"home": home, "away": away, "arena": arena, "mode": "quick", "control": "all",
		"length": int(Game.settings.length), "difficulty": int(Game.settings.difficulty), "knockout": false,
	})
