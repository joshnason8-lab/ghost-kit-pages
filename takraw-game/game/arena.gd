class_name Arena
extends Node3D
## A venue: the court and net to the ISTAF measurements (Court), and around them one of eight places takraw is
## played. Indoors, as the top game is: the national arena, a big domed stadium, a court in a shopping mall's atrium
## (where the world championship is played) and a provincial gym. Outdoors, as most people play it: a temple court,
## a park court under floodlights, a beach at sunset and a street by a night market.
## Built from merged, vertex-coloured parts (Geo), real-world pieces placed many at a time (Scenery: photographed
## skies and surfaces, trees, chairs, buildings and lamps from the shared assets), a crowd of cut-outs (Crowd) and a
## light or two; Low graphics leaves out the small things and uses the cut-down models.

## Each row of shophouses a little different in colour: as built, warmer, cooler, pinker.
const SHOPHOUSE_TINTS := [Color(1.0, 1.0, 1.0), Color(1.0, 0.93, 0.85), Color(0.9, 0.95, 1.0), Color(1.0, 0.9, 0.9)]

var venue := "national"
var women := false
var home_colors: Array = []   # the home crowd's shirts
var net_top := Court.NET_M
var crowd: Crowd
var _standing: Array = []      # where people stand (the others' spots are seats)
const FAR_GROUND := Rect2(-300, -300, 600, 600)   # outdoors the ground reaches the camera's far plane
const AMBIENCE := {"beach": ["amb_beach", -8.0], "temple": ["amb_temple", -12.0], "park": ["amb_park", -10.0],
	"street": ["amb_chatter", -10.0], "mall": ["amb_chatter", -16.0]}
var fans: Array[Node3D] = []  # ceiling fans to turn (the provincial gym)
var _t := 0.0

var _lit: Geo
var _glow: Geo
var _sc: Scenery
var _rng := RandomNumberGenerator.new()


func _init(p_venue := "national", p_women := false, p_home_colors := []) -> void:
	venue = p_venue
	women = p_women
	home_colors = p_home_colors
	net_top = Court.NET_W if women else Court.NET_M


func _ready() -> void:
	_lit = Geo.new()
	_glow = Geo.new()
	_sc = Scenery.new(self)
	_rng.seed = hash(venue)
	var kind := String(DB.venue(venue)[3])
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var spots: Array = []
	match kind:
		"arena":
			_indoor_env(Color("10151f"), Color(0.62, 0.66, 0.75), 1.05)
			_court(Color("2f8f5b"), Color("1f5aa8"), Color("16365e"))
			spots = _stands(12, 9.6, 13.4, Color("24344d"), Color("b8242c"))
			_led_boards(Color("0b1a33"))
			_roof(15.0, Color("0d1320"))
			_officials_furniture()
			_scoreboard_cube(Vector3(0, 10.5, 0))
		"dome":
			_indoor_env(Color("0d1119"), Color(0.6, 0.64, 0.72), 1.1)
			_court(Color("1f6fc2"), Color("e8722a"), Color("123355"))
			spots = _stands(20 if not low else 14, 10.0, 14.0, Color("1d2a40"), Color("1f6fc2"))
			_led_boards(Color("071225"))
			_roof(22.0, Color("0b111c"))
			_officials_furniture()
			_scoreboard_cube(Vector3(0, 13.0, 0))
		"mall":
			_indoor_env(Color("2a2420"), Color(0.85, 0.8, 0.72), 1.15)
			_court(Color("2b6cc4"), Color("1d2a40"), Color("d9d2c4"))
			spots = _mall()
			_led_boards(Color("1a1410"))
			_officials_furniture()
		"gym":
			_indoor_env(Color("1c1712"), Color(0.74, 0.73, 0.7), 0.95, 0.85)
			_court_on("white_maple_veneer", Color("247048"), Color(0.66, 0.52, 0.36), Color(0.6, 0.47, 0.32), 0.9, 2.0, 0.7)
			spots = _gym()
			_officials_furniture(false, true)
		"temple":
			_outdoor_env("day", Color(0.74, 0.76, 0.78))
			_court_on("concrete_floor", Color("1c4f8c"), Color("a8a39b"), Color("c8c4bc"), 0.9, 2.5, 0.85, "", false, 0.0, FAR_GROUND)
			spots = _temple()
			_officials_furniture(true)
		"park":
			_outdoor_env("dusk", Color(0.16, 0.18, 0.2))
			_court_on("clean_asphalt", Color("1d5c3a"), Color(0.9, 0.9, 0.92), Color(0.6, 0.85, 0.45), 0.9, 2.5, 0.8, "grass_ground", false,
				0.0, FAR_GROUND)
			spots = _park()
			_officials_furniture(true)
		"beach":
			_outdoor_env("sunset", Color(0.42, 0.47, 0.53))
			# (The dry sand stops at the damp sand by the water.)
			_court_on("coast_sand_01", Color.WHITE, Color.WHITE, Color.WHITE, 0.0, 3.0, 0.95, "", true, 0.0, Rect2(-300, -300, 600, 321))
			spots = _beach()
			_officials_furniture(true)
		"street":
			_outdoor_env("night", Color(0.06, 0.06, 0.08))
			_court_on("asphalt_02", Color("21508f"), Color(0.5, 0.5, 0.53), Color(0.42, 0.42, 0.45), 0.9, 3.0, 0.8, "", false, 0.0, FAR_GROUND)
			spots = _street()
			_officials_furniture(true)
	_net()
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	_sc.commit()
	if not spots.is_empty() or not _standing.is_empty():
		crowd = Crowd.new()
		var pal := home_colors.duplicate()
		crowd.build(spots, Game.crowd_density(), pal, hash(venue), _standing)
		add_child(crowd)


func _process(delta: float) -> void:
	_t += delta
	for f in fans:
		f.rotation.y += delta * 4.0


## How loud the place is (0-1): a packed arena more than a temple court.
func atmosphere() -> float:
	return {"arena": 0.85, "dome": 1.0, "mall": 0.8, "gym": 0.55, "temple": 0.3, "park": 0.35, "beach": 0.45, "street": 0.5}.get(String(DB.venue(venue)[3]), 0.6)


func indoor() -> bool:
	return bool(DB.venue(venue)[2])


## The court on sand (the beach): the ball's bounce and the footsteps are on sand.
func sand() -> bool:
	return venue == "beach"


## The place's own sound under the crowd (Sfx.ambience): [sound, volume dB], or "" for none (the halls: the crowd's
## murmur is their sound).
func ambience() -> Array:
	return AMBIENCE.get(venue, ["", 0.0])


# ---------------------------------------------------------------- light and sky

func _indoor_env(bg: Color, ambient: Color, energy: float, exposure := 1.0) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if not Scenery.low():
		env.tonemap_exposure = exposure
		# What the glossy floors reflect: a real hall's interior (a photographed panorama), not the background colour.
		Scenery.sky(env, "gym_01", 0.3)
		env.background_mode = Environment.BG_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_glow_on(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = energy
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.shadow_enabled = Game.shadows_enabled()
	add_child(sun)


## On High graphics, the bright things (the lights, the boards, the lines in the sun) bloom a little, as on television.
func _glow_on(env: Environment) -> void:
	if int(Game.settings.graphics) < Game.GFX_HIGH:
		return
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT


## Outdoors: a photographed sky for each time of day (Scenery), its sun where the sky's is by day; at night the light
## is the floodlights'. far: the colour of the ground (or the sea) far off in the haze: past 140 m everything fades into
## it, and the sky takes it under the horizon, so the ground and the sea have no edge and there is nothing empty beyond.
func _outdoor_env(time: String, far: Color) -> void:
	var env := Environment.new()
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = far
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 140.0
	env.fog_depth_end = 290.0
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.0
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = Game.shadows_enabled()
	var sky_name: String = {"day": "qwantani_noon_puresky", "dusk": "kloppenheim_02_puresky", "sunset": "qwantani_sunset_puresky",
		"night": "kloppenheim_07_puresky"}[time]
	Scenery.sky(env, sky_name, {"day": 1.0, "dusk": 0.6, "sunset": 1.0, "night": 0.45}[time], far)
	match time:
		"day":
			Scenery.aim_sun(sun, sky_name)
			sun.light_energy = 1.05
			sun.light_color = Color(1.0, 0.97, 0.9)
		"dusk":
			sun.rotation_degrees = Vector3(-70, -20, 0)   # the floodlights
			sun.light_energy = 0.95
			sun.light_color = Color(1.0, 0.95, 0.85)
		"sunset":
			Scenery.aim_sun(sun, sky_name)
			sun.light_energy = 1.1
			sun.light_color = Color(1.0, 0.82, 0.62)
		"night":
			sun.rotation_degrees = Vector3(-75, 10, 0)    # the street's lights and the court's lamps
			sun.light_energy = 0.9
			sun.light_color = Color(1.0, 0.9, 0.75)
	# By night the ambient light is the place's own (the sky is too dark to light it); by day the sky's.
	if Scenery.low() or time in ["dusk", "night"]:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = {"day": Color(0.75, 0.8, 0.9), "dusk": Color(0.55, 0.5, 0.65), "sunset": Color(0.85, 0.72, 0.68),
		"night": Color(0.45, 0.45, 0.55)}[time]
	env.ambient_light_energy = {"day": 0.6, "dusk": 0.38, "sunset": 0.85, "night": 0.45}[time]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if not Scenery.low():
		env.tonemap_exposure = 0.85   # exposed for the sunlit court, as a broadcast camera is
	_glow_on(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)
	Crowd.set_light({"day": 1.0, "dusk": 0.8, "sunset": 0.9, "night": 0.7}[time])


# ---------------------------------------------------------------- the court

## An indoor court: a synthetic mat in its colour, the surround (the 3 m free zone) in another, the floor beyond, and
## the lines.
func _court(court: Color, surround: Color, floor_col: Color) -> void:
	var fz := Court.FREE_ZONE
	_lit.floor_rect(-40, -40, 40, 40, -0.002, floor_col)
	# The playing surface has a sheen under the lights (alpha: gloss, Geo.material).
	_lit.floor_rect(-Court.HALF - fz, -Court.HALF_W - fz, Court.HALF + fz, Court.HALF_W + fz, 0.0, Color(surround, 0.65))
	_lit.floor_rect(-Court.HALF, -Court.HALF_W, Court.HALF, Court.HALF_W, 0.001, Color(court, 0.45))
	_court_lines()


## An outdoor court (or the gym's) on a photographed surface (Scenery): the ground, the surround (the 3 m free zone)
## tinted, the court painted in court (paint: how much paint, 0 none), tile metres a repeat; ground_surface: the
## ground beyond, if it is another surface (grass round a park's court). sand: lines are tapes.
## reach: the ground's extent (outdoors as far as the camera sees, 300 m, into the haze).
func _court_on(surface: String, court: Color, surround: Color, ground: Color, paint: float, tile: float, rough := 0.85,
		ground_surface := "", sand := false, ground_paint := 0.0, reach := Rect2(-60, -60, 120, 120)) -> void:
	var fz := Court.FREE_ZONE
	Scenery.plane(self, Scenery.surface(ground_surface if ground_surface != "" else surface, ground, ground_paint, tile, rough),
		reach.position.x, reach.position.y, reach.end.x, reach.end.y, -0.01)
	Scenery.plane(self, Scenery.surface(surface, surround, 0.0, tile, rough), -Court.HALF - fz, -Court.HALF_W - fz, Court.HALF + fz,
		Court.HALF_W + fz, -0.005)
	if paint > 0.0:
		Scenery.plane(self, Scenery.surface(surface, court, paint, tile, rough), -Court.HALF, -Court.HALF_W, Court.HALF, Court.HALF_W, 0.0)
	_court_lines(sand)


## The lines: the boundary (4 cm, inside the court), the centre line (2 cm), the quarter circles at the net and the
## service circles; on sand, tapes.
func _court_lines(sand := false) -> void:
	var line := Color("f6f4ee") if not sand else Color("1f4f8f")
	var y := 0.003
	var l := Court.LINE
	# Back lines and side lines, drawn inside the court.
	for s: float in [-1.0, 1.0]:
		_glow.floor_rect(s * Court.HALF - (l if s > 0 else 0.0), -Court.HALF_W, s * Court.HALF + (0.0 if s > 0 else l), Court.HALF_W, y, line)
		_glow.floor_rect(-Court.HALF, s * Court.HALF_W - (l if s > 0 else 0.0), Court.HALF, s * Court.HALF_W + (0.0 if s > 0 else l), y, line)
	_glow.floor_rect(-Court.CENTRE_LINE * 0.5, -Court.HALF_W, Court.CENTRE_LINE * 0.5, Court.HALF_W, y, line)
	# Quarter circles: centred where the centre line meets each side line, radius 0.90 m, the line drawn outward.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(0, y, sz * Court.HALF_W)
			var a0 := PI if sx < 0 else 0.0
			var start := a0 if sz < 0 else (a0 - PI * 0.5 if sx > 0 else a0)
			# The quarter in the court on side sx: from the centre line toward the back, from the side line inward.
			var from := 0.0
			var to := 0.0
			if sx > 0 and sz < 0:
				from = 0.0
				to = PI * 0.5
			elif sx < 0 and sz < 0:
				from = PI * 0.5
				to = PI
			elif sx < 0 and sz > 0:
				from = PI
				to = PI * 1.5
			else:
				from = PI * 1.5
				to = TAU
			if start == 99.0:
				pass
			_glow.ring(c, Court.QUARTER_R, Court.QUARTER_R + l, from, to, line, 12)
	# Service circles: radius 0.30 m, the line inside it, 2.45 m from each back line.
	for sx: float in [-1.0, 1.0]:
		_glow.ring(Vector3(sx * Court.SERVICE_D, y, 0), Court.SERVICE_R - l, Court.SERVICE_R, 0.0, TAU, line, 24)


## The net: posts 30 cm outside the side lines, the mesh 70 cm deep under the top, white tapes along the top and
## bottom, and the boundary tapes standing over the side lines.
func _net() -> void:
	var top := net_top
	var post_z := Court.HALF_W + Court.POST_OUT
	for s: float in [-1.0, 1.0]:
		_lit.cylinder(Vector3(0, 0, s * post_z), Vector3(0, top + Court.NET_POST_EXTRA + 0.04, s * post_z), 0.04, 0.04, Color("d8d8d8"), 10)
		_lit.cylinder(Vector3(0, 0, s * post_z), Vector3(0, 0.06, s * post_z), 0.14, 0.12, Color("3a3a3a"), 10)
	# Tapes: top and bottom 5 cm, both faces; the boundary tapes over each side line.
	var bottom := top - Court.NET_DEPTH
	for x: float in [-0.004, 0.004]:
		var nrm := Vector3(-1 if x < 0 else 1, 0, 0)
		_lit._tri_quad(Vector3(x, top, -post_z) if x > 0 else Vector3(x, top, post_z), Vector3(x, top, post_z) if x > 0 else Vector3(x, top, -post_z),
			Vector3(x, top - 0.05, post_z) if x > 0 else Vector3(x, top - 0.05, -post_z), Vector3(x, top - 0.05, -post_z) if x > 0 else Vector3(x, top - 0.05, post_z), nrm, Color("f3f3f3"))
		_lit._tri_quad(Vector3(x, bottom + 0.04, -post_z) if x > 0 else Vector3(x, bottom + 0.04, post_z), Vector3(x, bottom + 0.04, post_z) if x > 0 else Vector3(x, bottom + 0.04, -post_z),
			Vector3(x, bottom, post_z) if x > 0 else Vector3(x, bottom, -post_z), Vector3(x, bottom, -post_z) if x > 0 else Vector3(x, bottom, post_z), nrm, Color("f3f3f3"))
	for s: float in [-1.0, 1.0]:
		_lit.box(Vector3(0, (top + bottom) * 0.5, s * (Court.HALF_W - 0.025)), Vector3(0.012, top - bottom, 0.05), Color("f3f3f3"), 0.0, false)
	# The mesh itself, see-through.
	var mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(post_z * 2.0, Court.NET_DEPTH - 0.08)
	mesh.mesh = q
	mesh.rotation.y = PI * 0.5
	mesh.position = Vector3(0, (top + bottom) * 0.5 - 0.005, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _net_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.uv1_scale = Vector3(post_z * 2.0 / 0.07 / 8.0, (Court.NET_DEPTH - 0.08) / 0.07 / 8.0, 1)
	mat.texture_repeat = true
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


static var _net_tex: ImageTexture


## Eight 7 cm squares of net cord a tile.
static func _net_texture() -> ImageTexture:
	if _net_tex:
		return _net_tex
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in n:
		for k in n:
			if i % 8 == 0 or k % 8 == 0:
				img.set_pixel(i, k, Color(1, 1, 1, 1))
	img.generate_mipmaps()
	_net_tex = ImageTexture.create_from_image(img)
	return _net_tex


## The referee's high chair at one post, the assistant's stand at the other, the scorers' table, the team benches (in
## a gym, its own wooden benches).
func _officials_furniture(outdoor := false, gym := false) -> void:
	var post_z := Court.HALF_W + Court.POST_OUT
	var chair := Color("e6e6e6") if not outdoor else Color("7a5a3a")
	# The referee's chair on the far side (seen from the broadcast camera), 1.2 m up.
	var cz := post_z + 0.75
	for dx: float in [-0.25, 0.25]:
		for dz: float in [-0.25, 0.25]:
			_lit.cylinder(Vector3(dx, 0, cz + dz), Vector3(dx, 1.2, cz + dz), 0.025, 0.025, chair, 6, false)
	_lit.box(Vector3(0, 1.22, cz), Vector3(0.6, 0.05, 0.6), chair)
	_lit.box(Vector3(0, 1.5, cz + 0.28), Vector3(0.6, 0.55, 0.04), chair)
	_lit.box(Vector3(0, 0.6, cz - 0.31), Vector3(0.5, 0.04, 0.04), chair)
	# The scorers' table behind the referee, and the two benches.
	var table_z := post_z + 2.6
	_lit.box(Vector3(0, 0.72, table_z), Vector3(2.4, 0.06, 0.7), Color("1d2a40") if not outdoor else Color("8a6a48"))
	_lit.box(Vector3(0, 0.38, table_z + 0.33), Vector3(2.4, 0.7, 0.04), Color("19b3a3") if not outdoor else Color("8a6a48"))
	for s: float in [-1.0, 1.0]:
		if gym:
			_sc.add("seating/gym_bench", Vector3(s * 4.5, 0, post_z + 2.4), PI * 0.5)   # the hall's own benches
			continue
		_lit.box(Vector3(s * 4.5, 0.42, post_z + 2.4), Vector3(3.0, 0.06, 0.42), Color("2b3c55") if not outdoor else Color("6a4a32"))
		for k: float in [-1.3, 1.3]:
			_lit.box(Vector3(s * 4.5 + k, 0.2, post_z + 2.4), Vector3(0.06, 0.4, 0.4), Color("1a1a1a"))


# ---------------------------------------------------------------- indoor parts

## Seating on the two long sides and both ends: rows tiers deep, starting side_z from the middle (the long sides) and
## end_x (the ends). Returns where the people go.
func _stands(rows: int, side_z: float, end_x: float, concrete: Color, seat: Color) -> Array:
	var spots := []
	var step_d := 0.8
	var step_h := 0.42
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for s: float in [-1.0, 1.0]:
		var len_half := end_x + 2.0
		for r in rows:
			var z := s * (side_z + r * step_d + step_d * 0.5)
			var h := r * step_h
			_lit.box(Vector3(0, h * 0.5 + 0.21, z), Vector3(len_half * 2.0, h + 0.42, step_d), concrete.lightened(0.02 * float(r % 2)))
			if not low:
				_lit.box(Vector3(0, h + 0.45, z + s * 0.12), Vector3(len_half * 2.0, 0.06, 0.4), seat.darkened(0.15 * float(r % 3)))
			var x := -len_half + 0.3
			while x < len_half:
				spots.append(Vector3(x, h + 0.42, z + s * 0.1))
				x += 0.55
		# Ends: shorter stands behind each back line.
		for r in rows / 2:
			var x2 := s * (end_x + r * step_d + step_d * 0.5)
			var h2 := r * step_h
			_lit.box(Vector3(x2, h2 * 0.5 + 0.21, 0), Vector3(step_d, h2 + 0.42, side_z * 1.6), concrete)
			var z2 := -side_z * 0.8 + 0.3
			while z2 < side_z * 0.8:
				spots.append(Vector3(x2 + s * 0.1, h2 + 0.42, z2))
				z2 += 0.55
	# A wall behind the top rows.
	var top := rows * step_h + 2.5
	for s: float in [-1.0, 1.0]:
		_lit.box(Vector3(0, top * 0.5, s * (side_z + rows * step_d + 0.6)), Vector3((end_x + 2.0) * 2.0, top, 0.3), concrete.darkened(0.3))
	return spots


## The LED advertising boards round the court, glowing: the league and the game's own name, nothing real.
func _led_boards(face: Color) -> void:
	var d := Court.HALF_W + 4.0
	var e := Court.HALF + 4.5
	var cols := [Color("ff9a1f"), Color("19b3a3"), Color("e8336d"), Color("ffd27a")]
	var i := 0
	var x := -e + 1.5
	while x < e - 1.0:
		var w := 3.0
		_lit.box(Vector3(x + w * 0.5, 0.45, d), Vector3(w - 0.04, 0.9, 0.12), face)
		_glow.wall(Vector3(x + 0.06, 0, d - 0.065), Vector3(x + w - 0.1, 0, d - 0.065), 0.15, 0.78, Color(cols[i % 4], 1.0))
		_glow.wall(Vector3(x + 0.25, 0, d - 0.07), Vector3(x + w - 0.3, 0, d - 0.07), 0.38, 0.52, face.lightened(0.1))
		i += 1
		x += w
	for s: float in [-1.0, 1.0]:
		_lit.box(Vector3(s * e, 0.45, 0), Vector3(0.12, 0.9, 10.0), face)
		_glow.wall(Vector3(s * (e - 0.065), 0, -4.8 * s), Vector3(s * (e - 0.065), 0, 4.8 * s), 0.15, 0.78, Color(cols[(i + 1) % 4], 1.0))
	# Words on the long board facing the camera.
	for k in 3:
		var lbl := Label3D.new()
		lbl.text = ["SEPAK TAKRAW UNLEASHED", "SEPAK TAKRAW · 15 POINTS", "SEPAK TAKRAW UNLEASHED"][k]
		lbl.font = Game.font_display
		lbl.font_size = 96
		lbl.pixel_size = 0.004
		lbl.modulate = Color("0c1a29")
		lbl.outline_size = 0
		lbl.position = Vector3(-7.0 + k * 7.0, 0.47, d - 0.08)
		lbl.rotation.y = PI
		lbl.shaded = false
		add_child(lbl)


func _roof(h: float, col: Color) -> void:
	_lit.floor_rect(-30, -30, 30, 30, h, col)
	# Rows of lights under the roof.
	for x in range(-12, 13, 4):
		for z in range(-8, 9, 4):
			_glow.box(Vector3(x, h - 0.3, z), Vector3(1.2, 0.08, 0.5), Color("fff6e0"))


func _scoreboard_cube(c: Vector3) -> void:
	_lit.box(c, Vector3(4.0, 2.4, 4.0), Color("111821"))
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		var b := Basis(Vector3.UP, yaw)
		var n := b * Vector3(0, 0, 1)
		var right := b * Vector3(1, 0, 0)
		var center := c + n * 2.01
		_glow._tri_quad(center - right * 1.8 + Vector3(0, 1.0, 0), center + right * 1.8 + Vector3(0, 1.0, 0),
			center + right * 1.8 - Vector3(0, 1.0, 0), center - right * 1.8 - Vector3(0, 1.0, 0), n, Color("1c3b63"))


## The mall: the court in a three-storey atrium, shop fronts on every floor, people at the railings above and on
## temporary metal bleachers.
func _mall() -> Array:
	var spots := []
	var shops := [Color("e8336d"), Color("19b3a3"), Color("ffd27a"), Color("4c7ad3"), Color("ff9a1f"), Color("8ad36a")]
	for floor_i in 3:
		var y := floor_i * 4.5
		for s: float in [1.0]:   # the far side only: the camera's side is open
			var z := s * 13.0
			if floor_i > 0:
				_lit.box(Vector3(0, y - 0.15, s * 11.5), Vector3(40, 0.3, 3.0), Color("e9e2d6"))
				_lit.box(Vector3(0, y + 0.55, s * 10.05), Vector3(40, 1.1, 0.06), Color("bfe3ea"))  # glass railing
				var x := -18.0
				while x < 18.0:
					spots.append(Vector3(x, y, s * 10.4))
					x += 0.7
			var k := 0
			var sx := -19.0
			while sx < 19.0:
				_lit.box(Vector3(sx + 2.0, y + 1.9, z), Vector3(3.8, 3.8, 0.3), Color("efe8dc"))
				_glow.wall(Vector3(sx + 0.3, 0, z - s * 0.17), Vector3(sx + 3.7, 0, z - s * 0.17), y + 3.0, y + 3.6, shops[(k + floor_i) % 6])
				_glow.wall(Vector3(sx + 0.5, 0, z - s * 0.16), Vector3(sx + 3.5, 0, z - s * 0.16), y + 0.2, y + 2.7, Color("fff3d6").darkened(0.1 * float(k % 2)))
				k += 1
				sx += 4.0
	# Temporary metal bleachers along the far side.
	spots.append_array(_bleachers(3, 7.0))
	_lit.floor_rect(-30, -30, 30, 30, 14.0, Color("cfd6dc"))
	_glow.floor_rect(-6, -4, 6, 4, 13.95, Color("eaf6ff"))   # the skylight
	return spots


## The provincial gym: a maple floor, painted block walls, metal bleachers along one side, fluorescent battens under
## the roof, a clock over the doors and the small things by them (a fire alarm, a wet-floor sign), basketball boards
## on the end walls, banners and ceiling fans.
func _gym() -> Array:
	var spots := _bleachers(3, 10.1)
	var wall := Scenery.surface("concrete_block_wall", Color("e9e4d8"), 1.0, 2.4, 0.9)
	Scenery.box(self, wall, Vector3(0, 5, 12.6), Vector3(30, 10, 0.3))
	Scenery.box(self, wall, Vector3(14.5, 5, -6.5), Vector3(0.3, 10, 38))
	Scenery.box(self, wall, Vector3(-14.5, 5, -6.5), Vector3(0.3, 10, 38))
	_lit.box(Vector3(0, 5, -26.0), Vector3(30, 10, 0.3), Color("d8d2c4"))   # well behind the camera
	for x in range(-12, 13, 4):
		_glow.wall(Vector3(x - 1.2, 0, 12.44), Vector3(x + 1.2, 0, 12.44), 6.8, 8.6, Color("cfe8ff"))
	var banners := [Color("e8336d"), Color("19b3a3"), Color("ffd27a"), Color("1f6fc2")]
	for i in 4:
		_lit.box(Vector3(-9 + i * 6, 5.2, 12.42), Vector3(2.0, 1.2, 0.04), banners[i])
	# The doors at each end of the far wall, the clock above the middle, an alarm and a wet-floor sign by a door.
	for x: float in [-12.0, 12.0]:
		_lit.box(Vector3(x, 1.1, 12.43), Vector3(1.8, 2.2, 0.06), Color("5a6470"))
		_lit.box(Vector3(x, 1.1, 12.4), Vector3(0.04, 2.2, 0.07), Color("2b3138"))
	_sc.add("hall/wall_clock", Vector3(0, 4.0, 12.45), PI, 2.2)
	_sc.add("hall/fire_alarm", Vector3(10.4, 1.4, 12.45), PI, 1.6)
	_sc.add("hall/wet_floor_sign", Vector3(10.8, 0, 11.4), PI * 0.9)
	# Basketball boards on the end walls: a clean board 1.80 by 1.05 m, its rim 3.05 m up (built here, as halls have).
	for s: float in [-1.0, 1.0]:
		var wx := s * 14.35
		_lit.box(Vector3(wx - s * 0.6, 3.3, 0), Vector3(1.2, 0.08, 0.08), Color("33383e"))
		_lit.box(Vector3(wx - s * 1.2, 3.45, 0), Vector3(0.03, 1.05, 1.8), Color("f4f4f2"))
		_lit.box(Vector3(wx - s * 1.215, 3.45, 0), Vector3(0.01, 0.45, 0.59), Color("d23a2a"))
		_lit.box(Vector3(wx - s * 1.22, 3.45, 0), Vector3(0.01, 0.41, 0.55), Color("f4f4f2"))
		var rim := wx - s * (1.2 + 0.15 + 0.23)
		for k in 12:
			var a0 := TAU * k / 12.0
			var a1 := TAU * (k + 1) / 12.0
			_lit.cylinder(Vector3(rim + cos(a0) * 0.23, 3.05, sin(a0) * 0.23), Vector3(rim + cos(a1) * 0.23, 3.05, sin(a1) * 0.23), 0.012, 0.012, Color("e05a1a"), 4, false)
	_lit.floor_rect(-16, -27, 16, 14, 10.0, Color("6b625a"))
	for x in range(-10, 11, 4):
		for z in range(-6, 7, 4):
			_sc.add("hall/fluorescent_light", Vector3(x, 9.95, z + 0.3), 0.0, 1.6, false)
	for x: float in [-6.0, 0.0, 6.0]:
		var fan := Node3D.new()
		fan.position = Vector3(x, 9.2, 3.0)
		var g := Geo.new()
		g.cylinder(Vector3(0, 0.6, 0), Vector3(0, 0, 0), 0.03, 0.03, Color("dddddd"), 6)
		for k in 3:
			g.box(Vector3(cos(TAU * k / 3) * 0.6, 0, sin(TAU * k / 3) * 0.6), Vector3(1.1, 0.02, 0.18), Color("e8e8e8"), -TAU * k / 3)
		fan.add_child(g.commit(Geo.material(true)))
		add_child(fan)
		fans.append(fan)
	return spots


## Metal bleachers along the far side: sections (7.5 m wide, five rows) side by side centred on the court, their front
## at front_z; a person on most seats. Returns where people sit.
func _bleachers(sections: int, front_z: float) -> Array:
	var spots := []
	var w := 7.5
	for i in sections:
		var x := (i - (sections - 1) * 0.5) * w
		_sc.add("stands/bleacher_metal", Vector3(x, 0, front_z + 2.07), PI)
		for r in 5:
			var px := x - w * 0.5 + 0.35
			while px < x + w * 0.5 - 0.3:
				spots.append(Vector3(px, 0.42 + r * 0.52, front_z + 0.35 + r * 0.72))
				px += 0.55
	return spots


# ---------------------------------------------------------------- outdoor parts

## People standing in a row on the ground, from one point to another, step metres apart.
func _people_row(from: Vector3, to: Vector3, step: float) -> void:
	var d := from.distance_to(to)
	var n := int(d / step)
	for i in n:
		var p := from.lerp(to, float(i) / maxf(1.0, n - 1))
		_standing.append(Vector3(p.x, 0.0, p.z))


## Rows of seats facing the court along the far side (a model each: plastic chairs, stools, benches), with a person
## on most: rows deep from z, every step metres between x0 and x1; seat: the seat's height. Returns where people sit.
func _seat_rows(model: String, rows: int, z: float, x0: float, x1: float, step: float, seat: float, depth := 0.9) -> Array:
	var spots := []
	for r in rows:
		var x := x0 + (r % 2) * step * 0.5
		while x <= x1:
			var p := Vector3(x + _rng.randf_range(-0.04, 0.04), 0, z + r * depth + _rng.randf_range(-0.05, 0.05))
			_sc.add(model, p, PI + _rng.randf_range(-0.12, 0.12))
			spots.append(Vector3(p.x, seat, p.z + 0.03))
			x += step
	return spots


## Trees (photographed cut-outs) scattered in a box, each name of names as often as the others, heights from h0 to h1.
func _trees(names: Array, n: int, x0: float, x1: float, z0: float, z1: float, h0: float, h1: float) -> void:
	for i in n:
		var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(z0, z1))
		_sc.tree(names[i % names.size()], p, _rng.randf_range(h0, h1), _rng)


## A temple court in Thailand: the court on the wat's paved forecourt, the hall behind with its tiered gold-trimmed
## roofs, people on white plastic chairs as at a temple fair, coconut palms and rain trees round about.
func _temple() -> Array:
	var spots := []
	_sc.add("buildings/thai_temple", Vector3(0, 0, 27.0), PI * 0.5)
	spots.append_array(_seat_rows("seating/monobloc_chair", 2 if Scenery.low() else 3, 8.0, -9.0, 9.0, 0.62, 0.45))
	# A few standing at the back, by the temple's steps.
	_people_row(Vector3(-6, 0, 11.4), Vector3(6, 0, 11.4), 0.7)
	_trees(["coconut_palm", "rain_tree", "island_tree_a"], 7, -34.0, -15.0, 6.0, 26.0, 9.0, 13.0)
	_trees(["coconut_palm", "island_tree_b", "rain_tree"], 7, 15.0, 34.0, 6.0, 26.0, 9.0, 13.0)
	_trees(["coconut_palm"], 4, -16.0, 16.0, 36.0, 42.0, 14.0, 17.0)
	return spots


## A park court in the evening under floodlights: the court painted on asphalt in the grass, a chain-link fence round
## three sides, park benches with people, street lamps along the path, a basketball hoop on the next court, rain
## trees, and the town's blocks dark beyond.
func _park() -> Array:
	var spots := []
	# Floodlights on four poles.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * 10.6, 0, sz * 7.6)
			_lit.cylinder(p, p + Vector3(0, 9.0, 0), 0.12, 0.09, Color("8a8f98"), 6, false)
			_glow.box(p + Vector3(0, 9.0, 0), Vector3(1.0, 0.5, 0.2), Color("fffbe8"))
	# The fence: the far side and both ends, people watching through it from the benches behind.
	var fx := Court.HALF + Court.FREE_ZONE + 0.6
	var fz := Court.HALF_W + Court.FREE_ZONE + 0.6
	Scenery.fence(self, [Vector3(-fx, 0, -fz), Vector3(-fx, 0, fz), Vector3(fx, 0, fz), Vector3(fx, 0, -fz)], 3.0)
	var posts: Array = []
	for i in 9:
		posts.append(Vector3(-fx + i * fx * 0.25, 0, fz))
	for i in 5:
		posts.append(Vector3(-fx, 0, -fz + i * fz * 0.5))
		posts.append(Vector3(fx, 0, -fz + i * fz * 0.5))
	for p in posts:
		_lit.cylinder(p, p + Vector3(0, 3.05, 0), 0.03, 0.03, Color("7d8288"), 6, false)
	_lit.box(Vector3(0, 3.02, fz), Vector3(fx * 2.0, 0.04, 0.04), Color("7d8288"))
	# Benches behind the fence, a person on most; more standing behind them.
	for x in range(-9, 10, 3):
		_sc.add("seating/park_bench", Vector3(x, 0, fz + 1.2), PI)
		for k: float in [-0.45, 0.0, 0.45]:
			if _rng.randf() < 0.85:
				spots.append(Vector3(x + k, 0.45, fz + 1.25))
	_people_row(Vector3(-11, 0, fz + 2.4), Vector3(11, 0, fz + 2.4), 0.7)
	# The path behind with its lamps, and the next court with its hoop.
	for x in range(-20, 21, 8):
		_sc.add("props/street_lamp_tall", Vector3(x, 0, fz + 5.5))
	Scenery.plane(self, Scenery.surface("clean_asphalt", Color(0.95, 0.95, 0.97), 0.0, 2.5, 0.8), 13.5, -7.5, 29.0, 7.5, -0.004)
	_sc.add("hall/basketball_hoop", Vector3(27.2, 0, 0.0), -PI * 0.5)
	_trees(["rain_tree", "rain_tree", "island_tree_a"], 12, -36.0, 36.0, 16.0, 26.0, 9.0, 13.0)
	_trees(["rain_tree", "island_tree_b"], 6, -40.0, -18.0, -6.0, 14.0, 8.0, 12.0)
	# A row of shophouses past the trees (their cut-outs, 45 m off), apartment blocks behind with lit windows.
	for i in 4:
		_sc.add("buildings/shophouse_row_low", Vector3(-27.75 + i * 18.5, 0, 30.0), PI if i % 2 == 0 else 0.0, 1.0, false,
			SHOPHOUSE_TINTS[(i + 1) % 4])
	for i in 6:
		_sc.add("buildings/city_apartments_night", Vector3(-30.0 + i * 12.0, 0, 48.0 + _rng.randf_range(-3, 3)), PI, 1.0, false)
	return spots


## A beach court at sunset: the court on the sand, damp sand at the water's edge and the sea beyond (Scenery.water),
## coconut palms along the beach, stilt houses back from it, bunting over the court and umbrellas.
func _beach() -> Array:
	var spots := []
	Scenery.plane(self, Scenery.surface("damp_beach_sand", Color.WHITE, 0.0, 3.0, 0.7), -300, 21.0, 300, 27.0, -0.008)
	# (The sea runs on past the camera's far plane: it has no edge to see.)
	Scenery.water(self, -600, 26.0, 600, 600, Color("3f8f96"), Color("1a4a66"), Color("9fb4cc"))
	_trees(["coconut_palm"], 9, -34.0, -9.0, 10.0, 19.0, 8.0, 12.0)
	_trees(["coconut_palm"], 9, 9.0, 34.0, 10.0, 19.0, 8.0, 12.0)
	_trees(["coconut_palm", "island_tree_b"], 6, -40.0, -22.0, -12.0, 8.0, 8.0, 12.0)
	# (No shadows from the houses: under the low sun they would reach across the court.)
	_sc.add("buildings/stilt_house", Vector3(-19.0, 0, 19.0), PI * 0.8, 1.0, false)
	_sc.add("buildings/stilt_house", Vector3(21.0, 0, 17.0), -PI * 0.75, 1.0, false)
	# Bunting over the court, beach umbrellas, people on the sand.
	for s: float in [-1.0, 1.0]:
		_lit.cylinder(Vector3(s * 9.0, 0, 6.5), Vector3(s * 9.0, 5.0, 6.5), 0.05, 0.05, Color("dddddd"), 6, false)
	var cols := [Color("ff9a1f"), Color("e8336d"), Color("ffd27a"), Color("19b3a3"), Color("f3efe6")]
	for i in 24:
		var x := -9.0 + i * 0.78
		var y := 5.0 - 0.8 * sin(PI * float(i) / 23.0)
		_glow._tri_quad(Vector3(x - 0.25, y, 6.5), Vector3(x + 0.25, y, 6.5), Vector3(x + 0.02, y - 0.5, 6.5), Vector3(x - 0.02, y - 0.5, 6.5), Vector3(0, 0, -1), cols[i % 5])
	for x: float in [-12.0, -4.0, 5.0, 13.0]:
		_lit.cylinder(Vector3(x, 0, 10.5), Vector3(x, 2.2, 10.5), 0.04, 0.04, Color("eeeeee"), 6, false)
		_lit.cylinder(Vector3(x, 2.2, 10.5), Vector3(x, 2.7, 10.5), 1.4, 0.0, cols[int(absf(x)) % 5], 8)
	_people_row(Vector3(-12, 0, 8.0), Vector3(12, 0, 8.0), 0.6)
	_people_row(Vector3(-11, 0, 9.0), Vector3(11, 0, 9.0), 0.8)
	return spots


## A street court by a night market: the court painted on the street, food stalls under corrugated iron with lanterns
## strung over them and over the court, people on stools and at café tables, shophouses along the street with lamps
## on their walls and apartment blocks behind them, their windows lit.
func _street() -> Array:
	var spots := []
	# Shophouses end to end on both sides of the street, every other one turned to show its other front, each a
	# little different in colour; the far ones (and all on Low) their cut-outs.
	for i in 5:
		var x := -37.0 + i * 18.5
		_sc.add("buildings/shophouse_row_low" if absf(x) > 30.0 else "buildings/shophouse_row", Vector3(x, 0, 17.3),
			PI if i % 2 == 0 else 0.0, 1.0, false, SHOPHOUSE_TINTS[i % 4])
		_sc.add("buildings/shophouse_row_low", Vector3(x, 0, -21.0), 0.0 if i % 2 == 0 else PI, 1.0, false, SHOPHOUSE_TINTS[(i + 2) % 4])
	# Across each end of the street, more of them: the street turns there, and the ends are closed.
	for s: float in [-1.0, 1.0]:
		for k in 2:
			_sc.add("buildings/shophouse_row_low", Vector3(s * 55.0, 0, -11.75 + k * 18.5), s * PI * 0.5 + (PI if k == 1 else 0.0),
				1.0, false, SHOPHOUSE_TINTS[(k + 1) % 4])
	for i in 5:
		var x := -30.0 + i * 15.0 + _rng.randf_range(-2.0, 2.0)
		_sc.add("buildings/city_apartments_night", Vector3(x, 0, 27.0 + _rng.randf_range(-1.5, 1.5)), PI, 1.0, false)
	for i in 5:
		for k: float in [-3.0, 3.0]:
			_sc.add("props/street_lamp_wall", Vector3(-24.0 + i * 12.0 + k, 2.7, 16.13 - 0.8))
	# Stalls: tables under corrugated roofs on poles, a lantern under each.
	var roof := BoxMesh.new()
	roof.size = Vector3(3.0, 0.05, 1.9)
	roof.material = Scenery.surface("corrugated_iron", Color(0.95, 0.93, 0.9), 0.0, 1.5, 0.6)
	for i in 7:
		var x := -15.0 + i * 5.0
		_sc.add("props/long_table" if i % 2 == 0 else "props/scorers_table", Vector3(x, 0, 11.4))
		_sc.add_mesh("roof", roof, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(x, 2.35, 11.4)))
		for k: float in [-1.35, 1.35]:
			_lit.cylinder(Vector3(x + k, 0, 10.6), Vector3(x + k, 2.3, 10.6), 0.03, 0.03, Color("8a8a8a"), 4, false)
			_lit.cylinder(Vector3(x + k, 0, 12.2), Vector3(x + k, 2.45, 12.2), 0.03, 0.03, Color("8a8a8a"), 4, false)
		_sc.add("props/lantern", Vector3(x, 2.05, 11.6), 0.0, 1.1)
	for x: float in [-19.5, 19.5]:
		_sc.add("props/cafe_table_set", Vector3(x, 0, 9.6), _rng.randf_range(-0.4, 0.4))
		_sc.add("props/cafe_table_set", Vector3(x + signf(x) * 2.2, 0, 11.6), _rng.randf_range(-0.4, 0.4))
	# Strings of lanterns over the court, between poles.
	for s: float in [-1.0, 1.0]:
		_lit.cylinder(Vector3(s * 10.0, 0, 7.0), Vector3(s * 10.0, 6.0, 7.0), 0.08, 0.08, Color("555555"), 6, false)
		_lit.cylinder(Vector3(s * 10.0, 0, -7.0), Vector3(s * 10.0, 6.0, -7.0), 0.08, 0.08, Color("555555"), 6, false)
	for k in 3:
		var z := -6.0 + k * 6.0
		for i in 21:
			var x := -10.0 + i * 1.0
			var y := 6.0 - 1.0 * sin(PI * float(i) / 20.0)
			if i % 2 == 0:
				_sc.add("props/lantern", Vector3(x, y - 0.55, z), 0.0, 2.4, false)
				_glow.box(Vector3(x, y - 0.32, z), Vector3(0.1, 0.1, 0.1), Color("ffd27a"))
			else:
				_glow.box(Vector3(x, y - 0.1, z), Vector3(0.1, 0.1, 0.1), [Color("ffd27a"), Color("ff9a1f"), Color("fff6e0")][i % 3])
	# People on stools in front of the stalls, more standing behind.
	spots.append_array(_seat_rows("seating/folding_stool", 1, 8.0, -12.0, 12.0, 0.55, 0.44))
	for x: float in [-13.5, -12.8, 12.8, 13.5]:
		_sc.add("seating/metal_stool", Vector3(x, 0, 9.6), _rng.randf_range(0.0, TAU))
	_people_row(Vector3(-13, 0, 9.3), Vector3(13, 0, 9.3), 0.7)
	return spots
