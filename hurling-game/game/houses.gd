class_name Houses
extends RefCounted
## Irish houses made in code (the owner: "the houses on the outskirts look bad ... update those to look like real
## houses"; the scanned models were scraps of a city block in a 512-pixel texture): a town's terrace of two-storey
## houses, each rendered in its own colour under a slate roof, with chimney stacks on the party walls, white sash
## windows, a coloured front door with its fanlight and a sill and plinth; and a country cottage, whitewashed under a
## thatch, with its half door. Each is one mesh coloured by vertex, placed many times by Scenery (one draw call a
## kind). Marked in the vertex alpha for Scenery's house material: the glass (0, some lit at night), and each house's
## render and door by its place in the row (FACADE + slot * STEP, DOOR + slot * STEP), so every row placed gets its
## own colours from RENDER and DOORS, picked by its seed.

const ROW_W := 28.0       # a row of five houses, the size of the scanned row it replaces
const ROW_D := 8.2
const EAVES := 6.2        # two storeys
const RIDGE := 2.6        # the roof's height over the eaves

## Colours of the render, as Irish towns paint their houses, and of the doors.
const RENDER := ["e9dfc6", "efeee8", "e8cd86", "aab89b", "9fb4c6", "c47a5c", "d8a4a0", "bcb8af", "8f3d33", "b9d5c1",
	"d6c3a5", "f0e3b4"]
const DOORS := ["a8262a", "23365e", "2f5b3a", "1c1c1c", "d9a521", "3a6ea5", "6b2a4a", "f2f0ea"]
const SLATE := ["4a4f57", "54585e", "434852", "5b5552"]
const GLASS := Color(0.15, 0.19, 0.23, 0.0)   # alpha 0: a window (lit at night)
const FRAME := Color("f2f1ec")
const FACADE := 0.3       # the alpha marking house slot 0's render; slot k is FACADE + k * STEP
const DOOR := 0.6         # and its door
const STEP := 0.05

static var _meshes := {}


## The mesh for a name Scenery places: "house_row" (a terrace) or "house_cottage".
static func mesh(name: String) -> ArrayMesh:
	if not _meshes.has(name):
		_meshes[name] = _row(0) if name.begins_with("house_row") else _cottage(0)
	return _meshes[name]


static func _facade(slot: int) -> Color:
	return Color(0.8, 0.8, 0.8, FACADE + slot * STEP)


static func _door_mark(slot: int) -> Color:
	return Color(0.3, 0.3, 0.3, DOOR + slot * STEP)


## A terrace of five houses along x, its front (+z) to the street, centred on the origin.
static func _row(variant: int) -> ArrayMesh:
	var g := Geo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + variant * 31
	var n := 5
	var w := ROW_W / n
	var hd := ROW_D * 0.5
	var slate := Color(SLATE[variant % SLATE.size()])
	for i in n:
		var x0 := -ROW_W * 0.5 + i * w
		var x1 := x0 + w
		var col := _facade(i)
		var eaves := EAVES + (0.25 if rng.randf() < 0.3 else 0.0)
		# The walls: front and back in the house's colour, a darker plinth along the foot.
		g.box(Vector3((x0 + x1) * 0.5, eaves * 0.5, 0), Vector3(w, eaves, ROW_D), col, 0.0, false)
		g.box(Vector3((x0 + x1) * 0.5, 0.22, hd + 0.03), Vector3(w, 0.44, 0.08), Color("6a665e"), 0.0, false)
		# The front: the door to one side, a window beside it, two above; a sill under each.
		var door_left := rng.randf() < 0.5
		var dx := x0 + (0.9 if door_left else w - 0.9 - 1.0)
		var wx := x0 + (w - 1.0 - 1.3 if door_left else 1.0)
		_door(g, Vector3(dx + 0.5, 0, hd), _door_mark(i))
		_window(g, Vector3(wx + 0.65, 1.0, hd), Vector2(1.3, 1.5))
		for k in 2:
			_window(g, Vector3(x0 + w * (0.27 + 0.46 * k), 3.7, hd), Vector2(1.0, 1.45))
		# The back: two windows, plainer.
		for k in 2:
			_window(g, Vector3(x0 + w * (0.3 + 0.4 * k), 3.7, -hd), Vector2(0.9, 1.2), true)
		# The roof: two slopes of slate, a little over the walls; a gutter along the front.
		_roof(g, x0 - 0.02, x1 + 0.02, hd + 0.3, eaves, RIDGE, slate.lightened(rng.randf_range(-0.05, 0.05)))
		g.box(Vector3((x0 + x1) * 0.5, eaves - 0.05, hd + 0.38), Vector3(w + 0.04, 0.14, 0.14), Color("2b2e33"), 0.0, false)
	# Chimney stacks on the party walls and the ends, on the ridge, with their pots.
	for i in n + 1:
		var x: float = clampf(-ROW_W * 0.5 + i * w, -ROW_W * 0.5 + 0.35, ROW_W * 0.5 - 0.35)
		var top := EAVES + RIDGE + 1.0
		g.box(Vector3(x, top - 0.9, 0), Vector3(0.7, 1.8, 1.0), Color("b9ab98") if i % 2 == 0 else Color("a29482"))
		g.box(Vector3(x, top + 0.02, 0), Vector3(0.8, 0.12, 1.1), Color("8d8274"))
		for k in 2:
			g.cylinder(Vector3(x, top + 0.08, -0.22 + k * 0.44), Vector3(x, top + 0.45, -0.22 + k * 0.44), 0.11, 0.09,
				Color("a0563d"), 6)
	# The gable ends, rendered in the end houses' colours.
	_gable(g, -ROW_W * 0.5 - 0.01, -1.0, hd, EAVES, RIDGE, _facade(0))
	_gable(g, ROW_W * 0.5 + 0.01, 1.0, hd, EAVES, RIDGE, _facade(n - 1))
	return g.mesh()


## A cottage: whitewashed, single-storey, under a thatch with deep eaves; small windows and a half door.
static func _cottage(variant: int) -> ArrayMesh:
	var g := Geo.new()
	var w := 9.6
	var d := 6.0
	var hd := d * 0.5
	var wall := 2.7
	var white := Color("eeece4")
	g.box(Vector3(0, wall * 0.5, 0), Vector3(w, wall, d), white, 0.0, false)
	g.box(Vector3(0, 0.2, hd + 0.03), Vector3(w, 0.4, 0.08), Color("6d6d66"), 0.0, false)
	var trim := _door_mark(0)
	_door(g, Vector3(-0.6, 0, hd), trim, 2.0)
	for x in [-3.2, 1.4, 3.4]:
		_window(g, Vector3(x, 0.95, hd), Vector2(0.9, 1.0), false, trim)
	_window(g, Vector3(0.0, 0.95, -hd), Vector2(0.9, 1.0), true, trim)
	# The thatch: deep, golden brown, rounded over the eaves (two slopes and a roll along the ridge).
	var thatch := Color("a7834c")
	_roof(g, -w * 0.5 - 0.45, w * 0.5 + 0.45, hd + 0.6, wall - 0.1, 3.0, thatch)
	g.cylinder(Vector3(-w * 0.5 - 0.45, wall + 2.85, 0), Vector3(w * 0.5 + 0.45, wall + 2.85, 0), 0.32, 0.32, thatch.darkened(0.1), 8)
	_gable(g, -w * 0.5 - 0.01, -1.0, hd, wall, 2.9, white)
	_gable(g, w * 0.5 + 0.01, 1.0, hd, wall, 2.9, white)
	# A chimney at each end, whitewashed.
	for sx in [-1.0, 1.0]:
		g.box(Vector3(sx * (w * 0.5 - 0.5), wall + 2.4, 0), Vector3(0.8, 2.2, 0.9), white)
	return g.mesh()


## A window in a wall facing +z (or -z, back): its white frame, the glass, the sash bar and a sill. centre_x, y the
## bottom of the opening.
static func _window(g: Geo, at: Vector3, size: Vector2, back := false, frame := FRAME) -> void:
	var s := -1.0 if back else 1.0
	var z := at.z
	var c := Vector3(at.x, at.y + size.y * 0.5, z + s * 0.02)
	g.box(c, Vector3(size.x + 0.18, size.y + 0.18, 0.04), frame, 0.0, false)
	g.box(c + Vector3(0, 0, s * 0.025), Vector3(size.x, size.y, 0.03), GLASS, 0.0, false)
	g.box(c + Vector3(0, 0, s * 0.05), Vector3(size.x, 0.06, 0.03), frame, 0.0, false)
	g.box(c + Vector3(0, 0, s * 0.05), Vector3(0.05, size.y, 0.03), frame, 0.0, false)
	g.box(Vector3(at.x, at.y - 0.06, z + s * 0.08), Vector3(size.x + 0.3, 0.1, 0.18), Color("d9d6cc"), 0.0, false)


## A front door in a wall facing +z at x, with its fanlight over it (none for a cottage's half door).
static func _door(g: Geo, at: Vector3, col: Color, h := 2.2) -> void:
	g.box(Vector3(at.x, h * 0.5, at.z + 0.03), Vector3(1.1, h + 0.1, 0.05), FRAME, 0.0, false)
	g.box(Vector3(at.x, h * 0.5 - 0.02, at.z + 0.06), Vector3(0.95, h - 0.05, 0.04), col, 0.0, false)
	if h > 2.1:
		g.box(Vector3(at.x, h + 0.28, at.z + 0.04), Vector3(0.95, 0.4, 0.04), GLASS, 0.0, false)
	g.box(Vector3(at.x + 0.3, h * 0.48, at.z + 0.1), Vector3(0.06, 0.06, 0.05), Color("c9a646"), 0.0, false)


## Two slopes of a roof from x0 to x1, its eaves at height e over z = ±hd, its ridge h higher over z = 0.
static func _roof(g: Geo, x0: float, x1: float, hd: float, e: float, h: float, col: Color) -> void:
	var nf := Vector3(0, hd, h).normalized()
	var nb := Vector3(0, hd, -h).normalized()
	g.quad(Vector3(x0, e + h, 0), Vector3(x1, e + h, 0), Vector3(x1, e, hd), Vector3(x0, e, hd), nf, col)
	g.quad(Vector3(x1, e + h, 0), Vector3(x0, e + h, 0), Vector3(x0, e, -hd), Vector3(x1, e, -hd), nb, col.darkened(0.08))
	# The undersides of the eaves, so the roof does not look paper-thin from below.
	g.quad(Vector3(x0, e, hd), Vector3(x1, e, hd), Vector3(x1, e + 0.02, hd - 0.4), Vector3(x0, e + 0.02, hd - 0.4), Vector3.DOWN, col.darkened(0.4))


## The triangle of wall between the eaves and the ridge at an end of a roof (side -1 the -x end, 1 the +x end).
static func _gable(g: Geo, x: float, side: float, hd: float, e: float, h: float, col: Color) -> void:
	var apex := Vector3(x, e + h, 0)
	if side < 0.0:
		g.tri(apex, Vector3(x, e, hd), Vector3(x, e, -hd), Vector3.LEFT, col.darkened(0.08))
	else:
		g.tri(apex, Vector3(x, e, -hd), Vector3(x, e, hd), Vector3.RIGHT, col.darkened(0.08))
