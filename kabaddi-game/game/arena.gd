class_name Arena
extends Node3D
## Builds the court and its surroundings for one ground.
##
## Each ground is its sky and light (_env), its fixed parts (_shell: the court, the floor, stands, roofs, trees)
## and what changes from match to match or moves (_dress: the teams' boards, the crowd, rain, the sea). The fixed
## parts come baked with their lighting from assets/grounds/<id>/ (tools/bake_lighting) where they are there, and are
## built here otherwise.
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

const GROUNDS := "res://assets/grounds/"
static var use_baked := true   # off: the fixed parts built here, unlit by any bake (as tools/bake_lighting needs them)

var arena_id := "dome"
var shell: Node3D              # the ground's fixed parts
var baked := false             # ... came with their baked lighting
var crowd_mats: Array[ShaderMaterial] = []
var sun: DirectionalLight3D
var env: Environment
var barefoot := false
var _excite := 0.0
var _banner_key := ""
var _banner_labels := []

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
## excitement. Each spectator faces the court (their instance's -z): a camera behind them, as over the stand
## it looks over, sees their back, from the sheet drawn from behind. Fans in shirts wear their instance's
## colour, shaded by the shirt's own folds.
const CROWD_CARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_back : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D top_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D top_mask_back : filter_linear_mipmap, repeat_disable;
// Medium and High's second sheet (tools/crowd/variants.py): people from index people on, in their own clothes.
uniform sampler2D atlas2 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas2_back : source_color, filter_linear_mipmap, repeat_disable;
uniform float people = 8.0;   // people on the first sheet
uniform float people2 = 8.0;  // on the second
uniform float frames = 8.0;
uniform bool standing = false;
uniform float excitement = 0.0;
uniform float top_lum[16];   // each person's shirt brightness, linear; 0 keeps their own clothes
uniform float top_lum_back[16];   // the same from behind
uniform float falloff = 0.0;  // under lights (an arena, floodlights at night): the back rows darker, 0 by day
uniform float lift = 0.0;     // light of their own: under a roof on an overcast day they were black cut-outs
varying flat vec2 cell;
varying flat float dim;
varying flat float mirror;
varying flat float back;
varying flat vec3 tint;
varying flat float lum;
void vertex() {
	// Seen from behind when the camera is on the far side of them from where they face.
	vec3 to_eye = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	back = step(0.0, dot(MODEL_MATRIX[2].xz, to_eye.xz));
	// Face the camera, turning about the vertical only.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	if (!standing) {
		// Someone sitting on a tier has their legs down the front of it, but their card stands where they sit, half
		// a tier back: the tier hid them from the seat down. Drawn 0.6 m nearer the eye along its own line of sight
		// (and as much smaller, round the feet), they are where they were on screen, legs and all, in front of it.
		float d = length(MODELVIEW_MATRIX[3].xyz);
		float k = max(d - 0.6, 0.5) / d;
		MODELVIEW_MATRIX[3].xyz *= k;
		MODELVIEW_MATRIX[0].xyz *= k;
		MODELVIEW_MATRIX[1].xyz *= k;
		MODELVIEW_MATRIX[2].xyz *= k;
	}
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
	dim = 1.0 - falloff * clamp((length(MODEL_MATRIX[3].xz) - 10.0) / 12.0, 0.0, 1.0);
	mirror = step(0.5, fract(ph * 7.77));
	tint = INSTANCE_CUSTOM.rgb;
	lum = back > 0.5 ? top_lum_back[int(person)] : top_lum[int(person)];
}
void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, mirror), UV.y);
	vec4 c;
	if (cell.x < people) {
		uv = (cell + uv) / vec2(people, frames);
		c = back > 0.5 ? texture(atlas_back, uv) : texture(atlas, uv);
	} else {
		uv = (cell - vec2(people, 0.0) + uv) / vec2(people2, frames);
		c = back > 0.5 ? texture(atlas2_back, uv) : texture(atlas2, uv);
	}
	vec3 col = c.rgb;
	if (lum > 0.0 && tint.r + tint.g + tint.b > 0.003) {
		float m = back > 0.5 ? texture(top_mask_back, uv).r : texture(top_mask, uv).r;
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722)) / lum;
		col = mix(col, tint * clamp(l, 0.2, 1.5), m);
	}
	ALBEDO = col * dim;
	EMISSION = col * dim * lift;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Lit a little from above as well as from the front, like the heads and shoulders they are.
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(0.0, 0.8, 0.0, 0.0)).xyz);
}
"""
const CROWD_DIR := "res://assets/crowd/"
static var _crowd_sheets := {}   # the crowd's sprite sheet once loaded, by detail (Medium and High's has 16 people,
                                 # Low's 8): {} when the game has none

## A body drawn a second time (its material's next pass), flattened onto the floor along the sun's light and see-through
## black: its shadow, for when the sun casts none (Low graphics). The stencil lets each pixel be darkened once, however
## many limbs or players overlap there. Fog is left on: a shadow far off fades into the haze as the floor does.
const FLOOR_SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, world_vertex_coords, shadows_disabled;
stencil_mode read, write, compare_not_equal, 1;
uniform vec3 light_dir = vec3(0.0, -1.0, 0.0);   // the way the sun's light travels
uniform float floor_y = 0.013;                    // just over the court's lines and lettering
uniform float strength = 0.5;                     // how much darker the floor is in it (SHADE)
void vertex() {
	VERTEX += light_dir * (max(VERTEX.y - floor_y, 0.0) / -light_dir.y);
	VERTEX.y = floor_y;
}
void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = strength;
}
"""
static var _floor_shadow_shader: Shader = null
var floor_shadow: ShaderMaterial   # the players' shadows when the sun casts none: see HumanModel.set_floor_shadow
# How much darker the court is in the sun's shadow on each ground, with its baked lighting: the court seen from above
# with the sun and without it (all a shadow keeps), in linear light, lit 0.206 / shaded 0.058 in the dome, stadium
# 0.195 / 0.040, village 0.368 / 0.122, monsoon 0.088 / 0.011, beach 0.399 / 0.067 (tests/shade_check, 0.9.0's
# grounds); as the Compatibility renderer blends, in sRGB, 1 - srgb(shaded) / srgb(lit).
const SHADE := {"dome": 0.46, "stadium": 0.54, "village": 0.40, "monsoon": 0.68, "beach": 0.57}
# How strongly the sky lights a ground's bake, of its ambient light (tools/bake_lighting). The beach's clear evening sky
# lit its open sand at full strength almost as brightly as the sun did: from the broadcast camera the sand in shade was
# 72 % as bright as in the sun, and the shadows hardly showed. At 0.45, 43 %.
const BAKE_SKY := {"beach": 0.45}


## banner_text: the league's name on the boards and the run-off, a translation key (or words to show as they are), in
## capitals in the game's language, and redrawn when the language changes.
func build(p_arena_id: String, home_color: Color, away_color: Color, banner_text: String) -> void:
	_banner_key = banner_text
	arena_id = p_arena_id if p_arena_id in ["stadium", "village", "monsoon", "beach"] else "dome"
	_env()
	var path := GROUNDS + "%s/%s.tscn" % [arena_id, arena_id]
	if use_baked and ResourceLoader.exists(path):
		shell = (load(path) as PackedScene).instantiate()
		add_child(shell)
		# What it was baked with: the sky and sun are the arena's own (_env), and the lights that were only there for
		# the bake would light the players as well, at a cost on phones.
		for n in shell.get_children():
			if n is WorldEnvironment or n is Light3D or n.has_meta("bake_only"):
				shell.remove_child(n)
				n.free()
		baked = true
	else:
		shell = Node3D.new()
		shell.name = "Shell"
		add_child(shell)
		_shell()
	var banner := _banner()
	_dress(home_color, away_color, banner)
	for l in find_children("*", "Label3D", true, false):
		if (l as Label3D).text == banner:
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_banner_labels.append(l)


func _banner() -> String:
	return tr(_banner_key).to_upper()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _banner_labels.is_empty():
		var banner := _banner()
		for l in _banner_labels:
			if is_instance_valid(l):
				(l as Label3D).text = banner


## The ground as tools/bake_lighting bakes it: the sky, the sun and the fixed parts, with the lights that are only
## there to be baked (floodlights, roof lamps: their light on the ground is baked; the players are lit by the sun).
func build_for_bake(p_arena_id: String) -> Array:
	arena_id = p_arena_id
	_env()
	shell = Node3D.new()
	shell.name = "Shell"
	add_child(shell)
	_shell()
	return _bake_lights()


## Each ground's sky (a photographed one outdoors: Scenery.sky, turned so its sun is where the ground's sun is; its
## light as strong as the painted sky's before it, as measured looking up and sideways), sun, fog and grade.
func _env() -> void:
	match arena_id:
		"stadium":
			# An overcast night over the city, its cloud lit from below by the streets; the floodlights' white light.
			_environment(Scenery.sky("kloppenheim_07_puresky", 0.0, 0.4, 0.06, 0.25, Color(0.12, 0.13, 0.1), 0.7), Color.BLACK,
				1.6, 0.35, 0.006, Color("101830"))
			sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
			sun.light_color = Color("f2f6ff")
			_grade(Color(0.0, 0.012, 0.04), Color(1.0, 0.98, 0.94), 0.3)   # night: blue shadows, warm floodlit highlights
		"village":
			barefoot = true
			# Dusk: the sun low over the far side, the sky going pink and lilac.
			_environment(Scenery.sky("qwantani_dusk_2_puresky", 0.077, 1.4, 0.6, 0.39, Color(0.32, 0.24, 0.17)), Color.BLACK,
				1.9, 0.7, 0.0035, Color("d9a383"))
			sun.rotation = Vector3(deg_to_rad(-VILLAGE_SUN), deg_to_rad(-60), 0)
			sun.light_color = Color("ffc98a")
			_grade(Color(0.025, 0.012, 0.0), Color(1.0, 0.97, 0.92), 0.2)   # late afternoon: warm through
		"monsoon":
			# A light haze of rain (0.025 was a fog that greyed out the far stand and the trees).
			_environment(Scenery.sky("overcast_soil_puresky", -0.023, 1.2, 0.31, 0.15, Color(0.16, 0.14, 0.12), 0.35), Color.BLACK,
				0.6, 0.9, 0.009, Color("7f8a95"))
			sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(20), 0)
			sun.light_color = Color("d6e0ea")
			_grade(Color(0.03, 0.035, 0.045), Color(0.95, 0.97, 1.0), 0.08)   # overcast: soft, cool, a little hazy
		"beach":
			barefoot = true
			# Puri faces the Bay of Bengal, east (-z, the sea): the evening sun is over the land behind the broadcast
			# camera, west-south-west and low, and the sky over the sea is the clear blue opposite a sunset.
			_environment(Scenery.sky("qwantani_sunset_puresky", 0.817, 1.0, 1.06, 0.9, Color(0.45, 0.38, 0.28), 1.15), Color.BLACK,
				1.6, 0.32, 0.0011, Color("c9d8e6"))
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.adjustment_saturation = 1.1
			sun.rotation = Vector3(deg_to_rad(-24), deg_to_rad(30), 0)
			sun.light_color = Color("ffdcb0")
			# Evening: teal shadows, warm sand, the sun's light warm and the colour less strong than the day's (1.2): with
			# both, the sand went orange. (The grade gentler, the sky is a little bluer close up but the sand loses its
			# colour in the broadcast view, which is mostly sand: measured 0.18 -> 0.15 saturation, 0.18 before the pass.)
			_grade(Color(0.0, 0.02, 0.03), Color(1.0, 0.98, 0.93), 0.25)
		_:
			_environment(null, Color("070a12"), 1.25, 0.55, 0.012, Color("1a2236"), Color("2a3550"))
			sun.rotation = Vector3(deg_to_rad(-72), deg_to_rad(25), 0)
			sun.light_color = Color("fff3e0")
			_grade(Color(0.0, 0.006, 0.025), Color(1.0, 0.99, 0.97), 0.25)   # indoors: cool shadows under warm lamps
	_floor_shadow(SHADE[arena_id])


## A grade for the ground, after tonemapping: each channel from lift (its black) to gain (its white), along a gentle
## S curve (contrast, 0 a straight line). A one-dimensional lookup the Compatibility renderer applies too.
func _grade(lift: Color, gain: Color, contrast: float) -> void:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 9:
		var t := i / 8.0
		var s := lerpf(t, t * t * (3.0 - 2.0 * t), contrast)
		offsets.append(t)
		colors.append(Color(lerpf(lift.r, gain.r, s), lerpf(lift.g, gain.g, s), lerpf(lift.b, gain.b, s)))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var lut := GradientTexture1D.new()
	lut.gradient = g
	lut.width = 256
	env.adjustment_color_correction = lut


func _shell() -> void:
	match arena_id:
		"stadium":
			_shell_stadium()
		"village":
			_shell_village()
		"monsoon":
			_shell_monsoon()
		"beach":
			_shell_beach()
		_:
			_shell_dome()


func _dress(hc: Color, ac: Color, banner: String) -> void:
	match arena_id:
		"stadium":
			_dress_stadium(hc, ac, banner)
		"village":
			_dress_village(hc, ac)
		"monsoon":
			_dress_monsoon(hc, ac)
		"beach":
			_dress_beach(hc, ac)
		_:
			_dress_dome(hc, ac, banner)


## 0..1 crowd energy; decays on its own.
## What the players' feet sound on (Sfx.step): the village's beaten earth, Puri's sand, the mats everywhere else.
func step_surface() -> String:
	return {"village": "earth", "beach": "sand"}.get(arena_id, "mat")


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


const TEX := "res://assets/grounds/textures/"
# Metres of mat the mat's texture covers (tools/ground_art/make_textures.py makes it so). The other surfaces are
# photographed: Scenery.ground, Scenery.wall.
const PERIOD := {"mat": 2.0}
static var _tex := {}


static func _texture(name: String) -> Texture2D:
	# Medium and High lay the 2K texture where there is one (tools/ground_art: the mat's albedo); Low never loads it.
	if Game.detail_textures() and ResourceLoader.exists(TEX + name + "_2k.png"):
		name += "_2k"
	if not _tex.has(name):
		var path := TEX + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


## A surface from tools/ground_art: its detail texture times col, its normal map. Its UV scale is set where it is laid
## (_lay: by the size of what it covers), or it is laid in world space (world: stands, a floor slab).
func _textured(kind: String, col: Color, rough: float, normal_scale: float, world := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.albedo_texture = _texture(kind + "_albedo")
	var nt := _texture(kind + "_normal")
	if nt:
		m.normal_enabled = true
		m.normal_texture = nt
		m.normal_scale = normal_scale
	m.set_meta("period", float(PERIOD.get(kind, 2.0)))
	if world:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / float(PERIOD.get(kind, 2.0))
	return m


## The material laid on a plane of this size: its texture repeats at the surface's own period.
func _lay(m: Material, size: Vector2) -> Material:
	if not (m is StandardMaterial3D) or not m.has_meta("period") or (m as StandardMaterial3D).uv1_triplanar:
		return m
	var d: StandardMaterial3D = m.duplicate()
	var per := float(m.get_meta("period"))
	d.uv1_scale = Vector3(size.x / per, size.y / per, 1.0)
	return d


## A court's surface: the mats (a texture of their own), the earth and sand courts and the dome's floor (photographed:
## Scenery.ground). The scans are as dark as real earth and sand; the grounds' light was set for the lighter textures
## before them, so they are lightened to about those, in their colour too (their mean in linear light: the village's
## beaten earth 0.13 -> 0.21 and its red earth 0.12 -> 0.2, as the old mud's 0.27; Puri's sand 0.18 -> 0.44, as the
## old sand's 0.48), as measured on the baked grounds.
func _surface_mat(kind: String) -> Material:
	var m: Material
	match kind:
		"mat":
			m = _textured("mat", Color("1d4f9c"), 0.55, 0.5)
		"mat_wet":
			var w := _textured("mat", Color("1a4687"), 0.18, 0.6)
			w.metallic_specular = 0.8
			m = w
		"mud":
			# The village court: beaten earth, going to the red earth round it past its lines and sitting blocks.
			m = Scenery.ground("brown_mud_dry", 2.6, Color(1.76, 1.98, 2.3), {"b": "red_dirt_mud_01", "period_b": 2.4,
				"tint_b": VILLAGE_EARTH, "band_mode": 3, "b_band": Vector4(6.4, 7.4, 0.0, 1.8), "band_noise": 1.2,
				"rough_a": 0.95, "rough_b": 0.92})
		"sand":
			m = _beach_sand()
		"floor":
			m = Scenery.ground("concrete_floor", 3.0, Color(0.04, 0.085, 0.24), {"rough_a": 0.38, "spec": 0.6, "vary": 0.05})
		_:
			m = StandardMaterial3D.new()
	return m


const VILLAGE_EARTH := Color(1.52, 2.0, 2.5)


## Puri's sand, dry and light, darker and wet toward the sea (-z).
func _beach_sand() -> ShaderMaterial:
	return Scenery.ground("coast_sand_01", 2.2, Color(1.75, 1.8, 2.0), {"b": "damp_beach_sand", "period_b": 2.2,
		"tint_b": Color(1.8, 1.85, 2.05), "band_mode": 1, "b_band": Vector4(0.0, -1.0, 16.0, 24.0), "rough_a": 0.95,
		"rough_b": 0.55})


## The stands' concrete in col: the photographed concrete's grain, as light as the stands' texture before it (0.764).
func _stand_mat(col: Color) -> Material:
	return Scenery.wall("concrete_floor", col, 0.764)


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
	mi.material_override = _lay(mat, size)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _court(surface: String, lobby_tint: Color, line_color: Color, surround: Color) -> void:
	var court := Node3D.new()
	court.name = "Court"
	shell.add_child(court)
	var field_mat := _surface_mat(surface)
	if surface == "mat" or surface == "mat_wet":
		# Run-off mat, lobbies, then the field.
		var run_off := _textured("mat", surround, 0.6 if surface == "mat" else 0.22, 0.5)
		_plane(court, Vector2(16.0, 19.0), Vector3(0, 0.0, 0), run_off)
		var lobby_mat: StandardMaterial3D = field_mat.duplicate()
		lobby_mat.albedo_color = lobby_tint
		_plane(court, Vector2(LOBBY, HALF_L * 2), Vector3(-HALF_W - LOBBY * 0.5, 0.003, 0), lobby_mat)
		_plane(court, Vector2(LOBBY, HALF_L * 2), Vector3(HALF_W + LOBBY * 0.5, 0.003, 0), lobby_mat)
		_plane(court, Vector2(HALF_W * 2, HALF_L * 2), Vector3(0, 0.004, 0), field_mat)
		# Sitting blocks behind each end line.
		var sb := _textured("mat", lobby_tint.darkened(0.2), 0.6, 0.5)
		_plane(court, Vector2(8.0, 1.0), Vector3(0, 0.004, HALF_L + 2.5), sb)
		_plane(court, Vector2(8.0, 1.0), Vector3(0, 0.004, -HALF_L - 2.5), sb)
	else:
		# Earth and sand courts are the ground itself, marked out: a plane of their own for a finer bake (the village's
		# taking in its sitting blocks, where the beaten earth goes to the red earth round it).
		var size := Vector2(14.0, 20.0) if surface == "mud" else Vector2(HALF_W * 2 + 2 * LOBBY + 0.6, HALF_L * 2 + 0.6)
		_plane(court, size, Vector3(0, 0.004, 0), field_mat).set_meta("lm_texel", 0.06)

	# A bench in each sitting block for players who are out: both, in one go.
	var bench := []
	for sgn in [-1.0, 1.0]:
		var bz: float = sgn * (HALF_L + 2.62)
		bench.append([Vector3(7.8, 0.06, 0.4), Vector3(0, 0.39, bz)])
		for bx in [-3.7, -1.25, 1.25, 3.7]:
			bench.append([Vector3(0.06, 0.36, 0.34), Vector3(bx, 0.18, bz)])
	_boxes(court, bench, _mat(Color("3a4a5c") if surface.begins_with("mat") else Color("6b4a2e"), 0.7)).name = "Benches"

	# The lines, all in one go: 5 cm wide, baked at 2.5 cm a texel (tools/bake_lighting) to be more than a texel across.
	var y := 0.009
	var full_w := (HALF_W + LOBBY) * 2
	var lines := []
	# End lines and outer boundary (including lobbies).
	for z in [-HALF_L, HALF_L]:
		lines.append([Vector3(0, y, z), Vector2(full_w, LINE_W)])
	for x in [-HALF_W - LOBBY, -HALF_W, HALF_W, HALF_W + LOBBY]:
		lines.append([Vector3(x, y, 0), Vector2(LINE_W, HALF_L * 2)])
	# Midline, wider than the rest.
	lines.append([Vector3(0, y + 0.001, 0), Vector2(full_w, LINE_W * 1.6)])
	for sgn in [-1.0, 1.0]:
		lines.append([Vector3(0, y, sgn * BAULK), Vector2(HALF_W * 2, LINE_W)])
		lines.append([Vector3(0, y, sgn * BONUS), Vector2(HALF_W * 2, LINE_W)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in lines:
		var pm := PlaneMesh.new()
		pm.size = l[1]
		st.append_from(pm, 0, Transform3D(Basis(), l[0]))
	var mi := MeshInstance3D.new()
	mi.name = "Lines"
	mi.mesh = st.commit()
	mi.material_override = _mat(line_color, 0.7, 0.15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("lm_texel", 0.025)
	court.add_child(mi)


## Boxes, each [size, centre] or [size, centre, turn (a Basis)], as one mesh in mat: one draw however many there are.
func _boxes(parent: Node3D, boxes: Array, mat: Material, cast := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		var bm := BoxMesh.new()
		bm.size = b[0]
		st.append_from(bm, 0, Transform3D(b[2] if b.size() > 2 else Basis(), b[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if not cast:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


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

## The ground's environment: its sky (or indoors, without one, the background colour bg and an ambient light of
## ambient_color), the sun, the ambient light's strength, fog, glow and the adjustments.
func _environment(sky: Sky, bg: Color, sun_energy: float, ambient: float, fog_density := 0.0, fog_color := Color.BLACK, ambient_color := Color.BLACK) -> void:
	env = Environment.new()
	if sky:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	if fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density
		# A photographed sky shows through its haze: the fog takes the sky's own colour where it is seen against it.
		env.fog_sky_affect = 0.12 if sky else 0.4
		env.fog_aerial_perspective = 0.5 if sky else 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_energy = sun_energy
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	graphics_changed()


## The sun's shadows and the glow for the graphics level now; again when a match lowers it on a slow phone.
func graphics_changed() -> void:
	var g := int(Game.settings.graphics)
	env.glow_enabled = g >= Game.GFX_MEDIUM
	# The sky's light from its HDR, and the surfaces' normal maps, on Medium and High.
	if env.sky:
		Scenery.sky_detail(env.sky)
	RenderingServer.global_shader_parameter_set("scenery_detail", 1.0 if g >= Game.GFX_MEDIUM else 0.0)
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if g < Game.GFX_HIGH else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


## The players' shadows on the floor when the sun casts none (HumanModel.set_floor_shadow), along the sun's light and
## as dark as the sun's own shadow on the court (strength: SHADE).
func _floor_shadow(strength: float) -> void:
	if _floor_shadow_shader == null:
		_floor_shadow_shader = Shader.new()
		_floor_shadow_shader.code = FLOOR_SHADOW_SHADER
	floor_shadow = ShaderMaterial.new()
	floor_shadow.shader = _floor_shadow_shader
	floor_shadow.set_shader_parameter("light_dir", -sun.transform.basis.z)
	floor_shadow.set_shader_parameter("strength", strength)


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
		_crowd_cards(chosen.filter(func(p): return p.y > 0.2), palette, false, rng, facing)
		_crowd_cards(chosen.filter(func(p): return p.y <= 0.2), palette, true, rng, facing)
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


## The crowd's sprite sheet for this graphics level: on Low the eight people; on Medium and High sixteen, the eight
## and, on a second sheet beside theirs, the eight again in other colours (tools/crowd/variants.py). hi forces one or
## the other.
static func crowd_sheet(hi := -1) -> Dictionary:
	var detail := Game.detail_textures() if hi < 0 else hi == 1
	var sfx := "_hi" if detail and ResourceLoader.exists(CROWD_DIR + "crowd_atlas_hi.webp") else ""
	if not _crowd_sheets.has(sfx):
		var sheet := {}
		var f := FileAccess.open(CROWD_DIR + "crowd_atlas.json", FileAccess.READ)
		if f and ResourceLoader.exists(CROWD_DIR + "crowd_atlas.webp"):
			var info = JSON.parse_string(f.get_as_text())
			if info is Dictionary:
				sheet = {"info": info, "atlas": load(CROWD_DIR + "crowd_atlas.webp"),
					"mask": load(CROWD_DIR + "crowd_mask.png")}
				# From behind, if drawn (tools/crowd/render_crowd.gd); else the front again.
				var has_back := ResourceLoader.exists(CROWD_DIR + "crowd_atlas_back.webp")
				sheet["atlas_back"] = load(CROWD_DIR + "crowd_atlas_back.webp") if has_back else sheet.atlas
				sheet["mask_back"] = load(CROWD_DIR + "crowd_mask_back.png") if has_back else sheet.mask
				var g := FileAccess.open(CROWD_DIR + "crowd_atlas_hi.json", FileAccess.READ) if sfx != "" else null
				var hi_info = JSON.parse_string(g.get_as_text()) if g else null
				if hi_info is Dictionary:
					sheet.info = hi_info
					sheet["atlas2"] = load(CROWD_DIR + "crowd_atlas_hi.webp")
					sheet["atlas2_back"] = load(CROWD_DIR + "crowd_atlas_hi_back.webp")
		_crowd_sheets[sfx] = sheet
	return _crowd_sheets[sfx]


## Spectators as camera-facing cards, each facing the point facing (the court's middle): their instance's
## -z points there, so the card shows their back to a camera behind them. Fans in shirts are picked more
## often than the rest, and most wear a colour from the palette (the teams' colours among them); children are
## fewer.
func _crowd_cards(spots: Array, palette: Array, standing: bool, rng: RandomNumberGenerator, facing: Vector3) -> void:
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
	var lums_back := PackedFloat32Array()
	lums_back.resize(16)
	var total := 0.0
	# A person in other colours (the sixteen-person sheet) shares the person's own share of the crowd.
	var alike := {}
	for p in people:
		alike[int(p.get("base", -1))] = int(alike.get(int(p.get("base", -1)), 0)) + 1
	for i in people.size():
		var file := String(people[i].file)
		var wt := 3.0 if float(people[i].top_luminance) > 0.0 else 1.5
		if file.contains("boy") or file.contains("girl"):
			wt = 0.8
		wt /= float(alike.get(int(people[i].get("base", -1)), 1))
		weights.append(wt)
		total += wt
		lums[i] = float(people[i].top_luminance)
		lums_back[i] = float(people[i].get("top_luminance_back", people[i].top_luminance))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _card_mesh(w, h)
	mm.instance_count = spots.size()
	# Each one's feet and forward, kept for the tests: a headless run's MultiMesh keeps no transforms.
	var faces := PackedVector3Array()
	for i in spots.size():
		var pos: Vector3 = spots[i]
		# Feet on the ground, or on the tier below the seat; the sheet has 2 cm under the feet.
		var feet := pos - Vector3(0, (0.0 if standing else 0.45) + 0.02, 0)
		var s := rng.randf_range(0.93, 1.06)
		var look := facing - feet
		look.y = 0.0
		var turn := Basis.looking_at(look.normalized(), Vector3.UP) if look.length() > 0.01 else Basis()
		mm.set_instance_transform(i, Transform3D(turn.scaled(Vector3(s, s, s)), feet))
		faces.append_array([feet, -turn.z])
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
	mmi.set_meta("faces", faces)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CROWD_CARD_SHADER
	sm.shader = sh
	sm.set_shader_parameter("atlas", sheet.atlas)
	sm.set_shader_parameter("atlas_back", sheet.atlas_back)
	sm.set_shader_parameter("top_mask", sheet.mask)
	sm.set_shader_parameter("top_mask_back", sheet.mask_back)
	sm.set_shader_parameter("people", float(info.get("columns", people.size())))
	if sheet.has("atlas2"):
		sm.set_shader_parameter("atlas2", sheet.atlas2)
		sm.set_shader_parameter("atlas2_back", sheet.atlas2_back)
		sm.set_shader_parameter("people2", float(info.get("columns2", 8)))
	sm.set_shader_parameter("frames", float((info.frames as Array).size()))
	sm.set_shader_parameter("standing", standing)
	sm.set_shader_parameter("top_lum", lums)
	sm.set_shader_parameter("top_lum_back", lums_back)
	sm.set_shader_parameter("falloff", {"dome": 0.5, "stadium": 0.4}.get(arena_id, 0.0))
	sm.set_shader_parameter("lift", {"monsoon": 0.3}.get(arena_id, 0.0))
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


## Tiered stands on all four sides (into the shell), as one mesh: one draw for every tier (there were four a tier).
func _stand_boxes(inner_x: float, inner_z: float, tiers: int, mat: Material) -> void:
	var tier_d := 0.9
	var tier_h := 0.45
	var boxes := []
	for t in tiers:
		var h := tier_h * (t + 1)
		var off := t * tier_d
		var wx := (inner_x + off) * 2.0 + tier_d * 2
		for sgn in [-1.0, 1.0]:
			boxes.append([Vector3(tier_d, h, (inner_z + off) * 2.0), Vector3(sgn * (inner_x + off + tier_d * 0.5), h * 0.5, 0)])
			boxes.append([Vector3(wx, h, tier_d), Vector3(0, h * 0.5, sgn * (inner_z + off + tier_d * 0.5))])
	var mi := _boxes(shell, boxes, mat, false)
	mi.name = "Stands"
	# The stadium's, the biggest, a little coarser: at 0.15 m their lightmap alone needed more than a 1024 atlas, and the
	# ground's went to 2048 (four times the memory). The separate boxes before had 0.19 to 0.54 m.
	mi.set_meta("lm_texel", 0.25 if arena_id == "stadium" else 0.15)


## The spectators' seats on those stands.
func _stand_seats(inner_x: float, inner_z: float, tiers: int, gap_for_tunnel := true) -> Array:
	var seats := []
	var tier_d := 0.9
	var tier_h := 0.45
	for t in tiers:
		var h := tier_h * (t + 1)
		var off := t * tier_d
		for sgn in [-1.0, 1.0]:
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


## The LED boards round the run-off: [centre, size, turn] for each side.
func _board_segments(inner_x: float, inner_z: float) -> Array:
	var h := 0.9
	return [
		[Vector3(0, h * 0.5, -inner_z), Vector3(inner_x * 2, h, 0.12), 0.0],
		[Vector3(0, h * 0.5, inner_z), Vector3(inner_x * 2, h, 0.12), PI],
		[Vector3(-inner_x, h * 0.5, 0), Vector3(0.12, h, inner_z * 2), PI / 2],
		[Vector3(inner_x, h * 0.5, 0), Vector3(0.12, h, inner_z * 2), -PI / 2],
	]


func _ad_boards(inner_x: float, inner_z: float, colors: Array, text: String) -> void:
	# LED boards around the run-off, alternating team colours, with league text.
	var segs := _board_segments(inner_x, inner_z)
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


# ---------------------------------------------------------------- scenery round a ground

## About where the broadcast camera stands: the trees' cut-outs face it.
const TV_EYE := Vector3(11.0, 5.8, 0.0)
## Trees nearer the broadcast camera than this are the full model on Medium and High where their kind has one;
## cut-outs further off, and all of them on Low (they look far more real than a cut-down tree at that distance, at 4
## triangles each: the shared assets' own rule).
const NEAR_TREE := 25.0
## The seats' height, for whoever sits on them.
const SEAT_H := {"monobloc_chair": 0.44, "folding_stool": 0.44}
## The scorers' chairs at a local ground, behind their table (Officials sits them there).
const SCORERS_CHAIRS := [[Vector3(-8.2, 0, -0.45), PI / 2], [Vector3(-8.2, 0, 0.45), PI / 2]]
## A canopy's middle and half size for each tree, at its own size (1): for the bake's stand-ins (_bake_lights).
const CANOPY := {"rain_tree": [Vector3(0, 9.5, 0), Vector3(7.5, 3.2, 7.5)], "island_tree_a": [Vector3(0, 6.0, 0), Vector3(4.0, 2.6, 4.0)],
	"island_tree_b": [Vector3(0, 5.2, 0), Vector3(4.0, 2.0, 4.0)]}

var _blob_spots := []   # the seats' and tables' contact shadows, drawn in one go (_scenery_done)


## Trees, each [kind, position, size (1: the model's own), colour]: kind one in assets/scenery/trees (rain_tree,
## coconut_palm, island_tree_a, island_tree_b). A cut-out faces the broadcast camera, turned a quarter or a half for
## every other tree (its other side, or its mirror image) so no two of a kind look alike; the full model, where the
## kind has one, for the near ones on Medium and High. Each kind is drawn in one go.
func _trees(list: Array, sway := 0.0) -> void:
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var groups := {}
	for t in list:
		var kind: String = t[0]
		var pos: Vector3 = t[1]
		var full := not low and ResourceLoader.exists(Scenery.DIR + "trees/%s.res" % kind) \
			and Vector2(pos.x - TV_EYE.x, pos.z - TV_EYE.z).length() < NEAR_TREE
		var path := "trees/" + kind + ("" if full else "_card")
		var to_eye := TV_EYE - pos
		var turn := int(absf(pos.x * 7.0 + pos.z * 13.0)) % 4
		var yaw := atan2(to_eye.x, to_eye.z) + turn * PI * 0.5 if not full else fposmod(pos.x * 1.7 + pos.z * 2.3, TAU)
		if not groups.has(path):
			groups[path] = [[], []]
		groups[path][0].append(Scenery.at(pos, yaw, float(t[2])))
		groups[path][1].append(t[3] if t.size() > 3 else Color.WHITE)
	for path in groups:
		Scenery.scatter(self, path, groups[path][0], low, groups[path][1], true, sway)


## Seats, each [position, the way it faces (radians)]: kind monobloc_chair or folding_stool, drawn in one go, a soft
## shadow under each. Returns a place on each for someone sitting on it, as _crowd takes them (a sitting person's
## card a little forward of the seat, so its front edge does not cut across their knees).
func _seats(kind: String, list: Array, colors := []) -> Array:
	var xf := []
	var spots := []
	for c in list:
		var p: Vector3 = c[0]
		var yaw: float = c[1]
		xf.append(Scenery.at(p, yaw))
		_blob_spots.append([p, 0.34, 0.34, yaw])
		spots.append(p + Vector3(sin(yaw), 0, cos(yaw)) * 0.2 + Vector3(0, float(SEAT_H[kind]) + 0.02, 0))
	Scenery.scatter(self, "seating/" + kind, xf, int(Game.settings.graphics) == Game.GFX_LOW, colors)
	return spots


## A row of seats from a to b (spaced gap apart), facing the way facing (radians).
func _seat_row(a: Vector3, b: Vector3, gap: float, facing: float) -> Array:
	var out := []
	var n := int((b - a).length() / gap) + 1
	for i in n:
		out.append([a.lerp(b, float(i) / maxf(n - 1, 1)), facing])
	return out


## Dry grass growing round a ground's edge and against what stands on it: clumps of cut-outs, in one go.
func _grass_clumps(spots: Array, rng: RandomNumberGenerator) -> void:
	var xf := []
	var col := []
	for p in spots:
		for k in rng.randi_range(2, 4):
			var q: Vector3 = p + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			xf.append(Scenery.at(q, atan2(TV_EYE.x - q.x, TV_EYE.z - q.z) + rng.randf_range(-0.3, 0.3), rng.randf_range(0.7, 1.25)))
			col.append(Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25)))
	Scenery.scatter(self, "foliage/dry_grass_tall_card", xf, true, col, false, 0.08)


## What the scenery round a ground left to do once it is all there: the contact shadows, in one go.
func _scenery_done() -> void:
	Scenery.blobs(self, _blob_spots, 0.38)
	_blob_spots = []


## A village house (into the shell): plastered walls on a plinth, a door and a window, gables, and a pitched roof of
## clay tiles or thatch (the photographed surfaces, laid along the house's own sides).
func _hut(pos: Vector3, rot: float, wall: Color, thatch: bool) -> void:
	var h := Node3D.new()
	h.name = "Hut"
	h.position = pos
	h.rotation.y = rot
	shell.add_child(h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in [[Vector3(4.0, 2.4, 3.0), Vector3(0, 1.2, 0)], [Vector3(4.24, 0.32, 3.24), Vector3(0, 0.16, 0)]]:
		var bm := BoxMesh.new()
		bm.size = b[0]
		st.append_from(bm, 0, Transform3D(Basis(), b[1]))
	# The gables, up to the ridge under the roof.
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 2.0
		var tri := [Vector3(x, 2.4, -1.5), Vector3(x, 2.4, 1.5), Vector3(x, 3.18, 0.0)]
		if sx < 0.0:
			tri.reverse()
		for v in tri:
			gable.set_normal(Vector3(sx, 0, 0))
			gable.set_uv(Vector2(v.z, v.y))
			gable.add_vertex(v)
	gable.index()
	gable.generate_tangents()
	st.append_from(gable.commit(), 0, Transform3D())
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = st.commit()
	walls.material_override = Scenery.wall("clay_plaster", wall, 0.55, true, 2.0)
	h.add_child(walls)
	_boxes(h, [[Vector3(0.9, 1.75, 0.06), Vector3(0.75, 0.32 + 0.875, 1.52)], [Vector3(0.7, 0.6, 0.06), Vector3(-1.0, 1.5, 1.52)]],
		_mat(Color("3b2a1c"), 0.9)).name = "Openings"
	var roof := _boxes(h, [[Vector3(4.6, 0.12, 2.0), Vector3(0, 2.82, -0.78), Basis(Vector3.RIGHT, 0.5)],
		[Vector3(4.6, 0.12, 2.0), Vector3(0, 2.82, 0.78), Basis(Vector3.RIGHT, -0.5)]],
		Scenery.surface("thatch_roof_angled" if thatch else "clay_roof_tiles", 1.6 if thatch else 2.4))
	roof.name = "Roof"


## A blue tarpaulin on bamboo poles (into the shell), size across and along, its middle sagging, as at a village
## ground in the rains: spectators sit under it on plastic chairs.
func _tarp(centre: Vector3, size: Vector2, height: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	for i in n:
		for j in n:
			var quad := []
			for c in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var u: float = c.x / n - 0.5
				var v: float = c.y / n - 0.5
				var sag: float = 0.45 * (1.0 - 4.0 * u * u) * (1.0 - 4.0 * v * v)
				quad.append(Vector3(u * size.x, height - sag - v * 0.5, v * size.y))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(quad[k].x, quad[k].z) / 2.0)
				st.add_vertex(quad[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Tarp"
	mi.mesh = st.commit()
	mi.position = centre
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("245aa0")
	m.roughness = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	shell.add_child(mi)
	var poles := []
	for u in [-0.5, 0.0, 0.5]:
		for v in [-0.5, 0.5]:
			var top: float = height - v * 0.5
			poles.append([Vector3(0.09, top, 0.09), centre + Vector3(u * size.x, top * 0.5, v * size.y)])
	_boxes(shell, poles, _mat(Color("9c8152"), 0.8)).name = "Poles"


## A spot light that is only there to be baked (see _bake_lights), at pos, pointed at the point aim.
func _bake_spot(pos: Vector3, aim: Vector3, angle: float, reach: float, energy: float, col: Color, size: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.transform = Transform3D(Basis.looking_at((aim - pos).normalized(), Vector3.UP if absf((aim - pos).normalized().y) < 0.99 else Vector3.FORWARD), pos)
	l.spot_angle = angle
	l.spot_range = reach
	l.light_energy = energy
	l.light_color = col
	l.light_size = size   # the bake's soft shadows
	l.shadow_enabled = true
	return l


## The lights that are only there for tools/bake_lighting: the roof's lamps, the floodlights. Their light on the
## fixed parts is baked; they are taken out when the baked ground is loaded (build): the players are lit by the sun.
func _bake_lights() -> Array:
	var lights := []
	match arena_id:
		"dome":
			for x in [-6.0, -2.0, 2.0, 6.0]:
				for z in [-7.0, 0.0, 7.0]:
					lights.append(_bake_spot(Vector3(x, 13.8, z), Vector3(x * 0.8, 0, z * 0.8), 60.0, 24.0, 1.5, Color("fff3e0"), 0.6))
		"stadium":
			for p in STADIUM_FLOODS:
				lights.append(_bake_spot(p - (p * Vector3(1, 0, 1)).normalized() * 0.5, Vector3(0, 0, 0), 32.0, 75.0, 9.0, Color("f2f6ff"), 2.5))
	for l in lights:
		l.light_bake_mode = Light3D.BAKE_STATIC
		shell.add_child(l)
	# The teams' boards are put up for each match (_dress); for the bake, plain ones in their place, so the floor
	# has their shadow and a little of their glow. They go when the baked ground is loaded.
	var boards := {"dome": [8.6, 10.2], "stadium": [9.0, 11.0]}
	if boards.has(arena_id):
		var glow := _mat(Color("2a2f3a"), 0.4)
		glow.emission_enabled = true
		glow.emission = Color("fff1dc")
		glow.emission_energy_multiplier = 0.45
		for seg in _board_segments(boards[arena_id][0], boards[arena_id][1]):
			_box(shell, seg[1], seg[0], glow).set_meta("bake_only", true)
	# The trees are put up for each match too (_dress: copies of a model, which a bake cannot take in); for the bake, a
	# rough crown in each one's place, so the ground has the shade under it. They go when the baked ground is loaded.
	var trees: Array = {"village": _village_trees, "monsoon": _monsoon_trees, "beach": _beach_trees}.get(arena_id,
		func(): return []).call()
	var crown := _mat(Color("4a5a30"), 0.9)
	for t in trees:
		if not CANOPY.has(t[0]):
			continue
		var s: float = t[2]
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()   # 1 m across
		sp.radial_segments = 12
		sp.rings = 6
		mi.mesh = sp
		mi.position = t[1] + CANOPY[t[0]][0] * s
		mi.scale = CANOPY[t[0]][1] * s * 2.0
		mi.material_override = crown
		mi.set_meta("bake_only", true)
		mi.set_meta("lm_texel", 1.5)
		shell.add_child(mi)
	return lights


# ---------------------------------------------------------------- grounds

const STADIUM_FLOODS := [Vector3(-20, 22, -22), Vector3(20, 22, -22), Vector3(-20, 22, 22), Vector3(20, 22, 22)]


func _shell_dome() -> void:
	_court("mat", Color("ff8a1f"), Color("f3efe6"), Color("0f2c57"))
	_box(shell, Vector3(60, 0.1, 60), Vector3(0, -0.06, 0), _surface_mat("floor"), false)
	_stand_boxes(9.6, 11.2, 9, _stand_mat(Color("27324a")))
	# Roof lighting rig: the lamps, and the beams they hang from.
	var lamps := []
	for x in [-6.0, -2.0, 2.0, 6.0]:
		for z in [-7.0, 0.0, 7.0]:
			lamps.append([Vector3(1.6, 0.25, 0.9), Vector3(x, 14.0, z)])
	_boxes(shell, lamps, _mat(Color("fff7e6"), 0.2, 5.0), false).name = "Lamps"
	_boxes(shell, [[Vector3(0.3, 0.4, 30.0), Vector3(-9.0, 14.4, 0)], [Vector3(0.3, 0.4, 30.0), Vector3(9.0, 14.4, 0)]],
		_mat(Color("2c3440"), 0.5), false).name = "Beams"


func _dress_dome(hc: Color, ac: Color, banner: String) -> void:
	_mat_label(banner, Vector3(0, 0.012, -HALF_L - 1.2), 0.0, 120)
	_mat_label(banner, Vector3(0, 0.012, HALF_L + 1.2), PI, 120)
	_ad_boards(8.6, 10.2, [hc, ac, Color("ff9a1f")], banner)
	_crowd(_stand_seats(9.6, 11.2, 9), [hc, ac, hc, ac, Color("f3efe6"), Color("ff9a1f"), Color("2b2b2b")], Color("a06a48"), Vector3.ZERO)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 9, 0)
	fill.omni_range = 22.0
	fill.light_energy = 1.2
	fill.light_color = Color("dfe8ff")
	add_child(fill)


func _shell_stadium() -> void:
	_court("mat", Color("2f6fd6").darkened(0.35), Color("f3efe6"), Color("163a72"))
	_plane(shell, Vector2(240, 240), Vector3(0, -0.02, 0), Scenery.ground("grass_ground", 3.0, Color(1.1, 2.3, 1.7)))
	_stand_boxes(13.0, 15.0, 12, _stand_mat(Color("343d50")))
	# The floodlight towers: their masts, and their lamps facing the court.
	var masts := []
	var lamps := []
	for p in STADIUM_FLOODS:
		masts.append([Vector3(0.5, p.y, 0.5), Vector3(p.x, p.y * 0.5, p.z)])
		lamps.append([Vector3(3.6, 2.2, 0.3), p, Basis.looking_at((Vector3.ZERO - p).normalized(), Vector3.UP)])
	_boxes(shell, masts, _mat(Color("39424e"), 0.6)).name = "Masts"
	_boxes(shell, lamps, _mat(Color("fff6dc"), 0.2, 6.0), false).name = "Floodlights"


func _dress_stadium(hc: Color, ac: Color, banner: String) -> void:
	_mat_label(banner, Vector3(0, 0.012, -HALF_L - 1.2), 0.0, 120)
	_mat_label(banner, Vector3(0, 0.012, HALF_L + 1.2), PI, 120)
	_ad_boards(9.0, 11.0, [hc, ac], banner)
	_crowd(_stand_seats(13.0, 15.0, 12, false), [hc, ac, hc, ac, Color("f3efe6"), Color("1d4ed8"), Color("ff9933")], Color("a06a48"), Vector3.ZERO)
	_skyline()


## The city round the National Stadium at night: apartment blocks beyond its stands on three sides, dark against the
## cloud the city lights from below, their walls faintly lit from the street.
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var xf := []
	var col := []
	var n := 26
	for i in n:
		var a := lerpf(-1.95, 1.95, (i + rng.randf_range(0.2, 0.8)) / n)   # round from the far side's middle (-x)
		var r := rng.randf_range(62.0, 95.0)
		var p := Vector3(-cos(a) * r, 0, sin(a) * r)
		var w := rng.randf_range(1.0, 1.5)
		var basis := Basis(Vector3.UP, atan2(-p.x, -p.z) + rng.randf_range(-0.25, 0.25)).scaled(Vector3(w, rng.randf_range(0.8, 1.7), w))
		xf.append(Transform3D(basis, p))
		col.append(Color(1, 1, 1) * rng.randf_range(0.7, 1.3))   # some walls darker than others
	var mmi := Scenery.scatter(self, "buildings/city_apartments", xf, int(Game.settings.graphics) == Game.GFX_LOW, col, false)
	mmi.material_override = Scenery.night_block(mmi.multimesh.mesh.resource_path.get_basename().trim_prefix(Scenery.DIR))


# Gaon Maidan: a village ground at dusk. Beaten earth, the red earth round it going to worn grass, houses and the
# village temple among rain trees, the village on plastic chairs and folding stools along the far side and standing
# round the rest.
const VILLAGE_SUN := 17.0                                # the sun's height in the sky, degrees
const VILLAGE_SUN_WAY := Vector3(-0.866, 0.0, 0.5)       # and the way to it along the ground
const VILLAGE_HUTS := [[Vector3(-22, 0, -14), 0.55, Color("eadfca"), false], [Vector3(-25, 0, 5), 1.35, Color("e2b989"), true],
	[Vector3(-16, 0, 21), 2.3, Color("cddde2"), false], [Vector3(16, 0, -22), -0.5, Color("ead3bf"), true]]
## The village temple (shared assets: generated for the game), across the ground from the broadcast camera, facing the
## court, beside the rain tree at (-23.8, -6).
const VILLAGE_TEMPLE := Vector3(-20, 0, 1)


func _village_trees() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var kinds := ["rain_tree", "rain_tree", "island_tree_a", "island_tree_b", "rain_tree", "coconut_palm"]
	var tries := 0
	while out.size() < 30 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, 52.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.x > 18.0 and rng.randf() < 0.6:
			continue   # behind the broadcast camera: fewer
		if r < 70.0 and p.normalized().dot(VILLAGE_SUN_WAY) > 0.82:
			continue   # where the low sun is: a tree there would lay its shadow across the court
		var clear := p.distance_to(VILLAGE_TEMPLE) > 7.0
		for h in VILLAGE_HUTS:
			clear = clear and p.distance_to(h[0]) > 7.0
		for t in out:
			clear = clear and p.distance_to(t[1]) > (9.0 if t[0] == "rain_tree" else 6.0)
		if not clear:
			continue
		var kind: String = kinds[out.size() % kinds.size()]
		var s := rng.randf_range(0.8, 1.15) if kind == "rain_tree" else rng.randf_range(0.85, 1.25)
		var green := Color(rng.randf_range(0.82, 1.0), rng.randf_range(0.85, 1.0), rng.randf_range(0.75, 0.95))
		out.append([kind, p, s, green])
	# The big rain tree behind one end, the ground's landmark.
	out.append(["rain_tree", Vector3(4, 0, -27), 1.3, Color(0.9, 0.95, 0.85)])
	return out


func _shell_village() -> void:
	_court("mud", Color.WHITE, Color("f7f2e6"), Color.WHITE)
	_plane(shell, Vector2(300, 300), Vector3(0, -0.01, 0), Scenery.ground("red_dirt_mud_01", 2.4, VILLAGE_EARTH,
		{"b": "grass_ground", "period_b": 3.0, "tint_b": Color(1.15, 2.0, 1.4), "b_cover": 0.1, "band_mode": 2,
		"b_band": Vector4(0, 0, 18.0, 34.0), "band_noise": 9.0}))
	for h in VILLAGE_HUTS:
		_hut(h[0], h[1], h[2], h[3])


func _dress_village(hc: Color, ac: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	_trees(_village_trees(), 0.12)
	Scenery.scatter(self, "buildings/indian_village_temple", [Scenery.at(VILLAGE_TEMPLE, PI / 2)], low)
	_blob_spots.append([VILLAGE_TEMPLE, 2.7, 3.2, PI / 2])
	# Plastic chairs in two rows along the far side, stools at the ends, and standing round the rest.
	var chairs := _seat_row(Vector3(-10.5, 0, -7.6), Vector3(-10.5, 0, 7.6), 0.7, PI / 2)
	chairs.append_array(_seat_row(Vector3(-11.35, 0, -7.25), Vector3(-11.35, 0, 7.25), 0.7, PI / 2))
	var white := []
	for i in chairs.size():
		white.append(Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.12)) if rng.randf() < 0.85 else Color("d8e4f0"))
	chairs.append_array(SCORERS_CHAIRS)
	var spots := _seats("monobloc_chair", chairs, white)
	spots.resize(spots.size() - SCORERS_CHAIRS.size())   # Officials sits the scorers there
	var stools := []
	for end in [-1.0, 1.0]:
		for i in 7:
			var x := -3.3 + i * 1.1 + rng.randf_range(-0.2, 0.2)
			stools.append([Vector3(x, 0, end * rng.randf_range(11.0, 11.6)), (0.0 if end < 0 else PI) + rng.randf_range(-0.3, 0.3)])
	spots.append_array(_seats("folding_stool", stools))
	for i in 300:
		var a := TAU * i / 300.0 + rng.randf_range(-0.008, 0.008)
		var r := 12.3 + (i % 3) * 0.75 + rng.randf_range(-0.3, 0.3)
		var p := Vector3(cos(a) * r * 0.9, 0.0, sin(a) * r)
		if p.x < -9.8 and absf(p.z) < 8.8:
			p.x -= 2.6   # behind the chairs
		if absf(p.z) > 10.6 and absf(p.x) < 4.5:
			p.z += signf(p.z) * 1.4   # behind the stools
		spots.append(p)
	_crowd(spots, [Color("f3efe6"), Color("e0c35b"), Color("c44536"), Color("3a6ea5"), Color("6a994e"), Color("f28482"), hc, ac], Color("9a6345"), Vector3.ZERO)
	# Dry grass round the ground's edge, and against the houses.
	var clumps := []
	for i in 40:
		var a := rng.randf() * TAU
		clumps.append(Vector3(cos(a), 0, sin(a)) * rng.randf_range(17.0, 30.0))
	for h in VILLAGE_HUTS:
		clumps.append(h[0] + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5)))
	clumps.append(VILLAGE_TEMPLE + Vector3(0.5, 0, 3.0))
	_grass_clumps(clumps, rng)
	_scenery_done()


# Monsoon Ground: a mat under heavy cloud in the rain. Wet mud and puddles round it, a tin-roofed pavilion on one side,
# low stands round, rain trees dark with the wet and palms, and spectators under a tarpaulin at one end.
func _monsoon_trees() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var kinds := ["rain_tree", "coconut_palm", "rain_tree", "island_tree_a", "coconut_palm", "rain_tree"]
	var tries := 0
	while out.size() < 24 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(22.0, 50.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var clear := absf(p.z + 17.5) > 6.0 or absf(p.x + 2.0) > 8.0   # not in the tarpaulin's place
		for t in out:
			clear = clear and p.distance_to(t[1]) > (9.0 if t[0] == "rain_tree" else 5.0)
		if not clear:
			continue
		var kind: String = kinds[out.size() % kinds.size()]
		var wet := rng.randf_range(0.55, 0.7)   # dark with the rain
		out.append([kind, p, rng.randf_range(0.8, 1.15), Color(wet * 0.95, wet, wet * 0.9)])
	return out


func _shell_monsoon() -> void:
	_court("mat_wet", Color("e07a1f").darkened(0.2), Color("f3efe6"), Color("173b6b"))
	_plane(shell, Vector2(300, 300), Vector3(0, -0.01, 0), Scenery.ground("brown_mud", 2.4, Color(1.9, 1.85, 1.8),
		{"wet": 0.85, "puddles": 0.24, "rough_a": 0.55, "b": "grass_ground", "period_b": 3.0,
		"tint_b": Color(1.0, 1.9, 1.3), "band_mode": 2, "b_band": Vector4(0, 0, 18.0, 36.0), "band_noise": 9.0}))
	# Tin-roof pavilion on one side.
	_boxes(shell, [[Vector3(24, 0.12, 6), Vector3(-12.5, 4.2, 0), Basis(Vector3.UP, PI / 2) * Basis(Vector3.BACK, 0.12)]],
		_mat(Color("8f9aa3"), 0.35)).name = "Roof"
	var posts := []
	for z in [-11.0, -5.5, 0.0, 5.5, 11.0]:
		posts.append([Vector3(0.18, 4.2, 0.18), Vector3(-10.0, 2.1, z)])
		posts.append([Vector3(0.18, 3.6, 0.18), Vector3(-15.0, 1.8, z)])
	_boxes(shell, posts, _mat(Color("5d6670"), 0.5)).name = "Posts"
	_stand_boxes(10.5, 10.5, 3, _stand_mat(Color("7a8088")))
	_tarp(Vector3(-2.0, 0, -17.5), Vector2(9.0, 5.5), 2.7)


func _dress_monsoon(hc: Color, ac: Color) -> void:
	_trees(_monsoon_trees(), 0.25)
	var west := []
	for s in _stand_seats(10.5, 10.5, 3):
		if s.x < 0:
			west.append(s)
	# Under the tarpaulin: three rows of chairs facing the court, in its shade.
	var chairs := []
	for row in 3:
		chairs.append_array(_seat_row(Vector3(-6.0, 0, -15.6 - row * 0.95), Vector3(2.0, 0, -15.6 - row * 0.95), 0.72, 0.0))
	var shade := []
	for c in chairs:
		shade.append(Color(0.62, 0.64, 0.68))
	chairs.append_array(SCORERS_CHAIRS)
	var sat := _seats("monobloc_chair", chairs, shade)
	sat.resize(sat.size() - SCORERS_CHAIRS.size())
	west.append_array(sat)
	_crowd(west, [Color("f3efe6"), Color("2b2b2b"), hc, ac, Color("1d4ed8"), Color("e0c35b")], Color("8a5a3f"), Vector3.ZERO)
	_rain()
	_scenery_done()


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


# Puri Beach in the evening: the court marked on the sand, the beach running down into the Bay of Bengal at the far
# end (-z), coconut palms along the shore and trees inland, spectators on plastic chairs and standing round.
const SHORE := -28.0   # where the sea meets the sand
## Puri's landmark, the Jagannath temple's tower (shared assets: generated for the game, 60 m), on the far shore of the
## bay up the coast, 850 m from the broadcast camera and in the evening haze, where the camera sees it over the sea
## (any nearer and the top of a 60 m tower is above the top of the picture); the shore it stands on, with palms along it.
const PURI_TOWER := Vector3(-765, 0, -346)
const PURI_SHORE := [Vector3(-820, 0.02, -420), Vector2(700, 360)]   # the headland: its middle and size


func _beach_trees() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var tries := 0
	while out.size() < 26 and tries < 500:
		tries += 1
		var p := Vector3(rng.randf_range(-60.0, 45.0), 0, rng.randf_range(-16.0, 60.0))
		if absf(p.x) < 15.0 and p.z < 22.0:
			continue   # the beach the match is on
		var clear := true
		for t in out:
			clear = clear and p.distance_to(t[1]) > 6.0
		if not clear:
			continue
		# Palms along the shore; inland, broadleaf trees among them.
		var kind := "coconut_palm" if p.z < 30.0 or rng.randf() < 0.4 else ("island_tree_a" if rng.randf() < 0.5 else "island_tree_b")
		out.append([kind, p, rng.randf_range(0.75, 1.1), Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.88, 1.0), rng.randf_range(0.8, 0.95))])
	return out


func _shell_beach() -> void:
	_court("sand", Color.WHITE, Color("1d6fd1"), Color.WHITE)
	var sand := _beach_sand()
	_plane(shell, Vector2(320, 180), Vector3(0, -0.01, 66.0), sand)   # down to z = -24, where it starts to slope
	var slope := _plane(shell, Vector2(320, 14.03), Vector3(0, -0.43, -31.0), sand)
	slope.rotation.x = -atan(0.84 / 14.0)   # 0.84 m down into the sea over 14 m: the water's edge at SHORE
	slope.set_meta("lm_texel", 0.4)   # 320 m long: at a plane's usual texel, more than a 1024 lightmap atlas holds
	# Beach umbrellas: their poles, and each canopy in its colour.
	var tops := [Color("e4572e"), Color("2e86de"), Color("f6c445")]
	var spots := [Vector3(-12, 0, 6), Vector3(13, 0, -3), Vector3(10, 0, 9)]
	var poles := []
	for p in spots:
		poles.append([Vector3(0.08, 2.4, 0.08), p + Vector3(0, 1.2, 0)])
	_boxes(shell, poles, _mat(Color("dddddd"), 0.5)).name = "UmbrellaPoles"
	for i in spots.size():
		var top := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 1.4
		cone.height = 0.6
		cone.radial_segments = 24
		cone.rings = 1
		top.mesh = cone
		top.position = spots[i] + Vector3(0, 2.5, 0)
		top.material_override = _mat(tops[i], 0.7)
		shell.add_child(top)


func _dress_beach(hc: Color, ac: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# The sea: near the beach finely, for the swell where the waves run up the sand; beyond, out to the horizon.
	var water := Scenery.sea(SHORE)
	for part in [[Vector2(320, 72), Vector3(0, -0.25, -62.0), Vector2i(160, 36)], [Vector2(2400, 1100), Vector3(0, -0.25, -648.0), Vector2i(48, 22)]]:
		var sea := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = part[0]
		pm.subdivide_width = part[2].x
		pm.subdivide_depth = part[2].y
		sea.mesh = pm
		sea.position = part[1]
		sea.material_override = water
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sea)
	var trees := _beach_trees()
	var far_rng := RandomNumberGenerator.new()
	far_rng.seed = 41
	var x := -1000.0
	while x < -540.0:
		trees.append(["coconut_palm", Vector3(x, 0, PURI_SHORE[0].z + PURI_SHORE[1].y * 0.5 - far_rng.randf_range(6.0, 30.0)),
			far_rng.randf_range(0.85, 1.2), Color.WHITE])
		x += far_rng.randf_range(14.0, 34.0)
	_trees(trees, 0.3)
	var shore := MeshInstance3D.new()
	var land := PlaneMesh.new()
	land.size = PURI_SHORE[1]
	shore.mesh = land
	shore.position = PURI_SHORE[0]
	var edge: float = PURI_SHORE[0].z + PURI_SHORE[1].y * 0.5   # its shore, toward the beach
	shore.material_override = Scenery.ground("grass_ground", 3.0, Color(1.1, 1.3, 0.95), {"b": "coast_sand_01",
		"period_b": 2.2, "tint_b": Color(1.85, 1.8, 1.75), "band_mode": 1, "b_band": Vector4(0.0, 1.0, edge - 24.0, edge - 12.0)})
	shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shore)
	Scenery.scatter(self, "buildings/jagannath_tower", [Scenery.at(PURI_TOWER, atan2(TV_EYE.x - PURI_TOWER.x, TV_EYE.z - PURI_TOWER.z))],
		true, [], false)
	# Plastic chairs along the far side; standing round the rest, but for the sea's end.
	var chairs := _seat_row(Vector3(-10.4, 0, -6.2), Vector3(-10.4, 0, 8.2), 0.72, PI / 2)
	chairs.append_array(_seat_row(Vector3(-11.25, 0, -5.8), Vector3(-11.25, 0, 7.8), 0.72, PI / 2))
	var col := []
	for c in chairs:
		col.append([Color.WHITE, Color("e8eef4"), Color("f2e6c8"), Color("cfe3f2")][rng.randi() % 4])
	chairs.append_array(SCORERS_CHAIRS)
	var spots := _seats("monobloc_chair", chairs, col)
	spots.resize(spots.size() - SCORERS_CHAIRS.size())
	for i in 220:
		var a := TAU * i / 220.0
		var r := 11.0 + (i % 2) * 0.8
		var pos := Vector3(cos(a) * r * 0.9, 0.0, sin(a) * r)
		if pos.z < -8.0:
			continue
		if pos.x < -9.6 and absf(pos.z) < 9.0:
			pos.x -= 2.4   # behind the chairs
		spots.append(pos)
	_crowd(spots, [Color("f3efe6"), Color("f28482"), Color("84c7ff"), Color("ffd166"), hc, ac], Color("8f5a3c"), Vector3.ZERO)
	_scenery_done()
