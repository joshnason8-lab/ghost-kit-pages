extends Control
## Quick Match: two teams (clubs or countries, men or women), the event, the venue, how long, and how hard.

var _kind := "country"     # "country" or a league id ("MY", "TH", "ID")
var _women := false
var _home := "THA"
var _away := "MAS"
var _venue := "national"
var _body: VBoxContainer
var _vs: HBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_QUICK"), func(): Game.goto_menu())
	var play := UI.button(tr("PLAY"), true, _play)
	play.custom_minimum_size = Vector2(240, 66)
	(get_meta("header_right") as HBoxContainer).add_child(play)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(_body))
	_build()


func _ids() -> Array:
	if _kind == "country":
		return DB.countries_ranked(_women)
	return DB.league_clubs(_kind)


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	_body.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	# The teams.
	var teams: Array = UI.section(tr("TEAMS"), "people")
	left.add_child(teams[0])
	var kinds := ["country", "MY", "TH", "ID"]
	teams[1].add_child(UI.chips([tr("TEAMS_COUNTRIES"), tr("LEAGUE_MY"), tr("LEAGUE_TH"), tr("LEAGUE_ID")], kinds.find(_kind), func(i):
		_kind = kinds[i]
		var ids := _ids()
		_home = ids[0]
		_away = ids[1]
		_build()))
	teams[1].add_child(UI.chips([tr("MEN"), tr("WOMEN")], 1 if _women else 0, func(i):
		_women = i == 1
		_build()))
	var ids := _ids()
	if not (_home in ids):
		_home = ids[0]
	if not (_away in ids) or _away == _home:
		_away = ids[1] if ids[0] == _home else ids[0]
	teams[1].add_child(UI.field(tr("YOUR_TEAM"), UI.team_picker(ids, _home, func(id):
		_home = id
		if _away == _home:
			_away = ids[0] if ids[0] != _home else ids[1]
		_build())))
	teams[1].add_child(UI.field(tr("OPPONENT"), UI.team_picker(ids, _away, func(id):
		_away = id
		if _away == _home:
			_home = ids[0] if ids[0] != _away else ids[1]
		_build())))
	_vs = HBoxContainer.new()
	_vs.alignment = BoxContainer.ALIGNMENT_CENTER
	_vs.add_theme_constant_override("separation", 20)
	for id in [_home, _away]:
		var c := VBoxContainer.new()
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		var cr := Crest.make(id, 64)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(cr)
		var r := UI.label(tr("RATING") + " %d" % int(DB.team_rating(id, _women)), "MutedLabel", 16)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(r)
		_vs.add_child(c)
		if id == _home:
			_vs.add_child(UI.label(tr("VS"), "HeaderLabel", 40, Game.C_MUTED))
	teams[1].add_child(_vs)

	# The event and the match.
	var ev: Array = UI.section(tr("EVENT"), "whistle")
	right.add_child(ev[0])
	var events := ["regu", "team", "quadrant", "doubles"]
	var ev_note := UI.wrap(tr("EVENT_NOTE_" + events[int(Game.settings.event)].to_upper()), "MutedLabel", 17)
	ev[1].add_child(UI.chips([tr("EVENT_REGU"), tr("EVENT_TEAM"), tr("EVENT_QUADRANT"), tr("EVENT_DOUBLES")], clampi(int(Game.settings.event), 0, 3), func(i):
		Game.settings.event = i
		Game.save_settings()
		ev_note.text = tr("EVENT_NOTE_" + events[i].to_upper())))
	ev[1].add_child(ev_note)
	ev[1].add_child(UI.field(tr("MATCH_LENGTH"), UI.chips([tr("SETS_ONE"), tr("SETS_THREE")], int(Game.settings.sets), func(i):
		Game.settings.sets = i
		Game.save_settings())))
	ev[1].add_child(UI.field(tr("SET_POINTS"), UI.chips([tr("POINTS_15"), tr("POINTS_21")], int(Game.settings.points), func(i):
		Game.settings.points = i
		Game.save_settings())))
	ev[1].add_child(UI.difficulty_field(self))

	# The venue.
	var ven: Array = UI.section(tr("VENUE"), "flag")
	right.add_child(ven[0])
	var vnames := []
	var vids := []
	for vv in DB.VENUES:
		vids.append(vv[0])
		vnames.append(tr(vv[1]))
	var vnote := UI.wrap(tr(DB.venue(_venue)[1] + "_DESC"), "MutedLabel", 17)
	ven[1].add_child(UI.chips(vnames, vids.find(_venue), func(i):
		_venue = vids[i]
		vnote.text = tr(DB.venue(_venue)[1] + "_DESC")))
	ven[1].add_child(vnote)


func _play() -> void:
	var events := ["regu", "team", "quadrant", "doubles"]
	Game.start_match({
		"home": _home, "away": _away, "venue": _venue, "event": events[clampi(int(Game.settings.event), 0, 3)],
		"sets": 3 if int(Game.settings.sets) == 1 else 1, "points": 21 if int(Game.settings.points) == 1 else 15,
		"difficulty": int(Game.settings.difficulty), "mode": "quick", "user_team": 0, "women": _women,
	})
