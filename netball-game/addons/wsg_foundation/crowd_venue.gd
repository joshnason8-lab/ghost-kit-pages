class_name WsgCrowdVenue
extends RefCounted
## A venue's spectators as data, for every game: where the play is, and its sections - strips of rows of seats
## (benches, chairs, plastic seats, bleachers, stone steps, wall tops, stools) or of standing room (terraces, a floor,
## a rail). place() turns them into the crowd's spots: each fan's place, the way they face, the seat they sit on
## and what is around them; WsgCrowd3D.build_venue (Medium, High) and WsgCrowdCards (Low) draw them, and audit()
## measures them (tools/crowd_audit.gd): hips on the seat, soles on the floor, nothing inside a seat back, a row or a
## rail, everyone facing the play.
##
##   var v := WsgCrowdVenue.new(Vector3.ZERO, Vector2(30.5, 15.25))          # the court: centre, size (x along, z across)
##   v.add({"name": "main", "a": Vector3(-15, 0, 9), "b": Vector3(15, 0, 9), "rows": 8, "tread": 0.8, "rise": 0.4,
##       "seat": "plastic"})
##   v.add({"name": "end", "a": Vector3(17, 0, -6), "b": Vector3(17, 0, 6), "rows": 4, "tread": 0.5, "rise": 0.25,
##       "seat": "terrace", "barrier": {"height": 1.0, "gap": 0.35}})
##   crowd3d.build_venue(v, quality, focus)
##
## A section: its front edge a to b (the first row's floor, world), rows deep away from the play, each row tread deep
## and rise higher than the one in front. seat: a kind below (its height, depth, back and setback can be given), or
## a standing kind. pitch: one place every pitch m along the row. barrier: a rail or boards in front of the first row
## ({"height", "gap": from the barrier to the first row's front}). stand: the share of a seated section's fans on their
## feet (in front of their seats). facing: the way the section looks (a Vector3; default: square to the strip, toward
## the play, each fan turned toward the play's nearest part, at most MAX_TURN off square).

## Seats: height over the floor the feet are on (m), depth, the back's height over the seat (0: none), and setback: from
## the row's front edge to the seat's front (m; default: the seat at the back of the tread).
const KINDS := {
	"bench": {"height": 0.42, "depth": 0.35, "back": 0.0},
	"chair": {"height": 0.45, "depth": 0.42, "back": 0.42},
	"plastic": {"height": 0.43, "depth": 0.38, "back": 0.32},
	"bleacher": {"height": 0.42, "depth": 0.28, "back": 0.0},
	# (High seats: the legs hang - no reaching for the floor.)
	"stool": {"height": 0.62, "depth": 0.3, "back": 0.0, "dangle": true},
	"wall": {"height": 0.55, "depth": 0.3, "back": 0.0, "dangle": true},
	# Sitting on the step behind (stone steps, a kerb): the seat is the next row's front.
	"step": {"height": -1.0, "depth": 0.3, "back": 0.0},
	"terrace": {"standing": true},
	"floor": {"standing": true},
	"rail": {"standing": true},
}
## A fan turned toward the play at most this far off square to their row (radians).
const MAX_TURN := deg_to_rad(50.0)
## Standing: feet this far from a barrier, a riser or another fan's (m), and jittered this much.
const STAND_GAP := 0.3
const STAND_JITTER := 0.06

var play_centre := Vector3.ZERO
var play_size := Vector2(30, 15)        # x along the play's own x, y across (its z)
var play_yaw := 0.0                     # the play area's turn about up (radians)
var sections: Array = []


func _init(centre := Vector3.ZERO, size := Vector2(30, 15), yaw := 0.0) -> void:
	play_centre = centre
	play_size = size
	play_yaw = yaw


## Adds a section (see above); returns it with its defaults filled in.
func add(s: Dictionary) -> Dictionary:
	var d := s.duplicate(true)
	d.name = String(d.get("name", "section %d" % sections.size()))
	d.rows = int(d.get("rows", 1))
	d.tread = float(d.get("tread", 0.8))
	d.rise = float(d.get("rise", 0.0))
	d.seat = String(d.get("seat", "bench"))
	assert(KINDS.has(d.seat), "WsgCrowdVenue: no seat kind " + d.seat)
	var k: Dictionary = KINDS[d.seat]
	d.standing = bool(k.get("standing", false))
	if not d.standing:
		d.height = float(d.get("height", k.height if k.height >= 0.0 else d.rise))
		d.depth = float(d.get("depth", k.depth))
		d.back = float(d.get("back", k.back))
		d.setback = float(d.get("setback", d.tread if d.seat == "step" else d.tread - d.depth))
		d.dangle = bool(d.get("dangle", k.get("dangle", false)))
	d.pitch = float(d.get("pitch", 0.5 if not d.standing else 0.55))
	d.stand = float(d.get("stand", 0.0))
	sections.append(d)
	return d


## The nearest point of the play area to p (world, at p's height), the area drawn in by inset m.
func nearest_play(p: Vector3, inset := 0.0) -> Vector3:
	var b := Basis(Vector3.UP, play_yaw)
	var q := b.inverse() * (p - play_centre)
	var hx := maxf(play_size.x * 0.5 - inset, 0.0)
	var hz := maxf(play_size.y * 0.5 - inset, 0.0)
	var c := play_centre + b * Vector3(clampf(q.x, -hx, hx), 0.0, clampf(q.z, -hz, hz))
	return Vector3(c.x, p.y, c.z)


## A section's frame: [along (unit, a to b), away (unit, flat: from the play), length].
func frame(s: Dictionary) -> Array:
	var a: Vector3 = s.a
	var b: Vector3 = s.b
	var along := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := along.length()
	along = along / maxf(length, 0.001)
	var away := Vector3(-along.z, 0, along.x)
	var mid := (a + b) * 0.5
	if away.dot(Vector3(mid.x - play_centre.x, 0, mid.z - play_centre.z)) < 0.0:
		away = -away
	return [along, away, length]


## The way a fan at p in section s faces: toward the play's nearest part (drawn in a third), at most MAX_TURN off
## square to the row; or the section's own facing.
func facing_at(s: Dictionary, p: Vector3) -> Vector3:
	var fr := frame(s)
	var square: Vector3 = -fr[1]
	if s.has("facing"):
		var f: Vector3 = s.facing
		return Vector3(f.x, 0, f.z).normalized()
	var to := nearest_play(p, minf(play_size.x, play_size.y) / 3.0) - p
	to.y = 0.0
	if to.length() < 0.01:
		return square
	var ang := square.signed_angle_to(to.normalized(), Vector3.UP)
	return square.rotated(Vector3.UP, clampf(ang, -MAX_TURN, MAX_TURN))


## Every place in the venue: {"spots": anchors (a seated fan's: the floor under the middle of their seat; a standing
## fan's: their feet), "facings", "seat": the seat's height over that floor (0 standing), "anchor_seat": true where the
## spot is a seat's, "back": how far behind a seated spot its seat back or the step behind rises (INF: nothing),
## "section": its section's index, "floor": the floor's height under the feet, "dangle": true where the legs hang (a
## stool, a wall top), "half_depth": a seat's half depth, "front": from the middle of a seat to the front edge of the
## floor the feet are on (m), "obstacles": boxes [{"xf": Transform3D
## (the box's centre and axes), "size": Vector3, "what": String, "section": int}]}.
func place(seed := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := {"spots": [], "facings": [], "seat": PackedFloat32Array(), "anchor_seat": [], "back": PackedFloat32Array(),
		"section": PackedInt32Array(), "floor": PackedFloat32Array(), "dangle": [], "half_depth": PackedFloat32Array(),
		"front": PackedFloat32Array(), "seat_dir": PackedVector3Array(), "obstacles": []}
	for si in sections.size():
		var s: Dictionary = sections[si]
		var fr := frame(s)
		var along: Vector3 = fr[0]
		var away: Vector3 = fr[1]
		var length: float = fr[2]
		var a: Vector3 = s.a
		var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP)).orthonormalized()
		if basis.z.dot(away) < 0.0:
			basis = Basis(-along, Vector3.UP, away)
		if s.has("barrier"):
			var bar: Dictionary = s.barrier
			var gap := float(bar.get("gap", 0.35))
			var hh := float(bar.get("height", 1.0))
			_box(out, si, a + (s.b - a) * 0.5 - away * gap + Vector3.UP * hh * 0.5, basis, Vector3(length, hh, 0.06), "barrier")
		var n := maxi(1, int(floor(length / s.pitch)))
		for r in s.rows:
			var row0: Vector3 = a + away * (r * s.tread) + Vector3.UP * (r * s.rise)
			# The step behind: its riser at the back of this tread, as high as the rise.
			if s.rise > 0.0 and r < s.rows - 1:
				_box(out, si, row0 + (s.b - a) * 0.5 + away * s.tread + Vector3.UP * s.rise * 0.5, basis,
					Vector3(length, s.rise, 0.04), "step")
			if not s.standing:
				var seat_front: float = s.setback
				var seat_top: float = row0.y + s.height
				# The seat (for "step": the next row's tread), and its back.
				_box(out, si, row0 + (s.b - a) * 0.5 + away * (seat_front + s.depth * 0.5) + Vector3.UP * (s.height - 0.03),
					basis, Vector3(length, 0.06, s.depth), "seat")
				if s.back > 0.0:
					_box(out, si, row0 + (s.b - a) * 0.5 + away * (seat_front + s.depth + 0.02) + Vector3.UP * (s.height + s.back * 0.5),
						basis, Vector3(length, s.back, 0.04), "seat back")
				# How far behind the middle of the seat something rises past it: its back, else the riser of the row
				# behind (sitting on a step: the riser after the one sat on).
				var back := INF
				var riser_at: float = s.tread * (2.0 if s.seat == "step" else 1.0)
				var risers_left: int = s.rows - 1 - r - (1 if s.seat == "step" else 0)
				if s.back > 0.0:
					back = s.depth * 0.5
				elif s.rise > 0.0 and risers_left > 0:
					back = riser_at - seat_front - s.depth * 0.5
				# How far the toes may reach in front of the middle of the seat: to the step's edge (rows that rise: the
				# feet stay on the tread), else on a flat floor to the seat (its back) of the row in front, or the barrier
				# in front of the first row; nothing in front: no limit. (Kabaddi's chairs on flat ground had the toes
				# held on a tread that has no edge, pushing fans forward on their seats.)
				var toe_room: float = seat_front + s.depth * 0.5
				if s.rise <= 0.0:
					if r > 0:
						toe_room = s.tread - s.depth * 0.5 - (0.04 if s.back > 0.0 else 0.0)
					elif s.has("barrier"):
						toe_room = seat_front + s.depth * 0.5 + float(s.barrier.get("gap", 0.35)) - 0.05
					else:
						toe_room = INF
				for i in n:
					var x: float = (i + 0.5) * length / n
					var mid: Vector3 = row0 + along * x + away * (seat_front + s.depth * 0.5)
					var up: bool = rng.randf() < s.stand
					if up:
						# On their feet in front of their seat.
						var feet: Vector3 = row0 + along * x + away * maxf(seat_front - 0.12, 0.15)
						_spot(out, si, feet, facing_at(s, feet), 0.0, false, INF, row0.y)
					else:
						_spot(out, si, Vector3(mid.x, row0.y, mid.z), facing_at(s, mid), seat_top - row0.y, true, back, row0.y,
							s.depth * 0.5, toe_room, -away)
			else:
				# One line of fans a tread, or more on a deep one (a floor): STAND_GAP from the front, 0.6 m apart,
				# none nearer the back than a body's depth.
				var offs := []
				var o := STAND_GAP
				while o <= s.tread - 0.25:
					offs.append(o)
					o += 0.6
				if offs.is_empty():
					offs.append(s.tread * 0.5)
				for off in offs:
					for i in n:
						var x: float = (i + 0.5 + rng.randf_range(-1.0, 1.0) * STAND_JITTER / s.pitch) * length / n
						var feet: Vector3 = row0 + along * x + away * (off + rng.randf_range(-1.0, 1.0) * STAND_JITTER * 0.5)
						var f: Vector3 = facing_at(s, feet).rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
						_spot(out, si, feet, f, 0.0, false, INF, row0.y)
	return out


func _spot(out: Dictionary, si: int, p: Vector3, f: Vector3, seat: float, anchor: bool, back: float, floor_y: float,
		half_depth := 0.0, front := INF, seat_dir := Vector3.ZERO) -> void:
	out.seat_dir.append(seat_dir)
	out.half_depth.append(half_depth)
	out.front.append(front)
	out.spots.append(p)
	out.facings.append(f)
	out.seat.append(seat)
	out.anchor_seat.append(anchor)
	out.back.append(back)
	out.section.append(si)
	out.floor.append(floor_y)
	out.dangle.append(anchor and bool(sections[si].get("dangle", false)))


func _box(out: Dictionary, si: int, centre: Vector3, basis: Basis, size: Vector3, what: String) -> void:
	out.obstacles.append({"xf": Transform3D(basis, centre), "size": size, "what": what, "section": si})


## What the audit allows (m, degrees).
const HIPS_TOL := [-0.02, 0.03]       # the seat of the trousers over the seat surface
const FEET_TOL := [-0.02, 0.04]       # the soles over the floor (seated: in every seated frame; standing: likewise)
const INSIDE_TOL := 0.025             # how deep into a seat, a seat back, a step or a barrier anything may go (a hand
                                      # on a seat is not counted: a fan pushes on it getting up - crowd.json's
                                      # hand_vertices)
const FACING_MAX := 35.0              # a fan's body off the play's nearest part (drawn in a third)

## Measures a crowd built by WsgCrowd3D.build_venue against its venue: the fans drawn in 3D (per_section of each
## section, spread along it; 0: every one), skinned as the crowd's shader draws them (the seated motions with their
## lift, and the standing ones: a seated fan gets up where they sit). Returns {"fans", "fails": [String], "worst":
## {measure: [value, where, how many]}, "sections": {name: {"fans", "hips": [min, max], "feet": [min, max], "inside":
## deepest, "facing": most off, "backwards": n}}}.
static func audit(crowd: WsgCrowd3D, venue: WsgCrowdVenue, per_section := 40) -> Dictionary:
	var pl: Dictionary = crowd.placed
	var md := WsgCrowd3D.meta()
	var out := {"fans": 0, "fails": [], "sections": {}, "worst": {}}
	if int(md.get("version", 0)) < WsgCrowd3D.BAKE_VERSION:
		out.fails.append("the crowd's data (%s) was baked before version %d (its frames not grounded: seated soles up to 7 cm under the floor): bake it again - FORCE=1 tools/wsg/fetch_assets.sh" % [WsgCrowd3D.DIR, WsgCrowd3D.BAKE_VERSION])
	for s in venue.sections:
		out.sections[s.name] = {"fans": 0, "hips": [INF, -INF], "feet": [INF, -INF], "inside": 0.0, "facing": 0.0, "backwards": 0}
	# The frames tried: the first and middle of sitting and of clapping seated; standing, clapping standing and cheering.
	var rows := {"sit": [], "stand": [], "rise": []}
	for c in ["sit_idle", "sit_clap"]:
		rows.sit.append_array([int(md.clips[c].row), int(md.clips[c].row) + int(md.clips[c].frames) / 2])
	for c in ["stand_idle", "stand_clap", "cheer"]:
		rows.stand.append_array([int(md.clips[c].row), int(md.clips[c].row) + int(md.clips[c].frames) / 2])
	# Getting up (the owner's "in the seat" was most often mid-way): a quarter, half and three quarters up, drawn as
	# the shader draws them - the lift and the shins' reach going, the step forward coming, as they rise.
	var st_c: Dictionary = md.clips.sit_to_stand
	var rise_up := [0.25, 0.5, 0.75]
	for u in rise_up:
		rows.rise.append(int(st_c.row) + int(round(u * (int(st_c.frames) - 1))))
	# Which fans: every drawn one, or per_section of each spread along it.
	var drawn := []           # [mesh index, instance]
	var by_sec := {}
	for mi in crowd.meshes.size():
		var list: PackedInt32Array = crowd.spot_of[mi]
		for k in list.size():
			var si: int = pl.section[list[k]]
			if not by_sec.has(si):
				by_sec[si] = []
			by_sec[si].append([mi, k])
	for si in by_sec:
		var all: Array = by_sec[si]
		all.sort_custom(func(x, y): return crowd.spot_of[x[0]][x[1]] < crowd.spot_of[y[0]][y[1]])
		if per_section <= 0 or all.size() <= per_section:
			drawn.append_array(all)
		else:
			for n in per_section:
				drawn.append(all[n * all.size() / per_section])
	var frames := {}          # fan -> {row: PackedVector3Array}
	for d in drawn:
		var mi: int = d[0]
		var k: int = d[1]
		var mm: MultiMesh = crowd.meshes[mi].multimesh
		var fan := String(mm.mesh.resource_path.get_file()).get_slice("_crowd", 0)
		if not frames.has(fan):
			frames[fan] = _frames(fan, rows.sit + rows.stand + rows.rise)
		var fr: Dictionary = frames[fan]
		var mask := WsgCrowd3D.seat_mask(fan)
		var hands := {}
		for hv in md.fans[fan].get("hand_vertices", []):
			hands[int(hv)] = true
		var i: int = crowd.spot_of[mi][k]
		var si: int = pl.section[i]
		var sec: Dictionary = out.sections[venue.sections[si].name]
		var where := "%s, place %d (%s)" % [venue.sections[si].name, i, fan]
		var xf: Transform3D = crowd.placed_xf[mi][k][0]
		var lift: float = crowd.placed_xf[mi][k][1]
		var seated: bool = pl.seat[i] > 0.0
		var dangle: bool = pl.dangle[i]
		var knee := WsgCrowd3D.seat_of(fan).x * 0.9
		var floor_y: float = pl.floor[i]
		var seat_y: float = floor_y + pl.seat[i]
		out.fans += 1
		sec.fans += 1
		# The obstacles near this fan, each taken into the fan's own frame once: [fan-local to box-local, half size,
		# what].
		var near := []
		for ob in pl.obstacles:
			var oxf: Transform3D = ob.xf
			var lp: Vector3 = oxf.affine_inverse() * xf.origin
			var sz: Vector3 = ob.size
			if absf(lp.x) < sz.x * 0.5 + 1.0 and absf(lp.z) < sz.z * 0.5 + 1.0 and lp.y > -sz.y * 0.5 - 2.2 and lp.y < sz.y * 0.5 + 0.3:
				near.append([oxf.affine_inverse() * xf, sz * 0.5, ob.what, oxf.origin])
		var deepest := 0.0
		var deep_what := ""
		var fwd_up := float(crowd.stand_fwd.get(fan, 0.0)) if seated else 0.0
		for pose in (["sit", "rise", "stand"] if seated else ["stand"]):
			for ri in rows[pose].size():
				var r: int = rows[pose][ri]
				var pts: PackedVector3Array = fr[r]
				# How far up they are (0 seated, 1 standing), and so their lift, reach and step forward.
				var u: float = 0.0 if pose == "sit" else (1.0 if pose == "stand" else float(rise_up[ri]))
				var l := lift * (1.0 - smoothstep(0.5, 1.0, u))
				var rch := 0.0 if dangle else clampf(l, 0.0, WsgCrowd3D.REACH)
				var up := Vector3(0, l, fwd_up * smoothstep(0.0, 0.5, u))
				var lowest := INF
				var hips := INF
				for v in pts.size():
					var p: Vector3 = pts[v] + up
					if rch > 0.0:
						p.y -= rch * (1.0 - smoothstep(0.0, knee, pts[v].y))
					var wy := (xf * p).y
					lowest = minf(lowest, wy)
					if pose == "sit" and mask.size() > v and mask[v] == 1:
						hips = minf(hips, wy)
					for ob in near:
						if ob[2] == "seat" and hands.has(v):
							continue    # (a hand on a seat: pushing up from it, resting on it)
						var lp: Vector3 = (ob[0] as Transform3D) * p
						var h: Vector3 = ob[1]
						var dd := minf(minf(h.x - absf(lp.x), h.y - absf(lp.y)), h.z - absf(lp.z))
						if dd > deepest:
							deepest = dd
							deep_what = "%s (%s)" % [ob[2], pose]
							if OS.has_environment("AUDIT_DEBUG"):
								deep_what += " fan-local %s, obstacle-local %s, obstacle at %s, fan at %s" % [str(p), str(lp), str(ob[3]), str(xf.origin)]
				var fe := lowest - floor_y
				sec.feet = [minf(sec.feet[0], fe), maxf(sec.feet[1], fe)]
				if fe < FEET_TOL[0] or (fe > FEET_TOL[1] and not (dangle and pose != "stand")):
					_note(out, "feet", fe, where + " " + pose)
				if pose == "sit" and hips < INF:
					var he := hips - seat_y
					sec.hips = [minf(sec.hips[0], he), maxf(sec.hips[1], he)]
					if he < HIPS_TOL[0] or he > HIPS_TOL[1]:
						_note(out, "hips", he, where)
		sec.inside = maxf(sec.inside, deepest)
		if deepest > INSIDE_TOL:
			_note(out, "inside", deepest, where + " in a " + deep_what)
		var fwd := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
		var to := venue.nearest_play(xf.origin, minf(venue.play_size.x, venue.play_size.y) / 3.0) - xf.origin
		to.y = 0.0
		var off := rad_to_deg(fwd.angle_to(to.normalized())) if to.length() > 0.01 else 0.0
		sec.facing = maxf(sec.facing, off)
		if off > 90.0:
			sec.backwards += 1
		if off > FACING_MAX:
			_note(out, "facing", off, where)
	for key in out.worst:
		var w: Array = out.worst[key]
		out.fails.append("%s: %d fans out of bounds, worst %s at %s" % [key, w[2], ("%.0f degrees" % w[0]) if key == "facing" else ("%+.3f m" % w[0]), w[1]])
	return out


## A fan's vertices (their own units) in the motion texture's rows.
static func _frames(fan: String, rows: Array) -> Dictionary:
	var img := (load(WsgCrowd3D.DIR + fan + "_pos.res") as Texture2D).get_image()
	var nv := int(WsgCrowd3D.meta().fans[fan].vertices)
	var out := {}
	for r in rows:
		var pts := PackedVector3Array()
		pts.resize(nv)
		for v in nv:
			var c := img.get_pixel(v, r)
			pts[v] = Vector3(c.r, c.g, c.b)
		out[r] = pts
	return out


static func _note(out: Dictionary, key: String, value: float, where: String) -> void:
	if not out.worst.has(key):
		out.worst[key] = [value, where, 0, []]
	var w: Array = out.worst[key]
	w[2] += 1
	if absf(value) > absf(w[0]):
		w[0] = value
		w[1] = where
