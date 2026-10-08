extends Control
## Training Ground: short lessons for each move.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_TRAINING"), func(): Game.goto_menu(), tr("TRAINING_EYEBROW"))
	var done: Array = Game.settings.get("tutorial_done", [])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	for l in Tutorial.LESSONS:
		var id: String = l.id
		var b := Button.new()
		b.custom_minimum_size = Vector2(540, 96)
		b.pressed.connect(func():
			Sfx.click()
			Game.start_match(Tutorial.match_config(id)))
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 20
		h.offset_right = -16
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tick := UI.label("✓" if done.has(id) else "•", "HeaderLabel", 40, Game.C_GOOD if done.has(id) else Game.C_MUTED)
		tick.custom_minimum_size = Vector2(36, 0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tick)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UI.label(tr(l.title), "SubLabel", 24)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var first_step: Array = l.steps[0]
		var d := UI.label(tr(first_step[0]), "MutedLabel", 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		col.add_child(d)
		h.add_child(col)
		var side := UI.label(tr("ROLE_RAIDER") if l.raid else tr("HUD_DEFEND"), "EyebrowLabel", 14, Game.C_SAFFRON if l.raid else Game.C_MAGENTA)
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(side)
		b.add_child(h)
		grid.add_child(b)
	v.add_child(UI.scroll(grid))
	v.add_child(UI.wrap(tr("HOW_CONTROLS"), "MutedLabel", 18))
