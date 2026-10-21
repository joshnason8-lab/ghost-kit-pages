class_name Arena
extends Node3D
## A floorball venue: the rink to the IFF's measurements (Rules 101-105) and the hall round it. A local sports hall
## (birch walls, one bank of seats behind the benches), a city arena (dark, stands all round, a hanging scoreboard)
## or a school gym (a few parents on the wall bars' side).
##
## The rink: the sports floor with its markings painted into one texture (lines 5 cm, the goal creases, the
## goalkeeper areas, the centre line and spot, the face-off dots), the white boards with rounded corners, the two red
## goals with their nets, the substitution zones and benches on the far side, the penalty benches and the
## secretariat on the near side. Everything static is merged by material (Geo): a handful of draw calls, and the crowd
## one more (Crowd).

const FLOOR_PX := 32.0        # floor texture pixels a metre (40 m x 20 m: 1280 x 640)

var venue := "hall"
var home_colors: Array = []
var away_colors: Array = []
var crowd: Crowd
var bench_crowd: Crowd
var _lit: Geo
var _glow: Geo

static var _floor_tex: ImageTexture
static var _net_tex: ImageTexture


func _init(p_venue := "hall", p_home := [], p_away := []) -> void:
	venue = p_venue
	home_colors = p_home
	away_colors = p_away


func _ready() -> void:
	var v: Dictionary = DB.VENUES.get(venue, DB.VENUES.hall)
	_lit = Geo.new()
	_glow = Geo.new()
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	_env(venue, float(v.light))
	_floor()
	_boards()
	_goals()
	_benches()
	var spots: Array = []
	var walls := Color(String(v.walls))
	match String(v.stands):
		"bowl":
			_hall_box(walls, 34.0, 26.0, 16.0)
			spots = _stands(-1, 14 if not low else 10, walls)
			spots.append_array(_stands(1, 14 if not low else 10, walls))
			spots.append_array(_end_stands(-1, 10 if not low else 6, walls))
			spots.append_array(_end_stands(1, 10 if not low else 6, walls))
			_scoreboard_cube()
		"side":
			_hall_box(walls, 27.0, 18.0, 10.0)
			spots = _stands(-1, 7, Color("c8ad7f"))
			_wall_bars(1)
		_:
			_hall_box(walls, 24.0, 15.5, 8.0)
			spots = _stands(-1, 3, Color("c8ad7f"))
			_wall_bars(-1)
			_wall_bars(1)
	_ceiling_lights(float(v.light))
	add_child(_lit.commit(Geo.material(true)))
	add_child(_glow.commit(Geo.material(false)))
	crowd = Crowd.new()
	var palette: Array = home_colors.duplicate()
	palette.append_array(away_colors)
	crowd.build(spots, Game.crowd_density() * (1.0 if venue != "school" else 0.6), palette, hash(venue))
	add_child(crowd)


# ---------------------------------------------------------------- light

func _env(kind: String, energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15181d") if kind == "arena" else Color("2a2d31")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.84) if kind != "arena" else Color(0.6, 0.63, 0.7)
	env.ambient_light_energy = 0.42
	# Filmic on every level: in GL Compatibility it is a few instructions in the scene shader, and Low with the linear
	# curve showed the rink 40% darker than Medium and High (the playtest, docs/PLAYTEST.md).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The hall's lights hang over the rink: a high, soft key from above and a little to one side.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-72, 18, 0)
	sun.light_energy = 0.62 * energy
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.shadow_enabled = Game.shadows_enabled()
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# ---------------------------------------------------------------- the floor and its markings (102)

func _floor() -> void:
	# The hall's floor round the rink, then the rink's own sports floor with its markings.
	_lit.floor_rect(-32, -24, 32, 24, -0.01, Color("6f7379") if venue == "arena" else Color("9a8566"))
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(Rules.LENGTH, Rules.WIDTH)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = floor_texture()
	m.albedo_color = Color(0.86, 0.86, 0.86)
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The rink's floor: blue sports flooring with white markings, 4-5 cm lines (102), drawn once.
static func floor_texture() -> ImageTexture:
	if _floor_tex:
		return _floor_tex
	var w := int(Rules.LENGTH * FLOOR_PX)
	var h := int(Rules.WIDTH * FLOOR_PX)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var base := Color("2c66ad")
	img.fill(base)
	# A faint grain of the flooring's tiles.
	for x in range(0, w, int(FLOOR_PX * 0.5)):
		img.fill_rect(Rect2i(x, 0, 1, h), base.darkened(0.03))
	var line := Color("f2f4f7")
	var lw := maxi(2, int(round(0.05 * FLOOR_PX)))
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x + Rules.HALF_L) * FLOOR_PX), int((z + Rules.HALF_W) * FLOOR_PX))
	# Centre line and spot.
	var c0: Vector2i = to_px.call(0.0, -Rules.HALF_W)
	img.fill_rect(Rect2i(c0.x - lw / 2, 0, lw, h), line)
	_disc(img, to_px.call(0.0, 0.0), 0.12 * FLOOR_PX, line)
	for end: int in [-1, 1]:
		# The goal crease, 4 x 5 m (102.3), and the goalkeeper area, 1 x 2.5 m, its rear line the goal line (102.4).
		var cx0: float = minf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		var cx1: float = maxf(Rules.CREASE_FRONT * end, Rules.CREASE_BACK * end)
		_rect_outline(img, to_px.call(cx0, -Rules.CREASE_HALF_W), to_px.call(cx1, Rules.CREASE_HALF_W), lw, line)
		var gx0: float = minf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		var gx1: float = maxf(Rules.GK_AREA_FRONT * end, Rules.GOAL_LINE * end)
		_rect_outline(img, to_px.call(gx0, -Rules.GK_AREA_HALF_W), to_px.call(gx1, Rules.GK_AREA_HALF_W), lw, line)
		# The goal line between the posts: its marks.
		var gp: Vector2i = to_px.call(Rules.GOAL_LINE * end, 0.0)
		img.fill_rect(Rect2i(gp.x - lw / 2, int(gp.y - Rules.GOAL_W * 0.5 * FLOOR_PX), lw, int(Rules.GOAL_W * FLOOR_PX)), line)
	# The face-off dots: crosses, about 30 cm.
	for d in Rules.faceoff_dots().slice(1):
		var p: Vector2i = to_px.call(d.x, d.y)
		var arm := int(0.15 * FLOOR_PX)
		img.fill_rect(Rect2i(p.x - arm, p.y - lw / 2, arm * 2, lw), line)
		img.fill_rect(Rect2i(p.x - lw / 2, p.y - arm, lw, arm * 2), line)
	# Outside the rounded corners the boards stand: paint the hall's floor colour there so nothing shows past them.
	var hall := Color("9a8566")
	var r := Rules.CORNER_R * FLOOR_PX
	for sx: int in [0, 1]:
		for sz: int in [0, 1]:
			var cx := r if sx == 0 else w - r
			var cz := r if sz == 0 else h - r
			for yy in int(r) + 1:
				for xx in int(r) + 1:
					var px := int(cx - r + xx) if sx == 0 else int(cx + xx)
					var pz := int(cz - r + yy) if sz == 0 else int(cz + yy)
					if px < 0 or pz < 0 or px >= w or pz >= h:
						continue
					if Vector2(px + 0.5, pz + 0.5).distance_to(Vector2(cx, cz)) > r:
						img.set_pixel(px, pz, hall)
	img.generate_mipmaps()
	_floor_tex = ImageTexture.create_from_image(img)
	return _floor_tex


static func _rect_outline(img: Image, a: Vector2i, b: Vector2i, lw: int, col: Color) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	img.fill_rect(Rect2i(x0, y0, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y1 - lw, x1 - x0, lw), col)
	img.fill_rect(Rect2i(x0, y0, lw, y1 - y0), col)
	img.fill_rect(Rect2i(x1 - lw, y0, lw, y1 - y0), col)


static func _disc(img: Image, c: Vector2i, r: float, col: Color) -> void:
	for y in range(int(-r) - 1, int(r) + 2):
		for x in range(int(-r) - 1, int(r) + 2):
			if Vector2(x, y).length() <= r:
				img.set_pixel(clampi(c.x + x, 0, img.get_width() - 1), clampi(c.y + y, 0, img.get_height() - 1), col)


# ---------------------------------------------------------------- the boards (101)

## The rink's outline, inside face of the boards, as a closed polyline round the rounded corners.
static func outline(margin := 0.0, corner_seg := 8) -> Array:
	var pts := []
	var hx := Rules.HALF_L + margin
	var hz := Rules.HALF_W + margin
	var r := Rules.CORNER_R + margin
	var corners := [[Vector2(hx - r, hz - r), 0.0], [Vector2(-(hx - r), hz - r), PI * 0.5], [Vector2(-(hx - r), -(hz - r)), PI],
		[Vector2(hx - r, -(hz - r)), PI * 1.5]]
	for c in corners:
		for i in corner_seg + 1:
			var a: float = float(c[1]) + PI * 0.5 * float(i) / corner_seg
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


func _boards() -> void:
	var inner := outline(0.0)
	var outer := outline(0.05)
	var h := Rules.BOARD_H
	var white := Color("f4f5f6")
	var n := inner.size()
	for i in n:
		var a: Vector2 = inner[i]
		var b: Vector2 = inner[(i + 1) % n]
		var ao: Vector2 = outer[i]
		var bo: Vector2 = outer[(i + 1) % n]
		var mid := (a + b) * 0.5
		var col := _board_colour(mid)
		# Inside face (seen from the rink), top, outside face.
		_lit.wall(Vector3(b.x, 0, b.y), Vector3(a.x, 0, a.y), 0.0, h, col)
		_lit._tri_quad(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(bo.x, h, bo.y), Vector3(ao.x, h, ao.y), Vector3.UP, white.darkened(0.04))
		_lit.wall(Vector3(ao.x, 0, ao.y), Vector3(bo.x, 0, bo.y), 0.0, h, white.darkened(0.12))


## The boards' panels: white, with bands of colour where a hall would put its sponsors' boards (no names on them), and
## the substitution zones' ends marked on the far board (104).
func _board_colour(p: Vector2) -> Color:
	if p.y < -Rules.HALF_W + 0.5:
		var ax := absf(p.x)
		if absf(ax - Rules.SUB_ZONE_FROM_CENTRE) < 0.12 or absf(ax - (Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN)) < 0.12:
			return Color("1f2933")
	var seg := int(floor((p.x + p.y * 0.5 + 40.0) / 2.0))
	if absf(p.y) > Rules.HALF_W - 0.5 and absf(p.x) < 15.0:
		return [Color("f4f5f6"), Color("1d4ed8"), Color("f4f5f6"), Color("f08a24"), Color("f4f5f6"), Color("0f8b5f")][posmod(seg, 6)]
	return Color("f4f5f6")


# ---------------------------------------------------------------- the goals (103)

func _goals() -> void:
	var red := Color("d0202e")
	var r := 0.024
	var net := Geo.new()
	for end: int in [-1, 1]:
		var x := Rules.GOAL_LINE * end
		var back := x + Rules.GOAL_D * end
		var hw := Rules.GOAL_W * 0.5
		var gh := Rules.GOAL_H
		var pl := Vector3(x, 0, -hw)
		var pr := Vector3(x, 0, hw)
		# Posts and crossbar, the bottom frame round the back, the back's sloping supports.
		_lit.cylinder(pl, pl + Vector3(0, gh, 0), r, r, red, 8, false)
		_lit.cylinder(pr, pr + Vector3(0, gh, 0), r, r, red, 8, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), pr + Vector3(0, gh, 0), r, r, red, 8, false)
		_lit.cylinder(pl, Vector3(back, 0, -hw), r, r, red, 6, false)
		_lit.cylinder(pr, Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(Vector3(back, 0, -hw), Vector3(back, 0, hw), r, r, red, 6, false)
		_lit.cylinder(pl + Vector3(0, gh, 0), Vector3(back, 0.12, -hw), r * 0.8, r * 0.8, red, 6, false)
		_lit.cylinder(pr + Vector3(0, gh, 0), Vector3(back, 0.12, hw), r * 0.8, r * 0.8, red, 6, false)
		# The net: the back slope and the two sides, both ways round so it shows from inside and out.
		var top_l := pl + Vector3(0, gh, 0)
		var top_r := pr + Vector3(0, gh, 0)
		var bl := Vector3(back, 0, -hw)
		var br := Vector3(back, 0, hw)
		for quad in [[top_l, top_r, br, bl], [top_l, bl, pl, pl], [top_r, pr, br, br]]:
			var nn = ((quad[1] - quad[0]).cross(quad[2] - quad[0])).normalized()
			net._tri_quad(quad[0], quad[1], quad[2], quad[3], nn, Color.WHITE, Rect2(0, 0, 8, 6))
			net._tri_quad(quad[3], quad[2], quad[1], quad[0], -nn, Color.WHITE, Rect2(0, 0, 8, 6))
	var m := StandardMaterial3D.new()
	m.albedo_texture = net_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(net.commit(m))


static func net_texture() -> ImageTexture:
	if _net_tex:
		return _net_tex
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in 32:
		for k in 3:
			img.set_pixel(i, k, Color(0.96, 0.96, 0.96, 1))
			img.set_pixel(k, i, Color(0.96, 0.96, 0.96, 1))
	img.generate_mipmaps()
	_net_tex = ImageTexture.create_from_image(img)
	return _net_tex


# ---------------------------------------------------------------- benches, penalty benches, secretariat (104, 105)

func _benches() -> void:
	# The teams' benches behind their substitution zones on the far side, a substitute or two on each.
	var spots: Array = []
	for side: int in [-1, 1]:
		var x0: float = Rules.SUB_ZONE_FROM_CENTRE * side
		var x1: float = (Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN) * side
		var cx := (x0 + x1) * 0.5
		_lit.box(Vector3(cx, 0.22, -Rules.HALF_W - 2.4), Vector3(Rules.SUB_ZONE_LEN, 0.44, 0.45), Color("3b4552"))
		_lit.box(Vector3(cx, 0.6, -Rules.HALF_W - 2.65), Vector3(Rules.SUB_ZONE_LEN, 0.5, 0.06), Color("2e3640"))
		for i in 8:
			spots.append(Vector3(cx - Rules.SUB_ZONE_LEN * 0.4 + i * Rules.SUB_ZONE_LEN * 0.8 / 7.0, 0.1, -Rules.HALF_W - 2.4))
	# The penalty benches (2 m each, at least 1 m from the centre line) and the secretariat between them, near side.
	_lit.box(Vector3(0, 0.4, Rules.HALF_W + 1.6), Vector3(1.6, 0.8, 0.7), Color("e9ecef"))
	_lit.box(Vector3(0, 0.82, Rules.HALF_W + 1.6), Vector3(1.7, 0.04, 0.8), Color("1d4ed8"))
	for side: int in [-1, 1]:
		_lit.box(Vector3(side * 2.2, 0.22, Rules.HALF_W + 1.3), Vector3(2.0, 0.44, 0.45), Color("3b4552"))
	bench_crowd = Crowd.new()
	var pal: Array = [home_colors[0] if not home_colors.is_empty() else Color.WHITE, away_colors[0] if not away_colors.is_empty() else Color.WHITE]
	bench_crowd.build(spots, 0.75, pal, 9)
	add_child(bench_crowd)


# ---------------------------------------------------------------- the hall

func _hall_box(walls: Color, half_x: float, half_z: float, h: float) -> void:
	var c := walls
	_lit.wall(Vector3(-half_x, 0, -half_z), Vector3(half_x, 0, -half_z), 0, h, c)
	_lit.wall(Vector3(half_x, 0, -half_z), Vector3(half_x, 0, half_z), 0, h, c.darkened(0.06))
	_lit.wall(Vector3(-half_x, 0, half_z), Vector3(-half_x, 0, -half_z), 0, h, c.darkened(0.06))
	_lit.wall(Vector3(half_x, 0, half_z), Vector3(-half_x, 0, half_z), 0, h, c.darkened(0.03))
	# A darker skirting band, and the ceiling.
	_lit.wall(Vector3(-half_x + 0.01, 0, -half_z + 0.01), Vector3(half_x - 0.01, 0, -half_z + 0.01), 0, 1.2, c.darkened(0.25))
	_lit._tri_quad(Vector3(-half_x, h, half_z), Vector3(half_x, h, half_z), Vector3(half_x, h, -half_z), Vector3(-half_x, h, -half_z), Vector3.DOWN, Color("3a3f47"))


## Rows of seats along a long side (side -1: the far side, behind the benches; 1: the near side), rising.
func _stands(side: int, rows: int, col: Color) -> Array:
	var spots: Array = []
	var z0 := (Rules.HALF_W + 3.6) * side
	for r in rows:
		var z := z0 + side * r * 0.8
		var y := 0.45 + r * 0.42
		_lit.box(Vector3(0, y * 0.5, z), Vector3(30.0, y, 0.8), col.darkened(0.04 * (r % 2)))
		var x := -14.6
		while x <= 14.6:
			spots.append(Vector3(x + randf_range(-0.08, 0.08), y, z))
			x += 0.55
	return spots


func _end_stands(end: int, rows: int, col: Color) -> Array:
	var spots: Array = []
	for r in rows:
		var x := (Rules.HALF_L + 3.0 + r * 0.8) * end
		var y := 0.45 + r * 0.42
		_lit.box(Vector3(x, y * 0.5, 0), Vector3(0.8, y, 22.0), col.darkened(0.04 * (r % 2)))
		var z := -10.5
		while z <= 10.5:
			spots.append(Vector3(x, y, z))
			z += 0.55
	return spots


func _wall_bars(side: int) -> void:
	# A school's wall bars on a long wall.
	var z := (Rules.HALF_W + 5.4) * side
	for i in 14:
		var x := -16.0 + i * 2.4
		for k in 2:
			_lit.box(Vector3(x + k * 0.9, 1.4, z), Vector3(0.06, 2.8, 0.06), Color("b08a56"))
		for j in 9:
			_lit.box(Vector3(x + 0.45, 0.2 + j * 0.3, z), Vector3(0.9, 0.04, 0.04), Color("c49a62"))


func _ceiling_lights(energy: float) -> void:
	for i in 5:
		for k in 3:
			var x := -16.0 + i * 8.0
			var z := -7.0 + k * 7.0
			_glow.box(Vector3(x, 9.6, z), Vector3(2.4, 0.08, 0.5), Color(1, 0.98, 0.92) * clampf(energy, 0.8, 1.0), 0.0, false)


func _scoreboard_cube() -> void:
	_lit.box(Vector3(0, 11.5, 0), Vector3(4.0, 2.2, 4.0), Color("15181d"))
	for k in 4:
		var a := k * PI * 0.5
		_glow.box(Vector3(sin(a) * 2.01, 11.5, cos(a) * 2.01), Vector3(3.4 if k % 2 == 0 else 0.02, 1.6, 0.02 if k % 2 == 0 else 3.4), Color("101f3a"), 0.0, false)


func _process(_delta: float) -> void:
	pass
