class_name ButtonLayoutPanel
extends PanelContainer
## Move buttons, from Settings and from the pause menu: the card beside the match buttons while they are moved. It
## picks which side's buttons show (chasing or defending) and their size, and has Reset and Done. The buttons are the
## match's own (TouchControls) in editing mode: a finger drags one where the thumb finds it, saved as it goes.

var controls: TouchControls
var _done: Callable


func _init(c: TouchControls, done: Callable) -> void:
	controls = c
	_done = done
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	c.editing = true
	c.enabled = true
	c.visible = true


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := UI.label(tr("MOVE_BUTTONS"), "HeaderLabel", 32)
	UI.fit(t, 2)
	v.add_child(t)
	v.add_child(UI.wrap(tr("MOVE_BUTTONS_NOTE"), "MutedLabel", 17))
	var chasing: bool = controls.ids.is_empty() or controls.ids[0] == "KHO"
	v.add_child(UI.chips([tr("BTNS_CHASING"), tr("BTNS_DEFENDING")], 0 if chasing else 1, func(i):
		controls.set_buttons(["KHO", "DIVE", "POWERPLAY"] if i == 0 else ["DODGE", "SWITCH"])))
	if controls.ids.is_empty():
		controls.set_buttons(["KHO", "DIVE", "POWERPLAY"])
	v.add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")],
		int(Game.settings.btn_size), func(i):
			Game.settings.btn_size = i
			Game.save_settings()
			controls.set_buttons(controls.ids.duplicate())
			controls._paras.clear()
			controls.queue_redraw())))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var reset := UI.button(tr("RESET_PLACES"), false, func(): controls.reset_places())
	var done := UI.button(tr("DONE"), true, finish)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reset)
	row.add_child(done)
	v.add_child(row)
	get_viewport().size_changed.connect(_place)
	_place()


## On the joystick's side, where no button goes, halfway down the screen.
func _place() -> void:
	var s := get_viewport_rect().size
	var m := UI.safe_margins(self, 32.0)
	var lh: bool = Game.settings.left_handed
	var w := minf(520.0, s.x * TouchControls.STICK_SIDE - (m.x if not lh else m.z) - 20.0)
	set_anchors_preset(Control.PRESET_CENTER_LEFT if not lh else Control.PRESET_CENTER_RIGHT)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = m.x if not lh else -m.z - w
	offset_right = offset_left + w
	offset_top = 0.0
	offset_bottom = 0.0
	custom_minimum_size.x = w


func finish() -> void:
	controls.editing = false
	Game.save_settings()
	queue_free()
	_done.call()
