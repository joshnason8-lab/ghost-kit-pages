class_name Arena
extends Node3D
## A floorball venue: the rink to the IFF's measurements (Rules 101-105) and the hall round it. A local sports hall
## (birch slats, one bank of seats behind the benches, high windows), a city arena (dark, stands all round with
## aisles, an LED ribbon round their fronts, a hanging scoreboard, light rigs) or a school gym (painted walls, wall
## bars, a few parents).
##
## The rink: the sports floor with its markings painted into one texture (lines 5 cm, the goal creases, the
## goalkeeper areas, the centre line and spot, the face-off dots), a grain and the overhead lights' sheen in its
## shader; white plastic boards in 2 m panels with rounded corners and plain advertising (the game's own name and
## slogans only); the two red goals with their nets; the teams' benches on the far side, the penalty benches and the
## secretariat on the near side.
##
## Everything static is merged by material (Geo) over one texture sheet (assets/crowd/venue_atlas.png, made by
## tools/crowd/make_venue.gd): opaque, glowing, cut-out and see-through, a draw call each, the floor one more, the crowd
## one and the bench's people one (Crowd).

const FLOOR_PX := 32.0        # floor texture pixels a metre (40 m x 20 m: 1280 x 640)
const SHEET := "res://assets/crowd/venue_atlas.png"
const SHEET_H := 768.0
## The sheet's strips: [top, height] in pixels (tools/crowd/make_venue.gd's STRIPS). Each is 1024 px along.
const STRIPS := {
	"plain": [0, 16], "board": [16, 64], "ads1": [80, 64], "ads2": [144, 64], "led": [208, 64], "seats": [272, 64],
	"slats": [336, 64], "panel": [400, 64], "parquet": [464, 48], "step": [512, 32], "windows": [544, 64],
	"score": [608, 64], "net": [672, 32], "truss": [704, 64],
}
const ROW_RISE := 0.42        # the stands: each row this much higher ...
const ROW_DEPTH := 0.8        # ... and this much further back
const SEAT := 0.5             # a seat's width

var venue := "hall"
var home_colors: Array = []
var away_colors: Array = []
var crowd: Crowd
var bench_crowd: Crowd
var _lit: Geo                 # opaque structure, lit
var _glow: Geo                # lamps, screens, LED boards, windows: unshaded
var _cut: Geo                 # cut-outs: roof trusses
var _see: Geo                 # see-through: the nets, plexiglass
var _low := false
var _lamps := {}              # the ceiling's lamps, for the floor's reflection of them

static var _floor_tex: ImageTexture
static var _net_tex: ImageTexture
static var _grain_tex: ImageTexture
static var _floor_shader: Shader


func _init(p_venue := "hall", p_home := [], p_away := []) -> void:
	venue = p_venue
	home_colors = p_home
	away_colors = p_away


static func s(name: String) -> Vector2:
	var a: Array = STRIPS[name]
	return Vector2(a[0] / SHEET_H, a[1] / SHEET_H)


func _ready() -> void:
	var v: Dictionary = DB.VENUES.get(venue, DB.VENUES.hall)
	_lit = Geo.new()
	_glow = Geo.new()
	_cut = Geo.new()
	_see = Geo.new()
	_low = int(Game.settings.graphics) == Game.GFX_LOW
	var spots: Array = []
	var walls := Color(String(v.walls))
	match String(v.stands):
		"bowl":
			_lamps = {"h": 12.5, "step": Vector2(6.5, 6.5), "n": Vector2i(6, 4), "size": Vector2(1.6, 0.9)}
			_hall_arena(walls, 34.0, 27.0, 16.0)
			var seat := Color("24508f")
			spots = _stands(-1, 14 if not _low else 11, seat, true)
			spots.append_array(_stands(1, 14 if not _low else 11, seat, true))
			spots.append_array(_end_stands(-1, 10 if not _low else 7, seat))
			spots.append_array(_end_stands(1, 10 if not _low else 7, seat))
			_scoreboard_cube()
			_trusses(34.0, 27.0, 14.5, 7)
		"side":
			_lamps = {"h": 9.6, "step": Vector2(8.0, 7.0), "n": Vector2i(5, 3), "size": Vector2(2.4, 0.5)}
			_hall_sports(walls, 27.0, 18.0, 10.0)
			spots = _stands(-1, 7, Color("1f6fb2"), false)
			_wall_bars(1, 27.0, 18.0)
		_:
			_lamps = {"h": 7.6, "step": Vector2(8.0, 6.0), "n": Vector2i(4, 2), "size": Vector2(2.0, 0.5)}
			_hall_school(walls, 24.0, 15.5, 8.0)
			spots = _stands(-1, 3, Color("c8ad7f"), false)
			_wall_bars(-1, 24.0, 15.5)
			_wall_bars(1, 24.0, 15.5)
	_env(venue, float(v.light))
	_floor()
	_boards()
	_goals()
	_benches()
	_ceiling_lights()
	var atlas: Texture2D = sheet()
	add_child(_lit.commit(Geo.sheet_material("lit", atlas, _low, int(Game.settings.graphics) >= Game.GFX_HIGH)))
	add_child(_glow.commit(Geo.sheet_material("glow", atlas)))
	add_child(_cut.commit(Geo.sheet_material("cut", atlas, _low)))
	var see := _see.commit(Geo.sheet_material("blend", atlas))
	add_child(see)
	crowd = Crowd.new()
	var palette: Array = home_colors.duplicate()
	palette.append_array(away_colors)
	crowd.build(spots, Game.crowd_density() * (1.0 if venue != "school" else 0.6), palette, hash(venue))
	add_child(crowd)
	# The stands sit in the hall's half light, the rink under the lamps.
	Crowd.set_light({"arena": 0.78, "hall": 0.95}.get(venue, 0.95) * clampf(float(v.light), 0.8, 1.1))


static func sheet() -> Texture2D:
	return load(SHEET)


# ---------------------------------------------------------------- light

func _env(kind: String, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101318") if kind == "arena" else Color("3a3d42")
	# A sports hall's light comes from everywhere above: the lamps, the pale ceiling, the floor's bounce. A sky made of
	# that (bright above, the walls' grey at the horizon, the blue floor below) gives the athletes' PBR materials
	# their soft fill and reflections; on Low a plain ambient colour does it more cheaply.
	if not _low:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.62, 0.65, 0.7)
		sky_mat.sky_horizon_color = Color(0.4, 0.4, 0.4) if kind != "arena" else Color(0.2, 0.21, 0.24)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
		sky_mat.ground_bottom_color = Color(0.13, 0.22, 0.36)
		sky_mat.sky_curve = 0.25
		sky_mat.ground_curve = 0.1
		sky_mat.sun_angle_max = 0.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		sky.process_mode = Sky.PROCESS_MODE_QUALITY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.42 if kind != "arena" else 0.38
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.74, 0.77, 0.82) if kind != "arena" else Color(0.62, 0.65, 0.72)
		env.ambient_light_energy = 0.62
	# Filmic on every level: in GL Compatibility it is a few instructions in the scene shader, and Low with the linear
	# curve showed the rink 40% darker than Medium and High (the playtest, docs/PLAYTEST.md). Exposed a touch up and
	# its white point lowered so whites stay white and the shadows open (no crushed blacks).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The lamps over the rink: a high, slightly cool key from above and a little toward the camera's side, so faces
	# and kits seen from the broadcast position are lit; shadows short and under the feet.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-66, 14, 0)
	# With its shadow on (High), GL Compatibility draws the light in a pass of its own that comes out much brighter
	# and more saturated (measured on the floor, tests/arena_look.tscn): turned down there so every level looks alike.
	sun.light_energy = 0.92 * energy * (0.45 if Game.shadows_enabled() else 1.0)
	sun.light_color = Color(0.97, 0.985, 1.0)
	sun.light_specular = 0.6
	sun.shadow_enabled = Game.shadows_enabled()
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# ---------------------------------------------------------------- the floor and its markings (102)

func _floor() -> void:
	# The hall's floor round the rink, then the rink's own sports floor with its markings.
	if venue == "arena":
		_lit.strip_quad(Vector3(-36, -0.01, -28), Vector3(36, -0.01, -28), Vector3(36, -0.01, 28), Vector3(-36, -0.01, 28),
			Vector3.UP, Color("6a6f78"), s("step"), Rect2(0, 0, 9, 28))
	else:
		var wood := Color("c9b08c") if venue == "hall" else Color("d6c09c")
		_lit.strip_quad(Vector3(-30, -0.01, -20), Vector3(30, -0.01, -20), Vector3(30, -0.01, 20), Vector3(-30, -0.01, 20),
			Vector3.UP, Color(wood, 0.55), s("parquet"), Rect2(0, 0, 7.5, 40))
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Rules.LENGTH, Rules.WIDTH)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = floor_shader()
	m.set_shader_parameter("marks", floor_texture())
	m.set_shader_parameter("grain", grain_texture())
	m.set_shader_parameter("lamp_h", float(_lamps.h))
	m.set_shader_parameter("lamp_step", _lamps.step)
	m.set_shader_parameter("lamp_n", Vector2(_lamps.n))
	m.set_shader_parameter("lamp_size", _lamps.size)
	m.set_shader_parameter("sheen", 0.55 if venue == "arena" else 0.42)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The sports floor: its markings' texture, a fine grain, a soft sheen, and the lamps above seen in it, blurred more
## the further the reflection travels (as on a real synthetic floor, roughness about 0.4).
static func floor_shader() -> Shader:
	if _floor_shader:
		return _floor_shader
	_floor_shader = Shader.new()
	_floor_shader.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D marks : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform float lamp_h = 10.0;
uniform vec2 lamp_step = vec2(8.0, 7.0);
uniform vec2 lamp_n = vec2(5.0, 3.0);
uniform vec2 lamp_size = vec2(2.4, 0.5);
uniform float sheen = 0.45;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 m = texture(marks, UV).rgb;
	float g = texture(grain, wpos.xz * 0.61).r * 0.65 + texture(grain, wpos.xz * 0.137 + 0.3).r * 0.35;
	float line = smoothstep(0.55, 0.8, m.b * m.r);      // the white paint, smoother and brighter
	ALBEDO = m * mix(0.8, 0.92, line) * (1.0 + (g - 0.5) * mix(0.18, 0.05, line));
	ROUGHNESS = mix(0.42 + (g - 0.5) * 0.1, 0.35, line);
	SPECULAR = 0.3;
	// The lamps' reflection: the eye's ray off the floor, up to the ceiling's lamps, the nearest one's soft rectangle.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 v = normalize(wpos - cam);
	vec3 r = reflect(v, vec3(0.0, 1.0, 0.0));
	float t = (lamp_h - wpos.y) / max(r.y, 0.06);
	vec2 hit = wpos.xz + r.xz * t;
	vec2 half_n = (lamp_n - 1.0) * 0.5;
	vec2 c = (clamp(floor(hit / lamp_step + half_n + 0.5), vec2(0.0), lamp_n - 1.0) - half_n) * lamp_step;
	vec2 d = abs(hit - c) - lamp_size * 0.5;
	float blur = 0.15 + t * 0.03;
	float k = (1.0 - smoothstep(-blur, blur, d.x)) * (1.0 - smoothstep(-blur, blur, d.y));
	// The glow round them, wide and faint, and Fresnel: stronger the lower the eye.
	vec2 dd = max(abs(hit) - (lamp_n * lamp_step * 0.5), vec2(0.0));
	float wide = exp(-dot(dd, dd) * 0.01) * 0.04;
	float fres = 0.3 + 0.7 * pow(1.0 - clamp(-v.y, 0.0, 1.0), 5.0);
	EMISSION = vec3(0.92, 0.95, 1.0) * (k * 1.1 + wide) * sheen * fres * (1.0 - line * 0.5);
}
"""
	return _floor_shader


## A fine, tiling grain for the flooring (sums of whole waves across the tile, so its edges meet).
static func grain_texture() -> ImageTexture:
	if _grain_tex:
		return _grain_tex
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var waves := []
	for i in 10:
		waves.append([rng.randi_range(1, 9), rng.randi_range(-9, 9), rng.randf() * TAU, rng.randf_range(0.4, 1.0)])
	for y in n:
		for x in n:
			var val := 0.0
			for w in waves:
				val += sin(TAU * (float(w[0]) * x + float(w[1]) * y) / n + w[2]) * w[3]
			val = val / 6.0 + (rng.randf() - 0.5) * 0.5
			img.set_pixel(x, y, Color(0.5 + val * 0.5, 0, 0))
	img.generate_mipmaps()
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


## The rink's floor: blue sports flooring with white markings, 4-5 cm lines (102), drawn once.
static func floor_texture() -> ImageTexture:
	if _floor_tex:
		return _floor_tex
	var w := int(Rules.LENGTH * FLOOR_PX)
	var h := int(Rules.WIDTH * FLOOR_PX)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var base := Color("2a62a8")
	img.fill(base)
	# The flooring's rolls, 2 m wide, welded: seams barely seen.
	for z in range(int(FLOOR_PX * 2.0), h, int(FLOOR_PX * 2.0)):
		img.fill_rect(Rect2i(0, z, w, 1), base.darkened(0.06))
	var line := Color("f4f6f8")
	var lw := maxi(2, int(round(0.05 * FLOOR_PX)))
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x + Rules.HALF_L) * FLOOR_PX), int((z + Rules.HALF_W) * FLOOR_PX))
	# Centre line and spot.
	var c0: Vector2i = to_px.call(0.0, -Rules.HALF_W)
	img.fill_rect(Rect2i(c0.x - lw / 2, 0, lw, h), line)
	_disc(img, to_px.call(0.0, 0.0), 0.12 * FLOOR_PX, line)
	for end: int in [-1, 1]:
		# The goal crease, 4 x 5 m (102.3), and the goalkeeper area, 1 x 2.5 m, its rear line the goal line (102.4).
		var cx0: float = minf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		var cx1: float = maxf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		_rect_outline(img, to_px.call(cx0, -Rules.CREASE_HALF_W), to_px.call(cx1, Rules.CREASE_HALF_W), lw, line)
		var gx0: float = minf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		var gx1: float = maxf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		_rect_outline(img, to_px.call(gx0, -Rules.GK_AREA_HALF_W), to_px.call(gx1, Rules.GK_AREA_HALF_W), lw, line)
		# The goal line between the posts: its marks.
		var gp: Vector2i = to_px.call(Rules.GOAL_LINE * end, 0.0)
		img.fill_rect(Rect2i(gp.x - lw / 2, int(gp.y - Rules.GOAL_W * 0.5 * FLOOR_PX), lw, int(Rules.GOAL_W * FLOOR_PX)), line)
	# The face-off dots: crosses, about 30 cm.
	for d in Rules.faceoff_dots().slice(1):
		var p: Vector2i = to_px.call(d.x, d.y)
		var arm := int(0.15 * FLOOR_PX)
		img.fill_rect(Rect2i(p.x - arm, p.y - lw / 2, arm * 2, lw), line)
		img.fill_rect(Rect2i(p.x - lw / 2, p.y - arm, lw, arm * 2), line)
	# Outside the rounded corners the boards stand: paint a dark grey there so nothing shows past them.
	var hall := Color("4a4f57")
	var r := Rules.CORNER_R * FLOOR_PX
	for sx: int in [0, 1]:
		for sz: int in [0, 1]:
			var cx := r if sx == 0 else w - r
			var cz := r if sz == 0 else h - r
			for yy in int(r) + 1:
				for xx in int(r) + 1:
					var px := int(cx - r + xx) if sx == 0 else int(cx + xx)
					var pz := int(cz - r + yy) if sz == 0 else int(cz + yy)
					if px < 0 or pz < 0 or px >= w or pz >= h:
						continue
					if Vector2(px + 0.5, pz + 0.5).distance_to(Vector2(cx, cz)) > r:
						img.set_pixel(px, pz, hall)
	img.generate_mipmaps()
	_floor_tex = ImageTexture.create_from_image(img)
	return _floor_tex


static func _rect_outline(img: Image, a: Vector2i, b: Vector2i, lw: int, col: Color) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	img.fill_rect(Rect2i(x0, y0, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y1 - lw, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y0, lw, y1 - y0), col)
	img.fill_rect(Rect2i(x1 - lw, y0, lw, y1 - y0), col)


static func _disc(img: Image, c: Vector2i, r: float, col: Color) -> void:
	for y in range(int(-r) - 1, int(r) + 2):
		for x in range(int(-r) - 1, int(r) + 2):
			if Vector2(x, y).length() <= r:
				img.set_pixel(clampi(c.x + x, 0, img.get_width() - 1), clampi(c.y + y, 0, img.get_height() - 1), col)


# ---------------------------------------------------------------- the boards (101)

## The rink's outline, inside face of the boards, as a closed polyline round the rounded corners.
static func outline(margin := 0.0, corner_seg := 8) -> Array:
	var pts := []
	var hx := Rules.HALF_L + margin
	var hz := Rules.HALF_W + margin
	var r := Rules.CORNER_R + margin
	var corners := [[Vector2(hx - r, hz - r), 0.0], [Vector2(-(hx - r), hz - r), PI * 0.5], [Vector2(-(hx - r), -(hz - r)), PI],
		[Vector2(hx - r, -(hz - r)), PI * 1.5]]
	for c in corners:
		for i in corner_seg + 1:
			var a: float = float(c[1]) + PI * 0.5 * float(i) / corner_seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## The boards as 2 m panels: the outline with its straight sides cut every 2 m.
static func _panels(margin: float) -> Array:
	var src := outline(margin, 8)
	var pts := []
	var n := src.size()
	for i in n:
		var a: Vector2 = src[i]
		var b: Vector2 = src[(i + 1) % n]
		var k := maxi(1, int(round(a.distance_to(b) / 2.0)))
		for j in k:
			pts.append(a.lerp(b, float(j) / k))
	return pts


func _boards() -> void:
	var inner := _panels(0.0)
	var outer := _panels(0.05)
	var h := Rules.BOARD_H
	var white := Color(0.97, 0.97, 0.98, 0.32)     # alpha: roughness, a plastic sheen
	var n := inner.size()
	var ad := 0
	for i in n:
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % n]
		var ao: Vector2 = outer[i]
		var bo: Vector2 = outer[(i + 1) % n]
		var len_ := a.distance_to(b)
		var mid := (a + b) * 0.5
		# A panel 2 m long on a straight side: some carry advertising; the rest white, as do the curved corners.
		var strip := s("board")
		var u0 := 0.0 if len_ > 1.5 else 0.1
		var uv := Rect2(u0, 0, len_ / 8.0, 1)
		if len_ > 1.5 and _ad_panel(mid):
			strip = s("ads1") if ad % 8 < 4 else s("ads2")
			uv = Rect2((ad % 4) * 0.25 + 0.002, 0, 0.246, 1)
			ad += 3
		_lit.face(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 0.0, h, Vector3.ZERO, Color(1, 1, 1, 0.32), strip, uv.position.x, uv.size.x)
		# The top's rounded edge and the back, white.
		_lit._tri_quad(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(bo.x, h, bo.y), Vector3(ao.x, h, ao.y), Vector3.UP, white)
		_lit.face(Vector3(ao.x, 0, ao.y), Vector3(bo.x, 0, bo.y), 0.0, h, Vector3(mid.x * 3.0, 0, mid.y * 3.0), Color(0.9, 0.9, 0.91, 0.4),
			s("board"), u0, len_ / 8.0)
	# The substitution zones' ends marked on the far board (104): dark bars on its face.
	for sx: int in [-1, 1]:
		for x: float in [Rules.SUB_ZONE_FROM_CENTRE, Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN]:
			var px := x * sx
			_lit._tri_quad(Vector3(px - 0.05, h, -Rules.HALF_W + 0.006), Vector3(px + 0.05, h, -Rules.HALF_W + 0.006),
				Vector3(px + 0.05, 0, -Rules.HALF_W + 0.006), Vector3(px - 0.05, 0, -Rules.HALF_W + 0.006), Vector3.BACK, Color("1f2933"))
	# The boards' feet behind them, every 2 m on the long sides.
	for side: int in [-1, 1]:
		for i in 17:
			var x := -16.0 + i * 2.0
			_lit.box(Vector3(x, 0.12, (Rules.HALF_W + 0.2) * side), Vector3(0.05, 0.24, 0.3), Color("c9ccd1"))


## Where a hall puts advertising on the boards: along the long sides and the ends, away from the corners and the far
## side's substitution zones (their boards stay white, the zones' ends marked).
func _ad_panel(p: Vector2) -> bool:
	if absf(p.x) > Rules.HALF_L - 1.0:
		return absf(p.y) < 6.0
	if absf(p.x) > Rules.HALF_L - Rules.CORNER_R - 0.5:
		return false
	if p.y < 0.0 and absf(p.x) > Rules.SUB_ZONE_FROM_CENTRE - 0.5 and absf(p.x) < Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN + 0.5:
		return false
	return true


# ---------------------------------------------------------------- the goals (103)

func _goals() -> void:
	var red := Color(0.82, 0.1, 0.14, 0.3)
	var r := 0.024
	var seg := 6 if _low else 10
	for end: int in [-1, 1]:
		var x := Rules.GOAL_LINE * end
		var back := x + Rules.GOAL_D * end
		var hw := Rules.GOAL_W * 0.5
		var gh := Rules.GOAL_H
		var pl := Vector3(x, 0, -hw)
		var pr := Vector3(x, 0, hw)
		# Posts and crossbar, the bottom frame round the back, the back's sloping supports.
		_lit.cylinder(pl, pl + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pr, pr + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), pr + Vector3(0, gh, 0), r, r, red, seg, false)
		_lit.cylinder(pl, Vector3(back, 0, -hw), r, r, red, 6, false)
		_lit.cylinder(pr, Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(Vector3(back, 0, -hw), Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), Vector3(back, 0.12, -hw), r * 0.8, r * 0.8, red, 6, false)
		_lit.cylinder(pr + Vector3(0, gh, 0), Vector3(back, 0.12, hw), r * 0.8, r * 0.8, red, 6, false)
		# The net: the back slope and the two sides, a 4 cm white mesh, seen through.
		var top_l := pl + Vector3(0, gh, 0)
		var top_r := pr + Vector3(0, gh, 0)
		var bl := Vector3(back, 0, -hw)
		var br := Vector3(back, 0, hw)
		var slope := top_l.distance_to(bl)
		var quads := [[top_l, top_r, br, bl, Rules.GOAL_W, slope], [top_l, bl, pl, pl, Rules.GOAL_D, gh], [top_r, pr, br, br, gh, Rules.GOAL_D]]
		for quad in quads:
			var nn = ((quad[1] - quad[0]).cross(quad[2] - quad[0])).normalized()
			_see.strip_quad(quad[0], quad[1], quad[2], quad[3], nn, Color(0.97, 0.97, 0.97, 0.95), s("net"),
				Rect2(0, 0, float(quad[4]) / 1.28, float(quad[5]) / 0.04))


## The old net's texture, kept for callers that warm it up at load (the net is now a strip of the venue's sheet).
static func net_texture() -> ImageTexture:
	if _net_tex:
		return _net_tex
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_net_tex = ImageTexture.create_from_image(img)
	return _net_tex


# ---------------------------------------------------------------- benches, penalty benches, secretariat (104, 105)

## A bench: a plank of moulded seats on legs, their backs behind (a strip of seats toward the rink, plain behind), a
## plexiglass panel behind that on posts; seats_col the seats', people sit on it. facing: -1 the far side's, 1 the near.
func _bench(cx: float, z: float, length: float, facing: int, seats_col: Color, back_h: float) -> void:
	var seat_y := 0.44
	var x0 := cx - length * 0.5
	var x1 := cx + length * 0.5
	_lit.box(Vector3(cx, seat_y, z), Vector3(length, 0.05, 0.42), Color(seats_col, 0.5))
	var legs := maxi(2, int(length / 2.0) + 1)
	for k in legs:
		var lx := lerpf(x0 + 0.1, x1 - 0.1, float(k) / (legs - 1))
		_lit.box(Vector3(lx, seat_y * 0.5, z), Vector3(0.05, seat_y, 0.3), Color("3a3f47"))
	var zb := z + 0.2 * facing
	var rink := Vector3(cx, 0, z - facing * 5.0)
	_lit.face(Vector3(x0, 0, zb - 0.02 * facing), Vector3(x1, 0, zb - 0.02 * facing), seat_y, seat_y + 0.4, rink,
		Color(seats_col, 0.5), s("seats"), 0.0, length / 4.0)
	_lit.face(Vector3(x0, 0, zb), Vector3(x1, 0, zb), seat_y, seat_y + 0.4, Vector3(cx, 0, z + facing * 5.0), Color(seats_col.darkened(0.3), 0.6))
	_lit.flat(x0, zb - 0.02 * facing, x1, zb, seat_y + 0.4, Color(seats_col, 0.6))
	# The back panel (plexiglass on its posts).
	if back_h > 0.0:
		var zp := z + 0.38 * facing
		_see.face(Vector3(x0, 0, zp), Vector3(x1, 0, zp), 0.0, back_h, rink, Color(0.82, 0.9, 0.95, 0.16))
		for k in 2:
			_lit.box(Vector3(x0 if k == 0 else x1, back_h * 0.5, zp), Vector3(0.05, back_h, 0.05), Color("8d939b", 0.4))
		_lit.box(Vector3(cx, back_h, zp), Vector3(length, 0.04, 0.05), Color("8d939b", 0.4))


func _benches() -> void:
	# The teams' benches behind their substitution zones on the far side, the substitutes on them.
	var spots: Array = []
	for side: int in [-1, 1]:
		var x0: float = Rules.SUB_ZONE_FROM_CENTRE * side
		var x1: float = (Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN) * side
		var cx := (x0 + x1) * 0.5
		var team: Color = (home_colors[0] if side < 0 else away_colors[0]) if not home_colors.is_empty() and not away_colors.is_empty() else Color("3b4552")
		_bench(cx, -Rules.HALF_W - 2.4, Rules.SUB_ZONE_LEN, -1, team.darkened(0.25), 1.0)
		for i in 10:
			spots.append(Vector3(cx - Rules.SUB_ZONE_LEN * 0.45 + i * Rules.SUB_ZONE_LEN * 0.9 / 9.0, 0.0, -Rules.HALF_W - 2.15))
	# The penalty benches (2 m each, at least 1 m from the centre line) and the secretariat between them, near side:
	# low, so they keep to the bottom of the picture as before.
	for side: int in [-1, 1]:
		_bench(side * 2.2, Rules.HALF_W + 1.3, 2.0, 1, Color("3b4552"), 0.95)
		# Plexiglass ends to the penalty bench.
		for e: int in [-1, 1]:
			var ex := side * 2.2 + e * 1.0
			_see._tri_quad(Vector3(ex, 0.95, Rules.HALF_W + 0.15), Vector3(ex, 0.95, Rules.HALF_W + 1.7),
				Vector3(ex, 0.0, Rules.HALF_W + 1.7), Vector3(ex, 0.0, Rules.HALF_W + 0.15), Vector3(-e, 0, 0), Color(0.82, 0.9, 0.95, 0.12))
	# The secretariat: a table with a white top and a skirt with the game's name toward the rink, two chairs, laptops.
	var tz := Rules.HALF_W + 1.5
	_lit.box(Vector3(0, 0.76, tz), Vector3(1.8, 0.04, 0.75), Color(0.95, 0.95, 0.96, 0.5))
	_lit.face(Vector3(-0.9, 0, tz - 0.36), Vector3(0.9, 0, tz - 0.36), 0.05, 0.74, Vector3.ZERO, Color(1, 1, 1, 0.5), s("ads1"), 0.0, 0.25)
	_lit.face(Vector3(-0.9, 0, tz + 0.36), Vector3(0.9, 0, tz + 0.36), 0.05, 0.74, Vector3(0, 0, 30), Color(0.17, 0.19, 0.22, 0.6))
	for k: int in [-1, 1]:
		_lit.box(Vector3(k * 0.88, 0.37, tz), Vector3(0.04, 0.74, 0.7), Color("dfe2e6"))
		_lit.box(Vector3(k * 0.42, 0.45, tz + 0.55), Vector3(0.42, 0.05, 0.4), Color("596273"))
		_lit.box(Vector3(k * 0.42, 0.7, tz + 0.74), Vector3(0.42, 0.45, 0.04), Color("596273"))
		_lit.box(Vector3(k * 0.42, 0.21, tz + 0.55), Vector3(0.05, 0.42, 0.05), Color("8d939b"))
		_lit.box(Vector3(k * 0.42, 0.79, tz + 0.05), Vector3(0.3, 0.02, 0.2), Color("4a4f57", 0.4))
		_lit.box(Vector3(k * 0.42, 0.88, tz + 0.15), Vector3(0.3, 0.18, 0.015), Color("3a3f47", 0.4))
	bench_crowd = Crowd.new()
	var pal: Array = [home_colors[0] if not home_colors.is_empty() else Color.WHITE, away_colors[0] if not away_colors.is_empty() else Color.WHITE]
	bench_crowd.build(spots, 0.7, pal, 9, 1.0)
	add_child(bench_crowd)


# ---------------------------------------------------------------- the hall

func _walls(half_x: float, half_z: float, h: float, bands: Array) -> void:
	# Each band: [y0, y1, colour, strip, metres a repeat along, metres a repeat up]; round all four walls.
	var corners := [Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := (b - a).cross(Vector3.UP).normalized()
		var len_ := a.distance_to(b)
		for band in bands:
			var y0: float = band[0]
			var y1: float = band[1]
			var target: Array = [_glow] if band.size() > 6 and band[6] else [_lit]
			(target[0] as Geo).strip_quad(Vector3(a.x, y1, a.z), Vector3(b.x, y1, b.z), Vector3(b.x, y0, b.z), Vector3(a.x, y0, a.z), n,
				band[2], s(band[3]), Rect2(0, 0, len_ / float(band[4]), (y1 - y0) / float(band[5])))
	_lit._tri_quad(Vector3(-half_x, h, half_z), Vector3(half_x, h, half_z), Vector3(half_x, h, -half_z), Vector3(-half_x, h, -half_z), Vector3.DOWN, Color("3a3f47"))


func _hall_arena(walls: Color, half_x: float, half_z: float, h: float) -> void:
	# Behind the top rows: a concourse wall, the glass fronts of the hospitality boxes lit warm, the LED ribbon, the
	# roof's dark steel.
	walls = walls.lerp(Color("5a616c"), 0.75)
	_walls(half_x, half_z, h, [[0, 5.8, walls, "panel", 8.0, 1.6], [5.8, 7.6, Color(1.0, 0.86, 0.66), "windows", 6.0, 1.8, true],
		[7.6, 8.5, walls.darkened(0.2), "panel", 8.0, 0.9], [8.5, 9.3, Color(0.6, 0.62, 0.66), "led", 16.0, 0.8, true],
		[9.3, h, walls.darkened(0.3), "panel", 8.0, 3.0]])


func _hall_sports(walls: Color, half_x: float, half_z: float, h: float) -> void:
	# Birch slats to 4.5 m (ball-proof), pale acoustic panels above, a band of high windows under the roof.
	_walls(half_x, half_z, h, [[0, 4.5, walls, "slats", 8.0, 2.25], [4.5, 8.0, Color("e4e1da"), "panel", 8.0, 3.5],
		[8.0, 9.4, Color(0.9, 0.92, 0.95), "windows", 8.0, 1.4, true], [9.4, h, Color("e4e1da"), "panel", 8.0, 0.6]])
	# A scoreboard on each end wall.
	for e: int in [-1, 1]:
		var x := (half_x - 0.05) * e
		_lit.box(Vector3(x - 0.1 * e, 5.8, 0), Vector3(0.2, 1.4, 4.2), Color("15181d"))
		_glow.face(Vector3(x - 0.21 * e, 0, -1.9), Vector3(x - 0.21 * e, 0, 1.9), 5.2, 6.4, Vector3.ZERO, Color.WHITE, s("score"), 0.0, 0.5)


func _hall_school(walls: Color, half_x: float, half_z: float, h: float) -> void:
	_walls(half_x, half_z, h, [[0, 1.4, walls.darkened(0.2), "panel", 4.0, 1.4], [1.4, 6.6, walls, "panel", 8.0, 5.2],
		[6.6, 7.6, Color(0.9, 0.92, 0.95), "windows", 8.0, 1.0, true], [7.6, h, walls, "panel", 8.0, 0.4]])
	# Basketball boards at the ends.
	for e: int in [-1, 1]:
		var x := (half_x - 1.2) * e
		_lit.box(Vector3(x, 3.4, 0), Vector3(0.04, 1.05, 1.8), Color(0.97, 0.97, 0.97, 0.4))
		_lit.box(Vector3(x + 0.6 * e, 3.4, 0), Vector3(1.2, 0.08, 0.08), Color("6b7078"))
		_lit.cylinder(Vector3(x - 0.25 * e, 3.05, -0.23), Vector3(x - 0.25 * e, 3.05, 0.23), 0.012, 0.012, Color("e0582a"), 4, false)


## Rows of seats along a long side (side -1: the far side, behind the benches; 1: the near side), rising; aisles
## between sections. Each row: the step's front, its tread, the seats' backs at its back (people in front of them).
## Returns where people sit.
func _stands(side: int, rows: int, seat: Color, fascia: bool) -> Array:
	var spots: Array = []
	# The near side's stand stands back behind the camera's gantry, out of the broadcast picture (the penalty benches
	# and the secretariat at its foot); the far side's begins behind the teams' benches.
	var z0 := (Rules.HALF_W + (3.6 if side < 0 else 6.2)) * side
	var y_front := 1.0 if fascia else 0.0
	var half := 15.0
	var aisles := [-7.5, 0.0, 7.5] if fascia else [0.0]
	var concrete := Color("8a8d92") if fascia else Color("c8ad7f")
	var rink := Vector3(0, 0, 0)
	if fascia:
		# The stand's front: a wall with an LED ribbon round it, a glass rail on top.
		var zf := z0 - side * ROW_DEPTH * 0.5
		var l := Vector3(-half, 0, zf)
		var r := Vector3(half, 0, zf)
		_glow.face(l, r, 0.25, y_front - 0.05, rink, Color.WHITE, s("led"), 0.0, 30.0 / 8.0)
		_lit.face(l, r, 0.0, 0.25, rink, Color("1b1e23"))
		_see.face(l, r, y_front - 0.05, y_front + 0.85, rink, Color(0.8, 0.88, 0.95, 0.12))
	for r in rows:
		var zc := z0 + side * r * ROW_DEPTH
		var zf := zc - side * ROW_DEPTH * 0.5
		var zb := zc + side * ROW_DEPTH * 0.5
		var y := y_front + 0.45 + r * ROW_RISE
		var y_prev := y - ROW_RISE if r > 0 else 0.0
		# Riser and tread, the whole length.
		_lit.face(Vector3(-half, 0, zf), Vector3(half, 0, zf), y_prev, y, rink, concrete.darkened(0.25), s("step"), 0.0, 4.0, 0.5)
		_lit.flat(-half, zf, half, zb, y, concrete, s("step"), 4.0, 0.5)
		# Seats in sections between the aisles.
		var edges := [-half]
		for a in aisles:
			edges.append(a - 0.5)
			edges.append(a + 0.5)
		edges.append(half)
		for k in range(0, edges.size(), 2):
			var xa: float = edges[k]
			var xb: float = edges[k + 1]
			var zs := zb - side * 0.12
			_lit.face(Vector3(xa, 0, zs), Vector3(xb, 0, zs), y, y + 0.45, rink, Color(seat, 0.55), s("seats"),
				(xa + 40.0) / 4.0 if side < 0 else (40.0 - xb) / 4.0, (xb - xa) / 4.0)
			var x := xa + SEAT * 0.5
			while x < xb - SEAT * 0.25:
				spots.append(Vector3(x, y, zc + side * 0.12))
				x += SEAT
		# The row's end, seen at the corners.
		for e: int in [-1, 1]:
			_lit.face(Vector3(half * e, 0, zf), Vector3(half * e, 0, zb), 0.0, y, Vector3(half * e * 2.0, 0, zc), concrete.darkened(0.35))
	return spots


func _end_stands(end: int, rows: int, seat: Color) -> Array:
	var spots: Array = []
	var x0 := (Rules.HALF_L + 3.0) * end
	var half := 11.0
	var concrete := Color("8a8d92")
	var rink := Vector3.ZERO
	var xf0 := x0 - end * ROW_DEPTH * 0.5
	_glow.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.25, 0.95, rink, Color.WHITE, s("led"), 0.3, 22.0 / 8.0)
	_lit.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.0, 0.25, rink, Color("1b1e23"))
	_see.face(Vector3(xf0, 0, -half), Vector3(xf0, 0, half), 0.95, 1.85, rink, Color(0.8, 0.88, 0.95, 0.12))
	for r in rows:
		var xc := x0 + end * r * ROW_DEPTH
		var xf := xc - end * ROW_DEPTH * 0.5
		var xb := xc + end * ROW_DEPTH * 0.5
		var y := 1.0 + 0.45 + r * ROW_RISE
		var y_prev := y - ROW_RISE if r > 0 else 0.0
		_lit.face(Vector3(xf, 0, -half), Vector3(xf, 0, half), y_prev, y, rink, concrete.darkened(0.25), s("step"), 0.0, 3.0, 0.5)
		_lit.flat(xf, -half, xb, half, y, concrete, s("step"), 3.0, 0.5)
		var xs := xb - end * 0.12
		for sec: Array in [[-half, -0.5], [0.5, half]]:
			var za: float = sec[0]
			var zb: float = sec[1]
			_lit.face(Vector3(xs, 0, za), Vector3(xs, 0, zb), y, y + 0.45, rink, Color(seat, 0.55), s("seats"), 0.0, (zb - za) / 4.0)
			var z := za + SEAT * 0.5
			while z < zb - SEAT * 0.25:
				spots.append(Vector3(xc + end * 0.12, y, z))
				z += SEAT
		for e: int in [-1, 1]:
			_lit.face(Vector3(xf, 0, half * e), Vector3(xb, 0, half * e), 0.0, y, Vector3(xc, 0, half * e * 2.0), concrete.darkened(0.35))
	return spots


func _wall_bars(side: int, half_x: float, half_z: float) -> void:
	# A school's (or a hall's) wall bars along a long wall.
	var z := (half_z - 0.12) * side
	var count := 12 if venue == "school" else 8
	for i in count:
		var x := -float(count) * 1.2 + i * 2.4
		for k in 2:
			_lit.box(Vector3(x + k * 0.9, 1.4, z), Vector3(0.06, 2.8, 0.06), Color("b08a56", 0.5))
		for j in 9:
			_lit.box(Vector3(x + 0.45, 0.2 + j * 0.3, z), Vector3(0.9, 0.04, 0.04), Color("c49a62", 0.5))


## Roof trusses across the hall's far half, the lamps hung between them (only the far half: the broadcast and high
## cameras stand above the near half, where trusses would cross the picture).
func _trusses(half_x: float, half_z: float, y: float, n: int) -> void:
	for i in n:
		var x := -half_x + (i + 1) * 2.0 * half_x / (n + 1)
		_cut.strip_quad(Vector3(x, y, -half_z), Vector3(x, y, -6.0), Vector3(x, y - 1.6, -6.0), Vector3(x, y - 1.6, -half_z),
			Vector3.RIGHT, Color("9aa0a8"), s("truss"), Rect2(0, 0, (half_z - 6.0) / 8.0, 1))


func _ceiling_lights() -> void:
	var h: float = _lamps.h
	var st: Vector2 = _lamps.step
	var n: Vector2i = _lamps.n
	var sz: Vector2 = _lamps.size
	for i in n.x:
		for k in n.y:
			var x := (i - (n.x - 1) * 0.5) * st.x
			var z := (k - (n.y - 1) * 0.5) * st.y
			_glow.flat(x - sz.x * 0.5, z - sz.y * 0.5, x + sz.x * 0.5, z + sz.y * 0.5, h, Color(1, 0.99, 0.95), Vector2(-1, 0), 1, 1, true)


func _scoreboard_cube() -> void:
	_lit.box(Vector3(0, 11.5, 0), Vector3(4.0, 2.2, 4.0), Color("15181d"))
	for k in 4:
		var a := k * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		var c := out * 2.02
		var right := Vector3(cos(a), 0, -sin(a)) * 1.8
		_glow.face(c - right, c + right, 10.7, 12.3, c + out, Color.WHITE, s("score"), 0.0, 0.5)
