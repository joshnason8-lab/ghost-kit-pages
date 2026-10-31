extends Control
## End-of-season awards: the Arjuna Award for the most valuable player, on a walnut plaque with the
## winner's name engraved, plus the season's best raider and best defender.

var awards := {}
var label := ""
var back := "res://ui/main_menu.gd"
var mine := ""          # a team id or player id to highlight as yours
var title := "SEASON_AWARDS"
var titles := {"mvp": "ARJUNA_AWARD", "raider": "BEST_RAIDER", "defender": "BEST_DEFENDER"}
var sub := "ARJUNA_SUB"
var note := "ARJUNA_NOTE"
var _plaque: Node3D
var _t := 0.0


func setup(args: Dictionary) -> void:
	awards = args.get("awards", {})
	label = String(args.get("label", ""))
	back = String(args.get("back", back))
	mine = String(args.get("mine", ""))
	title = String(args.get("title", tr(title)))
	titles = args.get("titles", titles)
	sub = String(args.get("sub", sub))
	note = String(args.get("note", note))


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr(title), func(): Game.show_screen(back), label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# The award plaque.
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
	_build_plaque(sv)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(_award_card(String(titles.mvp), sub, awards.get("mvp", {}), "total", true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_award_card(String(titles.raider), "", awards.get("raider", {}), "raid", false))
	row.add_child(_award_card(String(titles.defender), "", awards.get("defender", {}), "tackle", false))
	right.add_child(row)
	right.add_child(UI.wrap(tr(note), "MutedLabel", 15))
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
		cv.add_child(UI.label(tr("ARJUNA_YOURS" if title_key == "ARJUNA_AWARD" else "AWARD_YOURS"), "SubLabel", 20, Game.C_SAFFRON))
	return card


## The award: a walnut plaque with a gold-rimmed enamel medal (the home screen's celebrating player, in gold) and
## an engraved gold plate (the award, the winner, his team and the season), turning a little so the gold catches
## the light.
func _build_plaque(sv: SubViewport) -> void:
	var root := Node3D.new()
	sv.add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	# A warm sky for the gold to mirror (the screen shows through behind the plaque).
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("fff1d6")
	sky_mat.sky_horizon_color = Color("c9a46a")
	sky_mat.ground_horizon_color = Color("5a4630")
	sky_mat.ground_bottom_color = Color("1c1712")
	sky.sky_material = sky_mat
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fa6c4")
	env.environment.ambient_light_energy = 0.55
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-28), deg_to_rad(-32), 0)
	key.light_energy = 1.7
	key.light_color = Color("ffe8c4")
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10), deg_to_rad(150), 0)
	rim.light_energy = 1.2
	rim.light_color = Game.C_SAFFRON
	root.add_child(rim)

	_plaque = Node3D.new()
	root.add_child(_plaque)
	var walnut := StandardMaterial3D.new()
	walnut.albedo_texture = _grain()
	walnut.uv1_scale = Vector3(1.0, 6.0, 1.0)   # the grain runs across the board
	walnut.roughness = 0.38
	var walnut_face: StandardMaterial3D = walnut.duplicate()
	walnut_face.albedo_color = Color(1.12, 1.08, 1.04)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e2b04a")
	gold.metallic = 0.85
	gold.roughness = 0.28
	var brushed: StandardMaterial3D = gold.duplicate()
	brushed.roughness = 0.42
	brushed.albedo_color = Color("d9ab55")
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color("13253d")
	enamel.roughness = 0.18
	enamel.metallic = 0.1
	# The board and its raised face.
	_box(Vector3(1.5, 1.95, 0.1), Vector3.ZERO, walnut)
	_box(Vector3(1.36, 1.81, 0.03), Vector3(0, 0, 0.06), walnut_face)
	# A thin gold line round the face.
	for e in [[Vector3(1.24, 0.02, 0.01), Vector3(0, 0.835, 0.08)], [Vector3(1.24, 0.02, 0.01), Vector3(0, -0.835, 0.08)],
			[Vector3(0.02, 1.69, 0.01), Vector3(0.61, 0, 0.08)], [Vector3(0.02, 1.69, 0.01), Vector3(-0.61, 0, 0.08)]]:
		_box(e[0], e[1], gold)
	# The medal: a gold rim, dark enamel, and the player in gold.
	var medal_y := 0.27
	_disc(0.46, 0.03, Vector3(0, medal_y, 0.085), gold)
	_disc(0.41, 0.03, Vector3(0, medal_y, 0.092), enamel)
	var fig := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.46, 0.68)
	fig.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = Shader.new()
	fm.shader.code = """shader_type spatial;
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec3 gold : source_color = vec3(0.89, 0.69, 0.29);
void fragment() {
	if (texture(art, UV).a < 0.5) {
		discard;
	}
	ALBEDO = gold;
	METALLIC = 0.85;
	ROUGHNESS = 0.3;
}
"""
	fm.set_shader_parameter("art", UI.art("celebrate"))
	fig.material_override = fm
	fig.position = Vector3(0, medal_y - 0.01, 0.109)
	_plaque.add_child(fig)
	# The engraved plate, with a screw at each end.
	_box(Vector3(1.1, 0.46, 0.014), Vector3(0, -0.53, 0.082), brushed)
	for sx in [-0.5, 0.5]:
		var screw := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.02
		sp.height = 0.02
		screw.mesh = sp
		screw.material_override = gold
		screw.position = Vector3(sx, -0.53, 0.09)
		_plaque.add_child(screw)
	var mvp: Dictionary = awards.get("mvp", {})
	var team_line := DB.team_name(String(mvp.team)) if mvp.has("team") else ""
	if label != "":
		team_line = label if team_line == "" else "%s · %s" % [team_line, label]
	_engrave(tr(String(titles.mvp)).to_upper(), Game.font_display, 0.075, -0.39)
	_engrave(String(mvp.get("name", "—")), Game.font_display, 0.12, -0.52)
	_engrave(team_line, Game.font_bold, 0.05, -0.65)

	var cam := Camera3D.new()
	cam.fov = 30
	root.add_child(cam)
	cam.position = Vector3(0, 0.0, 5.0)
	cam.look_at(Vector3(0, -0.02, 0))


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_plaque.add_child(mi)


## A disc facing the viewer (a cylinder on its side).
func _disc(radius: float, depth: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = depth
	c.radial_segments = 64
	mi.mesh = c
	mi.material_override = mat
	mi.rotation.x = PI * 0.5
	mi.position = pos
	_plaque.add_child(mi)


## A line cut into the plate: dark, centred, as tall as asked and narrowed to fit the plate if it is long.
func _engrave(text: String, font: Font, height: float, y: float) -> void:
	if text == "":
		return
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 96
	var px := height / 96.0
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * px
	if w > 0.98:
		px *= 0.98 / w
	l.pixel_size = px
	l.modulate = Color("3a240e")
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = Vector3(0, y, 0.0905)
	_plaque.add_child(l)


## Walnut: dark streaks of noise, run across the board by the material's scale.
func _grain() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.018
	n.fractal_octaves = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color("2c180d"))
	ramp.set_color(1, Color("5c3820"))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = ramp
	return tex


func _process(delta: float) -> void:
	_t += delta
	if _plaque:
		_plaque.rotation.y = sin(_t * 0.6) * 0.3
