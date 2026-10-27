extends Control
## Move buttons (Settings): the match buttons as they are laid out, over a dim pitch, to be dragged where your thumb
## wants them. Each place is kept (as a fraction of the screen, so it suits any phone), and Reset puts them back.
## Left-handed mirrors them.

var _tc: TouchControls


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	_tc = TouchControls.new()
	add_child(_tc)
	_tc.edit = true
	# The match's buttons: HIP in the corner (SERVE and SKIP take its place when they show), DIVE beside it.
	_tc.set_buttons(["HIP", "DIVE"])
	var v := UI.page(self, tr("MOVE_BUTTONS"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("MENU_SETTINGS"))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right: HBoxContainer = get_meta("header_right")
	right.add_child(UI.button(tr("RESET"), false, func(): _tc.reset_positions()))
	right.add_child(UI.button(tr("DONE"), true, func(): Game.show_screen("res://ui/settings_screen.gd")))
	var note := UI.wrap(tr("MOVE_BUTTONS_NOTE"), "MutedLabel", 18)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(note)
	for c in v.get_parent().get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(_tc, get_child_count() - 1)
