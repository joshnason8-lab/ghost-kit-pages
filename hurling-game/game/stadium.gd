class_name Stadium
extends Node3D
## The venue round the pitch, built in code and merged: the structure in one draw call (vertex-coloured, lit per
## vertex), the nets in one more (see-through), the floodlights' lamps in one, the crowd in one (Crowd), the grass and
## its lines in two (Pitch.build). Sky and light for the time of day. The camera's stand is on the near (+z) side,
## so that side has only what the camera can see over: a rail, the dugouts and the advertising-free hoarding.
##   parish   a club's field at dusk: a small covered stand, a grass bank, a rail round the field, ball-stop nets
##            behind the goals, four floodlight masts, the clubhouse, trees and the hills
##   county   a county ground: a long covered stand across the pitch, open terraces at the ends
##   stadium  the national stadium: tall stands on three sides, a terrace at one end
##   night    the county ground under its floodlights

var kind := "county"
var time := "day"
var crowd: Crowd
var home_colours: Array = []

const H := Pitch.HALF_L
const W := Pitch.HALF_W


func _init(venue_id := "county", p_home_colours := []) -> void:
	var v: Array = DB.venue(venue_id)
	kind = String(v[1])
	time = String(v[3])
	home_colours = p_home_colours


func _ready() -> void:
	add_child(Pitch.build(time))
	var g := Geo.new()
	var nets := Geo.new()
	var lamps := Geo.new()
	var spots: Array[Vector3] = []
	_goals(g, nets)
	_countryside(g)
	match kind:
		"parish":
			_parish(g, nets, lamps, spots)
		"stadium":
			_stadium(g, lamps, spots)
		_:
			_county(g, lamps, spots)
	add_child(g.commit(Geo.material(true)))
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	nm.vertex_color_use_as_albedo = true
	nm.albedo_color = Color(1, 1, 1, 0.22)
	add_child(nets.commit(nm))
	if not lamps.verts.is_empty():
		var lm := Geo.material(false)
		add_child(lamps.commit(lm))
	crowd = Crowd.new()
	var palette := home_colours.duplicate()
	crowd.build(spots, Game.crowd_density() * (0.55 if kind == "parish" else 1.0), palette, hash(kind))
	add_child(crowd)
	_environment()


## The goals: two white uprights 6.5 m apart, at least 7 m high, the crossbar 2.5 m up, and the net behind (a fine
## mesh in hurling) from the bar back to the ground about 2 m behind the line.
func _goals(g: Geo, nets: Geo) -> void:
	var white := Color(0.96, 0.96, 0.94)
	var r := Pitch.POST_W * 0.5
	for s: float in [-1.0, 1.0]:
		var x := (H + r) * s
		for zs: float in [-1.0, 1.0]:
			var z := (Pitch.POST_GAP * 0.5 + r) * zs
			g.cylinder(Vector3(x, 0, z), Vector3(x, Pitch.POST_H, z), r, r, white, 8)
		g.cylinder(Vector3(x, Pitch.BAR_H + r, -Pitch.POST_GAP * 0.5), Vector3(x, Pitch.BAR_H + r, Pitch.POST_GAP * 0.5), r, r, white, 8, false)
		# The net's frame and the net.
		var back := x + Pitch.NET_DEPTH * s
		var nc := Color(0.92, 0.92, 0.92)
		var hz := Pitch.POST_GAP * 0.5
		nets.wall(Vector3(x, 0, -hz), Vector3(x, 0, -hz), 0, 0, nc)
		nets._tri_quad(Vector3(x, Pitch.BAR_H, -hz), Vector3(x, Pitch.BAR_H, hz), Vector3(back, 0, hz), Vector3(back, 0, -hz), Vector3(s, 1, 0).normalized(), nc)
		nets._tri_quad(Vector3(x, Pitch.BAR_H, -hz), Vector3(back, 0, -hz), Vector3(back, 0, -hz), Vector3(x, 0, -hz), Vector3(0, 0, -1), nc)
		nets._tri_quad(Vector3(x, Pitch.BAR_H, hz), Vector3(x, 0, hz), Vector3(back, 0, hz), Vector3(back, 0, hz), Vector3(0, 0, 1), nc)
		# A corner flag at each corner, and the flags at the lines (Rule 1.2), as small posts.
		for zs: float in [-1.0, 1.0]:
			for d: float in [0.0, 13.0, 20.0, 45.0, 65.0]:
				var fx := (H - d) * s
				var fz := (W + 1.5) * zs
				g.cylinder(Vector3(fx, 0, fz), Vector3(fx, 1.5, fz), 0.02, 0.02, white, 4, false)
				g.box(Vector3(fx, 1.35, fz + 0.15 * zs), Vector3(0.02, 0.28, 0.3), Color("e8b020") if d == 0.0 else Color("d9d9d9"), 0.0, false)


func _rail(g: Geo, inset: float, h := 1.0) -> void:
	var c := Color("b9bfc4")
	var x := H + inset
	var z := W + inset
	for e in [[Vector3(-x, 0, -z), Vector3(x, 0, -z)], [Vector3(-x, 0, z), Vector3(x, 0, z)],
			[Vector3(-x, 0, -z), Vector3(-x, 0, z)], [Vector3(x, 0, -z), Vector3(x, 0, z)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		g.cylinder(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.03, 0.03, c, 4, false)
		var n := int(a.distance_to(b) / 3.0)
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			g.cylinder(p, p + Vector3(0, h, 0), 0.025, 0.025, c, 4, false)


## A covered stand along x from x0 to x1, its front at z0 (toward the pitch), rows rising away (dir -1: toward -z).
## Rows of people on its steps go into spots.
func _stand(g: Geo, x0: float, x1: float, z0: float, dir: float, rows: int, rise: float, depth: float, col: Color,
		spots: Array[Vector3], roof := true, roof_col := Color("5a6470"), base := 1.2) -> void:
	var seat := col
	for r in rows:
		var z := z0 + dir * (r * depth)
		var y := base + r * rise
		g.box(Vector3((x0 + x1) * 0.5, y * 0.5, z + dir * depth * 0.5), Vector3(x1 - x0, y, depth), seat.darkened(0.05 * float(r % 2)), 0.0)
		var n := int((x1 - x0) / 0.62)
		for i in n:
			spots.append(Vector3(x0 + 0.31 + i * 0.62 + (0.15 if r % 2 == 1 else 0.0), y, z + dir * depth * 0.45))
	var back_z := z0 + dir * rows * depth
	var top := base + rows * rise
	g.box(Vector3((x0 + x1) * 0.5, (top + 3.0) * 0.5, back_z + dir * 0.3), Vector3(x1 - x0, top + 3.0, 0.6), col.darkened(0.3))
	# The ends of the stand.
	for x: float in [x0, x1]:
		g.box(Vector3(x, (top + 3.0) * 0.5, (z0 + back_z) * 0.5), Vector3(0.5, top + 3.0, absf(back_z - z0)), col.darkened(0.25))
	if roof:
		var ry := top + 4.5
		g.box(Vector3((x0 + x1) * 0.5, ry, (z0 + back_z) * 0.5 - dir * 1.5), Vector3(x1 - x0 + 2.0, 0.5, absf(back_z - z0) + 3.0), roof_col)
		var n := int((x1 - x0) / 12.0)
		for i in n + 1:
			var px := lerpf(x0, x1, float(i) / n)
			g.cylinder(Vector3(px, 0, back_z), Vector3(px, ry, back_z), 0.18, 0.18, roof_col.darkened(0.2), 6, false)


## A terrace (open steps, standing) across an end: along z from z0 to z1, its front at x0, rising away (dir).
func _terrace(g: Geo, z0: float, z1: float, x0: float, dir: float, rows: int, col: Color, spots: Array[Vector3]) -> void:
	for r in rows:
		var x := x0 + dir * r * 0.7
		var y := 0.6 + r * 0.32
		g.box(Vector3(x + dir * 0.35, y * 0.5, (z0 + z1) * 0.5), Vector3(0.7, y, z1 - z0), col.darkened(0.04 * float(r % 2)))
		var n := int((z1 - z0) / 0.6)
		for i in n:
			spots.append(Vector3(x + dir * 0.35, y, z0 + 0.3 + i * 0.6 + (0.2 if r % 2 == 1 else 0.0)))
	# Crush barriers every few rows.
	for r in range(3, rows, 4):
		var x := x0 + dir * r * 0.7
		g.cylinder(Vector3(x, 0.6 + r * 0.32 + 1.0, z0), Vector3(x, 0.6 + r * 0.32 + 1.0, z1), 0.04, 0.04, Color("8a9096"), 4, false)


var mast_spots: Array[Vector3] = []   # where the floodlight masts stand (tests: none between the camera and the field)


func _mast(g: Geo, lamps: Geo, p: Vector3, h: float, face: Vector3) -> void:
	mast_spots.append(p)
	g.cylinder(p, p + Vector3(0, h, 0), 0.35, 0.22, Color("9aa2aa"), 6, false)
	var head := p + Vector3(0, h, 0)
	var side := face.cross(Vector3.UP).normalized()
	g.box(head + Vector3(0, 0.8, 0), Vector3(4.0, 2.4, 0.4), Color("6a737c"), atan2(side.x, side.z) + PI * 0.5)
	for i in 3:
		for j in 2:
			var lp := head + side * (float(i) - 1.0) * 1.2 + Vector3(0, 0.2 + j * 1.2, 0) + face * 0.25
			lamps.box(lp, Vector3(0.9, 0.8, 0.9), Color(1.0, 0.97, 0.85) if time != "day" else Color(0.8, 0.8, 0.78), 0.0, false)


func _trees(g: Geo, rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float, n: int) -> void:
	for i in n:
		var p := Vector3(rng.randf_range(x0, x1), 0, rng.randf_range(z0, z1))
		var h := rng.randf_range(7.0, 14.0)
		g.cylinder(p, p + Vector3(0, h * 0.45, 0), 0.25, 0.18, Color("3a2c20"), 5, false)
		var col := Color("2e5a2a").lerp(Color("44703a"), rng.randf())
		# A rounded crown of three tiers, like the ash and sycamore round a field.
		for k in 3:
			var y0 := h * (0.35 + k * 0.18)
			var r := h * (0.34 - k * 0.08)
			g.cylinder(p + Vector3(0, y0, 0), p + Vector3(0, y0 + h * 0.3, 0), r, r * 0.55, col.lightened(0.04 * k), 7)


## The land round the ground, out to the hills: a patchwork of fields in different greens with hedges between them,
## as round any ground in Ireland, so the trees, banks and stands stand on something (round three: "the trees are
## just floating" over the sky's lower half). A little below the pitch, which covers it near the field.
func _countryside(g: Geo) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var greens: Array = {"day": [Color("5a8a3e"), Color("6b9645"), Color("4d7d37"), Color("7a9a4a"), Color("587f3a")],
		"dusk": [Color("5a7d40"), Color("668a46"), Color("4f733b"), Color("738a48"), Color("57773e")],
		"night": [Color("16251a"), Color("1b2c1d"), Color("142218"), Color("1f2f1f"), Color("182819")]}[time]
	var hedge: Color = {"day": Color("2f4f24"), "dusk": Color("33522a"), "night": Color("0b140d")}[time]
	var cell := 90.0
	var reach := 860.0
	var n := int(reach / cell)
	for i in range(-n, n):
		for j in range(-n, n):
			var x0 := i * cell + rng.randf_range(-8.0, 8.0)
			var z0 := j * cell + rng.randf_range(-8.0, 8.0)
			var w := cell + rng.randf_range(-6.0, 10.0)
			var d := cell + rng.randf_range(-6.0, 10.0)
			var c := Vector3(x0 + w * 0.5, -0.09, z0 + d * 0.5)
			if Vector2(c.x, c.z).length() > reach:
				continue
			var col: Color = greens[rng.randi() % greens.size()]
			g.box(c, Vector3(w, 0.1, d), col, 0.0, false)
			# Hedges on two sides of each field (the others come from its neighbours), off the pitch's surrounds.
			if absf(c.x) > H + 30.0 or absf(c.z) > W + 30.0:
				g.box(Vector3(c.x, 0.7, z0), Vector3(w, 1.6, 1.4), hedge, 0.0, false)
				g.box(Vector3(x0, 0.7, c.z), Vector3(1.4, 1.6, d), hedge, 0.0, false)


func _hills(g: Geo, rng: RandomNumberGenerator, r: float, col: Color) -> void:
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var h0 := 14.0 + 26.0 * absf(sin(a0 * 2.3 + 1.0)) + rng.randf() * 6.0
		var h1 := 14.0 + 26.0 * absf(sin(a1 * 2.3 + 1.0)) + rng.randf() * 6.0
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		g._tri_quad(Vector3(p0.x, h0, p0.z), Vector3(p1.x, h1, p1.z), Vector3(p1.x, -1, p1.z), Vector3(p0.x, -1, p0.z), -p0.normalized(), col)


func _parish(g: Geo, nets: Geo, lamps: Geo, spots: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_rail(g, 3.0)
	# The stand on the far side, at the halfway line: a small covered stand of eight rows.
	_stand(g, -22.0, 22.0, -W - 6.0, -1.0, 8, 0.38, 0.75, Color("6d7a86"), spots, true, Color("3f5a6b"), 0.8)
	# The grass bank along the rest of the far side, where people stand.
	for side: float in [-1.0, 1.0]:
		var xa := 26.0 * side
		var xb := (H + 4.0) * side
		var x0 := minf(xa, xb)
		var x1 := maxf(xa, xb)
		for r in 4:
			var z := -W - 5.0 - r * 1.6
			var y := 0.3 + r * 0.55
			g.box(Vector3((x0 + x1) * 0.5, y * 0.5, z), Vector3(x1 - x0, y, 1.6), Color("2f5126").darkened(0.03 * r))
			for i in int((x1 - x0) / 1.4):
				if rng.randf() < 0.6:
					spots.append(Vector3(x0 + 0.7 + i * 1.4 + rng.randf_range(-0.3, 0.3), y, z + rng.randf_range(-0.4, 0.4)))
	# People along the rail on the near side, and the dugouts.
	for i in 90:
		spots.append(Vector3(rng.randf_range(-H, H), 0.0, W + 4.0 + rng.randf_range(0, 1.5)))
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(10.0 * s, 1.1, -W - 3.2), Vector3(8.0, 2.2, 1.6), Color("3a4652"))
	# Ball-stop nets behind each goal: tall poles and a net between them.
	for s: float in [-1.0, 1.0]:
		var x := (H + 9.0) * s
		for z in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			g.cylinder(Vector3(x, 0, z), Vector3(x, 14.0, z), 0.12, 0.1, Color("8a9298"), 5, false)
		nets.wall(Vector3(x, 0, -24.0), Vector3(x, 0, 24.0), 2.0, 14.0, Color(0.55, 0.58, 0.6), true)
		# The rail's end: a low wall behind the goal.
		g.box(Vector3((H + 4.0) * s, 0.5, 0), Vector3(0.3, 1.0, 60.0), Color("8f979e"))
	# The clubhouse behind one goal, and the dressing rooms.
	g.box(Vector3(-H - 22.0, 3.0, -18.0), Vector3(14.0, 6.0, 26.0), Color("d8d2c2"))
	g.box(Vector3(-H - 22.0, 6.4, -18.0), Vector3(15.0, 0.8, 27.0), Color("5a3a2a"))
	# Floodlight masts at the four corners.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# The near side's masts stand back behind the camera's gantry, out of the picture.
			var p := Vector3((H - 10.0) * sx, 0, (W + 9.0) * sz if sz < 0.0 else W + 32.0)
			_mast(g, lamps, p, 24.0, (-p).normalized())
	# Trees, then the hills at dusk.
	_trees(g, rng, -H - 40.0, H + 40.0, -W - 40.0, -W - 18.0, 60)
	_trees(g, rng, H + 16.0, H + 40.0, -W, W, 18)
	_trees(g, rng, -H - 40.0, -H - 16.0, 0, W, 10)
	_hills(g, rng, 560.0, Color("5a5c72"))


func _county(g: Geo, lamps: Geo, spots: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	g.box(Vector3(0, 0.5, -W - 4.5), Vector3(Pitch.LENGTH + 20.0, 1.0, 0.4), Color("1f4a32"))
	g.box(Vector3(0, 0.5, W + 4.5), Vector3(Pitch.LENGTH + 20.0, 1.0, 0.4), Color("1f4a32"))
	# The long covered stand on the far side.
	_stand(g, -62.0, 62.0, -W - 6.0, -1.0, 24, 0.42, 0.8, Color("6a7682"), spots, true, Color("4a5560"), 1.4)
	# The open terraces on the far side beyond it and at both ends.
	for s: float in [-1.0, 1.0]:
		_terrace(g, -W + 2.0, W - 2.0, (H + 8.0) * s, s, 16, Color("8c8f88"), spots)
		for r in 10:
			var x0 := 64.0 * s
			var x1 := (H + 8.0) * s
			var z := -W - 6.0 - r * 0.7
			var y := 0.6 + r * 0.32
			g.box(Vector3((x0 + x1) * 0.5, y * 0.5, z - 0.35), Vector3(absf(x1 - x0), y, 0.7), Color("8c8f88"))
			for i in int(absf(x1 - x0) / 0.6):
				spots.append(Vector3(minf(x0, x1) + 0.3 + i * 0.6, y, z - 0.35))
	# A low stand on the near side, under the camera.
	for r in 6:
		var z := W + 6.0 + r * 0.8
		var y := 0.8 + r * 0.42
		g.box(Vector3(0, y * 0.5, z + 0.4), Vector3(Pitch.LENGTH, y, 0.8), Color("6a7682"))
		for i in 200:
			spots.append(Vector3(-H + 0.35 + i * 0.7, y, z + 0.4))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3((H + 12.0) * sx, 0, (W + 14.0) * sz if sz < 0.0 else W + 32.0)
			_mast(g, lamps, p, 38.0, (-p).normalized())
	_trees(g, rng, -H - 60.0, H + 60.0, -W - 70.0, -W - 40.0, 30)
	_hills(g, rng, 760.0, Color("5d7468") if time != "night" else Color("0c1210"))


func _stadium(g: Geo, lamps: Geo, spots: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	g.box(Vector3(0, 0.6, -W - 5.0), Vector3(Pitch.LENGTH + 30.0, 1.2, 0.4), Color("1f5a3a"))
	g.box(Vector3(0, 0.6, W + 5.0), Vector3(Pitch.LENGTH + 30.0, 1.2, 0.4), Color("1f5a3a"))
	# The far stand: lower and upper tiers, a roof over all.
	_stand(g, -80.0, 80.0, -W - 6.0, -1.0, 22, 0.42, 0.8, Color("6c7884"), spots, false, Color(), 1.4)
	_stand(g, -80.0, 80.0, -W - 26.0, -1.0, 24, 0.6, 0.85, Color("5e6a76"), spots, true, Color("c9ced3"), 11.0)
	# One end: a tall stand; the other: the terrace.
	for r in 30:
		var x := H + 9.0 + r * 0.85
		var y := 1.4 + r * 0.55
		g.box(Vector3(x + 0.42, y * 0.5, 0), Vector3(0.85, y, 100.0), Color("66727e").darkened(0.04 * float(r % 2)))
		for i in 160:
			spots.append(Vector3(x + 0.42, y, -48.0 + i * 0.6))
	g.box(Vector3(H + 36.0, 22.0, 0), Vector3(1.0, 6.0, 104.0), Color("c9ced3"))
	_terrace(g, -50.0, 50.0, -H - 9.0, -1.0, 26, Color("8c8f88"), spots)
	# The near side's lower tier, under the camera.
	for r in 8:
		var z := W + 6.0 + r * 0.8
		var y := 1.4 + r * 0.42
		g.box(Vector3(0, y * 0.5, z + 0.4), Vector3(Pitch.LENGTH + 20.0, y, 0.8), Color("6c7884"))
		for i in 230:
			spots.append(Vector3(-H - 10.0 + 0.35 + i * 0.7, y, z + 0.4))
	# The corners closed with stands at an angle, and lights on the roof's edge.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0]:
			var p := Vector3((H + 14.0) * sx, 0, (W + 14.0) * sz)
			g.box(p + Vector3(0, 12.0, 0), Vector3(18.0, 24.0, 18.0), Color("5e6a76"), PI * 0.25)
	for i in 9:
		var x := lerpf(-78.0, 78.0, float(i) / 8.0)
		lamps.box(Vector3(x, 38.5, -W - 40.0), Vector3(3.0, 0.6, 1.0), Color(1.0, 0.97, 0.85) if time != "day" else Color(0.85, 0.85, 0.82), 0.0, false)
	_hills(g, rng, 800.0, Color("6a7d80"))


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_max_distance = 120.0
	match time:
		"day":
			sm.sky_top_color = Color("4a86c9")
			sm.sky_horizon_color = Color("c9d8e4")
			sm.ground_horizon_color = Color("9fb0a8")
			sun.rotation_degrees = Vector3(-48, 30, 0)
			sun.light_energy = 1.1
			sun.light_color = Color(1.0, 0.97, 0.9)
		"dusk":
			# A summer evening: the sun just down behind the hills, the floodlights coming on.
			sm.sky_top_color = Color("3d5590")
			sm.sky_horizon_color = Color("f2a868")
			sm.ground_horizon_color = Color("6e5a66")
			sm.sky_energy_multiplier = 1.3
			sun.rotation_degrees = Vector3(-38, 160, 0)
			sun.light_energy = 0.95
			sun.light_color = Color(1.0, 0.9, 0.78)
		"night":
			sm.sky_top_color = Color("060a18")
			sm.sky_horizon_color = Color("1a2038")
			sm.ground_horizon_color = Color("0c0f1c")
			sun.rotation_degrees = Vector3(-70, 15, 0)   # the floodlights, really
			sun.light_energy = 0.95
			sun.light_color = Color(1.0, 0.95, 0.85)
	# Below the horizon (what the gantry camera sees past the hills and trees): the horizon's own haze, not the
	# material's default brown.
	sm.ground_bottom_color = sm.ground_horizon_color.darkened(0.15)
	sm.ground_curve = 0.2
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = {"day": Color(0.78, 0.82, 0.9), "dusk": Color(0.7, 0.66, 0.72), "night": Color(0.42, 0.45, 0.58)}[time]
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if int(Game.settings.graphics) >= Game.GFX_MEDIUM:
		env.fog_enabled = true
		env.fog_light_color = sm.sky_horizon_color.lerp(Color(0.75, 0.78, 0.85), 0.6)
		env.fog_density = 0.0009
		env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)
	Crowd.set_light({"day": 1.0, "dusk": 0.72, "night": 0.75}[time])


## What stops a ball behind each goal: [metres behind the end line, half its width, its height]. The parish field's
## ball-stop nets; the terraces and stands at the bigger grounds.
func backstop() -> Vector3:
	match kind:
		"parish":
			return Vector3(9.0, 24.0, 14.0)
		"stadium":
			return Vector3(9.0, W + 8.0, 30.0)
	return Vector3(8.0, W + 8.0, 20.0)


func atmosphere() -> float:
	return {"parish": 0.45, "county": 0.8, "stadium": 1.0}.get(kind, 0.7)
