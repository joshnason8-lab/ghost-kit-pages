extends Control
## Language, graphics, camera, sound and control options.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_SETTINGS"), func(): Game.goto_menu())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	v.add_child(UI.scroll(body))

	var names := []
	var codes := []
	for pair in Game.LANGUAGES:
		codes.append(pair[0])
		names.append(pair[1])
	body.add_child(UI.field(tr("LANGUAGE"), UI.chips(names, codes.find(Game.settings.language), func(i):
		Game.set_language(codes[i])
		# Rebuild so every label picks up the new language.
		Game.show_screen("res://ui/settings_screen.gd"))))

	body.add_child(UI.field(tr("GRAPHICS"), UI.chips([tr("GFX_LOW"), tr("GFX_MEDIUM"), tr("GFX_HIGH")], int(Game.settings.graphics), func(i):
		Game.settings.graphics = i
		Game.save_settings())))
	if RiggedBody.available():
		body.add_child(UI.field(tr("SET_MODELS"), UI.chips([tr("MODELS_CLASSIC"), tr("MODELS_REAL")], int(Game.settings.get("models", 1)), func(i):
			Game.settings.models = i
			Game.save_settings())))
	body.add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_THIRD"), tr("CAM_FIRST"), tr("CAM_TV")], int(Game.settings.camera), func(i):
		Game.settings.camera = i
		Game.save_settings())))
	body.add_child(UI.difficulty_field(self))
	body.add_child(UI.field(tr("MATCH_LENGTH"), UI.chips([tr("LENGTH_SHORT"), tr("LENGTH_MEDIUM"), tr("LENGTH_FULL")], int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))
	body.add_child(UI.field(tr("CANT"), UI.chips([tr("CANT_TAP"), tr("CANT_AUTO")], int(Game.settings.get("cant", 0)), func(i):
		Game.settings.cant = i
		Game.save_settings())))

	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 40)
	for key in ["sound", "vibration", "left_handed"]:
		var k: String = key
		var title = {"sound": "SOUND", "vibration": "VIBRATION", "left_handed": "LEFT_HANDED"}[k]
		toggles.add_child(UI.field(tr(title), UI.chips([tr("ON"), tr("OFF")], 0 if Game.settings[k] else 1, func(i):
			Game.settings[k] = i == 0
			Game.save_settings()
			if k == "sound" and i == 1:
				Sfx.stop_all())))
	body.add_child(toggles)
	body.add_child(UI.wrap(tr("PLACEHOLDER_NOTE"), "MutedLabel"))
