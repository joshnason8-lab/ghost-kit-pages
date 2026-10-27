class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one small sheet of figures, every one an instance of the same quad, so a
## stand of thousands is one draw call. Each one faces the court's centre (its instance turned that way), and turns
## partly to follow the ball (set_look), some quicker than others; a shader turns the cut-out to the camera and shows
## the figure from the side the camera sees of them (the front, three-quarters, the side, from behind: Crowd.VIEWS),
## going from one side to the next as they turn (a dissolve, not a jump), picks its shirt, and makes it fidget. The
## figures are whole, legs and feet too: seated (on a seat, a step, a bench) or standing (on the sand, by the
## stalls). When the crowd goes up (excite) the seated get to their feet, a few at a time, and cheer, each their own
## way (clapping, jumping, a fist pumped, both arms up swaying: Crowd.CHEERS), played from the sheet's frames; as it
## settles they stop and sit down again, one by one. Flags of the two teams playing wave here and there (show_teams).

const FIGS := 16         # figures across the sheet
const FIG_W := 72        # each one's pixels
const FIG_H := 192
const FIG_W_M := 0.825   # and metres: from the floor (the feet) to above a hand held up
const FIG_H_M := 2.2
const VIEWS := [0.0, 45.0, 90.0, 135.0, 180.0]   # the sides each figure is drawn from, in degrees from the front
const ROWS := 10         # the figures at rest: seated from each of the VIEWS, then standing from each
## The people cheering: each of the first half of the figures (the second half are the same people in other poses)
## in CHEER_FRAMES frames of their own cheer, from each of the VIEWS.
const CHEER_FRAMES := 3
const CHEER_CLAP := 0
const CHEER_JUMP := 1
const CHEER_FIST := 2
const CHEER_SWAY := 3
## Each person's cheer (the high sheet's sixteen; the low one's eight are the first eight): most clap.
const CHEERS := [0, 1, 2, 0, 3, 1, 0, 2, 1, 0, 3, 2, 0, 1, 2, 0]
## The sheet's cells, a row after another: ROWS * figures at rest, then the cheering. Wider than the figures (a
## quarter more), so it is 14 cells high whatever the figures: within 4096 px for the GPUs of older phones.
const SHEET_ROWS := 14
const SEAT := 0.45       # a seat's height: a seated spectator's feet are this far under their spot
const SHEET := "res://assets/models/crowd_sheet.png"
## On Medium and High a bigger sheet: twice the figures (more skin tones and heights, shorts of their own colours,
## more poses), a third more pixels each; compressed for the GPU. The figures' size in metres is the same.
const FIGS_HI := 32
const FIG_W_HI := 96
const FIG_H_HI := 256
const SHEET_HI := "res://assets/models/crowd_sheet_hi.png"
const FLAG_W := 96       # a flag's pixels (in the crowd)
const FLAG_H := 64
const TURN_STEP := 1.2   # m (set_look)
const TURN_TIME := 0.7   # s

static var _sheets := {}          # hi (bool) -> the sheet
static var _mat: ShaderMaterial
static var _flag_mat: ShaderMaterial
static var _flag_mesh: ArrayMesh
static var _mat_hi := false

var spots: Array[Vector3] = []   # where people sit (the seat) or stand
var placed: Array[Transform3D] = []   # each one's place (their feet) and the way they face (as the MultiMesh has them)
var _flag_at: Array[Transform3D] = []   # where the flags are held up
var _flag_mi: MultiMeshInstance3D
static var _excite := 0.0         # how excited the crowd is: what it is going toward, and what it shows now
static var _shown := 0.0
static var _look := Vector3.ZERO  # where the crowd looks (the ball), and where it looks now (following it, a little late)
static var _looking := Vector3.ZERO
## The crowd turns with the play in steps (each when the play has moved TURN_STEP): from where it looked to where it
## looks, each spectator a moment of the turn after another's (TURN_TIME in all), so between turns every one is still.
static var _look_from := Vector3.ZERO
static var _look_to := Vector3.ZERO
static var _turn := 1.0


## The sheet: people from the players' models, seated and standing, rendered by tools/models/crowd_sheet.tscn (the
## bigger one with -- hi).
static func sheet(big := hi()) -> Texture2D:
	if not _sheets.has(big):
		_sheets[big] = load(SHEET_HI if big else SHEET)
	return _sheets[big]


## Whether this graphics level has the bigger sheet (Medium and High).
static func hi() -> bool:
	return int(Game.settings.graphics) >= Game.GFX_MEDIUM and ResourceLoader.exists(SHEET_HI)


## The sheet's cells across, for so many figures.
static func cols(figs: int) -> int:
	return figs + figs / 4


## Where cell i is on the sheet (column, row).
static func cell(i: int, figs: int) -> Vector2i:
	return Vector2i(i % cols(figs), i / cols(figs))


## The cell of person l cheering, frame fr, from view v (an index into VIEWS).
static func cheer_cell(l: int, fr: int, v: int, figs: int) -> int:
	return ROWS * figs + (fr * VIEWS.size() + v) * (figs / 2) + l


static func material() -> ShaderMaterial:
	if _mat:
		if _mat_hi != hi():
			_mat_hi = hi()
			_sheet_params()
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 16.0;
uniform float cols = 20.0;
uniform float cheers[16];
uniform float excite = 0.0;
uniform float excite_to = 0.0;      // where the excitement is going
uniform float time_s = 0.0;
uniform float light = 1.0;
uniform vec3 look_from = vec3(0.0); // where the play was and is (the ball): spectators turn partly toward it, as
uniform vec3 look_to = vec3(0.0);   // far round as the turn has got for them (turn, 0-1, theirs later or sooner)
uniform float turn = 1.0;
varying vec4 data;
varying vec4 sides;    // the side of them seen (0 front .. 4 behind) and mirrored (0, 1): before the turn (x, y), after (z, w)
varying vec3 pose;     // x: how far they have turned (0-1), y: on their feet (0-1), z: cheering (0-1)
varying float frame;   // the cheer's frame (0-2, between two)

// How far a spectator whose mark it is has got (0 .. 1) as the excitement passes it: over band of it, or less when
// the crowd stops short of that (never left half way).
float up_by(float mark, float band) {
	float b = excite_to > mark ? clamp(excite_to - mark, 0.0001, band) : band;
	return clamp((excite - mark) / b, 0.0, 1.0);
}

// The side of a spectator facing front (the court's centre), turned partly toward the play, that the camera sees:
// how many of the VIEWS round from their front, and whether on their left (as the sheet draws them: 0) or right (1).
vec2 seen(vec2 front, vec2 to_play, vec2 to_cam, float h) {
	vec2 facing = front;
	if (dot(to_play, to_play) > 0.01) facing = normalize(mix(front, normalize(to_play), mix(0.35, 0.7, h)));
	float round_from = acos(clamp(dot(facing, to_cam), -1.0, 1.0));
	return vec2(clamp(floor(round_from / 0.7853982 + 0.5), 0.0, 4.0), step(dot(vec2(facing.y, -facing.x), to_cam), 0.0));
}

void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	float h1 = fract(data.z * 17.31 + data.x * 5.17);
	float h2 = fract(data.z * 41.7 + data.y * 3.3);
	// On their feet: always (data.w 1), or a seated spectator once the crowd is up past their own mark; cheering a
	// little after (those always standing, from a mark of their own).
	float mark = data.w > 0.999 ? mix(0.3, 0.95, h2) : data.w;
	float standing = data.w > 0.999 ? 1.0 : up_by(mark, 0.12);
	float cheer = up_by(mark + 0.03, 0.12);
	// The cheer: each person's own (by the sheet), at their own pace and moment.
	float fig = floor(data.x * figs);
	float person = mod(fig, figs * 0.5);
	float kind = cheers[int(person)];
	float u = fract(time_s * mix(0.88, 1.12, h1) * (kind < 0.5 ? 2.3 : (kind < 1.5 ? 1.2 : (kind < 2.5 ? 1.5 : 0.7))) + data.z);
	float lift = 0.0;
	if (kind < 0.5) {
		frame = 2.0 * (0.5 - 0.5 * cos(u * 6.2831));   // the hands apart, together, apart
	} else if (kind < 1.5) {
		// A jump: down into a crouch and up (on the floor), then the flight (a parabola, the height their own).
		float g = 0.38;
		if (u < g) {
			frame = 1.0 - sin(u / g * 3.14159);
		} else {
			float s = (u - g) / (1.0 - g);
			frame = 1.0 + sin(s * 3.14159);
			lift = 4.0 * s * (1.0 - s) * mix(0.18, 0.32, h2);
		}
	} else if (kind < 2.5) {
		frame = 2.0 * pow(sin(u * 3.14159), 0.7);   // the fist punched up, and down again
	} else {
		frame = 1.0 + sin(u * 6.2831);              // swaying from side to side
	}
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The side of them the camera sees, before the crowd's turn and after it (each turned partly toward the play,
	// some more than others), and how far through the turn they are: some turn sooner, some later.
	vec2 to_cam = normalize((CAMERA_POSITION_WORLD - world).xz);
	vec2 front = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xz);
	sides = vec4(seen(front, look_from.xz - world.xz, to_cam, h2), seen(front, look_to.xz - world.xz, to_cam, h2));
	pose = vec3(smoothstep(0.0, 1.0, clamp((turn - h1 * 0.6) / 0.4, 0.0, 1.0)), standing, cheer);
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + lift * cheer, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

// A threshold for each pixel (0-1, evenly spread over the screen), for dissolving one figure into another.
float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	// Each pixel from one of two figures (two sides of them as they turn, two frames, sitting or up), the share of
	// each as far as the turn or the movement has got: a dissolve.
	vec2 fc = FRAGCOORD.xy;
	vec2 now = step(dither(fc), pose.x) > 0.5 ? sides.zw : sides.xy;
	float view = now.x;
	float mirror = now.y;
	float up = step(dither(fc + vec2(5.0, 29.0)), pose.y);
	float cheering = up * step(dither(fc + vec2(23.0, 17.0)), pose.z);
	// (A frame held clean most of the time, dissolved into the next only on the way.)
	float f0 = min(floor(frame), 1.0);
	float fr = f0 + step(dither(fc + vec2(31.0, 3.0)), smoothstep(0.2, 0.8, frame - f0));
	float fig = floor(data.x * figs);
	float c = cheering > 0.5 ? 10.0 * figs + (fr * 5.0 + view) * figs * 0.5 + mod(fig, figs * 0.5)
		: (view + 5.0 * up) * figs + fig;
	vec2 at = vec2(mod(c, cols), floor(c / cols + 0.001));
	// (Kept a texel inside its cell, or the filtering picks up the edge of the one next to it; the mipmap chosen from
	// the cut-out's own UV, the same whichever cell a pixel takes.)
	vec2 in_cell = clamp(vec2(mix(UV.x, 1.0 - UV.x, mirror), UV.y), vec2(0.004), vec2(0.996));
	vec2 cell_size = vec2(1.0 / cols, 1.0 / 14.0);
	vec2 g = UV * cell_size;
	vec4 tex = textureGrad(sheet, (at + in_cell) * cell_size, dFdx(g), dFdy(g));
	if (tex.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.45) * 0.75;
	// The shirt is the part the sheet marks (alpha 0.7), white with its shading: dyed.
	float is_shirt = 1.0 - smoothstep(0.8, 0.9, tex.a);
	vec3 col = mix(tex.rgb, shirt * tex.r, is_shirt);
	ALBEDO = col * light;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat_hi = hi()
	_sheet_params()
	return _mat


## The sheet for this graphics level, and how it is laid out.
static func _sheet_params() -> void:
	var figs := FIGS_HI if _mat_hi else FIGS
	_mat.set_shader_parameter("sheet", sheet(_mat_hi))
	_mat.set_shader_parameter("figs", float(figs))
	_mat.set_shader_parameter("cols", float(cols(figs)))
	_mat.set_shader_parameter("cheers", PackedFloat32Array(CHEERS))


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
	_look_from = Vector3.ZERO
	_look_to = Vector3.ZERO
	_turn = 1.0
	material().set_shader_parameter("excite", 0.0)
	material().set_shader_parameter("excite_to", 0.0)
	material().set_shader_parameter("look_from", Vector3.ZERO)
	material().set_shader_parameter("look_to", Vector3.ZERO)
	material().set_shader_parameter("turn", 1.0)
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


## Flags held up here and there in the crowd (one in thirty), waving, harder when the crowd is up: a pole and a cloth
## each, all of them one draw call. Until show_teams says whose, two stripes of the home side's colours.
func _flags(rng: RandomNumberGenerator, keep: Array[Vector3], stands: Array, palette: Array) -> void:
	_flag_at.clear()
	for i in keep.size():
		if rng.randf() < 0.033:
			var feet: Vector3 = keep[i] - (Vector3.ZERO if stands[i] else Vector3(0, SEAT, 0))
			_flag_at.append(Transform3D(facing(keep[i]).rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)), feet + Vector3(0.18, 0, 0)))
	var img := Image.create_empty(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	img.fill(palette[0] if not palette.is_empty() else Game.C_SAFFRON)
	img.fill_rect(Rect2i(0, FLAG_H / 2, FLAG_W, FLAG_H / 2), palette[1] if palette.size() > 1 else Color.WHITE)
	_show_flags(img, img, 0.0)


## The flags in the crowd are the two teams' (their countries' flags, or a club's colours): most of them the home
## side's, a third the visitors'.
func show_teams(home: String, away: String) -> void:
	if not _flag_at.is_empty():
		_show_flags(team_flag(home), team_flag(away), 0.35)


## A team's flag as the crowd waves it: a country's own, or a club's colours (the first, with a sash of the second).
static func team_flag(id: String) -> Image:
	var t := DB.team(id)
	if t.get("kind", "") == "country":
		return Flags.image(id, FLAG_W, FLAG_H)
	var img := Image.create_empty(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	var c1: Color = t.get("c1", Game.C_SAFFRON)
	var c2: Color = t.get("c2", Color.WHITE)
	for y in FLAG_H:
		for x in FLAG_W:
			var d := float(y) / FLAG_H - (1.0 - float(x) / FLAG_W) * 0.9 - 0.05
			img.set_pixel(x, y, c2 if absf(d) < 0.16 else c1)
	return img


## The flags made: home's cloth on away_share of them, away's on the rest; the two side by side in one texture.
func _show_flags(home: Image, away: Image, away_share: float) -> void:
	if _flag_mi:
		_flag_mi.queue_free()
		_flag_mi = null
	if _flag_at.is_empty():
		return
	var both := Image.create_empty(FLAG_W * 2, FLAG_H, false, Image.FORMAT_RGBA8)
	for k in 2:
		var img: Image = (home if k == 0 else away).duplicate()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != Vector2i(FLAG_W, FLAG_H):
			img.resize(FLAG_W, FLAG_H, Image.INTERPOLATE_LANCZOS)
		both.blit_rect(img, Rect2i(0, 0, FLAG_W, FLAG_H), Vector2i(k * FLAG_W, 0))
	both.generate_mipmaps()
	_flag_material().set_shader_parameter("flags", ImageTexture.create_from_image(both))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _flag()
	mm.instance_count = _flag_at.size()
	for i in _flag_at.size():
		mm.set_instance_transform(i, _flag_at[i])
		# r: whose (0 home, 1 away), a: the wave's phase.
		mm.set_instance_custom_data(i, Color(1.0 if rng.randf() < away_share else 0.0, 0, 0, rng.randf()))
	_flag_mi = MultiMeshInstance3D.new()
	_flag_mi.multimesh = mm
	_flag_mi.material_override = _flag_material()
	_flag_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flag_mi)


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
uniform sampler2D flags : source_color, filter_linear_mipmap;   // the home side's flag, then the visitors'
uniform float excite = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float shade;
void vertex() {
	data = INSTANCE_CUSTOM;
	shade = 1.0;
	if (UV.x >= 0.0) {
		float ph = data.a * 6.2831;
		float w = TIME * (5.0 + 4.0 * excite) + ph - UV.x * 3.0;
		VERTEX.z += sin(w) * 0.16 * UV.x * (0.5 + excite);
		VERTEX.y -= 0.06 * UV.x * UV.x;
		shade = 0.86 + 0.14 * cos(w);   // the folds a little lighter and darker
	}
}
void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.02, 0.98) + data.r) * 0.5, 1.0 - UV.y);
	vec3 c = UV.x < 0.0 ? vec3(0.55) : texture(flags, uv).rgb * shade;
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
			material().set_shader_parameter("excite_to", _excite)
			_flag_material().set_shader_parameter("excite", _shown)
		_looking = _look if _looking.distance_to(_look) < 0.01 else _looking.lerp(_look, minf(1.0, delta * 3.0))
		# A turn done and the play moved on: the next.
		if _turn >= 1.0 and _looking.distance_to(_look_to) > TURN_STEP:
			_look_from = _look_to
			_look_to = _looking
			_turn = 0.0
			material().set_shader_parameter("look_from", _look_from)
			material().set_shader_parameter("look_to", _look_to)
		if _turn < 1.0:
			_turn = minf(1.0, _turn + delta / TURN_TIME)
			material().set_shader_parameter("turn", _turn)


static func set_excite(k: float) -> void:
	_excite = clampf(k, 0.0, 1.0)


## Where the play is (the ball, on the ground): the crowd turns partly toward it, following it a little late.
static func set_look(at: Vector3) -> void:
	_look = Vector3(at.x, 0.0, at.z)


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
	_flag_material().set_shader_parameter("light", k)
