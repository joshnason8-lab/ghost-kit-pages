class_name WsgSettingsScreen
extends Control
## The common Settings screen (WsgSettings.screen()). Each change is saved and applied; applied(key, value) tells the
## game (a new tier: rebuild what it built from it).

signal applied(key: String, value: Variant)
signal back

var theme_b: WsgBroadcastTheme
var opts := {}
## The controls by key (a test presses them).
var controls := {}


func _init(p_theme: WsgBroadcastTheme, p_opts := {}) -> void:
	theme_b = p_theme
	opts = p_opts
	name = "WsgSettings"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)
	col.add_child(theme_b.label(tr(str(opts.get("title", "Settings"))), theme_b.title_size, theme_b.accent))
	# Graphics.
	col.add_child(theme_b.label(tr("Graphics"), theme_b.sub_size, theme_b.sub_text))
	var g := HBoxContainer.new()
	col.add_child(g)
	var group := ButtonGroup.new()
	var tiers := []
	for t in 3:
		var b := _button(g, [tr("Low"), tr("Medium"), tr("High")][t])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = WsgFoundation.tier == t
		b.pressed.connect(_apply.bind("graphics", t))
		tiers.append(b)
	controls["graphics"] = tiers
	# Sound.
	for bus in opts.get("buses", []):
		col.add_child(theme_b.label(tr(str(bus)), theme_b.sub_size, theme_b.sub_text))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(280, 40)
		sl.value = float(WsgSettings.get_value("volume_" + str(bus), 1.0))
		sl.value_changed.connect(func(v: float): _apply("volume_" + str(bus), v))
		col.add_child(sl)
		controls["volume_" + str(bus)] = sl
	# The joystick.
	if opts.get("joystick", true):
		col.add_child(theme_b.label(tr("Joystick"), theme_b.sub_size, theme_b.sub_text))
		var j := HBoxContainer.new()
		col.add_child(j)
		var side := _button(j, "")
		var upd := func(): side.text = tr("On the left") if WsgSettings.get_value("joystick_side") == "left" else tr("On the right")
		upd.call()
		side.pressed.connect(func():
			_apply("joystick_side", "right" if WsgSettings.get_value("joystick_side") == "left" else "left")
			upd.call())
		controls["joystick_side"] = side
		var size := HSlider.new()
		size.min_value = 0.7
		size.max_value = 1.4
		size.step = 0.05
		size.custom_minimum_size = Vector2(200, 40)
		size.value = float(WsgSettings.get_value("joystick_size", 1.0))
		size.value_changed.connect(func(v: float): _apply("joystick_size", v))
		j.add_child(size)
		controls["joystick_size"] = size
	# Haptics.
	var h := CheckButton.new()
	h.text = tr("Vibration")
	h.button_pressed = bool(WsgSettings.get_value("haptics", true))
	h.add_theme_font_size_override("font_size", theme_b.sub_size)
	h.add_theme_color_override("font_color", theme_b.text)
	h.toggled.connect(func(on: bool):
		_apply("haptics", on)
		if on:
			WsgHaptics.play("tap"))
	col.add_child(h)
	controls["haptics"] = h
	var bk := _button(col, tr("Back"))
	bk.pressed.connect(func(): back.emit())
	controls["back"] = bk


func _apply(key: String, v: Variant) -> void:
	WsgSettings.set_value(key, v)
	applied.emit(key, v)


func _button(parent: Control, t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(96, 48)
	b.add_theme_font_size_override("font_size", theme_b.sub_size)
	b.add_theme_color_override("font_color", theme_b.text)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, theme_b.style(theme_b.panel.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", theme_b.style(theme_b.accent.darkened(0.3)))
	if theme_b.font:
		b.add_theme_font_override("font", theme_b.font)
	parent.add_child(b)
	return b
