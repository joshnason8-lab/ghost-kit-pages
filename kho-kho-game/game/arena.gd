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
var _plaster: Geo     # walls in a photo-scanned plaster (houses, the school)
var _tiles: Geo       # clay-tiled roofs
var _thatch: Geo      # thatched roofs
var _concrete: Geo    # the stands' concrete
var kind := ""
var _chairs: Array = []    # monobloc chairs under the front row of a village crowd
var _benches: Array = []   # painted benches (pupils at the school, the teams at a ground)


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
	_plaster = Geo.new()
	_tiles = Geo.new()
	_thatch = Geo.new()
	_concrete = Geo.new()
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	kind = String(DB.venue(venue)[4])
	_field()
	_poles()
	_table()
	var spots: Array = []
	match kind:
		"village":
			_env(Color("2a2140"), Color("d27a4e"), Color(0.78, 0.66, 0.7), 0.85, Vector3(-22, -30, 0), Color(1.0, 0.8, 0.68),
				"qwantani_dusk_2_puresky", 1.0, 40.0)
			spots = _ground_crowd(low)
			_huts()
			_string_lights(low)
			_greenery(low, true)
			_temple()
		"school":
			_env(Color("6ea7e0"), Color("dbe8f0"), Color(0.8, 0.82, 0.86), 1.1, Vector3(-55, 30, 0), Color(1.0, 0.97, 0.9),
				"qwantani_noon_puresky", 1.0, 150.0)
			spots = _ground_crowd(low, true)
			_school()
			_greenery(low, false)
		"arena":
			_env(Color("0c0f18"), Color("1a2030"), Color(0.62, 0.64, 0.72), 1.0, Vector3(-65, 20, 0), Color(1.0, 0.98, 0.95))
			spots = _stands(14 if not low else 9, true)
			_roof_lights()
		"stadium":
			_env(Color("060914"), Color("161c33"), Color(0.5, 0.52, 0.62), 0.95, Vector3(-70, -15, 0), Color(1.0, 0.93, 0.8),
				"kloppenheim_02_puresky", 0.32, 150.0)
			spots = _stands(16 if not low else 10, false)
			_floodlights()
			_skyline(low, 80.0, 6 if not low else 4)
	add_child(_ground.commit(ground_material(kind, f)))
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	if not _plaster.verts.is_empty():
		add_child(_plaster.commit(Props.textured("clay_plaster" if kind == "village" else "yellow_plaster", 2.0)))
	if not _tiles.verts.is_empty():
		add_child(_tiles.commit(Props.textured("clay_roof_tiles", 2.0)))
	if not _thatch.verts.is_empty():
		add_child(_thatch.commit(Props.textured("thatch_roof_angled", 2.5)))
	if not _concrete.verts.is_empty():
		add_child(_concrete.commit(Props.textured("plastered_wall", 3.0, 0.9)))
	if not _chairs.is_empty():
		Props.place(self, "seating/monobloc_chair", _chairs)
	if not _benches.is_empty():
		Props.place(self, "seating/painted_bench", _benches)
	if not spots.is_empty():
		crowd = Crowd.new()
		crowd.build(spots, Game.crowd_density(), home_colors, hash(venue), kind in ["arena", "stadium"])
		add_child(crowd)


## How loud the place is (0-1).
func atmosphere() -> float:
	return {"village": 0.55, "school": 0.45, "arena": 0.95, "stadium": 0.85}.get(String(DB.venue(venue)[4]), 0.6)


# ---------------------------------------------------------------- light

const SHADOW_SUN := 0.18


func _env(top: Color, horizon: Color, ambient: Color, energy: float, sun_rot: Vector3, sun_col: Color, sky_name := "",
		sky_energy := 1.0, sky_turn := 0.0) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = top
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if int(Game.settings.graphics) >= Game.GFX_MEDIUM else Environment.TONE_MAPPER_LINEAR
	if int(Game.settings.graphics) < Game.GFX_MEDIUM:
		env.ambient_light_energy = 0.8   # the linear tone mapper draws darker: lift the shade to match Medium
	if int(Game.settings.graphics) >= Game.GFX_HIGH:
		env.fog_enabled = true
		env.fog_light_color = horizon
		env.fog_density = 0.004 if sky_name == "" else 0.0015
		env.fog_sky_affect = 0.0   # a photographed sky has its own haze
	if sky_name != "":
		# A photographed sky (Poly Haven, CC0) as the background on every level: a panorama, nothing computed from it.
		# High has it at 4k (the same photograph, its colours matched to the 2k: tools/env/make_sky_4k.py).
		var sky_mat := PanoramaSkyMaterial.new()
		var sky_4k := Props.ENV + "skies/%s_sky_4k.jpg" % sky_name
		sky_mat.panorama = load(sky_4k if int(Game.settings.graphics) == Game.GFX_HIGH and ResourceLoader.exists(sky_4k) else Props.ENV + "skies/%s_sky_2k.jpg" % sky_name)
		sky_mat.energy_multiplier = sky_energy
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.sky_rotation = Vector3(0, deg_to_rad(sky_turn), 0)
		if int(Game.settings.graphics) >= Game.GFX_HIGH:
			env.fog_light_color = horizon.lerp(Color(0.75, 0.72, 0.8), 0.5)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = energy
	sun.light_color = sun_col
	sun.shadow_enabled = Game.shadows_enabled()
	if sun.shadow_enabled:
		# The Compatibility renderer lights far more strongly from a shadowed sun (measured at the school: the field
		# 238 against 166 from the same sun unshadowed, and 165 at 0.18 of its energy): High matches Medium so.
		sun.light_energy = energy * SHADOW_SUN
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	if sky_name == "":
		# Indoors, or a night with no sky picture: a dome coloured from the horizon up.
		var to_sun := Basis.from_euler(sun_rot * PI / 180.0) * Vector3.BACK
		_glow.dome(90.0, horizon, top, sun_col.lerp(horizon, 0.3), to_sun, 5 if int(Game.settings.graphics) == Game.GFX_LOW else 8, 20 if int(Game.settings.graphics) == Game.GFX_LOW else 28)


## The ground's material: a photo-scanned surface (Poly Haven, CC0) laid from above, in its own colour for earth
## (the field's own vertex colour is the reference: the lobby and the ground round it darker or lighter by theirs),
## or as grain under the colours for the fast game's mats; at the school, worn grass beyond the lobby. Lighter where
## the play wears it (along the lane, round the poles). (Its normal map, tried on Medium and High, lit the ground
## unevenly from the broadcast camera's height and is left off.)
const GROUND := {"village": ["red_laterite_soil_stones", ""], "school": ["dry_ground_01", "sparse_grass"],
	"stadium": ["terrain_red_01", ""], "arena": ["rubber_tiles", ""]}


static func ground_material(p_kind: String, fd: Dictionary) -> ShaderMaterial:
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var pick: Array = GROUND.get(p_kind, GROUND["village"])
	var mat := p_kind == "arena"
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode %s specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 mean = vec3(0.1);
uniform vec3 edge_mean = vec3(0.1);
uniform vec3 edge_col = vec3(0.3, 0.28, 0.12);
uniform float tile = 2.5;
uniform vec2 edge_from = vec2(20.0, 12.0);
uniform float half_gap = 12.0;
uniform float wear = 0.1;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz / tile;
	vec3 t = texture(albedo_tex, uv).rgb;
	// The photo in its own colour, brought to the brightness of the ground's own colour there (the lobby and the
	// ground round it darker than the field).
	const vec3 L = vec3(0.2126, 0.7152, 0.0722);
	vec3 c = t * clamp(dot(COLOR.rgb, L) / dot(mean, L), 0.2, 4.0);
	%s
	%s
	float lane = exp(-wpos.z * wpos.z / 2.5) * (1.0 - smoothstep(half_gap, half_gap + 2.0, abs(wpos.x)));
	float poles = exp(-(pow(abs(wpos.x) - half_gap, 2.0) + wpos.z * wpos.z) / 3.0);
	ALBEDO = c * (1.0 + wear * max(lane, poles));
	%s
}
""" % ["vertex_lighting," if low else "",
		# Mats: the rubber's grain, softer.
		"c = COLOR.rgb * mix(1.0, clamp(dot(t, L) / dot(mean, L), 0.5, 1.6), 0.35);" if mat else "",
		"float e = smoothstep(0.0, 4.0, max(abs(wpos.x) - edge_from.x, abs(wpos.z) - edge_from.y)); c = mix(c, edge_col * clamp(texture(edge_tex, uv * 0.8).rgb / edge_mean, vec3(0.2), vec3(2.5)), e);" if pick[1] != "" else "",
		""]
	var m := ShaderMaterial.new()
	m.shader = sh
	var tex := Props.surface(pick[0])
	m.set_shader_parameter("albedo_tex", tex[0])
	if pick[1] != "":
		m.set_shader_parameter("edge_tex", Props.surface(pick[1])[0])
	m.set_shader_parameter("mean", MEANS[pick[0]])
	if pick[1] != "":
		m.set_shader_parameter("edge_mean", MEANS[pick[1]])
		var ec := Color("6e6a3a").srgb_to_linear()
		m.set_shader_parameter("edge_col", Vector3(ec.r, ec.g, ec.b))
	m.set_shader_parameter("tile", 3.0 if not mat else 1.2)
	m.set_shader_parameter("half_gap", float(fd.pole_gap) * 0.5)
	m.set_shader_parameter("edge_from", Vector2(float(fd.length) * 0.5 + float(fd.lobby) + 1.0, float(fd.width) * 0.5 + float(fd.lobby) + 1.0))
	m.set_shader_parameter("wear", 0.1 if not mat else 0.03)
	return m


## Each surface's average colour (linear), measured from its photo (python, PIL): what the ground shader divides out.
const MEANS := {
	"red_laterite_soil_stones": Vector3(0.1318, 0.0464, 0.0244),
	"dry_ground_01": Vector3(0.2425, 0.2031, 0.1494),
	"sparse_grass": Vector3(0.0792, 0.0455, 0.0055),
	"terrain_red_01": Vector3(0.0797, 0.0511, 0.0330),
	"rubber_tiles": Vector3(0.0104, 0.0111, 0.0142),
}


# ---------------------------------------------------------------- the field

func _field() -> void:
	var L: float = f.length * 0.5
	var W: float = f.width * 0.5
	var lobby: float = f.lobby
	var mat := surface() == "mat"
	var earth := Color("a8573a") if time_of_day() != "day" else Color("b8693f")
	var outside := (Color("7a4a34") if kind != "school" else Color("8a7a52")) if not mat else Color("1b2433")
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


## Where the timekeeper sits: the officials' table, at his whistle's height.
func table_pos() -> Vector3:
	return Vector3(0, 1.2, -(f.width * 0.5 + f.lobby + 1.4))


## The officials' table and the benches, on the far side line.
func _table() -> void:
	var z: float = -(f.width * 0.5 + f.lobby + 1.4)
	if surface() == "mat":
		# The hall's: a draped table and the teams' benches.
		_lit.box(Vector3(0, 0.38, z), Vector3(3.2, 0.06, 0.8), Color("e9e2d0"))
		_lit.box(Vector3(0, 0.2, z - 0.05), Vector3(3.1, 0.38, 0.7), Color("2c5a8a"))
		for s: float in [-1.0, 1.0]:
			_lit.box(Vector3(s * 6.5, 0.22, z - 0.3), Vector3(5.0, 0.08, 0.5), Color("7a5432"))
			for k in 3:
				_lit.box(Vector3(s * 6.5 - 2.0 + k * 2.0, 0.1, z - 0.3), Vector3(0.08, 0.2, 0.4), Color("5a3a20"))
	else:
		# A ground's: the scorers' trestle table and painted wooden benches for the teams (the shared assets).
		Props.place(self, "props/scorers_table", [Props.at(Vector3(0, 0, z))])
		for s: float in [-1.0, 1.0]:
			for k in 4:
				_benches.append(Props.at(Vector3(s * 6.5 - 1.8 + k * 1.2, 0, z - 0.3)))
	# A shamiana over the table: a striped canopy on four poles.
	if int(Game.settings.graphics) > Game.GFX_LOW and surface() != "mat":
		for sx: float in [-1.8, 1.8]:
			for sz: float in [-0.9, 0.9]:
				_lit.cylinder(Vector3(sx, 0, z + sz), Vector3(sx, 2.4, z + sz), 0.03, 0.03, Color("d8d0c0"), 6, false)
		for i in 6:
			var c := Color("d63a2a") if i % 2 == 0 else Color("f2e6c8")
			_lit.box(Vector3(-1.8 + 0.6 * i + 0.3, 2.42, z), Vector3(0.6, 0.04, 2.0), c)


# ---------------------------------------------------------------- the places

## People round a ground: on white plastic chairs in front (on benches, at the school), sitting on the earth behind
## them, then standing, four or five deep.
func _ground_crowd(low: bool, kids := false) -> Array:
	var spots := []
	var L: float = f.length * 0.5 + f.lobby + 1.0
	var W: float = f.width * 0.5 + f.lobby + 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows := 3 if low else 5
	for r in rows:
		var d := 1.0 + r * 0.9
		var seat := r == 0          # the front row: chairs (benches at the school)
		# Low: chairs only on the far side, which the camera faces (a low chair is 618 triangles; a ring of 118 was
		# 73,000 on the budget of 90,000). Elsewhere that row sits on the earth.
		var seat_ends := seat and not low
		var ground := r == 1        # the next: on the earth
		var step := (0.6 if kids else 0.75) if seat else (0.75 if ground else 0.6)
		var y := 0.45 if seat else (-0.42 if ground else 0.0)
		var x := -L - d
		while x < L + d:
			# The far side, behind the table, and the two ends; the near side only far to the left and right.
			var far := Vector3(x + (0.0 if seat else rng.randf_range(-0.2, 0.2)), y, -W - d - 1.8)
			spots.append(far)
			if seat and not kids:
				_chairs.append(Props.at(Vector3(far.x, 0, far.z), rng.randf_range(-0.12, 0.12)))
			if absf(x) > 9.0:
				var nr := Vector3(x + (0.0 if seat else rng.randf_range(-0.2, 0.2)), y if (seat_ends or not seat) else -0.42, W + d)
				spots.append(nr)
				if seat_ends and not kids:
					_chairs.append(Props.at(Vector3(nr.x, 0, nr.z), PI + rng.randf_range(-0.12, 0.12)))
			x += step
		var zz := -W
		while zz < W:
			for s: float in [-1.0, 1.0]:
				var e := Vector3(s * (L + d), y if (seat_ends or not seat) else -0.42, zz + (0.0 if seat else rng.randf_range(-0.2, 0.2)))
				spots.append(e)
				if seat_ends and not kids:
					_chairs.append(Props.at(Vector3(e.x, 0, e.z), -s * PI * 0.5 + rng.randf_range(-0.12, 0.12)))
			zz += step
		if seat and kids:
			# Pupils on painted benches, two to a bench.
			var bx := -L - d
			while bx < L + d:
				_benches.append(Props.at(Vector3(bx + 0.3, 0, -W - d - 1.8)))
				bx += 1.2
	if kids:
		for i in spots.size():
			var v: Vector3 = spots[i]
			if v.y <= 0.0:
				spots[i] = v - Vector3(0, 0.25, 0)
	return spots


## Tiers of seats on the far side and both ends (the near side is where the cameras are).
func _stands(rows: int, indoor: bool) -> Array:
	var spots := []
	var L: float = f.length * 0.5 + f.lobby + 3.0
	var W: float = f.width * 0.5 + f.lobby + 3.2
	var seat := Color("2b3550") if indoor else Color(0.78, 0.78, 0.8)
	var riser := Color("1c2233") if indoor else Color(0.6, 0.6, 0.64)
	# Outdoors the terraces are concrete (a photo-scanned finish); indoors, painted seating.
	var g: Geo = _lit if indoor else _concrete
	for r in rows:
		var d := r * 0.85
		var hgt := 0.45 + r * 0.45
		# Far side.
		g.box(Vector3(0, hgt - 0.22, -W - d), Vector3(L * 2 + d * 2, 0.45, 0.85), seat if r % 2 == 0 else riser)
		# Ends.
		for s: float in [-1.0, 1.0]:
			g.box(Vector3(s * (L + d), hgt - 0.22, 0), Vector3(0.85, 0.45, W * 2 + d * 2), seat if r % 2 == 0 else riser)
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
	# Rows of fluorescent battens under the deck (the shared assets), each lit.
	var lights := []
	for i in 9:
		for k in 4:
			lights.append(Props.at(Vector3(-16.0 + i * 4.0, 13.9, -9.0 + k * 6.0), 0.0, 1.8))
	Props.place(self, "hall/fluorescent_light", lights)
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


## Trees and plants round a ground (the shared assets): rain trees, the wide shade trees of Indian grounds, near
## the ground; coconut palms at the village; tropical trees further off; dry grass and green clumps at the edges.
## Every one is a cut-out (4 triangles), on every level: see below.
func _greenery(low: bool, village: bool) -> void:
	Props.card_light = Color(0.78, 0.72, 0.74) if village else Color(0.95, 0.95, 0.93)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var near := {"trees/rain_tree": [], "trees/coconut_palm": []}
	var cards := {"trees/rain_tree_card": [], "trees/coconut_palm_card": [], "trees/island_tree_a_card": [],
		"trees/island_tree_b_card": [], "foliage/dry_grass_tall_card": [], "foliage/grass_clumps_card": []}
	# Near: behind the far side and the ends, beyond the crowd, 28 to 40 m out.
	var n_rain := 7 if village else 8
	var n_palm := 7 if village else 0
	for i in n_rain + n_palm:
		var a := PI * 1.06 + PI * 0.88 * (float(i) + rng.randf_range(-0.3, 0.3)) / float(n_rain + n_palm - 1)
		var r := rng.randf_range(30.0, 40.0)
		var p := Vector3(cos(a) * r * 1.15, 0, sin(a) * r * 0.85 - 4.0)
		var palm := village and (i % 2 == 1) and n_palm > 0
		var t := Props.at(p, rng.randf() * TAU, rng.randf_range(0.8, 1.05) if not palm else rng.randf_range(0.75, 1.0))
		# Every tree here stands 30 m or more from the camera, where the cut-outs (rendered from the full models)
		# look truer than the models themselves (faceted under a low sun): the cut-outs on every level.
		cards["trees/coconut_palm_card" if palm else "trees/rain_tree_card"].append(t)
	# Far: a ring of tropical trees as cut-outs, 50 to 70 m out, round the back and the sides.
	for i in (14 if low else 22):
		var a := PI * 0.95 + PI * 1.1 * float(i) / float((14 if low else 22) - 1) + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(50.0, 68.0)
		var p := Vector3(cos(a) * r * 1.1, 0, sin(a) * r * 0.8 - 6.0)
		var which: String = ["trees/island_tree_a_card", "trees/island_tree_b_card", "trees/rain_tree_card"][i % 3]
		if village and i % 4 == 1:
			which = "trees/coconut_palm_card"
		cards[which].append(Props.at(p, rng.randf() * TAU, rng.randf_range(0.8, 1.2)))
	# The edges: clumps of dry grass and green grass round the outside of the crowd (not on Low).
	if not low:
		var L: float = f.length * 0.5 + f.lobby + 7.0
		var W: float = f.width * 0.5 + f.lobby + 7.5
		for i in 46:
			var side := i % 3
			var p := Vector3(rng.randf_range(-L - 4.0, L + 4.0), 0, -W - rng.randf_range(0.0, 6.0)) if side == 0 else \
				Vector3((L + rng.randf_range(0.0, 6.0)) * (1.0 if side == 1 else -1.0), 0, rng.randf_range(-W, W))
			var which := "foliage/dry_grass_tall_card" if (village and rng.randf() < 0.6) else "foliage/grass_clumps_card"
			cards[which].append(Props.at(p + Vector3(0, 0.02, 0), rng.randf() * TAU, rng.randf_range(0.6, 1.1)))
	for k in near:
		Props.place(self, k, near[k])
	for k in cards:
		Props.place(self, k, cards[k], false)


## The village temple (the lead's shared assets; the owner had it made): a whitewashed shrine with saffron and red
## stripes at the edge of the ground, its porch facing the field, a rain tree beside it and a few chairs in its
## forecourt.
func _temple() -> void:
	var p := Vector3(-13.5, 0, -24.0)
	Props.place(self, "buildings/indian_village_temple", [Props.at(p, atan2(-p.x, -p.z))])
	Props.place(self, "trees/rain_tree_card", [Props.at(p + Vector3(-7.0, 0, -2.5), 0.6, 0.95)], false)
	var face := atan2(-p.x, -p.z)
	for k in 3:
		var off := Basis(Vector3.UP, face) * Vector3(-1.6 + k * 1.0, 0, 4.2)
		_chairs.append(Props.at(p + off, face + PI + randf_range(-0.3, 0.3)))


## A town behind the place: painted apartment blocks on the skyline (the shared assets).
func _skyline(low: bool, dist: float, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var xf := []
	for i in n:
		var a := PI * 1.2 + PI * 0.6 * float(i) / float(maxi(n - 1, 1)) + rng.randf_range(-0.04, 0.04)
		var r := dist + rng.randf_range(-6.0, 10.0)
		var p := Vector3(cos(a) * r * 1.2, 0, sin(a) * r * 0.8)
		xf.append(Props.at(p, -a - PI * 0.5 + rng.randf_range(-0.3, 0.3), rng.randf_range(0.9, 1.3)))
	Props.place(self, "buildings/city_apartments", xf)


## Village houses: plastered walls on a plinth (clay plaster), a thatched or clay-tiled roof over the eaves, a
## door and a window.
func _huts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var walls := [Color("e8d6b8"), Color("f2e4c8"), Color("e0c8a8"), Color("efe2c6"), Color("d8dccf")]
	for i in 6:
		var p := Vector3(-34.0 + i * 13.5 + rng.randf_range(-2, 2), 0, -28.0 - (i % 2) * 5.0 - rng.randf_range(0, 3))
		var w := rng.randf_range(4.5, 6.5)
		var d := rng.randf_range(3.4, 4.4)
		var hgt := rng.randf_range(2.4, 2.9)
		var wall: Color = walls[i % walls.size()]
		_lit.box(p + Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, d + 0.4), Color("8f7a5e"))
		_plaster.box(p + Vector3(0, 0.3 + hgt * 0.5, 0), Vector3(w, hgt, d), wall)
		var thatch := i % 3 != 2
		(_thatch if thatch else _tiles).prism(p + Vector3(0, 0.3 + hgt, 0), w + 1.0, d + 1.4, rng.randf_range(1.2, 1.7),
			Color(0.95, 0.92, 0.85) if thatch else Color(0.95, 0.85, 0.8))
		_lit.box(p + Vector3(-w * 0.15, 0.3 + 0.95, d * 0.5 + 0.01), Vector3(0.95, 1.9, 0.04), Color("4a2e1a"))
		_lit.box(p + Vector3(w * 0.25, 0.3 + 1.5, d * 0.5 + 0.01), Vector3(0.9, 0.75, 0.04), Color("2c3a44"))


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
	_plaster.box(Vector3(0, 3.5, z - 1.0), Vector3(46, 7.0, 5.0), Color(1, 1, 1))
	_lit.box(Vector3(0, 3.5, z + 1.6), Vector3(46.4, 0.25, 1.4), Color("d8c08c"))     # the first floor's verandah
	_lit.box(Vector3(0, 7.1, z + 0.6), Vector3(47, 0.35, 7.2), Color("9a3a2a"))       # the roof slab's edge
	_plaster.box(Vector3(0, 7.6, z + 3.0), Vector3(47, 0.7, 0.2), Color(0.92, 0.92, 0.92))    # the parapet
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
	_plaster.box(Vector3(0, 0.6, -18.5), Vector3(50, 1.2, 0.25), Color(0.85, 0.85, 0.85))
	# The town behind the school.
	_skyline(low, 55.0, 4 if not low else 3)
	if not low:
		for i in 11:
			_lit.box(Vector3(-25.0 + i * 5.0, 0.7, -18.5), Vector3(0.4, 1.4, 0.4), Color("bdb3a0"))
