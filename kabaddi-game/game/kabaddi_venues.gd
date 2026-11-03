class_name KabaddiVenues
extends RefCounted
## Every ground's spectators declared for the shared foundation's crowd placement (WsgCrowdVenue, ADOPTING 5.1): who
## sits where, on what, and who stands. The foundation places each fan from these (seated on their seat, not in it,
## feet on the floor, facing the play) and its crowd_audit checks them (game/crowd_venues.gd). Arena builds its crowd
## from venue(id).place() and puts its chair and stool props where these seats are.
##
## The play area is the mat with its lobbies: 12 m across (x) by 13 m long (z), centred, square to the world.

const PLAY := Vector2(2.0 * (Arena.HALF_W + Arena.LOBBY), 2.0 * Arena.HALF_L)
const TREAD := 0.9     # the stands' steps: as Arena._stand_boxes builds them
const RISE := 0.45
const PITCH := 0.55    # one fan every so many m along a row, seated or standing


static func venue(arena_id: String) -> WsgCrowdVenue:
	var v := WsgCrowdVenue.new(Vector3.ZERO, PLAY, 0.0)
	match arena_id:
		"dome":
			_tiers(v, 9.6, 11.2, 9, true)
		"stadium":
			_tiers(v, 13.0, 15.0, 12, false)
		"monsoon":
			# The stand on the west side only (the rest is open ground under the rain trees).
			v.add({"name": "west stand", "a": Vector3(-(10.5 - TREAD), 0, -10.5), "b": Vector3(-(10.5 - TREAD), 0, 10.5),
				"rows": 3, "tread": TREAD, "rise": RISE, "seat": "step", "pitch": PITCH})
			# Under the tarpaulin at the north end: three rows of plastic chairs facing the court.
			_chairs(v, "tarpaulin chairs", Vector3(-6.0, 0, -15.6), Vector3(2.0, 0, -15.6), Vector3(0, 0, -1), 3, 0.95, 0.72)
		"village":
			_chairs(v, "chairs", Vector3(-10.5, 0, -7.6), Vector3(-10.5, 0, 7.6), Vector3(-1, 0, 0), 2, 0.85, 0.7)
			for end in [-1.0, 1.0]:
				# Folding stools at each end: low, the soles on the ground.
				# (Their middles 11.55 m out, as the stools stood; room in front for the feet, as the chairs'.)
				v.add({"name": "stools %s" % ("north" if end < 0 else "south"), "a": Vector3(-3.85, 0, end * 11.0),
					"b": Vector3(3.85, 0, end * 11.0), "rows": 1, "tread": 0.8, "rise": 0.0, "seat": "stool",
					"height": 0.44, "dangle": false, "depth": 0.3, "setback": 0.4, "pitch": 1.1})
			_ring(v, 12.3, 2, func(p: Vector3) -> float:
				if p.x < -7.5 and absf(p.z) < 9.0:
					return -1.0  # the chairs' side: standing behind them in a line of its own
				if absf(p.z) > 10.0 and absf(p.x) < 4.6:
					return 1.6   # behind the stools
				return 0.0)
			_behind_chairs(v, -12.9, 9.2)
		"beach":
			_chairs(v, "chairs", Vector3(-10.4, 0, -6.2), Vector3(-10.4, 0, 8.2), Vector3(-1, 0, 0), 2, 0.85, 0.72)
			_ring(v, 11.0, 2, func(p: Vector3) -> float:
				if p.z < -8.0:
					return -1.0  # the sea's end: nobody
				if p.x < -7.5 and absf(p.z) < 9.0:
					return -1.0  # the chairs' side: standing behind them in a line of its own
				return 0.0)
			_behind_chairs(v, -12.8, 8.6, -6.6)
	return v


## Stepped stands on all four sides, sitting on the step behind (seat "step"), the first row's feet on the floor in
## front of the bottom step. The sides run between the ends; the ends' corners are left empty (rows would overlap).
## With a tunnel: each end's first two rows split either side of it, the rest above full width.
static func _tiers(v: WsgCrowdVenue, inner_x: float, inner_z: float, tiers: int, tunnel: bool) -> void:
	var fx := inner_x - TREAD
	var fz := inner_z - TREAD
	for s in [-1.0, 1.0]:
		var side := "west" if s < 0.0 else "east"
		v.add({"name": "%s stand" % side, "a": Vector3(s * fx, 0, -inner_z), "b": Vector3(s * fx, 0, inner_z),
			"rows": tiers, "tread": TREAD, "rise": RISE, "seat": "step", "pitch": PITCH})
	for s in [-1.0, 1.0]:
		var end := "north" if s < 0.0 else "south"
		if not tunnel:
			v.add({"name": "%s stand" % end, "a": Vector3(-inner_x, 0, s * fz), "b": Vector3(inner_x, 0, s * fz),
				"rows": tiers, "tread": TREAD, "rise": RISE, "seat": "step", "pitch": PITCH})
			continue
		for half in [-1.0, 1.0]:
			v.add({"name": "%s stand %s of the tunnel" % [end, "left" if half < 0.0 else "right"],
				"a": Vector3(half * 1.2, 0, s * fz), "b": Vector3(half * inner_x, 0, s * fz),
				"rows": 2, "tread": TREAD, "rise": RISE, "seat": "step", "pitch": PITCH})
		v.add({"name": "%s stand upper" % end, "a": Vector3(-inner_x, 2 * RISE, s * (fz + 2 * TREAD)),
			"b": Vector3(inner_x, 2 * RISE, s * (fz + 2 * TREAD)), "rows": tiers - 2, "tread": TREAD, "rise": RISE,
			"seat": "step", "pitch": PITCH})


## Rows of plastic chairs: first_a to first_b the line of the first row's seat middles (as the props stand), back
## the way away from the court; the section's front edge set so the seats land on those lines.
static func _chairs(v: WsgCrowdVenue, name: String, first_a: Vector3, first_b: Vector3, back: Vector3, rows: int,
		tread: float, pitch: float) -> void:
	var depth := 0.38
	# The seat at the back of its row's tread: the feet's room in front of it is the row's (with less, the foundation
	# keeps the toes on the tread by sitting the fan back into the seat).
	var setback := tread - depth - 0.03
	var front := -back * (setback + depth * 0.5)
	var along := (first_b - first_a).normalized()
	v.add({"name": name, "a": first_a + front - along * pitch * 0.5, "b": first_b + front + along * pitch * 0.5,
		"rows": rows, "tread": tread, "rise": 0.0, "seat": "plastic", "height": 0.44, "depth": depth, "back": 0.32,
		"setback": setback, "pitch": pitch})


## Standing on the ground behind the chairs on the west side, two deep, from z0 to z1 (default -z1), x the front.
static func _behind_chairs(v: WsgCrowdVenue, x: float, z1: float, z0 := INF) -> void:
	v.add({"name": "standing behind the chairs", "a": Vector3(x, 0, -z1 if z0 == INF else z0), "b": Vector3(x, 0, z1),
		"rows": 2, "tread": 0.75, "rise": 0.0, "seat": "floor", "pitch": PITCH})


## A ring of people standing on the ground round the court: an ellipse (x squashed to 0.9) in short straight
## sections, each pushed out by push(its middle) m (to stand behind the seats), or left out where it says < 0.
static func _ring(v: WsgCrowdVenue, r: float, rows: int, push: Callable, segments := 16) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var mid := Vector3(cos((a0 + a1) * 0.5) * r * 0.9, 0, sin((a0 + a1) * 0.5) * r)
		var extra: float = push.call(mid)
		if extra < 0.0:
			continue
		var p0 := Vector3(cos(a0) * (r + extra) * 0.9, 0, sin(a0) * (r + extra))
		var p1 := Vector3(cos(a1) * (r + extra) * 0.9, 0, sin(a1) * (r + extra))
		v.add({"name": "standing %d" % i, "a": p0, "b": p1, "rows": rows, "tread": 0.75, "rise": 0.0, "seat": "floor",
			"pitch": PITCH})
