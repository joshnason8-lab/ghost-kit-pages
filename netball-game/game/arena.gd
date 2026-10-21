class_name Arena
extends Node3D
## A venue: the court to the Rules of Netball's measurements (Court), its goal posts, and around it one of three
## places netball is played. An indoor arena with seating all round, as at an international; a sports hall with one
## stand down its side, where most league netball is played; and an asphalt court under the sky, as so much of the
## game is across Africa, the Caribbean and the Pacific. Built from merged, vertex-coloured parts (Geo): a handful of
## draw calls for the whole place, however many parts. The crowd is one draw call (Crowd). Low graphics leaves out the
## small things.

var venue := "arena"
var home_colors: Array = []
var crowd: Crowd
var _lit: Geo
var _glow: Geo
var _low := false


func _init(p_venue := "arena", p_home_colors := []) -> void:
	venue = p_venue
	home_colors = p_home_colors


func _ready() -> void:
	_lit = Geo.new()
	_glow = Geo.new()
	_low = int(Game.settings.graphics) == Game.GFX_LOW
	var kind := String(DB.venue(venue)[2])
	var spots: Array = []
	match kind:
		"arena":
			_indoor_env(Color("0d0a1c"), Color(0.66, 0.66, 0.78))
			_court(Color("2f6fc4"), Color("1f4f8f"), Color("1a1736"))
			spots = _stands(14 if not _low else 9, 4.6, 6.4, Color("2a2350"), Color("3a2f6e"))
			_boards(Color("120e26"), Color("c8f03c"))
			_roof(16.0, Color("0c0a18"))
			_bench()
		"hall":
			_indoor_env(Color("1b1712"), Color(0.75, 0.72, 0.68))
			_court(Color("2e7d6a"), Color("c8925a"), Color("b9844f"), true)
			spots = _hall()
			_bench()
		"outdoor":
			_outdoor_env()
			_court(Color("3a74b8"), Color("2d6a43"), Color("4a4d52"))
			spots = _outdoor()
			_bench(true)
	_posts()
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	if not spots.is_empty():
		crowd = Crowd.new()
		crowd.build(spots, Game.crowd_density(), home_colors.duplicate(), hash(venue))
		add_child(crowd)


## How loud the place is (0-1).
func atmosphere() -> float:
	return {"arena": 0.9, "hall": 0.55, "outdoor": 0.4}.get(String(DB.venue(venue)[2]), 0.6)


func indoor() -> bool:
	return String(DB.venue(venue)[2]) != "outdoor"


# ---------------------------------------------------------------- light and sky

func _indoor_env(bg: Color, ambient: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = Game.shadows_enabled()
	add_child(sun)


func _outdoor_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("3d6fb3")
	mat.sky_horizon_color = Color("f2c08a")
	mat.ground_horizon_color = Color("8c7a63")
	mat.ground_bottom_color = Color("4c4236")
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.05
	sun.shadow_enabled = Game.shadows_enabled()
	add_child(sun)


# ---------------------------------------------------------------- the court

## The playing court in court_col, the run-off round it in runoff_col and the floor beyond in floor_col. White lines
## 50 mm wide: the outline, the two transverse lines, the centre circle and the goal circles. wood: a sports hall's
## timber floor.
func _court(court_col: Color, runoff_col: Color, floor_col: Color, wood := false) -> void:
	var hl := Court.HALF_L
	var hw := Court.HALF_W
	var ro := Court.RUNOFF
	_lit.floor_rect(-hl - 14.0, -hw - 14.0, hl + 14.0, hw + 14.0, -0.02, floor_col)
	_lit.floor_rect(-hl - ro, -hw - ro, hl + ro, hw + ro, -0.01, runoff_col)
	if wood:
		# Boards along the court's length, in two shades.
		var n := 30
		for i in n:
			var z0 := -hw - ro + (hw + ro) * 2.0 * i / n
			var z1 := -hw - ro + (hw + ro) * 2.0 * (i + 1) / n
			_lit.floor_rect(-hl - ro, z0, hl + ro, z1, -0.009, runoff_col.lightened(0.05 if i % 2 == 0 else 0.0))
	_lit.floor_rect(-hl, -hw, hl, hw, 0.0, court_col)
	var lw := Court.LINE_W
	var line := Color("f4f4f4")
	var y := 0.004
	# The outline: side lines and goal lines, inside the court's measure (lines are part of the court).
	_glow.floor_rect(-hl, -hw, hl, -hw + lw, y, line)
	_glow.floor_rect(-hl, hw - lw, hl, hw, y, line)
	_glow.floor_rect(-hl, -hw, -hl + lw, hw, y, line)
	_glow.floor_rect(hl - lw, -hw, hl, hw, y, line)
	for sx: float in [-1.0, 1.0]:
		var tx := Court.THIRD_X * sx
		_glow.floor_rect(tx - lw * 0.5, -hw, tx + lw * 0.5, hw, y, line)
		# The goal circle: a semicircle of 4.9 m on the goal line's middle.
		var gx := hl * sx
		var a0 := PI * 0.5 if sx > 0.0 else -PI * 0.5
		_glow.ring(Vector3(gx, y, 0), Court.CIRCLE_R - lw, Court.CIRCLE_R, a0, a0 + PI, line, 40)
	_glow.ring(Vector3(0, y, 0), Court.CENTRE_R - lw, Court.CENTRE_R, 0.0, TAU, line, 24)


## The goal posts: a post 3.05 m tall on each goal line's middle, the ring 380 mm across on a 150 mm arm, the net open
## at both ends, a padded protector round the post's foot.
func _posts() -> void:
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(Court.HALF_L * sx + 0.04 * sx, 0, 0)
		_lit.cylinder(base, base + Vector3(0, Court.RING_H, 0), Court.POST_R, Court.POST_R, Color("d8d8dc"), 10)
		_lit.cylinder(base, base + Vector3(0, 1.6, 0), 0.2, 0.2, Color("1d1a33"), 12)
		var ring_c := Vector3((Court.HALF_L - Court.RING_OUT - Court.RING_R) * sx, Court.RING_H, 0)
		_lit.box(Vector3((Court.HALF_L - Court.RING_OUT * 0.5) * sx, Court.RING_H, 0), Vector3(Court.RING_OUT + 0.06, 0.025, 0.04), Color("d8d8dc"))
		# The ring: twelve short bars round a circle.
		var seg := 14
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p0 := ring_c + Vector3(cos(a0), 0, sin(a0)) * (Court.RING_R + 0.008)
			var p1 := ring_c + Vector3(cos(a1), 0, sin(a1)) * (Court.RING_R + 0.008)
			_glow.cylinder(p0, p1, 0.009, 0.009, Color("ff6a1a"), 4, false)
		# The net: strands from the ring down to a smaller ring 40 cm below.
		if not _low:
			for i in 10:
				var a := TAU * i / 10.0
				var top := ring_c + Vector3(cos(a), 0, sin(a)) * Court.RING_R
				var bot := ring_c + Vector3(cos(a + 0.5) * Court.RING_R * 0.7, -0.4, sin(a + 0.5) * Court.RING_R * 0.7)
				_glow.cylinder(top, bot, 0.005, 0.005, Color("f2f2f2"), 3, false)


## The officials' bench: the scorers' and timekeepers' table at the middle of one side line, and the two team
## benches either side of it.
func _bench(outdoor := false) -> void:
	var z := Court.HALF_W + Court.RUNOFF + 0.9
	_lit.box(Vector3(0, 0.38, z), Vector3(3.2, 0.76, 0.7), Color("2b2552") if not outdoor else Color("6b5a44"))
	for sx: float in [-1.0, 1.0]:
		_lit.box(Vector3(6.5 * sx, 0.23, z + 0.2), Vector3(4.0, 0.45, 0.45), Color("3a3360") if not outdoor else Color("7a6a50"))


# ---------------------------------------------------------------- the arena

## Rows of seats all round, rows rows deep, rising from the floor; returns where the people sit.
func _stands(rows: int, gap_side: float, gap_end: float, seat: Color, step: Color) -> Array:
	var spots := []
	var hl := Court.HALF_L + Court.RUNOFF
	var hw := Court.HALF_W + Court.RUNOFF
	for r in rows:
		var rise := 0.45 + r * 0.42
		var back := 0.85
		var d_side := gap_side - Court.RUNOFF + r * back
		var d_end := gap_end - Court.RUNOFF + r * back
		var x0 := -hl - d_end
		var x1 := hl + d_end
		var z0 := -hw - d_side
		var z1 := hw + d_side
		var col := step if r % 4 == 0 else seat
		# The step each row sits on, all four sides.
		_lit.box(Vector3(0, rise * 0.5, z1 + back * 0.5), Vector3(x1 - x0, rise, back), col)
		_lit.box(Vector3(0, rise * 0.5, z0 - back * 0.5), Vector3(x1 - x0, rise, back), col)
		_lit.box(Vector3(x1 + back * 0.5, rise * 0.5, 0), Vector3(back, rise, z1 - z0), col)
		_lit.box(Vector3(x0 - back * 0.5, rise * 0.5, 0), Vector3(back, rise, z1 - z0), col)
		var gap := 0.62
		var nx := int((x1 - x0) / gap)
		var nz := int((z1 - z0) / gap)
		for i in nx:
			var x := x0 + (i + 0.5) * gap
			# The near side (toward the camera, +z) has the officials' bench and fewer seats low down.
			if not (r < 2 and absf(x) < 9.0):
				spots.append(Vector3(x, rise, z1 + back * 0.45))
			spots.append(Vector3(x, rise, z0 - back * 0.45))
		for i in nz:
			var z := z0 + (i + 0.5) * gap
			spots.append(Vector3(x1 + back * 0.45, rise, z))
			spots.append(Vector3(x0 - back * 0.45, rise, z))
	return spots


## The advertising boards round the run-off: a low glowing band (plain colours, no brands).
func _boards(base: Color, accent: Color) -> void:
	var hl := Court.HALF_L + Court.RUNOFF + 0.4
	var hw := Court.HALF_W + Court.RUNOFF + 0.4
	var h := 0.9
	for z: float in [-hw, hw]:
		var n := 12
		for i in n:
			var x0 := -hl + (hl * 2.0) * i / n
			var x1 := -hl + (hl * 2.0) * (i + 1) / n
			var c := base.lerp(accent, 0.18 if i % 3 == 0 else 0.06)
			if z > 0.0 and absf((x0 + x1) * 0.5) < 3.0:
				continue   # the officials' table
			_glow.wall(Vector3(x0, 0, z), Vector3(x1, 0, z), 0.0, h, c, true)
			_glow.floor_rect(x0, z - 0.01, x1, z + 0.01, h, accent.darkened(0.3))
	for x: float in [-hl, hl]:
		_glow.wall(Vector3(x, 0, -hw), Vector3(x, 0, hw), 0.0, h, base.lerp(accent, 0.08), true)


## The roof: a dark ceiling with rows of lights.
func _roof(h: float, col: Color) -> void:
	if _low:
		return
	var w := 40.0
	_lit.box(Vector3(0, h, 0), Vector3(w * 1.6, 0.3, w), col)
	for i in 6:
		for j in 3:
			var p := Vector3(-12.5 + i * 5.0, h - 0.3, -6.0 + j * 6.0)
			_glow.box(p, Vector3(1.4, 0.15, 0.6), Color("fff6e0"))


# ---------------------------------------------------------------- the hall

## The hall's walls, its high windows and its one stand; returns the seats.
func _hall() -> Array:
	var hl := Court.HALF_L + Court.RUNOFF + 1.2
	var hw := Court.HALF_W + Court.RUNOFF + 1.0
	var wall := Color("d8cdb8")
	var h := 9.0
	# The far wall and the two end walls; the near side has the stand.
	_lit.wall(Vector3(hl, 0, -hw - 5.0), Vector3(-hl, 0, -hw - 5.0), 0, h, wall)
	_lit.wall(Vector3(-hl, 0, -hw - 5.0), Vector3(-hl, 0, hw + 7.0), 0, h, wall.darkened(0.08))
	_lit.wall(Vector3(hl, 0, hw + 7.0), Vector3(hl, 0, -hw - 5.0), 0, h, wall.darkened(0.08))
	# A blue band low on the walls, and high windows of daylight.
	_lit.wall(Vector3(hl, 0, -hw - 4.98), Vector3(-hl, 0, -hw - 4.98), 0, 1.6, Color("2b4f86"))
	for i in 7:
		var x := -hl + 4.0 + i * (hl * 2.0 - 8.0) / 6.0
		_glow.wall(Vector3(x + 1.4, 0, -hw - 4.95), Vector3(x - 1.4, 0, -hw - 4.95), 6.2, 8.2, Color("dfe9f2"))
	# Wall bars on the far wall.
	if not _low:
		for i in 8:
			_lit.box(Vector3(-6.0 + i * 0.5, 2.0, -hw - 4.8), Vector3(0.06, 4.0, 0.08), Color("b88a52"))
	# The stand: seven rows of benches down the near side.
	var spots := []
	for r in 7:
		var rise := 0.45 + r * 0.45
		var z := hw + 0.5 + r * 0.8
		_lit.box(Vector3(0, rise * 0.5, z), Vector3(hl * 1.6, rise, 0.8), Color("8a6a46") if r % 2 == 0 else Color("7a5c3c"))
		var n := int(hl * 1.6 / 0.6)
		for i in n:
			var x := -hl * 0.8 + (i + 0.5) * 0.6
			if r < 1 and absf(x) < 9.0:
				continue
			spots.append(Vector3(x, rise, z))
	# The ceiling and its lights.
	if not _low:
		_lit.box(Vector3(0, h, 0), Vector3(hl * 2.2, 0.2, hw * 3.0), Color("6b6359"))
		for i in 4:
			for j in 2:
				_glow.box(Vector3(-11.0 + i * 7.3, h - 0.2, -4.0 + j * 8.0), Vector3(2.4, 0.12, 0.4), Color("fffbe8"))
	return spots


# ---------------------------------------------------------------- the outdoor court

func _outdoor() -> Array:
	var hl := Court.HALF_L + Court.RUNOFF
	var hw := Court.HALF_W + Court.RUNOFF
	# A wire fence on posts round three sides; the near side open, with the people standing along it.
	for i in 13:
		var x := -hl + (hl * 2.0) * i / 12.0
		_lit.cylinder(Vector3(x, 0, -hw - 0.5), Vector3(x, 3.0, -hw - 0.5), 0.04, 0.04, Color("7a7d80"), 6)
	_glow.wall(Vector3(hl, 0, -hw - 0.5), Vector3(-hl, 0, -hw - 0.5), 0.0, 3.0, Color(0.55, 0.58, 0.6, 1.0).darkened(0.2))
	# Trees and low buildings beyond, under the evening sky.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in (8 if _low else 18):
		var x := rng.randf_range(-hl - 8.0, hl + 8.0)
		var z := -hw - rng.randf_range(5.0, 16.0)
		var hgt := rng.randf_range(4.0, 8.0)
		_lit.cylinder(Vector3(x, 0, z), Vector3(x, hgt * 0.45, z), 0.18, 0.14, Color("5a4632"), 5)
		_lit.blob(Vector3(x, hgt * 0.7, z), Vector3(rng.randf_range(1.6, 2.8), hgt * 0.32, rng.randf_range(1.6, 2.8)), Color("3f6b34").lightened(rng.randf_range(-0.1, 0.1)))
	for i in 4:
		var x := -26.0 + i * 17.0
		_lit.box(Vector3(x, 2.0, -hw - 22.0), Vector3(10.0, 4.0, 6.0), Color("c9b79a").darkened(0.1 * i))
		_lit.box(Vector3(x, 4.2, -hw - 22.0), Vector3(10.6, 0.4, 6.6), Color("8a3b2e"))
	# The people: standing along the near side and both ends, a few on a low wall.
	var spots := []
	for r in 3:
		for i in 60:
			var x := -hl + 0.5 + i * (hl * 2.0 - 1.0) / 59.0
			if absf(x) < 8.0:
				continue
			spots.append(Vector3(x + rng.randf_range(-0.2, 0.2), 0.0 + r * 0.2, hw + 0.8 + r * 0.7))
		for i in 18:
			var z := -hw + 1.0 + i * (hw * 2.0 - 2.0) / 17.0
			spots.append(Vector3(-hl - 0.8 - r * 0.7, 0.0, z))
			spots.append(Vector3(hl + 0.8 + r * 0.7, 0.0, z))
	return spots
