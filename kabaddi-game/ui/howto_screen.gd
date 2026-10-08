extends Control
## Rules and controls.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HOW_TITLE"), func(): Game.goto_menu())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	var items := [
		["MENU_QUICK", "HOW_RAID"], ["CANT", "HOW_CANT"], ["HUD_DEFEND", "HOW_DEFEND"], ["BTN_CHAIN", "HOW_CHAIN"], ["EV_BONUS", "HOW_BONUS"],
		["HUD_DOD", "HOW_DOD"], ["EV_ALL_OUT", "HOW_ALLOUT"], ["EV_REVIVED", "HOW_REVIVE"], ["CAMERA", "HOW_CONTROLS"],
	]
	for it in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var dot := UI.swatch(Game.C_SAFFRON, Vector2(6, 0))
		dot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(dot)
		var text := UI.wrap(tr(it[1]), "", 22)
		row.add_child(text)
		body.add_child(row)
	Game.settings.seen_howto = true
	Game.save_settings()
