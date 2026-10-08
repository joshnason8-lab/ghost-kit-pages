extends Control
## End-of-season awards: the Arjuna Award for the most valuable player, with a bronze
## statuette of Arjuna the archer, plus the season's best raider and best defender.

var awards := {}
var label := ""
var back := "res://ui/main_menu.gd"
var mine := ""          # a team id or player id to highlight as yours
var _statue: Node3D
var _t := 0.0


func setup(args: Dictionary) -> void:
	awards = args.get("awards", {})
	label = String(args.get("label", ""))
	back = String(args.get("back", back))
	mine = String(args.get("mine", ""))


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("SEASON_AWARDS"), func(): Game.show_screen(back), label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# The statuette.
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(360, 420)
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	_build_statue(sv)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_award_card("ARJUNA_AWARD", "ARJUNA_SUB", awards.get("mvp", {}), "total", true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_award_card("BEST_RAIDER", "", awards.get("raider", {}), "raid", false))
	row.add_child(_award_card("BEST_DEFENDER", "", awards.get("defender", {}), "tackle", false))
	right.add_child(row)
	right.add_child(UI.wrap(tr("ARJUNA_NOTE"), "MutedLabel", 15))
	Sfx.crowd(0.6)
	Sfx.play("roar", -8.0)


func _is_mine(w: Dictionary) -> bool:
	return mine != "" and (String(w.get("pid", "")) == mine or String(w.get("team", "")) == mine)


func _award_card(title_key: String, sub_key: String, w: Dictionary, stat: String, big: bool) -> PanelContainer:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(UI.label(tr(title_key).to_upper(), "EyebrowLabel", 15 if not big else 17, Game.C_GOLD))
	if sub_key != "":
		cv.add_child(UI.label(tr(sub_key), "MutedLabel", 15))
	if w.is_empty():
		cv.add_child(UI.label("—", "HeaderLabel", 30))
		return card
	var name_l := UI.label(String(w.name), "TitleLabel" if big else "HeaderLabel", 56 if big else 30, Game.C_GOLD if _is_mine(w) else Game.C_INK)
	cv.add_child(name_l)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.add_child(UI.swatch(DB.team(String(w.team)).get("c1", Game.C_MUTED), Vector2(6, 22)))
	trow.add_child(UI.label(DB.team_name(String(w.team)), "SubLabel", 18))
	cv.add_child(trow)
	var line := ""
	match stat:
		"raid":
			line = "%d %s" % [int(w.raid), tr("STAT_RAID_PTS")]
		"tackle":
			line = "%d %s" % [int(w.tackle), tr("STAT_TACKLE_PTS")]
		_:
			line = "%d %s · %d %s · %d %s" % [int(w.raid) + int(w.tackle), tr("POINTS_TOTAL"), int(w.raid), tr("STAT_RAID_PTS"), int(w.tackle), tr("STAT_TACKLE_PTS")]
	cv.add_child(UI.label(line, "MutedLabel", 17))
	if _is_mine(w) and big:
		cv.add_child(UI.label(tr("ARJUNA_YOURS"), "SubLabel", 20, Game.C_SAFFRON))
	return card


## Arjuna the archer, cast in bronze, turning on a plinth.
func _build_statue(sv: SubViewport) -> void:
	var root := Node3D.new()
	sv.add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fa6c4")
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(40), 0)
	key.light_energy = 2.0
	key.light_color = Color("ffe2b8")
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(210), 0)
	rim.light_energy = 1.4
	rim.light_color = Game.C_SAFFRON
	root.add_child(rim)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("a8742f")
	bronze.metallic = 0.85
	bronze.roughness = 0.35
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("2a2f38")
	stone.roughness = 0.6
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.65
	cyl.height = 0.5
	plinth.mesh = cyl
	plinth.material_override = stone
	plinth.position = Vector3(0, 0.25, 0)
	root.add_child(plinth)
	_statue = Node3D.new()
	_statue.position = Vector3(0, 0.5, 0)
	root.add_child(_statue)
	var data := {"id": "ARJUNA", "name": "", "role": "raider",
		"attrs": {"speed": 80, "agility": 80, "strength": 80, "reach": 80, "tackle": 60, "stamina": 80},
		"number": 0, "skin": 2, "hair": 0, "build": 1.04, "height": 1.8}
	var a := Athlete.new()
	a.setup(data, 0, Color("a8742f"), Color("a8742f"), true)
	_statue.add_child(a)
	a.set_state("argue", 1e9)   # one arm out, as if drawing a bow
	await get_tree().process_frame
	for mi in a.find_children("*", "GeometryInstance3D", true, false):
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = bronze
		elif mi is Label3D:
			(mi as Label3D).visible = false
	var cam := Camera3D.new()
	cam.fov = 34
	root.add_child(cam)
	cam.position = Vector3(0, 1.45, 4.4)
	cam.look_at(Vector3(0, 1.3, 0))


func _process(delta: float) -> void:
	_t += delta
	if _statue:
		_statue.rotation.y = sin(_t * 0.5) * 0.9 + PI
