class_name Arena
extends Node3D
## A venue: the court and net to the ISTAF measurements (Court), and around them one of eight places takraw is
## played. Indoors, as the top game is: the national arena, a big domed stadium, a court in a shopping mall's atrium
## (where the world championship is played) and a provincial gym. Outdoors, as most people play it: a temple court,
## a park court under floodlights, a beach at sunset and a street by a night market.
## Built from merged, vertex-coloured parts (Geo), a crowd of cut-outs (Crowd) and a light or two; Low graphics
## leaves out the small things.

var venue := "national"
var women := false
var home_colors: Array = []   # the home crowd's shirts
var net_top := Court.NET_M
var crowd: Crowd
var fans: Array[Node3D] = []  # ceiling fans to turn (the provincial gym)
var _t := 0.0

var _lit: Geo
var _glow: Geo


func _init(p_venue := "national", p_women := false, p_home_colors := []) -> void:
	venue = p_venue
	women = p_women
	home_colors = p_home_colors
	net_top = Court.NET_W if women else Court.NET_M


func _ready() -> void:
	_lit = Geo.new()
	_glow = Geo.new()
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
			_indoor_env(Color("1c1712"), Color(0.7, 0.68, 0.66), 0.95)
			_court(Color("2f8f5b"), Color("c79a5b"), Color("b98a4e"), true)
			spots = _gym()
			_officials_furniture()
		"temple":
			_outdoor_env("day")
			_court(Color("2e6fb0"), Color("9a9a92"), Color("8f8b80"))
			spots = _temple()
			_officials_furniture(true)
		"park":
			_outdoor_env("dusk")
			_court(Color("2f8f5b"), Color("6b6f73"), Color("3f6b34"))
			spots = _park()
			_officials_furniture(true)
		"beach":
			_outdoor_env("sunset")
			_court(Color("e2cfa6"), Color("dcc79c"), Color("dcc79c"), false, true)
			spots = _beach()
			_officials_furniture(true)
		"street":
			_outdoor_env("night")
			_court(Color("2e6fb0"), Color("3a3d42"), Color("2c2e31"))
			spots = _street()
			_officials_furniture(true)
	_net()
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	if not spots.is_empty():
		crowd = Crowd.new()
		var pal := home_colors.duplicate()
		crowd.build(spots, Game.crowd_density(), pal, hash(venue))
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


# ---------------------------------------------------------------- light and sky

func _indoor_env(bg: Color, ambient: Color, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
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


func _outdoor_env(time: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = Game.shadows_enabled()
	match time:
		"day":
			sm.sky_top_color = Color("3d7fd6")
			sm.sky_horizon_color = Color("bcd8f0")
			sm.ground_horizon_color = Color("bcd8f0")
			sun.rotation_degrees = Vector3(-55, 35, 0)
			sun.light_energy = 1.15
			sun.light_color = Color(1.0, 0.97, 0.9)
		"dusk":
			sm.sky_top_color = Color("1d2550")
			sm.sky_horizon_color = Color("c25a6e")
			sm.ground_horizon_color = Color("3a2a3a")
			sun.rotation_degrees = Vector3(-70, -20, 0)   # the floodlights, really
			sun.light_energy = 0.95
			sun.light_color = Color(1.0, 0.95, 0.85)
		"sunset":
			sm.sky_top_color = Color("2c2d68")
			sm.sky_horizon_color = Color("ff8a3d")
			sm.ground_horizon_color = Color("ff8a3d")
			sun.rotation_degrees = Vector3(-24, 160, 0)
			sun.light_energy = 0.95
			sun.light_color = Color(1.0, 0.92, 0.82)
		"night":
			sm.sky_top_color = Color("060a18")
			sm.sky_horizon_color = Color("1a1f3a")
			sm.ground_horizon_color = Color("0c0f1c")
			sun.rotation_degrees = Vector3(-75, 10, 0)
			sun.light_energy = 0.9
			sun.light_color = Color(1.0, 0.9, 0.75)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = {"day": Color(0.75, 0.8, 0.9), "dusk": Color(0.55, 0.5, 0.65), "sunset": Color(0.78, 0.76, 0.8),
		"night": Color(0.4, 0.42, 0.55)}[time]
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	_glow_on(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)
	Crowd.set_light({"day": 1.0, "dusk": 0.8, "sunset": 0.9, "night": 0.7}[time])


# ---------------------------------------------------------------- the court

## The court: a synthetic mat in its colour, the surround (the 3 m free zone) in another, the floor beyond, and the
## lines: the boundary (4 cm, inside the court), the centre line (2 cm), the quarter circles at the net and the
## service circles. wood: a wooden gym floor; sand: beach takraw's sand court with tapes for lines.
func _court(court: Color, surround: Color, floor_col: Color, wood := false, sand := false) -> void:
	var fz := Court.FREE_ZONE
	_lit.floor_rect(-40, -40, 40, 40, -0.002, floor_col)
	if wood:
		# Boards: long strips of slightly different tones.
		for i in 40:
			var z := -20.0 + i * 1.0
			_lit.floor_rect(-20, z, 20, z + 1.0, -0.001, floor_col.darkened(0.04 * float(i % 3)))
	# The playing surface has a sheen under the lights (alpha: gloss, Geo.material); sand has none.
	var sheen := 1.0 if sand else 0.45
	_lit.floor_rect(-Court.HALF - fz, -Court.HALF_W - fz, Court.HALF + fz, Court.HALF_W + fz, 0.0, Color(surround, sheen + 0.2))
	_lit.floor_rect(-Court.HALF, -Court.HALF_W, Court.HALF, Court.HALF_W, 0.001, Color(court, sheen))
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


## The referee's high chair at one post, the assistant's stand at the other, the scorers' table, the team benches.
func _officials_furniture(outdoor := false) -> void:
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


## The mall: the court in a three-storey atrium, shop fronts on every floor, people at the railings above and in a
## few rows of temporary seats.
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
	# Temporary seats along the far side.
	for s: float in [1.0]:
		for r in 5:
			var z := s * (7.2 + r * 0.75)
			_lit.box(Vector3(0, r * 0.35 * 0.5 + 0.2, z), Vector3(18.0, r * 0.35 + 0.4, 0.75), Color("3a4252"))
			var x := -8.7
			while x < 9.0:
				spots.append(Vector3(x, r * 0.35 + 0.4, z))
				x += 0.55
	_lit.floor_rect(-30, -30, 30, 30, 14.0, Color("cfd6dc"))
	_glow.floor_rect(-6, -4, 6, 4, 13.95, Color("eaf6ff"))   # the skylight
	return spots


## The provincial gym: a wooden floor, a few rows of bleachers, brick walls with high windows, banners and fans.
func _gym() -> Array:
	var spots := []
	for r in 5:
		var z := 8.0 + r * 0.7
		_lit.box(Vector3(0, r * 0.4 * 0.5 + 0.2, z), Vector3(22, r * 0.4 + 0.4, 0.7), Color("8a8f98"))
		var x := -10.5
		while x < 10.5:
			spots.append(Vector3(x, r * 0.4 + 0.4, z))
			x += 0.55
	var wall := Color("b9805c")
	_lit.box(Vector3(0, 5, 12.5), Vector3(30, 10, 0.3), wall)
	_lit.box(Vector3(0, 5, -26.0), Vector3(30, 10, 0.3), wall)   # well behind the camera
	_lit.box(Vector3(14.5, 5, -6.5), Vector3(0.3, 10, 38), wall.darkened(0.08))
	_lit.box(Vector3(-14.5, 5, -6.5), Vector3(0.3, 10, 38), wall.darkened(0.08))
	for x in range(-12, 13, 4):
		_glow.wall(Vector3(x - 1.2, 0, 12.34), Vector3(x + 1.2, 0, 12.34), 6.5, 8.5, Color("cfe8ff"))
	var banners := [Color("e8336d"), Color("19b3a3"), Color("ffd27a"), Color("1f6fc2")]
	for i in 4:
		_lit.box(Vector3(-9 + i * 6, 5.0, 12.3), Vector3(2.0, 1.4, 0.04), banners[i])
	_lit.floor_rect(-16, -27, 16, 14, 10.0, Color("6b625a"))
	for x: float in [-6.0, 0.0, 6.0]:
		_glow.box(Vector3(x, 9.8, 0), Vector3(3.0, 0.1, 0.4), Color("fff6e0"))
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


# ---------------------------------------------------------------- outdoor parts

func _tree(p: Vector3, h: float, leaves: Color) -> void:
	_lit.cylinder(p, p + Vector3(0, h * 0.55, 0), 0.16, 0.1, Color("5a4030"), 6, false)
	_lit.blob(p + Vector3(0, h * 0.7, 0), Vector3(h * 0.32, h * 0.3, h * 0.32), leaves)
	_lit.blob(p + Vector3(h * 0.15, h * 0.85, 0.1), Vector3(h * 0.22, h * 0.2, h * 0.22), leaves.lightened(0.08))


func _palm(p: Vector3, h: float) -> void:
	var lean := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	var top := p + Vector3(0, h, 0) + lean
	_lit.cylinder(p, p + Vector3(0, h * 0.5, 0) + lean * 0.3, 0.18, 0.15, Color("6b4a30"), 6, false)
	_lit.cylinder(p + Vector3(0, h * 0.5, 0) + lean * 0.3, top, 0.15, 0.12, Color("6b4a30"), 6, false)
	for k in 7:
		var a := TAU * k / 7.0
		var d := Vector3(cos(a), 0, sin(a))
		_lit.box(top + d * 1.0 + Vector3(0, -0.35, 0), Vector3(2.2, 0.06, 0.45), Color("2f7a3a").lightened(0.05 * float(k % 2)), -a)


func _people_row(spots: Array, from: Vector3, to: Vector3, step: float, y := 0.0) -> void:
	var d := from.distance_to(to)
	var n := int(d / step)
	for i in n:
		var p := from.lerp(to, float(i) / maxf(1.0, n - 1))
		spots.append(Vector3(p.x, y, p.z))


func _temple() -> Array:
	var spots := []
	_lit.floor_rect(-60, -60, 60, 60, -0.01, Color("c9b48a"))
	# The temple's hall behind the court: white walls, a stepped base, tiered red and gold roofs.
	var z := 14.0
	_lit.box(Vector3(0, 0.6, z), Vector3(18, 1.2, 9), Color("efe9df"))
	_lit.box(Vector3(0, 3.2, z), Vector3(14, 4.0, 7), Color("f6f1e8"))
	for k in 3:
		var w := 17.0 - k * 3.5
		var y := 5.4 + k * 1.6
		_lit.box(Vector3(0, y, z), Vector3(w, 0.5, 9.0 - k * 1.5), Color("b8242c"))
		_lit.box(Vector3(0, y + 0.3, z), Vector3(w - 0.4, 0.12, 9.2 - k * 1.5), Color("e2b23a"))
	_lit.cylinder(Vector3(0, 10.2, z), Vector3(0, 13.0, z), 0.5, 0.0, Color("e2b23a"), 8)
	for x: float in [-5.0, -2.5, 2.5, 5.0]:
		_lit.cylinder(Vector3(x, 1.2, z - 3.6), Vector3(x, 5.2, z - 3.6), 0.25, 0.25, Color("f2ede4"), 8)
	# Steps where people sit, a low wall, trees and a few monks' umbrellas.
	for r in 4:
		_lit.box(Vector3(0, 0.15 + r * 0.3, z - 4.8 - (3 - r) * 0.5), Vector3(16, 0.3, 0.5), Color("e8e0d2"))
		_people_row(spots, Vector3(-7, 0, z - 4.85 - (3 - r) * 0.5), Vector3(7, 0, z - 4.85 - (3 - r) * 0.5), 0.6, 0.3 + r * 0.3)
	_people_row(spots, Vector3(-10, 0, 7.6), Vector3(10, 0, 7.6), 0.75)
	for x: float in [-16.0, -12.0, 12.0, 16.0]:
		_tree(Vector3(x, 0, 9.0 + randf() * 3.0), 7.0, Color("2f6b2e"))
	for x: float in [-14.0, 14.0]:
		_tree(Vector3(x, 0, -12.0), 8.0, Color("336f30"))
	_lit.box(Vector3(0, 0.5, 19.5), Vector3(50, 1.0, 0.4), Color("e8e0d2"))
	return spots


func _park() -> Array:
	var spots := []
	_lit.floor_rect(-60, -60, 60, 60, -0.01, Color("3f6b34"))
	# Floodlights on four poles.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(sx * 10.0, 0, sz * 7.5)
			_lit.cylinder(p, p + Vector3(0, 9.0, 0), 0.12, 0.09, Color("8a8f98"), 6, false)
			_glow.box(p + Vector3(0, 9.0, 0), Vector3(1.0, 0.5, 0.2), Color("fffbe8"))
	# Trees, benches, the city behind.
	for i in 12:
		_tree(Vector3(-22.0 + i * 4.0 + randf() * 1.5, 0, 15.0 + randf() * 4.0), 6.0 + randf() * 3.0, Color("27542a"))
	for i in 9:
		var h := 12.0 + randf() * 20.0
		_lit.box(Vector3(-32.0 + i * 8.0, h * 0.5, 45.0), Vector3(6.0, h, 6.0), Color("2a2f45"))
		for w in int(h / 3.0):
			if randf() < 0.6:
				_glow.box(Vector3(-32.0 + i * 8.0 + randf_range(-2, 2), 2.0 + w * 3.0, 41.95), Vector3(0.8, 0.8, 0.05), Color("ffe3a0"))
	for x: float in [-6.0, 0.0, 6.0]:
		_lit.box(Vector3(x, 0.45, 7.8), Vector3(2.4, 0.08, 0.5), Color("6a4a32"))
	_people_row(spots, Vector3(-8, 0, 7.8), Vector3(8, 0, 7.8), 0.6, 0.45)
	_people_row(spots, Vector3(-11, 0, 9.0), Vector3(11, 0, 9.0), 0.7)
	return spots


func _beach() -> Array:
	var spots := []
	_lit.floor_rect(-80, -80, 80, 80, -0.01, Color("dcc79c"))
	# The sea behind, and the sun's path on it.
	_glow.floor_rect(-120, 22, 120, 200, 0.0, Color("8fc0d4"))   # (unshaded: shown darker than it reads here)
	for i in 6:
		_glow.floor_rect(10.0 - i * 0.4, 30.0 + i * 6.0, 18.0 + i * 0.4, 31.0 + i * 6.0, 0.01, Color("ffd27a").darkened(i * 0.08))
	for i in 10:
		_palm(Vector3(-24.0 + i * 5.5 + randf() * 2.0, 0, 13.0 + randf() * 6.0), 6.0 + randf() * 2.5)
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
		_lit.cylinder(Vector3(x, 2.2, 10.5), Vector3(x, 2.7, 10.5), 1.4, 0.0, cols[int(x) % 5 if int(x) % 5 >= 0 else 0], 8)
	_people_row(spots, Vector3(-12, 0, 8.0), Vector3(12, 0, 8.0), 0.6)
	_people_row(spots, Vector3(-11, 0, 9.0), Vector3(11, 0, 9.0), 0.8)
	return spots


func _street() -> Array:
	var spots := []
	_lit.floor_rect(-60, -60, 60, 60, -0.01, Color("2a2b2e"))
	# Shophouses behind, market stalls with striped awnings, strings of lights over the court.
	var house := [Color("d9c7a8"), Color("b9d6c8"), Color("e3b7a0"), Color("c8c0dc")]
	for i in 10:
		var x := -27.0 + i * 6.0
		var h := 7.0 + float(i % 3) * 1.5
		_lit.box(Vector3(x, h * 0.5, 16.0), Vector3(5.8, h, 5.0), house[i % 4])
		_glow.wall(Vector3(x - 2.2, 0, 13.45), Vector3(x + 2.2, 0, 13.45), 0.2, 2.6, Color("ffcf7a").darkened(0.2 * float(i % 2)))
		_glow.wall(Vector3(x - 1.8, 0, 13.45), Vector3(x - 0.4, 0, 13.45), 4.0, 5.4, Color("ffe8b0"))
		_glow.wall(Vector3(x + 0.4, 0, 13.45), Vector3(x + 1.8, 0, 13.45), 4.0, 5.4, Color("ffe8b0").darkened(0.3 * float(i % 3 == 0)))
	var aw := [Color("e8336d"), Color("19b3a3"), Color("ff9a1f"), Color("4c7ad3")]
	for i in 7:
		var x := -15.0 + i * 5.0
		_lit.box(Vector3(x, 0.45, 10.5), Vector3(2.6, 0.9, 1.2), Color("8a6a48"))
		_lit.box(Vector3(x, 2.3, 10.5), Vector3(2.9, 0.08, 1.6), aw[i % 4], 0.0, false)
		for k: float in [-1.3, 1.3]:
			_lit.cylinder(Vector3(x + k, 0, 11.2), Vector3(x + k, 2.3, 11.2), 0.03, 0.03, Color("cccccc"), 4, false)
		_glow.box(Vector3(x, 2.1, 10.5), Vector3(0.18, 0.18, 0.18), Color("fff1c0"))
	for s: float in [-1.0, 1.0]:
		_lit.cylinder(Vector3(s * 10.0, 0, 7.0), Vector3(s * 10.0, 6.0, 7.0), 0.08, 0.08, Color("555555"), 6, false)
		_lit.cylinder(Vector3(s * 10.0, 0, -7.0), Vector3(s * 10.0, 6.0, -7.0), 0.08, 0.08, Color("555555"), 6, false)
	for k in 3:
		var z := -6.0 + k * 6.0
		for i in 26:
			var x := -10.0 + i * 0.8
			var y := 6.0 - 1.0 * sin(PI * float(i) / 25.0)
			_glow.box(Vector3(x, y, z), Vector3(0.12, 0.12, 0.12), [Color("ffd27a"), Color("ff9a1f"), Color("fff6e0")][i % 3])
	_people_row(spots, Vector3(-12, 0, 8.0), Vector3(12, 0, 8.0), 0.55)
	_people_row(spots, Vector3(-13, 0, 9.0), Vector3(13, 0, 9.0), 0.7)
	return spots
