class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one small sheet of figures, every one an instance of the same quad, so a
## stand of thousands is one draw call. Each one faces the court's centre (its instance turned that way), and turns
## partly to follow the ball (set_look); a shader turns the cut-out to the camera and shows the figure from the side
## the camera sees of them (the front, three-quarters, the side, from behind: Crowd.VIEWS), picks its shirt, and makes
## it fidget. The figures are whole, legs and feet too: seated (on a seat, a step,
## a bench) or standing (on the sand, by the stalls). When the crowd goes up (excite) the seated get to their feet, a
## few at a time, and jump and cheer; as it settles they sit down again.

const FIGS := 16         # figures across the sheet
const FIG_W := 72        # each one's pixels
const FIG_H := 192
const FIG_W_M := 0.825   # and metres: from the floor (the feet) to above a hand held up
const FIG_H_M := 2.2
const VIEWS := [0.0, 45.0, 90.0, 135.0, 180.0]   # the sides each figure is drawn from, in degrees from the front
const ROWS := 10         # the sheet's rows: seated from each of the VIEWS, then standing from each
const SEAT := 0.45       # a seat's height: a seated spectator's feet are this far under their spot
const SHEET := "res://assets/models/crowd_sheet.png"
## On Medium and High a bigger sheet: twice the figures (more skin tones and heights, shorts of their own colours,
## more poses), a third more pixels each; compressed for the GPU. The figures' size in metres is the same.
const FIGS_HI := 32
const FIG_W_HI := 96
const FIG_H_HI := 256
const SHEET_HI := "res://assets/models/crowd_sheet_hi.png"

static var _sheets := {}          # hi (bool) -> the sheet
static var _mat: ShaderMaterial
static var _flag_mat: ShaderMaterial
static var _flag_mesh: ArrayMesh
static var _mat_hi := false

var spots: Array[Vector3] = []   # where people sit (the seat) or stand
var placed: Array[Transform3D] = []   # each one's place (their feet) and the way they face (as the MultiMesh has them)
static var _excite := 0.0         # how excited the crowd is: what it is going toward, and what it shows now
static var _shown := 0.0
static var _look := Vector3.ZERO  # where the crowd looks (the ball), and where it looks now (following it, a little late)
static var _looking := Vector3.ZERO


## The sheet: people from the players' models, seated and standing, rendered by tools/models/crowd_sheet.tscn (the
## bigger one with -- hi).
static func sheet(big := hi()) -> Texture2D:
	if not _sheets.has(big):
		_sheets[big] = load(SHEET_HI if big else SHEET)
	return _sheets[big]


## Whether this graphics level has the bigger sheet (Medium and High).
static func hi() -> bool:
	return int(Game.settings.graphics) >= Game.GFX_MEDIUM and ResourceLoader.exists(SHEET_HI)


static func material() -> ShaderMaterial:
	if _mat:
		if _mat_hi != hi():
			_mat_hi = hi()
			_mat.set_shader_parameter("sheet", sheet())
			_mat.set_shader_parameter("figs", float(FIGS_HI if _mat_hi else FIGS))
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
uniform vec3 look_at = vec3(0.0);   // where the play is (the ball): spectators turn partly toward it
uniform float look_amt = 0.5;
varying vec4 data;
varying float row;
varying float mirror;
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	// Standing: always (data.w 1), or a seated spectator on their feet while the crowd is up past their own mark.
	float standing = data.w > 0.999 ? 1.0 : step(data.w, excite);
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * max(0.0, excite - 0.25) * 0.3 * standing;
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The way the spectator faces: the court's centre, turned partly toward the play.
	vec2 facing = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xz);
	vec2 to_play = look_at.xz - world.xz;
	if (dot(to_play, to_play) > 0.01) facing = normalize(mix(facing, normalize(to_play), look_amt));
	// The side of them the camera sees: how far round from their front (each a little different, so they don't all
	// turn at once), and whether on their left (as the sheet draws them) or their right (mirrored).
	vec2 to_cam = normalize((CAMERA_POSITION_WORLD - world).xz);
	float round_from = acos(clamp(dot(facing, to_cam), -1.0, 1.0)) + (data.z - 0.5) * 0.3;
	float view = clamp(floor(round_from / 0.7853982 + 0.5), 0.0, 4.0);
	mirror = step(dot(vec2(facing.y, -facing.x), to_cam), 0.0);
	row = view + 5.0 * standing;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	// (Kept a texel inside its row, or the filtering picks up the edge of the row next to it.)
	float u = mix(UV.x, 1.0 - UV.x, mirror);
	vec2 uv = vec2((u + floor(data.x * figs)) / figs, (clamp(UV.y, 0.005, 0.995) + floor(row + 0.5)) / 10.0);
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
	_mat_hi = hi()
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS_HI if _mat_hi else FIGS))
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
	_look = Vector3.ZERO
	_looking = Vector3.ZERO
	material().set_shader_parameter("excite", 0.0)
	material().set_shader_parameter("look_at", Vector3.ZERO)
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
	_flags(rng, keep, stands, palette)


## Flags in the home side's colours held up here and there in the crowd (one in thirty), waving, harder when the crowd
## is up: a pole and a cloth each, all of them one draw call.
func _flags(rng: RandomNumberGenerator, keep: Array[Vector3], stands: Array, palette: Array) -> void:
	if palette.size() < 2:
		return
	var xf: Array[Transform3D] = []
	for i in keep.size():
		if rng.randf() < 0.033:
			var feet: Vector3 = keep[i] - (Vector3.ZERO if stands[i] else Vector3(0, SEAT, 0))
			xf.append(Transform3D(facing(keep[i]).rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)), feet + Vector3(0.18, 0, 0)))
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _flag()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, palette[0])
		var c2: Color = palette[1]
		mm.set_instance_custom_data(i, Color(c2.r, c2.g, c2.b, rng.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _flag_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A flag on its pole, as held up by a seated spectator: the pole from the hands to 2.5 m, the cloth (UV.x along it,
## from the pole) in four strips so it can wave; UV.x below 0 marks the pole.
static func _flag() -> ArrayMesh:
	if _flag_mesh:
		return _flag_mesh
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	v.append_array([Vector3(-0.012, 1.1, 0), Vector3(0.012, 1.1, 0), Vector3(0.012, 2.5, 0), Vector3(-0.012, 2.5, 0)])
	uv.append_array([Vector2(-1, 0), Vector2(-1, 0), Vector2(-1, 1), Vector2(-1, 1)])
	idx.append_array([0, 1, 2, 0, 2, 3])
	for k in 5:
		var u := k / 4.0
		v.append_array([Vector3(u * 0.75, 1.98, 0), Vector3(u * 0.75, 2.48, 0)])
		uv.append_array([Vector2(u, 0), Vector2(u, 1)])
		if k > 0:
			var b := 4 + (k - 1) * 2
			idx.append_array([b, b + 2, b + 3, b, b + 3, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	_flag_mesh = ArrayMesh.new()
	_flag_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _flag_mesh


static func _flag_material() -> ShaderMaterial:
	if _flag_mat:
		return _flag_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float excite = 0.0;
uniform float light = 1.0;
varying vec4 cols;
varying vec3 top;
void vertex() {
	cols = INSTANCE_CUSTOM;
	top = COLOR.rgb;
	if (UV.x >= 0.0) {
		float ph = cols.a * 6.2831;
		VERTEX.z += sin(TIME * (5.0 + 4.0 * excite) + ph - UV.x * 3.0) * 0.16 * UV.x * (0.5 + excite);
		VERTEX.y -= 0.06 * UV.x * UV.x;
	}
}
void fragment() {
	vec3 c = UV.x < 0.0 ? vec3(0.55) : (UV.y > 0.5 ? top : cols.rgb);
	ALBEDO = c * light;
}
"""
	_flag_mat = ShaderMaterial.new()
	_flag_mat.shader = sh
	return _flag_mat


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
			_flag_material().set_shader_parameter("excite", _shown)
		if _looking != _look:
			_looking = _look if _looking.distance_to(_look) < 0.01 else _looking.lerp(_look, minf(1.0, delta * 2.5))
			material().set_shader_parameter("look_at", _looking)


static func set_excite(k: float) -> void:
	_excite = clampf(k, 0.0, 1.0)


## Where the play is (the ball, on the ground): the crowd turns partly toward it, following it a little late.
static func set_look(at: Vector3) -> void:
	_look = Vector3(at.x, 0.0, at.z)


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
	_flag_material().set_shader_parameter("light", k)
