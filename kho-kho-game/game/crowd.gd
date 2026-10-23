class_name Crowd
extends MultiMeshInstance3D
## The spectators: cut-outs from one sheet of figures, every one an instance of the same quad, so a stand of thousands
## is one draw call. A shader turns each to face the camera, picks its figure and shirt from the sheet, makes it
## fidget, and at an out (excite) brings some of them to their feet, cheering.
##
## The sheet is the players' own model (ModelBody), posed and lit and drawn once at load (render_sheet): row 0 the
## crowd at rest, four sitting and four standing and clapping, in four skin tones; row 1 the same people cheering;
## rows 2 and 3 the same again seen from behind. Their shirts are drawn in a key colour (magenta) that the shader paints
## with each person's colour. Where nothing can be drawn (the headless tests) the sheet is painted in code instead.
##
## Every spectator faces the court's centre (his instance's +Z, flattened to the ground). The card always turns to
## the camera, but shows his back when the camera is behind him: the near side's crowd, between the broadcast camera
## and the play, is seen from behind, watching the play (until 0.4.1 they all faced the camera).

const FIGS := 8          # figures across the sheet
const FIG_W := 64
const FIG_H := 128
const CELL_M := Vector2(1.1, 2.2)   # the metres a cell covers
const SEAT_DROP := 0.88             # a seated figure's hips are this far above its cell's foot
const ROWS := 4                     # at rest, cheering; from the front, from behind

static var _sheet: ImageTexture
static var _mat: ShaderMaterial
static var _rendered := false

var spots: Array[Vector3] = []   # where people stand, or sit (their seat)
var xforms: Array[Transform3D] = []   # each one's transform, as given to the multimesh (which keeps none headless)


static func sheet() -> ImageTexture:
	if _sheet:
		return _sheet
	_sheet = ImageTexture.create_from_image(_painted())
	return _sheet


## The sheet drawn from the model: 8 figures by 4 rows. Awaitable; a no-op where nothing renders.
static func render_sheet(tree: SceneTree) -> void:
	if _rendered or DisplayServer.get_name() == "headless":
		return
	_rendered = true
	var vp := SubViewport.new()
	vp.size = Vector2i(FIG_W * FIGS, FIG_H * ROWS)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child.call_deferred(vp)   # the root may be busy adding its own children
	await tree.process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CELL_M.y * ROWS
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(CELL_M.x * FIGS * 0.5, 0.0, 10.0)
	vp.add_child(cam)
	cam.current = true
	var tones := [Color("d9a77a"), Color("c48a5c"), Color("a86b45"), Color("6e4430")]
	for row in ROWS:
		for i in FIGS:
			var b := ModelBody.new({"skin": tones[i % 4], "jersey": Color(1, 0, 1), "shorts": Color("2a2a30"),
				"height": 1.72 + 0.04 * float((i * 7) % 3)}, true)
			vp.add_child(b)
			var seated := i < 4
			var cheering := row % 2 == 1
			var back := row >= 2
			# Row r between (1 - r) and (2 - r) cells above the camera; each figure's feet at its cell's foot.
			b.position = Vector3(CELL_M.x * (i + 0.5), (1.0 - row) * CELL_M.y + 0.05, 0.0)
			b.rotation.y = deg_to_rad([0.0, 12.0, -10.0, 20.0][i % 4]) + (PI if back else 0.0)
			b.play("cheer" if cheering else ("seated" if seated else ("clap" if i % 2 == 0 else "stand")), 1.0, 0.0)
	for k in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	if OS.get_environment("KK_SHEET") != "":
		img.save_png(OS.get_environment("KK_SHEET"))
	img.generate_mipmaps()
	if _sheet:
		_sheet.update(img)
	else:
		_sheet = ImageTexture.create_from_image(img)
	if _mat:
		_mat.set_shader_parameter("sheet", _sheet)


## The painted fallback: the same layout, in flat shapes.
static func _painted() -> Image:
	var img := Image.create_empty(FIG_W * FIGS, FIG_H * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skins := [Color("d9a77a"), Color("c48a5c"), Color("a86b45"), Color("6e4430")]
	for row in ROWS:
		for f in FIGS:
			var ox := f * FIG_W
			var oy := row * FIG_H
			var skin: Color = skins[f % 4]
			for y in FIG_H:
				for x in FIG_W:
					var u := (x + 0.5) / FIG_W - 0.5
					var v := (y + 0.5) / FIG_H
					var c := Color(0, 0, 0, 0)
					var top := 0.55 if (f < 4 and row % 2 == 0) else 0.32
					if v > top + 0.12 and absf(u) < 0.2:
						c = Color(1, 0, 1, 1)
					if v > top + 0.45 and absf(u) < 0.18:
						c = Color("2a2a30")
					var hd := Vector2(u / 0.11, (v - top - 0.05) / 0.06)
					if hd.length() < 1.0:
						c = skin if row < 2 else Color("16110d")   # from behind: his hair
					img.set_pixel(ox + x, oy + y, c)
	img.generate_mipmaps()
	return img


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 8.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
uniform float rows = 4.0;
varying vec4 data;
varying float up;
varying float back;
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	// At an out, a share of them (as many as excite says) on their feet, jumping.
	up = step(1.0 - excite, fract(data.z * 13.71));
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * up * 0.22;
	float fidget = sin(time_s * 1.3 + ph) * 0.015;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// He faces the court (his +Z); the camera behind him sees his back.
	vec2 face = normalize(MODEL_MATRIX[2].xz + vec2(1e-5));
	vec2 to_cam = INV_VIEW_MATRIX[3].xz - world.xz;
	back = step(dot(face, to_cam), 0.0);
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	float row = up + 2.0 * back;
	vec2 uv = vec2((UV.x + floor(data.x * figs)) / figs, (UV.y + row) / rows);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3) * 0.9;
	// The key colour: magenta, its brightness the cloth's shading.
	float key = clamp((min(c.r, c.b) - c.g) * 3.0, 0.0, 1.0);
	float shade = max(c.r, c.b);
	vec3 col = mix(c.rgb, shirt * shade, key);
	ALBEDO = col * light;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS))
	_mat.set_shader_parameter("rows", float(ROWS))
	return _mat


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours). A spot
## sits (a figure from the sheet's sitting four) where seated says, where its height is below the ground (a row of
## a ground crowd on the earth), or where it is a seat's height (a chair or a bench).
func build(p_spots: Array, density: float, palette: Array, seed_ := 1, seated := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	var sits: Array[bool] = []
	for s in p_spots:
		if rng.randf() < density:
			var v: Vector3 = s
			var sit := seated or v.y < -0.2 or v.y > 0.3
			if v.y < -0.2:
				v.y = 0.15   # on the earth, on his haunches
			keep.append(v)
			sits.append(sit)
	spots = keep
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = CELL_M
	q.center_offset = Vector3(0, CELL_M.y * 0.5, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	xforms.clear()
	for i in keep.size():
		var base := keep[i] - Vector3(0, SEAT_DROP if sits[i] else 0.0, 0)
		xforms.append(Transform3D(Basis(Vector3.UP, facing(base)), base))
		mm.set_instance_transform(i, xforms[i])
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 else Color(rng.randf(), rng.randf(), rng.randf())
		var fig := rng.randi_range(0, 3) + (0 if sits[i] else 4)
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase.
		mm.set_instance_custom_data(i, Color((fig + 0.5) / FIGS, _code(col), rng.randf(), 0.0))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The way a spectator at p faces: toward the court's centre, flattened to the ground (a yaw: +Z turned by it).
static func facing(p: Vector3) -> float:
	return atan2(-p.x, -p.z)


## Shirt colours come out of the shader from one number; find one whose colour is near col (a few tries).
static func _code(col: Color) -> float:
	var best := 0.0
	var bd := 9.0
	for i in 256:
		var y := float(i) / 256.0 + 0.001
		var c := Vector3(fposmod(y * 7.13, 1.0), fposmod(y * 3.77, 1.0), fposmod(y * 5.31, 1.0))
		var d := c.distance_to(Vector3(col.r, col.g, col.b))
		if d < bd:
			bd = d
			best = y
	return best


func _process(_delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)


static func set_excite(k: float) -> void:
	material().set_shader_parameter("excite", clampf(k, 0.0, 1.0))


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
