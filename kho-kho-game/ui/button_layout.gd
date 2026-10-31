extends Control
## Settings > Move buttons: the match buttons over a match the AI plays (on Low graphics, over the field drawn still),
## with the card beside them (ButtonLayoutPanel). Drag a button where the thumb finds it.

var controls: TouchControls
var _match: Node = null


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, false)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.stretch_shrink = 2 if int(Game.settings.graphics) <= Game.GFX_MEDIUM else 1
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	svc.add_child(sv)
	_match = load("res://game/match.gd").new()
	_match.config = {"home": "MAH", "away": "ODI", "venue": "arena", "mode": "quick", "user_team": -1, "attract": true,
		"turn_len": 9999.0, "format": KhoRules.FAST}
	sv.add_child(_match)
	var shade := ColorRect.new()
	shade.color = Color(Game.C_BG, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	controls = TouchControls.new()
	add_child(controls)
	controls.set_buttons(["KHO", "DIVE", "POWERPLAY"])
	add_child(ButtonLayoutPanel.new(controls, _back))
	set_meta("back", _back)


func _back() -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
	Sfx.stop_all()
	Game.show_screen("res://ui/settings_screen.gd")
