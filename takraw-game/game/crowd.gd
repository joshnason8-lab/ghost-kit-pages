class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one small sheet of figures, every one an instance of the same quad, so a
## stand of thousands is one draw call. Each one faces the court's centre (its instance turned that way); a shader
## turns the cut-out to the camera, shows the figure from the front or, when the camera is behind the spectator, from
## behind, picks its shirt, and makes it fidget. The figures are whole, legs and feet too: seated (on a seat, a step,
## a bench) or standing (on the sand, by the stalls). When the crowd goes up (excite) the seated get to their feet, a
## few at a time, and jump and cheer; as it settles they sit down again.

const FIGS := 16         # figures across the sheet
const FIG_W := 72        # each one's pixels
const FIG_H := 192
const FIG_W_M := 0.825   # and metres: from the floor (the feet) to above a hand held up
const FIG_H_M := 2.2
const ROWS := 4          # the sheet's rows: seated from the front, seated from behind, standing from the front, behind
const SEAT := 0.45       # a seat's height: a seated spectator's feet are this far under their spot
const SHEET := "res://assets/models/crowd_sheet.png"

static var _sheet: Texture2D
static var _mat: ShaderMaterial

var spots: Array[Vector3] = []   # where people sit (the seat) or stand
var placed: Array[Transform3D] = []   # each one's place (their feet) and the way they face (as the MultiMesh has them)
static var _excite := 0.0         # how excited the crowd is: what it is going toward, and what it shows now
static var _shown := 0.0


## The sheet: people from the players' models, seated and standing, rendered by tools/models/crowd_sheet.tscn.
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
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 8.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float row;
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	// Standing: always (data.w 1), or a seated spectator on their feet while the crowd is up past their own mark.
	float standing = data.w > 0.999 ? 1.0 : step(data.w, excite);
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * max(0.0, excite - 0.25) * 0.3 * standing;
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The way the spectator faces (the court), and whether the camera is behind them.
	vec3 facing = (MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	float behind = step(dot(facing.xz, to_cam.xz), 0.0);
	row = behind + 2.0 * standing;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	// (Kept a texel inside its row, or the filtering picks up the edge of the row next to it.)
	vec2 uv = vec2((UV.x + floor(data.x * figs)) / figs, (clamp(UV.y, 0.005, 0.995) + floor(row + 0.5)) / 4.0);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.45) * 0.75;
	// The shirt is the part the sheet marks (alpha 0.7), white with its shading: dyed.
	float is_shirt = 1.0 - smoothstep(0.8, 0.9, c.a);
	vec3 col = mix(c.rgb, shirt * c.r, is_shirt);
	ALBEDO = col * light;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS))
	return _mat


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours). spots
## are seats (the seat's height), standing where people stand (on the ground).
func build(p_spots: Array, density: float, palette: Array, seed_ := 1, standing := []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	var stands := []
	var all := p_spots + standing
	for i in all.size():
		if rng.randf() < density:
			keep.append(all[i])
			stands.append(i >= p_spots.size())
	spots = keep
	_excite = 0.0
	_shown = 0.0
	material().set_shader_parameter("excite", 0.0)
	placed.clear()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(FIG_W_M, FIG_H_M)
	q.center_offset = Vector3(0, FIG_H_M * 0.5, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var feet: Vector3 = keep[i] - (Vector3.ZERO if stands[i] else Vector3(0, SEAT, 0))
		placed.append(Transform3D(facing(keep[i]), feet))
		mm.set_instance_transform(i, placed[i])
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 else Color(rng.randf(), rng.randf(), rng.randf())
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase, w: 1 standing, else
		# how excited the crowd must be for them to get up.
		var up := 1.0 if stands[i] else rng.randf_range(0.3, 0.95)
		mm.set_instance_custom_data(i, Color(rng.randf(), _code(col), rng.randf(), up))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A spectator at spot faces the court's centre: their +Z turned toward it, on the ground.
static func facing(spot: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-spot.x, -spot.z))


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


func _process(delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
		# Up quickly, down slowly: people get to their feet together and sit down one by one.
		if _shown != _excite:
			_shown = move_toward(_shown, _excite, delta * (2.5 if _excite > _shown else 0.35))
			material().set_shader_parameter("excite", _shown)


static func set_excite(k: float) -> void:
	_excite = clampf(k, 0.0, 1.0)


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
