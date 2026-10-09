extends Control
## Settings, grouped into cards: the game, the raid rule, the screen, sound and controls.

const RULE_KEYS := ["RULE_CLOCK", "RULE_CANT_TAP", "RULE_CANT_AUTO"]
const RULE_NOTES := ["RULE_CLOCK_NOTE", "RULE_TAP_NOTE", "RULE_BREATH_NOTE"]

var _rule_note: Label


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_SETTINGS"), func(): Game.goto_menu())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 20)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	v.add_child(UI.scroll(cols))

	# The game.
	var game: Array = UI.section(tr("SET_GAME"), "flag")
	left.add_child(game[0])
	var names := []
	var codes := []
	for pair in Game.LANGUAGES:
		codes.append(pair[0])
		names.append(pair[1])
	game[1].add_child(UI.field(tr("LANGUAGE"), UI.chips(names, codes.find(Game.settings.language), func(i):
		Game.set_language(codes[i])
		# Rebuild so every label picks up the new language.
		Game.show_screen("res://ui/settings_screen.gd"))))
	game[1].add_child(UI.difficulty_field(self))
	game[1].add_child(UI.field(tr("MATCH_LENGTH"), UI.chips([tr("LENGTH_SHORT"), tr("LENGTH_MEDIUM"), tr("LENGTH_FULL")], int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))

	# The raid rule, with what each one means.
	var rule: Array = UI.section(tr("RAID_RULE"), "whistle")
	left.add_child(rule[0])
	var rnames := []
	for k in RULE_KEYS:
		rnames.append(tr(k))
	var cur := clampi(int(Game.settings.get("raid_rule", 2)), 0, 2)
	rule[1].add_child(UI.chips(rnames, cur, func(i):
		Game.settings.raid_rule = i
		Game.save_settings()
		_rule_note.text = tr(RULE_NOTES[i])))
	_rule_note = UI.wrap(tr(RULE_NOTES[cur]), "MutedLabel", 17)
	rule[1].add_child(_rule_note)
	left.move_child(rule[0], 0)   # the raid rule matters most: put it first

	# The screen.
	var disp: Array = UI.section(tr("SET_DISPLAY"), "display")
	right.add_child(disp[0])
	disp[1].add_child(UI.field(tr("GRAPHICS"), UI.chips([tr("GFX_LOW"), tr("GFX_MEDIUM"), tr("GFX_HIGH")], int(Game.settings.graphics), func(i):
		Game.settings.graphics = i
		Game.save_settings())))
	disp[1].add_child(_toggle("auto_gfx", "GFX_AUTO"))
	if RiggedBody.available():
		disp[1].add_child(UI.field(tr("SET_MODELS"), UI.chips([tr("MODELS_CLASSIC"), tr("MODELS_REAL")], int(Game.settings.get("models", 1)), func(i):
			Game.settings.models = i
			Game.save_settings())))
	var cams := [Game.CAM_THIRD, Game.CAM_TV]
	disp[1].add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_THIRD"), tr("CAM_TV")], maxi(0, cams.find(int(Game.settings.camera))), func(i):
		Game.settings.camera = cams[i]
		Game.save_settings())))

	# Sound and controls.
	var snd: Array = UI.section(tr("SET_SOUND_CONTROLS"), "sound")
	right.add_child(snd[0])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 36)
	row.add_theme_constant_override("v_separation", 14)
	for key in ["sound", "vibration", "left_handed"]:
		row.add_child(_toggle(key, {"sound": "SOUND", "vibration": "VIBRATION", "left_handed": "LEFT_HANDED"}[key]))
	snd[1].add_child(row)
	right.add_child(UI.wrap(tr("PLACEHOLDER_NOTE"), "MutedLabel", 15))


func _toggle(key: String, title_key: String) -> VBoxContainer:
	return UI.field(tr(title_key), UI.chips([tr("ON"), tr("OFF")], 0 if Game.settings[key] else 1, func(i):
		Game.settings[key] = i == 0
		Game.save_settings()
		if key == "sound" and i == 1:
			Sfx.stop_all()))
