class_name Arena
extends Node3D
## A floorball venue: the rink to the IFF's measurements (Rules 101-105) and the hall round it. A local sports hall
## (birch slats, one bank of seats behind the benches, high windows), a city arena (dark, stands all round with
## aisles, an LED ribbon round their fronts, a hanging scoreboard, light rigs) or a school gym (painted walls, wall
## bars, a few parents).
##
## The rink: the sports floor with its markings painted into one texture (lines 5 cm, the goal creases, the
## goalkeeper areas, the centre line and spot, the face-off dots), a grain and the overhead lights' sheen in its
## shader; white plastic boards in 2 m panels with rounded corners and plain advertising (the game's own name and
## slogans only); the two red goals with their nets; the teams' benches on the far side, the penalty benches and the
## secretariat on the near side.
##
## Everything static is merged by material (Geo) over one texture sheet (assets/crowd/venue_atlas.png, made by
## tools/crowd/make_venue.gd): opaque, glowing, cut-out and see-through, a draw call each, the floor one more, the crowd
## one and the bench's people one (Crowd). The halls' walls are real surfaces baked into that sheet (birch slats from a
## maple veneer scan, painted concrete block lit from its normal map). The floor is one plane over the whole hall: the
## rink's markings, and round them the hall's floor, both with a scanned surface (rubber sports tiles; the school's
## wooden boards) for grain, and its normal map on Medium and High.
##
## The halls' fittings are models from assets/shared (Poly Haven and the owner's), one MultiMeshInstance3D a model, so
## each costs a draw call however many there are: the sports hall's pull-out aluminium bleachers, pale birch gym
## benches, wall clocks, fluorescent battens (sports hall), pendant lamps (school), Nordic break-glass fire alarm call
## points and a wet floor sign. Low skips the smallest (call points, the sign) and draws
## the sports hall's battens as glowing panels. Every model is its _low file (the lamps, clock, call point and sign
## are the same mesh at both levels, seen from far off), but for the gym benches and bleachers on High; the call
## point has one file for every level.

const FLOOR_PX := 32.0        # floor texture pixels a metre (40 m x 20 m: 1280 x 640)
const SHEET := "res://assets/crowd/venue_atlas.png"
const SHEET_H := 1024.0
## The sheet's strips: [top, height] in pixels (tools/crowd/make_venue.gd's STRIPS). Each is 1024 px along.
const STRIPS := {
	"plain": [0, 16], "board": [16, 64], "ads1": [80, 64], "ads2": [144, 64], "led": [208, 64], "seats": [272, 64],
	"slats": [336, 64], "panel": [400, 64], "parquet": [464, 48], "step": [512, 32], "windows": [544, 64],
	"score": [608, 64], "net": [672, 32], "truss": [704, 64], "block": [768, 128], "signs": [896, 64], "tread": [960, 32],
	"ceiling": [992, 32],
}
## The signs strip's pieces, as fractions along it (make_venue.gd's SIGNS): [start, length].
const SIGNS := {"exit": [0.0, 0.125], "door": [0.125, 0.25], "glass": [0.375, 0.25], "mat": [0.625, 0.125], "alarm": [0.75, 0.0625]}
const SHARED := "res://assets/shared/"
## The floor's scanned surfaces: [albedo, normal, metres a repeat, the albedo's mean brightness] (the 1024 px files;
## Medium and High load the same scans at 2048 px, _2k).
const SURFACES := {
	"rubber": ["surfaces/rubber_tiles/rubber_tiles_albedo_1k.jpg", "surfaces/rubber_tiles/rubber_tiles_normal_1k.jpg", 3.0, 0.13],
	"wood": ["surfaces/wood_floor/wood_floor_albedo_1k.jpg", "surfaces/wood_floor/wood_floor_normal_1k.jpg", 1.4, 0.39],
}
const ROW_RISE := 0.42        # the stands: each row this much higher ...
const ROW_DEPTH := 0.8        # ... and this much further back
const SEAT := 0.5             # a seat's width
const METAL_ROWS := 5         # the arena's lower tier: rows of steel bleacher
## The hall's bleacher section (assets/shared/stands/bleacher_hall): its depth, how far a section behind is raised,
## and each row's seat plank [height, z from the section's middle] (measured from the model).
const BLEACHER_D := 2.4
const BLEACHER_LIFT := 1.35
const BLEACHER_ROWS := [[0.33, 0.8], [0.76, 0.38], [1.2, -0.5]]

var venue := "hall"
var home_colors: Array = []
var away_colors: Array = []
var crowd: Crowd
var bench_crowd: Crowd
var _lit: Geo                 # opaque structure, lit
var _glow: Geo                # lamps, screens, LED boards, windows: unshaded
var _cut: Geo                 # cut-outs: roof trusses
var _see: Geo                 # see-through: the nets, plexiglass
var _low := false
var _lamps := {}              # the ceiling's lamps, for the floor's reflection of them
var _half := Vector2(27, 19)  # the hall's half length and width (its walls)
var _models := 0              # model instances placed (for tests and arena_look)
var _doors: Array = []        # [the wall's foot under a door, into the hall]

static var _floor_tex: ImageTexture
static var _net_tex: ImageTexture
static var _floor_shader: Shader
static var _floor_shader_low: Shader
static var _meshes := {}      # a model's opaque meshes and their placement in it, by path and level


func _init(p_venue := "hall", p_home := [], p_away := []) -> void:
	venue = p_venue
	home_colors = p_home
	away_colors = p_away


static func s(name: String) -> Vector2:
	var a: Array = STRIPS[name]
	return Vector2(a[0] / SHEET_H, a[1] / SHEET_H)


func _ready() -> void:
	var v: Dictionary = DB.VENUES.get(venue, DB.VENUES.hall)
	_lit = Geo.new()
	_glow = Geo.new()
	_cut = Geo.new()
	_see = Geo.new()
	_low = int(Game.settings.graphics) == Game.GFX_LOW
	var spots: Array = []
	var walls := Color(String(v.walls))
	match String(v.stands):
		"bowl":
			_lamps = {"h": 12.5, "step": Vector2(6.5, 6.5), "n": Vector2i(6, 4), "size": Vector2(1.6, 0.9), "kind": "panel"}
			_half = Vector2(34, 27)
			_hall_arena(walls, 34.0, 27.0, 16.0)
			var seat := Color("24508f")
			spots = _stands(-1, 14 if not _low else 11, seat, true)
			spots.append_array(_stands(1, 14 if not _low else 11, seat, true))
			spots.append_array(_end_stands(-1, 10 if not _low else 7, seat))
			spots.append_array(_end_stands(1, 10 if not _low else 7, seat))
			_scoreboard_cube()
			_trusses(34.0, 27.0, 14.5, 7)
		"side":
			# Rows of fluorescent battens on a lighting rail under the roof trusses.
			_lamps = {"h": 8.3, "step": Vector2(7.0, 6.5), "n": Vector2i(6, 3), "size": Vector2(0.9, 0.62), "kind": "tube"}
			_half = Vector2(27, 19)
			_hall_sports(walls, 27.0, 19.0, 10.0)
			spots = _bleachers()
			_wall_bars(1, 27.0, 19.0)
			_trusses(27.0, 19.0, 10.0, 5)
		_:
			# Industrial pendant lamps on their cords from the ceiling (8 m), their bowls' rims at 6.7 m.
			_lamps = {"h": 6.75, "step": Vector2(8.0, 5.5), "n": Vector2i(5, 3), "size": Vector2(0.5, 0.5), "kind": "pendant"}
			_half = Vector2(24, 16)
			_hall_school(walls, 24.0, 16.0, 8.0)
			spots = _stands(-1, 3, Color("c8ad7f"), false)
			_wall_bars(-1, 24.0, 16.0)
			_wall_bars(1, 24.0, 16.0)
	_env(venue, float(v.light))
	_floor()
	if venue == "arena":
		_floor_decals()
		_make_light_show()
	_boards()
	_goals()
	_benches()
	_ceiling_lights()
	if venue != "arena":
		_fittings()
	var atlas: Texture2D = sheet()
	add_child(_lit.commit(Geo.sheet_material("lit", atlas, _low, int(Game.settings.graphics) >= Game.GFX_HIGH)))
	add_child(_glow.commit(Geo.sheet_material("glow", atlas)))
	add_child(_cut.commit(Geo.sheet_material("cut", atlas, _low)))
	var see := _see.commit(Geo.sheet_material("blend", atlas))
	add_child(see)
	crowd = Crowd.new()
	var palette: Array = home_colors.duplicate()
	palette.append_array(away_colors)
	crowd.build(spots, Game.crowd_density() * (1.0 if venue != "school" else 0.6), palette, hash(venue))
	add_child(crowd)
	# The stands sit in the hall's half light, the rink under the lamps.
	Crowd.set_light({"arena": 0.78, "hall": 0.95}.get(venue, 0.95) * clampf(float(v.light), 0.8, 1.1))


static func sheet() -> Texture2D:
	return load(SHEET)


# ---------------------------------------------------------------- light

func _env(kind: String, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101318") if kind == "arena" else Color("3a3d42")
	# A sports hall's light comes from everywhere above: the lamps, the pale ceiling, the floor's bounce. A sky made of
	# that (bright above, the walls' grey at the horizon, the blue floor below) gives the athletes' PBR materials
	# their soft fill and reflections; on Low a plain ambient colour does it more cheaply.
	if not _low:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.62, 0.65, 0.7)
		sky_mat.sky_horizon_color = Color(0.4, 0.4, 0.4) if kind != "arena" else Color(0.2, 0.21, 0.24)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		# Below: the floor's colour (the blue sports floor; the school's boards).
		sky_mat.ground_bottom_color = Color(0.13, 0.22, 0.36) if kind != "school" else Color(0.34, 0.27, 0.2)
		sky_mat.sky_curve = 0.25
		sky_mat.ground_curve = 0.1
		sky_mat.sun_angle_max = 0.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.42 if kind != "arena" else 0.38
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.74, 0.77, 0.82) if kind != "arena" else Color(0.62, 0.65, 0.72)
		env.ambient_light_energy = 0.62
	# Filmic on every level: in GL Compatibility it is a few instructions in the scene shader, and Low with the linear
	# curve showed the rink 40% darker than Medium and High (the playtest, docs/PLAYTEST.md). Exposed a touch up and
	# its white point lowered so whites stay white and the shadows open (no crushed blacks).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The lamps over the rink: a high, slightly cool key from above and a little toward the camera's side, so faces
	# and kits seen from the broadcast position are lit; shadows short and under the feet.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-66, 14, 0)
	# With its shadow on (High), GL Compatibility draws the light in a pass of its own that comes out much brighter
	# and more saturated (measured on the floor, tests/arena_look.tscn): turned down there so every level looks alike.
	sun.light_energy = 0.92 * energy * (0.45 if Game.shadows_enabled() else 1.0)
	sun.light_color = Color(0.97, 0.985, 1.0)
	sun.light_specular = 0.6
	sun.shadow_enabled = Game.shadows_enabled()
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# ---------------------------------------------------------------- the floor and its markings (102)

func _floor() -> void:
	# One plane over the whole hall: the rink's sports floor with its markings, the hall's floor round it (the shader
	# tells them apart by the rink's rounded outline), a scanned surface over both.
	var kind := "wood" if venue == "school" else "rubber"
	var src: Array = SURFACES[kind]
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = _half * 2.0
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = floor_shader(_low)
	m.set_shader_parameter("marks", floor_texture())
	# Low: the 1024 px scan, no normal map; Medium and High: the 2048 px scan and its normal map.
	var res := "_1k" if _low else "_2k"
	m.set_shader_parameter("surface", load(SHARED + String(src[0]).replace("_1k", res)))
	if not _low:
		m.set_shader_parameter("surface_n", load(SHARED + String(src[1]).replace("_1k", res)))
	m.set_shader_parameter("tile_m", float(src[2]))
	m.set_shader_parameter("surface_mean", float(src[3]))
	m.set_shader_parameter("wood", 1.0 if kind == "wood" else 0.0)
	# The city arena's flooring a light sky blue with navy creases, as the Swedish league's arenas lay it; the halls keep
	# the deeper blue.
	if venue == "arena":
		m.set_shader_parameter("rink_col", Color("7fa9d4"))
		m.set_shader_parameter("crease_col", Color("2b4f8c"))
		m.set_shader_parameter("crease_x", Vector3(Rules.CREASE_FRONT, Rules.CREASE_BACK, Rules.CREASE_HALF_W))
	# Round the rink: the arena's grey sports floor over its concrete, the sports hall's own floor a darker blue-grey of
	# the same flooring; the school's boards run under the rink too.
	var surround: Color = {"arena": Color("5d636c"), "hall": Color("4f6680")}.get(venue, Color("d6c09c"))
	m.set_shader_parameter("surround", surround)
	m.set_shader_parameter("lamp_h", float(_lamps.h))
	m.set_shader_parameter("lamp_step", _lamps.step)
	m.set_shader_parameter("lamp_n", Vector2(_lamps.n))
	m.set_shader_parameter("lamp_size", _lamps.size)
	m.set_shader_parameter("lamp_round", 1.0 if String(_lamps.kind) == "pendant" else 0.0)
	m.set_shader_parameter("sheen", {"arena": 0.55, "school": 0.5}.get(venue, 0.42))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The city arena's floor decals (assets/crowd/floor_decals.png, tools/venue/make_decals.py): a disc in the centre
## circle and four panels, two each side of the centre line, as a league arena prints its sponsors on the floor (here
## the game's own name and slogans). One mesh, one draw call, a few millimetres over the floor.
func _floor_decals() -> void:
	var tex: Texture2D = load("res://assets/crowd/floor_decals.png")
	if tex == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc := Rect2(0.0, 0.0, 0.5, 1.0)
	var go := Rect2(0.5, 0.0, 0.5, 0.5)
	var tag := Rect2(0.5, 0.5, 0.5, 0.5)
	# [centre (x, z), size (along x, along z), turn (radians), the sheet's part]
	var pieces := [
		[Vector2(0, 0), Vector2(3.4, 3.4), 0.0, disc],
		[Vector2(-7.5, 5.2), Vector2(4.2, 2.0), 0.0, go],
		[Vector2(7.5, 5.2), Vector2(4.2, 2.0), 0.0, tag],
		[Vector2(-7.5, -5.2), Vector2(4.2, 2.0), PI, tag],
		[Vector2(7.5, -5.2), Vector2(4.2, 2.0), PI, go],
	]
	var corners := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	for pc: Array in pieces:
		var c: Vector2 = pc[0]
		var sz: Vector2 = pc[1]
		var r: Rect2 = pc[3]
		var uvs := [r.position, r.position + Vector2(r.size.x, 0), r.position + r.size, r.position + Vector2(0, r.size.y)]
		var pts := []
		for k in 4:
			var v: Vector2 = ((corners[k] as Vector2) * sz).rotated(float(pc[2])) + c
			pts.append(Vector3(v.x, 0.004, v.y))
		for k: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- the goal light show

var _show: MultiMeshInstance3D
var _show_t := 0.0
var _show_end := 1
const SHOW_S := 6.5      # how long the lights play after a goal
const SPOTS := 14        # coloured spots roaming the floor (and one more: the scoring goal's crease)

## The arena's light show after a goal, as in the Swedish league: pink and blue spots roam the rink and the crease of
## the goal just scored in glows. One MultiMesh of glowing quads on the floor, drawn only while it plays.
func _make_light_show() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = SPOTS + 1
	_show = MultiMeshInstance3D.new()
	_show.multimesh = mm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 col;
void vertex() { col = COLOR; }
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	// A spot (alpha 1): a soft round pool of light. The crease (alpha 0): a soft-edged rectangle.
	float spot = 1.0 - smoothstep(0.35, 1.0, length(d));
	float box = (1.0 - smoothstep(0.8, 1.0, abs(d.x))) * (1.0 - smoothstep(0.8, 1.0, abs(d.y)));
	ALBEDO = col.rgb * mix(box, spot, col.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_show.material_override = m
	_show.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show.visible = false
	add_child(_show)


## A goal scored in the goal at end (-1 or 1): the lights play for SHOW_S seconds (the city arena only).
func goal_lights(end: int) -> void:
	if _show == null:
		return
	_show_end = end
	_show_t = SHOW_S
	_show.visible = true


func _process(delta: float) -> void:
	if _show == null or _show_t <= 0.0:
		return
	_show_t -= delta
	if _show_t <= 0.0:
		_show.visible = false
		return
	var t := SHOW_S - _show_t
	var fade := clampf(t / 0.4, 0.0, 1.0) * clampf(_show_t / 1.2, 0.0, 1.0)
	var mm := _show.multimesh
	for i in SPOTS:
		# Each spot sweeps a slow figure of its own over the rink.
		var ph := float(i) * 1.7
		var x := sin(t * (0.45 + 0.05 * (i % 4)) + ph) * 15.0
		var z := cos(t * (0.38 + 0.04 * (i % 3)) + ph * 1.3) * 7.5
		var size := 1.6 + 0.9 * float(i % 3)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, 1, size)), Vector3(x, 0.012, z)))
		var c := Color(1.0, 0.35, 0.6) if i % 2 == 0 else Color(0.35, 0.65, 1.0)
		if i % 5 == 0:
			c = Color(0.9, 0.9, 1.0)
		var k := 0.55 * fade * (0.75 + 0.25 * sin(t * 6.0 + ph))
		mm.set_instance_color(i, Color(c.r * k, c.g * k, c.b * k, 1.0))
	# The crease of the goal scored in, lit pink and pulsing.
	var cx := (Rules.CREASE_FRONT + Rules.CREASE_BACK) * 0.5 * _show_end
	var cl := absf(Rules.CREASE_FRONT - Rules.CREASE_BACK)
	mm.set_instance_transform(SPOTS, Transform3D(Basis.IDENTITY.scaled(Vector3(cl + 0.6, 1, Rules.CREASE_HALF_W * 2.0 + 0.6)), Vector3(cx, 0.014, 0)))
	var g := fade * (0.45 + 0.25 * sin(t * 9.0))
	mm.set_instance_color(SPOTS, Color(1.0 * g, 0.3 * g, 0.5 * g, 0.0))


## The sports floor: its markings' texture inside the rink, the hall's floor colour outside it, a scanned surface for
## grain (rubber sports tiles; or, wood 1, the school's boards themselves, the markings painted on them), its normal
## map on Medium and High, a soft sheen, and the lamps above seen in it, blurred more the further the reflection
## travels (as on a real synthetic floor, roughness about 0.4).
static func floor_shader(low := false) -> Shader:
	if low and _floor_shader_low:
		return _floor_shader_low
	if not low and _floor_shader:
		return _floor_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D marks : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile_m = 2.0;
uniform float surface_mean = 0.13;
uniform float wood = 0.0;
uniform vec4 rink_col : source_color = vec4(0.0);   // a flooring colour of the venue's own (alpha 1), else the markings texture's blue
uniform vec3 crease_col : source_color = vec3(0.1, 0.2, 0.45);   // and its goal creases
uniform vec3 crease_x = vec3(13.15, 17.15, 2.5);   // the creases: from, to (|x|), half width
uniform vec3 surround : source_color = vec3(0.3, 0.4, 0.5);
uniform vec2 rink_half = vec2(20.0, 10.0);
uniform float corner_r = 1.5;
uniform float lamp_h = 10.0;
uniform vec2 lamp_step = vec2(8.0, 7.0);
uniform vec2 lamp_n = vec2(5.0, 3.0);
uniform vec2 lamp_size = vec2(2.4, 0.5);
uniform float lamp_round = 0.0;
uniform float sheen = 0.45;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	// Inside the rink's rounded outline (101): its markings; outside, the hall's floor.
	vec2 q = abs(p) - (rink_half - corner_r);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_r;
	float inside = 1.0 - step(0.0, sd);
	vec3 m = texture(marks, (p + rink_half) / (rink_half * 2.0)).rgb;
	float line = inside * smoothstep(0.55, 0.8, m.b * m.r);      // the white paint, smoother and brighter
	// The scanned surface: the wood's boards run along the hall.
	vec2 suv = (wood > 0.5 ? p.yx : p) / tile_m;
	vec3 st = texture(surface, suv).rgb;
	// The rink's flooring: the markings texture's blue, or the venue's own colour (the crease, darker in the texture,
	// its own darker one).
	float crease = step(crease_x.x, abs(p.x)) * step(abs(p.x), crease_x.y) * step(abs(p.y), crease_x.z);
	vec3 rink = mix(m, mix(mix(rink_col.rgb, crease_col, crease), m, line), rink_col.a);
	vec3 base = mix(surround, rink, inside);
	if (wood > 0.5) {
		// Varnished beech: the scan lifted and cooled a little.
		vec3 w = mix(st, vec3(dot(st, vec3(0.333))), 0.42) * vec3(1.5, 1.47, 1.42);
		ALBEDO = mix(w, m * 0.92, line);
		ROUGHNESS = mix(0.45, 0.4, line);
	} else {
		float g = dot(st, vec3(0.333)) / surface_mean;
		// The grain: plain on the rink (a rolled sports floor's faint texture), the tiles' joints round it.
		ALBEDO = base * mix(0.86, 0.92, line) * clamp(1.0 + (g - 1.0) * mix(2.0, 0.8, inside) * (1.0 - line * 0.8), 0.7, 1.3);
		ROUGHNESS = mix(0.45 + (g - 1.0) * 0.08, 0.35, line);
	}
	SPECULAR = 0.3;
	%s
	// The lamps' reflection: the eye's ray off the floor, up to the ceiling's lamps, the nearest one's soft shape.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 v = normalize(wpos - cam);
	vec3 r = reflect(v, vec3(0.0, 1.0, 0.0));
	float t = (lamp_h - wpos.y) / max(r.y, 0.06);
	vec2 hit = wpos.xz + r.xz * t;
	vec2 half_n = (lamp_n - 1.0) * 0.5;
	vec2 c = (clamp(floor(hit / lamp_step + half_n + 0.5), vec2(0.0), lamp_n - 1.0) - half_n) * lamp_step;
	vec2 d = abs(hit - c) - lamp_size * 0.5;
	if (lamp_round > 0.5) {
		d = vec2(length(hit - c) - lamp_size.x * 0.5);
	}
	float blur = 0.15 + t * 0.03;
	float k = (1.0 - smoothstep(-blur, blur, d.x)) * (1.0 - smoothstep(-blur, blur, d.y));
	// The glow round them, wide and faint, and Fresnel: stronger the lower the eye.
	vec2 dd = max(abs(hit) - (lamp_n * lamp_step * 0.5), vec2(0.0));
	float wide = exp(-dot(dd, dd) * 0.01) * 0.04;
	float fres = 0.3 + 0.7 * pow(1.0 - clamp(-v.y, 0.0, 1.0), 5.0);
	EMISSION = vec3(0.92, 0.95, 1.0) * (k * 1.1 + wide) * sheen * fres * (1.0 - line * 0.5);
}
""" % ("" if low else """// The surface's relief (tile joints, the boards' grain), faint under the paint.
	vec3 nm = texture(surface_n, suv).rgb;
	NORMAL_MAP = wood > 0.5 ? nm.grb : nm;
	NORMAL_MAP_DEPTH = mix(0.4, 0.12, max(inside * 0.7, line));""")
	if low:
		_floor_shader_low = sh
	else:
		_floor_shader = sh
	return sh


## The rink's floor: blue sports flooring with white markings, 4-5 cm lines (102), drawn once.
static func floor_texture() -> ImageTexture:
	if _floor_tex:
		return _floor_tex
	var w := int(Rules.LENGTH * FLOOR_PX)
	var h := int(Rules.WIDTH * FLOOR_PX)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var base := Color("2a62a8")
	img.fill(base)
	# The flooring's rolls, 2 m wide, welded: seams barely seen.
	for z in range(int(FLOOR_PX * 2.0), h, int(FLOOR_PX * 2.0)):
		img.fill_rect(Rect2i(0, z, w, 1), base.darkened(0.06))
	var line := Color("f4f6f8")
	var lw := maxi(2, int(round(0.05 * FLOOR_PX)))
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x + Rules.HALF_L) * FLOOR_PX), int((z + Rules.HALF_W) * FLOOR_PX))
	# Centre line and spot.
	var c0: Vector2i = to_px.call(0.0, -Rules.HALF_W)
	img.fill_rect(Rect2i(c0.x - lw / 2, 0, lw, h), line)
	_disc(img, to_px.call(0.0, 0.0), 0.12 * FLOOR_PX, line)
	for end: int in [-1, 1]:
		# The goal crease, 4 x 5 m (102.3), and the goalkeeper area, 1 x 2.5 m, its rear line the goal line (102.4).
		# The crease is laid in a darker blue, as on the floors of the Nordic leagues and the World Championships.
		var cx0: float = minf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		var cx1: float = maxf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		var f0: Vector2i = to_px.call(cx0, -Rules.CREASE_HALF_W)
		var f1: Vector2i = to_px.call(cx1, Rules.CREASE_HALF_W)
		img.fill_rect(Rect2i(f0, f1 - f0), base.darkened(0.38))
		_rect_outline(img, to_px.call(cx0, -Rules.CREASE_HALF_W), to_px.call(cx1, Rules.CREASE_HALF_W), lw, line)
		var gx0: float = minf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		var gx1: float = maxf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		_rect_outline(img, to_px.call(gx0, -Rules.GK_AREA_HALF_W), to_px.call(gx1, Rules.GK_AREA_HALF_W), lw, line)
		# The goal line between the posts: its marks.
		var gp: Vector2i = to_px.call(Rules.GOAL_LINE * end, 0.0)
		img.fill_rect(Rect2i(gp.x - lw / 2, int(gp.y - Rules.GOAL_W * 0.5 * FLOOR_PX), lw, int(Rules.GOAL_W * FLOOR_PX)), line)
	# The face-off dots: crosses, about 30 cm.
	for d in Rules.faceoff_dots().slice(1):
		var p: Vector2i = to_px.call(d.x, d.y)
		var arm := int(0.15 * FLOOR_PX)
		img.fill_rect(Rect2i(p.x - arm, p.y - lw / 2, arm * 2, lw), line)
		img.fill_rect(Rect2i(p.x - lw / 2, p.y - arm, lw, arm * 2), line)
	# Outside the rounded corners the boards stand: paint a dark grey there so nothing shows past them.
	var hall := Color("4a4f57")
	var r := Rules.CORNER_R * FLOOR_PX
	for sx: int in [0, 1]:
		for sz: int in [0, 1]:
			var cx := r if sx == 0 else w - r
			var cz := r if sz == 0 else h - r
			for yy in int(r) + 1:
				for xx in int(r) + 1:
					var px := int(cx - r + xx) if sx == 0 else int(cx + xx)
					var pz := int(cz - r + yy) if sz == 0 else int(cz + yy)
					if px < 0 or pz < 0 or px >= w or pz >= h:
						continue
					if Vector2(px + 0.5, pz + 0.5).distance_to(Vector2(cx, cz)) > r:
						img.set_pixel(px, pz, hall)
	img.generate_mipmaps()
	_floor_tex = ImageTexture.create_from_image(img)
	return _floor_tex


static func _rect_outline(img: Image, a: Vector2i, b: Vector2i, lw: int, col: Color) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	img.fill_rect(Rect2i(x0, y0, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y1 - lw, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y0, lw, y1 - y0), col)
	img.fill_rect(Rect2i(x1 - lw, y0, lw, y1 - y0), col)


static func _disc(img: Image, c: Vector2i, r: float, col: Color) -> void:
	for y in range(int(-r) - 1, int(r) + 2):
		for x in range(int(-r) - 1, int(r) + 2):
			if Vector2(x, y).length() <= r:
				img.set_pixel(clampi(c.x + x, 0, img.get_width() - 1), clampi(c.y + y, 0, img.get_height() - 1), col)


# ---------------------------------------------------------------- the boards (101)

## The rink's outline, inside face of the boards, as a closed polyline round the rounded corners.
static func outline(margin := 0.0, corner_seg := 8) -> Array:
	var pts := []
	var hx := Rules.HALF_L + margin
	var hz := Rules.HALF_W + margin
	var r := Rules.CORNER_R + margin
	var corners := [[Vector2(hx - r, hz - r), 0.0], [Vector2(-(hx - r), hz - r), PI * 0.5], [Vector2(-(hx - r), -(hz - r)), PI],
		[Vector2(hx - r, -(hz - r)), PI * 1.5]]
	for c in corners:
		for i in corner_seg + 1:
			var a: float = float(c[1]) + PI * 0.5 * float(i) / corner_seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## The boards as 2 m panels: the outline with its straight sides cut every 2 m.
static func _panels(margin: float) -> Array:
	var src := outline(margin, 8)
	var pts := []
	var n := src.size()
	for i in n:
		var a: Vector2 = src[i]
		var b: Vector2 = src[(i + 1) % n]
		var k := maxi(1, int(round(a.distance_to(b) / 2.0)))
		for j in k:
			pts.append(a.lerp(b, float(j) / k))
	return pts


func _boards() -> void:
	var inner := _panels(0.0)
	var outer := _panels(0.05)
	var h := Rules.BOARD_H
	var white := Color(0.97, 0.97, 0.98, 0.32)     # alpha: roughness, a plastic sheen
	var n := inner.size()
	var ad := 0
	for i in n:
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % n]
		var ao: Vector2 = outer[i]
		var bo: Vector2 = outer[(i + 1) % n]
		var len_ := a.distance_to(b)
		var mid := (a + b) * 0.5
		# A panel 2 m long on a straight side: some carry advertising; the rest white, as do the curved corners.
		var strip := s("board")
		var u0 := 0.0 if len_ > 1.5 else 0.1
		var uv := Rect2(u0, 0, len_ / 8.0, 1)
		if len_ > 1.5 and _ad_panel(mid):
			strip = s("ads1") if ad % 8 < 4 else s("ads2")
			uv = Rect2((ad % 4) * 0.25 + 0.002, 0, 0.246, 1)
			ad += 3
		_lit.face(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 0.0, h, Vector3.ZERO, Color(1, 1, 1, 0.32), strip, uv.position.x, uv.size.x)
		# The top's rounded edge and the back, white.
		_lit._tri_quad(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(bo.x, h, bo.y), Vector3(ao.x, h, ao.y), Vector3.UP, white)
		_lit.face(Vector3(ao.x, 0, ao.y), Vector3(bo.x, 0, bo.y), 0.0, h, Vector3(mid.x * 3.0, 0, mid.y * 3.0), Color(0.9, 0.9, 0.91, 0.4),
			s("board"), u0, len_ / 8.0)
	# The substitution zones' ends marked on the far board (104): dark bars on its face.
	for sx: int in [-1, 1]:
		for x: float in [Rules.SUB_ZONE_FROM_CENTRE, Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN]:
			var px := x * sx
			_lit._tri_quad(Vector3(px - 0.05, h, -Rules.HALF_W + 0.006), Vector3(px + 0.05, h, -Rules.HALF_W + 0.006),
				Vector3(px + 0.05, 0, -Rules.HALF_W + 0.006), Vector3(px - 0.05, 0, -Rules.HALF_W + 0.006), Vector3.BACK, Color("1f2933"))
	# The boards' feet behind them, every 2 m on the long sides.
	for side: int in [-1, 1]:
		for i in 17:
			var x := -16.0 + i * 2.0
			_lit.box(Vector3(x, 0.12, (Rules.HALF_W + 0.2) * side), Vector3(0.05, 0.24, 0.3), Color("c9ccd1"))


## Where a hall puts advertising on the boards: along the long sides and the ends, away from the corners and the far
## side's substitution zones (their boards stay white, the zones' ends marked).
func _ad_panel(p: Vector2) -> bool:
	if absf(p.x) > Rules.HALF_L - 1.0:
		return absf(p.y) < 6.0
	if absf(p.x) > Rules.HALF_L - Rules.CORNER_R - 0.5:
		return false
	if p.y < 0.0 and absf(p.x) > Rules.SUB_ZONE_FROM_CENTRE - 0.5 and absf(p.x) < Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN + 0.5:
		return false
	return true


# ---------------------------------------------------------------- the goals (103)

func _goals() -> void:
	var red := Color(0.82, 0.1, 0.14, 0.3)
	var r := 0.024
	var seg := 6 if _low else 10
	for end: int in [-1, 1]:
		var x := Rules.GOAL_LINE * end
		var back := x + Rules.GOAL_D * end
		var hw := Rules.GOAL_W * 0.5
		var gh := Rules.GOAL_H
		var pl := Vector3(x, 0, -hw)
		var pr := Vector3(x, 0, hw)
		# Posts and crossbar, the bottom frame round the back, the back's sloping supports.
		_lit.cylinder(pl, pl + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pr, pr + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), pr + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pl, Vector3(back, 0, -hw), r, r, red, 6, false)
		_lit.cylinder(pr, Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(Vector3(back, 0, -hw), Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), Vector3(back, 0.12, -hw), r * 0.8, r * 0.8, red, 6, false)
		_lit.cylinder(pr + Vector3(0, gh, 0), Vector3(back, 0.12, hw), r * 0.8, r * 0.8, red, 6, false)
		# The net: the back slope and the two sides, a 4 cm white mesh, seen through.
		var top_l := pl + Vector3(0, gh, 0)
		var top_r := pr + Vector3(0, gh, 0)
		var bl := Vector3(back, 0, -hw)
		var br := Vector3(back, 0, hw)
		var slope := top_l.distance_to(bl)
		var quads := [[top_l, top_r, br, bl, Rules.GOAL_W, slope], [top_l, bl, pl, pl, Rules.GOAL_D, gh], [top_r, pr, br, br, gh, Rules.GOAL_D]]
		for quad in quads:
			var nn = ((quad[1] - quad[0]).cross(quad[2] - quad[0])).normalized()
			_see.strip_quad(quad[0], quad[1], quad[2], quad[3], nn, Color(0.97, 0.97, 0.97, 0.95), s("net"),
				Rect2(0, 0, float(quad[4]) / 1.28, float(quad[5]) / 0.04))


## The old net's texture, kept for callers that warm it up at load (the net is now a strip of the venue's sheet).
static func net_texture() -> ImageTexture:
	if _net_tex:
		return _net_tex
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_net_tex = ImageTexture.create_from_image(img)
	return _net_tex


# ---------------------------------------------------------------- benches, penalty benches, secretariat (104, 105)

## A bench: a plank of moulded seats on legs, their backs behind (a strip of seats toward the rink, plain behind), a
## plexiglass panel behind that on posts; seats_col the seats', people sit on it. facing: -1 the far side's, 1 the near.
func _bench(cx: float, z: float, length: float, facing: int, seats_col: Color, back_h: float) -> void:
	var seat_y := 0.44
	var x0 := cx - length * 0.5
	var x1 := cx + length * 0.5
	_lit.box(Vector3(cx, seat_y, z), Vector3(length, 0.05, 0.42), Color(seats_col, 0.5))
	var legs := maxi(2, int(length / 2.0) + 1)
	for k in legs:
		var lx := lerpf(x0 + 0.1, x1 - 0.1, float(k) / (legs - 1))
		_lit.box(Vector3(lx, seat_y * 0.5, z), Vector3(0.05, seat_y, 0.3), Color("3a3f47"))
	var zb := z + 0.2 * facing
	var rink := Vector3(cx, 0, z - facing * 5.0)
	_lit.face(Vector3(x0, 0, zb - 0.02 * facing), Vector3(x1, 0, zb - 0.02 * facing), seat_y, seat_y + 0.4, rink,
		Color(seats_col, 0.5), s("seats"), 0.0, length / 4.0)
	_lit.face(Vector3(x0, 0, zb), Vector3(x1, 0, zb), seat_y, seat_y + 0.4, Vector3(cx, 0, z + facing * 5.0), Color(seats_col.darkened(0.3), 0.6))
	_lit.flat(x0, zb - 0.02 * facing, x1, zb, seat_y + 0.4, Color(seats_col, 0.6))
	# The back panel (plexiglass on its posts).
	if back_h > 0.0:
		var zp := z + 0.38 * facing
		_see.face(Vector3(x0, 0, zp), Vector3(x1, 0, zp), 0.0, back_h, rink, Color(0.82, 0.9, 0.95, 0.16))
		for k in 2:
			_lit.box(Vector3(x0 if k == 0 else x1, back_h * 0.5, zp), Vector3(0.05, back_h, 0.05), Color("8d939b", 0.4))
		_lit.box(Vector3(cx, back_h, zp), Vector3(length, 0.04, 0.05), Color("8d939b", 0.4))


func _benches() -> void:
	# The teams' benches behind their substitution zones on the far side, the substitutes on them.
	var spots: Array = []
	for side: int in [-1, 1]:
		var x0: float = Rules.SUB_ZONE_FROM_CENTRE * side
		var x1: float = (Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN) * side
		var cx := (x0 + x1) * 0.5
		var team: Color = (home_colors[0] if side < 0 else away_colors[0]) if not home_colors.is_empty() and not away_colors.is_empty() else Color("3b4552")
		_bench(cx, -Rules.HALF_W - 2.4, Rules.SUB_ZONE_LEN, -1, team.darkened(0.25), 1.0)
		for i in 10:
			spots.append(Vector3(cx - Rules.SUB_ZONE_LEN * 0.45 + i * Rules.SUB_ZONE_LEN * 0.9 / 9.0, 0.0, -Rules.HALF_W - 2.15))
	# The penalty benches (2 m each, at least 1 m from the centre line) and the secretariat between them, near side:
	# low, so they keep to the bottom of the picture as before.
	for side: int in [-1, 1]:
		_bench(side * 2.2, Rules.HALF_W + 1.3, 2.0, 1, Color("3b4552"), 0.95)
		# Plexiglass ends to the penalty bench.
		for e: int in [-1, 1]:
			var ex := side * 2.2 + e * 1.0
			_see._tri_quad(Vector3(ex, 0.95, Rules.HALF_W + 0.15), Vector3(ex, 0.95, Rules.HALF_W + 1.7),
				Vector3(ex, 0.0, Rules.HALF_W + 1.7), Vector3(ex, 0.0, Rules.HALF_W + 0.15), Vector3(-e, 0, 0), Color(0.82, 0.9, 0.95, 0.12))
	# The secretariat: a table with a white top and a skirt with the game's name toward the rink, two chairs, laptops.
	var tz := Rules.HALF_W + 1.5
	_lit.box(Vector3(0, 0.76, tz), Vector3(1.8, 0.04, 0.75), Color(0.95, 0.95, 0.96, 0.5))
	_lit.face(Vector3(-0.9, 0, tz - 0.36), Vector3(0.9, 0, tz - 0.36), 0.05, 0.74, Vector3.ZERO, Color(1, 1, 1, 0.5), s("ads1"), 0.0, 0.25)
	_lit.face(Vector3(-0.9, 0, tz + 0.36), Vector3(0.9, 0, tz + 0.36), 0.05, 0.74, Vector3(0, 0, 30), Color(0.17, 0.19, 0.22, 0.6))
	for k: int in [-1, 1]:
		_lit.box(Vector3(k * 0.88, 0.37, tz), Vector3(0.04, 0.74, 0.7), Color("dfe2e6"))
		_lit.box(Vector3(k * 0.42, 0.45, tz + 0.55), Vector3(0.42, 0.05, 0.4), Color("596273"))
		_lit.box(Vector3(k * 0.42, 0.7, tz + 0.74), Vector3(0.42, 0.45, 0.04), Color("596273"))
		_lit.box(Vector3(k * 0.42, 0.21, tz + 0.55), Vector3(0.05, 0.42, 0.05), Color("8d939b"))
		_lit.box(Vector3(k * 0.42, 0.79, tz + 0.05), Vector3(0.3, 0.02, 0.2), Color("4a4f57", 0.4))
		_lit.box(Vector3(k * 0.42, 0.88, tz + 0.15), Vector3(0.3, 0.18, 0.015), Color("3a3f47", 0.4))
	bench_crowd = Crowd.new()
	var pal: Array = [home_colors[0] if not home_colors.is_empty() else Color.WHITE, away_colors[0] if not away_colors.is_empty() else Color.WHITE]
	bench_crowd.build(spots, 0.7, pal, 9, 1.0)
	add_child(bench_crowd)


# ---------------------------------------------------------------- the hall

func _walls(half_x: float, half_z: float, h: float, bands: Array, pale_ceiling := false) -> void:
	# Each band: [y0, y1, colour, strip, metres a repeat along, metres a repeat up]; round all four walls.
	var corners := [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := (b - a).cross(Vector3.UP).normalized()
		var len_ := a.distance_to(b)
		for band in bands:
			var y0: float = band[0]
			var y1: float = band[1]
			var target: Array = [_glow] if band.size() > 6 and band[6] else [_lit]
			(target[0] as Geo).strip_quad(Vector3(a.x, y1, a.z), Vector3(b.x, y1, b.z), Vector3(b.x, y0, b.z), Vector3(a.x, y0, a.z), n,
				band[2], s(band[3]), Rect2(0, 0, len_ / float(band[4]), (y1 - y0) / float(band[5])))
	if pale_ceiling:
		# A hall's ceiling: white acoustic boards in 60 cm bays. Lit only by the bounce off the floor, which a lamp from
		# above cannot give a face turned down: drawn unshaded, the soft grey such a ceiling shows.
		_glow.strip_quad(Vector3(-half_x, h, half_z), Vector3(half_x, h, half_z), Vector3(half_x, h, -half_z), Vector3(-half_x, h, -half_z),
			Vector3.DOWN, Color(0.8, 0.81, 0.82), s("ceiling"), Rect2(0, 0, half_x * 2.0 / 9.6, half_z * 2.0 / 0.6))
	else:
		_lit._tri_quad(Vector3(-half_x, h, half_z), Vector3(half_x, h, half_z), Vector3(half_x, h, -half_z), Vector3(-half_x, h, -half_z), Vector3.DOWN, Color("3a3f47"))


func _hall_arena(walls: Color, half_x: float, half_z: float, h: float) -> void:
	# Behind the top rows: a concourse wall, the glass fronts of the hospitality boxes lit warm, the LED ribbon, the
	# roof's dark steel.
	walls = walls.lerp(Color("5a616c"), 0.75)
	_walls(half_x, half_z, h, [[0, 5.8, walls, "panel", 8.0, 1.6], [5.8, 7.6, Color(1.0, 0.86, 0.66), "windows", 6.0, 1.8, true],
		[7.6, 8.5, walls.darkened(0.2), "panel", 8.0, 0.9], [8.5, 9.3, Color(0.6, 0.62, 0.66), "led", 16.0, 0.8, true],
		[9.3, h, walls.darkened(0.3), "panel", 8.0, 3.0]])


func _hall_sports(_walls_col: Color, half_x: float, half_z: float, h: float) -> void:
	# A Nordic sports hall: painted block to 1.2 m (ball-proof, easy to wipe), pale birch slats above it to 6 m, painted
	# block again to the band of high windows (a pale sky only), a white ceiling on the roof's trusses.
	var paint := Color(0.97, 0.97, 0.96)
	_walls(half_x, half_z, h, [[0, 1.2, Color(0.93, 0.93, 0.93), "block", 16.0, 2.0], [1.2, 6.0, Color(1.0, 0.97, 0.92), "slats", 8.0, 2.4],
		[6.0, 8.2, paint, "block", 16.0, 2.0], [8.2, 9.4, Color(0.9, 0.92, 0.95), "windows", 8.0, 1.4, true], [9.4, h, paint, "block", 16.0, 2.0]], true)
	# A scoreboard on each end wall.
	for e: int in [-1, 1]:
		var x := (half_x - 0.05) * e
		_lit.box(Vector3(x - 0.1 * e, 5.8, 0), Vector3(0.2, 1.4, 4.2), Color("15181d"))
		_glow.face(Vector3(x - 0.21 * e, 0, -1.9), Vector3(x - 0.21 * e, 0, 1.9), 5.2, 6.4, Vector3.ZERO, Color.WHITE, s("score"), 0.0, 0.5)
		# The basketball boards, folded up to the ceiling on their winch frames as they are for every other sport.
		_backboard_folded(Vector3((half_x - 2.4) * e, h, 0.0), e)
		# The doors to the changing rooms, the exit sign over them.
		_door(Vector3(half_x * e, 0, -9.5), Vector3(-e, 0, 0))


func _hall_school(walls: Color, half_x: float, half_z: float, h: float) -> void:
	# An older school gym: concrete block painted pale, a darker dado to 1.6 m (scuffed by balls), high windows.
	var paint := walls.lerp(Color(0.96, 0.97, 0.97), 0.7)
	_walls(half_x, half_z, h, [[0, 1.6, walls.darkened(0.08), "block", 16.0, 2.0], [1.6, 6.6, paint, "block", 16.0, 2.0],
		[6.6, 7.6, Color(0.9, 0.92, 0.95), "windows", 8.0, 1.0, true], [7.6, h, paint, "block", 16.0, 2.0]], true)
	_lit.face(Vector3(-half_x, 0, -half_z + 0.01), Vector3(half_x, 0, -half_z + 0.01), 1.58, 1.64, Vector3.ZERO, Color("6f7c86"))
	for e: int in [-1, 1]:
		# A basketball board on each end wall, on its bracket.
		_backboard_wall(Vector3(half_x * e, 0, 0), e)
		_door(Vector3(half_x * e, 0, -9.0), Vector3(-e, 0, 0))
	# Climbing ropes from a steel beam in the far corner (pushed to the wall for a match, clear of the cameras behind
	# the goals), hanging clear of the floor.
	var rz := -half_z + 0.7
	_lit.box(Vector3(-half_x + 2.9, h - 0.12, rz), Vector3(4.0, 0.2, 0.12), Color("5d636b"))
	for k in 4:
		var x := -half_x + 1.4 + k * 1.0
		_lit.cylinder(Vector3(x, h - 0.22, rz), Vector3(x, 1.1, rz), 0.018, 0.018, Color("c2a878", 0.9), 5, false)
		_lit.cylinder(Vector3(x, 1.1, rz), Vector3(x, 0.95, rz), 0.03, 0.0, Color("a88f62", 0.9), 5, false)


## A double door on a wall (p the wall's foot under the door's centre, n into the hall): the doors 2 m x 2.1 m, a
## green emergency exit sign over them (lit), and a fire alarm call point beside them (a model on Medium and High).
func _door(p: Vector3, n: Vector3) -> void:
	var along := Vector3(-n.z, 0, n.x)
	var f := p + n * 0.012
	_lit.face(f - along * 1.0, f + along * 1.0, 0.0, 2.1, p + n * 5.0, Color(1, 1, 1, 0.6), s("signs"), SIGNS.door[0], SIGNS.door[1])
	# The frame round it.
	var fr := Color("8d939b", 0.5)
	for k: int in [-1, 1]:
		_lit.box(f + along * (1.04 * k) + Vector3(0, 1.08, 0), Vector3(0.08, 2.16, 0.08) if absf(n.x) < 0.5 else Vector3(0.08, 2.16, 0.08), fr)
	_lit.box(f + Vector3(0, 2.14, 0), (Vector3(2.16, 0.08, 0.08) if absf(n.x) < 0.5 else Vector3(0.08, 0.08, 2.16)), fr)
	# The exit sign: a white box out from the wall, its face lit green.
	var sp := p + n * 0.06 + Vector3(0, 2.42, 0)
	_lit.box(sp, (Vector3(0.42, 0.2, 0.1) if absf(n.x) < 0.5 else Vector3(0.1, 0.2, 0.42)), Color(0.95, 0.95, 0.95))
	var sf := sp + n * 0.052
	_glow.face(sf - along * 0.2, sf + along * 0.2, 2.33, 2.51, sf + n, Color(1, 1, 1), s("signs"), SIGNS.exit[0], SIGNS.exit[1])
	_doors.append([p, n])


## A regulation basketball board (1.80 x 1.05 m of clear glass, white lines, an orange 45 cm rim 3.05 m up and a white
## net) on a bracket from an end wall: e the end (+1: the wall at +x), p the wall's foot on the hall's axis.
func _backboard_wall(p: Vector3, e: int) -> void:
	var face_x := p.x - e * 1.2            # the board's face 1.2 m out from the wall (its baseline's place)
	var y0 := 2.9
	_board(Vector3(face_x, y0, 0), e, false)
	# The bracket: two arms from the wall to the board's back, a brace below each.
	var steel := Color("4a5058", 0.5)
	for z: float in [-0.5, 0.5]:
		_lit.box(Vector3((face_x + p.x) * 0.5, y0 + 0.75, z), Vector3(1.2, 0.08, 0.08), steel)
		_lit.cylinder(Vector3(p.x - e * 0.02, y0 - 0.4, z), Vector3(face_x + e * 0.05, y0 + 0.7, z), 0.03, 0.03, steel, 4, false)
	for z: float in [-0.5, 0.5]:
		_lit.box(Vector3(p.x - e * 0.03, y0 + 0.2, z), Vector3(0.06, 1.4, 0.1), steel)   # the wall rails


## The same board on a ceiling winch frame, folded up: the frame swung up under the roof, the board lying face down
## under it, the rim pointing to the floor and the net hanging from it. p: the ceiling over the board, e the end.
func _backboard_folded(p: Vector3, e: int) -> void:
	var y := p.y - 0.95
	_board(Vector3(p.x, y, 0), e, true)
	var steel := Color("8d939b", 0.45)
	# The frame: two lattice arms from the hinge on the ceiling near the wall to the board, a cross tube, the winch.
	var hinge_x := p.x + e * 1.9
	for z: float in [-0.55, 0.55]:
		_lit.cylinder(Vector3(hinge_x, p.y - 0.05, z), Vector3(p.x - e * 0.6, y + 0.12, z), 0.04, 0.04, steel, 5, false)
		_lit.cylinder(Vector3(p.x + e * 0.6, p.y - 0.05, z), Vector3(p.x - e * 0.6, y + 0.12, z), 0.025, 0.025, steel, 4, false)
		_lit.cylinder(Vector3(p.x + e * 0.6, p.y - 0.05, z), Vector3(hinge_x - e * 0.5, y + 0.55, z), 0.02, 0.02, steel, 4, false)
	_lit.cylinder(Vector3(p.x - e * 0.6, y + 0.12, -0.6), Vector3(p.x - e * 0.6, y + 0.12, 0.6), 0.03, 0.03, steel, 4, false)
	_lit.box(Vector3(hinge_x, p.y - 0.08, 0), Vector3(0.25, 0.16, 1.4), Color("5d636b"))
	_lit.box(Vector3(p.x + e * 0.9, p.y - 0.12, 0), Vector3(0.35, 0.22, 0.3), Color("2f6fb2", 0.5))   # the winch motor
	_lit.cylinder(Vector3(p.x + e * 0.9, p.y - 0.2, 0), Vector3(p.x - e * 0.3, y + 0.05, 0), 0.006, 0.006, Color("3a3f47"), 3, false)


## The board: glass with the white border and shooter's rectangle (the sheet's signs strip), an aluminium edge, the
## orange rim (45 cm inside, 15 cm off the glass) and its net. Upright with its face toward the hall (folded false; c the
## middle of its lower edge on its face), or folded face down (c the middle of the board's face).
func _board(c: Vector3, e: int, folded: bool) -> void:
	var w := 0.9
	var hgt := 1.05
	var edge := Color("c9ccd1", 0.4)
	var orange := Color("e0582a", 0.35)
	var rim_r := 0.235
	if not folded:
		var x := c.x
		var to := Vector3(x - e * 5.0, c.y, 0)
		_see.face(Vector3(x, 0, -w), Vector3(x, 0, w), c.y, c.y + hgt, to, Color(1, 1, 1, 1), s("signs"), SIGNS.glass[0], SIGNS.glass[1])
		for z: float in [-w, w]:
			_lit.box(Vector3(x + e * 0.02, c.y + hgt * 0.5, z), Vector3(0.04, hgt + 0.04, 0.03), edge)
		for yy: float in [c.y, c.y + hgt]:
			_lit.box(Vector3(x + e * 0.02, yy, 0), Vector3(0.04, 0.03, w * 2.0 + 0.04), edge)
		# The rim, 3.05 m up, its ring's near edge 15 cm off the glass; a plate behind it.
		var rc := Vector3(x - e * (0.15 + rim_r), 3.05, 0)
		_lit.box(Vector3(x - e * 0.08, 3.0, 0), Vector3(0.16, 0.12, 0.2), orange)
		_ring(rc, rim_r, Vector3.UP, orange)
		_net(rc, rim_r, Vector3.DOWN, 0.42)
	else:
		# Face down: the glass level, its long side across the hall, its lower edge toward the wall.
		var x0 := c.x - e * hgt * 0.5
		var x1 := c.x + e * hgt * 0.5
		_see.strip_quad(Vector3(x0, c.y, -w), Vector3(x0, c.y, w), Vector3(x1, c.y, w), Vector3(x1, c.y, -w), Vector3.DOWN, Color(1, 1, 1, 1),
			s("signs"), Rect2(SIGNS.glass[0], 0, SIGNS.glass[1], 1))
		for z: float in [-w, w]:
			_lit.box(Vector3(c.x, c.y + 0.02, z), Vector3(hgt + 0.04, 0.04, 0.03), edge)
		for xx: float in [x0, x1]:
			_lit.box(Vector3(xx, c.y + 0.02, 0), Vector3(0.03, 0.04, w * 2.0 + 0.04), edge)
		# The rim near the wall's edge of the board, now pointing down; the net hangs from it.
		var rc := Vector3(x1 - e * 0.15, c.y - 0.15 - rim_r, 0)
		_lit.box(Vector3(x1 - e * 0.15, c.y - 0.08, 0), Vector3(0.12, 0.16, 0.2), orange)
		_ring(rc, rim_r, Vector3(e, 0, 0), orange)
		_net(rc + Vector3(-e * 0.05, -0.05, 0), rim_r * 0.95, Vector3(-e * 0.35, -1, 0).normalized(), 0.4)


## A rim: a ring of round tube about the axis n.
func _ring(c: Vector3, r: float, n: Vector3, col: Color) -> void:
	var a := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var b := n.cross(a).normalized()
	var seg := 10
	for i in seg:
		var t0 := TAU * i / seg
		var t1 := TAU * (i + 1) / seg
		_lit.cylinder(c + (a * cos(t0) + b * sin(t0)) * r, c + (a * cos(t1) + b * sin(t1)) * r, 0.009, 0.009, col, 4, false)


## A basketball net: a tapering tube of the goal's net strip from the rim down (along dir), seen through.
func _net(c: Vector3, r: float, dir: Vector3, length: float) -> void:
	var a := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var b := dir.cross(a).normalized()
	var seg := 8
	var bot := c + dir * length
	for i in seg:
		var t0 := TAU * i / seg
		var t1 := TAU * (i + 1) / seg
		var d0 := a * cos(t0) + b * sin(t0)
		var d1 := a * cos(t1) + b * sin(t1)
		_see.strip_quad(c + d0 * r, c + d1 * r, bot + d1 * r * 0.6, bot + d0 * r * 0.6, (d0 + d1).normalized(), Color(1, 1, 1, 0.9),
			s("net"), Rect2(0, 0, r * 0.9 / 1.28 * 4.0, length / 0.08))


## The sports hall's stand behind the teams' benches: pull-out aluminium bleachers (assets/shared/stands/bleacher_hall,
## 8 m sections of three rows, 0.8 m deep, rising 0.45 m, on a dark steel frame), four across and two deep, the back
## sections raised on a dark steel deck so the six rows rise evenly. Each section a MultiMesh instance (one draw call
## for all eight; the _low model on Low and Medium). Returns where people sit: on each row's plank, feet on the one below.
func _bleachers() -> Array:
	var spots: Array = []
	var front := -Rules.HALF_W - 3.2          # the first row's front edge, behind the benches' plexiglass
	var at: Array[Transform3D] = []
	for tier in 2:
		var z := front - BLEACHER_D * 0.5 - tier * BLEACHER_D
		var lift := tier * BLEACHER_LIFT
		for k in 4:
			var x := -12.0 + k * 8.0
			at.append(Transform3D(Basis.IDENTITY, Vector3(x, lift, z)))
			for row: Array in BLEACHER_ROWS:
				var sx := x - 3.75
				while sx < x + 3.8:
					spots.append(Vector3(sx, lift + float(row[0]) - 0.42, z + float(row[1])))
					sx += SEAT
		if tier > 0:
			# The deck the back sections stand on: its front and sides dark steel.
			var zf := z + BLEACHER_D * 0.5
			var zb := z - BLEACHER_D * 0.5
			_lit.face(Vector3(-16, 0, zf), Vector3(16, 0, zf), 0.0, lift, Vector3(0, 0, 0), Color("2b2f35", 0.5))
			_lit.flat(-16, zb, 16, zf, lift, Color("3a3f47", 0.6))
			for e: int in [-1, 1]:
				_lit.face(Vector3(16 * e, 0, zf), Vector3(16 * e, 0, zb), 0.0, lift, Vector3(32 * e, 0, z), Color("2b2f35", 0.5))
	_place("stands/bleacher_hall", at, true)
	return spots


## Rows of seats along a long side (side -1: the far side, behind the benches; 1: the near side), rising; aisles
## between sections. Each row: the step's front, its tread, the seats' backs at its back (people in front of them).
## Returns where people sit.
func _stands(side: int, rows: int, seat: Color, fascia: bool) -> Array:
	var spots: Array = []
	# The near side's stand stands back behind the camera's gantry, out of the broadcast picture (the penalty benches
	# and the secretariat at its foot); the far side's begins behind the teams' benches.
	var z0 := (Rules.HALF_W + (3.6 if side < 0 else 6.2)) * side
	var y_front := 1.0 if fascia else 0.0
	var half := 15.0
	var aisles := [-7.5, 0.0, 7.5] if fascia else [0.0]
	var concrete := Color("8a8d92") if fascia else Color("c8ad7f")
	var rink := Vector3(0, 0, 0)
	if fascia:
		# The stand's front: a wall with an LED ribbon round it, a glass rail on top.
		var zf := z0 - side * ROW_DEPTH * 0.5
		var l := Vector3(-half, 0, zf)
		var r := Vector3(half, 0, zf)
		_glow.face(l, r, 0.25, y_front - 0.05, rink, Color.WHITE, s("led"), 0.0, 30.0 / 8.0)
		_lit.face(l, r, 0.0, 0.25, rink, Color("1b1e23"))
		_see.face(l, r, y_front - 0.05, y_front + 0.85, rink, Color(0.8, 0.88, 0.95, 0.12))
	for r in rows:
		var zc := z0 + side * r * ROW_DEPTH
		var zf := zc - side * ROW_DEPTH * 0.5
		var zb := zc + side * ROW_DEPTH * 0.5
		var y := y_front + 0.45 + r * ROW_RISE
		var y_prev := y - ROW_RISE if r > 0 else 0.0
		# Riser and tread, the whole length: the arena's lower tier a steel bleacher (aluminium treads, dark risers),
		# concrete above it.
		if fascia and r < METAL_ROWS:
			_lit.face(Vector3(-half, 0, zf), Vector3(half, 0, zf), y_prev, y, rink, Color("2b2f35", 0.5))
			_lit.flat(-half, zf, half, zb, y, Color(0.8, 0.82, 0.85, 0.45), s("tread"), 30.0 / 8.0, 1.0)
		else:
			_lit.face(Vector3(-half, 0, zf), Vector3(half, 0, zf), y_prev, y, rink, concrete.darkened(0.25), s("step"), 0.0, 4.0, 0.5)
			_lit.flat(-half, zf, half, zb, y, concrete, s("step"), 4.0, 0.5)
		# Seats in sections between the aisles.
		var edges := [-half]
		for a in aisles:
			edges.append(a - 0.5)
			edges.append(a + 0.5)
		edges.append(half)
		for k in range(0, edges.size(), 2):
			var xa: float = edges[k]
			var xb: float = edges[k + 1]
			var zs := zb - side * 0.12
			_lit.face(Vector3(xa, 0, zs), Vector3(xb, 0, zs), y, y + 0.45, rink, Color(seat, 0.55), s("seats"),
				(xa + 40.0) / 4.0 if side < 0 else (40.0 - xb) / 4.0, (xb - xa) / 4.0)
			var x := xa + SEAT * 0.5
			while x < xb - SEAT * 0.25:
				spots.append(Vector3(x, y, zc + side * 0.12))
				x += SEAT
		# The row's end, seen at the corners.
		for e: int in [-1, 1]:
			_lit.face(Vector3(half * e, 0, zf), Vector3(half * e, 0, zb), 0.0, y, Vector3(half * e * 2.0, 0, zc), concrete.darkened(0.35))
	return spots


func _end_stands(end: int, rows: int, seat: Color) -> Array:
	var spots: Array = []
	var x0 := (Rules.HALF_L + 3.0) * end
	var half := 11.0
	var concrete := Color("8a8d92")
	var rink := Vector3.ZERO
	var xf0 := x0 - end * ROW_DEPTH * 0.5
	_glow.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.25, 0.95, rink, Color.WHITE, s("led"), 0.3, 22.0 / 8.0)
	_lit.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.0, 0.25, rink, Color("1b1e23"))
	_see.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.95, 1.85, rink, Color(0.8, 0.88, 0.95, 0.12))
	for r in rows:
		var xc := x0 + end * r * ROW_DEPTH
		var xf := xc - end * ROW_DEPTH * 0.5
		var xb := xc + end * ROW_DEPTH * 0.5
		var y := 1.0 + 0.45 + r * ROW_RISE
		var y_prev := y - ROW_RISE if r > 0 else 0.0
		if r < METAL_ROWS:
			_lit.face(Vector3(xf, 0, -half), Vector3(xf, 0, half), y_prev, y, rink, Color("2b2f35", 0.5))
			_lit.flat(xf, -half, xb, half, y, Color(0.8, 0.82, 0.85, 0.45), s("tread"), 1.0, 22.0 / 8.0)
		else:
			_lit.face(Vector3(xf, 0, -half), Vector3(xf, 0, half), y_prev, y, rink, concrete.darkened(0.25), s("step"), 0.0, 3.0, 0.5)
			_lit.flat(xf, -half, xb, half, y, concrete, s("step"), 3.0, 0.5)
		var xs := xb - end * 0.12
		for sec: Array in [[-half, -0.5], [0.5, half]]:
			var za: float = sec[0]
			var zb: float = sec[1]
			_lit.face(Vector3(xs, 0, za), Vector3(xs, 0, zb), y, y + 0.45, rink, Color(seat, 0.55), s("seats"), 0.0, (zb - za) / 4.0)
			var z := za + SEAT * 0.5
			while z < zb - SEAT * 0.25:
				spots.append(Vector3(xc + end * 0.12, y, z))
				z += SEAT
		for e: int in [-1, 1]:
			_lit.face(Vector3(xf, 0, half * e), Vector3(xb, 0, half * e), 0.0, y, Vector3(xc, 0, half * e * 2.0), concrete.darkened(0.35))
	return spots


func _wall_bars(side: int, half_x: float, half_z: float) -> void:
	# A school's (or a hall's) wall bars along a long wall.
	var z := (half_z - 0.12) * side
	var count := 12 if venue == "school" else 8
	for i in count:
		var x := -float(count) * 1.2 + i * 2.4
		for k in 2:
			_lit.box(Vector3(x + k * 0.9, 1.4, z), Vector3(0.06, 2.8, 0.06), Color("b08a56", 0.5))
		for j in 9:
			_lit.box(Vector3(x + 0.45, 0.2 + j * 0.3, z), Vector3(0.9, 0.04, 0.04), Color("c49a62", 0.5))


## Roof trusses across the hall's far half, the lamps hung between them (only the far half: the broadcast and high
## cameras stand above the near half, where trusses would cross the picture).
func _trusses(half_x: float, half_z: float, y: float, n: int) -> void:
	for i in n:
		var x := -half_x + (i + 1) * 2.0 * half_x / (n + 1)
		_cut.strip_quad(Vector3(x, y, -half_z), Vector3(x, y, -6.0), Vector3(x, y - 1.6, -6.0), Vector3(x, y - 1.6, -half_z),
			Vector3.RIGHT, Color("c4c9cf") if venue != "arena" else Color("9aa0a8"), s("truss"), Rect2(0, 0, (half_z - 6.0) / 8.0, 1))


func _ceiling_lights() -> void:
	var h: float = _lamps.h
	var st: Vector2 = _lamps.step
	var n: Vector2i = _lamps.n
	var sz: Vector2 = _lamps.size
	var kind := String(_lamps.kind)
	var at: Array[Transform3D] = []
	for i in n.x:
		for k in n.y:
			var x := (i - (n.x - 1) * 0.5) * st.x
			var z := (k - (n.y - 1) * 0.5) * st.y
			match kind:
				"tube":
					# A batten's white housing on the rail, its tubes under it (glowing panels on Low).
					_lit.box(Vector3(x, h + 0.035, z), Vector3(sz.x + 0.1, 0.07, sz.y + 0.08), Color(0.95, 0.95, 0.95, 0.5))
					# Its lit diffuser, the tubes (the model, Medium and High) in front of it.
					_glow.flat(x - sz.x * 0.5, z - sz.y * 0.5, x + sz.x * 0.5, z + sz.y * 0.5, h - (0.01 if _low else 0.002), Color(1, 0.99, 0.95), Vector2(-1, 0), 1, 1, true)
					if not _low:
						at.append(Transform3D(Basis.IDENTITY, Vector3(x, h, z)))
					# Its drop rods up to the ceiling.
					for dx: float in [-0.35, 0.35]:
						_lit.box(Vector3(x + dx, (h + 0.07 + _ceiling_h()) * 0.5, z), Vector3(0.015, _ceiling_h() - h - 0.07, 0.015), Color("8d939b"))
				"pendant":
					at.append(Transform3D(Basis.IDENTITY, Vector3(x, _ceiling_h(), z)))
				_:
					_glow.flat(x - sz.x * 0.5, z - sz.y * 0.5, x + sz.x * 0.5, z + sz.y * 0.5, h, Color(1, 0.99, 0.95), Vector2(-1, 0), 1, 1, true)
	match kind:
		"tube":
			# Each row's lighting rail, the battens under it.
			for k in n.y:
				var z := (k - (n.y - 1) * 0.5) * st.y
				var xe := (n.x - 1) * 0.5 * st.x + sz.x * 0.5 + 0.3
				_lit.box(Vector3(0, h + 0.11, z), Vector3(xe * 2.0, 0.08, 0.1), Color(0.9, 0.9, 0.9, 0.5))
			_place("hall/fluorescent_light", at, true)
		"pendant":
			_place("hall/hanging_lamp", at, true)


func _ceiling_h() -> float:
	return {"arena": 16.0, "hall": 10.0}.get(venue, 8.0)


## The halls' smaller things: a wall clock over each door, a fire alarm call point beside it and a wet floor sign by
## the first (the sports hall's, on Medium and High), and the low gym benches along the far wall's free ends.
func _fittings() -> void:
	var clocks: Array[Transform3D] = []
	var alarms: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	for d in _doors:
		var p: Vector3 = d[0]
		var n: Vector3 = d[1]
		var yaw := atan2(n.x, n.z)
		var along := Vector3(-n.z, 0, n.x)
		clocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.4), p + n * 0.005 + Vector3(0, 3.05, 0)))
		alarms.append(Transform3D(Basis(Vector3.UP, yaw), p + n * 0.028 + along * 1.45 + Vector3(0, 1.4, 0)))
		if signs.is_empty():
			signs.append(Transform3D(Basis(Vector3.UP, yaw + 0.5), p + n * 0.9 - along * 1.6))
	_place("hall/wall_clock", clocks)
	if venue == "hall" and not _low:
		_place("hall/fire_alarm_nordic", alarms)
		_place("hall/wet_floor_sign", signs)
	# Pale birch gymnastics benches (3 m, 33 cm high), long side to the wall.
	var benches: Array[Transform3D] = []
	var xs: Array = [17.8, 21.0, 24.2] if venue == "hall" else [17.2, 20.9]
	for side: int in [-1, 1]:
		for x: float in xs:
			if venue == "school" and side < 0 and x > 19.0:
				continue   # the ropes' corner
			benches.append(Transform3D(Basis.IDENTITY, Vector3(x * side, 0, -_half.y + 0.2)))
	_place("seating/gym_bench_pale", benches, true)


## Places copies of a model from assets/shared, one MultiMeshInstance3D for each mesh in it (so a draw call a surface
## however many are placed). Low takes the model's _low file (and so does Medium where medium_low), with its
## materials lit per vertex and no normal map. A see-through part (a clock's glass) is left out.
func _place(name: String, at: Array[Transform3D], medium_low := false) -> void:
	if at.is_empty():
		return
	var g := int(Game.settings.graphics)
	var low_file := g == Game.GFX_LOW or (medium_low and g == Game.GFX_MEDIUM)
	var path := SHARED + name + ("_low" if low_file else "") + ".glb"
	if not ResourceLoader.exists(path):
		path = SHARED + name + ("" if low_file else "_low") + ".glb"   # a model with one file for every level
	var key := "%s%d" % [path, int(_low)]
	if not _meshes.has(key):
		_meshes[key] = _load_meshes(path, _low)
	for e: Array in _meshes[key]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e[0]
		mm.instance_count = at.size()
		for i in at.size():
			mm.set_instance_transform(i, at[i] * (e[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_models += at.size()


static func _load_meshes(path: String, low: bool) -> Array:
	var out := []
	var scn: PackedScene = load(path)
	var root := scn.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh
		var opaque := true
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				opaque = false
		if not opaque:
			continue
		# The lamps' tubes and bulbs: brighter than the scans' own emission, as a lamp that is on.
		var lamp := false
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
				lamp = true
		if low or lamp:
			mesh = mesh.duplicate()
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var lm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					if low:
						lm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
						lm.normal_enabled = false
					if lm.emission_enabled:
						lm.emission_energy_multiplier *= 3.0
					mesh.surface_set_material(i, lm)
		# Where the mesh sits in the model.
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		out.append([mesh, xf])
	root.free()
	return out


func _scoreboard_cube() -> void:
	_lit.box(Vector3(0, 11.5, 0), Vector3(4.0, 2.2, 4.0), Color("15181d"))
	for k in 4:
		var a := k * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		var c := out * 2.02
		var right := Vector3(cos(a), 0, -sin(a)) * 1.8
		_glow.face(c - right, c + right, 10.7, 12.3, c + out, Color.WHITE, s("score"), 0.0, 0.5)
