class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one sheet of people, every one an instance of the same quad, so a stand of
## thousands is one draw call. The sheet is rendered from the maker's own models (two fans made with Meshy, in four
## poses each: tools/crowd/render_fans.gd), head to waist, from the front and from behind. Each person faces the pitch
## (their instance's +Z, toward the centre of the field); the shader turns the cut-out to the camera so it is never
## seen edge-on, and draws the person from the front when the camera is in front of them, from behind (the back of
## the head, no face) when it is behind them, as the television camera is behind the near stand. It picks the figure
## and shirt (the sheet's mask says where the shirt is), and makes them fidget, and jump and wave when the crowd goes
## up (excite). (Round five: "upgrade the look of the fans, they just look like shapes".)

const FIGS := 8          # figures across the sheet, each drawn twice: from the front, then (FIGS more) from behind
const FIG_W := 64
const FIG_H := 128
const SHEET := "res://assets/crowd/sheet.png"
const MASK := "res://assets/crowd/mask.png"

static var _sheet: Texture2D
static var _mask: Texture2D
static var _mat: ShaderMaterial

var spots: Array[Vector3] = []   # where people stand or sit (their feet)
var facings: Array[Vector3] = [] # the way each faces: toward the centre of the field, flat


## The sheet: eight people from the front, then the same eight from behind (and its shirt mask).
static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(SHEET)
		_mask = load(MASK)
	return _sheet


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform float figs = 8.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float back;
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * excite * 0.28;
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The person faces their instance's +Z (the pitch); seen from behind, draw them from behind (Crowd.seen_from_behind).
	vec3 facing = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z));
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	back = dot(facing, vec3(to_cam.x, 0.0, to_cam.z)) < 0.0 ? 1.0 : 0.0;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	vec2 uv = vec2((UV.x + floor(data.x * figs) + back * figs) / (figs * 2.0), UV.y);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3) * 0.9;
	// The shirt is white on the sheet: its shading kept, its colour each person's.
	float is_shirt = smoothstep(0.3, 0.7, texture(mask, uv).r);
	float shade = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.86;
	vec3 col = mix(c.rgb, shirt * shade, is_shirt);
	ALBEDO = pow(col, vec3(2.2)) * light;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("mask", _mask)
	_mat.set_shader_parameter("figs", float(FIGS))
	return _mat


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours).
func build(p_spots: Array, density: float, palette: Array, seed_ := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	for s in p_spots:
		if rng.randf() < density:
			keep.append(s)
	spots = keep
	facings = []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.52, 1.04)
	q.center_offset = Vector3(0, 0.52, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var f := facing_at(keep[i])
		facings.append(f)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(f.x, f.z)), keep[i]))
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 else Color(rng.randf(), rng.randf(), rng.randf())
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase.
		mm.set_instance_custom_data(i, Color(rng.randf(), _code(col), rng.randf(), 0.0))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The way a spectator at p faces: toward the centre of the field, flat on the ground.
static func facing_at(p: Vector3) -> Vector3:
	var d := Vector3(-p.x, 0.0, -p.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


## What the shader decides for each person: is the camera behind them (so they are drawn from behind)?
static func seen_from_behind(p: Vector3, facing: Vector3, cam: Vector3) -> bool:
	var to_cam := cam - p
	return facing.dot(Vector3(to_cam.x, 0.0, to_cam.z)) < 0.0


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
