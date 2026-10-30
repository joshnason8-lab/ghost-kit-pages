class_name Stadium
extends Node3D
## The venue round the pitch, built in code and merged: the structure in one draw call (vertex-coloured, lit per
## vertex), the nets in one more (see-through), the crowd in one (Crowd), the grass and
## its lines in two (Pitch.build). Sky and light for the time of day. The camera's stand is on the near (+z) side,
## so that side has only what the camera can see over: a rail, the dugouts and the advertising-free hoarding.
##   parish   a club's field at dusk: a small covered stand, a grass bank, a rail round the field, ball-stop nets
##            behind the goals, four floodlight masts, the clubhouse, trees, the village beyond
##   county   a county ground: a long covered stand across the pitch, open terraces at the ends
##   stadium  the national stadium: tall stands on three sides, a terrace at one end
##   night    the county ground under its floodlights

var kind := "county"
var time := "day"
var crowd: Crowd
## On Medium and High the nearer fans are whole 3D people (the foundation's WsgCrowd3D), the rest stay cut-outs.
var crowd3d: WsgCrowd3D
var _seats := {}            # spot index -> how far behind the feet the step behind rises above the seat (m; INF: it
                            # does not): a seat in a stand (the 3D fans sit on it and get up)
var _spots: Array[Vector3] = []
## Where the 3D fans go first in a match: the middle of the far stand (the one the television camera looks at).
const CROWD_FOCUS := Vector3(0, 4.0, -Pitch.HALF_W - 12.0)
## A stand's seats: their height over the step the feet are on, and how deep (from the step behind) (m).
const SEAT_H := 0.40
const SEAT_D := 0.35
var scenery: Scenery
var home_colours: Array = []
var away_colours: Array = []    # with them, the crowd is both counties' (a championship day)
var to_sun := Vector3(0.3, 0.8, 0.5).normalized()   # where the light comes from (PlayerShadows reads it)
var net: GoalNet               # the goals' nets (a sliotar into one ripples it)
var structure: MeshInstance3D  # the stands, walls and roofs, built
var baked := false             # drawn under its baked light (Low and Medium: assets/env/light)

const H := Pitch.HALF_L
const W := Pitch.HALF_W


func _init(venue_id := "county", p_home_colours := [], p_away_colours := []) -> void:
	var v: Array = DB.venue(venue_id)
	kind = String(v[1])
	time = String(v[3])
	home_colours = p_home_colours
	away_colours = p_away_colours


func _ready() -> void:
	add_child(Pitch.build(time))
	var g := Geo.new()
	var nets := Geo.new()
	var fields := Geo.new()
	var spots: Array[Vector3] = []
	scenery = Scenery.new(time)
	_goals(g, nets)
	_dugouts(g)
	_countryside(g, fields)
	match kind:
		"parish":
			_parish(g, nets, spots)
		"stadium":
			_stadium(g, spots)
		_:
			_county(g, spots)
	structure = g.commit(Geo.ultra_material() if Ultra.active() else Geo.material(true))
	if Ultra.lit():
		structure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # the stands' shadow on the field
	add_child(structure)
	_baked_light()
	add_child(fields.commit(field_material(time)))
	scenery.commit()
	add_child(scenery)
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	nm.vertex_color_use_as_albedo = true
	nm.albedo_color = Color(1, 1, 1, 0.22)
	add_child(nets.commit(nm))
	net = GoalNet.new()
	net.build(H + Pitch.POST_W * 0.5, time)
	add_child(net)
	crowd = Crowd.new()
	_spots = spots
	build_crowd(CROWD_FOCUS, int(Game.settings.graphics))
	add_child(crowd)
	_environment()


## Low and Medium (and every tier on GL Compatibility but High's): the light baked in Cycles (the shared
## foundation's WsgLightBake: tools/env/bake_light.sh) - the sun and sky on the stands, the roofs' shadow on the
## seats, the corners darker, the stands' shadow on the grass - for one texture read, where the stands were lit per
## vertex without shadows. High draws the scene's own light and shadows.
const LIGHT_DIR := "res://assets/env/light/"


func _baked_light() -> void:
	var grass_m := Pitch.grass_material(time)
	grass_m.set_shader_parameter("shade_on", false)
	baked = false
	if Ultra.lit() or OS.has_environment("WSG_NO_BAKE"):
		return
	var lm := WsgLightBake.load_for(structure.mesh as ArrayMesh, LIGHT_DIR + "%s_%s" % [kind, time])
	if lm.is_empty():
		return
	baked = true
	structure.mesh = lm.mesh
	structure.material_override = WsgLightBake.material(lm, Ultra.renderer_ready())
	if lm.ground != null:
		var r: Array = lm.ground_rect
		grass_m.set_shader_parameter("shade", lm.ground)
		grass_m.set_shader_parameter("shade_rect", Vector4(r[0], r[1], r[2], r[3]))
		grass_m.set_shader_parameter("shade_on", true)


## The crowd: on Medium and High the 3D fans take the spots nearest focus (as many as quality's budget: 1 Medium,
## 2 High, 3 Close - a practice or a shoot-out, the camera near one goal and few players to draw), the cut-outs the
## rest; on Low all cut-outs. Built again when the camera's place changes (the shoot-out, the practice: behind the
## goal they shoot at).
func build_crowd(focus: Vector3, quality: int) -> void:
	var palette := home_colours.duplicate()
	var density := Game.crowd_density() * (0.55 if kind == "parish" else 1.0)
	var flat := _spots
	if crowd3d:
		crowd3d.queue_free()
		crowd3d = null
	if quality > Game.GFX_LOW and WsgCrowd3D.available() and not OS.has_environment("WSG_OFF"):
		crowd3d = WsgCrowd3D.new()
		add_child(crowd3d)
		var facings := _spots.map(func(p): return Crowd.facing_at(p))
		var seated := []
		var room := []
		for i in _spots.size():
			seated.append(SEAT_H if _seats.has(i) else 0.0)
			room.append(_seats.get(i, INF))
		var used := crowd3d.build(_spots, facings, density, hash(kind), seated, quality, focus, room)
		crowd3d.set_teams(home_colours[0], away_colours[0] if not away_colours.is_empty() else home_colours[1])
		var taken := {}
		for i in used:
			taken[i] = true
		flat = []
		for i in _spots.size():
			if not taken.has(i):
				flat.append(_spots[i])
	crowd.build(flat, density, palette, hash(kind),
		away_colours if kind != "parish" else [], 0.75 if kind != "parish" and not away_colours.is_empty() else 0.45)


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
		# The net's frame: a white bar on the ground across the back and one down each side from the bar's ends (the
		# net itself is GoalNet, added in _ready).
		var back := x + Pitch.NET_DEPTH * s
		var hz := Pitch.POST_GAP * 0.5
		var fr := 0.025
		g.cylinder(Vector3(back, fr, -hz), Vector3(back, fr, hz), fr, fr, white, 6, false)
		for zs: float in [-1.0, 1.0]:
			g.cylinder(Vector3(x, Pitch.BAR_H, hz * zs), Vector3(back, fr, hz * zs), fr, fr, white, 6, false)
			g.cylinder(Vector3(x, fr, hz * zs), Vector3(back, fr, hz * zs), fr, fr, white, 6, false)
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
	# The far side's rail stops at the dugouts (they stand in its line) and goes on between them.
	var gap := Bench.FIRST + (Bench.SEATS - 1) * Bench.STEP + 1.0
	var gap_in := Bench.FIRST - 1.0
	for e in [[Vector3(-x, 0, -z), Vector3(-gap, 0, -z)], [Vector3(-gap_in, 0, -z), Vector3(gap_in, 0, -z)],
			[Vector3(gap, 0, -z), Vector3(x, 0, -z)], [Vector3(-x, 0, z), Vector3(x, 0, z)],
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
		# The seats: a bench along the back of the step, against the step behind (the 3D fans sit on it; the owner:
		# "the crowd is still 'in' the seats" - they sat on nothing, half into the step behind).
		# (Not with WSG_OFF, the game as it was: the pilot's before.)
		if not OS.has_environment("WSG_OFF"):
			g.box(Vector3((x0 + x1) * 0.5, y + SEAT_H * 0.5, z + dir * (depth - SEAT_D * 0.5)), Vector3(x1 - x0, SEAT_H, SEAT_D),
				col.lightened(0.16).darkened(0.06 * float(r % 2)), 0.0)
		# How far behind the feet the step behind (or the back wall) rises above the seat: a fan sitting back into it
		# comes forward.
		var behind := depth * 0.55 if rise > SEAT_H or r == rows - 1 else INF
		# (A seat every 0.62 m; with the HD pack 0.52 m, as close as real seats: a fuller stand.)
		var gap := 0.52 if Ultra.active() else 0.62
		var n := int((x1 - x0) / gap)
		for i in n:
			spots.append(Vector3(x0 + gap * 0.5 + i * gap + (0.15 if r % 2 == 1 else 0.0), y, z + dir * depth * 0.45))
			_seats[spots.size() - 1] = behind
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


func _mast(g: Geo, p: Vector3, h: float, face: Vector3) -> void:
	mast_spots.append(p)
	g.cylinder(p, p + Vector3(0, h, 0), 0.35, 0.22, Color("9aa2aa"), 6, false)
	# The lamp array on top (the Meshy floodlight, 4.5 m across), aimed down at the field.
	scenery.add("floodlight", p + Vector3(0, h + 1.6, 0), atan2(face.x, face.z), 2.4, deg_to_rad(22.0))


## The dugouts on the far touchline either side of halfway, where the substitutes sit (Bench) and come on: a
## shelter (back wall, sides and a sloping roof) with a row of wooden benches in it, facing the field.
func _dugouts(g: Geo) -> void:
	var shell := Color("2c3640")
	var roof := Color("8a96a0")
	for sx: float in [-1.0, 1.0]:
		var x0 := sx * (Bench.FIRST - 0.9)
		var x1 := sx * (Bench.FIRST + (Bench.SEATS - 1) * Bench.STEP + 0.9)
		var cx := (x0 + x1) * 0.5
		var w := absf(x1 - x0)
		var back := Bench.SEAT_Z - 0.85
		g.box(Vector3(cx, 1.15, back), Vector3(w, 2.3, 0.15), shell)
		for x: float in [x0, x1]:
			g.box(Vector3(x, 1.1, back + 0.95), Vector3(0.12, 2.2, 1.9), shell)
		g.box(Vector3(cx, 2.3, back + 1.0), Vector3(w + 0.3, 0.08, 2.2), roof)
		for i in int(w / 1.2):
			scenery.add("painted_bench_low", Vector3(minf(x0, x1) + 0.65 + i * 1.2, 0, Bench.SEAT_Z - 0.05), 0.0)


## Trees as Irish grounds have them round the field: oak and the darker broadleaves (ash, sycamore), cut-outs of
## the shared models, 8 to 15 m tall.
func _trees(rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float, n: int) -> void:
	for i in n:
		var p := Vector3(rng.randf_range(x0, x1), 0, rng.randf_range(z0, z1))
		var h := rng.randf_range(8.0, 15.0)
		var oak := rng.randf() < 0.55
		scenery.add("oak_tree_card" if oak else "broadleaf_tree_dark_card", p, rng.randf() * TAU, h / (14.28 if oak else 11.22))


## The land round the ground, out to the horizon: a patchwork of fields in different greens (the photo-scanned
## leafy grass in each field's colour) with hedgerows between them, as round any ground in Ireland, so the trees,
## banks and stands stand on something. Near the ground the hedgerows are plants (bushes of the small broadleaf,
## wispy grass, ferns and clumps along the bottom, now and then a tree); far off, where they are a line in the haze,
## a low dark bank. A little below the pitch, which covers it near the field.
func _countryside(g: Geo, fields: Geo) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var greens: Array = {"day": [Color("5a8a3e"), Color("6b9645"), Color("4d7d37"), Color("7a9a4a"), Color("587f3a")],
		"dusk": [Color("5a7d40"), Color("668a46"), Color("4f733b"), Color("738a48"), Color("57773e")],
		"night": [Color("16251a"), Color("1b2c1d"), Color("142218"), Color("1f2f1f"), Color("182819")]}[time]
	var hedge: Color = {"day": Color("2f4f24"), "dusk": Color("33522a"), "night": Color("0b140d")}[time]
	var cell := 90.0
	var reach := 860.0
	var n := int(reach / cell)
	# Under the patchwork, the land itself, so no sky shows in the gaps between fields.
	fields.box(Vector3(0, -0.17, 0), Vector3(reach * 2.0 + 200.0, 0.05, reach * 2.0 + 200.0), greens[2].darkened(0.08), 0.0, false)
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
			fields.box(c, Vector3(w, 0.1, d), col, 0.0, false)
			# Hedges on two sides of each field (the others come from its neighbours), off the pitch's surrounds.
			if (absf(c.x) > H + 30.0 or absf(c.z) > W + 30.0) and not (kind == "parish" and LAKE.grow(20.0).has_point(Vector2(c.x, c.z))):
				var near := Vector2(c.x, c.z).length() < HEDGE_PLANTS
				for e in [[Vector3(x0, 0, z0), Vector3(x0 + w, 0, z0)], [Vector3(x0, 0, z0), Vector3(x0, 0, z0 + d)]]:
					if near:
						_hedgerow(rng, e[0], e[1])
					else:
						var mid: Vector3 = (e[0] + e[1]) * 0.5
						var size := Vector3(w, 1.6, 1.4) if (e[1] as Vector3).x != (e[0] as Vector3).x else Vector3(1.4, 1.6, d)
						g.box(mid + Vector3(0, 0.7, 0), size, hedge, 0.0, false)


const HEDGE_PLANTS := 420.0   # m: hedgerows nearer than this are plants, further a dark bank
const LAKE := Rect2(-300.0, -325.0, 520.0, 150.0)   # the parish field's lough (x, z): no hedges across it
const VILLAGE := Rect2(-225.0, -142.0, 450.0, 48.0)  # the parish field's road and village: no hedge through a house


## A hedgerow from a to b: bushes a few metres tall close together, grasses and ferns along the foot (near the
## ground only), and a tree standing out of it every so often.
func _hedgerow(rng: RandomNumberGenerator, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var side := Vector3(-dir.z, 0, dir.x)
	var t := rng.randf_range(0.0, 4.0)
	var clear := VILLAGE if kind == "parish" else Rect2()
	while t < length:
		var p := a + dir * t + side * rng.randf_range(-0.6, 0.6)
		if clear.has_point(Vector2(p.x, p.z)):
			t += 5.0
			continue
		scenery.add("small_broadleaf_card", p, rng.randf() * TAU, rng.randf_range(0.3, 0.46))
		if rng.randf() < 0.06:
			var oak := rng.randf() < 0.5
			scenery.add("oak_tree_card" if oak else "broadleaf_tree_dark_card", p + side * 1.5, rng.randf() * TAU, rng.randf_range(0.6, 0.95))
		t += rng.randf_range(4.5, 7.5)
	if a.length() > 260.0:
		return
	t = rng.randf_range(0.0, 2.0)
	var foot := ["grass_wispy_card", "grass_clumps_card", "fern_card"]
	while t < length:
		var p := a + dir * t + side * rng.randf_range(-1.4, 1.4)
		if clear.has_point(Vector2(p.x, p.z)):
			t += 2.5
			continue
		scenery.add(foot[rng.randi() % foot.size()], p, rng.randf() * TAU, rng.randf_range(0.8, 1.4))
		t += rng.randf_range(2.0, 3.6)


static var _field_mats := {}


## The fields: the photo-scanned leafy grass, in each field's own green (the vertex colour), unlit in the time of
## day's light as the pitch is. Two sizes of the texture over each other so the tiling does not show from the gantry.
static func field_material(t: String) -> ShaderMaterial:
	var key := "%s|%d" % [t, int(Game.settings.graphics)]
	if _field_mats.has(key):
		return _field_mats[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform float light = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 a = mix(texture(tex, wp.xz / 4.0).rgb, texture(tex, wp.xz / 23.0 + vec2(0.3, 0.7)).rgb, 0.5);
	float MEAN_LUM = max(dot(textureLod(tex, vec2(0.5), 10.0).rgb, vec3(0.2126, 0.7152, 0.0722)), 0.002);   // its 1 x 1 mip
	float k = dot(a, vec3(0.2126, 0.7152, 0.0722)) / MEAN_LUM;
	ALBEDO = compat_to_scene(mix(COLOR.rgb * k, a * (dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)) / MEAN_LUM), 0.3) * light);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", load(Game.hd("res://assets/env/ground/leafy_grass_albedo_1k.jpg")))
	m.set_shader_parameter("light", {"day": 0.95, "dusk": 0.8, "night": 0.85}.get(t, 1.0))
	_field_mats[key] = m
	return m


func _parish(g: Geo, nets: Geo, spots: Array[Vector3]) -> void:
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
			_mast(g, p, 24.0, (-p).normalized())
	# Trees round the field.
	_trees(rng, -H - 40.0, H + 40.0, -W - 40.0, -W - 18.0, 60)
	_trees(rng, H + 16.0, H + 40.0, -W, W, 18)
	_trees(rng, -H - 40.0, -H - 16.0, 0, W, 10)
	# The village beyond the far hedge: thatched cottages along the road and a terrace of houses, facing the field;
	# the road itself with its lamps; a dry-stone wall of mossy rocks along the ground's far boundary.
	var road_z := -W - 58.0
	g.box(Vector3(0, -0.03, road_z), Vector3(520.0, 0.08, 6.5), Color("4a4d50") if time != "night" else Color("1c1e20"), 0.0, false)
	for x: float in [-150.0, -105.0, 95.0, 160.0]:
		var p := Vector3(x + rng.randf_range(-6, 6), 0, road_z - 13.0 - rng.randf_range(0, 6))
		scenery.add("house_cottage", p, Scenery.facing(p, Vector3(p.x, 0, 0)) + rng.randf_range(-0.15, 0.15))
	for x: float in [-30.0, 10.0]:
		var p := Vector3(x, 0, road_z - 16.0)
		scenery.add("house_row", p, 0.0)
	for i in 14:
		var p := Vector3(-195.0 + i * 30.0, 0, road_z + 4.2)
		scenery.add("street_lamp_tall_low", p, PI, 1.6)
	for i in 18:
		scenery.add("mossy_rocks_low", Vector3(-H - 30.0 + i * 9.5, 0, -W - 44.0 + rng.randf_range(-0.6, 0.6)), rng.randf_range(-0.2, 0.2) + (PI if i % 2 else 0.0), rng.randf_range(0.8, 1.0))
	# A lough beyond the village, as many clubs have: it catches the sunset.
	add_child(_lake(Vector3(LAKE.get_center().x, 0.02, LAKE.get_center().y), LAKE.size))
	# Benches by the clubhouse.
	for i in 3:
		var p := Vector3(-H - 13.5, 0, -24.0 + i * 6.0)
		scenery.add("park_bench_low", p, PI * 0.5)


## Pitchside advertising boards' faces at z (facing the field: dir +1 faces +z), panels of a few colours as a
## board's ads change along it; the county ground's in its painted greens and whites rather than lit.
func _boards(g: Geo, z: float, dir: float, length: float, h := 1.0, painted := false) -> void:
	var cols := [Color("b0287e"), Color("7a2a9a"), Color("d0388e"), Color("5c2a8a")] if not painted \
		else [Color("2a6a44"), Color("e8e4d8"), Color("1f4a32"), Color("c8b45a")]
	var n := int(length / 6.0)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * (length / n)
		g.box(Vector3(x, h * 0.55, z + dir * 0.02), Vector3(length / n - 0.15, h * 0.8, 0.04), cols[(i * 7 + 3) % cols.size()])


## The terracotta strip between the grass and the boards (the national stadium's).
func _perimeter(g: Geo, z0: float, z1: float) -> void:
	g.floor_rect(-H - 12.0, z0, H + 12.0, z1, 0.02, Color("7a4636"))


## A cantilevered roof's white truss: a deep beam along its front edge and a rib every 10 m arching back over it.
func _truss(g: Geo, x0: float, x1: float, front_z: float, back_z: float, y: float) -> void:
	var white := Color("e6eaee")
	g.box(Vector3((x0 + x1) * 0.5, y - 0.4, front_z), Vector3(x1 - x0, 1.6, 0.5), white)
	var n := int((x1 - x0) / 10.0)
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var mid := Vector3(x, y + 3.2, lerpf(front_z, back_z, 0.4))
		g.cylinder(Vector3(x, y + 0.4, front_z), mid, 0.22, 0.22, white, 5, false)
		g.cylinder(mid, Vector3(x, y + 0.4, back_z), 0.22, 0.22, white, 5, false)


func _county(g: Geo, spots: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	g.box(Vector3(0, 0.5, -W - 4.5), Vector3(Pitch.LENGTH + 20.0, 1.0, 0.4), Color("1f4a32"))
	g.box(Vector3(0, 0.5, W + 4.5), Vector3(Pitch.LENGTH + 20.0, 1.0, 0.4), Color("1f4a32"))
	if int(Game.settings.graphics) > Game.GFX_LOW:
		_boards(g, -W - 4.28, 1.0, Pitch.LENGTH + 20.0, 0.85, true)
		_boards(g, W + 4.28, -1.0, Pitch.LENGTH + 20.0, 0.85, true)
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
			_mast(g, p, 38.0, (-p).normalized())
	_trees(rng, -H - 60.0, H + 60.0, -W - 70.0, -W - 40.0, 30)
	# The county town round the ground: terraced rows on the streets behind the ends and beyond the far stand, the
	# street lamps outside.
	_town(rng, H + 34.0, 120.0)


func _stadium(g: Geo, spots: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# The advertising boards round the field, lit magenta and purple as the national stadium's are (no names).
	g.box(Vector3(0, 0.6, -W - 5.0), Vector3(Pitch.LENGTH + 30.0, 1.2, 0.4), Color("6a1f55"))
	g.box(Vector3(0, 0.6, W + 5.0), Vector3(Pitch.LENGTH + 30.0, 1.2, 0.4), Color("6a1f55"))
	var hd := int(Game.settings.graphics) > Game.GFX_LOW
	if hd:
		_boards(g, -W - 4.78, 1.0, Pitch.LENGTH + 30.0)
		_boards(g, W + 4.78, -1.0, Pitch.LENGTH + 30.0)
		_perimeter(g, W + 2.6, W + 4.8)
		_perimeter(g, -W - 4.8, -W - 2.6)
	# The far stand: lower and upper tiers, a roof over all; on Medium and High the level of boxes between them
	# (a band of glass), a lit ribbon on the upper tier's front, and the roof's white truss (Croke Park's look).
	var upper := 14.0 if hd else 11.0
	_stand(g, -80.0, 80.0, -W - 6.0, -1.0, 22, 0.42, 0.8, Color("6c7884"), spots, false, Color(), 1.4)
	_stand(g, -80.0, 80.0, -W - 26.0, -1.0, 24, 0.6, 0.85, Color("5e6a76"), spots, true, Color("c9ced3"), upper)
	if hd:
		var lower_top := 1.4 + 22 * 0.42
		g.box(Vector3(0, (lower_top + upper) * 0.5, -W - 25.95), Vector3(160.0, upper - lower_top, 0.1), Color("1b2a3a"))
		for i in 41:
			g.box(Vector3(-80.0 + i * 4.0, (lower_top + upper) * 0.5, -W - 25.88), Vector3(0.12, upper - lower_top, 0.08), Color("c9ced3"))
		g.box(Vector3(0, upper - 0.35, -W - 25.86), Vector3(160.0, 0.7, 0.12), Color("b0287e"))
		g.box(Vector3(0, lower_top + 0.3, -W - 23.55), Vector3(160.0, 0.6, 0.12), Color("5c2a8a"))
		_truss(g, -81.0, 81.0, -W - 23.0, -W - 49.4, upper + 24 * 0.6 + 4.5)
	# One end: a tall stand; the other: the terrace.
	for r in 30:
		var x := H + 9.0 + r * 0.85
		var y := 1.4 + r * 0.55
		g.box(Vector3(x + 0.42, y * 0.5, 0), Vector3(0.85, y, 100.0), Color("66727e").darkened(0.04 * float(r % 2)))
		# Seats, as the stands' (the fans sit on them; the step behind is a backrest).
		if not OS.has_environment("WSG_OFF"):
			g.box(Vector3(x + 0.85 - SEAT_D * 0.5, y + SEAT_H * 0.5, 0), Vector3(SEAT_D, SEAT_H, 100.0),
				Color("66727e").lightened(0.16).darkened(0.06 * float(r % 2)))
		for i in 160:
			spots.append(Vector3(x + 0.42, y, -48.0 + i * 0.6))
			_seats[spots.size() - 1] = 0.43
	g.box(Vector3(H + 36.0, 22.0, 0), Vector3(1.0, 6.0, 104.0), Color("c9ced3"))
	_terrace(g, -50.0, 50.0, -H - 9.0, -1.0, 26, Color("8c8f88"), spots)
	# The near side's lower tier, under the camera.
	for r in 8:
		var z := W + 6.0 + r * 0.8
		var y := 1.4 + r * 0.42
		g.box(Vector3(0, y * 0.5, z + 0.4), Vector3(Pitch.LENGTH + 20.0, y, 0.8), Color("6c7884"))
		for i in 230:
			spots.append(Vector3(-H - 10.0 + 0.35 + i * 0.7, y, z + 0.4))
	# The corners closed with stands at an angle (the owner: "two big black blocks in the corners ... make those into
	# something"): seats and a crowd, and over them the press box at one corner and the big screen at the other.
	for sx: float in [-1.0, 1.0]:
		_corner(g, sx, spots, sx > 0.0, hd)
	# Floodlights along the front of the far stand's roof, aimed down at the field.
	for i in 7:
		var x := lerpf(-72.0, 72.0, float(i) / 6.0)
		scenery.add("floodlight", Vector3(x, 31.2 + (3.0 if hd else 0.0), -W - 23.5), 0.0, 1.8, deg_to_rad(35.0))
	# Dublin's terraced streets round the national stadium, on the skyline beyond the stands.
	_town(rng, H + 52.0, 170.0)


## A corner of the national stadium, between the far stand and an end (sx -1 the left, 1 the right): tiers of seats
## angled to the field with their crowd, a back wall to the height of the stands round it, and on top a glazed press
## and media box under a flat roof, its front lit (press) or the big screen in a dark frame (screen).
func _corner(g: Geo, sx: float, spots: Array[Vector3], press: bool, hd: bool) -> void:
	var c := Vector3((H + 12.0) * sx, 0, -(W + 12.0))
	var toward := Vector3(-sx, 0, 1).normalized()      # to the field
	var along := Vector3(1, 0, sx).normalized()         # across the corner
	var yaw := -sx * PI * 0.25
	var rows := 20
	var width := 24.0
	var top := 1.4 + rows * 0.6
	for r in rows:
		var y := 1.4 + r * 0.6
		var at := c - toward * (r * 0.85 + 0.42)
		g.box(at + Vector3(0, y * 0.5, 0), Vector3(width + r * 0.9, y, 0.85), Color("66727e").darkened(0.04 * float(r % 2)), yaw)
		var n := int((width + r * 0.9 - 0.8) / 0.72)
		for i in n:
			spots.append(at + along * (-(width + r * 0.9) * 0.5 + 0.4 + i * 0.72) + Vector3(0, y, 0))
	# The back: a wall up to the box, the stands' grey.
	var back := c - toward * (rows * 0.85 + 0.8)
	g.box(back + Vector3(0, (top + 9.0) * 0.5, 0), Vector3(width + rows * 0.9 + 2.0, top + 9.0, 1.6), Color("5e6a76"), yaw)
	var box_c := back + toward * 3.2 + Vector3(0, top + 4.6, 0)
	var bw := width + rows * 0.9 - 2.0
	if press:
		# The press box: a band of glass in white mullions, a lit fascia, a flat roof with a lip.
		g.box(box_c, Vector3(bw, 7.0, 5.6), Color("2f3b48"), yaw)
		g.box(box_c + toward * 2.82, Vector3(bw - 0.6, 4.2, 0.08), Color("1b2a3a"), yaw)
		for i in int(bw / 2.4) + 1:
			g.box(box_c + toward * 2.88 + along * (-bw * 0.5 + 0.3 + i * 2.4), Vector3(0.14, 4.4, 0.08), Color("e6e9ec"), yaw)
		g.box(box_c + toward * 2.9 + Vector3(0, -2.6, 0), Vector3(bw, 0.6, 0.1), Color("b0287e"), yaw)
		g.box(box_c + Vector3(0, 3.7, 0) + toward * 0.4, Vector3(bw + 1.0, 0.4, 7.2), Color("c9ced3"), yaw)
	else:
		# The big screen: a deep frame on legs over the seats, its face a dark glow in the ground's colours.
		g.box(box_c + Vector3(0, 0.8, 0), Vector3(bw * 0.8, 9.0, 1.8), Color("22272d"), yaw)
		g.box(box_c + Vector3(0, 0.8, 0) + toward * 0.92, Vector3(bw * 0.8 - 1.2, 7.8, 0.06), Color("142b3a"), yaw)
		if hd:
			for k in 3:
				g.box(box_c + Vector3(0, -1.8 + k * 2.6, 0) + toward * 0.96, Vector3(bw * 0.8 - 1.6, 0.5, 0.04),
					[Color("5c2a8a"), Color("b0287e"), Color("1f6f8b")][k], yaw)
		for lx in [-0.3, 0.3]:
			g.box(back + toward * 2.0 + along * (lx * bw) + Vector3(0, top * 0.5, 0), Vector3(0.6, top, 0.6), Color("9aa2aa"), yaw)


## A stretch of water: the shared water normal map scrolled two ways at once, the sky's horizon colour in it at a
## low angle and the lough's own dark green-grey looking down (Fresnel); unlit, no real-time reflection.
func _lake(c: Vector3, size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D waves : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep = vec3(0.10, 0.14, 0.15);
uniform vec3 sky = vec3(0.9, 0.7, 0.6);
uniform float light = 1.0;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// A lough's shore, not a rectangle: an oval with a ragged edge.
	vec2 q = UV * 2.0 - 1.0;
	float edge = length(q) + (noise(UV * 7.0) - 0.5) * 0.35 + (noise(UV * 23.0) - 0.5) * 0.08;
	if (edge > 0.95) { discard; }
	vec2 uv = wp.xz / 14.0;
	vec3 n1 = texture(waves, uv + vec2(TIME * 0.012, TIME * 0.007)).rgb * 2.0 - 1.0;
	vec3 n2 = texture(waves, uv * 1.7 - vec2(TIME * 0.009, -TIME * 0.011)).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(n1.x + n2.x, 3.0, n1.y + n2.y));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	vec3 refl = sky * (0.55 + 0.45 * clamp(n.x * 3.0 + 0.5, 0.0, 1.0));
	vec3 c = mix(deep, refl, clamp(fres * 0.85, 0.0, 0.7));
	c = mix(c * 0.8, c, smoothstep(0.95, 0.7, edge));   // darker in the shallows by the bank
	ALBEDO = compat_to_scene(c * light);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("waves", load("res://assets/env/water/water_normal_512.png"))
	var d: Dictionary = _sky_data_for(sky_name())
	var hc: Array = d.horizon
	var hz := Color(hc[0], hc[1], hc[2]).lerp(Color(0.62, 0.64, 0.74), 0.5)
	m.set_shader_parameter("sky", Vector3(hz.r, hz.g, hz.b))     # (plain values: look.gdshaderinc)
	m.set_shader_parameter("deep", Vector3(0.07, 0.1, 0.11))
	m.set_shader_parameter("light", Scenery.light(time).v)
	mi.material_override = m
	return mi


static func _sky_data_for(name: String) -> Dictionary:
	if _sky_data.is_empty():
		_sky_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/env/sky/skies.json"))
	return _sky_data[name]


## Terraced rows on the streets round a ground in a town: across both ends at x = ±end, facing in, and along the
## far side beyond the stand at z = -far; street lamps along the kerb in front of the ends' rows.
func _town(rng: RandomNumberGenerator, end: float, far: float) -> void:
	for sx: float in [-1.0, 1.0]:
		for i in 4:
			var p := Vector3(sx * (end + rng.randf_range(0, 3)), 0, -45.0 + i * 31.0)
			scenery.add("house_row", p, -sx * PI * 0.5)
		for i in 8:
			scenery.add("street_lamp_tall_low", Vector3(sx * (end - 6.0), 0, -56.0 + i * 16.0), -sx * PI * 0.5, 1.6)
	for i in 9:
		var p := Vector3(-124.0 + i * 31.0, 0, -far - rng.randf_range(0, 4))
		scenery.add("house_row", p, 0.0)


## Each ground's sky: a real one (Poly Haven's skies, as 2K panoramas): the parish field under a Northern Irish
## sunset, the county ground under Irish grey cloud, the national stadium on a bright final day with summer cumulus,
## the county ground at night under a cloudy sky lit by the town. (The shared "suburban football field" sky was
## not used: its horizon is a German town's red-tiled roofs.)
const SKY := {"dusk": "belfast_sunset_puresky", "day": "kloofendal_overcast_puresky", "stadium": "kloofendal_48d_partly_cloudy_puresky",
	"night": "kloppenheim_07_puresky"}
## Where each sky's sun should be seen from (its compass direction, x and z): at dusk low in the far left of the
## camera's view, the glow behind the far side; by day behind the camera's right shoulder, so the field is lit from
## the front; at night the town's glow beyond the far side.
const SUN_AT := {"dusk": Vector2(-0.55, -1.0), "day": Vector2(0.6, 1.0), "night": Vector2(0.3, -1.0)}

static var _sky_data := {}


func sky_name() -> String:
	return SKY["stadium"] if kind == "stadium" and time == "day" else SKY[time]


func _environment() -> void:
	var name := sky_name()
	var d: Dictionary = _sky_data_for(name)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := PanoramaSkyMaterial.new()
	sm.panorama = load("res://assets/env/sky/%s_sky_2k.jpg" % name)
	sm.filter = true
	# The night sky's photograph is exposed for the day's eye: darkened to sit over a floodlit field.
	sm.energy_multiplier = 0.32 if time == "night" else 1.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY if int(Game.settings.graphics) >= Game.GFX_HIGH else Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Turn the sky so its sun is where SUN_AT wants it (the panorama's u = 0.5 is +z, u = 0.25 is +x).
	var sun_yaw := (0.5 - float(d.sun_u)) * TAU
	var want: Vector2 = SUN_AT[time]
	var turn := atan2(want.x, want.y) - sun_yaw
	env.sky_rotation = Vector3(0, turn, 0)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_max_distance = 120.0
	# The sun's light comes from its place in the sky, but never lower than 28 degrees (a sunset's grazing light
	# would leave the stands black); at night the floodlights, from high up.
	var elev := deg_to_rad(clampf(float(d.sun_elevation), 28.0, 60.0)) if time != "night" else deg_to_rad(70.0)
	var az := sun_yaw + turn
	to_sun = Vector3(sin(az) * cos(elev), sin(elev), cos(az) * cos(elev))
	sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	var sc: Array = d.sun_colour
	sun.light_color = Color(1.0, 0.95, 0.85) if time == "night" else Color(sc[0], sc[1], sc[2]).lerp(Color.WHITE, 0.45)
	sun.light_energy = {"day": 1.1, "dusk": 0.95, "night": 0.95}[time]
	# The ambient light: the sky's own colour (from its HDR, tools/env/sky_light.py), at the game's strength.
	var ac: Array = d.ambient
	var sky_amb := Color(ac[0], ac[1], ac[2])
	var base: Color = {"day": Color(0.78, 0.82, 0.9), "dusk": Color(0.7, 0.66, 0.72), "night": Color(0.42, 0.45, 0.58)}[time]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(base.r * sky_amb.r, base.g * sky_amb.g, base.b * sky_amb.b).lerp(base, 0.4)
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if int(Game.settings.graphics) >= Game.GFX_MEDIUM:
		var hc: Array = d.horizon
		env.fog_enabled = true
		# The haze: the horizon's colour, cooled (a sunset's orange over everything reads as smoke).
		env.fog_light_color = Color(hc[0], hc[1], hc[2]).lerp(Color(0.72, 0.75, 0.82), 0.5 if time == "day" else 0.75) * (0.35 if time == "night" else 1.0)
		env.fog_density = 0.0009 if time == "day" else 0.0006
		env.fog_sky_affect = 0.0
	if Ultra.lit():
		_ultra_light(env, sun, sky)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)
	Crowd.set_light({"day": 1.0, "dusk": 0.72, "night": 0.75}[time])


## High's light (on Vulkan): the sun's real shadows over the whole ground in four cascades, soft at the
## edges, the stands' shadow across the field as on a summer afternoon; the sky's own light and reflections; ACES
## tone mapping and a glow on what is brightest (the floodlights, the sun on white); at night the floodlights' beams
## from the masts or the stand's roof. (SSAO is not in the Mobile renderer: the players' and stands' own shading
## stands in for it.)
func _ultra_light(env: Environment, sun: DirectionalLight3D, sky: Sky) -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_energy *= {"day": 2.2, "dusk": 1.8, "night": 0.7}[time]
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_energy = {"day": 0.7, "dusk": 0.6, "night": 0.35}[time]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = {"day": 0.95, "dusk": 1.05, "night": 1.2}[time]
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	if time == "night":
		for sp in _floodlight_spots():
			var l := SpotLight3D.new()
			l.position = sp
			l.look_at_from_position(sp, Vector3(sp.x * 0.15, 0, sp.z * 0.15))
			l.spot_range = 190.0
			l.spot_angle = 34.0
			l.spot_attenuation = 0.6
			l.light_energy = 9.0
			l.light_color = Color(1.0, 0.97, 0.9)
			l.shadow_enabled = false
			add_child(l)


## Where the floodlights are (the masts' lamp arrays, or along the stadium's roof): at most eight (the Mobile
## renderer lights each mesh with up to eight).
func _floodlight_spots() -> Array:
	var out := []
	for t: Transform3D in scenery.placed("floodlight"):
		out.append(t.origin)
	if out.size() > 8:
		var every := ceili(out.size() / 8.0)
		out = out.filter(func(p): return out.find(p) % every == 0)
	return out


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
