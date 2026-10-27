extends Control
## Match setup, laid out as the day at the court is: first the court, four places each with its game (ulama de
## cadera on the earth courts; the classic stone court, reconstructed); the court drawn from above, to scale; then the
## two towns facing each other across the analco, each with its faja's colours and its players by place; then how many a
## side, the count's urria, how long, and how good the other town is. Watch a match: the same, both towns played by the
## computer.

var _home := "ESC"
var _away := "LLA"
var _venue := "village"
var _watch := false
var _body: VBoxContainer


func setup(args: Dictionary) -> void:
	_watch = bool(args.get("watch", false))


func _ready() -> void:
	UI.screen(self)
	_venue = String(Game.settings.get("venue", "village"))
	if not DB.VENUES.has(_venue):
		_venue = "village"
	_pick_teams()
	var v := UI.page(self, tr("MENU_WATCH") if _watch else tr("MENU_QUICK"), func(): Game.goto_menu(), tr("SETUP_EYEBROW"))
	var play := UI.button(tr("TO_THE_COURT"), true, _play)
	play.custom_minimum_size = Vector2(240, 64)
	(get_meta("header_right") as HBoxContainer).add_child(play)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(_body))
	_build()


func _rules() -> String:
	return String(DB.venue(_venue).rules)


## The towns that suit the court, if the ones chosen do not.
func _pick_teams() -> void:
	var ids: Array = DB.teams_for(_rules())
	if not (_home in ids):
		_home = ids[0]
	if _away == _home:
		_away = ids[1]


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	# The courts.
	var courts := HBoxContainer.new()
	courts.add_theme_constant_override("separation", 12)
	_body.add_child(courts)
	for id in DB.VENUE_ORDER:
		var r := String(DB.venue(id).rules)
		var card := UI.option_card(tr("VENUE_" + id.to_upper()), tr("RULES_NAME_" + r.to_upper()), null, id == _venue, func():
			var was := _rules()
			_venue = id
			Game.settings.venue = id
			if _rules() != was:
				Game.settings.mode = _rules()
				var ids: Array = DB.teams_for(_rules())
				_home = ids[0]
				_away = ids[1]
			Game.save_settings()
			_build())
		courts.add_child(card)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	_body.add_child(mid)
	mid.add_child(_team_card(0))
	var diagram := CourtDiagram.new()
	diagram.custom_minimum_size = Vector2(360, 200)
	diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram.size_flags_stretch_ratio = 1.2
	diagram.set_court(_rules(), DB.team(_home).c1, DB.team(_away).c1)
	mid.add_child(diagram)
	mid.add_child(_team_card(1))
	# The options.
	var opts: Array = UI.section(tr("MATCH_OPTIONS"), "gavel")
	_body.add_child(opts[0])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 28)
	flow.add_theme_constant_override("v_separation", 14)
	opts[1].add_child(flow)
	var sizes: Array = Rules.side_sizes(_rules())
	var key := "side_" + _rules()
	var cur := int(Game.settings.get(key, Rules.default_side(_rules())))
	if not (cur in sizes):
		cur = Rules.default_side(_rules())
	var snames := []
	for n in sizes:
		snames.append(Plural.word("PLAYERS_A_SIDE", n))
	flow.add_child(UI.field(tr("SIDE_SIZE"), UI.chips(snames, sizes.find(cur), func(i):
		Game.settings[key] = sizes[i]
		Game.save_settings())))
	if _rules() == Rules.ULAMA:
		var uk := ["3_7", "3_5_7", "none"]
		var un := [tr("URRIA_3_7"), tr("URRIA_3_5_7"), tr("URRIA_NONE")]
		flow.add_child(UI.field(tr("URRIA"), UI.chips(un, maxi(0, uk.find(String(Game.settings.get("urria", "3_7")))), func(i):
			Game.settings.urria = uk[i]
			Game.save_settings())))
	var lens := []
	for n in Game.LENGTHS:
		lens.append(tr("MINUTES_N").format({"n": n}) if n > 0 else tr("TO_EIGHT"))
	flow.add_child(UI.field(tr("MATCH_LENGTH"), UI.chips(lens, int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))
	if not _watch:
		opts[1].add_child(UI.difficulty_field(self))
	opts[1].add_child(UI.wrap(tr("RULES_NOTE_" + _rules().to_upper()), "MutedLabel", 16))
	opts[1].add_child(UI.wrap(tr("LENGTH_NOTE"), "MutedLabel", 16))


## A town: its name and nickname, its faja, its players by their places; arrows to change it.
func _team_card(k: int) -> Control:
	var id := _home if k == 0 else _away
	var t := DB.team(id)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PAPER
	sb.set_corner_radius_all(6)
	sb.border_color = t.c1
	sb.border_width_top = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var role := tr("YOUR_TOWN") if k == 0 and not _watch else tr("RIVAL_TOWN")
	var eb := UI.label(role.to_upper(), "EyebrowLabel", 14, Color(Game.C_PRINT, 0.65))
	UI.fit(eb, 1)
	v.add_child(eb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(_arrow("back", k, -1))
	head.add_child(Colours.make(id, 40))
	var name := UI.label(String(t.town), "HeaderLabel", 30, Game.C_PRINT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.fit(name, 2)
	head.add_child(name)
	head.add_child(_arrow("next", k, 1))
	var sub := UI.label(UI.bits([String(t.nick), String(t.region)]), "MutedLabel", 16, Color(Game.C_PRINT, 0.75))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.fit(sub, 2)
	v.add_child(sub)
	var n := int(Game.settings.get("side_" + _rules(), Rules.default_side(_rules())))
	if not (n in Rules.side_sizes(_rules())):
		n = Rules.default_side(_rules())
	var roster := DB.roster(id, n)
	var ai := TeamAI.new(null, k, roster, 1, 1)
	for i in roster.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var rl := UI.label(tr("ROLE_" + ai.role_of(i).to_upper()), "", 14, Color(Game.C_PRINT, 0.6))
		rl.custom_minimum_size = Vector2(92, 0)
		UI.fit(rl, 1)
		row.add_child(rl)
		var pn := UI.label(String(roster[i].name), "SubLabel", 16, Game.C_PRINT)
		pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.fit(pn, 1)
		row.add_child(pn)
	return card


func _arrow(icon: String, k: int, step: int) -> Button:
	return UI.round_button(icon, func():
		var ids: Array = DB.ids()
		var cur := _home if k == 0 else _away
		var other := _away if k == 0 else _home
		var i := ids.find(cur)
		for n in ids.size():
			i = (i + step + ids.size()) % ids.size()
			if ids[i] != other:
				break
		if k == 0:
			_home = ids[i]
		else:
			_away = ids[i]
		_build(), 44)


func _play() -> void:
	var r := _rules()
	var n := int(Game.settings.get("side_" + r, Rules.default_side(r)))
	Game.start_match({"home": _home, "away": _away, "venue": _venue, "rules": r, "side": n, "mode": "watch" if _watch else "quick",
		"user_team": -1 if _watch else 0, "difficulty": int(Game.settings.difficulty), "urria": String(Game.settings.get("urria", "3_7")),
		"length": Game.LENGTHS[int(Game.settings.length)], "stage": tr("FRIENDLY")})
