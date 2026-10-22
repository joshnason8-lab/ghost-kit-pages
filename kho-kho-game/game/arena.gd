class_name Arena
extends Node3D
## A venue: the field marked out to the rule book's measurements (KhoRules.field) and, round it, one of four places
## kho kho is played: a village ground of beaten earth at dusk, a school ground by day, an indoor arena on mats as the
## fast game is played, and a floodlit stadium of red earth at night. The officials' table and the teams' benches are
## on the far side line, as at a championship; the broadcast camera looks across from the near one.
## Built from merged, vertex-coloured parts (Geo): the ground, the structure, and the lines and lights that glow are
## three draw calls; the crowd one more (Crowd). Low graphics leaves out the small things.

var venue := "maidan"
var fmt := KhoRules.CLASSIC
var f := {}
var crowd: Crowd
var home_colors: Array = []
var _lit: Geo
var _glow: Geo
var _ground: Geo


func _init(p_venue := "maidan", p_fmt := KhoRules.CLASSIC, p_home_colors := []) -> void:
	venue = p_venue
	fmt = p_fmt
	home_colors = p_home_colors
	f = KhoRules.field(fmt)


func surface() -> String:
	return String(DB.venue(venue)[2])


func time_of_day() -> String:
	return String(DB.venue(venue)[3])


func _ready() -> void:
	_lit = Geo.new()
	_glow = Geo.new()
	_ground = Geo.new()
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var kind := String(DB.venue(venue)[4])
	_field()
	_poles()
	_table()
	var spots: Array = []
	match kind:
		"village":
			_env(Color("2a2140"), Color("d27a4e"), Color(0.75, 0.62, 0.62), 0.9, Vector3(-30, -35, 0), Color(1.0, 0.82, 0.62))
			spots = _ground_crowd(low)
			_hills(Color("3e5a3a"), Color("c98a6a"))
			_trees(22 if not low else 10, 24.0, 38.0, true)
			_huts()
			_string_lights(low)
		"school":
			_env(Color("6ea7e0"), Color("dbe8f0"), Color(0.8, 0.82, 0.86), 1.1, Vector3(-55, 30, 0), Color(1.0, 0.97, 0.9))
			spots = _ground_crowd(low, true)
			_hills(Color("4f6e4a"), Color("b9d2e6"))
			_school()
			_trees(16 if not low else 7, 26.0, 40.0)
		"arena":
			_env(Color("0c0f18"), Color("1a2030"), Color(0.62, 0.64, 0.72), 1.0, Vector3(-65, 20, 0), Color(1.0, 0.98, 0.95))
			spots = _stands(14 if not low else 9, true)
			_roof_lights()
		"stadium":
			_env(Color("060914"), Color("161c33"), Color(0.5, 0.52, 0.62), 0.95, Vector3(-70, -15, 0), Color(1.0, 0.93, 0.8))
			spots = _stands(16 if not low else 10, false)
			_floodlights()
	add_child(_ground.commit(ground_material(surface() == "mat", f.pole_gap * 0.5)))
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	if not spots.is_empty():
		crowd = Crowd.new()
		crowd.build(spots, Game.crowd_density(), home_colors, hash(venue), kind in ["arena", "stadium"])
		add_child(crowd)


## How loud the place is (0-1).
func atmosphere() -> float:
	return {"village": 0.55, "school": 0.45, "arena": 0.95, "stadium": 0.85}.get(String(DB.venue(venue)[4]), 0.6)


# ---------------------------------------------------------------- light

func _env(top: Color, horizon: Color, ambient: Color, energy: float, sun_rot: Vector3, sun_col: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = top
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if int(Game.settings.graphics) < Game.GFX_MEDIUM:
		env.ambient_light_energy = 0.8   # the linear tone mapper draws darker: lift the shade to match Medium
	if int(Game.settings.graphics) >= Game.GFX_HIGH:
		env.fog_enabled = true
		env.fog_light_color = horizon
		env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = energy
	sun.light_color = sun_col
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# The sky: a dome coloured from the horizon up, brighter toward the sun.
	var to_sun := Basis.from_euler(sun_rot * PI / 180.0) * Vector3.BACK
	_glow.dome(90.0, horizon, top, sun_col.lerp(horizon, 0.3), to_sun, 5 if int(Game.settings.graphics) == Game.GFX_LOW else 8, 20 if int(Game.settings.graphics) == Game.GFX_LOW else 28)


## Hills far off, hazy with distance: a ring of long low mounds behind the place.
func _hills(col: Color, haze: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var n := 9 if int(Game.settings.graphics) == Game.GFX_LOW else 14
	for i in n:
		var a := PI * 1.02 + PI * 0.96 * float(i) / float(n - 1) + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(70.0, 82.0)
		var c := Vector3(cos(a) * r, -2.0, sin(a) * r * 0.85 - 4.0)
		_lit.ball(c, Vector3(rng.randf_range(14.0, 24.0), rng.randf_range(5.0, 11.0), rng.randf_range(8.0, 12.0)), col.lerp(haze, rng.randf_range(0.35, 0.6)), 0.08, i)


## The ground's material: the vertex colours under a fine grain and a broad mottle (one small texture made once),
## lighter where the play wears it (along the lane, round the poles). Mats get a fainter, finer grain.
static var _detail: ImageTexture


static func ground_material(mat: bool, half_gap: float) -> ShaderMaterial:
	if _detail == null:
		var fine := FastNoiseLite.new()
		fine.noise_type = FastNoiseLite.TYPE_CELLULAR
		fine.frequency = 0.09
		fine.seed = 3
		var broad := FastNoiseLite.new()
		broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		broad.frequency = 0.012
		broad.fractal_octaves = 3
		broad.seed = 9
		var a := fine.get_seamless_image(128, 128)
		var b := broad.get_seamless_image(128, 128)
		var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				img.set_pixel(x, y, Color(a.get_pixel(x, y).r, b.get_pixel(x, y).r, 0.0, 1.0))
		img.generate_mipmaps()
		_detail = ImageTexture.create_from_image(img)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode vertex_lighting, specular_disabled;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float grain = 0.16;
uniform float mottle = 0.12;
uniform float wear = 0.12;
uniform float half_gap = 12.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 d = texture(detail, wpos.xz * 0.35).rg;
	float broad = texture(detail, wpos.xz * 0.035 + vec2(0.37, 0.11)).g;
	float n = (1.0 + grain * (d.r - 0.5) * 2.0) * (1.0 + mottle * (broad - 0.5) * 2.0);
	float lane = exp(-wpos.z * wpos.z / 2.5) * (1.0 - smoothstep(half_gap, half_gap + 2.0, abs(wpos.x)));
	float poles = exp(-(pow(abs(wpos.x) - half_gap, 2.0) + wpos.z * wpos.z) / 3.0);
	ALBEDO = COLOR.rgb * n * (1.0 + wear * max(lane, poles));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("detail", _detail)
	m.set_shader_parameter("half_gap", half_gap)
	if mat:
		m.set_shader_parameter("grain", 0.05)
		m.set_shader_parameter("mottle", 0.04)
		m.set_shader_parameter("wear", 0.04)
	return m


# ---------------------------------------------------------------- the field

func _field() -> void:
	var L: float = f.length * 0.5
	var W: float = f.width * 0.5
	var lobby: float = f.lobby
	var mat := surface() == "mat"
	var earth := Color("a8573a") if time_of_day() != "day" else Color("b8693f")
	var outside := Color("6c5a3c") if not mat else Color("1b2433")
	_ground.floor_rect(-60, -60, 60, 60, -0.01, outside)
	if mat:
		# The fast game's mats: the field one colour, the lobby another, the free zones a third.
		_ground.floor_rect(-L - lobby, -W - lobby, L + lobby, W + lobby, 0.0, Color("2f3f8c"))
		_ground.floor_rect(-L, -W, L, W, 0.004, Color("2f86c9"))
		var pg: float = f.pole_gap * 0.5
		for s: float in [-1.0, 1.0]:
			_ground.floor_rect(minf(s * pg, s * L), -W, maxf(s * pg, s * L), W, 0.006, Color("e2604f"))
	else:
		# Beaten earth, rolled and watered: a little lighter where the play wears it, darker at the edges.
		_ground.floor_rect(-L - lobby - 2.0, -W - lobby - 2.0, L + lobby + 2.0, W + lobby + 2.0, -0.004, earth.darkened(0.12))
		_ground.floor_rect(-L - lobby, -W - lobby, L + lobby, W + lobby, 0.0, earth.darkened(0.04))
		_ground.floor_rect(-L, -W, L, W, 0.001, earth)
	# The lines, in lime (or white tape on the mats), 5 cm wide.
	var line := Color("f4f6e8") if not mat else Color("f7f7f7")
	# 5 cm chalk; on Low (no anti-aliasing, a smaller render) drawn wider so it does not break into dashes far off.
	var lw := 0.09 if int(Game.settings.graphics) == Game.GFX_LOW else 0.06
	var y := 0.012
	_glow.floor_rect(-L, -W, L, -W + lw, y, line)
	_glow.floor_rect(-L, W - lw, L, W, y, line)
	_glow.floor_rect(-L, -W, -L + lw, W, y, line)
	_glow.floor_rect(L - lw, -W, L, W, y, line)
	# The central lane, pole to pole, 30 cm wide.
	var pg2: float = f.pole_gap * 0.5
	var lh: float = f.lane_w * 0.5
	_glow.floor_rect(-pg2, -lh, pg2, -lh + lw, y, line)
	_glow.floor_rect(-pg2, lh - lw, pg2, lh, y, line)
	# The post lines, across the field at each pole: the free zones beyond.
	for s: float in [-1.0, 1.0]:
		_glow.floor_rect(s * pg2 - lw * 0.5, -W, s * pg2 + lw * 0.5, W, y, line)
	# The cross lanes, side line to side line, each as wide as its rule book says; the squares where they meet the lane.
	var cw: float = f.cross_w
	for x: float in f.square_x:
		_glow.floor_rect(x - cw * 0.5, -W, x - cw * 0.5 + lw, W, y + 0.001, line)
		_glow.floor_rect(x + cw * 0.5 - lw, -W, x + cw * 0.5, W, y + 0.001, line)
	# The lobby's edge, a rope on pegs on a ground, a line on the mats.
	if not mat:
		var rope := Color("e8d9b0")
		_lit.box(Vector3(0, 0.25, -W - lobby), Vector3(L * 2 + lobby * 2, 0.02, 0.02), rope)
		_lit.box(Vector3(0, 0.25, W + lobby), Vector3(L * 2 + lobby * 2, 0.02, 0.02), rope)
		_lit.box(Vector3(-L - lobby, 0.25, 0), Vector3(0.02, 0.02, W * 2 + lobby * 2), rope)
		_lit.box(Vector3(L + lobby, 0.25, 0), Vector3(0.02, 0.02, W * 2 + lobby * 2), rope)
		var step := 4.0
		var xx := -L - lobby
		while xx <= L + lobby + 0.01:
			for zz: float in [-W - lobby, W + lobby]:
				_lit.box(Vector3(xx, 0.14, zz), Vector3(0.05, 0.28, 0.05), Color("6b4a2a"))
			xx += step


## The two poles: smooth wood, 1.225 m above the ground, 9.5 cm thick, at the lane's ends.
func _poles() -> void:
	var pg: float = f.pole_gap * 0.5
	var r: float = f.pole_d * 0.5
	for s: float in [-1.0, 1.0]:
		_lit.cylinder(Vector3(s * pg, 0, 0), Vector3(s * pg, f.pole_h, 0), r, r * 0.92, Color("d8b07a"), 10, true)
		_lit.cylinder(Vector3(s * pg, 0, 0), Vector3(s * pg, 0.04, 0), r * 1.8, r * 1.8, Color("8a5a2b"), 10, true)


## The officials' table and the benches, on the far side line.
func _table() -> void:
	var z: float = -(f.width * 0.5 + f.lobby + 1.4)
	_lit.box(Vector3(0, 0.38, z), Vector3(3.2, 0.06, 0.8), Color("e9e2d0"))
	_lit.box(Vector3(0, 0.2, z - 0.05), Vector3(3.1, 0.38, 0.7), Color("2c5a8a"))
	for s: float in [-1.0, 1.0]:
		_lit.box(Vector3(s * 6.5, 0.22, z - 0.3), Vector3(5.0, 0.08, 0.5), Color("7a5432"))
		for k in 3:
			_lit.box(Vector3(s * 6.5 - 2.0 + k * 2.0, 0.1, z - 0.3), Vector3(0.08, 0.2, 0.4), Color("5a3a20"))
	# A shamiana over the table: a striped canopy on four poles.
	if int(Game.settings.graphics) > Game.GFX_LOW and surface() != "mat":
		for sx: float in [-1.8, 1.8]:
			for sz: float in [-0.9, 0.9]:
				_lit.cylinder(Vector3(sx, 0, z + sz), Vector3(sx, 2.4, z + sz), 0.03, 0.03, Color("d8d0c0"), 6, false)
		for i in 6:
			var c := Color("d63a2a") if i % 2 == 0 else Color("f2e6c8")
			_lit.box(Vector3(-1.8 + 0.6 * i + 0.3, 2.42, z), Vector3(0.6, 0.04, 2.0), c)


# ---------------------------------------------------------------- the places

## People round a ground: sitting on the earth in front, standing behind them, three or four deep.
func _ground_crowd(low: bool, kids := false) -> Array:
	var spots := []
	var L: float = f.length * 0.5 + f.lobby + 1.0
	var W: float = f.width * 0.5 + f.lobby + 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows := 3 if low else 5
	for r in rows:
		var d := 1.0 + r * 0.9
		var h := 0.0 if r < 2 else 0.0
		var step := 0.75 if r < 2 else 0.6
		var scale_y := -0.42 if r < 2 else 0.0   # the front rows sit on the ground
		var x := -L - d
		while x < L + d:
			# The far side, behind the table, and the two ends; the near side only far to the left and right.
			spots.append(Vector3(x + rng.randf_range(-0.2, 0.2), h + scale_y, -W - d - 1.8))
			if absf(x) > 9.0:
				spots.append(Vector3(x + rng.randf_range(-0.2, 0.2), h + scale_y, W + d))
			x += step
		var zz := -W
		while zz < W:
			for s: float in [-1.0, 1.0]:
				spots.append(Vector3(s * (L + d), h + scale_y, zz + rng.randf_range(-0.2, 0.2)))
			zz += step
	if kids:
		for i in spots.size():
			spots[i] = spots[i] - Vector3(0, 0.25, 0)
	return spots


## Tiers of seats on the far side and both ends (the near side is where the cameras are).
func _stands(rows: int, indoor: bool) -> Array:
	var spots := []
	var L: float = f.length * 0.5 + f.lobby + 3.0
	var W: float = f.width * 0.5 + f.lobby + 3.2
	var seat := Color("2b3550") if indoor else Color("4a4f5c")
	var riser := Color("1c2233") if indoor else Color("33363f")
	for r in rows:
		var d := r * 0.85
		var hgt := 0.45 + r * 0.45
		# Far side.
		_lit.box(Vector3(0, hgt - 0.22, -W - d), Vector3(L * 2 + d * 2, 0.45, 0.85), seat if r % 2 == 0 else riser)
		# Ends.
		for s: float in [-1.0, 1.0]:
			_lit.box(Vector3(s * (L + d), hgt - 0.22, 0), Vector3(0.85, 0.45, W * 2 + d * 2), seat if r % 2 == 0 else riser)
		var x := -L - d + 0.4
		while x < L + d:
			spots.append(Vector3(x, hgt, -W - d))
			x += 0.62
		var z := -W - d + 0.4
		while z < W + d - 3.0:
			for s: float in [-1.0, 1.0]:
				spots.append(Vector3(s * (L + d), hgt, z))
			z += 0.62
	var back := -W - rows * 0.85 - 0.5
	_lit.wall(Vector3(-L - rows, 0, back), Vector3(L + rows, 0, back), 0.0, rows * 0.45 + 4.0, Color("151a28") if indoor else Color("23262e"))
	# Boards round the lobby: plain coloured panels (no names).
	if indoor:
		var bz: float = f.width * 0.5 + f.lobby + 0.6
		for i in 12:
			var x0 := -L + i * (L * 2.0 / 12.0)
			_glow.box(Vector3(x0 + L / 12.0, 0.45, -bz), Vector3(L * 2.0 / 12.0 - 0.1, 0.9, 0.08), [Color("ff8a1f"), Color("2f86c9"), Color("f2e6c8")][i % 3])
	return spots


## The hall's roof: a dark deck on steel trusses, rows of lights between them, and a big screen hung over the
## centre (plain: no names).
func _roof_lights() -> void:
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for i in 6:
		for s2: float in [-1.0, 1.0]:
			_glow.box(Vector3(-12.5 + i * 5.0, 14.0, s2 * 7.0), Vector3(1.6, 0.1, 0.6), Color("fff6e0"))
	_lit.box(Vector3(0, 14.6, 0), Vector3(70, 0.3, 56), Color("10131d"))
	var trusses: int = 4 if low else 7
	for i in trusses:
		var x: float = -21.0 + i * 42.0 / float(trusses - 1)
		_lit.box(Vector3(x, 14.2, 0), Vector3(0.35, 0.5, 54), Color("3a4150"))
		if not low:
			_lit.box(Vector3(x, 13.3, 0), Vector3(0.2, 0.2, 54), Color("3a4150"))
			for k in 9:
				var z := -24.0 + k * 6.0
				_lit.box(Vector3(x, 13.75, z + 1.5), Vector3(0.12, 1.1, 0.12), Color("3a4150"))
	# The screen: four faces of panels, hung on cables.
	var c := Vector3(0, 10.2, 0)
	_lit.box(c, Vector3(4.6, 2.4, 4.6), Color("181b22"))
	for k in 4:
		var yaw := PI * 0.5 * k
		var n := Vector3(sin(yaw), 0, cos(yaw))
		_glow.box(c + n * 2.31, Vector3(4.1, 1.9, 0.02), Color("1d3a6a").lerp(Color("2f86c9"), 0.4), yaw)
	for sx: float in [-1.6, 1.6]:
		_lit.cylinder(c + Vector3(sx, 1.2, 0), Vector3(sx, 14.4, 0), 0.03, 0.03, Color("9aa0aa"), 4, false)


## Four lattice towers at the corners, each a bank of lamps tilted at the field; a roof over the far stand.
func _floodlights() -> void:
	var L: float = f.length * 0.5 + 10.0
	var W: float = f.width * 0.5 + 9.0
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			if sz > 0.0 and low:
				continue
			var base := Vector3(sx * L, 0, sz * W)
			# Three legs leaning in to the head, braced.
			for k in 3:
				var a := TAU * k / 3.0
				var foot := base + Vector3(cos(a), 0, sin(a)) * 1.4
				_lit.cylinder(foot, base + Vector3(0, 19.5, 0), 0.12, 0.08, Color("7b808a"), 5, false)
			if not low:
				for hgt: float in [5.0, 10.0, 15.0]:
					var r := 1.4 * (1.0 - hgt / 19.5)
					_lit.ring(base + Vector3(0, hgt, 0), r - 0.06, r + 0.06, 0.0, TAU, Color("7b808a"), 8)
			# The head: a frame and four rows of lamps, facing the field's centre.
			var yaw := atan2(-base.x, -base.z)
			var head := base + Vector3(0, 20.5, 0)
			_lit.box(head, Vector3(4.2, 2.6, 0.35), Color("3a3e46"), yaw)
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			for row in 4:
				for col in 6:
					var p := head + right * (-1.75 + col * 0.7) + Vector3(0, -0.95 + row * 0.63, 0) + fwd * 0.2
					_glow.box(p, Vector3(0.5, 0.42, 0.06), Color("fffbe8"), yaw)
	# A cantilevered roof over the far stand, on columns.
	var z: float = -(f.width * 0.5 + f.lobby + 3.2) - 16 * 0.85
	_lit.box(Vector3(0, 12.0, z + 6.0), Vector3(f.length + 16.0, 0.4, 14.0), Color("2a2e38"))
	if not low:
		for i in 7:
			var x: float = -float(f.length) * 0.5 - 6.0 + i * (float(f.length) + 12.0) / 6.0
			_lit.box(Vector3(x, 6.0, z), Vector3(0.4, 12.0, 0.4), Color("5a5f6a"))
			_lit.box(Vector3(x, 11.6, z + 6.0), Vector3(0.3, 0.5, 12.0), Color("4a4f5a"))
	# The night: a few stars.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in (40 if not low else 0):
		var a := rng.randf_range(PI * 1.05, PI * 1.95)
		var e := rng.randf_range(0.25, 1.1)
		var d := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 85.0
		_glow.box(d, Vector3(0.25, 0.25, 0.25), Color(1, 1, 0.95).lerp(Color("aac8ff"), rng.randf()))


## Trees behind the place: neem and rain trees, a broad crown of several rounded masses on a forked trunk, and (palms
## true) coconut palms, a leaning ringed trunk with a crown of drooping fronds.
func _trees(n: int, r0: float, r1: float, palms := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for i in n:
		var a := rng.randf_range(PI * 1.05, PI * 1.95)
		var r := rng.randf_range(r0, r1)
		var p := Vector3(cos(a) * r * 1.2, 0, sin(a) * r * 0.7 - 6.0)
		if palms and i % 3 == 0:
			_palm(p, rng.randf_range(7.0, 11.0), rng, low)
			continue
		var h := rng.randf_range(5.5, 9.5)
		var bark := Color("4a3424").lerp(Color("5e4630"), rng.randf())
		var crown_y := h * 0.62
		_lit.cylinder(p, p + Vector3(0, crown_y, 0), 0.32, 0.22, bark, 6 if low else 8, false)
		# Two limbs forking up into the crown.
		for k in (1 if low else 2):
			var dir := Vector3(rng.randf_range(-1, 1), 1.4, rng.randf_range(-1, 1)).normalized()
			var from := p + Vector3(0, crown_y * 0.8, 0)
			_lit.cylinder(from, from + dir * h * 0.3, 0.16, 0.09, bark, 5, false)
		var leaf := Color("2f5a2a").lerp(Color("557d36"), rng.randf())
		var masses := 3 if low else 6
		for k in masses:
			var off := Vector3(rng.randf_range(-1, 1) * h * 0.28, rng.randf_range(-0.1, 0.25) * h, rng.randf_range(-1, 1) * h * 0.22)
			var sz := h * rng.randf_range(0.2, 0.3)
			_lit.ball(p + Vector3(0, h * 0.78, 0) + off, Vector3(sz * 1.2, sz * 0.8, sz * 1.1), leaf.lerp(Color("6f8f3a"), rng.randf() * 0.35), 0.18, i * 7 + k)


func _palm(p: Vector3, h: float, rng: RandomNumberGenerator, low: bool) -> void:
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.15, 0.25)).normalized()
	var segs := 4 if low else 6
	var prev := p
	var top := p
	for k in segs:
		var t := float(k + 1) / segs
		# The trunk bends: more lean the higher it goes.
		var q := p + (lean * Vector3(t * 1.6, 1.0, t * 1.6)).normalized() * h * t
		q.y = h * t
		_lit.cylinder(prev, q, 0.24 - 0.06 * t, 0.22 - 0.06 * t, Color("7a6248").lerp(Color("5f4a36"), float(k % 2)), 6, false)
		prev = q
		top = q
	var frond := Color("3d7a2e")
	var n := 6 if low else 9
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var len := h * rng.randf_range(0.36, 0.46)
		var pts := []
		for j in 4:
			var t := float(j) / 3.0
			pts.append(top + dir * len * t + Vector3(0, 0.6 * t - 1.9 * t * t, 0))
		for j in 3:
			var w0 := 0.55 * (1.0 - float(j) / 3.0) + 0.08
			var w1 := 0.55 * (1.0 - float(j + 1) / 3.0) + 0.08
			var a0: Vector3 = pts[j]
			var a1: Vector3 = pts[j + 1]
			var c := frond.lerp(Color("5a8f36"), float(j) / 3.0)
			_lit._tri_quad(a0 - side * w0, a0 + side * w0, a1 + side * w1, a1 - side * w1, Vector3.UP, c)
			_lit._tri_quad(a1 - side * w1, a1 + side * w1, a0 + side * w0, a0 - side * w0, Vector3.DOWN, c.darkened(0.2))
	_lit.ball(top, Vector3(0.45, 0.35, 0.45), Color("5e4a2a"), 0.1, 3)


## Village houses: plastered walls on a plinth, a thatched (or tiled) roof over the eaves, a door and a window.
func _huts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var walls := [Color("d9b98c"), Color("e8d2a8"), Color("c99a72"), Color("dcc9a0"), Color("b9c7c0")]
	for i in 6:
		var p := Vector3(-34.0 + i * 13.5 + rng.randf_range(-2, 2), 0, -28.0 - (i % 2) * 5.0 - rng.randf_range(0, 3))
		var w := rng.randf_range(4.5, 6.5)
		var d := rng.randf_range(3.4, 4.4)
		var hgt := rng.randf_range(2.4, 2.9)
		var wall: Color = walls[i % walls.size()]
		_lit.box(p + Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4), Color("8f7a5e"))
		_lit.box(p + Vector3(0, 0.3 + hgt * 0.5, 0), Vector3(w, hgt, d), wall)
		var thatch := i % 3 != 2
		var roof := Color("a88a52").lerp(Color("8a6a3a"), rng.randf()) if thatch else Color("a4442e")
		_lit.prism(p + Vector3(0, 0.3 + hgt, 0), w + 1.0, d + 1.4, rng.randf_range(1.2, 1.7), roof)
		_lit.box(p + Vector3(-w * 0.15, 0.3 + 0.95, d * 0.5 + 0.01), Vector3(0.95, 1.9, 0.04), Color("4a2e1a"))
		_lit.box(p + Vector3(w * 0.25, 0.3 + 1.5, d * 0.5 + 0.01), Vector3(0.9, 0.75, 0.04), Color("2c3a44"))
		# A haystack or a cart beside some of them.
		if i % 2 == 0:
			_lit.ball(p + Vector3(w * 0.5 + 2.0, 0.9, 1.0), Vector3(1.3, 1.2, 1.3), Color("c9a65a"), 0.1, i)


func _string_lights(low: bool) -> void:
	if low:
		return
	var z: float = -(f.width * 0.5 + f.lobby + 3.0)
	for k in 2:
		var zz := z if k == 0 else -z
		if k == 1:
			continue
		for i in 40:
			var x := -20.0 + i * 1.0
			var sag := 3.6 - 0.6 * sin(PI * fposmod(x, 10.0) / 10.0)
			_glow.box(Vector3(x, sag, zz), Vector3(0.12, 0.12, 0.12), [Color("ffcf6a"), Color("ff7a4a"), Color("fff2c0"), Color("7ad0ff")][i % 4])
	for x: float in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		_lit.cylinder(Vector3(x, 0, z), Vector3(x, 3.8, z), 0.05, 0.05, Color("6b4a2a"), 5, false)


## The school: two storeys with a verandah of pillars on each, windows with frames, a parapet, a water tank on the
## roof, and the boundary wall in front.
func _school() -> void:
	var z := -24.0
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var wall := Color("e6cf9a")
	_lit.box(Vector3(0, 3.5, z - 1.0), Vector3(46, 7.0, 5.0), wall)
	_lit.box(Vector3(0, 3.5, z + 1.6), Vector3(46.4, 0.25, 1.4), Color("d8c08c"))     # the first floor's verandah
	_lit.box(Vector3(0, 7.1, z + 0.6), Vector3(47, 0.35, 7.2), Color("9a3a2a"))       # the roof slab's edge
	_lit.box(Vector3(0, 7.6, z + 3.0), Vector3(47, 0.7, 0.2), wall.darkened(0.08))    # the parapet
	for row in 2:
		for i in 14:
			var x := -20.0 + i * 3.1
			_lit.box(Vector3(x, 1.8 + row * 3.4, z + 1.51), Vector3(1.5, 1.5, 0.05), Color("f2eadc"))
			_lit.box(Vector3(x, 1.8 + row * 3.4, z + 1.54), Vector3(1.25, 1.25, 0.04), Color("3b5872"))
			if not low:
				_lit.box(Vector3(x - 1.55, 1.7 + row * 3.4, z + 2.15), Vector3(0.3, 3.4, 0.3), Color("efe4cc"))
		if not low:
			_lit.box(Vector3(0, 3.35 + row * 3.4, z + 2.25), Vector3(46, 0.08, 0.06), Color("8a6a4a"))   # the rail
	_lit.cylinder(Vector3(14, 7.3, z - 1.0), Vector3(14, 9.2, z - 1.0), 1.4, 1.4, Color("2b2b2b"), 10, true)   # the tank
	_lit.box(Vector3(0, 0.6, -18.5), Vector3(50, 1.2, 0.25), Color("cfc6b4"))
	if not low:
		for i in 11:
			_lit.box(Vector3(-25.0 + i * 5.0, 0.7, -18.5), Vector3(0.4, 1.4, 0.4), Color("bdb3a0"))
