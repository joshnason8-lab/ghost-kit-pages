class_name Crowd
extends MultiMeshInstance3D
## The spectators: cut-outs of the owner's two athletes posed as spectators (seated, leaning, clapping, standing to
## cheer), each seen from five angles round them, on one sheet (assets/crowd/crowd_atlas.png, baked by
## tools/crowd/make_atlas.gd). Every person is an instance of the same upright quad, so a stand of thousands is one
## draw call. The shader turns each quad to the camera, picks the cut-out of that person's pose seen from where the
## camera is (mirrored for the other side), gives them their shirt's colour and their skin's tone, makes them fidget,
## and stands them up to cheer when the crowd goes up (excite).

const SHEET := "res://assets/crowd/crowd_atlas.png"
const COLS := 16.0            # cut-outs across the sheet; 4 rows
const ROWS := 4.0
const POSES := 5              # sit, lean, clap, cheer, fist (make_atlas.gd's POSES)
const VIEWS := 5              # 0, 45, 90, 135, 180 degrees round the person
const FRAME := Vector2(1.1, 2.2)   # metres a cut-out shows (make_atlas.gd: FRAME_H, cells 1:2)

static var _sheet: Texture2D
static var _mat: ShaderMaterial

var spots: Array[Vector3] = []   # where people sit (the floor under their feet)


static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(SHEET)
	return _sheet


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
varying vec2 cell;       // the cut-out's column and row
varying float mirror;
varying vec3 shirt;
varying vec3 tone;
varying vec2 uv;
void vertex() {
	vec4 d = INSTANCE_CUSTOM;   // x: model + idle pose / 10, y: skin tone, z: phase, w: facing (turns)
	shirt = COLOR.rgb;
	float model = floor(d.x + 0.001);
	float idle = floor(fract(d.x) * 10.0 + 0.5);
	float ph = d.z * 6.2831;
	// Up on their feet when the crowd goes up: the keenest first.
	float up = step(1.0 - excite, fract(d.z * 7.31)) * step(0.05, excite);
	float pose = up > 0.5 ? (fract(d.z * 3.7) < 0.6 ? 3.0 : 4.0) : idle;
	// A clapper claps.
	if (idle > 1.5 && up < 0.5 && sin(time_s * 7.0 + ph) < 0.0) pose = 0.0;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 to_cam = normalize(cam.xz - world.xz);
	float fa = d.w * 6.2831853;
	vec2 face = vec2(sin(fa), cos(fa));
	float ang = atan(face.y * to_cam.x - face.x * to_cam.y, dot(face, to_cam));
	float view = clamp(floor(abs(ang) / 0.7853982 + 0.5), 0.0, 4.0);
	mirror = ang < 0.0 ? 1.0 : 0.0;
	float idx = (model * 5.0 + pose) * 5.0 + view;
	cell = vec2(mod(idx, 16.0), floor(idx / 16.0));
	tone = mix(vec3(1.0), vec3(0.42, 0.33, 0.27), d.y);
	// Seated, a person fills only the cut-out's lower 70%: the quad shrinks to that (less overdraw).
	float seated = step(pose, 2.5);
	float fh = mix(1.0, 0.71, seated);
	VERTEX.y *= fh;
	uv = vec2(UV.x, 1.0 - (1.0 - UV.y) * fh);
	float jump = up * max(0.0, sin(time_s * 8.0 + ph)) * excite * 0.12;
	float fidget = sin(time_s * 1.3 + ph) * 0.015;
	vec3 right = vec3(-to_cam.y, 0.0, to_cam.x);
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	float u = mirror > 0.5 ? 1.0 - uv.x : uv.x;
	vec4 c = texture(sheet, (cell + vec2(u, uv.y)) / vec2(16.0, 4.0));
	if (c.a < 0.25) discard;
	float is_shirt = smoothstep(0.8, 0.95, c.a);
	float is_skin = (1.0 - is_shirt) * smoothstep(0.5, 0.62, c.a);
	vec3 col = c.rgb;
	col = mix(col, shirt * clamp(dot(c.rgb, vec3(0.3333)) / 0.5, 0.25, 1.6), is_shirt);
	col = mix(col, col * tone, is_skin);
	ALBEDO = col * light;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	return _mat


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours), the
## rest (1 - share of them) a spectator's everyday colours. Each faces the rink. A share of 1 with two colours is a
## pair of benches: the first colour for those left of the centre line, the second for those right of it.
func build(p_spots: Array, density: float, palette: Array, seed_ := 1, share := 0.45) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	for s in p_spots:
		if rng.randf() < density:
			keep.append(s)
	spots = keep
	var everyday := [Color("2b2f36"), Color("e8e8e6"), Color("3b5b8c"), Color("8a1f2b"), Color("4b6b3a"), Color("c9a227"),
		Color("6d6f73"), Color("1f3f6b"), Color("b4552d"), Color("d8d2c4"), Color("5a3d6e"), Color("2f6f73")]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = FRAME
	q.center_offset = Vector3(0, FRAME.y * 0.5, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var p := keep[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < share \
			else everyday[rng.randi_range(0, everyday.size() - 1)]
		if share >= 1.0 and palette.size() == 2:
			col = palette[0 if p.x < 0.0 else 1]
		col = col.lightened(rng.randf_range(-0.08, 0.08))
		mm.set_instance_color(i, col.srgb_to_linear())
		# Facing the rink: toward the nearest point of its middle.
		var aim := Vector3(clampf(p.x, -11.0, 11.0), 0.0, clampf(p.z, -2.0, 2.0)) - p
		var facing := fposmod(atan2(aim.x, aim.z) / TAU, 1.0)
		var model := rng.randi_range(0, 1)
		var idle: int = [0, 0, 1, 2][rng.randi_range(0, 3)]
		var tone := 0.0 if rng.randf() < 0.75 else rng.randf_range(0.25, 1.0)
		mm.set_instance_custom_data(i, Color(model + idle * 0.1, tone, rng.randf(), facing))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", fmod(Time.get_ticks_msec() / 1000.0, 3600.0))


static func set_excite(k: float) -> void:
	material().set_shader_parameter("excite", clampf(k, 0.0, 1.0))


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
