extends Control
## International: pick a tournament (the World Championship, the Royal Cup, the Asian or the Southeast Asian Championship),
## men's or women's, the regu or the team event, and your country; then the tournament's home: the two groups, your
## next match, the knockouts, and the medals.

var _kind := "world"
var _women := false
var _event := "regu"


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var c = Game.get_cup()
	if c == null:
		_choose()
	else:
		_hub(c)


func _choose() -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("NEW_TOURNAMENT"))
	var parts := UI.pick_layout(v, tr("PICK_COUNTRY"))
	var left: VBoxContainer = parts[0]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	for k in ["world", "royal", "asia", "sea"]:
		var kind: String = k
		var name := String(Cup.KINDS[kind].name)
		list.add_child(UI.option_card(tr(name), tr(name + "_DESC") if kind == _kind else "", Icon.make("trophy", 40, Game.C_GOLD if kind == _kind else Game.C_MUTED),
			kind == _kind, func():
				_kind = kind
				_refresh()))
	left.add_child(UI.scroll(list))
	var evs := ["regu", "team"]
	(parts[1] as HBoxContainer).add_child(UI.chips_row([tr("EVENT_REGU"), tr("EVENT_TEAM")], evs.find(_event), func(i):
		_event = evs[i]))
	(parts[1] as HBoxContainer).add_child(UI.chips_row([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_refresh()))
	# The countries that take part in this event (the strongest first): no United States at the Asian Championship.
	var field: Array = Cup.KINDS[_kind].field
	var ids := DB.countries_ranked(_women).filter(func(id): return id in field)
	var grid := UI.team_grid(self, ids, 2, func(id):
		Game.new_cup(_kind, id, _women, _event)
		Game.show_screen("res://ui/cup_screen.gd"))
	(parts[2] as VBoxContainer).add_child(UI.scroll(grid))


func _refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	UI.screen(self)
	_choose()


func _hub(c: Cup) -> void:
	var v := UI.page(self, c.title(), func(): Game.goto_menu(), c.stage_name())
	var right: HBoxContainer = get_meta("header_right")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	for g in 2:
		var card := UI.card()
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UI.label(tr("GROUP_N").format({"g": ["A", "B"][g]}).to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
		cv.add_child(UI.table(self, c.group_table(g), c.user, true, 2))
		left.add_child(card)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(side)
	if c.stage == "done":
		var mc := UI.card()
		var mv := VBoxContainer.new()
		mv.add_theme_constant_override("separation", 8)
		mc.add_child(mv)
		var medal := c.user_medal()
		mv.add_child(UI.label((tr("MEDAL_" + medal.to_upper()) if medal != "" else tr("NO_MEDAL")).to_upper(), "EyebrowLabel", 16, Game.C_GOLD))
		for pair in [["MEDAL_GOLD", [c.medals.get("gold", "")]], ["MEDAL_SILVER", [c.medals.get("silver", "")]], ["MEDAL_BRONZE", c.medals.get("bronze", [])]]:
			for id in pair[1]:
				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 10)
				h.add_child(Icon.make("trophy", 26, {"MEDAL_GOLD": Game.C_GOLD, "MEDAL_SILVER": Color("c9d1db"), "MEDAL_BRONZE": Color("cd8a4e")}[pair[0]]))
				h.add_child(Crest.make(String(id), 30))
				var nm := UI.fit(UI.label(DB.team_name(String(id)), "SubLabel", 20))
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(nm)
				mv.add_child(h)
		side.add_child(mc)
		right.add_child(UI.button(tr("NEW_TOURNAMENT"), true, func():
			Game.delete_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
		return
	var f := c.next_fixture()
	if not f.is_empty():
		var card := UI.card()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(UI.label(tr("NEXT_MATCH").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
		cv.add_child(UI.fixture_line(self, f, c.user))
		cv.add_child(UI.label(tr(DB.venue(c.venue())[1]), "MutedLabel", 17))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var stage := {"group": tr("GROUP_STAGE"), "semi": tr("SEMI_FINAL"), "final": tr("FINAL")}.get(c.stage, "") as String
		row.add_child(UI.button(tr("PLAY"), true, func():
			Game.start_match({"home": f.home, "away": f.away, "venue": c.venue(), "event": c.event, "sets": 3, "points": 15,
				"difficulty": int(Game.settings.difficulty), "mode": "cup", "user_team": 0 if f.home == c.user else 1,
				"women": c.women, "stage": stage})))
		row.add_child(UI.button(tr("SIM_MATCH"), false, func():
			c.sim_next()
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
		cv.add_child(row)
		side.add_child(card)
	else:
		side.add_child(UI.wrap(tr("OUT_OF_CUP"), "SubLabel", 22))
		side.add_child(UI.button(tr("SIM_REST"), true, func():
			while c.stage != "done":
				c.sim_next()
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	var ko := UI.card()
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 6)
	ko.add_child(kv)
	for fx in c.fixtures:
		if fx.stage != "group":
			kv.add_child(UI.label(tr("SEMI_FINAL" if fx.stage == "semi" else "FINAL").to_upper(), "EyebrowLabel", 14))
			kv.add_child(UI.fixture_line(self, fx, c.user))
	if kv.get_child_count() > 0:
		side.add_child(ko)
	right.add_child(UI.button(tr("ABANDON"), false, func():
		Game.delete_cup()
		Game.show_screen("res://ui/cup_screen.gd")))
