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
			_trees(18 if not low else 10, 24.0, 36.0)
			_huts()
			_string_lights(low)
		"school":
			_env(Color("6ea7e0"), Color("dbe8f0"), Color(0.8, 0.82, 0.86), 1.1, Vector3(-55, 30, 0), Color(1.0, 0.97, 0.9))
			spots = _ground_crowd(low, true)
			_school()
			_trees(12 if not low else 7, 26.0, 38.0)
		"arena":
			_env(Color("0c0f18"), Color("1a2030"), Color(0.62, 0.64, 0.72), 1.0, Vector3(-65, 20, 0), Color(1.0, 0.98, 0.95))
			spots = _stands(14 if not low else 9, true)
			_roof_lights()
		"stadium":
			_env(Color("060914"), Color("161c33"), Color(0.5, 0.52, 0.62), 0.95, Vector3(-70, -15, 0), Color(1.0, 0.93, 0.8))
			spots = _stands(16 if not low else 10, false)
			_floodlights()
	add_child(_ground.commit(Geo.material(true)))
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	if not spots.is_empty():
		crowd = Crowd.new()
		crowd.build(spots, Game.crowd_density(), home_colors, hash(venue))
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
	# The sky's glow at the horizon: a band of colour round the far side (cheaper than a sky).
	var r := 70.0
	for i in 24:
		var a0 := PI * 1.0 + PI * float(i) / 24.0 - PI * 0.5
		var a1 := PI * 1.0 + PI * float(i + 1) / 24.0 - PI * 0.5
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r - 10.0)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r - 10.0)
		_glow.wall(p0, p1, -1.0, 9.0, horizon)
		_glow.wall(p0 + Vector3(0, 9, 0), p1 + Vector3(0, 9, 0), 0.0, 14.0, horizon.lerp(top, 0.6))


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
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var n := 6 if int(Game.settings.graphics) == Game.GFX_LOW else 14
		for i in n:
			var x := rng.randf_range(-L, L)
			var z := rng.randf_range(-W, W)
			var r := rng.randf_range(1.0, 3.0)
			_ground.floor_rect(x - r, z - r * 0.6, x + r, z + r * 0.6, 0.002 + i * 0.0001, earth.lightened(rng.randf_range(0.02, 0.07)))
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


func _roof_lights() -> void:
	for i in 6:
		for s: float in [-1.0, 1.0]:
			_glow.box(Vector3(-12.5 + i * 5.0, 14.0, s * 7.0), Vector3(1.6, 0.1, 0.6), Color("fff6e0"))
	_lit.box(Vector3(0, 14.4, 0), Vector3(60, 0.3, 50), Color("10131d"))


func _floodlights() -> void:
	var L: float = f.length * 0.5 + 10.0
	var W: float = f.width * 0.5 + 9.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			if sz > 0.0 and int(Game.settings.graphics) == Game.GFX_LOW:
				continue
			var base := Vector3(sx * L, 0, sz * W)
			_lit.cylinder(base, base + Vector3(0, 18, 0), 0.25, 0.18, Color("6b6f78"), 6, false)
			_glow.box(base + Vector3(0, 18.6, 0), Vector3(2.6, 1.4, 0.3), Color("fffbe8"))


func _trees(n: int, r0: float, r1: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in n:
		var a := rng.randf_range(PI * 1.05, PI * 1.95)
		var r := rng.randf_range(r0, r1)
		var p := Vector3(cos(a) * r * 1.2, 0, sin(a) * r * 0.7 - 6.0)
		var h := rng.randf_range(5.0, 9.0)
		_lit.cylinder(p, p + Vector3(0, h * 0.55, 0), 0.25, 0.18, Color("4a3424"), 6, false)
		_lit.blob(p + Vector3(0, h * 0.75, 0), Vector3(h * 0.38, h * 0.3, h * 0.38), Color("2f5a2a").lerp(Color("4f7a34"), rng.randf()))


func _huts() -> void:
	for i in 4:
		var p := Vector3(-24.0 + i * 15.0, 0, -26.0 - (i % 2) * 4.0)
		_lit.box(p + Vector3(0, 1.3, 0), Vector3(5.0, 2.6, 3.6), Color("c9a27a").lerp(Color("e0c49a"), float(i % 2)))
		_lit.box(p + Vector3(0, 2.9, 0), Vector3(5.6, 0.6, 4.2), Color("7a4a2a"))
		_lit.box(p + Vector3(0.8, 0.9, 1.81), Vector3(0.9, 1.8, 0.02), Color("3a2414"))


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


func _school() -> void:
	var z := -24.0
	_lit.box(Vector3(0, 3.5, z), Vector3(46, 7.0, 6.0), Color("e6cf9a"))
	_lit.box(Vector3(0, 7.3, z), Vector3(47, 0.6, 6.6), Color("9a3a2a"))
	for row in 2:
		for i in 14:
			_lit.box(Vector3(-20.0 + i * 3.1, 1.8 + row * 3.0, z + 3.01), Vector3(1.4, 1.4, 0.04), Color("3b5872"))
	_lit.box(Vector3(0, 0.6, -18.5), Vector3(50, 1.2, 0.25), Color("cfc6b4"))
