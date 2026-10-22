class_name Arena
extends Node3D
## A venue: the court to the Rules of Netball's measurements (Court), its goal posts, and around it one of three
## places netball is played. An indoor arena under floodlights with a bowl of seating all round, as at an
## international; a sports hall with one stand down its side, where most league netball is played; and a court under
## an evening sky on floodlight poles, as so much of the game is across Africa, the Caribbean and the Pacific.
##
## Built from merged, vertex-coloured parts (Geo) drawn by the venue's shaders (VenueLook): its structure in one draw
## call, what glows (lines, light strips, boards, nets) in a second and its lights in a third, however many parts. The
## stands' seated people are painted by the shader, so a full house costs nothing more; on Medium and High the front
## rows are people of their own who jump and wave (Crowd, one more draw call). Low graphics leaves out the small
## things and the bloom.

var venue := "arena"
var home_colors: Array = []
var crowd: Crowd
var _lit: Geo
var _glow: Geo
var _fx: Geo
var _low := false
var _gfx := 0
var _lamps: Array[Vector3] = []   # lights reflected in the floor (at most 8)
var _look := {}                   # the shaders' settings for this venue (VenueLook uniforms)


func _init(p_venue := "arena", p_home_colors := []) -> void:
	venue = p_venue
	home_colors = p_home_colors


func _ready() -> void:
	_lit = Geo.new()
	_glow = Geo.new()
	_fx = Geo.new()
	_gfx = int(Game.settings.graphics)
	_low = _gfx == Game.GFX_LOW
	var kind := String(DB.venue(venue)[2])
	var spots: Array = []
	match kind:
		"arena":
			spots = _arena()
		"hall":
			spots = _hall()
		"outdoor":
			spots = _outdoor()
	_posts()
	if not home_colors.is_empty():
		_look["team_a"] = home_colors[0]
		_look["team_b"] = home_colors[min(1, home_colors.size() - 1)]
	var lit := VenueLook.lit()
	var glow := VenueLook.glow()
	for m: ShaderMaterial in [lit, glow]:
		_apply(m)
	add_child(_lit.commit(lit))
	add_child(_glow.commit(glow))
	var fx := VenueLook.flare()
	fx.set_shader_parameter("intensity", 1.25 if _low else 1.6)
	fx.set_shader_parameter("halo", 0.8 if _low else 1.0)
	var fxi := _fx.commit(fx)
	fxi.sorting_offset = 50.0
	add_child(fxi)
	if not spots.is_empty():
		crowd = Crowd.new()
		Crowd.set_tint(_look.get("stand_tint", Color.WHITE))
		crowd.build(spots, Game.crowd_density(), home_colors.duplicate(), hash(venue))
		add_child(crowd)


## How loud the place is (0-1).
func atmosphere() -> float:
	return {"arena": 0.9, "hall": 0.55, "outdoor": 0.4}.get(String(DB.venue(venue)[2]), 0.6)


func indoor() -> bool:
	return String(DB.venue(venue)[2]) != "outdoor"


func _apply(m: ShaderMaterial) -> void:
	var lamps := PackedVector3Array()
	for i in 8:
		lamps.append(_lamps[i] if i < _lamps.size() else Vector3(0, 30, 0))
	m.set_shader_parameter("lamp", lamps)
	m.set_shader_parameter("lamp_count", mini(_lamps.size(), 4 if _low else 8))
	for k: String in _look:
		m.set_shader_parameter(k, _look[k])


# ---------------------------------------------------------------- light and sky

## The world's light: a background or sky, ambient light and a key light from above. Medium and High add bloom
## round anything brighter than white (the lights, the light strips) and a filmic curve.
func _env(bg: Color, ambient: Color, amb_energy: float, key: Color, key_energy: float, key_rot: Vector3, sky: Sky = null) -> void:
	var env := Environment.new()
	if sky:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = amb_energy
	if _low:
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.1
		env.tonemap_white = 5.0
		env.glow_enabled = true
		env.glow_intensity = 0.95
		env.glow_strength = 1.0
		env.glow_bloom = 0.03
		env.glow_hdr_threshold = 0.95
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.set_glow_level(1, 0.0)
		env.set_glow_level(2, 1.0)
		env.set_glow_level(3, 1.0)
		env.set_glow_level(4, 0.6)
		env.set_glow_level(5, 0.4)
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.05
		env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = key_rot
	sun.light_color = key
	sun.light_energy = key_energy
	sun.shadow_enabled = Game.shadows_enabled()
	add_child(sun)


# ---------------------------------------------------------------- the court

## The playing court in court_col, the run-off round it in runoff_col and the floor beyond in floor_col, all polished
## (the lights in it, darker toward the edges). White lines 50 mm wide: the outline, the two transverse lines, the
## centre circle and the goal circles. surround: the kind of face for the run-off and beyond (a hall's timber floor,
## an outdoor court's surround).
func _court(court_col: Color, runoff_col: Color, floor_col: Color, surround := VenueLook.FLOOR) -> void:
	var hl := Court.HALF_L
	var hw := Court.HALF_W
	var ro := Court.RUNOFF
	_lit.kind = Vector2(surround, 0)
	_lit.floor_rect(-hl - 26.0, -hw - 26.0, hl + 26.0, hw + 26.0, -0.02, floor_col)
	_lit.floor_rect(-hl - ro, -hw - ro, hl + ro, hw + ro, -0.01, runoff_col)
	_lit.kind = Vector2(VenueLook.FLOOR, 0)
	_lit.floor_rect(-hl, -hw, hl, hw, 0.0, court_col)
	_lit.kind = Vector2.ZERO
	var lw := Court.LINE_W
	var line := Color("f6f8ff")
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


## A thin glowing line round the run-off's edge, in col.
func _runoff_edge(col: Color) -> void:
	var x := Court.HALF_L + Court.RUNOFF
	var z := Court.HALF_W + Court.RUNOFF
	var w := 0.06
	var y := 0.003
	_glow.floor_rect(-x, -z, x, -z + w, y, col)
	_glow.floor_rect(-x, z - w, x, z, y, col)
	_glow.floor_rect(-x, -z, -x + w, z, y, col)
	_glow.floor_rect(x - w, -z, x, z, y, col)


## The goal posts: a silver post 3.05 m tall on each goal line's middle, a glossy orange ring 380 mm across on a
## 150 mm arm, a white corded net open at both ends, and a padded protector round the post.
func _posts() -> void:
	var pad := Color(_look.get("pad", Color("1b2a6e")))
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(Court.HALF_L * sx + 0.04 * sx, 0, 0)
		_lit.kind = Vector2(VenueLook.METAL, 0)
		_lit.cylinder(base, base + Vector3(0, Court.RING_H + 0.02, 0), Court.POST_R, Court.POST_R, Color("d4d8e0"), 12)
		_lit.kind = Vector2(VenueLook.GLOSS, 0)
		_lit.cylinder(base, base + Vector3(0, 1.75, 0), 0.19, 0.19, pad, 14)
		_lit.cylinder(base + Vector3(0, 1.75, 0), base + Vector3(0, 1.9, 0), 0.19, 0.19, Color("ff6a1a"), 14)
		var ring_c := Vector3((Court.HALF_L - Court.RING_OUT - Court.RING_R) * sx, Court.RING_H, 0)
		var orange := Color("ff7b1c")
		_lit.box(Vector3((Court.HALF_L - Court.RING_OUT * 0.5 + 0.02) * sx, Court.RING_H - 0.02, 0), Vector3(Court.RING_OUT + 0.08, 0.05, 0.07), orange)
		# The ring: a tube in short pieces round a circle.
		var seg := 14 if _low else 22
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p0 := ring_c + Vector3(cos(a0), 0, sin(a0)) * (Court.RING_R + 0.01)
			var p1 := ring_c + Vector3(cos(a1), 0, sin(a1)) * (Court.RING_R + 0.01)
			_lit.cylinder(p0, p1, 0.011, 0.011, orange, 4 if _low else 6, false)
		_lit.kind = Vector2.ZERO
		# The net: a corded skirt from the ring down to a narrower opening 42 cm below (the shader knots the cords).
		_glow.kind = Vector2(VenueLook.NET, 0)
		var n := 16
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var t0 := ring_c + Vector3(cos(a0), 0, sin(a0)) * Court.RING_R
			var t1 := ring_c + Vector3(cos(a1), 0, sin(a1)) * Court.RING_R
			var b0 := ring_c + Vector3(cos(a0) * 0.68 * Court.RING_R, -0.42, sin(a0) * 0.68 * Court.RING_R)
			var b1 := ring_c + Vector3(cos(a1) * 0.68 * Court.RING_R, -0.42, sin(a1) * 0.68 * Court.RING_R)
			var u0 := 8.0 * i / n
			var u1 := 8.0 * (i + 1) / n
			_glow.quad(t0, t1, b1, b0, Color("f4f6fa"), [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 3), Vector2(u0, 3)])
		_glow.kind = Vector2.ZERO


## The officials' bench: the scorers' and timekeepers' table at the middle of one side line, with a glowing front,
## and the two team benches either side of it.
func _bench(table: Color, seat: Color, accent: Color) -> void:
	var z := Court.HALF_W + Court.RUNOFF + 0.9
	_lit.box(Vector3(0, 0.38, z), Vector3(3.2, 0.76, 0.7), table)
	_glow.kind = Vector2(VenueLook.LED, 0.2)
	_glow.wall(Vector3(1.55, 0, z - 0.36), Vector3(-1.55, 0, z - 0.36), 0.42, 0.68, accent)
	_glow.kind = Vector2.ZERO
	for sx: float in [-1.0, 1.0]:
		_lit.box(Vector3(6.5 * sx, 0.23, z + 0.2), Vector3(4.0, 0.45, 0.45), seat)
		_lit.box(Vector3(6.5 * sx, 0.6, z + 0.42), Vector3(4.0, 0.7, 0.08), accent.darkened(0.25))
		if not _low:
			for i in 3:
				_lit.box(Vector3(-0.9 + i * 0.9, 0.5, z + 0.6), Vector3(0.45, 1.0, 0.45), seat.darkened(0.2))


# ---------------------------------------------------------------- stands

## A ring of four faces round the court at distance o0 (beyond the run-off's corners X0, Z0) and height y0 to
## distance o1 and height y1: a slope of seats, a fascia or a walkway, mitred at the corners. k: the kind of face; for
## STAND the UV is in metres, along the side and up the slope.
func _ring(g: Geo, x0: float, z0: float, o0: float, y0: float, o1: float, y1: float, col: Color, k := Vector2.ZERO, sides := [0, 1, 2, 3]) -> void:
	var len_ := Vector2(o1 - o0, y1 - y0).length()
	g.kind = k
	for i: int in sides:
		var c0 := _corner(i, x0, z0)
		var c1 := _corner((i + 1) % 4, x0, z0)
		var a := Vector3(c0.x + signf(c0.x) * o0, y0, c0.y + signf(c0.y) * o0)
		var b := Vector3(c1.x + signf(c1.x) * o0, y0, c1.y + signf(c1.y) * o0)
		var c := Vector3(c1.x + signf(c1.x) * o1, y1, c1.y + signf(c1.y) * o1)
		var d := Vector3(c0.x + signf(c0.x) * o1, y1, c0.y + signf(c0.y) * o1)
		# u along the side, in metres from its middle; v up the face.
		var along := Vector2(b.x - a.x, b.z - a.z).normalized()
		var ua := Vector2(a.x, a.z).dot(along)
		var ub := Vector2(b.x, b.z).dot(along)
		var uc := Vector2(c.x, c.z).dot(along)
		var ud := Vector2(d.x, d.z).dot(along)
		# Seen from the court the face goes a, b, c, d anticlockwise; Geo wants them clockwise from the front.
		g.quad(a, d, c, b, col, [Vector2(ua, 0), Vector2(ud, len_), Vector2(uc, len_), Vector2(ub, 0)])
	g.kind = Vector2.ZERO


func _corner(i: int, x0: float, z0: float) -> Vector2:
	return [Vector2(-x0, -z0), Vector2(x0, -z0), Vector2(x0, z0), Vector2(-x0, z0)][i]


## Light sprites along a ring at distance o and height y, one every step metres along each side (flares), with sides
## to leave out (0 far, 1 the +x end, 2 near, 3 the -x end).
func _ring_lights(x0: float, z0: float, o: float, y: float, step: float, size: float, col: Color, streak := 0.0, skip: Array = []) -> void:
	for i in 4:
		if i in skip:
			continue
		var c0 := _corner(i, x0, z0)
		var c1 := _corner((i + 1) % 4, x0, z0)
		var a := Vector3(c0.x + signf(c0.x) * o, y, c0.y + signf(c0.y) * o)
		var b := Vector3(c1.x + signf(c1.x) * o, y, c1.y + signf(c1.y) * o)
		var n := maxi(1, int(a.distance_to(b) / step))
		for j in n:
			var p := a.lerp(b, (j + 0.5) / n)
			p += Vector3(-signf(p.x) * 0.15 if i % 2 == 1 else 0.0, 0, -signf(p.z) * 0.15 if i % 2 == 0 else 0.0)
			_fx.sprite(p, size, col, streak)


## People of their own (Crowd) in the front rows of a slope of seats, rows deep, between aisles every aisle metres;
## the slope starts at distance o0 and height y0 and each row is depth deep and rise high. sides: which sides of the
## ring (as _ring_lights); the near side's middle is left clear in its first two rows (the officials' bench).
func _front_rows(x0: float, z0: float, o0: float, y0: float, rows: int, depth: float, rise: float, aisle: float, sides := [0, 1, 2, 3]) -> Array:
	var spots := []
	for r in rows:
		var o := o0 + (r + 0.12) * depth
		var y := y0 + (r + 0.12) * rise
		for i: int in sides:
			var c0 := _corner(i, x0, z0)
			var c1 := _corner((i + 1) % 4, x0, z0)
			var a := Vector3(c0.x + signf(c0.x) * o, y, c0.y + signf(c0.y) * o)
			var b := Vector3(c1.x + signf(c1.x) * o, y, c1.y + signf(c1.y) * o)
			var along := (b - a).normalized()
			var n := int(a.distance_to(b) / 0.55)
			for j in n:
				var p := a.lerp(b, (j + 0.5) / n)
				var u := Vector2(p.x, p.z).dot(Vector2(along.x, along.z))
				if absf(fposmod(u, aisle) - aisle * 0.5) < 0.7:
					continue   # the stairs
				if i == 2 and r < 2 and absf(p.x) < 9.0:
					continue   # the officials' bench
				spots.append(p)
	return spots


# ---------------------------------------------------------------- the arena

## The arena: a deep blue night inside, the court bright under rigs of floodlights, a bowl of two tiers all round
## with a lit fascia between them, glowing boards round the run-off.
func _arena() -> Array:
	var night := Color("040a24")
	_env(night, Color("7088d0"), 0.55, Color("f4f6ff"), 1.0, Vector3(-62, 25, 0))
	_look = {"night": night, "fade_y0": 2.0, "fade_y1": 11.0, "fade_amt": 0.9, "stand_tint": Color(0.4, 0.45, 0.72) if _low else Color(0.5, 0.55, 0.85), "sheen": 0.32 if _low else 0.4,
		"gloss": 300.0, "vig_size": Vector2(25.0, 16.5), "vig_dark": 0.32, "seat_col": Color("1c2560"),
		"stair_col": Color("39447a"), "density": 0.86, "aisle_every": 9.0, "lamp_col": Color("dfe8ff"),
		"pad": Color("17256a"), "pool_lo": 0.45, "pool_hi": 1.15 if _low else 0.98, "pool_glow": 0.1}
	_court(Color("5a8cc8"), Color("3a95a8"), Color("0a1a44"))
	_runoff_edge(Color("2fd6e0"))
	_boards()
	# The bowl: front corners of the seating, X0 along, Z0 across.
	var x0 := Court.HALF_L + Court.RUNOFF + 3.3
	var z0 := Court.HALF_W + Court.RUNOFF + 1.55
	var front := 1.0          # the lower tier's front wall
	var lower := 8            # rows in the lower tier
	var depth := 0.85
	var rise := 0.425
	var o1 := lower * depth
	var y1 := front + lower * rise
	var first := 0 if _low else (3 if _gfx == Game.GFX_MEDIUM else 5)
	var wall := Color("10183e")
	_lit.kind = Vector2.ZERO
	_ring(_lit, x0, z0, 0.0, 0.0, 0.0, front, wall)
	# People of their own in the front rows on Medium and High, but not on the near side, under the cameras.
	_ring(_lit, x0, z0, 0.0, front, o1, y1, Color("1c2560"), Vector2(VenueLook.STAND, first), [0, 1, 3])
	_ring(_lit, x0, z0, 0.0, front, o1, y1, Color("1c2560"), Vector2(VenueLook.STAND, 0), [2])
	_ring(_glow, x0, z0, -0.02, front - 0.07, -0.02, front, Color("ff7a2a"), Vector2(VenueLook.LED, 0.6))
	# The walkway behind the lower tier, and the fascia under the upper tier with its strip of light.
	var fo := o1 + 0.7
	var fy := y1 + 1.3
	_ring(_lit, x0, z0, o1, y1, fo, y1, Color("141b44"))
	_ring(_lit, x0, z0, fo, y1, fo, fy, Color("0c1233"))
	_ring(_glow, x0, z0, fo - 0.015, y1 + 0.3, fo - 0.015, fy - 0.2, Color("0e2a66"), Vector2(VenueLook.LED, -0.35))
	_ring(_glow, x0, z0, fo - 0.02, fy - 0.16, fo - 0.02, fy - 0.04, Color("29d8ea"), Vector2(VenueLook.LED, 0.9))
	_ring(_glow, x0, z0, fo - 0.02, y1 + 0.18, fo - 0.02, y1 + 0.24, Color("ff7a2a"), Vector2(VenueLook.LED, 0.2))
	# The upper tier, steeper, fading into the dark, and the back wall up to the roof.
	var uo := fo + 11.0
	var uy := fy + 8.8
	_ring(_lit, x0, z0, fo, fy, uo, uy, Color("1c2560"), Vector2(VenueLook.STAND, 0))
	_ring(_lit, x0, z0, uo, uy, uo, 22.0, Color("070c22"))
	# Lamps on the fascia, shining down on the court.
	_ring_lights(x0, z0, fo - 0.1, fy - 0.5, 6.0 if not _low else 8.0, 0.5, Color("eaf2ff"), 0.8)
	for i in (2 if _low else 4):
		var x := -18.0 + i * 12.0 if not _low else -12.0 + i * 24.0
		_lamps.append(Vector3(x, fy - 0.45, -z0 - fo))
	_rigs(x0, z0)
	_twinkles(x0, z0, fo, fy, uo, uy)
	_bench(Color("161e4a"), Color("232c66"), Color("29d8ea"))
	if _low:
		return []
	return _front_rows(x0, z0, 0.0, front, first, depth, rise, 9.0, [0, 1, 3])


## The boards round the run-off: a dark frame and a glowing band of plain colour that a slow light sweeps along (no
## brands).
func _boards() -> void:
	var hl := Court.HALF_L + Court.RUNOFF + 0.45
	var hw := Court.HALF_W + Court.RUNOFF + 0.45
	var h := 0.9
	var cols := [Color("1fbcd6"), Color("ff6a1a"), Color("2f6df0")]
	var runs := []   # [from, to, colour index]: each run faces the court (Geo.wall faces right of from -> to)
	for z: float in [-hw, hw]:
		var n := 9
		for i in n:
			var x0 := -hl + (hl * 2.0) * i / n
			var x1 := -hl + (hl * 2.0) * (i + 1) / n
			if z > 0.0 and absf((x0 + x1) * 0.5) < 3.0:
				continue   # the officials' table
			var a := Vector3(x0 + 0.03, 0, z)
			var b := Vector3(x1 - 0.03, 0, z)
			runs.append([a, b, i] if z < 0.0 else [b, a, i + 1])
	runs.append([Vector3(-hl, 0, hw), Vector3(-hl, 0, -hw), 0])
	runs.append([Vector3(hl, 0, -hw), Vector3(hl, 0, hw), 0])
	for r: Array in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var inward := (b - a).cross(Vector3.UP).normalized()
		_lit.wall(a, b, 0.0, h, Color("0b1030"), true)
		_lit.kind = Vector2.ZERO
		_glow.kind = Vector2(VenueLook.LED, 0.15)
		_glow.wall(a + inward * 0.01, b + inward * 0.01, 0.18, h - 0.1, cols[int(r[2]) % 3])
		_glow.kind = Vector2.ZERO
		var t0 := a - inward * 0.08
		_lit.quad(Vector3(a.x, h, a.z), Vector3(t0.x, h, t0.z), Vector3(t0.x + b.x - a.x, h, t0.z + b.z - a.z), Vector3(b.x, h, b.z), Color("1a2350"))


## The roof and the floodlight rigs under it: trusses along both sides and across both ends, each with banks of lamps
## that flare, a glow in the air round them and beams down to the court.
func _rigs(x0: float, z0: float) -> void:
	var h := 15.5
	if not _low:
		_lit.box(Vector3(0, 23.0, 0), Vector3((x0 + 20.0) * 2.0, 0.4, (z0 + 20.0) * 2.0), Color("050a1e"), 0.0, false)
	var bank := Color("e6eeff")
	for sz: float in [-1.0, 1.0]:
		var z := 9.5 * sz
		_lit.box(Vector3(0, h + 0.35, z), Vector3(36.0, 0.5, 0.5), Color("1a2148"))
		for i in 7:
			var x := -15.0 + i * 5.0
			_lit.box(Vector3(x, h, z), Vector3(1.8, 0.5, 0.7), Color("20284f"))
			_glow.floor_rect(x - 0.8, z - 0.3, x + 0.8, z + 0.3, h - 0.26, bank)
			for j: float in [-0.45, 0.45]:
				_fx.sprite(Vector3(x + j, h - 0.35, z - 0.25 * sz), 1.3 if not _low else 1.0, Color("dfe9ff"), 0.9)
			if sz < 0.0 and i % 2 == 1 and _lamps.size() < 8:
				_lamps.append(Vector3(x, h - 0.3, z))
			# The far rig lights the air round it, and on Medium and High throws beams down onto the court.
			if sz < 0.0 and i % 2 == 1:
				_fx.sprite(Vector3(x, h - 0.6, z), 9.0, Color("56689e"), -1.0)
				if not _low:
					_fx.beam(Vector3(x, h - 0.4, z), Vector3(x * 0.85, 0.0, -1.5), 5.0, Color("46558a"))
	for sx: float in [-1.0, 1.0]:
		var x := 20.5 * sx
		_lit.box(Vector3(x, h + 0.35, 0), Vector3(0.5, 0.5, 20.0), Color("1a2148"))
		for i in 3:
			var z := -6.0 + i * 6.0
			_lit.box(Vector3(x, h, z), Vector3(0.7, 0.5, 1.8), Color("20284f"))
			for j: float in [-0.45, 0.45]:
				_fx.sprite(Vector3(x - 0.3 * sx, h - 0.35, z + j), 1.2 if not _low else 0.9, Color("dfe9ff"), 0.9)


## Small lights that come and go in the upper tier: phones, cameras, the stairs' lamps.
func _twinkles(x0: float, z0: float, o0: float, y0: float, o1: float, y1: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in (24 if _low else 70):
		var side := rng.randi_range(0, 3)
		var t := rng.randf_range(0.05, 0.9)
		var o := lerpf(o0, o1, t)
		var y := lerpf(y0, y1, t) + 0.6
		var c0 := _corner(side, x0, z0)
		var c1 := _corner((side + 1) % 4, x0, z0)
		var a := Vector3(c0.x + signf(c0.x) * o, y, c0.y + signf(c0.y) * o)
		var b := Vector3(c1.x + signf(c1.x) * o, y, c1.y + signf(c1.y) * o)
		var col := Color("fff2d6") if rng.randf() < 0.7 else Color("8fe8ff")
		_fx.sprite(a.lerp(b, rng.randf_range(0.05, 0.95)), rng.randf_range(0.1, 0.22), col, 0.0, rng.randf_range(0.05, 1.0))


# ---------------------------------------------------------------- the hall

## The hall on an evening: a timber floor with the court painted on it, padded walls with a band of colour, high
## windows of dusk, pennants, rows of lights in the ceiling, and one stand down the near side.
func _hall() -> Array:
	var night := Color("141a2c")
	_env(night, Color("c8bfb0"), 0.62, Color("fff4e2"), 0.95, Vector3(-62, 25, 0))
	_look = {"night": night, "fade_amt": 0.0, "sheen": 0.3 if _low else 0.38, "gloss": 220.0,
		"vig_size": Vector2(30.0, 20.0), "vig_dark": 0.7, "seat_col": Color("6a4a30"), "stair_col": Color("8a7a66"),
		"density": 0.7, "aisle_every": 8.0, "lamp_col": Color("fff1d8"), "pad": Color("1f8a96"), "stand_tint": Color(0.95, 0.92, 0.88),
		"pool_lo": 0.72, "pool_hi": 1.08, "pool_glow": 0.05}
	_court(Color("3d97a6"), Color("c9a27a"), Color("b48e66"), VenueLook.WOOD)
	_runoff_edge(Color("ff8a3a"))
	var hl := Court.HALF_L + 12.5   # room for the camera behind the goal
	var hw := Court.HALF_W + Court.RUNOFF + 1.0
	var wall := Color("d9d4cc")
	var h := 11.5
	var fz := -hw - 5.0
	# The far wall and the two end walls; the near side has the stand.
	_lit.wall(Vector3(hl, 0, fz), Vector3(-hl, 0, fz), 0, h, wall, true)
	_lit.wall(Vector3(-hl, 0, fz), Vector3(-hl, 0, hw + 7.0), 0, h, wall.darkened(0.08), true)
	_lit.wall(Vector3(hl, 0, hw + 7.0), Vector3(hl, 0, fz), 0, h, wall.darkened(0.08), true)
	# The near wall behind the stand: one-sided, so the broadcast camera beyond it sees through.
	_lit.wall(Vector3(hl, 0, hw + 7.0), Vector3(-hl, 0, hw + 7.0), 0, h, wall.darkened(0.15))
	# Padding low on the walls, a stripe of orange above it, and the high windows at dusk.
	for w: Array in [[Vector3(hl, 0, fz + 0.03), Vector3(-hl, 0, fz + 0.03)], [Vector3(-hl + 0.03, 0, fz), Vector3(-hl + 0.03, 0, hw + 7.0)],
			[Vector3(hl - 0.03, 0, hw + 7.0), Vector3(hl - 0.03, 0, fz)]]:
		_lit.kind = Vector2(VenueLook.GLOSS, 0)
		_lit.wall(w[0], w[1], 0, 2.0, Color("1f8a96"), true)
		_lit.kind = Vector2.ZERO
		_glow.kind = Vector2(VenueLook.LED, 0.1)
		_glow.wall(w[0] + (Vector3(0, 0, 0.01) if w[0].z == w[1].z else Vector3(0.01 * -signf(w[0].x), 0, 0)),
			w[1] + (Vector3(0, 0, 0.01) if w[0].z == w[1].z else Vector3(0.01 * -signf(w[0].x), 0, 0)), 2.0, 2.18, Color("ff7a2a"))
		_glow.kind = Vector2.ZERO
	for i in 7:
		var x := -hl + 4.0 + i * (hl * 2.0 - 8.0) / 6.0
		_lit.wall(Vector3(x + 1.55, 0, fz + 0.04), Vector3(x - 1.55, 0, fz + 0.04), 6.9, 9.6, Color("8a8378"), true)
		_glow.wall(Vector3(x + 1.4, 0, fz + 0.06), Vector3(x - 1.4, 0, fz + 0.06), 7.05, 9.45, Color("4a5f9e"))
		_glow.wall(Vector3(x + 1.4, 0, fz + 0.07), Vector3(x - 1.4, 0, fz + 0.07), 7.05, 7.6, Color("e8946a"))
		_glow.wall(Vector3(x + 0.04, 0, fz + 0.08), Vector3(x - 0.04, 0, fz + 0.08), 7.05, 9.45, Color("8a8378"))
	# A plain scoreboard and pennants of plain colours on the far wall.
	_lit.box(Vector3(0, 4.3, fz + 0.2), Vector3(4.2, 1.6, 0.3), Color("15182a"))
	_glow.kind = Vector2(VenueLook.LED, 0.4)
	for i in 2:
		_glow.wall(Vector3(-0.3 + i * 1.9, 0, fz + 0.37), Vector3(-1.6 + i * 1.9, 0, fz + 0.37), 3.85, 4.75, Color("ffb23a") if i == 0 else Color("29d8ea"))
	_glow.kind = Vector2.ZERO
	if not _low:
		var pc := [Color("ff6a1a"), Color("29b8e0"), Color("f2f2f2"), Color("2f6df0")]
		for i in 26:
			var x := -hl + 1.0 + i * (hl * 2.0 - 2.0) / 25.0
			_lit.quad(Vector3(x - 0.4, 5.6, fz + 0.1), Vector3(x + 0.4, 5.6, fz + 0.1), Vector3(x, 4.9, fz + 0.1), Vector3(x, 4.9, fz + 0.1), pc[i % 4])
		# Wall bars at one end of the far wall.
		for i in 8:
			_lit.box(Vector3(-15.0 + i * 0.5, 2.6, fz + 0.15), Vector3(0.06, 3.0, 0.08), Color("b88a52"))
	# The stand: wooden benches down the near side, a rail in front with a light strip.
	var z0 := hw + 0.4
	var rows := 7
	var depth := 0.8
	var rise := 0.45
	var first := 0
	var front := 0.5
	var ax := hl * 0.8
	_lit.wall(Vector3(ax, 0, z0), Vector3(-ax, 0, z0), 0.0, front, Color("4a3524"), true)
	_glow.kind = Vector2(VenueLook.LED, 0.3)
	_glow.wall(Vector3(-ax, 0, z0 - 0.01), Vector3(ax, 0, z0 - 0.01), front - 0.06, front, Color("ff8a3a"))
	_glow.kind = Vector2.ZERO
	var sb := Vector3(-ax, front, z0)
	_lit.kind = Vector2(VenueLook.STAND, first)
	var slope := Vector2(rows * depth, rows * rise).length()
	_lit.quad(Vector3(ax, front, z0), Vector3(ax, front + rows * rise, z0 + rows * depth), Vector3(-ax, front + rows * rise, z0 + rows * depth), sb,
		Color("6a4a30"), [Vector2(ax, 0), Vector2(ax, slope), Vector2(-ax, slope), Vector2(-ax, 0)])
	_lit.kind = Vector2.ZERO
	for sx: float in [-1.0, 1.0]:
		var e := Vector3(ax * sx, 0, z0)
		_lit.quad(e, e + Vector3(0, front, 0), e + Vector3(0, front + rows * rise, rows * depth), e + Vector3(0, 0, rows * depth), Color("4a3524"))
		_lit.quad(e + Vector3(0, 0, rows * depth), e + Vector3(0, front + rows * rise, rows * depth), e + Vector3(0, front, 0), e, Color("4a3524"))
	# The ceiling and its lights.
	if not _low:
		_lit.box(Vector3(0, h, 0), Vector3(hl * 2.2, 0.2, hw * 3.0), Color("4a4640"))
	for i in 4:
		for j in 3:
			var p := Vector3(-11.0 + i * 7.3, h - 0.12, -8.0 + j * 7.0)
			_glow.box(p, Vector3(2.4, 0.12, 0.5), Color("fffbe8"))
			_fx.sprite(p + Vector3(0, -0.1, 0), 0.9 if not _low else 0.7, Color("fff3dc"), 0.7)
			if j < 2 and i % 1 == 0 and _lamps.size() < 8:
				_lamps.append(p)
	_bench(Color("2a3a4a"), Color("1c6c78"), Color("ff8a3a"))
	# All painted: the stand is behind the cameras, and people of their own there would stand in the low camera's way.
	return []


# ---------------------------------------------------------------- the outdoor court

## The outdoor court on an evening: a blue court on a green surround, a chain-link fence, trees and houses with their
## windows lit under a dusk sky, floodlights on poles; the people stand round the open side and the ends.
func _outdoor() -> Array:
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("0d1a48")
	mat.sky_horizon_color = Color("e98b5c")
	mat.sky_curve = 0.12
	mat.ground_horizon_color = Color("3a3040")
	mat.ground_bottom_color = Color("1a1820")
	mat.sun_angle_max = 8.0
	sky.sky_material = mat
	_env(Color.BLACK, Color("8c94c0"), 0.6, Color("fff1dc"), 1.05, Vector3(-52, -32, 0), sky)
	_look = {"night": Color("0d1a48"), "fade_amt": 0.0, "sheen": 0.22 if _low else 0.28, "gloss": 160.0,
		"vig_size": Vector2(30.0, 22.0), "vig_dark": 0.55, "density": 0.75, "lamp_col": Color("fff4e0"),
		"pad": Color("1b4fa8"), "pool_lo": 0.5, "pool_hi": 1.12 if _low else 0.98, "pool_glow": 0.08}
	_court(Color("6690c8"), Color("4a9a6e"), Color("4a4d56"), VenueLook.ASPHALT)
	var hl := Court.HALF_L + Court.RUNOFF
	var hw := Court.HALF_W + Court.RUNOFF
	# A chain-link fence on posts down the far side, a low one across the ends (the camera behind the goal looks over
	# it); the near side open, with the people standing along it.
	var fz := -hw - 0.5
	var fx := hl + 0.5
	for i in 13:
		var x := -fx + (fx * 2.0) * i / 12.0
		_lit.kind = Vector2(VenueLook.METAL, 0)
		_lit.cylinder(Vector3(x, 0, fz), Vector3(x, 3.2, fz), 0.04, 0.04, Color("8a8e96"), 6)
		_lit.kind = Vector2.ZERO
	_lit.cylinder(Vector3(-fx, 3.2, fz), Vector3(fx, 3.2, fz), 0.03, 0.03, Color("8a8e96"), 4)
	_glow.kind = Vector2(VenueLook.FENCE, 0)
	_glow.quad(Vector3(-fx, 3.2, fz), Vector3(fx, 3.2, fz), Vector3(fx, 0, fz), Vector3(-fx, 0, fz), Color("9aa0aa"),
		[Vector2(-fx, 3.2), Vector2(fx, 3.2), Vector2(fx, 0), Vector2(-fx, 0)])
	for sx: float in [-1.0, 1.0]:
		_glow.quad(Vector3(fx * sx, 1.2, fz), Vector3(fx * sx, 1.2, -fz), Vector3(fx * sx, 0, -fz), Vector3(fx * sx, 0, fz), Color("9aa0aa"),
			[Vector2(fz, 1.2), Vector2(-fz, 1.2), Vector2(-fz, 0), Vector2(fz, 0)])
		_lit.cylinder(Vector3(fx * sx, 1.2, fz), Vector3(fx * sx, 1.2, -fz), 0.03, 0.03, Color("8a8e96"), 4)
	_glow.kind = Vector2.ZERO
	# Trees and low houses beyond, their windows lit, under the evening sky.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in (8 if _low else 18):
		var x := rng.randf_range(-hl - 8.0, hl + 8.0)
		var z := -hw - rng.randf_range(5.0, 16.0)
		var hgt := rng.randf_range(4.0, 8.0)
		_lit.cylinder(Vector3(x, 0, z), Vector3(x, hgt * 0.45, z), 0.18, 0.14, Color("3a2c22"), 5)
		_lit.blob(Vector3(x, hgt * 0.7, z), Vector3(rng.randf_range(1.6, 2.8), hgt * 0.32, rng.randf_range(1.6, 2.8)), Color("244a32").lightened(rng.randf_range(-0.06, 0.08)))
	for i in 4:
		var x := -26.0 + i * 17.0
		var z := -hw - 22.0
		_lit.box(Vector3(x, 2.0, z), Vector3(10.0, 4.0, 6.0), Color("8f8270").darkened(0.08 * i))
		_lit.box(Vector3(x, 4.2, z), Vector3(10.6, 0.4, 6.6), Color("6a2e26"))
		for j in 3:
			_glow.wall(Vector3(x - 3.0 + j * 2.6 + 0.5, 0, z + 3.02), Vector3(x - 3.0 + j * 2.6 - 0.5, 0, z + 3.02), 1.4, 2.5,
				Color("ffc77a") if (i + j) % 3 != 0 else Color("5a6a8a"))
	# The floodlights: poles at the corners and half way along each side, banks of lamps on top.
	for p: Vector2 in [Vector2(-hl - 1.2, -hw - 1.5), Vector2(hl + 1.2, -hw - 1.5), Vector2(-hl - 1.2, hw + 2.5), Vector2(hl + 1.2, hw + 2.5),
			Vector2(0, -hw - 1.5)]:
		var top := 6.2 if p.y < 0.0 else 9.5   # the far ones low enough to be seen from the stand's camera
		_lit.kind = Vector2(VenueLook.METAL, 0)
		_lit.cylinder(Vector3(p.x, 0, p.y), Vector3(p.x, top, p.y), 0.13, 0.09, Color("9aa0aa"), 8)
		_lit.kind = Vector2.ZERO
		var inward := Vector3(-p.x, 0, -p.y).normalized()
		var yaw := atan2(inward.x, inward.z)
		var head := Vector3(p.x, top + 0.3, p.y) + inward * 0.3
		_lit.box(head, Vector3(2.2, 1.0, 0.25), Color("2a2e38"), yaw)
		var side := Vector3(inward.z, 0, -inward.x)
		for r in 2:
			for c in 3:
				var lp := head + inward * 0.14 + side * (-0.7 + c * 0.7) + Vector3(0, -0.22 + r * 0.44, 0)
				_glow.box(lp, Vector3(0.5, 0.34, 0.04), Color("fff6e4"), yaw, false)
				_fx.sprite(lp + inward * 0.1, 0.9 if not _low else 0.7, Color("fff2dc"), 0.8)
		if p.y < 0.0:
			_lamps.append(head)
	_bench(Color("4a4f5c"), Color("2f6df0"), Color("ff8a3a"))
	# The people: standing along the near side and both ends.
	var spots := []
	var lines := [[Vector3(-hl + 0.5, 0, hw + 0.8), Vector3(-8.0, 0, hw + 0.8)], [Vector3(8.0, 0, hw + 0.8), Vector3(hl - 0.5, 0, hw + 0.8)],
		[Vector3(-hl - 0.8, 0, hw - 1.0), Vector3(-hl - 0.8, 0, -hw + 1.0)], [Vector3(hl + 0.8, 0, -hw + 1.0), Vector3(hl + 0.8, 0, hw - 1.0)]]
	if _low:
		# Painted on three upright faces a row deep each (one draw call with the rest).
		for l: Array in lines:
			var a: Vector3 = l[0]
			var b: Vector3 = l[1]
			var back := Vector3(0, 0, 1) if a.z == b.z else Vector3(signf(a.x), 0, 0)
			for k in 2:
				var o := back * (0.6 * k)
				var len_ := a.distance_to(b)
				_lit.kind = Vector2(VenueLook.STANDING, 0)
				_lit.quad(a + o + Vector3(0, 2.2, 0), b + o + Vector3(0, 2.2, 0), b + o, a + o, Color(0, 0, 0, 0),
					[Vector2(k * 0.3, 2.2), Vector2(len_ + k * 0.3, 2.2), Vector2(len_ + k * 0.3, 0), Vector2(k * 0.3, 0)])
				_lit.kind = Vector2.ZERO
		return []
	for r in 3:
		for l: Array in lines:
			var a: Vector3 = l[0]
			var b: Vector3 = l[1]
			var back := Vector3(0, 0, 1) if a.z == b.z else Vector3(signf(a.x), 0, 0)
			var n := int(a.distance_to(b) / 0.55)
			for i in n:
				spots.append(a.lerp(b, (i + 0.5) / n) + back * (r * 0.7) + Vector3(rng.randf_range(-0.2, 0.2), r * 0.2, 0))
	return spots
