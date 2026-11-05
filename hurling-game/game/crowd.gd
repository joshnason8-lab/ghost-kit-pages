class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one sheet of people, every one an instance of the same quad, so a stand of
## thousands is one draw call. The sheet is rendered from the maker's own models (two fans made with Meshy, in four
## poses each: tools/crowd/render_fans.gd), head to waist, from the front and from behind. Each person faces the pitch
## (their instance's +Z, toward the centre of the field); the shader turns the cut-out to the camera so it is never
## seen edge-on, and draws the person from the front when the camera is in front of them, from behind (the back of
## the head, no face) when it is behind them, as the television camera is behind the near stand. It picks the figure
## and shirt (the sheet's mask says where the shirt is), and makes them fidget, and get up and cheer when the crowd
## goes up (excite): on Medium and High their arms go up and wave, or a fist pumps, each at their own pace (the
## sheet's cheering frames, eased between). (Round five: "upgrade the look of the fans, they just look like shapes".)

const FIGS := 8          # figures across the sheet, each drawn twice: from the front, then (FIGS more) from behind
const FIG_W := 64
const FIG_H := 128
const SHEET := "res://assets/crowd/sheet.png"
const MASK := "res://assets/crowd/mask.png"
## Medium and High: all six fans, 24 figures at twice the size, the front in the top row and the back below
## (sheet_hd.png, tools/crowd/render_fans.gd hd).
const FIGS_HD := 24

static var _sheets := {}         # Medium or High (true) or Low -> [sheet, mask]
static var _mats := {}

var spots: Array[Vector3] = []   # where people stand or sit (their feet)
var facings: Array[Vector3] = [] # the way each faces: toward the centre of the field, flat


static func _hd() -> bool:
	return int(Game.settings.graphics) > Game.GFX_LOW and ResourceLoader.exists(Game.hd(SHEET))


## The sheet's level: "ultra" (the HD pack's, the 24 figures at 256 x 512), true (Medium and High) or false (Low).
static func _level() -> Variant:
	return "ultra" if Ultra.active() else _hd()


## The sheet: on Low eight people from the front, then the same eight from behind, in one row; on Medium and High
## twenty-four, front above and back below (and its shirt mask).
static func sheet() -> Texture2D:
	var hd: Variant = _level()
	if not _sheets.has(hd):
		if hd is String:
			_sheets[hd] = [load("res://ultra/crowd/sheet.png"), load("res://ultra/crowd/mask.png")]
		else:
			_sheets[hd] = [load(Game.hd(SHEET) if hd else SHEET), load(Game.hd(MASK) if hd else MASK)]
	return _sheets[hd][0]


static func material() -> ShaderMaterial:
	var hd: Variant = _level()
	if _mats.has(hd):
		return _mats[hd]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform float figs = 8.0;
uniform bool rows = false;     // the sheet in rows (front, back), not one
uniform bool cheers = false;   // and two more rows: each fan cheering (render_fans.gd: CHEER)
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float back;
varying float cheer;     // how far into cheering this one is (0-1)
varying float wave;      // between the two frames of the cheer (0-1)
void vertex() {
	data = INSTANCE_CUSTOM;
	float ph = data.z * 6.2831;
	// Excited, each one up off the seat a little (some more than others), then bobbing and swaying at their own
	// pace, smoothly: no hopping in step (the owner: "no quick up/down animations that looks corny").
	float own = fract(data.z * 13.7);
	float rate = 1.5 + own * 0.9;
	float rise = excite * (0.06 + own * 0.08);
	float bob = (0.5 - 0.5 * cos(time_s * rate * 6.2831 + ph)) * excite * (0.05 + own * 0.05);
	float jump = rise + bob;
	float fidget = sin(time_s * 1.3 + ph) * 0.02 + sin(time_s * rate * 3.1416 + ph * 1.7) * 0.05 * excite;
	// And the arms: each comes up into a cheer as the crowd goes past their own point (not all at once), waving at
	// their own pace, eased between the two frames so it moves smoothly.
	float from = 0.12 + own * 0.4;
	cheer = cheers ? smoothstep(from, from + 0.18, excite) : 0.0;
	wave = 0.5 - 0.5 * cos(time_s * (2.4 + own * 2.2) + ph * 3.0);
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// The person faces their instance's +Z (the pitch); seen from behind, draw them from behind (Crowd.seen_from_behind).
	vec3 facing = normalize(vec3(MODEL_MATRIX[2].x, 0.0, MODEL_MATRIX[2].z));
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	back = dot(facing, vec3(to_cam.x, 0.0, to_cam.z)) < 0.0 ? 1.0 : 0.0;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
vec2 cell(vec2 p, float fig, float row) {
	float n = cheers ? 4.0 : 2.0;
	return rows ? vec2((p.x + fig) / figs, (p.y + row) / n)
		: vec2((p.x + fig + row * figs) / (figs * 2.0), p.y);
}
void fragment() {
	float fig = floor(data.x * figs);
	vec2 uv = cell(UV, fig, back);
	vec4 c = texture(sheet, uv);
	float m = texture(mask, uv).r;
	if (cheer > 0.001) {
		// The same fan's cheer (four frames a fan, two pairs: both arms waving, or a fist pumped).
		float base = floor(fig / 4.0) * 4.0 + (fract(data.z * 7.31) < 0.6 ? 0.0 : 2.0);
		vec2 u0 = cell(UV, base, back + 2.0);
		vec2 u1 = cell(UV, base + 1.0, back + 2.0);
		vec4 c0 = texture(sheet, u0);
		vec4 c1 = texture(sheet, u1);
		// Blended with the alpha taken in (so a raised arm fades across, never a ghost of colour round it).
		vec4 cw = vec4(mix(c0.rgb * c0.a, c1.rgb * c1.a, wave), mix(c0.a, c1.a, wave));
		float mw = mix(texture(mask, u0).r, texture(mask, u1).r, wave);
		vec4 all_ = vec4(mix(c.rgb * c.a, cw.rgb, cheer), mix(c.a, cw.a, cheer));
		c = vec4(all_.rgb / max(all_.a, 0.001), all_.a);
		m = mix(m, mw, cheer);
	}
	if (c.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3) * 0.9;
	// The shirt is white on the sheet: its shading kept, its colour each person's.
	float is_shirt = smoothstep(0.3, 0.7, m);
	float shade = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.86;
	vec3 col = mix(c.rgb, shirt * shade, is_shirt);
	// (w: the seat's baked light; 0 - none given - is open.)
	ALBEDO = compat_to_scene(pow(col, vec3(2.2)) * light * (data.w > 0.0 ? data.w : 1.0));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var tex := sheet()
	var figs := float(FIGS if hd is bool and not hd else FIGS_HD)
	m.set_shader_parameter("sheet", tex)
	m.set_shader_parameter("mask", _sheets[hd][1])
	m.set_shader_parameter("figs", figs)
	m.set_shader_parameter("rows", not (hd is bool and not hd))
	m.set_shader_parameter("cheers", tall())
	_mats[hd] = m
	return m


## The sheet's cells are the tall ones, with the cheering rows (render_fans.gd hd and ultra; an HD pack fetched before
## them has the shorter two-row sheet, drawn as it was).
static func tall() -> bool:
	var hd: Variant = _level()
	if hd is bool and not hd:
		return false
	var tex := sheet()
	return float(tex.get_height()) / (float(tex.get_width()) / FIGS_HD) > 6.0


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours). With
## away too (a championship day at a county ground or the stadium), most wear one county's colours or the other's,
## in sections of the stand that lean one way, as at Croke Park: share of them in county colours, the rest anything.
## colours: a shirt a spot instead (Stadium._shirts: the same as the 3D fans', so a fan keeps theirs between the two);
## lights: a number a spot, the seat's baked light (under a roof, darker).
func build(p_spots: Array, density: float, palette: Array, seed_ := 1, away: Array = [], share := 0.45, colours: Array = [],
		lights: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	var kept := []
	for i in p_spots.size():
		if rng.randf() < density:
			keep.append(p_spots[i])
			kept.append(i)
	spots = keep
	facings = []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.52, 1.04)
	q.center_offset = Vector3(0, 0.52, 0)
	if tall():
		# The taller cells (room for the arms up): the head where it was, 0.21 m more above it.
		q.size = Vector2(0.6, 1.5)
		q.center_offset = Vector3(0, 0.54, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		var f := facing_at(keep[i])
		facings.append(f)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(f.x, f.z)), keep[i]))
		var col := Color(rng.randf(), rng.randf(), rng.randf())
		if not palette.is_empty() and rng.randf() < share:
			var pal := palette
			if not away.is_empty():
				# The section (about 12 m of stand): leaning home or away; most in it follow, a few the others.
				var sec := hash(Vector2i(floori(keep[i].x / 12.0), floori(keep[i].z / 10.0)))
				var home_side := (sec % 100) < 50
				pal = palette if (rng.randf() < 0.8) == home_side else away
			col = pal[rng.randi_range(0, pal.size() - 1)]
		if kept[i] < colours.size():
			col = colours[kept[i]]
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase, w: the seat's light.
		var li := float(lights[kept[i]]) if kept[i] < lights.size() else 1.0
		mm.set_instance_custom_data(i, Color(rng.randf(), WsgCrowd3D.shirt_code(col), rng.randf(), li))
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


func _process(delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	# The crowd's excitement eased toward what the play asks: up over about half a second, down over two.
	var k := 1.0 - exp(-delta * (5.0 if _want > _now else 1.4))
	_now = lerpf(_now, _want, k)
	material().set_shader_parameter("excite", _now)


static var _want := 0.0
static var _now := 0.0


## How excited the crowd should be (0-1); it gets there smoothly (_process).
static func set_excite(k: float) -> void:
	_want = clampf(k, 0.0, 1.0)
	WsgCrowd3D.set_excite(k)


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
	WsgCrowd3D.set_light(k)
