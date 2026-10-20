class_name ButtonLayoutPanel
extends PanelContainer
## Move buttons, from Settings and from the pause menu: the card beside the match buttons while they are moved. It picks
## which side's buttons show (raiding or defending) and their size, and has Reset and Done. The buttons are the match's
## own (TouchControls) in editing mode: a touch drags one where the thumb finds it, and the layout is saved as it goes.

var controls: TouchControls
var _done: Callable
var _was := {}   # the controls as they were, put back on Done


## c: the buttons to move; cant: the raid's buttons are the tapped cant's (Settings > Raid rule); done: called on Done.
func _init(c: TouchControls, cant: bool, done: Callable) -> void:
	controls = c
	_done = done
	theme_type_variation = "CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in ["context", "cant_mode", "held", "read_hint", "chain_on", "enabled", "visible"]:
		_was[k] = c.get(k)
	c.enabled = true
	c.visible = true
	c.held = false
	c.read_hint = ""
	c.chain_on = false
	c.cant_mode = cant
	# The side being played when the match was paused (raiding from Settings).
	c.context = "defend" if _was.context == "defend" else "raid"
	c.editing = true


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UI.label(tr("MOVE_BUTTONS"), "HeaderLabel", 34))
	v.add_child(UI.wrap(tr("MOVE_BUTTONS_NOTE"), "MutedLabel", 17))
	v.add_child(UI.chips([tr("BTNS_RAIDING"), tr("BTNS_DEFENDING")], 1 if controls.context == "defend" else 0, func(i):
		controls.context = "raid" if i == 0 else "defend"
		controls.queue_redraw()))
	v.add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")],
		int(Game.settings.btn_size), func(i):
			Game.settings.btn_size = i
			Game.save_settings()
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
	var w := minf(560.0, s.x * TouchControls.STICK_SIDE - (m.x if not lh else m.z) - 20.0)
	set_anchors_preset(Control.PRESET_CENTER_LEFT if not lh else Control.PRESET_CENTER_RIGHT)
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = m.x if not lh else -m.z - w
	offset_right = offset_left + w
	offset_top = 0.0
	offset_bottom = 0.0


## Done: the buttons as they were (out of editing), then the caller's own.
func finish() -> void:
	controls.editing = false
	for k in _was:
		controls.set(k, _was[k])
	controls.queue_redraw()
	_done.call()
