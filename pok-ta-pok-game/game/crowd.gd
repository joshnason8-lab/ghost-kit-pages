class_name Crowd
extends MultiMeshInstance3D
## The spectators: cut-outs from one sheet of people, every one an instance of the same quad, so a crowd of thousands
## is one draw call. The sheet is rendered once, at loading, from the same lit 3D bodies as the players (bake): sixteen
## people in everyday clothes (shirts, trousers or long skirts, straw hats and caps), each from the front and from
## behind. Headless (the tests) there is nothing to render with, so a plain painted sheet stands in.
## Each person faces the court (their instance's +Z, toward its centre, flat); the shader turns the cut-out to the
## camera so it is never seen edge-on, and draws the person from the front when the camera is in front of them and
## from behind when it is behind them. They fidget, and jump when the crowd goes up (excite).

const FIGS := 16
const FIG_W := 64
const FIG_H := 176
const CARD := Vector2(0.62, 1.7)   # a standing person's card, metres

static var _sheet: Texture2D
static var _mat: ShaderMaterial

var spots: Array[Vector3] = []
var facings: Array[Vector3] = []
var xforms: Array[Transform3D] = []   # each person's place and turn as given to the MultiMesh (kept: headless keeps none)


## The people on the sheet: shirt, trousers or skirt, hat (0 none, 1 straw, 2 cap), long hair.
static func people() -> Array:
	var shirts := [Color("e8e4da"), Color("2f5d8a"), Color("b8352b"), Color("e0a43a"), Color("3c8f5a"), Color("f2efe6"),
		Color("6b4a8a"), Color("c96a8a"), Color("2a2a2e"), Color("4fa3b8"), Color("d9c8a0"), Color("8a2b24"),
		Color("eadfc8"), Color("1f7f86"), Color("e7b98f"), Color("5a6b3a")]
	var out := []
	for i in FIGS:
		var woman := i % 3 == 1
		out.append({"kind": "spectator", "shirt": shirts[i], "trousers": [Color("2f3a52"), Color("3a3430"), Color("5a4a3a"), Color("6a2a3a"), Color("2c2a2e")][i % 5],
			"skirt": woman, "long_hair": woman, "hat": [1, 0, 2, 0, 1, 0, 0, 2][i % 8] if not woman else 0,
			"cap": [Color("8a2b24"), Color("1f3a6a"), Color("2a2a2e")][i % 3],
			"skin": DB.SKINS[(i * 3) % 4], "hair": DB.HAIRS[i % 3], "height": 1.6 + 0.12 * float((i * 7) % 5) / 4.0, "build": float((i * 5) % 7) / 6.0})
	return out


static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = _painted()
	return _sheet


## Renders the sheet from the bodies (awaitable: it takes a few frames). Does nothing headless.
static func bake(host: Node) -> void:
	if DisplayServer.get_name() == "headless" or _sheet is ImageTexture and _sheet.has_meta("baked"):
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(FIG_W * FIGS, FIG_H)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var w := float(FIGS) * CARD.x
	cam.size = CARD.y
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(w * 0.5, CARD.y * 0.5, 10.0)
	sv.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	sun.light_energy = 1.2
	sv.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.55
	we.environment = env
	sv.add_child(we)
	var bodies := []
	var ps := people()
	for i in FIGS:
		var b := Body.new(ps[i])
		sv.add_child(b)
		b.position = Vector3((i + 0.5) * CARD.x, 0, 0)
		b.apply(Moves.judge_idle(float(i)))
		bodies.append(b)
	var img := Image.create_empty(FIG_W * FIGS, FIG_H * 2, false, Image.FORMAT_RGBA8)
	for view in 2:
		for i in FIGS:
			(bodies[i] as Body).rotation = Vector3(0, PI if view == 1 else 0.0, 0)
		for k in 3:
			await RenderingServer.frame_post_draw
		var shot := sv.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		img.blit_rect(shot, Rect2i(0, 0, FIG_W * FIGS, FIG_H), Vector2i(0, FIG_H * view))
	sv.queue_free()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("baked", true)
	_sheet = tex
	if _mat:
		_mat.set_shader_parameter("sheet", _sheet)


## The stand-in sheet: simple standing figures, front and back.
static func _painted() -> ImageTexture:
	var img := Image.create_empty(FIG_W * FIGS, FIG_H * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ps := people()
	for view in 2:
		for f in FIGS:
			var pp: Dictionary = ps[f]
			for y in FIG_H:
				for x in FIG_W:
					var u := (x + 0.5) / FIG_W - 0.5
					var v := (y + 0.5) / FIG_H
					var c := Color(0, 0, 0, 0)
					if v > 0.18 and v < 0.55 and absf(u) < 0.2:
						c = pp.shirt
					elif v >= 0.55 and absf(u) < 0.15:
						c = pp.trousers
					elif Vector2(u / 0.08, (v - 0.12) / 0.07).length() < 1.0:
						c = pp.hair if view == 1 else pp.skin
					img.set_pixel(f * FIG_W + x, view * FIG_H + y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 16.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float back;
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * excite * 0.22 * step(0.35, data.w);
	float sway = sin(time_s * 1.3 + ph) * 0.015;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The person faces their instance's +Z (the court); seen from behind, draw them from behind (Crowd.seen_from_behind).
	vec3 facing = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z));
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	back = dot(facing, vec3(to_cam.x, 0.0, to_cam.z)) < 0.0 ? 1.0 : 0.0;
	world += right * (VERTEX.x + sway * VERTEX.y) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	vec2 uv = vec2((UV.x + floor(data.x * figs)) / figs, (UV.y + back) * 0.5);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb * light * (0.88 + 0.24 * data.y);
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS))
	return _mat


## Fills the spots with people (density 0-1 of them).
func build(p_spots: Array, density: float, _palette: Array, seed_ := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	for s in p_spots:
		if rng.randf() < density:
			keep.append(s)
	spots = keep
	facings = []
	xforms = []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = CARD
	q.center_offset = Vector3(0, CARD.y * 0.5, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var f := facing_at(keep[i])
		facings.append(f)
		var t := Transform3D(Basis(Vector3.UP, atan2(f.x, f.z)), keep[i])
		xforms.append(t)
		mm.set_instance_transform(i, t)
		# x: the figure; y: a little lighter or darker; z: phase; w: whether they jump.
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The way a spectator at p faces: toward the centre of the court, flat on the ground.
static func facing_at(p: Vector3) -> Vector3:
	var d := Vector3(-p.x, 0.0, -p.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


static func seen_from_behind(p: Vector3, facing: Vector3, cam: Vector3) -> bool:
	var to_cam := cam - p
	return facing.dot(Vector3(to_cam.x, 0.0, to_cam.z)) < 0.0


func _process(_delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)


static func set_excite(k: float) -> void:
	material().set_shader_parameter("excite", clampf(k, 0.0, 1.0))


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
