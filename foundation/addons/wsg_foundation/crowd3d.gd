class_name WsgCrowd3D
extends Node3D
## The 3D crowd for Medium and High: whole fans (legs and all) seated or standing in the stands, one instanced draw
## call per fan model, animated on the GPU from baked vertex-animation textures (crowd_vat.gdshader). They sit, get
## up and sit down, clap (on the clapping sound's beat) and cheer with their arms up as the excitement builds, and
## turn their heads and shoulders to the ball. Low keeps the game's own billboard crowd.
##
##   var crowd := WsgCrowd3D.new()
##   add_child(crowd)
##   crowd.build(spots, facings, density, seed)          # spots: feet (world); facings: the way each faces (flat)
##   WsgCrowd3D.set_excite(1.0)                          # a score: up they get (eased: up quick, down slow)
##   WsgCrowd3D.set_tension(0.4)                         # building pressure (a run on goal): some get up and clap
##   crowd.watch_ball(ball_position)                     # every frame
##   crowd.clap(2.4, 0.9, 6.0)                           # the rhythm clapping sound: claps/s, unison 0..1, seconds
##   crowd.set_teams(home_colour, away_colour)
## The data (the fans' meshes and textures) lives in DIR: tools/bake_crowd.gd makes it. Budget: see docs/BUDGET.md.

## The crowd's data: baked from the ActorCore crowd motions at build time (licensed, data/crowd/) if this build has
## it, else the authored motions that ship with the addon (crowd/).
static var DIR := "res://addons/wsg_foundation/data/crowd/" if FileAccess.file_exists("res://addons/wsg_foundation/data/crowd/crowd.json") else "res://addons/wsg_foundation/crowd/"
## Fans the 3D crowd draws at most, by quality (1 Medium, 2 High, 3 Close: a mode with the camera close and few
## players on the pitch - a practice, a shoot-out): WsgFoundation.crowd_budget, by the game's profile - [near (the
## full figure), in all (the rest the far figure, about a third of the triangles)]. The rest of the spots stay with
## the game's billboards.
## A fan's feet are this far in front of their origin (m): the spot given is the feet (WsgCrowdClips.FEET_FORWARD).
const FEET_FORWARD := WsgCrowdClips.FEET_FORWARD

static var _excite_target := 0.0
static var _light := 1.0
static var _tension := 0.0
static var _meta := {}
static var _seats := {}
## A seat's height over the feet (m) when a spot is just "seated": a stand's seat.
const SEAT := 0.44

var excite := 0.0
var meshes: Array[MultiMeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var used: PackedInt32Array = []         # which of the spots given are drawn in 3D (the rest: billboards)
var _ball := Vector3.ZERO
var _ball_set := false
var _clap_left := 0.0
var _clap_time := 0.0
var _clap_rate := 2.4
var _clap_sync := 0.6
## How often each fan model is picked (its name, as crowd.json has it: "fan" to "fan6"; any not given: 1), set before
## build(). The shared fans: fan2 and fan5 are women, fan, fan3 (older), fan4 and fan6 men. A crowd of mostly women
## (Netball): {"fan2": 4.0, "fan5": 4.0}. None given: each the same, and the crowd exactly as before.
var fan_weights := {}
var _looks := {}
## For each mesh in meshes: the spots its fans stand for (the indices given to build), in its instances' order; and
## each fan's transform and seated lift as placed (for the audit: a MultiMesh does not give them back headless).
var spot_of: Array = []
var placed_xf: Array = []
## The venue's places this crowd was built from (build_venue: WsgCrowdVenue.place()), for the audit.
var placed := {}
var _anchor: Array = []     # per spot: true where it is the middle of a seat (build_venue), not the feet
var _back: Variant = INF    # per spot: how far behind it the seat's back or the step behind rises (m)
var _dangle: Array = []     # per spot: the legs hang (a stool, a wall top)
var _half: Array = []       # per spot: the seat's half depth (m)
var _front: Array = []      # per spot: from the middle of the seat to the front edge of the floor under the feet (m)
var _seat_dir := PackedVector3Array()   # per spot: the seat's front (flat, unit)

## Palettes for set_looks, each dark to light (sRGB): skin tones from deep brown to fair; hair black, browns, auburn,
## blonde, grey (the grey ones older); the legs' clothes denim, black, charcoal, navy, khaki, stone.
const LOOKS := {
	"skin": [Color(0.36, 0.23, 0.17), Color(0.49, 0.32, 0.22), Color(0.62, 0.43, 0.31), Color(0.74, 0.55, 0.42),
		Color(0.84, 0.66, 0.54), Color(0.9, 0.74, 0.64), Color(0.94, 0.8, 0.71)],
	"hair": [Color(0.08, 0.07, 0.06), Color(0.17, 0.12, 0.09), Color(0.3, 0.2, 0.13), Color(0.45, 0.24, 0.13),
		Color(0.55, 0.42, 0.27), Color(0.78, 0.65, 0.42), Color(0.68, 0.67, 0.66)],
	"legs": [Color(0.09, 0.09, 0.1), Color(0.2, 0.21, 0.23), Color(0.16, 0.2, 0.33), Color(0.22, 0.32, 0.5),
		Color(0.36, 0.45, 0.6), Color(0.6, 0.55, 0.43), Color(0.75, 0.72, 0.64)],
}


## Is the crowd's data in this build?
static func available() -> bool:
	return ResourceLoader.exists(DIR + "crowd.json") or FileAccess.file_exists(DIR + "crowd.json")


static func meta() -> Dictionary:
	if _meta.is_empty() and available():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "crowd.json"))
	return _meta


## How near a spot is to the focus for choosing the 3D fans: along the stands first (whole sections out from the
## middle of the view), so the 3D fans end in a line across the stand, as between two sections, not a ring.
static func nearness(p: Vector3, focus: Vector3) -> float:
	var d := p - focus
	return absf(d.x) + absf(d.z) * 0.15


## The excitement the crowd rises to (0..1); it eases up quickly and down slowly.
static func set_excite(k: float) -> void:
	_excite_target = clampf(k, 0.0, 1.0)


## Building pressure (0..1): a floor under the excitement, so the keen ones are up before the score.
static func set_tension(k: float) -> void:
	_tension = clampf(k, 0.0, 1.0)


## What the game last asked of the crowd (WsgAudio's crowd follows it too, with or without 3D fans drawn).
static func target_excitement() -> float:
	return _excite_target


static func tension() -> float:
	return _tension


## Places the fans: spots are their feet (world), facings the way each faces (flat; toward the pitch). seated: true
## (all on seats SEAT high), false (a terrace: all standing), one bool a spot, or one number a spot (the seat's
## height over the feet, m; 0 standing): each seated fan is lifted so they sit on it, not in it. room: how far
## behind the feet the step behind rises above the seat (m; one number, or one a spot): a fan who would sit back into
## it comes forward. quality: 1 Medium, 2 High, 3 Close (WsgFoundation.crowd_budget; Low: do not build; keep the
## billboards). Returns the indices of the
## spots it drew, nearest the focus first; the game's billboards take the others. shirts: a Color a spot (the colour
## that spot's fan wears - give the cut-outs the same, and a fan keeps it between the two), or none (a team's colours
## or anything); lights: a number a spot (the seat's baked light, WsgLightBake's probes: 1 open, less under a roof).
func build(spots: Array, facings: Array, density := 1.0, seed := 0, seated: Variant = true, quality := 1, focus := Vector3.ZERO,
		room: Variant = INF, shirts: Array = [], lights: Array = []) -> PackedInt32Array:
	for g in _begin(spots, facings, density, seed, seated, quality, focus, room, shirts, lights):
		_place_group(g, 0, (g.list as Array).size())
		_add_group(g)
	_ctx = {}
	return used


## build() behind a loading overlay (WsgLoading): the same crowd (the same draws, in the same order), with a
## checkpoint every CHUNK fans, so the main thread is never held long (Hurling's practice: 2,400 full figures, 784 ms
## in one piece). LD: the overlay (WsgLoading.current() if none given; none up: no pauses).
func build_async(spots: Array, facings: Array, density := 1.0, seed := 0, seated: Variant = true, quality := 1,
		focus := Vector3.ZERO, room: Variant = INF, shirts: Array = [], lights: Array = [], ld: WsgLoading = null) -> PackedInt32Array:
	if ld == null:
		ld = WsgLoading.current()
	var groups := _begin(spots, facings, density, seed, seated, quality, focus, room, shirts, lights)
	var total := maxi(used.size(), 1)
	var done := 0
	for g in groups:
		var n := (g.list as Array).size()
		var k := 0
		while k < n:
			var e := mini(k + CHUNK, n)
			_place_group(g, k, e)
			done += e - k
			k = e
			if ld:
				await ld.checkpoint(float(done) / total)
		_add_group(g)
	_ctx = {}
	return used


## Fans placed between two checkpoints of build_async.
const CHUNK := 64
var _ctx := {}


## The draws (who is drawn, which fan model): the groups, one a fan model (near or far), each to place.
func _begin(spots: Array, facings: Array, density: float, seed: int, seated: Variant, quality: int, focus: Vector3,
		room: Variant, shirts: Array, lights: Array) -> Array:
	for m in meshes:
		m.queue_free()
	meshes.clear()
	materials.clear()
	spot_of.clear()
	placed_xf.clear()
	used = PackedInt32Array()
	var md := meta()
	if md.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# The spots nearest the action first, as many as the budget allows.
	var order := range(spots.size())
	# Nearest the focus along the stands first (whole sections, out from the middle of the view), so where the 3D
	# fans end and the cut-outs begin is a line across the stand, as between two sections, not a ring.
	order.sort_custom(func(a, b): return nearness(spots[a], focus) < nearness(spots[b], focus))
	var budget: Array = WsgFoundation.crowd_budget(quality)
	var cap := int(budget[1] * clampf(density, 0.0, 1.0))
	var near_cap := int(budget[0] * clampf(density, 0.0, 1.0))
	var take := []
	for i in order:
		if take.size() >= cap:
			break
		if rng.randf() <= density:
			take.append(i)
	used = PackedInt32Array(take)
	var fans: Array = md.fans.keys()
	var cum := PackedFloat32Array()
	var tot := 0.0
	for f in fans:
		tot += maxf(float(fan_weights.get(f, 1.0)), 0.0)
		cum.append(tot)
	var by_fan := {}
	for n in take.size():
		var i: int = take[n]
		var pick := rng.randi() % fans.size()
		if i < _anchor.size() and _anchor[i] and not _dangle[i]:
			# A venue's seat: a fan whose legs fit it (sized within FIT_MIN..FIT_MAX, the shins' reach to spare).
			var seat_h := _per_spot(seated, i)
			# (Only fans who fit, if any does: sized up past FIT_MAX, a short-legged fan's thighs went down through a
			# tall chair's front edge as they got up - Kho Kho's fan4 in 0.45 m chairs.)
			var cw := PackedFloat32Array()
			var ct := 0.0
			var any_fits := false
			for f in fans:
				var need := seat_h / seat_of(f).x
				any_fits = any_fits or (need >= FIT_MIN and need <= FIT_MAX * 1.03)
			for f in fans:
				var need := seat_h / seat_of(f).x
				var fits := need >= FIT_MIN and need <= FIT_MAX * 1.03
				ct += maxf(float(fan_weights.get(f, 1.0)), 0.0) * (1.0 if fits or not any_fits else 0.0)
				cw.append(ct)
			if ct > 0.0:
				pick = mini(cw.bsearch(rng.randf() * ct, false), fans.size() - 1)
		elif not fan_weights.is_empty() and tot > 0.0:
			pick = mini(cum.bsearch(rng.randf() * tot, false), fans.size() - 1)
		var f: String = fans[pick] + ("" if n < near_cap else "|far")
		if not by_fan.has(f):
			by_fan[f] = []
		by_fan[f].append(i)
	_ctx = {"spots": spots, "facings": facings, "seated": seated, "room": room, "shirts": shirts, "lights": lights, "rng": rng}
	var groups := []
	for key in by_fan:
		var list: Array = by_fan[key]
		var f: String = key.get_slice("|", 0)
		var far: bool = key.ends_with("|far")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true       # (COLOR in the shader is the vertex's times the instance's)
		mm.mesh = load(DIR + f + ("_crowd_far.res" if far else "_crowd.res"))
		mm.instance_count = list.size()
		groups.append({"f": f, "list": list, "mm": mm, "xfs": []})
	return groups


## Places fans K0..K1 of a group (in order: the draws are the same however it is cut).
func _place_group(g: Dictionary, k0: int, k1: int) -> void:
	var spots: Array = _ctx.spots
	var facings: Array = _ctx.facings
	var seated: Variant = _ctx.seated
	var room: Variant = _ctx.room
	var shirts: Array = _ctx.shirts
	var lights: Array = _ctx.lights
	var rng: RandomNumberGenerator = _ctx.rng
	var f: String = g.f
	var list: Array = g.list
	var mm: MultiMesh = g.mm
	var xfs: Array = g.xfs
	for k in range(k0, k1):
		var i: int = list[k]
		var fwd: Vector3 = facings[i] if i < facings.size() else Vector3.FORWARD
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		var h := rng.randf_range(0.93, 1.07)
		var seat_h := _per_spot(seated, i)
		var on_seat: bool = i < _anchor.size() and _anchor[i] and seat_h > 0.0
		if on_seat:
			# A venue's seat: sized to it (the soles on the floor, the seat of the trousers on the seat), within
			# what people are.
			h = clampf(seat_h / seat_of(f).x * rng.randf_range(0.98, 1.02), FIT_MIN, FIT_MAX)
		elif seat_h > 0.0:
			# Sizes drawn toward ones that fit the seat: short legs dangle less, long ones sit lower.
			h = lerpf(h, clampf(seat_h / seat_of(f).x, 0.93, 1.07), 0.6)
		var pl := place(spots[i], fwd, h, f, seat_h, _per_spot(room, i), on_seat, _per_spot(_back, i) if on_seat else INF,
			float(_half[i]) if on_seat else 0.0, float(_front[i]) if on_seat else INF,
			_seat_dir[i] if on_seat and i < _seat_dir.size() else Vector3.ZERO)
		mm.set_instance_transform(k, pl[0])
		xfs.append(pl)
		# (g: the seat's light, its sign whether seated; a: the shirt's code. Small numbers: the Compatibility
		# renderer keeps custom data in half floats.)
		var code := shirt_palette_code(shirts[i]) if i < shirts.size() and shirts[i] is Color else 0.0
		var li := clampf(float(lights[i]) if i < lights.size() else 1.0, 0.05, 2.0)
		# (r: the fan's own random number, plus 2 where their legs hang.)
		var hang: bool = i < _dangle.size() and _dangle[i]
		mm.set_instance_custom_data(k, Color(rng.randf() + (2.0 if hang else 0.0), li if seat_h > 0.0 else -li, pl[1], code))
		var tone := rng.randf_range(0.85, 1.1)
		mm.set_instance_color(k, Color(tone, tone * rng.randf_range(0.95, 1.03), tone * rng.randf_range(0.93, 1.05), 1.0))


## A placed group into the scene.
func _add_group(g: Dictionary) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = g.mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _material(g.f)
	mi.material_override = mat
	add_child(mi)
	meshes.append(mi)
	materials.append(mat)
	spot_of.append(PackedInt32Array(g.list))
	placed_xf.append(g.xfs)


## What the crowd's data must have been baked with (crowd.json "version"; tools/bake_crowd.gd): 3 = every frame
## grounded at its soles, the parts, hand vertices. A crowd baked before (a game's old local licensed bake) has its
## seated soles up to 7 cm under the floor: WsgCrowdVenue.audit refuses it - run tools/wsg/fetch_assets.sh with
## FORCE=1 to bake it again.
const BAKE_VERSION := 3


## A fan's size fitted to a venue's seat at most this far from the model's own.
const FIT_MIN := 0.86
const FIT_MAX := 1.14
## A seated fan whose seat is higher than their legs reach (their own units) is lifted onto it and their shins
## stretched down to the floor by as much, up to this (crowd_vat.gdshader; not where the legs hang).
const REACH := 0.08


## The crowd of a venue (WsgCrowdVenue): its places, each seated fan fitted to their seat (hips on it, soles on the
## floor in front, off the seat's back and the step behind), each facing the play. The rest as build(). Returns the
## spots drawn in 3D (indices into placed.spots: the billboards, or WsgCrowdCards, take the rest).
func build_venue(venue: WsgCrowdVenue, quality := 1, focus := Vector3.ZERO, density := 1.0, seed := 0, shirts: Array = [],
		lights: Array = []) -> PackedInt32Array:
	_venue_begin(venue, seed)
	var got := build(placed.spots, placed.facings, density, seed, Array(placed.seat), quality, focus, INF, shirts, lights)
	_venue_end()
	return got


## build_venue() behind a loading overlay: the same crowd, with checkpoints (build_async). `await` it.
func build_venue_async(venue: WsgCrowdVenue, quality := 1, focus := Vector3.ZERO, density := 1.0, seed := 0,
		shirts: Array = [], lights: Array = [], ld: WsgLoading = null) -> PackedInt32Array:
	_venue_begin(venue, seed)
	if ld == null:
		ld = WsgLoading.current()
	if ld:
		await ld.checkpoint()
	var got := await build_async(placed.spots, placed.facings, density, seed, Array(placed.seat), quality, focus, INF,
		shirts, lights, ld)
	_venue_end()
	return got


func _venue_begin(venue: WsgCrowdVenue, seed: int) -> void:
	placed = venue.place(seed)
	_anchor = placed.anchor_seat
	_back = Array(placed.back)
	_dangle = placed.dangle
	_half = Array(placed.half_depth)
	_front = Array(placed.front)
	_seat_dir = placed.get("seat_dir", PackedVector3Array())


func _venue_end() -> void:
	_seat_dir = PackedVector3Array()
	_anchor = []
	_back = INF
	_dangle = []
	_half = []
	_front = []
	# Getting up, a seated fan steps forward off their seat: each fan model as far as the most any of them needs
	# (place(): their standing legs clear of the seat's front edge).
	stand_fwd.clear()
	for mi in meshes.size():
		var fan := String(meshes[mi].multimesh.mesh.resource_path.get_file()).get_slice("_crowd", 0)
		var fwd := 0.0
		for pl in placed_xf[mi]:
			fwd = maxf(fwd, float(pl[2]) if pl.size() > 2 else 0.0)
		stand_fwd[fan] = fwd
		materials[mi].set_shader_parameter("stand_fwd", fwd)


## For each fan model of a venue's crowd: how far forward (their own units) they step as they get up.
var stand_fwd := {}


## Where a standing fan's legs begin (their own units, z: the furthest back of anything lower than their seat over the
## standing motions; ahead of their origin is positive).
static func stand_rear(fan: String) -> float:
	if not _stand_rears.has(fan):
		var md := meta()
		var img := (load(DIR + fan + "_pos.res") as Texture2D).get_image()
		var st := seat_of(fan)
		var rear := INF
		for c in ["stand_idle", "stand_clap", "cheer"]:
			for f in int(md.clips[c].frames):
				for v in int(md.fans[fan].vertices):
					var px := img.get_pixel(v, int(md.clips[c].row) + f)
					if px.g < st.x:
						rear = minf(rear, px.b)
		_stand_rears[fan] = rear
	return _stand_rears[fan]


## How far ahead of their origin a fan's toes go (their own units), seated or standing.
static func toe_of(fan: String, seated: bool) -> float:
	var key := fan + ("|sit" if seated else "|stand")
	if not _toes.has(key):
		var md := meta()
		var img := (load(DIR + fan + "_pos.res") as Texture2D).get_image()
		var toe := -INF
		for c in (["sit_idle", "sit_clap"] if seated else ["stand_idle", "stand_clap", "cheer"]):
			for f in int(md.clips[c].frames):
				for v in int(md.fans[fan].vertices):
					var px := img.get_pixel(v, int(md.clips[c].row) + f)
					if px.g < 0.15:
						toe = maxf(toe, px.b)
		_toes[key] = toe
	return _toes[key]


static var _stand_rears := {}
static var _toes := {}


## A fan at a spot (their feet, world) facing fwd, h their size: [their transform, how far (their own units) the
## seated body is lifted]. seat_h: the seat's height over the feet (0: standing); room: how far behind the feet the
## step behind rises above the seat. Lifted so the seat of their trousers is on the seat (never sunk into it), and
## brought forward if they would sit back into the step.
static func place(spot: Vector3, fwd: Vector3, h: float, fan: String, seat_h: float, room := INF, on_seat := false,
		back := INF, half_depth := 0.0, front := INF, seat_dir := Vector3.ZERO) -> Array:
	var b := Basis.looking_at(-fwd, Vector3.UP)   # +Z toward fwd
	if on_seat:
		# spot: the floor under the middle of the seat (half_depth deep, its middle front m from the front edge of the
		# floor the feet are on). The seat of the trousers as far back on it as the back (the body's furthest back,
		# seated) keeps off what rises behind - people sit back, and their feet then have the room in front - but on
		# the seat, and the toes on the floor.
		var st := seat_of(fan)
		var x := maxf(-back + 0.02 - (rear_of(fan) - st.y) * h, -half_depth + 0.06)
		# Far enough forward that what goes down past the seat (the backs of the knees, the calves) is in front of its
		# edge, measured square to the seat (SEAT_DIR: its front): a fan turned toward the play at the end of a long
		# strip seat has their knees out along it (Kabaddi's fan5 at the end of the dome's step, turned, the tops of
		# its calves 2.5 cm into the step).
		var legs := legs_down_of(fan)
		if not legs.is_empty():
			var n := seat_dir if seat_dir != Vector3.ZERO else fwd
			var c := clampf(fwd.dot(n), 0.35, 1.0)
			var sx := Vector3.UP.cross(fwd).dot(n)     # the fan's own x (their left) along the seat's front
			var least := INF
			for q in legs:
				least = minf(least, q.x * sx + q.y * c)
			x = maxf(x, (half_depth + 0.01 - h * least) / c + st.y * h)
		x = minf(x, minf(half_depth - 0.08, front - 0.02 - (toe_of(fan, true) - st.y) * h))
		var at := spot + fwd * (x - st.y * h)
		# Getting up: the standing legs (their furthest back, stand_rear) clear of the seat's front edge.
		var step := maxf(0.0, (half_depth + 0.02 - (x - st.y * h)) / h - stand_rear(fan))
		return [Transform3D(b.scaled(Vector3.ONE * h), at), maxf(seat_h / h - st.x, -0.02), step]
	var lift := 0.0
	var push := 0.0
	if seat_h > 0.0:
		var s := seat_of(fan)
		lift = maxf(seat_h / h - s.x, -0.02)
		push = maxf(0.0, (FEET_FORWARD - s.y) - (room / h - 0.02))
	return [Transform3D(b.scaled(Vector3.ONE * h), spot - fwd * (FEET_FORWARD - push) * h), lift]


static func _per_spot(v: Variant, i: int) -> float:
	var x: Variant = v[i] if v is Array or v is PackedFloat32Array else v
	if x is bool:
		return SEAT if x else 0.0
	return float(x)


## Where a fan sits, in their own space: x the seat's height over the soles (the lowest point of the seat of their
## trousers and their thighs, over the seated motions), y how far back that comes (z: behind the origin, negative).
## From crowd.json (tools/bake_crowd.gd writes it), else read off their motion texture.
static func seat_of(fan: String) -> Vector2:
	if not _seats.has(fan):
		var md := meta()
		var fm: Dictionary = md.fans.get(fan, {})
		if fm.has("seat"):
			_seats[fan] = Vector2(fm.seat[0], fm.seat[1])
		else:
			var img := (load(DIR + fan + "_pos.res") as Texture2D).get_image()
			_seats[fan] = measure_seat(img, int(fm.vertices), seated_rows(md))
	return _seats[fan]


## How far back a seated fan's body goes (their own units: z, negative behind their origin): the furthest back of
## anything above the seat over the seated motions (the back, the head, an elbow).
static func rear_of(fan: String) -> float:
	if not _rears.has(fan):
		var md := meta()
		var img := (load(DIR + fan + "_pos.res") as Texture2D).get_image()
		var st := seat_of(fan)
		var rear := 0.0
		for r in seated_rows(md):
			for v in int(md.fans[fan].vertices):
				var c := img.get_pixel(v, r)
				if c.g > st.x + 0.1:
					rear = minf(rear, c.b)
		_rears[fan] = rear
	return _rears[fan]


static var _rears := {}


## Where a seated fan's legs go down past the seat (their own units, x and z): the outline (convex hull) of
## everything (the hands aside) lower than the seat of their trousers and ahead of it, over the seated motions; empty
## if nothing is.
static func legs_down_of(fan: String) -> PackedVector2Array:
	if not _legs.has(fan):
		var md := meta()
		var img := (load(DIR + fan + "_pos.res") as Texture2D).get_image()
		var st := seat_of(fan)
		var hands := {}
		for hv in md.fans[fan].get("hand_vertices", []):
			hands[int(hv)] = true
		var pts := PackedVector2Array()
		for r in seated_rows(md):
			for v in int(md.fans[fan].vertices):
				if hands.has(v):
					continue
				var c := img.get_pixel(v, r)
				if c.g < st.x - 0.015 and c.b > st.y + 0.05:
					pts.append(Vector2(c.r, c.b))
		_legs[fan] = Geometry2D.convex_hull(pts) if pts.size() > 2 else pts
	return _legs[fan]


static var _legs := {}


## The motion texture's rows a fan is seated in: sitting, clapping seated, and the first of getting up.
## The seat of a fan's trousers and thighs: one byte a vertex (from crowd.json; empty for data baked before it).
static func seat_mask(fan: String) -> PackedByteArray:
	var fm: Dictionary = meta().fans[fan]
	var mask := PackedByteArray()
	if fm.has("seat_vertices"):
		mask.resize(int(fm.vertices))
		for v in fm.seat_vertices:
			mask[int(v)] = 1
	return mask


static func seated_rows(md: Dictionary) -> Array:
	var rows := []
	for c in ["sit_idle", "sit_clap"]:
		for f in int(md.clips[c].frames):
			rows.append(int(md.clips[c].row) + f)
	rows.append(int(md.clips.sit_to_stand.row))
	return rows


## seat_of from a motion texture (positions, a column a vertex). seat: one byte a vertex, 1 where it is the seat of the
## trousers or a thigh (the bake knows from the weights); without it, anything within the hips' width, behind the
## shins and higher than a seat can be low (a foot tucked back under the seat is not what they sit on).
static func measure_seat(pos: Image, vertices: int, rows: Array, seat_mask := PackedByteArray()) -> Vector2:
	var seat := INF
	var pts := []
	for r in rows:
		for v in vertices:
			var c := pos.get_pixel(v, r)
			var p := Vector3(c.r, c.g, c.b)
			var on := seat_mask[v] == 1 if not seat_mask.is_empty() else absf(p.x) < 0.2 and p.y > 0.22
			if on and p.z < FEET_FORWARD - 0.1 and p.y < 0.8:
				seat = minf(seat, p.y)
				pts.append(p)
	var back := 0.0
	for p in pts:
		if p.y < seat + 0.18:
			back = minf(back, p.z)
	return Vector2(seat, back)


func _material(fan: String) -> ShaderMaterial:
	var md := meta()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/wsg_foundation/crowd_vat.gdshader")
	mat.set_shader_parameter("vat_pos", load(DIR + fan + "_pos.res"))
	mat.set_shader_parameter("vat_nrm", load(DIR + fan + "_nrm.res"))
	mat.set_shader_parameter("vertices", int(md.fans[fan].vertices))
	mat.set_shader_parameter("fps", float(md.fps))
	mat.set_shader_parameter("knee", seat_of(fan).x * 0.9)
	mat.set_shader_parameter("reach", REACH)
	# (This fan's own skin, hair and trousers: what set_looks shades from. Older data has none: no part is marked.)
	var lk: Dictionary = md.fans[fan].get("looks", {})
	for part in lk:
		var c: Array = lk[part]
		mat.set_shader_parameter("ref_" + part, Vector3(c[0], c[1], c[2]))
	_apply_looks(mat)
	for c in md.clips:
		var ci: Dictionary = md.clips[c]
		mat.set_shader_parameter("clip_" + c, Vector4(ci.row, ci.frames, ci.length, 1.0 if ci.loop else 0.0))
	return mat


## Each fan's skin, hair and the legs' clothes (trousers, a skirt, shorts) their own, picked from these (Colors,
## sRGB, each list dark to light, up to 8; WsgCrowd3D.LOOKS has broad ones): the six shared fans become many people.
## An empty list keeps that part as the fan was made (and none called: the crowd exactly as before). Before or after
## build(). Shading is kept (the new colour lighter and darker where the fan's own was); a darker skin goes mostly
## with the darker half of the hair.
func set_looks(skin: Array = [], hair: Array = [], legs: Array = []) -> void:
	_looks = {"skin": skin, "hair": hair, "legs": legs}
	for m in materials:
		_apply_looks(m)


func _apply_looks(mat: ShaderMaterial) -> void:
	for part in ["skin", "hair", "legs"]:
		var list: Array = _looks.get(part, [])
		var arr := PackedVector3Array()
		for c in list.slice(0, 8):
			arr.append(Vector3((c as Color).r, (c as Color).g, (c as Color).b))
		while arr.size() < 8:
			arr.append(Vector3.ZERO)
		mat.set_shader_parameter(part + "s" if part != "legs" else "legs", arr)
		mat.set_shader_parameter("n_" + part + ("s" if part != "legs" else ""), mini(list.size(), 8))


func set_teams(a: Color, b: Color) -> void:
	for m in materials:
		m.set_shader_parameter("team_a", a)
		m.set_shader_parameter("team_b", b)


## The ground's light on them (1 by day; lower at dusk or under lights), for every crowd.
static func set_light(k: float) -> void:
	_light = k


## Where the light comes from (world, toward the sun: the game's), for every crowd: the fans are lit as the games
## light their people (a cel light, the side away from it shade of the side toward it).
static func set_sun(to_sun: Vector3, shade := 0.72) -> void:
	_sun = to_sun.normalized()
	_shade = shade


static var _sun := Vector3(0.35, 0.85, 0.4).normalized()
static var _shade := 0.72


## A shirt colour as the one number the 3D fans' shader reads (build() uses it for the shirts it is given): 1 plus the
## nearest of SHIRTS, 256 colours that reach white, the pale neutrals and plain colours (a half float keeps it exact).
## (shirt_code below, below 1, is the old hash the games' cut-out shaders decode; it could not make white or pale
## shirts - white came out mint - Kho Kho, Pok Ta Pok.)
static func shirt_palette_code(col: Color) -> float:
	var best := 0
	var bd := 9.0
	for i in 256:
		var c := shirt_palette(i)
		var d := Vector3(c.r - col.r, c.g - col.g, c.b - col.b).length()
		if d < bd:
			bd = d
			best = i
	return 1.0 + (float(best) + 0.5) / 256.0


## The 256 shirts: 16 greys black to white, then 20 hues (18 degrees apart) x 3 saturations x 4 values
## (crowd_vat.gdshader decodes the same).
static func shirt_palette(i: int) -> Color:
	if i < 16:
		var g := float(i) / 15.0
		return Color(g, g, g)
	var k := i - 16
	return Color.from_hsv(float(k % 20) / 20.0, [0.3, 0.6, 0.95][(k / 20) % 3], [0.35, 0.55, 0.75, 0.95][k / 60])


## A shirt colour as the one number the games' cut-outs decode (Hurling's Crowd._code: fract(code * vec3(7.13, 3.77,
## 5.31))), the nearest of the 256 that hash makes.
static func shirt_code(col: Color) -> float:
	var best := 0.0
	var bd := 9.0
	for i in 256:
		var y := float(i) / 256.0 + 0.001
		var c := Vector3(fposmod(y * 7.13, 1.0), fposmod(y * 3.77, 1.0), fposmod(y * 5.31, 1.0))
		var d := c.distance_to(Vector3(col.r, col.g, col.b))
		if d < bd:
			bd = d
			best = y
	return best


## What they watch (world); eased so heads do not snap.
func watch_ball(p: Vector3) -> void:
	_ball = p if not _ball_set else _ball
	_ball_lag = p if not _ball_set else _ball_lag
	_ball_set = true
	_target_ball = p


var _target_ball := Vector3.ZERO
var _ball_lag := Vector3.ZERO


## The rhythmic clapping is playing: claps a second, how much in unison (0..1), for how long.
func clap(rate: float, sync: float, seconds: float) -> void:
	_clap_rate = rate
	_clap_sync = sync
	_clap_left = seconds
	_clap_time = 0.0


func _process(delta: float) -> void:
	if materials.is_empty():
		return
	var target := maxf(_excite_target, _tension * 0.55)
	# Up quickly (a score lifts them in about half a second), down slowly (they settle over a few seconds).
	var rate := 5.0 if target > excite else 0.7
	excite = lerpf(excite, target, 1.0 - exp(-delta * rate))
	_ball = _ball.lerp(_target_ball, 1.0 - exp(-delta * 3.0))
	_ball_lag = _ball_lag.lerp(_ball, 1.0 - exp(-delta * 1.2))
	_clap_time += delta
	var clapping := 0.0
	if _clap_left > 0.0:
		_clap_left -= delta
		clapping = 0.35
	for m in materials:
		m.set_shader_parameter("excite", maxf(excite, clapping))
		m.set_shader_parameter("ball", _ball)
		m.set_shader_parameter("ball_lag", _ball_lag)
		m.set_shader_parameter("clap_time", _clap_time)
		m.set_shader_parameter("clap_rate", _clap_rate)
		m.set_shader_parameter("clap_sync", _clap_sync)
		m.set_shader_parameter("light", _light)
		m.set_shader_parameter("sun_dir", _sun)
		m.set_shader_parameter("shade", _shade)
