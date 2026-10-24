class_name Scenery
## The grounds' photographic scenery, from the lead session's shared assets (assets/scenery; tools/scenery): the
## skies, the ground's surfaces and the sea, and the models round a ground (trees, chairs, stools, the scorers' table,
## buildings), each kind drawn in one go however many there are (a MultiMesh), the cut-down model or a cut-out on Low.
## Arena lays them out, ground by ground.

const DIR := "res://assets/scenery/"

## A photographed sky: a 2K panorama for the background on every level, and on Medium and High the same sky in HDR
## for the light it gives the ground (ambient light, reflections). The panorama is turned so its sun sits where the
## ground's own sun is; below the horizon, the panorama's horizon goes on as haze for the background, and the ground's
## colour lights things from below.
const SKY_SHADER := """
shader_type sky;
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform sampler2D light : filter_linear, repeat_enable;
uniform bool use_light = false;   // the HDR for the light (Medium, High); the panorama's own on Low
uniform float turn = 0.0;         // of a full turn
uniform float energy = 1.0;       // the background
uniform float light_energy = 1.0; // the light from the panorama (Low)
uniform float hdr_energy = 1.0;   // ... from the HDR
uniform float light_max = 6.0;    // the HDR's sun held to this: the sun's own light is the ground's DirectionalLight3D
uniform float saturation = 1.0;   // of the sky's colour
uniform vec3 ground : source_color = vec3(0.2);
vec3 sat(vec3 c) {
	return mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
}
void sky() {
	vec2 uv = vec2(fract(SKY_COORDS.x - turn), min(SKY_COORDS.y, 0.499));
	if (AT_CUBEMAP_PASS) {
		vec3 c = sat(use_light ? min(texture(light, uv).rgb, vec3(light_max)) * hdr_energy : texture(panorama, uv).rgb * light_energy);
		// Below the horizon the ground, as bright as the sky makes it.
		COLOR = mix(c, ground * dot(c, vec3(0.2126, 0.7152, 0.0722)), 1.0 - smoothstep(-0.1, 0.0, EYEDIR.y));
	} else {
		COLOR = sat(texture(panorama, uv).rgb) * energy;
	}
}
"""
static var _sky_shader: Shader = null


## The sky called name (assets/scenery/skies/<name>_sky_2k.jpg and _light_1k.hdr), turned by turn (of a full turn):
## energy the background's brightness, light_energy and hdr_energy its light's from the panorama and from the HDR,
## ground the colour of the light from below the horizon, saturation its colour's strength.
static func sky(name: String, turn: float, energy: float, light_energy: float, hdr_energy: float, ground: Color,
		saturation := 1.0) -> Sky:
	if _sky_shader == null:
		_sky_shader = Shader.new()
		_sky_shader.code = SKY_SHADER
	var m := ShaderMaterial.new()
	m.shader = _sky_shader
	m.set_meta("sky", name)
	m.set_shader_parameter("panorama", load(DIR + "skies/%s_sky_2k.jpg" % name))
	m.set_shader_parameter("turn", turn)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("light_energy", light_energy)
	m.set_shader_parameter("hdr_energy", hdr_energy)
	m.set_shader_parameter("ground", ground)
	m.set_shader_parameter("saturation", saturation)
	var s := Sky.new()
	s.sky_material = m
	sky_detail(s)
	return s


## The sky's light from its HDR on Medium and High, from the panorama on Low (where the HDR is not even loaded).
static func sky_detail(s: Sky) -> void:
	var m := s.sky_material as ShaderMaterial
	if m == null or not m.has_meta("sky"):
		return
	var hdr := int(Game.settings.graphics) >= Game.GFX_MEDIUM
	if hdr and m.get_shader_parameter("light") == null:
		m.set_shader_parameter("light", load(DIR + "skies/%s_light_1k.hdr" % String(m.get_meta("sky"))))
	m.set_shader_parameter("use_light", hdr)


## A ground: a photographed surface laid in metres over the world (so it runs on across every plane that shows it),
## a second one showing through in patches or toward a line (the earth round a court, the wet sand by the sea),
## brightness varied over tens of metres so the tiles do not show, and on Medium and High the surfaces' normal maps
## (scenery_detail, a global shader parameter: Arena.graphics_changed). The monsoon's is wet, with puddles.
const GROUND_SHADER := """
shader_type spatial;
global uniform float scenery_detail;
uniform sampler2D albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;   // r: patches, g: variation, b: puddles
uniform vec3 tint_a = vec3(1.0);   // linear: the scans are as dark as the real ground, the game's light was set for lighter
uniform vec3 tint_b = vec3(1.0);
uniform float period_a = 2.5;   // metres a tile covers
uniform float period_b = 2.5;
uniform float rough_a = 0.9;
uniform float rough_b = 0.9;
uniform float spec = 0.5;
uniform bool two = false;        // the second surface shows at all
uniform float b_cover = 0.0;     // of the ground, in patches
uniform int band_mode = 0;       // and toward a line (1), out from the middle (2) or outside a box (3):
uniform vec4 b_band = vec4(0.0); // xy the line's way or the box's half size, z where B starts, w where it is all B
uniform float band_noise = 4.0;  // metres the band's edge wanders
uniform float patch_size = 40.0; // metres a patch spans
uniform float vary = 0.12;
uniform float normal_depth = 1.0;
uniform float wet = 0.0;
uniform float puddles = 0.0;     // of the ground under water
uniform sampler2D water_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	vec3 n3 = texture(patches, p / patch_size).rgb;
	vec3 col = texture(albedo_a, p / period_a).rgb * tint_a;
	float b = 0.0;
	if (two) {
		b = smoothstep(1.0 - b_cover - 0.08, 1.0 - b_cover + 0.08, n3.r);
		if (band_mode > 0) {
			float d = band_mode == 1 ? dot(p, b_band.xy) : (band_mode == 2 ? length(p) : max(abs(p.x) - b_band.x, abs(p.y) - b_band.y));
			b = max(b, smoothstep(b_band.z, b_band.w, d + (n3.r - 0.5) * band_noise));
		}
		col = mix(col, texture(albedo_b, p / period_b).rgb * tint_b, b);
	}
	col *= 1.0 + (n3.g - 0.5) * 2.0 * vary;
	float rough = mix(rough_a, rough_b, b);
	vec3 nm = vec3(0.5, 0.5, 1.0);
	if (scenery_detail > 0.5) {
		nm = texture(normal_a, p / period_a).rgb;
		if (two) {
			nm = mix(nm, texture(normal_b, p / period_b).rgb, b);
		}
	}
	if (wet > 0.0) {
		float pd = smoothstep(1.0 - puddles - 0.025, 1.0 - puddles + 0.025, n3.b);
		col *= mix(1.0 - 0.4 * wet, 0.3, pd);
		rough = mix(mix(rough, 0.3, wet), 0.02, pd);
		vec3 still = vec3(0.5, 0.5, 1.0);
		if (scenery_detail > 0.5) {
			still = texture(water_normal, p * 0.4 + vec2(TIME * 0.02, TIME * 0.035)).rgb;
		}
		nm = mix(nm, still, pd);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
}
"""
static var _ground_shader: Shader = null
static var _textures := {}


static func texture(path: String) -> Texture2D:
	# Medium and High take a surface's 2K texture where it has one (the courts' own); Low never loads it.
	var hi := path.replace("_1k.", "_2k.")
	if hi != path and Game.detail_textures() and ResourceLoader.exists(DIR + hi):
		path = hi
	if not _textures.has(path):
		_textures[path] = load(DIR + path) if ResourceLoader.exists(DIR + path) else null
	return _textures[path]


## A ground of surface a (a folder in assets/scenery/surfaces), a metres to a tile, tinted; params sets the rest
## (b, period_b, tint_b, b_cover, band_mode, b_band, rough_a, wet, puddles...: GROUND_SHADER's own names).
static func ground(a: String, period: float, tint := Color.WHITE, params := {}) -> ShaderMaterial:
	if _ground_shader == null:
		_ground_shader = Shader.new()
		_ground_shader.code = GROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = _ground_shader
	m.set_shader_parameter("albedo_a", texture("surfaces/%s/%s_albedo_1k.jpg" % [a, a]))
	m.set_shader_parameter("normal_a", texture("surfaces/%s/%s_normal_1k.jpg" % [a, a]))
	m.set_shader_parameter("period_a", period)
	m.set_shader_parameter("tint_a", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("patches", texture("surfaces/patches.png"))
	for k in params:
		if k == "b":
			var b := String(params.b)
			m.set_shader_parameter("two", true)
			m.set_shader_parameter("albedo_b", texture("surfaces/%s/%s_albedo_1k.jpg" % [b, b]))
			m.set_shader_parameter("normal_b", texture("surfaces/%s/%s_normal_1k.jpg" % [b, b]))
		elif params[k] is Color:
			# The tints are plain vec3s (linear multipliers, not colours): a Color does not take, and is not saved.
			var c: Color = params[k]
			m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
		else:
			m.set_shader_parameter(k, params[k])
	if float(params.get("wet", 0.0)) > 0.0:
		m.set_shader_parameter("water_normal", texture("water/water_normal_512.png"))
	return m


## Cut-outs (trees, grass): a picture of the plant on two crossed planes, its outline cut from the alpha. The cut
## keeps its coverage in the smaller mipmaps (else a far tree thins away to its trunk), the leaves let some light
## through, and the whole is lit partly from above, as a tree's crown is rather than as the flat card it is. Sways a
## little in the wind (sway, metres at its top).
const CARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float cut = 0.4;
uniform float translucency = 0.3;
uniform float sway = 0.0;
uniform float height = 10.0;
uniform float saturation = 1.0;   // of the picture's colour (some were rendered vivid)
uniform float brightness = 1.0;
varying vec3 tint;
void vertex() {
	tint = COLOR.rgb;
	float t = clamp(VERTEX.y / height, 0.0, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 0.9 + o.x * 0.37 + o.z * 0.21) * sway * t * t;
	VERTEX.z += sin(TIME * 0.7 + o.z * 0.29) * sway * 0.5 * t * t;
}
void fragment() {
	vec4 c = texture(albedo, UV);
	vec2 px = UV * vec2(textureSize(albedo, 0));
	float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
	c.rgb = mix(vec3(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))), c.rgb, saturation) * brightness;
	ALBEDO = c.rgb * tint;
	ALPHA = c.a * (1.0 + 0.3 * lod);
	ALPHA_SCISSOR_THRESHOLD = cut;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = c.rgb * tint * translucency;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(0.0, 0.8, 0.0, 0.0)).xyz);
}
"""
static var _card_shader: Shader = null
static var _materials := {}
## How each cut-out sits in the game's light: [saturation, brightness, translucency]. The rain tree's picture was
## rendered vivid, a lime green no real one has; the island trees' are photographs, as they are.
const CARD_LOOK := {"trees/rain_tree_card": [0.6, 0.82, 0.3], "trees/coconut_palm_card": [0.8, 0.85, 0.35],
	"foliage/dry_grass_tall_card": [0.85, 0.9, 0.4]}


## A model's mesh (path in assets/scenery, without .res), the cut-down one on Low where it has one.
static func mesh(path: String, low: bool) -> Mesh:
	if low and ResourceLoader.exists(DIR + path + "_low.res"):
		path += "_low"
	return load(DIR + path + ".res")


## The material for the model at path (as mesh() picked it): its textures, rough and not metallic, both sides drawn
## as the models are made, coloured by each copy's colour (the MultiMesh's); a cut-out's own shader for a card.
static func material(path: String, sway := 0.0) -> Material:
	var key := "%s:%s" % [path, sway]
	if _materials.has(key):
		return _materials[key]
	var m: Material
	if path.ends_with("_card"):
		if _card_shader == null:
			_card_shader = Shader.new()
			_card_shader.code = CARD_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = _card_shader
		sm.set_shader_parameter("albedo", load(DIR + path + "_albedo.png"))
		sm.set_shader_parameter("sway", sway)
		sm.set_shader_parameter("height", (load(DIR + path + ".res") as Mesh).get_aabb().end.y)
		var look: Array = CARD_LOOK.get(path, [1.0, 1.0, 0.3])
		sm.set_shader_parameter("saturation", look[0])
		sm.set_shader_parameter("brightness", look[1])
		sm.set_shader_parameter("translucency", look[2])
		m = sm
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load(DIR + path + "_albedo.jpg")
		if ResourceLoader.exists(DIR + path + "_normal.jpg"):
			sm.normal_enabled = true
			sm.normal_texture = load(DIR + path + "_normal.jpg")
		sm.roughness = 0.8
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.vertex_color_use_as_albedo = true
		m = sm
	_materials[key] = m
	return m


## Copies of one model, drawn in one go: at each of xforms, coloured by colors (one each, or all white). path is the
## model's (as mesh() takes it); low takes the cut-down mesh. Casts shadows where shadows is set (the sun casts none
## on Low anyway).
static func scatter(parent: Node3D, path: String, xforms: Array, low: bool, colors := [], shadows := true,
		sway := 0.0) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var me := mesh(path, low)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = me
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = path.get_file().to_pascal_case()
	mmi.multimesh = mm
	mmi.material_override = material(me.resource_path.get_basename().trim_prefix(DIR), sway)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## A copy of a model standing at pos, turned by yaw (radians about the vertical), scaled by s.
static func at(pos: Vector3, yaw: float, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), pos)


## Soft dark patches on the ground under things standing on it (chairs, stools, tables), all in one go: their
## contact shadow, on every level. Each spot is [centre, radius x, radius z, turn].
static func blobs(parent: Node3D, spots: Array, strength := 0.45) -> MeshInstance3D:
	if spots.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in spots:
		var c: Vector3 = s[0]
		var b := Basis(Vector3.UP, float(s[3]))
		var ax: Vector3 = b.x * float(s[1])
		var az: Vector3 = b.z * float(s[2])
		var y := Vector3(0, c.y + 0.012, 0)
		var corners := [c - ax - az, c + ax - az, c + ax + az, c - ax + az]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(Vector3(corners[k].x, 0, corners[k].z) + y)
	var mi := MeshInstance3D.new()
	mi.name = "ContactShadows"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, strength)
	m.albedo_texture = _blob_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static var _blob: GradientTexture2D = null


static func _blob_texture() -> GradientTexture2D:
	if _blob == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.8))
		_blob = GradientTexture2D.new()
		_blob.gradient = g
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	return _blob


## The sea: a gentle swell, ripples from the water's normal map in two layers drifting different ways, deep water
## darker and bluer than the shallows, the sky in it (the environment's reflections, strongest at a glancing look),
## and surf where it runs up the beach (shore: the line along z where the sea meets the sand).
const SEA_SHADER := """
shader_type spatial;
global uniform float scenery_detail;
uniform sampler2D waves : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.02, 0.12, 0.2);
uniform vec3 shallow : source_color = vec3(0.1, 0.32, 0.36);
uniform vec3 foam : source_color = vec3(0.92, 0.93, 0.9);
uniform float shore = -28.0;
uniform float swell = 0.12;
varying vec3 wpos;
varying float crest;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float out_to_sea = clamp((shore - w.z) / 30.0, 0.0, 1.0);
	float s = sin(w.x * 0.11 + w.z * 0.05 + TIME * 0.8) * 0.6 + sin(w.z * 0.21 - w.x * 0.03 + TIME * 1.15) * 0.4;
	VERTEX.y += s * swell * (0.35 + 0.65 * out_to_sea);
	crest = s;
	wpos = w;
}
void fragment() {
	vec2 p = wpos.xz;
	float d = max(shore - p.y, 0.0);
	vec3 n = vec3(0.5, 0.5, 1.0);
	if (scenery_detail > 0.5) {
		vec3 a = texture(waves, p * 0.045 + vec2(TIME * 0.011, TIME * 0.007)).rgb;
		vec3 b = texture(waves, p * 0.12 + vec2(-TIME * 0.009, TIME * 0.016)).rgb;
		n = normalize(vec3((a.xy + b.xy) - 1.0, 1.0)) * 0.5 + 0.5;
	}
	vec3 col = mix(shallow, deep, smoothstep(0.0, 40.0, d));
	// Surf: a band at the water's edge that comes and goes with the swell, broken up by the patches.
	float edge = 1.0 - smoothstep(0.0, 2.2 + crest * 0.8, d);
	float broken = texture(patches, p * vec2(0.08, 0.3) + vec2(TIME * 0.01, 0.0)).g;
	float f = clamp(edge * (0.55 + broken), 0.0, 1.0);
	f = max(f, smoothstep(0.75, 1.0, crest) * 0.25 * smoothstep(4.0, 12.0, d) * (1.0 - smoothstep(30.0, 60.0, d)) * broken);
	ALBEDO = mix(col, foam, f);
	ROUGHNESS = mix(0.05, 0.7, f);
	SPECULAR = 0.55;
	NORMAL_MAP = mix(n, vec3(0.5, 0.5, 1.0), f);
}
"""
static var _sea_shader: Shader = null


static func sea(shore: float) -> ShaderMaterial:
	if _sea_shader == null:
		_sea_shader = Shader.new()
		_sea_shader.code = SEA_SHADER
	var m := ShaderMaterial.new()
	m.shader = _sea_shader
	m.set_shader_parameter("waves", texture("water/water_normal_512.png"))
	m.set_shader_parameter("patches", texture("surfaces/patches.png"))
	m.set_shader_parameter("shore", shore)
	return m


## Walls and stands: a photographed surface's grain (concrete, plaster), in grey, on each face (laid along whichever
## axis the face looks down: in the world, or the thing's own axes where it is turned, a hut), in the wall's own colour.
## lift scales the grain's mean brightness to the one wanted.
const WALL_SHADER := """
shader_type spatial;
global uniform float scenery_detail;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 colour : source_color = vec3(0.2, 0.24, 0.3);
uniform float period = 2.5;
uniform float lift = 1.0;
uniform float rough = 0.85;
uniform bool own_axes = false;
varying vec3 pos;
varying vec3 nrm;
void vertex() {
	pos = own_axes ? VERTEX : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nrm = own_axes ? NORMAL : (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	vec3 an = abs(nrm);
	vec2 uv = an.y > max(an.x, an.z) ? pos.xz : (an.x > an.z ? pos.zy : pos.xy);
	vec3 c = texture(grain, uv / period).rgb;
	ALBEDO = colour * dot(c, vec3(0.2126, 0.7152, 0.0722)) * lift;
	ROUGHNESS = rough;
	if (scenery_detail > 0.5) {
		NORMAL_MAP = texture(grain_normal, uv / period).rgb;
		NORMAL_MAP_DEPTH = 0.6;
	}
}
"""
static var _wall_shader: Shader = null
## Each surface's mean brightness (linear), to lift its grain to the brightness wanted.
const GRAIN_MEAN := {"concrete_floor": 0.263, "clay_plaster": 0.113}


## A wall or stand of surface's grain, as bright on average as mean (linear) times colour.
static func wall(surface: String, colour: Color, mean: float, own_axes := false, period := 2.5) -> ShaderMaterial:
	if _wall_shader == null:
		_wall_shader = Shader.new()
		_wall_shader.code = WALL_SHADER
	var m := ShaderMaterial.new()
	m.shader = _wall_shader
	m.set_shader_parameter("grain", texture("surfaces/%s/%s_albedo_1k.jpg" % [surface, surface]))
	m.set_shader_parameter("grain_normal", texture("surfaces/%s/%s_normal_1k.jpg" % [surface, surface]))
	m.set_shader_parameter("colour", colour)
	m.set_shader_parameter("lift", mean / float(GRAIN_MEAN[surface]))
	m.set_shader_parameter("own_axes", own_axes)
	m.set_shader_parameter("period", period)
	return m


## A photographed surface as it is (a roof's tiles or thatch), laid along the thing's own axes, period metres a tile.
static func surface(name: String, period: float, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture("surfaces/%s/%s_albedo_1k.jpg" % [name, name])
	m.normal_enabled = true
	m.normal_texture = texture("surfaces/%s/%s_normal_1k.jpg" % [name, name])
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / period
	return m


## Apartment blocks at night: their walls dark, lit only by the street and the city's cloud (not by the stadium's
## floodlights, 80 m off: so unshaded), and here and there a window lit, warm, in patches that differ block to block.
## The models' windows are blue glass in a yellow wall: the blue is where the lit windows are.
const NIGHT_BLOCK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;
uniform vec3 night : source_color = vec3(0.07, 0.075, 0.095);
uniform vec3 lamp : source_color = vec3(1.0, 0.76, 0.42);
uniform float lit = 0.5;   // of the windows
varying float seed;
varying float shade;
void vertex() {
	seed = fract(MODEL_MATRIX[3].x * 0.137 + MODEL_MATRIX[3].z * 0.291);
	shade = COLOR.r;
}
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	float glass = smoothstep(0.02, 0.1, c.b - c.r);
	float on = step(1.0 - lit, texture(patches, UV * 2.5 + vec2(seed * 7.0, seed * 3.0)).g);
	ALBEDO = c * night * shade + lamp * glass * on * 0.75;
}
"""
static var _night_block_shader: Shader = null


static func night_block(path: String) -> ShaderMaterial:
	if _night_block_shader == null:
		_night_block_shader = Shader.new()
		_night_block_shader.code = NIGHT_BLOCK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _night_block_shader
	m.set_shader_parameter("albedo", load(DIR + path + "_albedo.jpg"))
	m.set_shader_parameter("patches", texture("surfaces/patches.png"))
	return m
