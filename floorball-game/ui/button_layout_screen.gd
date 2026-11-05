extends Control
## Move buttons (Settings): the match buttons over a picture of the rink, to drag where your thumb wants them. They
## are kept as fractions of the screen, so they sit the same on any phone; Reset puts them back.

var _tc: TouchControls


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, false)
	set_meta("back", func(): Game.show_screen("res://ui/settings_screen.gd"))
	var bg := ColorRect.new()
	bg.color = Game.C_FLOOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var sketch := RinkSketch.new()
	sketch.animate = false
	sketch.home = Color.WHITE
	sketch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sketch.modulate = Color(1, 1, 1, 0.35)
	add_child(sketch)
	_tc = TouchControls.new()
	add_child(_tc)
	_tc.set_buttons(["SHOOT", "PASS", "SPRINT"])
	_tc.editing = true
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 24
	bar.offset_left = -420
	bar.offset_right = 420
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	var card := UI.card("GlassPanel")
	var note := UI.wrap(tr("MOVE_BUTTONS_NOTE"), "SubLabel", 18)
	note.custom_minimum_size = Vector2(340, 0)
	card.add_child(note)
	bar.add_child(card)
	bar.add_child(UI.button(tr("RESET"), false, func(): _tc.reset_places()))
	bar.add_child(UI.button(tr("DONE"), true, func(): Game.show_screen("res://ui/settings_screen.gd")))
	UI.keep_on_screen(bar)
