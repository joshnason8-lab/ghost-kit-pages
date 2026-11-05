extends Control
## Settings > Move buttons: the match buttons over a match the AI plays, from the broadcast camera as in a match (on Low
## graphics, a picture of one), with the card beside them (ButtonLayoutPanel). Drag a button where the thumb finds it.

var controls: TouchControls
var panel: ButtonLayoutPanel
var _sv: SubViewport
var _match: Node = null


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, false)
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		svc.stretch_shrink = 2 if int(Game.settings.graphics) == Game.GFX_MEDIUM else 1
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(svc)
		_sv = SubViewport.new()
		_sv.own_world_3d = true
		svc.add_child(_sv)
		_start_match()
	else:
		var pic := TextureRect.new()
		pic.texture = load("res://assets/ui/ground_dome.jpg")
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
	# A little darker, so that the buttons and the card stand out.
	var shade := ColorRect.new()
	shade.color = Color(Game.C_BG, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	controls = TouchControls.new()
	add_child(controls)
	panel = ButtonLayoutPanel.new(controls, int(Game.settings.get("raid_rule", 2)) == 1, _back)
	add_child(panel)
	set_meta("back", _back)   # the phone's back button does the same as Done


## The match behind, as behind the home screen: another once it is over.
func _start_match() -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
	_match = load("res://game/match.gd").new()
	_match.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"attract": true, "length": 0, "difficulty": 2}
	_match.finished.connect(func(_r): _start_match.call_deferred())
	_sv.add_child(_match)


func _back() -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
		_match = null
	Sfx.stop_all()
	Game.show_screen("res://ui/settings_screen.gd")
