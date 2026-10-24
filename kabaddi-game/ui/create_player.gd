extends Control
## Career: create your player, with a live 3D preview.

var profile := {"name": "", "state": "STATE_HARYANA", "role": "raider", "signature": "hand", "style": "ankle", "skin": 2, "hair": 0, "build": 1, "number": 10, "height": 1.80}
var _preview_root: Node3D
var _athlete: Athlete
var _cam: Camera3D
var _t := 0.0


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	profile.name = tr("DEFAULT_PLAYER_NAME")
	var v := UI.page(self, tr("CREATE_PLAYER"), func(): Game.goto_menu(), tr("MENU_CAREER"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 18)
	cols.add_child(UI.scroll(form))
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_edit := LineEdit.new()
	name_edit.text = profile.name
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(420, 56)
	name_edit.text_changed.connect(func(t): profile.name = t)
	form.add_child(UI.field(tr("NAME"), name_edit))

	var states := OptionButton.new()
	states.custom_minimum_size = Vector2(420, 56)
	for i in DB.STATES.size():
		states.add_item(tr(DB.STATES[i]), i)
	states.item_selected.connect(func(i): profile.state = DB.STATES[i])
	form.add_child(UI.field(tr("HOME_STATE"), states))

	var roles := ["raider", "allrounder", "defender"]
	var role_hint := UI.wrap(tr("CAREER_HINT_RAIDER"), "MutedLabel", 17)
	form.add_child(UI.field(tr("ROLE"), UI.chips([tr("ROLE_RAIDER"), tr("ROLE_ALLROUNDER"), tr("ROLE_DEFENDER")], 0, func(i):
		profile.role = roles[i]
		role_hint.text = tr("CAREER_HINT_DEFENDER") if roles[i] == "defender" else tr("CAREER_HINT_RAIDER"))))
	form.add_child(role_hint)
	var move_labels := []
	for mv in DB.MOVES:
		move_labels.append(tr(DB.MOVE_KEYS[mv]))
	form.add_child(UI.field(tr("SPECIALITY"), UI.chips(move_labels, 0, func(i): profile.signature = DB.MOVES[i])))
	var style_labels := []
	for st in DB.STYLES:
		style_labels.append(tr(DB.STYLE_KEYS[st]))
	form.add_child(UI.field(tr("TACKLE_STYLE"), UI.chips(style_labels, 0, func(i): profile.style = DB.STYLES[i])))
	form.add_child(UI.field(tr("BUILD"), UI.chips([tr("BUILD_LEAN"), tr("BUILD_ATHLETIC"), tr("BUILD_POWER")], 1, func(i):
		profile.build = i
		_refresh_preview())))

	var skins := HBoxContainer.new()
	skins.add_theme_constant_override("separation", 10)
	var sg := ButtonGroup.new()
	for i in DB.SKIN_TONES.size():
		skins.add_child(_swatch_button(Color(DB.SKIN_TONES[i]), sg, i == profile.skin, func():
			profile.skin = i
			_refresh_preview()))
	form.add_child(UI.field(tr("SKIN_TONE"), skins))
	var hairs := HBoxContainer.new()
	hairs.add_theme_constant_override("separation", 10)
	var hg := ButtonGroup.new()
	for i in DB.HAIR_COLORS.size():
		hairs.add_child(_swatch_button(Color(DB.HAIR_COLORS[i]), hg, i == profile.hair, func():
			profile.hair = i
			_refresh_preview()))
	form.add_child(UI.field(tr("HAIR"), hairs))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.custom_minimum_size = Vector2(440, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(440, 400)
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	_preview_root = Node3D.new()
	sv.add_child(_preview_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fa6c4")
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_preview_root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(35), 0)
	key.light_energy = 1.6
	_preview_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(200), 0)
	rim.light_energy = 1.2
	rim.light_color = Game.C_SAFFRON
	_preview_root.add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.04
	floor_mi.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("1d4f9c")
	floor_mi.material_override = fm
	floor_mi.position.y = -0.02
	_preview_root.add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 32
	_cam.position = Vector3(0, 1.15, 4.6)
	_preview_root.add_child(_cam)
	_cam.look_at(Vector3(0, 0.95, 0))
	_refresh_preview()

	var go := UI.button(tr("ENTER_AUCTION"), true, func():
		if String(profile.name).strip_edges() == "":
			profile.name = tr("DEFAULT_PLAYER_NAME")
		Game.new_career(profile)
		Game.show_screen("res://ui/auction_screen.gd"))
	right.add_child(go)


func _swatch_button(c: Color, group: ButtonGroup, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	b.custom_minimum_size = Vector2(56, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(28)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.border_color = Game.C_SAFFRON
	sbp.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover_pressed", sbp)
	b.pressed.connect(cb)
	return b


func _refresh_preview() -> void:
	if _preview_root == null:
		return
	if _athlete:
		_athlete.queue_free()
	var p := {"id": "PREVIEW", "name": "", "role": profile.role, "attrs": {"speed": 60, "agility": 60, "strength": 60, "reach": 60, "tackle": 60, "stamina": 60},
		"number": 10, "skin": profile.skin, "hair": profile.hair, "build": [0.93, 1.02, 1.12][int(profile.build)], "height": 1.80}
	_athlete = Athlete.new()
	_athlete.setup(p, 0, Color("12a4a7"), Color("f3efe6"), false)
	_preview_root.add_child(_athlete)
	_athlete.set_state("raid")


func _process(delta: float) -> void:
	_t += delta
	if _athlete:
		_athlete.facing = Vector3(sin(_t * 0.6), 0, cos(_t * 0.6))
