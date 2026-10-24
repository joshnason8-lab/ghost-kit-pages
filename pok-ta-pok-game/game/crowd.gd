class_name Crowd
extends MultiMeshInstance3D
## The spectators: cut-outs from one sheet of people, every one an instance of the same quad, so a crowd of thousands
## is one draw call. The sheet is rendered once, at loading, from the realistic townspeople made with Meshy
## (assets/people/fan_*: a ranchero in a palm hat, a grandmother in a rebozo, a boy, a man in a guayabera...), each from
## the front and from behind, every one twice (the second turned a little and in another light). Without them, the
## code-built bodies stand in; headless (the tests) there is nothing to render with, so a plain painted sheet does.
## Each person faces the court (their instance's +Z, toward its centre, flat); the shader turns the cut-out to the
## camera so it is never seen edge-on, and draws the person from the front when the camera is in front of them and
## from behind when it is behind them. They fidget, and jump when the crowd goes up (excite).

const FIGS := 16
const FIG_W := 64
const FIG_H := 176
const CARD := Vector2(0.66, 1.82)  # a standing person's card, metres (a hat on a tall man fits)
## The townspeople (tools/meshy/prepare.gd): mesh and texture, each at its height (m).
const FANS := [["fan_ranchero", 1.72], ["fan_blouse", 1.6], ["fan_elder", 1.65], ["fan_tshirt", 1.74], ["fan_rebozo", 1.52],
	["fan_boy", 1.38], ["fan_young_woman", 1.62], ["fan_guayabera", 1.7]]
## Medium and High: eight more, for a crowd of 32 different figures, each drawn half as large again (FIGS_HQ).
const FANS_HQ := [["fan_huipil", 1.5], ["fan_texana", 1.73], ["fan_cane", 1.62], ["fan_girl", 1.25], ["fan_mother", 1.58],
	["fan_jersey", 1.72], ["fan_yucatec", 1.6], ["fan_apron", 1.55]]
const FIGS_HQ := 32
const FIG_W_HQ := 96
const FIG_H_HQ := 264
## The sheet as baked: how many figures, and each one's size in pixels (Low: FIGS at FIG_W x FIG_H, as always).
static var figs := FIGS
static var fig_w := FIG_W
static var fig_h := FIG_H

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


static var _fans := {}


## The townspeople's meshes and materials: [[mesh, material, height]], or [] when they are not in the build. hq: all
## sixteen (Medium, High); otherwise Low's eight.
static func fan_meshes(hq := false) -> Array:
	if not _fans.has(hq):
		_fans[hq] = []
		for f in (FANS + FANS_HQ if hq else FANS):
			var path := "res://assets/people/%s.res" % f[0]
			if not ResourceLoader.exists(path):
				continue
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/people/%s.jpg" % f[0])
			m.roughness = 0.85
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			_fans[hq].append([load(path), m, float(f[1])])
	return _fans[hq]


## Medium and High, with all sixteen townspeople in the build.
static func hq_sheet() -> bool:
	return int(Game.settings.graphics) >= Game.GFX_MEDIUM and fan_meshes(true).size() >= FANS.size() + FANS_HQ.size()


## Is the sheet not yet baked, or baked for the other kind of graphics level?
static func needs_bake() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return not (_sheet is ImageTexture and _sheet.has_meta("baked") and bool(_sheet.get_meta("hq")) == hq_sheet())


## Renders the sheet from the townspeople (awaitable: it takes a few frames). Does nothing headless.
static func bake(host: Node) -> void:
	if not needs_bake():
		return
	var hq := hq_sheet()
	var nf := FIGS_HQ if hq else FIGS
	var fw := FIG_W_HQ if hq else FIG_W
	var fh := FIG_H_HQ if hq else FIG_H
	var sv := SubViewport.new()
	sv.size = Vector2i(fw * nf, fh)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(sv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var w := float(nf) * CARD.x
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
	var fans := fan_meshes(hq)
	var ps := people()
	for i in nf:
		var b: Node3D
		if not fans.is_empty():
			# A townsperson: the model stands 1.9 m tall about its middle (prepare.gd); scaled to their height.
			var f: Array = fans[i % fans.size()]
			var mi := MeshInstance3D.new()
			mi.mesh = f[0]
			mi.material_override = f[1]
			var k := float(f[2]) / 1.9 * (1.0 if i < fans.size() else 0.97)
			mi.scale = Vector3.ONE * k
			mi.position = Vector3(0, 0.95 * k, 0)
			b = Node3D.new()
			b.add_child(mi)
			sv.add_child(b)
		else:
			var body := Body.new(ps[i])
			sv.add_child(body)
			body.apply(Moves.judge_idle(float(i)))
			b = body
		b.position = Vector3((i + 0.5) * CARD.x, 0, 0)
		bodies.append(b)
	var img := Image.create_empty(fw * nf, fh * 2, false, Image.FORMAT_RGBA8)
	for view in 2:
		for i in nf:
			# The second of each pair turned a little, so the two read as different people in the stands.
			(bodies[i] as Node3D).rotation = Vector3(0, (PI if view == 1 else 0.0) + (0.35 if i >= nf / 2 else 0.0), 0)
		for k in 3:
			await RenderingServer.frame_post_draw
		var shot := sv.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		img.blit_rect(shot, Rect2i(0, 0, fw * nf, fh), Vector2i(0, fh * view))
	sv.queue_free()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("baked", true)
	tex.set_meta("hq", hq)
	_sheet = tex
	figs = nf
	fig_w = fw
	fig_h = fh
	if _mat:
		_mat.set_shader_parameter("sheet", _sheet)
		_mat.set_shader_parameter("figs", float(figs))


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
uniform float light_k = 1.0;
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
	ALBEDO = c.rgb * light_k * (0.88 + 0.24 * data.y);
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(figs))
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
	material().set_shader_parameter("light_k", k)
