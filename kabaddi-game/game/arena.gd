class_name Arena
extends Node3D
## Builds the court and its surroundings for one ground.
##
## Court geometry follows Pro-style men's rules: a 10 m x 13 m playing field split by the
## midline, baulk lines 3.75 m from the midline, bonus lines 1 m further, 1 m lobbies on both
## sides, and a sitting block behind each end line. Origin is the centre of the midline;
## x runs across the court, z along it. Team 0 defends z > 0, team 1 defends z < 0.

const HALF_W := 5.0
const HALF_L := 6.5
const LOBBY := 1.0
const BAULK := 3.75
const BONUS := 4.75
const LINE_W := 0.05

var arena_id := "dome"
var crowd_mats: Array[ShaderMaterial] = []
var sun: DirectionalLight3D
var env: Environment
var barefoot := false
var _water: ShaderMaterial = null
var _excite := 0.0

const CROWD_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 skin_tone : source_color = vec3(0.55, 0.38, 0.27);
uniform float excitement = 0.0;
varying vec3 v_col;
void vertex() {
	float ph = INSTANCE_CUSTOM.a * 6.2831;
	float rate = 2.0 + excitement * 7.0;
	float jump = max(0.0, sin(TIME * rate + ph * 3.0));
	VERTEX.y += jump * (0.015 + excitement * 0.16);
	vec3 skin = skin_tone * (0.7 + 0.6 * fract(INSTANCE_CUSTOM.a * 7.13));
	v_col = mix(INSTANCE_CUSTOM.rgb, skin, COLOR.r);
}
void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.92;
}
"""

## The crowd as cards cut from a sprite sheet of real people (tools/crowd/render_crowd.gd): each card turns
## to face the camera, and picks its frame (sitting, clapping, standing to cheer) from the crowd's
## excitement. Fans in shirts wear their instance's colour, shaded by the shirt's own folds.
const CROWD_CARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D top_mask : filter_linear_mipmap, repeat_disable;
uniform float people = 8.0;
uniform float frames = 8.0;
uniform bool standing = false;
uniform float excitement = 0.0;
uniform float top_lum[16];   // each person's shirt brightness, linear; 0 keeps their own clothes
varying flat vec2 cell;
varying flat float mirror;
varying flat vec3 tint;
varying flat float lum;
void vertex() {
	// Face the camera, turning about the vertical only.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float slot = INSTANCE_CUSTOM.a * 16.0;   // person index + a random phase
	float person = floor(slot);
	float ph = fract(slot);
	float keen = fract(ph * 3.71);
	float beat = step(0.5, fract(TIME * (1.4 + excitement * 1.6) + ph * 5.0));
	float base = standing ? 3.0 : 0.0;
	float frame = base;
	if (excitement > 0.5 + 0.45 * keen) {
		frame = 6.0 + step(0.65, fract(TIME * 0.35 + ph * 3.0));   // on their feet, arms up or a fist
		VERTEX.y += max(0.0, sin(TIME * 6.0 + ph * 40.0)) * 0.07 * excitement;
	} else if (excitement > 0.2 + 0.4 * keen || fract(TIME * 0.03 + ph * 9.1) < 0.05) {
		frame = base + 1.0 + beat;   // clapping
	}
	cell = vec2(person, frame);
	mirror = step(0.5, fract(ph * 7.77));
	tint = INSTANCE_CUSTOM.rgb;
	lum = top_lum[int(person)];
}
void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, mirror), UV.y);
	uv = (cell + uv) / vec2(people, frames);
	vec4 c = texture(atlas, uv);
	vec3 col = c.rgb;
	if (lum > 0.0 && tint.r + tint.g + tint.b > 0.003) {
		float m = texture(top_mask, uv).r;
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722)) / lum;
		col = mix(col, tint * clamp(l, 0.2, 1.5), m);
	}
	ALBEDO = col;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Lit a little from above as well as from the front, like the heads and shoulders they are.
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(0.0, 0.8, 0.0, 0.0)).xyz);
}
"""
const CROWD_DIR := "res://assets/crowd/"
static var _crowd_sheet = null   # the crowd's sprite sheet once loaded: {} when the game has none

const WATER_SHADER := """
shader_type spatial;
uniform vec3 deep : source_color = vec3(0.04, 0.23, 0.36);
uniform vec3 shallow : source_color = vec3(0.12, 0.55, 0.62);
void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.35 + TIME * 1.2) * 0.12 + sin(VERTEX.z * 0.5 + TIME * 0.9) * 0.08;
}
void fragment() {
	float w = sin(UV.x * 120.0 + TIME * 1.5) * 0.5 + 0.5;
	ALBEDO = mix(deep, shallow, UV.y * 0.6 + w * 0.08);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.7;
}
"""


func build(p_arena_id: String, home_color: Color, away_color: Color, banner_text: String) -> void:
	arena_id = p_arena_id
	match arena_id:
		"village":
			_build_village(home_color, away_color)
		"stadium":
			_build_stadium(home_color, away_color, banner_text)
		"monsoon":
			_build_monsoon(home_color, away_color)
		"beach":
			_build_beach(home_color, away_color)
		_:
			_build_dome(home_color, away_color, banner_text)


## 0..1 crowd energy; decays on its own.
func excite(amount: float) -> void:
	_excite = clampf(maxf(_excite, amount), 0.0, 1.0)


func _process(delta: float) -> void:
	_excite = move_toward(_excite, 0.12, delta * 0.35)
	for m in crowd_mats:
		m.set_shader_parameter("excitement", _excite)


# ---------------------------------------------------------------- materials

func _mat(c: Color, rough := 0.8, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _noise_tex(freq: float, seamless := true, as_normal := false, bump := 1.0, ramp: Gradient = null) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = seamless
	t.noise = n
	t.as_normal_map = as_normal
	t.bump_strength = bump
	if ramp:
		t.color_ramp = ramp
	return t


func _surface_mat(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match kind:
		"mat":
			m.albedo_color = Color("1d4f9c")
			m.roughness = 0.55
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.08, true, true, 1.5)
			m.normal_scale = 0.25
			m.uv1_scale = Vector3(6, 6, 6)
		"mat_wet":
			m.albedo_color = Color("1a4687")
			m.roughness = 0.18
			m.metallic_specular = 0.8
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.05, true, true, 2.0)
			m.normal_scale = 0.35
			m.uv1_scale = Vector3(4, 4, 4)
		"mud":
			var g := Gradient.new()
			g.set_color(0, Color("6e4a2e"))
			g.set_color(1, Color("9b7048"))
			m.albedo_texture = _noise_tex(0.02, true, false, 1.0, g)
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.06, true, true, 6.0)
			m.normal_scale = 0.8
			m.uv1_scale = Vector3(3, 3, 3)
		"sand":
			var g2 := Gradient.new()
			g2.set_color(0, Color("a8834f"))
			g2.set_color(1, Color("c9a874"))
			m.albedo_texture = _noise_tex(0.03, true, false, 1.0, g2)
			m.roughness = 0.97
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.12, true, true, 4.0)
			m.normal_scale = 0.6
			m.uv1_scale = Vector3(4, 4, 4)
		"grass":
			var g3 := Gradient.new()
			g3.set_color(0, Color("4b6b2a"))
			g3.set_color(1, Color("7a8f3a"))
			m.albedo_texture = _noise_tex(0.015, true, false, 1.0, g3)
			m.roughness = 0.95
			m.uv1_scale = Vector3(12, 12, 12)
		"floor":
			m.albedo_color = Color("141a24")
			m.roughness = 0.35
			m.metallic_specular = 0.6
	return m


# ---------------------------------------------------------------- court

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, cast := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	if not cast:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	mi.mesh = p
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _court(surface: String, lobby_tint: Color, line_color: Color, surround: Color) -> void:
	var court := Node3D.new()
	court.name = "Court"
	add_child(court)
	var field_mat := _surface_mat(surface)
	if surface == "mat" or surface == "mat_wet":
		# Run-off mat, lobbies, then the field.
		_plane(court, Vector2(16.0, 19.0), Vector3(0, 0.0, 0), _mat(surround, 0.6))
		var lobby_mat: StandardMaterial3D = field_mat.duplicate()
		lobby_mat.albedo_color = lobby_tint
		_plane(court, Vector2(LOBBY, HALF_L * 2), Vector3(-HALF_W - LOBBY * 0.5, 0.003, 0), lobby_mat)
		_plane(court, Vector2(LOBBY, HALF_L * 2), Vector3(HALF_W + LOBBY * 0.5, 0.003, 0), lobby_mat)
		_plane(court, Vector2(HALF_W * 2, HALF_L * 2), Vector3(0, 0.004, 0), field_mat)
		# Sitting blocks behind each end line.
		var sb := _mat(lobby_tint.darkened(0.2), 0.6)
		_plane(court, Vector2(8.0, 1.0), Vector3(0, 0.004, HALF_L + 2.5), sb)
		_plane(court, Vector2(8.0, 1.0), Vector3(0, 0.004, -HALF_L - 2.5), sb)
	else:
		# Earth and sand courts are the ground itself, marked out.
		_plane(court, Vector2(HALF_W * 2 + 2 * LOBBY + 0.6, HALF_L * 2 + 0.6), Vector3(0, 0.004, 0), field_mat)

	# A bench in each sitting block for players who are out.
	var bench_mat := _mat(Color("3a4a5c") if surface.begins_with("mat") else Color("6b4a2e"), 0.7)
	for sgn in [-1.0, 1.0]:
		var bz: float = sgn * (HALF_L + 2.62)
		_box(court, Vector3(7.8, 0.06, 0.4), Vector3(0, 0.39, bz), bench_mat)
		for bx in [-3.7, -1.25, 1.25, 3.7]:
			_box(court, Vector3(0.06, 0.36, 0.34), Vector3(bx, 0.18, bz), bench_mat)

	var lm := _mat(line_color, 0.7, 0.15)
	var y := 0.009
	var full_w := (HALF_W + LOBBY) * 2
	# End lines and outer boundary (including lobbies).
	for z in [-HALF_L, HALF_L]:
		_line(court, Vector3(0, y, z), Vector2(full_w, LINE_W), lm)
	for x in [-HALF_W - LOBBY, -HALF_W, HALF_W, HALF_W + LOBBY]:
		_line(court, Vector3(x, y, 0), Vector2(LINE_W, HALF_L * 2), lm)
	# Midline, wider than the rest.
	_line(court, Vector3(0, y + 0.001, 0), Vector2(full_w, LINE_W * 1.6), lm)
	for sgn in [-1.0, 1.0]:
		_line(court, Vector3(0, y, sgn * BAULK), Vector2(HALF_W * 2, LINE_W), lm)
		_line(court, Vector3(0, y, sgn * BONUS), Vector2(HALF_W * 2, LINE_W), lm)


func _line(parent: Node3D, pos: Vector3, size: Vector2, mat: Material) -> void:
	_plane(parent, size, pos, mat)


func _mat_label(text: String, pos: Vector3, rot_y: float, size := 140, col := Color(1, 1, 1, 0.55)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_display
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation = Vector3(-PI / 2, rot_y, 0)
	l.shaded = true
	add_child(l)


# ---------------------------------------------------------------- environment

func _environment(sky_top: Color, sky_horizon: Color, ground: Color, sun_energy: float, ambient: float, fog_density := 0.0, fog_color := Color.BLACK, use_sky := true, bg := Color.BLACK) -> void:
	env = Environment.new()
	if use_sky:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_horizon
		sky_mat.ground_horizon_color = sky_horizon
		sky_mat.ground_bottom_color = ground
		sky_mat.sun_angle_max = 12.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = sky_horizon
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = int(Game.settings.graphics) >= Game.GFX_MEDIUM
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	if fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density
		env.fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_energy = sun_energy
	sun.shadow_enabled = Game.shadows_enabled()
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if int(Game.settings.graphics) < Game.GFX_HIGH else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


# ---------------------------------------------------------------- crowds and props

func _person_mesh() -> ArrayMesh:
	# One low-poly spectator: torso (shirt colour) and head (skin). Vertex colour red marks skin.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 0.85
	body.radial_segments = 6
	body.rings = 2
	var head := SphereMesh.new()
	head.radius = 0.12
	head.height = 0.24
	head.radial_segments = 6
	head.rings = 4
	_append(st, body, Transform3D(Basis(), Vector3(0, 0.42, 0)), Color(0, 0, 0))
	_append(st, head, Transform3D(Basis(), Vector3(0, 0.97, 0)), Color(1, 0, 0))
	st.generate_normals()
	return st.commit()


func _append(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(col)
		st.add_vertex(xf * verts[i])


func _crowd(positions: Array, palette: Array, skin: Color, facing: Vector3 = Vector3.ZERO) -> void:
	var keep := Game.crowd_density()
	var chosen := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for p in positions:
		if rng.randf() < keep:
			chosen.append(p)
	if chosen.is_empty():
		return
	if not crowd_sheet().is_empty():
		# People on tiers sit; people on the ground stand.
		_crowd_cards(chosen.filter(func(p): return p.y > 0.2), palette, false, rng)
		_crowd_cards(chosen.filter(func(p): return p.y <= 0.2), palette, true, rng)
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _person_mesh()
	mm.instance_count = chosen.size()
	for i in chosen.size():
		var pos: Vector3 = chosen[i]
		var look := (facing - pos)
		look.y = 0
		var basis := Basis()
		if look.length() > 0.01:
			basis = Basis.looking_at(look.normalized(), Vector3.UP)
		var s := rng.randf_range(0.9, 1.08)
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3(s, s, s)), pos))
		var c: Color = palette[rng.randi() % palette.size()]
		c = c.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.12)
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CROWD_SHADER
	sm.shader = sh
	sm.set_shader_parameter("skin_tone", skin)
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd_mats.append(sm)
	add_child(mmi)


static func crowd_sheet() -> Dictionary:
	if _crowd_sheet == null:
		_crowd_sheet = {}
		var f := FileAccess.open(CROWD_DIR + "crowd_atlas.json", FileAccess.READ)
		if f and ResourceLoader.exists(CROWD_DIR + "crowd_atlas.webp"):
			var info = JSON.parse_string(f.get_as_text())
			if info is Dictionary:
				_crowd_sheet = {"info": info, "atlas": load(CROWD_DIR + "crowd_atlas.webp"),
					"mask": load(CROWD_DIR + "crowd_mask.png")}
	return _crowd_sheet


## Spectators as camera-facing cards. Fans in shirts are picked more often than the rest, and most wear
## a colour from the palette (the teams' colours among them); children are fewer.
func _crowd_cards(spots: Array, palette: Array, standing: bool, rng: RandomNumberGenerator) -> void:
	if spots.is_empty():
		return
	var sheet := crowd_sheet()
	var info: Dictionary = sheet.info
	var people: Array = info.people
	var cell: Array = info.cell
	var h := float(info.cell_height_m)
	var w := h * float(cell[0]) / float(cell[1])
	var weights := []
	var lums := PackedFloat32Array()
	lums.resize(16)
	var total := 0.0
	for i in people.size():
		var file := String(people[i].file)
		var wt := 3.0 if float(people[i].top_luminance) > 0.0 else 1.5
		if file.contains("boy") or file.contains("girl"):
			wt = 0.8
		weights.append(wt)
		total += wt
		lums[i] = float(people[i].top_luminance)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _card_mesh(w, h)
	mm.instance_count = spots.size()
	for i in spots.size():
		var pos: Vector3 = spots[i]
		# Feet on the ground, or on the tier below the seat; the sheet has 2 cm under the feet.
		var feet := pos - Vector3(0, (0.0 if standing else 0.45) + 0.02, 0)
		var s := rng.randf_range(0.93, 1.06)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), feet))
		var pick := rng.randf() * total
		var person := 0
		while person < people.size() - 1 and pick > weights[person]:
			pick -= weights[person]
			person += 1
		var tint := Color(0, 0, 0)
		if rng.randf() < 0.8:
			var c: Color = palette[rng.randi() % palette.size()]
			tint = c.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.1).srgb_to_linear()
		mm.set_instance_custom_data(i, Color(tint.r, tint.g, tint.b, (person + rng.randf_range(0.0, 0.999)) / 16.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CROWD_CARD_SHADER
	sm.shader = sh
	sm.set_shader_parameter("atlas", sheet.atlas)
	sm.set_shader_parameter("top_mask", sheet.mask)
	sm.set_shader_parameter("people", float(people.size()))
	sm.set_shader_parameter("frames", float((info.frames as Array).size()))
	sm.set_shader_parameter("standing", standing)
	sm.set_shader_parameter("top_lum", lums)
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crowd_mats.append(sm)
	add_child(mmi)


func _card_mesh(w: float, h: float) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, h, 0), Vector3(-w * 0.5, h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Tiered stands on all four sides. Returns spectator seat positions.
func _stands(inner_x: float, inner_z: float, tiers: int, mat: Material, gap_for_tunnel := true) -> Array:
	var seats := []
	var tier_d := 0.9
	var tier_h := 0.45
	for t in tiers:
		var h := tier_h * (t + 1)
		var off := t * tier_d
		var wx := (inner_x + off) * 2.0 + tier_d * 2
		# Long sides (along z).
		for sgn in [-1.0, 1.0]:
			_box(self, Vector3(tier_d, h, (inner_z + off) * 2.0), Vector3(sgn * (inner_x + off + tier_d * 0.5), h * 0.5, 0), mat, false)
			_box(self, Vector3(wx, h, tier_d), Vector3(0, h * 0.5, sgn * (inner_z + off + tier_d * 0.5)), mat, false)
			var z := -inner_z - off + 0.4
			while z < inner_z + off - 0.4:
				seats.append(Vector3(sgn * (inner_x + off + tier_d * 0.5), h, z))
				z += 0.55
			var x := -inner_x - off + 0.4
			while x < inner_x + off - 0.4:
				if not (gap_for_tunnel and absf(x) < 1.2 and t < 2):
					seats.append(Vector3(x, h, sgn * (inner_z + off + tier_d * 0.5)))
				x += 0.55
	return seats


func _ad_boards(inner_x: float, inner_z: float, colors: Array, text: String) -> void:
	# LED boards around the run-off, alternating team colours, with league text.
	var h := 0.9
	var segs := [
		[Vector3(0, h * 0.5, -inner_z), Vector3(inner_x * 2, h, 0.12), 0.0],
		[Vector3(0, h * 0.5, inner_z), Vector3(inner_x * 2, h, 0.12), PI],
		[Vector3(-inner_x, h * 0.5, 0), Vector3(0.12, h, inner_z * 2), PI / 2],
		[Vector3(inner_x, h * 0.5, 0), Vector3(0.12, h, inner_z * 2), -PI / 2],
	]
	var i := 0
	for s in segs:
		var col: Color = colors[i % colors.size()]
		_box(self, s[1], s[0], _mat(col.darkened(0.35), 0.4, 1.2), false)
		var l := Label3D.new()
		l.text = text
		l.font = Game.font_display
		l.font_size = 110
		l.pixel_size = 0.005
		l.modulate = Color(1, 1, 1, 0.95)
		var pos: Vector3 = s[0]
		var inward := -pos.normalized() * 0.08
		l.position = pos + inward
		l.rotation = Vector3(0, s[2], 0)
		add_child(l)
		i += 1


func _tree(pos: Vector3, scale_f: float, trunk_col: Color, leaf_col: Color) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * scale_f
	add_child(t)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.3
	cyl.height = 3.2
	trunk.mesh = cyl
	trunk.position = Vector3(0, 1.6, 0)
	trunk.material_override = _mat(trunk_col, 0.95)
	t.add_child(trunk)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31 + pos.z * 17)
	for k in 5:
		var leaf := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(1.1, 1.6)
		sp.height = sp.radius * 1.6
		sp.radial_segments = 10
		sp.rings = 6
		leaf.mesh = sp
		leaf.position = Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(3.2, 4.4), rng.randf_range(-0.9, 0.9))
		leaf.material_override = _mat(leaf_col.lerp(Color("2f4a1c"), rng.randf() * 0.4), 0.9)
		t.add_child(leaf)


func _palm(pos: Vector3, scale_f: float, lean: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * scale_f
	t.rotation = Vector3(lean, randf() * TAU, 0)
	add_child(t)
	var trunk_mat := _mat(Color("7a6046"), 0.9)
	for k in 6:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.18
		cyl.height = 1.1
		seg.mesh = cyl
		seg.position = Vector3(0, 0.55 + k * 1.0, k * k * 0.03)
		seg.rotation.x = k * 0.05
		seg.material_override = trunk_mat
		t.add_child(seg)
	var crown := Vector3(0, 6.2, 0.75)
	var leaf_mat := _mat(Color("3f7a2e"), 0.85)
	for k in 9:
		var leaf := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 3.2
		leaf.mesh = cap
		leaf.material_override = leaf_mat
		var a := TAU * k / 9.0
		leaf.position = crown + Vector3(cos(a), -0.35, sin(a)) * 1.3
		leaf.rotation = Vector3(0, -a, 0)
		leaf.rotate_object_local(Vector3.FORWARD, PI / 2 - 0.35)
		leaf.scale = Vector3(1.0, 1.0, 0.25)
		t.add_child(leaf)


func _hut(pos: Vector3, rot: float, wall: Color, roof: Color) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = rot
	add_child(h)
	_box(h, Vector3(4.0, 2.4, 3.0), Vector3(0, 1.2, 0), _mat(wall, 0.95))
	var roof_l := _box(h, Vector3(4.6, 0.15, 2.0), Vector3(0, 2.85, -0.75), _mat(roof, 0.9))
	roof_l.rotation.x = 0.5
	var roof_r := _box(h, Vector3(4.6, 0.15, 2.0), Vector3(0, 2.85, 0.75), _mat(roof, 0.9))
	roof_r.rotation.x = -0.5
	_box(h, Vector3(0.9, 1.7, 0.05), Vector3(0.6, 0.85, 1.52), _mat(Color("3b2a1c"), 0.9))


func _floodlight(pos: Vector3, look_at_pos: Vector3) -> void:
	_box(self, Vector3(0.5, pos.y, 0.5), Vector3(pos.x, pos.y * 0.5, pos.z), _mat(Color("39424e"), 0.6))
	var panel := _box(self, Vector3(3.6, 2.2, 0.3), pos, _mat(Color("fff6dc"), 0.2, 6.0), false)
	panel.basis = Basis.looking_at((look_at_pos - pos).normalized(), Vector3.UP)


# ---------------------------------------------------------------- grounds

func _build_dome(hc: Color, ac: Color, banner: String) -> void:
	_environment(Color("0b0f1a"), Color("2a3550"), Color("0b0f1a"), 1.25, 0.55, 0.012, Color("1a2236"), false, Color("070a12"))
	sun.rotation = Vector3(deg_to_rad(-72), deg_to_rad(25), 0)
	sun.light_color = Color("fff3e0")
	_court("mat", Color("ff8a1f"), Color("f3efe6"), Color("0f2c57"))
	_mat_label(banner, Vector3(0, 0.012, -HALF_L - 1.2), 0.0, 120)
	_mat_label(banner, Vector3(0, 0.012, HALF_L + 1.2), PI, 120)
	_box(self, Vector3(60, 0.1, 60), Vector3(0, -0.06, 0), _surface_mat("floor"), false)
	_ad_boards(8.6, 10.2, [hc, ac, Color("ff9a1f")], banner)
	var seats := _stands(9.6, 11.2, 9, _mat(Color("1b2433"), 0.8))
	_crowd(seats, [hc, ac, hc, ac, Color("f3efe6"), Color("ff9a1f"), Color("2b2b2b")], Color("a06a48"), Vector3.ZERO)
	# Roof lighting rig.
	for x in [-6.0, -2.0, 2.0, 6.0]:
		for z in [-7.0, 0.0, 7.0]:
			_box(self, Vector3(1.6, 0.25, 0.9), Vector3(x, 14.0, z), _mat(Color("fff7e6"), 0.2, 5.0), false)
	for x in [-9.0, 9.0]:
		_box(self, Vector3(0.3, 0.4, 30.0), Vector3(x, 14.4, 0), _mat(Color("2c3440"), 0.5), false)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 9, 0)
	fill.omni_range = 22.0
	fill.light_energy = 1.2
	fill.light_color = Color("dfe8ff")
	add_child(fill)


func _build_stadium(hc: Color, ac: Color, banner: String) -> void:
	_environment(Color("050b1c"), Color("1c2a4a"), Color("0a0f18"), 1.6, 0.35, 0.006, Color("101830"))
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_color = Color("f2f6ff")
	_court("mat", Color("2f6fd6").darkened(0.35), Color("f3efe6"), Color("163a72"))
	_mat_label(banner, Vector3(0, 0.012, -HALF_L - 1.2), 0.0, 120)
	_mat_label(banner, Vector3(0, 0.012, HALF_L + 1.2), PI, 120)
	_plane(self, Vector2(120, 120), Vector3(0, -0.02, 0), _surface_mat("grass"))
	_ad_boards(9.0, 11.0, [hc, ac], banner)
	var seats := _stands(13.0, 15.0, 12, _mat(Color("2a3140"), 0.85), false)
	_crowd(seats, [hc, ac, hc, ac, Color("f3efe6"), Color("1d4ed8"), Color("ff9933")], Color("a06a48"), Vector3.ZERO)
	for p in [Vector3(-20, 22, -22), Vector3(20, 22, -22), Vector3(-20, 22, 22), Vector3(20, 22, 22)]:
		_floodlight(p, Vector3.ZERO)


func _build_village(hc: Color, ac: Color) -> void:
	barefoot = true
	_environment(Color("4f7cc4"), Color("f2b36b"), Color("6b4a2e"), 1.9, 0.7, 0.008, Color("e8b07a"))
	sun.rotation = Vector3(deg_to_rad(-14), deg_to_rad(-60), 0)
	sun.light_color = Color("ffc98a")
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
	sky_mat.sun_curve = 0.08
	_court("mud", Color.WHITE, Color("f7f2e6"), Color.WHITE)
	_plane(self, Vector2(140, 140), Vector3(0, -0.01, 0), _surface_mat("grass"))
	var dirt := _surface_mat("mud")
	dirt.uv1_scale = Vector3(10, 10, 10)
	_plane(self, Vector2(26, 30), Vector3(0, 0.0, 0), dirt)
	# Villagers standing around the ground.
	var ring := []
	for i in 260:
		var a := TAU * i / 260.0
		var r := 11.5 + (i % 3) * 0.7
		ring.append(Vector3(cos(a) * r * 0.85, 0.0, sin(a) * r))
	_crowd(ring, [Color("f3efe6"), Color("e0c35b"), Color("c44536"), Color("3a6ea5"), Color("6a994e"), Color("f28482"), hc, ac], Color("9a6345"), Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, 40.0)
		_tree(Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(1.0, 1.6), Color("5b4330"), Color("4a6b2a"))
	_hut(Vector3(-17, 0, -12), 0.6, Color("c9a27e"), Color("7b4a2a"))
	_hut(Vector3(18, 0, -15), -0.4, Color("d8b48c"), Color("6e3f22"))
	_hut(Vector3(-20, 0, 10), 2.2, Color("e2c49b"), Color("7b4a2a"))
	# A banyan-sized tree behind one end for character.
	_tree(Vector3(4, 0, -22), 2.6, Color("4c3a2a"), Color("3f5f24"))


func _build_monsoon(hc: Color, ac: Color) -> void:
	_environment(Color("4a5562"), Color("8c96a0"), Color("3b4048"), 0.6, 0.9, 0.025, Color("7f8a95"))
	sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(20), 0)
	sun.light_color = Color("d6e0ea")
	_court("mat_wet", Color("e07a1f").darkened(0.2), Color("f3efe6"), Color("173b6b"))
	_plane(self, Vector2(140, 140), Vector3(0, -0.01, 0), _surface_mat("grass"))
	# Tin-roof pavilion on one side.
	var roof := _box(self, Vector3(24, 0.12, 6), Vector3(-12.5, 4.2, 0), _mat(Color("8f9aa3"), 0.35))
	roof.rotation.y = PI / 2
	roof.rotation.z = 0.12
	for z in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		_box(self, Vector3(0.18, 4.2, 0.18), Vector3(-10.0, 2.1, z), _mat(Color("5d6670"), 0.5))
		_box(self, Vector3(0.18, 3.6, 0.18), Vector3(-15.0, 1.8, z), _mat(Color("5d6670"), 0.5))
	var seats := _stands(10.5, 10.5, 3, _mat(Color("6c7178"), 0.9))
	var west := []
	for s in seats:
		if s.x < 0:
			west.append(s)
	_crowd(west, [Color("f3efe6"), Color("2b2b2b"), hc, ac, Color("1d4ed8"), Color("e0c35b")], Color("8a5a3f"), Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 14:
		var a := rng.randf_range(-1.2, 1.2)
		var r := rng.randf_range(16.0, 28.0)
		_palm(Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.9, 1.3), rng.randf_range(-0.12, 0.12))
	_rain()


func _rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = [600, 1400, 2600][int(Game.settings.graphics)]
	p.lifetime = 1.1
	p.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 24, 40))
	p.position = Vector3(0, 16, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.015, 0.5)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.85, 0.9, 1.0, 0.35)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = dm
	p.draw_pass_1 = drop
	add_child(p)


func _build_beach(hc: Color, ac: Color) -> void:
	barefoot = true
	_environment(Color("1f6fd0"), Color("8cc4e6"), Color("b59866"), 1.05, 0.32, 0.002, Color("cfe8f5"))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_saturation = 1.2
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(140), 0)
	sun.light_color = Color("fff1d6")
	_court("sand", Color.WHITE, Color("1d6fd1"), Color.WHITE)
	var sand := _surface_mat("sand")
	sand.uv1_scale = Vector3(20, 20, 20)
	_plane(self, Vector2(160, 70), Vector3(0, -0.01, 5), sand)
	# The sea, beyond the far end.
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 140)
	pm.subdivide_width = 48
	pm.subdivide_depth = 24
	sea.mesh = pm
	sea.position = Vector3(0, -0.25, -98)
	_water = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	_water.shader = sh
	sea.material_override = _water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var ring := []
	for i in 200:
		var a := TAU * i / 200.0
		var r := 10.5 + (i % 2) * 0.8
		var pos := Vector3(cos(a) * r * 0.85, 0.0, sin(a) * r)
		if pos.z < -8.0:
			continue
		ring.append(pos)
	_crowd(ring, [Color("f3efe6"), Color("f28482"), Color("84c7ff"), Color("ffd166"), hc, ac], Color("8f5a3c"), Vector3.ZERO)
	for x in [-16.0, -11.0, 12.0, 17.0]:
		_palm(Vector3(x, 0, randf_range(-6.0, 12.0)), randf_range(1.0, 1.3), randf_range(-0.2, 0.2))
	# Beach umbrellas.
	for p in [Vector3(-12, 0, 6), Vector3(13, 0, -3), Vector3(10, 0, 9)]:
		_box(self, Vector3(0.08, 2.4, 0.08), p + Vector3(0, 1.2, 0), _mat(Color("dddddd"), 0.5))
		var top := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 1.4
		cone.height = 0.6
		top.mesh = cone
		top.position = p + Vector3(0, 2.5, 0)
		top.material_override = _mat([hc, ac, Color("ff9a1f")][int(p.x) % 3], 0.7)
		add_child(top)
