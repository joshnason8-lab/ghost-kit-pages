extends Control
## Quick match: pick teams, ground, length, difficulty and camera.

var source := 0   # 0 league, 1 countries
var home := "MUM"
var away := "DEL"
var arena := "dome"
var _body: VBoxContainer
var _pickers: HBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_QUICK"), func(): Game.goto_menu())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	v.add_child(UI.scroll(_body))

	_body.add_child(UI.field(tr("TEAMS_LEAGUE") + " / " + tr("TEAMS_COUNTRIES"), UI.chips([tr("LEAGUE_NAME"), tr("TEAMS_COUNTRIES")], source, func(i):
		source = i
		var ids := DB.league_ids if i == 0 else DB.country_ids
		home = ids[0]
		away = ids[1]
		arena = "dome" if i == 0 else "stadium"
		_rebuild_pickers())))

	_pickers = HBoxContainer.new()
	_pickers.add_theme_constant_override("separation", 24)
	_body.add_child(_pickers)
	_rebuild_pickers()

	var arena_names := []
	var arena_ids := []
	for a in DB.ARENAS:
		arena_names.append(tr(a.name))
		arena_ids.append(a.id)
	var arena_desc := UI.label(tr(DB.ARENAS[0].desc), "MutedLabel")
	_body.add_child(UI.field(tr("ARENA"), UI.chips(arena_names, arena_ids.find(arena), func(i):
		arena = arena_ids[i]
		arena_desc.text = tr(DB.ARENAS[i].desc))))
	_body.add_child(arena_desc)

	_body.add_child(UI.field(tr("MATCH_LENGTH"), UI.chips([tr("LENGTH_SHORT"), tr("LENGTH_MEDIUM"), tr("LENGTH_FULL")], int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))
	_body.add_child(UI.difficulty_field(self))
	_body.add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_THIRD"), tr("CAM_FIRST"), tr("CAM_TV")], int(Game.settings.camera), func(i):
		Game.settings.camera = i
		Game.save_settings())))

	var play := UI.button(tr("PLAY"), true, _play)
	play.custom_minimum_size = Vector2(320, 70)
	play.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(play)


func _rebuild_pickers() -> void:
	for c in _pickers.get_children():
		c.queue_free()
	var ids := DB.league_ids if source == 0 else DB.country_ids
	_pickers.add_child(UI.field(tr("YOUR_TEAM"), UI.team_picker(ids, home, func(id): home = id)))
	var vs := UI.label(tr("VS"), "HeaderLabel")
	vs.size_flags_vertical = Control.SIZE_SHRINK_END
	_pickers.add_child(vs)
	_pickers.add_child(UI.field(tr("OPPONENT"), UI.team_picker(ids, away, func(id): away = id)))


func _play() -> void:
	if home == away:
		var ids := DB.league_ids if source == 0 else DB.country_ids
		away = ids[(ids.find(home) + 1) % ids.size()]
	Game.start_match({
		"home": home, "away": away, "arena": arena, "mode": "quick", "control": "all",
		"length": int(Game.settings.length), "difficulty": int(Game.settings.difficulty), "knockout": false,
	})
