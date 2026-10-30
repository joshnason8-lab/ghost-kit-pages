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


## Places the fans: spots are their feet (world), facings the way each faces (flat; toward the pitch). seated: true
## (all on seats SEAT high), false (a terrace: all standing), one bool a spot, or one number a spot (the seat's
## height over the feet, m; 0 standing): each seated fan is lifted so they sit on it, not in it. room: how far
## behind the feet the step behind rises above the seat (m; one number, or one a spot): a fan who would sit back into
## it comes forward. quality: 1 Medium, 2 High, 3 Close (WsgFoundation.crowd_budget; Low: do not build; keep the
## billboards). Returns the indices of the
## spots it drew, nearest the focus first; the game's billboards take the others.
func build(spots: Array, facings: Array, density := 1.0, seed := 0, seated: Variant = true, quality := 1, focus := Vector3.ZERO,
		room: Variant = INF) -> PackedInt32Array:
	for m in meshes:
		m.queue_free()
	meshes.clear()
	materials.clear()
	used = PackedInt32Array()
	var md := meta()
	if md.is_empty():
		return used
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
	var by_fan := {}
	for n in take.size():
		var i: int = take[n]
		var f: String = fans[rng.randi() % fans.size()] + ("" if n < near_cap else "|far")
		if not by_fan.has(f):
			by_fan[f] = []
		by_fan[f].append(i)
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
		for k in list.size():
			var i: int = list[k]
			var fwd: Vector3 = facings[i] if i < facings.size() else Vector3.FORWARD
			fwd = Vector3(fwd.x, 0, fwd.z).normalized()
			var h := rng.randf_range(0.93, 1.07)
			var seat_h := _per_spot(seated, i)
			if seat_h > 0.0:
				# Sizes drawn toward ones that fit the seat: short legs dangle less, long ones sit lower.
				h = lerpf(h, clampf(seat_h / seat_of(f).x, 0.93, 1.07), 0.6)
			var pl := place(spots[i], fwd, h, f, seat_h, _per_spot(room, i))
			mm.set_instance_transform(k, pl[0])
			mm.set_instance_custom_data(k, Color(rng.randf(), 1.0 if seat_h > 0.0 else 0.0, pl[1], 0))
			var tone := rng.randf_range(0.85, 1.1)
			mm.set_instance_color(k, Color(tone, tone * rng.randf_range(0.95, 1.03), tone * rng.randf_range(0.93, 1.05), 1.0))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := _material(f)
		mi.material_override = mat
		add_child(mi)
		meshes.append(mi)
		materials.append(mat)
	return used


## A fan at a spot (their feet, world) facing fwd, h their size: [their transform, how far (their own units) the
## seated body is lifted]. seat_h: the seat's height over the feet (0: standing); room: how far behind the feet the
## step behind rises above the seat. Lifted so the seat of their trousers is on the seat (never sunk into it), and
## brought forward if they would sit back into the step.
static func place(spot: Vector3, fwd: Vector3, h: float, fan: String, seat_h: float, room := INF) -> Array:
	var b := Basis.looking_at(-fwd, Vector3.UP)   # +Z toward fwd
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
	for c in md.clips:
		var ci: Dictionary = md.clips[c]
		mat.set_shader_parameter("clip_" + c, Vector4(ci.row, ci.frames, ci.length, 1.0 if ci.loop else 0.0))
	return mat


func set_teams(a: Color, b: Color) -> void:
	for m in materials:
		m.set_shader_parameter("team_a", a)
		m.set_shader_parameter("team_b", b)


## The ground's light on them (1 by day; lower at dusk or under lights), for every crowd.
static func set_light(k: float) -> void:
	_light = k


## What they watch (world); eased so heads do not snap.
func watch_ball(p: Vector3) -> void:
	_ball = p if not _ball_set else _ball
	_ball_set = true
	_target_ball = p


var _target_ball := Vector3.ZERO


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
	_clap_time += delta
	var clapping := 0.0
	if _clap_left > 0.0:
		_clap_left -= delta
		clapping = 0.35
	for m in materials:
		m.set_shader_parameter("excite", maxf(excite, clapping))
		m.set_shader_parameter("ball", _ball)
		m.set_shader_parameter("clap_time", _clap_time)
		m.set_shader_parameter("clap_rate", _clap_rate)
		m.set_shader_parameter("clap_sync", _clap_sync)
		m.set_shader_parameter("light", _light)
