class_name Scenery
extends RefCounted
## The venues' real-world pieces (assets/venue/, from the shared assets: photo-scanned Poly Haven models and
## surfaces, and the owner's models): trees, seats, buildings, lamps, skies, ground and water. Pieces are placed
## many at a time, each kind drawn as one MultiMesh, so forty chairs cost a draw call. On Low the cut-down "_low"
## models are used; trees are always photographed cut-outs ("_card": two crossed planes), which look far more real
## from the broadcast seats than any mesh a phone can afford.

const DIR := "res://assets/venue/"
## The sun in each sky (the brightest point of its panorama): across the image (0-1, from -Z toward +X) and its height
## above the horizon (degrees); the venue's sunlight comes from there. tools: the skies' 2K images, measured once.
const SUNS := {
	"qwantani_noon_puresky": [0.598, 49.0],
	"qwantani_sunset_puresky": [0.598, 16.0],   # (the sun is at 7 degrees: lit from a little higher, or every shadow crosses the court)
	"kloppenheim_02_puresky": [0.598, 18.0],
	"kloppenheim_07_puresky": [0.621, 41.0],
}
## Models whose cut-down version is no smaller to speak of and comes out broken: the full one on Low too.
const FULL_ON_LOW := ["stands/bleacher_metal"]
## The photographs' mean brightness (linear), so a surface painted over keeps its grain at the paint's own shade.
const MEAN := {"clean_asphalt": 0.06, "asphalt_02": 0.11, "concrete_floor": 0.28, "coast_sand_01": 0.18,
	"damp_beach_sand": 0.12, "white_maple_veneer": 0.68, "concrete_block_wall": 0.05, "corrugated_iron": 0.44,
	"grass_ground": 0.12}

static var _parts := {}       # model path -> [[Mesh, Transform3D], ...]
static var _tintable := {}    # Mesh -> its copy whose materials take each instance's colour
static var _surface_shaders := {}  # on Low? -> Shader (Low filters the ground plainly, the others anisotropically)
static var _water_shader: Shader

var _root: Node3D
var _placed := {}             # model name -> [Transform3D, ...]
var _shadows := {}            # model name -> casts shadows
var _tints := {}              # model name -> [Color, ...], one an instance
var _made := {}               # key -> [Mesh, [Transform3D, ...], casts shadows]: meshes made in code
static var _fence_shader: Shader


func _init(root: Node3D) -> void:
	_root = root


static func low() -> bool:
	return int(Game.settings.graphics) == Game.GFX_LOW


## Puts a model (a name under assets/venue/, without ".glb") at a place: p on the floor, turned yaw (radians),
## scaled s, its colour multiplied by tint (a row of houses a little different each).
func add(name: String, p: Vector3, yaw := 0.0, s := 1.0, shadows := true, tint := Color.WHITE) -> void:
	if not _placed.has(name):
		_placed[name] = []
		_tints[name] = []
	(_placed[name] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p))
	(_tints[name] as Array).append(tint)
	_shadows[name] = shadows and not name.ends_with("_card")


## A tree's cut-out, turned so both its planes face the broadcast camera, a little different each time.
func tree(name: String, p: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var full: float = {"coconut_palm": 15.3, "rain_tree": 15.7, "island_tree_a": 9.2, "island_tree_b": 8.8}.get(name, 10.0)
	add("trees/%s_card" % name, p, PI * 0.25 + rng.randf_range(-0.3, 0.3), height / full)


## Puts a mesh made in code (a stall's roof) at a place; every one of a key is drawn together.
func add_mesh(key: String, mesh: Mesh, xf: Transform3D, shadows := true) -> void:
	if not _made.has(key):
		_made[key] = [mesh, [], shadows]
	(_made[key][1] as Array).append(xf)


## Makes everything added so far: one MultiMesh for each part of each model, and for each mesh made in code.
func commit() -> void:
	for name in _placed:
		var xf: Array = _placed[name]
		var tints: Array = _tints[name]
		var tinted := tints.any(func(c): return c != Color.WHITE)
		for part in parts(name):
			_multi(_tinted(part[0]) if tinted else part[0], xf.map(func(t): return (t as Transform3D) * (part[1] as Transform3D)),
				_shadows[name], tints if tinted else [])
	for key in _made:
		_multi(_made[key][0], _made[key][1], _made[key][2])
	_placed.clear()
	_tints.clear()
	_made.clear()


func _multi(mesh: Mesh, xf: Array, shadows: bool, colors := []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() and shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mmi)


## A model's meshes, each with its place in the model (the Low version on Low, when there is one), read once.
static func parts(name: String) -> Array:
	var path := DIR + name + ".glb"
	if low() and not name.ends_with("_card") and not name in FULL_ON_LOW and ResourceLoader.exists(DIR + name + "_low.glb"):
		path = DIR + name + "_low.glb"
	if _parts.has(path):
		return _parts[path]
	var out := []
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != scene:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		out.append([_lit_glass(m.mesh), xf])
	scene.free()
	_parts[path] = out
	return out


## The mesh with its materials multiplied by each instance's colour (MultiMesh colours reach the material as COLOR).
static func _tinted(mesh: Mesh) -> Mesh:
	if not _tintable.has(mesh):
		var copy: Mesh = mesh.duplicate()
		for i in copy.get_surface_count():
			var mat := copy.surface_get_material(i)
			if mat is BaseMaterial3D:
				var m: BaseMaterial3D = mat.duplicate()
				m.vertex_color_use_as_albedo = true
				copy.surface_set_material(i, m)
		_tintable[mesh] = copy
	return _tintable[mesh]


## Lamp and lantern glass glows (the models' emission is off).
static func _lit_glass(mesh: Mesh) -> Mesh:
	var glow := false
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat and String(mat.resource_name).contains("glass") and mat is BaseMaterial3D:
			glow = true
	if not glow:
		return mesh
	var m: Mesh = mesh.duplicate()
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		if mat and String(mat.resource_name).contains("glass") and mat is BaseMaterial3D:
			var g: BaseMaterial3D = mat.duplicate()
			g.emission_enabled = true
			g.emission = Color("ffe2a8")
			g.emission_energy_multiplier = 2.2
			m.surface_set_material(i, g)
	return m


# ---------------------------------------------------------------- skies

## A sky from its panorama: the background on every level, and on Medium and High the light around the place too.
static func sky(env: Environment, name: String, energy := 1.0) -> void:
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load(DIR + "skies/%s_sky_2k.jpg" % name)
	pm.energy_multiplier = energy
	var s := Sky.new()
	s.sky_material = pm
	s.radiance_size = Sky.RADIANCE_SIZE_32 if low() else Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = s
	# No reflections of the sky: its bright horizon, caught by the ground at a glancing angle, whitens the far ground.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if not low():
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.75


## Points the sunlight from where the sky's sun is.
static func aim_sun(sun: DirectionalLight3D, sky_name: String) -> void:
	var s: Array = SUNS[sky_name]
	var a := TAU * float(s[0])
	var e := deg_to_rad(float(s[1]))
	var toward := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
	sun.basis = Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.BACK)


# ---------------------------------------------------------------- surfaces

## A photographed surface (assets/venue/surfaces/), laid in world space: tile metres a repeat; tint multiplies it,
## or with paint 1 paints it in tint keeping the grain (a court painted on concrete). Its relief (normal map) on
## Medium and High.
static func surface(name: String, tint := Color.WHITE, paint := 0.0, tile := 2.5, rough := 0.85) -> ShaderMaterial:
	if not _surface_shaders.has(low()):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, FILTER, repeat_enable;
uniform sampler2D normal_tex : hint_normal, FILTER, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float paint = 0.0;
uniform float mean = 0.4;
uniform float tile = 2.5;
uniform float rough = 0.85;
uniform bool relief = true;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv = (n.y > 0.7 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy)) / tile;
	vec3 c = texture(albedo_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 painted = tint * clamp(1.0 + 0.35 * (l / mean - 1.0), 0.55, 1.35);
	ALBEDO = mix(c * tint, painted, paint);
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	if (relief) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = 0.8;
	}
}
""".replace("FILTER", "filter_linear_mipmap" if low() else "filter_linear_mipmap_anisotropic")
		_surface_shaders[low()] = sh
	var m := ShaderMaterial.new()
	m.shader = _surface_shaders[low()]
	m.set_shader_parameter("albedo_tex", load(DIR + "surfaces/%s/%s_albedo_1k.jpg" % [name, name]))
	m.set_shader_parameter("normal_tex", load(DIR + "surfaces/%s/%s_normal_1k.jpg" % [name, name]))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("paint", paint)
	m.set_shader_parameter("mean", float(MEAN.get(name, 0.45)))
	m.set_shader_parameter("tile", tile)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("relief", not low())
	return m


## A flat rectangle of a surface at height y, from (x0, z0) to (x1, z1).
static func plane(root: Node3D, mat: Material, x0: float, z0: float, x1: float, z1: float, y := 0.0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## A box of a surface (a wall, a roof): centre c, size s, turned yaw.
static func box(root: Node3D, mat: Material, c: Vector3, s: Vector3, yaw := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = s
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = c
	mi.rotation.y = yaw
	root.add_child(mi)
	return mi


# ---------------------------------------------------------------- water

## The sea: two copies of a wave normal map drifting across each other, deep blue far out and lighter near the shore,
## the sky's colour in it at a glancing angle and the sun's glints (no real-time reflections: a phone's budget).
static func water(root: Node3D, x0: float, z0: float, x1: float, z1: float, shallow: Color, deep: Color, sky_col: Color) -> void:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D waves : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color;
uniform vec3 deep : source_color;
uniform vec3 sky_col : source_color;
uniform float shore = 22.0;
uniform bool relief = true;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz * 0.045;
	if (relief) {
		vec3 a = texture(waves, uv + TIME * vec2(0.011, 0.017)).rgb;
		vec3 b = texture(waves, uv * 1.9 + TIME * vec2(-0.015, 0.009)).rgb;
		NORMAL_MAP = normalize((a + b) - 1.0) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 0.6;
	}
	float far = smoothstep(shore, shore + 45.0, wpos.z);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow, deep, far) * (1.0 - fres * 0.4);
	EMISSION = sky_col * fres * 0.5;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _water_shader
	m.set_shader_parameter("waves", load(DIR + "water/water_normal_512.png"))
	m.set_shader_parameter("shallow", shallow)
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("sky_col", sky_col)
	m.set_shader_parameter("shore", z0)
	m.set_shader_parameter("relief", not low())
	plane(root, m, x0, z0, x1, z1, -0.02)


# ---------------------------------------------------------------- fences

## A chain-link fence h metres high along the points on the floor: the wire's diamonds cut by a shader from one
## surface, fading to a see-through grey where the mesh is finer than a pixel (it would shimmer otherwise).
static func fence(root: Node3D, pts: Array, h: float) -> void:
	if _fence_shader == null:
		_fence_shader = Shader.new()
		_fence_shader.code = """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley;
void fragment() {
	vec2 g = vec2(UV.x + UV.y, UV.x - UV.y) / 0.065;
	vec2 f = abs(fract(g) - 0.5);
	float wire = 0.5 - max(f.x, f.y);
	float px = max(fwidth(g.x), fwidth(g.y));
	float mask = 1.0 - smoothstep(0.06, 0.06 + px, wire);
	ALPHA = mix(mask, 0.3, clamp(px * 3.0 - 0.4, 0.0, 1.0)) * 0.95;
	ALBEDO = vec3(0.6, 0.62, 0.64);
	METALLIC = 0.6;
	ROUGHNESS = 0.45;
}
"""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := a.distance_to(b)
		var n := (b - a).cross(Vector3.UP).normalized()
		var quad := [[a, Vector2(along, 0)], [b, Vector2(along + d, 0)], [b + Vector3(0, h, 0), Vector2(along + d, h)],
			[a + Vector3(0, h, 0), Vector2(along, h)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
		along += d
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = _fence_shader
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Loads the pieces a venue uses before the match starts (the loading screen), so nothing stalls on the first frame.
static func warm(names: Array) -> void:
	for n in names:
		parts(n)
