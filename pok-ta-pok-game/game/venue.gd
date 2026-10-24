class_name Venue
extends Node3D
## The court and all round it, built from the court's numbers (game/court.gd), the shared assets' photographed skies,
## surfaces and plants, and simple shapes in code. Four places:
##   village   a village court in southern Sinaloa at dusk: the taste of packed earth, a scratched analco and chivos,
##             low painted houses with flat roofs, rain trees, coconut palms, agave and dry grass; people along the
##             sides on benches and chairs.
##   festival  the same earth court by day at a festival: stands down one side, shade awnings at the ends, papel picado
##             strung over the people.
##   stone     a restored stone court in the Yucatán forest (the classic court, reconstructed): the I-shaped alley,
##             the sloped benches and walls, the rings, a pyramid over the trees and a stela at each end.
##   night     that court by torchlight.
## Static geometry is merged by material (one draw call each); every repeated thing is a MultiMesh; the crowd is one
## draw call. Low graphics: cut-outs for every tree, no normal maps, per-vertex light, fewer people.

var id := "village"
var info := {}
var court: Court
var crowd: Crowd
var scenery: Scenery
var sun: DirectionalLight3D
var env: Environment
var torches: Array[Vector3] = []
var _flames: MultiMeshInstance3D
var _lights: Array[OmniLight3D] = []
var _rng := RandomNumberGenerator.new()

static var _skies := {}


func build(p_id: String, p_court: Court, home_colour := Color.WHITE, away_colour := Color.WHITE) -> void:
	id = p_id
	info = DB.venue(id)
	court = p_court
	_rng.seed = hash(id)
	scenery = Scenery.new(String(info.time))
	add_child(scenery)
	_environment()
	match id:
		"village":
			_earth_court()
			_village()
		"festival":
			_earth_court()
			_festival()
		_:
			_stone_court()
			_forest()
			if id == "night":
				_torches()
	scenery.commit()
	_crowd(home_colour, away_colour)


func time() -> String:
	return String(info.time)


# ---------------------------------------------------------------- sky and light

static func sky_data() -> Dictionary:
	if _skies.is_empty():
		_skies = JSON.parse_string(FileAccess.get_file_as_string("res://assets/env/sky/skies.json"))
	return _skies


func _environment() -> void:
	var g := int(Game.settings.graphics)
	var sky_name := String(info.sky)
	var d: Dictionary = sky_data().get(sky_name, {})
	env = Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/env/sky/%s_sky_2k.jpg" % sky_name)
	pm.energy_multiplier = {"day": 1.0, "dusk": 1.0, "night": 1.0}.get(time(), 1.0)
	sky.sky_material = pm
	sky.radiance_size = Sky.RADIANCE_SIZE_32 if g == Game.GFX_LOW else Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var amb: Array = d.get("ambient", [1, 1, 1])
	var amb_c := Color(float(amb[0]), float(amb[1]), float(amb[2]))
	if g == Game.GFX_LOW:
		# Low: a flat ambient light the colour of the sky, read from its HDR once (tools/env/sky_light.py).
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = amb_c
		env.ambient_light_energy = {"day": 0.55, "dusk": 0.78, "night": 0.22}.get(time(), 0.5)
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = {"day": 0.6, "dusk": 0.85, "night": 0.14}.get(time(), 0.6)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = {"day": 0.95, "dusk": 1.25, "night": 0.8}.get(time(), 1.0)
	env.tonemap_white = 6.0
	var hor: Array = d.get("horizon", [0.8, 0.8, 0.8])
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(float(hor[0]), float(hor[1]), float(hor[2])).darkened(0.1 if time() != "night" else 0.6)
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 320.0
	env.fog_density = 0.0
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.0
	if g >= Game.GFX_HIGH:
		env.glow_enabled = time() == "night"
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	var elev := deg_to_rad(float(d.get("sun_elevation", 40.0)))
	var az := TAU * float(d.get("sun_u", 0.6))
	if time() == "night":
		elev = deg_to_rad(38.0)   # the moon, high: not the far town's glow in the panorama
	sun.rotation = Vector3(-elev, az, 0)
	var sc: Array = d.get("sun_colour", [1, 1, 1])
	sun.light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
	sun.light_energy = {"day": 1.25, "dusk": 1.3, "night": 0.12}.get(time(), 1.0)
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# ---------------------------------------------------------------- the earth court (ulama)

func _earth_court() -> void:
	var hl := Court.ULAMA_HALF_L
	var hw := Court.ULAMA_HALF_W
	# The ground all round: dry, cracked earth and thin grass; the taste itself packed and swept.
	var ground := Geo.new(3.0)
	ground.tint = Color(0.92, 0.88, 0.82)
	var big := 260.0
	ground.quad(Vector3(-big, 0, big), Vector3(big, 0, big), Vector3(big, 0, -big), Vector3(-big, 0, -big))
	_mesh(ground.commit(), Geo.surface("dry_ground_01", Color(0.95, 0.9, 0.85) if id == "village" else Color(0.88, 0.9, 0.82)), "ground")
	var taste := Geo.new(2.0)
	taste.tint = Color(1.0, 0.94, 0.88)
	var m := 1.2
	taste.quad(Vector3(-hl - m, 0.004, hw + m), Vector3(hl + m, 0.004, hw + m), Vector3(hl + m, 0.004, -hw - m), Vector3(-hl - m, 0.004, -hw - m))
	_mesh(taste.commit(), Geo.surface("brown_mud_dry", Color(1.0, 0.95, 0.9), 0.95), "taste")
	# The lines scratched and limed in the earth: the side lines, the analco across the middle, a chivo at each end.
	var lines := Geo.new(1.0)
	lines.tint = Color(0.86, 0.82, 0.74)
	var w := 0.06
	var y := 0.008
	for s in [-1.0, 1.0]:
		lines.quad(Vector3(-hl, y, s * hw + w), Vector3(hl, y, s * hw + w), Vector3(hl, y, s * hw - w), Vector3(-hl, y, s * hw - w))
		lines.quad(Vector3(s * hl - w, y, hw), Vector3(s * hl + w, y, hw), Vector3(s * hl + w, y, -hw), Vector3(s * hl - w, y, -hw))
	lines.quad(Vector3(-w * 1.6, y, hw + 0.5), Vector3(w * 1.6, y, hw + 0.5), Vector3(w * 1.6, y, -hw - 0.5), Vector3(-w * 1.6, y, -hw - 0.5))
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lm.roughness = 1.0
	_mesh(lines.commit(), lm, "lines")


func _village() -> void:
	var houses := Geo.new(2.5)
	var roofs := Geo.new(2.5)
	var dark := Geo.new(2.5)
	var paints := [Color("e9c9c0"), Color("cfe0cf"), Color("efdca4"), Color("d9e2ea"), Color("efe8dc"), Color("e7b98f"), Color("c9d6c0")]
	# Low houses on both sides, a lane's width back from the people, and a few beyond the ends.
	var spots := []
	for s in [-1.0, 1.0]:
		var x := -46.0
		while x < 46.0:
			var wdt := _rng.randf_range(6.0, 10.0)
			spots.append([Vector3(x + wdt * 0.5, 0, s * _rng.randf_range(16.0, 19.0)), Vector3(wdt, _rng.randf_range(2.8, 3.6), _rng.randf_range(5.0, 7.0)), s])
			x += wdt + _rng.randf_range(2.5, 9.0)
	for sp in spots:
		var c: Vector3 = sp[0]
		var sz: Vector3 = sp[1]
		var face: float = -signf(c.z)
		var col: Color = paints[_rng.randi_range(0, paints.size() - 1)]
		houses.box(c + Vector3(0, sz.y * 0.5, 0), sz, col)
		# The flat roof's parapet, a band of the same paint a shade darker.
		roofs.box(c + Vector3(0, sz.y + 0.2, 0), Vector3(sz.x + 0.1, 0.4, sz.z + 0.1), Color(0.7, 0.68, 0.64))
		# A door and a window on the court side.
		var fz := c.z + face * (sz.z * 0.5 + 0.02)
		var dx := _rng.randf_range(-sz.x * 0.3, sz.x * 0.3)
		var wx := c.x + dx + (1.6 if dx < 0 else -1.6)
		var sx := face   # the corners in the order that faces the court
		dark.quad(Vector3(c.x + dx - 0.5 * sx, 0, fz), Vector3(c.x + dx + 0.5 * sx, 0, fz), Vector3(c.x + dx + 0.5 * sx, 2.1, fz), Vector3(c.x + dx - 0.5 * sx, 2.1, fz), Color("4a3a2e"))
		dark.quad(Vector3(wx - 0.55 * sx, 1.0, fz), Vector3(wx + 0.55 * sx, 1.0, fz), Vector3(wx + 0.55 * sx, 2.0, fz), Vector3(wx - 0.55 * sx, 2.0, fz), Color("2e2a28"))
	_mesh(houses.commit(), Geo.surface("plastered_wall", Color.WHITE, 0.95), "houses")
	_mesh(roofs.commit(), Geo.surface("plastered_wall", Color(0.85, 0.82, 0.78), 0.95), "roofs")
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(dark.commit(), dm, "doors")
	# Benches for the people along the court, a little way back from the side lines.
	var benches := Geo.new(1.0)
	for s in [-1.0, 1.0]:
		var x := -28.0
		while x < 28.0:
			benches.box(Vector3(x + 1.5, 0.42, s * 5.2), Vector3(3.0, 0.08, 0.35), Color("6b5440"))
			benches.box(Vector3(x + 0.3, 0.2, s * 5.2), Vector3(0.12, 0.4, 0.3), Color("4e3d2e"))
			benches.box(Vector3(x + 2.7, 0.2, s * 5.2), Vector3(0.12, 0.4, 0.3), Color("4e3d2e"))
			x += _rng.randf_range(5.0, 9.0)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.vertex_color_is_srgb = true
	bm.roughness = 0.9
	_mesh(benches.commit(), bm, "benches")
	# Trees and scrub.
	var g := int(Game.settings.graphics)
	for i in 26:
		var p := _scatter(22.0, 80.0, 0.0)
		var pick := _rng.randf()
		if pick < 0.5:
			scenery.add("rain_tree_card", p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
		elif pick < 0.8:
			scenery.add("coconut_palm_card", p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.15))
		else:
			scenery.add("island_tree_b_card", p, _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))
	for i in (40 if g > Game.GFX_LOW else 18):
		scenery.add("dry_grass_tall_card", _scatter(9.0, 60.0, 4.0), _rng.randf() * TAU, _rng.randf_range(0.6, 1.0))
	for i in (30 if g > Game.GFX_LOW else 14):
		scenery.add("agave", _scatter(10.0, 45.0, 6.0), _rng.randf() * TAU, _rng.randf_range(0.8, 1.4))
	for i in 10:
		scenery.add("boulder_low", _scatter(9.0, 40.0, 6.0), _rng.randf() * TAU, _rng.randf_range(0.3, 0.6))


func _festival() -> void:
	# Stands down the far side: stepped rows on a frame, and a shade awning at each end.
	var stands := Geo.new(2.0)
	var steel := Geo.new(2.0)
	var rows := 7
	for s in [-1.0]:
		for r in rows:
			var z: float = s * (6.0 + r * 0.8)
			var y := 0.45 + r * 0.42
			stands.box(Vector3(0, y - 0.04, z), Vector3(52.0, 0.1, 0.8), Color(0.78, 0.76, 0.72))
			stands.box(Vector3(0, y * 0.5, z + s * 0.38), Vector3(52.0, y, 0.06), Color(0.62, 0.6, 0.58))
		for k in 14:
			var x := -26.0 + k * 4.0
			steel.box(Vector3(x, 1.6, s * 11.6), Vector3(0.12, 3.2, 0.12), Color(0.4, 0.42, 0.45))
	_mesh(stands.commit(), Geo.surface("plastered_wall", Color(0.82, 0.8, 0.78), 0.9), "stands")
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	sm.metallic = 0.5
	sm.roughness = 0.5
	_mesh(steel.commit(), sm, "steel")
	# Awnings at the ends (canvas on poles) and papel picado strung along the near side over the standing crowd.
	var cloth := Geo.new(2.0)
	var cols := [Color("c8452c"), Color("e0a43a"), Color("3fae7a"), Color("4fa3b8"), Color("b04a8a"), Color("f2efe6")]
	for s in [-1.0, 1.0]:
		for k in 3:
			var cx: float = s * (35.0 + k * 5.0)
			var cz := (k - 1) * 5.5
			cloth.box(Vector3(cx, 3.0, cz), Vector3(4.6, 0.06, 4.6), cols[(k + (2 if s > 0 else 0)) % cols.size()])
			for q in [[-2.2, -2.2], [2.2, -2.2], [-2.2, 2.2], [2.2, 2.2]]:
				cloth.box(Vector3(cx + q[0], 1.5, cz + q[1]), Vector3(0.08, 3.0, 0.08), Color(0.55, 0.55, 0.56))
	var x := -30.0
	var i := 0
	while x < 30.0:
		var c: Color = cols[i % cols.size()]
		var z := 6.4
		var sag := 0.35 * sin(fposmod(x, 6.0) / 6.0 * PI)
		cloth.quad(Vector3(x, 4.4 - sag, z), Vector3(x + 0.34, 4.4 - sag, z), Vector3(x + 0.34, 3.95 - sag, z), Vector3(x, 3.95 - sag, z), c)
		x += 0.5
		i += 1
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.vertex_color_is_srgb = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.roughness = 0.95
	_mesh(cloth.commit(), cm, "awnings")
	var g := int(Game.settings.graphics)
	for k in 22:
		var p := _scatter(26.0, 85.0, 0.0)
		scenery.add("rain_tree_card" if _rng.randf() < 0.6 else "coconut_palm_card", p, _rng.randf() * TAU, _rng.randf_range(0.9, 1.3))
	for k in (20 if g > Game.GFX_LOW else 10):
		scenery.add("agave", _scatter(14.0, 40.0, 8.0), _rng.randf() * TAU, _rng.randf_range(0.8, 1.3))


# ---------------------------------------------------------------- the stone court (classic, reconstructed)

func _stone_court() -> void:
	var al := Court.ALLEY_HALF_L
	var aw := Court.ALLEY_HALF_W
	var tz := Court.TALUD_Z
	var th := Court.TALUD_H
	var wh := Court.WALL_H
	var el := Court.END_HALF_L
	var ew := Court.END_HALF_W
	var deep := 13.0         # the structures' back
	var stone := Geo.new(2.4)
	stone.tint = Color(1.0, 0.97, 0.92)
	var floor_g := Geo.new(3.0)
	floor_g.tint = Color(0.96, 0.93, 0.87)
	# The ground round the court: thin grass on limestone soil.
	var ground := Geo.new(3.0)
	var big := 260.0
	ground.quad(Vector3(-big, -0.01, big), Vector3(big, -0.01, big), Vector3(big, -0.01, -big), Vector3(-big, -0.01, -big))
	_mesh(ground.commit(), Geo.surface("sparse_grass", Color(0.78, 0.82, 0.72)), "ground")
	# The plastered floor of the alley and the end courts.
	floor_g.quad(Vector3(-al, 0.0, aw), Vector3(al, 0.0, aw), Vector3(al, 0.0, -aw), Vector3(-al, 0.0, -aw))
	for s in [-1.0, 1.0]:
		var x0: float = s * al
		var x1: float = s * el
		floor_g.quad(Vector3(minf(x0, x1), 0.0, ew), Vector3(maxf(x0, x1), 0.0, ew), Vector3(maxf(x0, x1), 0.0, -ew), Vector3(minf(x0, x1), 0.0, -ew))
	for s in [-1.0, 1.0]:
		var sz: float = s
		# The talud: from the alley's edge up to the wall's foot.
		var a := Vector3(-al, 0.0, sz * aw)
		var b := Vector3(al, 0.0, sz * aw)
		var c := Vector3(al, th, sz * tz)
		var d := Vector3(-al, th, sz * tz)
		if sz > 0:
			stone.quad(a, b, c, d)
		else:
			stone.quad(b, a, d, c)
		# The structure: its inner face is the wall above the talud; its top, where people watch; its back and ends.
		stone.box(Vector3(0, wh * 0.5, sz * (tz + deep) * 0.5), Vector3(al * 2.0, wh, deep - tz), Color(-1, 0, 0))
		stone.box(Vector3(0, wh + 0.25, sz * (tz + 0.6)), Vector3(al * 2.0, 0.5, 1.2))
		# The talud's two end faces (triangles as thin quads).
		for ex in [-al, al]:
			var e1 := Vector3(ex, 0.0, sz * aw)
			var e2 := Vector3(ex, 0.0, sz * tz)
			var e3 := Vector3(ex, th, sz * tz)
			if (ex > 0) == (sz > 0):
				stone.quad(e1, e2, e3, e3)
			else:
				stone.quad(e2, e1, e3, e3)
		# The end courts' walls.
		stone.box(Vector3(s * (el + 0.5), Court.END_WALL_H * 0.5, 0), Vector3(1.0, Court.END_WALL_H, ew * 2.0 + 2.0))
		for zs in [-1.0, 1.0]:
			stone.box(Vector3(s * (al + el) * 0.5, Court.END_WALL_H * 0.5, zs * (ew + 0.5)), Vector3(el - al, Court.END_WALL_H, 1.0))
	# The rings, out from each wall at the centre line, their holes along the alley: each cut from one stone, so a
	# plain stone (not the walls' coursed blocks).
	var rings := Geo.new(0.9)
	rings.tint = Color(0.92, 0.88, 0.8)
	for c in court.rings():
		rings.washer(c, Court.RING_IN, Court.RING_OUT, Court.RING_DEPTH, 28)
		# A raised rim round the hole and round the edge, as the carved rings have.
		rings.washer(c, Court.RING_IN, Court.RING_IN + 0.06, Court.RING_DEPTH + 0.025, 28)
		rings.washer(c, Court.RING_OUT - 0.05, Court.RING_OUT, Court.RING_DEPTH + 0.02, 28)
		# The tenon into the wall.
		rings.box(Vector3(0, c.y, c.z + signf(c.z) * Court.RING_OFF * 0.5 + signf(c.z) * 0.12), Vector3(0.26, 0.4, Court.RING_OFF))
	_mesh(rings.commit(), Geo.surface("broken_wall", Color(0.95, 0.92, 0.86), 0.9), "rings")
	# A stela at each end, beyond the end court (plain: their carving would need a model, docs/MESHY_BRIEF.md).
	for s in [-1.0, 1.0]:
		stone.box(Vector3(s * (el + 5.0), 1.6, -3.0), Vector3(1.3, 3.2, 0.5))
		stone.box(Vector3(s * (el + 5.0), 0.25, -3.0), Vector3(2.0, 0.5, 1.2))
	_mesh(stone.commit(), Geo.surface("sandstone_blocks", Color(0.98, 0.95, 0.88), 0.92), "stone")
	_mesh(floor_g.commit(), Geo.surface("plastered_wall", Color(0.93, 0.9, 0.84), 0.95), "floor")
	# The centre line marked on the floor.
	var lines := Geo.new(1.0)
	lines.tint = Color(0.62, 0.55, 0.46)
	lines.quad(Vector3(-0.08, 0.006, aw), Vector3(0.08, 0.006, aw), Vector3(0.08, 0.006, -aw), Vector3(-0.08, 0.006, -aw))
	for s in [-1.0, 1.0]:
		var x: float = s * al
		lines.quad(Vector3(x - 0.06, 0.006, aw), Vector3(x + 0.06, 0.006, aw), Vector3(x + 0.06, 0.006, -aw), Vector3(x - 0.06, 0.006, -aw))
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	_mesh(lines.commit(), lm, "lines")
	_pyramid(Vector3(-20.0, 0, -85.0), 36.0)


## A stepped pyramid with a temple on top, on the skyline over the trees (built plain; a carved one is in
## docs/MESHY_BRIEF.md).
func _pyramid(at: Vector3, base: float) -> void:
	var p := Geo.new(3.0)
	var tiers := 7
	var h := 3.4
	for i in tiers:
		var w := base * (1.0 - float(i) / (tiers + 1.5))
		p.box(at + Vector3(0, h * (i + 0.5), 0), Vector3(w, h, w))
	var top := base * (1.0 - float(tiers) / (tiers + 1.5))
	p.box(at + Vector3(0, h * tiers + 2.6, 0), Vector3(top * 0.7, 5.2, top * 0.6))
	# The stairway up the front, toward the court.
	p.box(at + Vector3(0, h * tiers * 0.5, base * 0.5 - 1.5), Vector3(7.0, h * tiers, 3.0))
	_mesh(p.commit(), Geo.surface("broken_wall", Color(0.95, 0.92, 0.86), 0.95), "pyramid")


func _forest() -> void:
	var g := int(Game.settings.graphics)
	# A ring of forest round the cleared site; denser beyond.
	var n := 70 if g > Game.GFX_LOW else 44
	for i in n:
		var p := _scatter(34.0, 95.0, 0.0)
		var pick := _rng.randf()
		var kind := "island_tree_a_card" if pick < 0.45 else ("island_tree_b_card" if pick < 0.7 else ("rain_tree_card" if pick < 0.9 else "coconut_palm_card"))
		scenery.add(kind, p, _rng.randf() * TAU, _rng.randf_range(1.0, 1.5))
	for i in (30 if g > Game.GFX_LOW else 12):
		scenery.add("grass_clumps_card", _scatter(15.0, 40.0, 10.0), _rng.randf() * TAU, _rng.randf_range(0.7, 1.1))


func _torches() -> void:
	# Torches along the top of each structure and at the end courts' corners.
	for s in [-1.0, 1.0]:
		for k in 5:
			torches.append(Vector3(-14.0 + k * 7.0, Court.WALL_H + 1.4, s * (Court.TALUD_Z + 0.5)))
		for e in [-1.0, 1.0]:
			torches.append(Vector3(e * (Court.END_HALF_L + 0.6), Court.END_WALL_H + 1.1, s * Court.END_HALF_W))
	var posts := Geo.new(1.0)
	for t in torches:
		posts.box(t - Vector3(0, 0.75, 0), Vector3(0.1, 1.2, 0.1), Color("3a2a1e"))
		posts.box(t - Vector3(0, 0.1, 0), Vector3(0.22, 0.22, 0.22), Color("2a1e16"))
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.vertex_color_is_srgb = true
	_mesh(posts.commit(), pm, "torch_posts")
	# The flames: one MultiMesh of glowing cards.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.8)
	q.center_offset = Vector3(0, 0.3, 0)
	mm.mesh = q
	mm.instance_count = torches.size()
	for i in torches.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, torches[i]))
	_flames = MultiMeshInstance3D.new()
	_flames.multimesh = mm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float time_s = 0.0;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	world += right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float flick = 0.85 + 0.15 * sin(time_s * 13.0 + UV.y * 9.0);
	float shape = 1.0 - length(vec2(uv.x * 1.6, (uv.y + 0.2) * 0.9));
	shape = clamp(shape * 1.6, 0.0, 1.0) * flick;
	ALBEDO = mix(vec3(1.0, 0.35, 0.05), vec3(1.0, 0.85, 0.45), shape) * shape * 2.0;
}
"""
	var fm := ShaderMaterial.new()
	fm.shader = sh
	_flames.material_override = fm
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flames)
	# Real light from a few of them on Medium and High (each light costs every lit object a pass on phones).
	var g := int(Game.settings.graphics)
	var lit := 0 if g == Game.GFX_LOW else (4 if g == Game.GFX_MEDIUM else 8)
	var pick := [1, 3, 6, 8, 0, 2, 5, 7]
	for k in mini(lit, torches.size()):
		var l := OmniLight3D.new()
		l.position = torches[pick[k] % torches.size()] + Vector3(0, 0.3, 0)
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 3.2
		l.omni_range = 18.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
	if g == Game.GFX_LOW:
		# No lights on Low: the torches' warmth in the ambient light instead.
		env.ambient_light_color = env.ambient_light_color.lerp(Color(1.0, 0.65, 0.4), 0.5)
		env.ambient_light_energy = 0.5


func _process(_delta: float) -> void:
	if _flames:
		var t := Time.get_ticks_msec() / 1000.0
		(_flames.material_override as ShaderMaterial).set_shader_parameter("time_s", t)
		for i in _lights.size():
			_lights[i].light_energy = 3.0 + 0.4 * sin(t * (11.0 + i) + i)


# ---------------------------------------------------------------- the people

## Where people watch from, and the crowd built there: one MultiMesh, everyone facing the middle of the court.
func spectator_spots() -> Array:
	var out := []
	match id:
		"village":
			for s in [-1.0, 1.0]:
				var x := -29.0
				while x < 29.0:
					for row in 3:
						out.append(Vector3(x + _rng.randf_range(-0.2, 0.2), 0.0, s * (4.6 + row * 0.75 + _rng.randf_range(0.0, 0.3))))
					x += _rng.randf_range(0.55, 0.9)
			for s in [-1.0, 1.0]:
				for k in 30:
					out.append(Vector3(s * _rng.randf_range(32.0, 36.0), 0.0, _rng.randf_range(-6.0, 6.0)))
		"festival":
			for r in 7:
				var x := -25.5
				while x < 25.5:
					out.append(Vector3(x + _rng.randf_range(-0.1, 0.1), 0.45 + r * 0.42, -(6.0 + r * 0.8 + 0.05)))
					x += 0.6
			var x2 := -29.0
			while x2 < 29.0:
				for row in 2:
					out.append(Vector3(x2 + _rng.randf_range(-0.2, 0.2), 0.0, 4.4 + row * 0.75))
				x2 += 0.6
			for s in [-1.0, 1.0]:
				for k in 40:
					out.append(Vector3(s * _rng.randf_range(33.0, 41.0), 0.0, _rng.randf_range(-7.0, 7.0)))
		_:
			# On the platforms on top of each structure, and behind the end courts' walls.
			for s in [-1.0, 1.0]:
				var x := -17.0
				while x < 17.0:
					for row in 4:
						out.append(Vector3(x + _rng.randf_range(-0.15, 0.15), Court.WALL_H, s * (Court.TALUD_Z + 1.6 + row * 0.8)))
					x += 0.62
				for k in 60:
					out.append(Vector3(s * _rng.randf_range(Court.END_HALF_L + 1.6, Court.END_HALF_L + 5.0), 0.0, _rng.randf_range(-8.0, 8.0)))
	return out


func _crowd(home: Color, away: Color) -> void:
	crowd = Crowd.new()
	add_child(crowd)
	var palette := [home, away, Color("f2efe6"), Color("2a2a2e")]
	crowd.build(spectator_spots(), Game.crowd_density(), palette, hash(id) % 1000)
	crowd.set_light({"day": 1.0, "dusk": 0.8, "night": 0.4}.get(time(), 1.0))


# ---------------------------------------------------------------- helpers

func _mesh(mesh: Mesh, mat: Material, name_: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() and name_ in ["stone", "houses", "stands", "pyramid"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A point round the court: between r0 and r1 metres from the court's long middle line, never on the court or where
## people stand (clear metres beside the court's edges).
func _scatter(r0: float, r1: float, clear: float) -> Vector3:
	var hl := court.half_l() + clear
	for i in 20:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(r0, r1)
		var p := Vector3(cos(a) * r * 1.6, 0, sin(a) * r)
		if absf(p.x) < hl + 6.0 and absf(p.z) < 9.0 + clear:
			continue
		if absf(p.z) < 20.0 and absf(p.x) < hl and r0 > 15.0 and id == "village":
			continue
		return p
	return Vector3(r1 * 1.6, 0, r1)
