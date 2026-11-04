class_name ButtonLayoutPanel
extends PanelContainer
## Move buttons (Settings, or the pause menu): a card beside the match buttons while they are moved. The buttons are
## the match's own (TouchControls) in editing mode: a touch drags one where the thumb finds it, and the layout is
## saved as it goes. Button size can be changed here too. Reset and Done.

var controls: TouchControls
var _done: Callable
var _was_ids: Array = []


func _init(c: TouchControls, done: Callable) -> void:
	controls = c
	_done = done
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_was_ids = c.ids.duplicate()
	c.visible = true
	c.editing = true
	c.set_buttons(["PASS", "LOB", "SHOOT", "SWITCH"])


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UI.label(tr("MOVE_BUTTONS"), "HeaderLabel", 36))
	v.add_child(UI.wrap(tr("MOVE_BUTTONS_NOTE"), "MutedLabel", 17))
	v.add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")],
		int(Game.settings.btn_size), func(i):
			Game.settings.btn_size = i
			Game.save_settings()
			controls.set_buttons(controls.ids))))
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
	var w := minf(500.0, s.x * 0.42 - (m.x if not lh else m.z))
	set_anchors_preset(Control.PRESET_CENTER_LEFT if not lh else Control.PRESET_CENTER_RIGHT)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = m.x if not lh else -m.z - w
	offset_right = offset_left + w
	offset_top = 0.0
	offset_bottom = 0.0


func finish() -> void:
	controls.editing = false
	controls.set_buttons(_was_ids)
	_done.call()
