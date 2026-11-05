class_name LanguagePicker
extends Control
## The language picker the main menu opens over itself: the phone's language first, then each
## language by its own name with the English name under it. Tap outside, ✕ or Back closes it.

signal picked

var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = "CardPanel"
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	_card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var gl := Icon.make("globe", 34, Game.C_SAFFRON)
	gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gl)
	var title := UI.label(tr("LANGUAGE"), "HeaderLabel", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.round_button("close", close, 52))

	var cur := String(Game.settings.language)
	v.add_child(_choice("", tr("LANG_PHONE"), Game.language_names(Game.phone_language())[0], cur == "", true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	for pair in Game.LANGUAGES:
		grid.add_child(_choice(pair[0], pair[1], pair[2] if pair[2] != pair[1] else "", cur == pair[0]))

	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _choice(code: String, title: String, sub: String, on: bool, wide := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 72) if wide else Vector2(200, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL_HI, 0.8)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	if on:
		sb.bg_color = Color(Game.C_SAFFRON, 0.18)
		sb.border_color = Game.C_SAFFRON
		sb.set_border_width_all(3)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(Game.C_SAFFRON, 0.26)
	sbh.border_color = Game.C_SAFFRON
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -16
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", -2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	if wide:
		# The phone's language: "Phone language" and, beside it, what that is.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UI.label(title, "SubLabel", 24))
		var what := UI.label(sub, "SubLabel", 22, Game.C_GOLD)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(what)
		tv.add_child(row)
	else:
		tv.add_child(UI.label(title, "SubLabel", 28))
		if sub != "":
			tv.add_child(UI.label(sub, "MutedLabel", 16))
	if on:
		var ck := Icon.make("check", 26, Game.C_SAFFRON)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ck)
	b.pressed.connect(func():
		Sfx.click()
		Game.set_language(code)
		picked.emit()
		close())
	return b
