class_name CrowdVenues
extends RefCounted
## Where each venue's spectators sit or stand, declared for the shared foundation's crowd placement (WsgCrowdVenue,
## ADOPTING 5.1): the arena's courtside sections, the sports hall's stand, the park court's standing crowd. The
## foundation places, sizes and turns the people from these (Crowd draws them: 3D people on Medium and High, cards on
## Low) and its audit measures them: tools/wsg/crowd_audit.gd with this file as the registry,
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT [quality]
## Every number here is the venue's own (Arena builds the stands from the same ones, or they were measured off its
## models, as noted).

## The arena's courtside sections on Medium and High: the owner's Meshy stand (bleacher_metal), each 7.48 m wide, five
## rows of folding seats 14 a row half a metre apart, set on a slope (20 degrees) that is the floor under the feet.
## Measured off the model (its front +Z, metres; tools: a side view and its up-facing faces): how far forward the toes
## may go (front: 8 cm past the stand's front edge, over the lower tier's wall), the floor under the middle of a foot
## (the slope's height there, less 1.5 cm: a fan long in the leg for so low a seat sits at most 2.3 cm over it), the
## seat's front edge and top, its depth, and the chair back's height over the seat. People sit in the first row only:
## the model's rows are 0.46 to 0.8 m apart, closer to the chair backs in front than knees need (the 2nd row's knees
## would be in the 1st row's chair backs, the 3rd's in the 2nd's, the 5th's in the 4th's; the 4th row's people could
## sit, 0.28 m over the slope, but getting up for a goal their feet went 16 cm into the 3rd row's chair backs).
const METAL_W := 7.48
const METAL_HALF_D := 2.07
const METAL_ROWS := [
	{"front": 2.15, "floor": 0.355, "seat_front": 1.73, "top": 0.72, "depth": 0.40, "back": 0.44},
]
## The empty rows' seats and backs are still there: the audit measures the people in front of them against these
## boxes ([z0, z1, y0, y1] in the model).
const METAL_EMPTY := [
	[0.72, 1.12, 1.03, 1.09, "seat"], [0.65, 0.72, 1.08, 1.51, "seat back"],
	[0.29, 0.64, 1.18, 1.28, "seat"], [0.04, 0.37, 1.25, 1.66, "seat back"],
	[-0.53, -0.17, 1.64, 1.72, "seat"], [-0.64, -0.51, 1.70, 2.09, "seat back"],
	[-1.04, -0.65, 1.92, 1.97, "seat"], [-1.12, -1.04, 1.95, 2.40, "seat back"],
]
## Low: the owner's lighter three-row aluminium stand (bleacher_hall, its _low), 8 m wide: three planks (top, front
## and back edge, in the model) - the first is the second's footboard, the second the seat, the third (behind, its
## people's feet would be where the second's sit) left empty.
const HALL_BLEACHER_W := 8.0
const HALL_BLEACHER_HALF_D := 1.2
const PLANKS := [[0.33, 1.20, 0.49], [0.76, 0.74, 0.12], [1.20, -0.07, -1.04]]


## A venue whose places are only a share of its seats (density: who came today; a section's "fill" scales it; all:
## every seat, for the audit), the same places for the same seed. Its extra obstacles (empty seats no one may sit in)
## are measured by the audit like the sections' own. place() also gives each place's "id" (its index among every
## place).
class Venue extends WsgCrowdVenue:
	var density := 1.0
	var all := false
	var extra_obstacles: Array = []
	## Who is in this crowd, as WsgCrowd3D.fan_weights (the netball crowd's own: mostly women), for this venue's seats.
	var fan_weights := {"fan2": 4.0, "fan5": 4.0}

	func place(seed := 0) -> Dictionary:
		var every := super.place(seed)
		var keep := PackedInt32Array()
		var rng := RandomNumberGenerator.new()
		for i in every.spots.size():
			var s: Dictionary = sections[every.section[i]]
			rng.seed = hash([seed, i])
			if not all and rng.randf() >= density * float(s.get("fill", 1.0)):
				continue
			keep.append(i)
		var out := {"id": keep}
		for k in every:
			if k == "obstacles":
				out[k] = every[k] + extra_obstacles
				continue
			var src = every[k]
			var dst = src.duplicate()
			dst.clear()
			for i in keep:
				dst.append(src[i])
			out[k] = dst
		return out

	## A box no one may be inside (an empty seat, its back): xf its centre and axes, size its full size.
	func obstacle(xf: Transform3D, size: Vector3, what: String) -> void:
		extra_obstacles.append({"xf": xf, "size": size, "what": what, "section": -1})


## The court every venue's people watch: its middle, its size (the play, without the run-off).
static func _venue() -> Venue:
	return Venue.new(Vector3.ZERO, Vector2(Court.HALF_L * 2.0, Court.HALF_W * 2.0))


## The way a block of fixed seats at mid, square to them (flat, toward the play), faces: toward the play's nearest part
## (as the foundation aims each fan), turned at most max_turn (radians) from square.
static func _facing(v: WsgCrowdVenue, mid: Vector3, square: Vector3, max_turn: float) -> Vector3:
	var to := v.nearest_play(mid, minf(v.play_size.x, v.play_size.y) / 3.0) - mid
	to.y = 0.0
	square = Vector3(square.x, 0, square.z).normalized()
	return square.rotated(Vector3.UP, clampf(square.signed_angle_to(to.normalized(), Vector3.UP), -max_turn, max_turn))


## Each side of the arena's courtside seating (0 the far side, 1 the +x end, 3 the -x end): [the stand's transform at
## the side's middle (its front +Z toward the court), how many sections of width w]. A stand half_d deep from its
## middle to its front, the fronts at the lower tier's foot (x0, z0: the bowl's front corners), at height y.
static func courtside_sides(w: float, half_d: float, x0: float, z0: float, y: float) -> Array:
	var out := []
	for side in [0, 1, 3]:
		var span := x0 * 2.0 if side == 0 else z0 * 2.0
		var n := int(floor(span / w))
		var yaw := 0.0 if side == 0 else (-PI * 0.5 if side == 1 else PI * 0.5)
		var back := half_d + 0.05
		var c := Vector3(0, y, -z0 - back) if side == 0 else Vector3((x0 + back) * (1.0 if side == 1 else -1.0), y, 0)
		out.append([Transform3D(Basis(Vector3.UP, yaw), c), n])
	return out


## The sections of one stand along a side: each section's transform (its front +Z).
static func courtside(w: float, half_d: float, x0: float, z0: float, y: float) -> Array:
	var out := []
	for sd: Array in courtside_sides(w, half_d, x0, z0, y):
		var xf: Transform3D = sd[0]
		var n: int = sd[1]
		for i in n:
			out.append(xf * Transform3D(Basis.IDENTITY, Vector3((i - (n - 1) * 0.5) * w, 0, 0)))
	return out


## The arena's courtside crowd (x0, z0: the bowl's front corners; y: the lower tier's front wall), a section a stand.
## Medium and High: the Meshy stands' front row, 14 chairs; Low: the light stand's middle plank, its feet on the front
## plank. Each stand's people face one way, as fixed seats do: toward the nearest part of the play from the stand's
## middle (the ends of a 37 m side are past the court's). The painted tiers behind stay painted.
static func arena(x0: float, z0: float, y: float, low: bool) -> Venue:
	var v := _venue()
	var w := HALL_BLEACHER_W if low else METAL_W
	var names := {0: "far side", 1: "east end", 3: "west end"}
	var sides := courtside_sides(w, HALL_BLEACHER_HALF_D if low else METAL_HALF_D, x0, z0, y)
	for k in sides.size():
		var side: Transform3D = sides[k][0]
		var n: int = sides[k][1]
		for i in n:
			var xf := side * Transform3D(Basis.IDENTITY, Vector3((i - (n - 1) * 0.5) * w, 0, 0))
			# (Turned at most 15 degrees on Low's plank, 25 in the chairs: a body turned further on a plank seat has its
			# shins in the plank beside it as it gets up.)
			var facing := _facing(v, xf.origin, xf.basis.z, 0.26 if low else 0.44)
			var name := "%s %d" % [names[[0, 1, 3][k]], i + 1]
			if low:
				var foot: Array = PLANKS[0]
				var seat: Array = PLANKS[1]
				var depth := 0.36
				v.add({"name": name, "a": xf * Vector3(-w * 0.5, foot[0], foot[1]), "b": xf * Vector3(w * 0.5, foot[0], foot[1]),
					"rows": 1, "tread": foot[1] - seat[1] + depth, "seat": "bleacher", "height": seat[0] - foot[0], "depth": depth,
					"back": 0.0, "setback": foot[1] - seat[1], "pitch": 0.499999, "facing": facing})
				# The back plank: empty.
				var bp: Array = PLANKS[2]
				v.obstacle(xf * Transform3D(Basis.IDENTITY, Vector3(0, bp[0] - 0.03, (bp[1] + bp[2]) * 0.5)),
					Vector3(w, 0.06, bp[1] - bp[2]), "seat")
				continue
			# The chairs: 14, from 0.49 m in from the stand's ends, half a metre apart.
			for row: Dictionary in METAL_ROWS:
				v.add({"name": name, "a": xf * Vector3(-3.5, row.floor, row.front), "b": xf * Vector3(3.5, row.floor, row.front),
					"rows": 1, "tread": row.front - row.seat_front + row.depth, "seat": "chair", "height": row.top - row.floor,
					"depth": row.depth, "back": row.back, "setback": row.front - row.seat_front, "pitch": 0.499999, "facing": facing})
			for e: Array in METAL_EMPTY:
				v.obstacle(xf * Transform3D(Basis.IDENTITY, Vector3(0, (e[2] + e[3]) * 0.5, (e[0] + e[1]) * 0.5)),
					Vector3(w, e[3] - e[2], e[1] - e[0]), e[4])
	return v


## The sports hall's stand down the near side (Arena._hall_stand: rows stepped up from z0, each depth deep and rise
## high, the first at front, tip-up seats every half metre from -ax with a stair every 8 m): people in the front three
## rows (a league crowd, out of the low camera's way), most in front; a section a block between two stairs, its people
## facing one way (as fixed seats do: toward the play from the block's middle, at most 17 degrees off square).
static func hall(z0: float, depth: float, rise: float, front: float, ax: float) -> Venue:
	var v := _venue()
	var n := int(ax * 2.0 / 0.5)
	var blocks := []
	for i in n:
		var x := -ax + (i + 0.5) * 0.5
		var stair := absf(fposmod(x, 8.0) - 4.0) < 0.6
		if stair:
			continue
		if blocks.is_empty() or float(blocks[-1][1]) < x - 0.3:
			blocks.append([x - 0.25, x + 0.25])
		else:
			blocks[-1][1] = x + 0.25
	for k in blocks.size():
		var a := Vector3(blocks[k][0], front, z0)
		var b := Vector3(blocks[k][1], front, z0)
		# The seat (Arena._hall_stand's boxes): 0.40 to 0.76 m back on the tread, its top 0.445 m up, the back's top 0.82.
		v.add({"name": "stand, block %d" % (k + 1), "a": a, "b": b, "rows": 3, "tread": depth, "rise": rise,
			"seat": "plastic",
			"height": 0.445, "depth": 0.36, "back": 0.375, "setback": 0.40, "pitch": 0.499999, "fill": 0.6,
			"facing": _facing(v, (a + b) * 0.5, Vector3(0, 0, -1), 0.3)})
	return v


## The park court's crowd, standing: along the open near side either side of the benches, behind the tall fence down
## the far side (on the path), and behind the low fence at each end, round the park bench there (fx, fz: the end and
## far fences; hl, hw: the run-off's edges).
static func outdoor(hl: float, hw: float, fx: float, fz: float) -> Venue:
	var v := _venue()
	var deep := 1.8      # three lines of people
	v.add({"name": "near side, west", "a": Vector3(-hl + 0.5, 0, hw + 0.5), "b": Vector3(-8.0, 0, hw + 0.5), "rows": 1,
		"tread": deep, "seat": "floor"})
	v.add({"name": "near side, east", "a": Vector3(8.0, 0, hw + 0.5), "b": Vector3(hl - 0.5, 0, hw + 0.5), "rows": 1,
		"tread": deep, "seat": "floor"})
	# The path behind the far fence: one line, half a metre back from it (a cheer's arms clear of the wire), between the
	# park benches 1 m behind it (at x -15, -7.5 and 7.5, Arena._outdoor).
	for part: Array in [[-hl, -16.0], [-14.0, -8.5], [-6.5, 6.5], [8.5, hl]]:
		v.add({"name": "far side, %+.0f m" % ((part[0] + part[1]) * 0.5), "a": Vector3(part[0], 0, fz - 0.5),
			"b": Vector3(part[1], 0, fz - 0.5), "rows": 1, "tread": 0.6, "seat": "floor", "barrier": {"height": 3.6, "gap": 0.5},
			"fill": 0.7})
	for sx: float in [-1.0, 1.0]:
		var end := "east end" if sx > 0.0 else "west end"
		var x := sx * (fx + 0.35)
		var bar := {"height": 1.2, "gap": 0.35}
		# The park bench behind each end (at fx + 2, z -4): two lines in front of it, three either side.
		for part: Array in [[hw - 1.0, -2.8, deep, "near"], [-2.8, -5.2, 1.2, "by the bench"],
				[-5.2, -hw + 1.0, deep, "far"]]:
			v.add({"name": "%s, %s" % [end, part[3]], "a": Vector3(x, 0, part[0]), "b": Vector3(x, 0, part[1]), "rows": 1,
				"tread": part[2], "seat": "floor", "barrier": bar})
	return v


## The audit's registry (tools/wsg/crowd_audit.gd): each venue as Arena declares it at the audit's level (its third
## argument: 1 Medium, 2 High), the Low arena's own stands too, each drawn in its real venue (tests/crowd_scene.gd).
static func venues() -> Array:
	var args := OS.get_cmdline_user_args()
	var q := clampi(int(args[2]) if args.size() > 2 else 2, 1, 2)
	var out := []
	for e: Array in [["Arena", "arena", q], ["Arena (Low)", "arena", 0], ["Sports hall", "hall", q],
			["Park court", "outdoor", q]]:
		var keep: int = int(Game.settings.graphics)
		Game.settings.graphics = e[2]
		var a := Arena.new(e[1])
		a.crowd_off = true
		a._ready()
		out.append({"name": e[0], "venue": a.crowd_venue,
			"scene": "res://tests/crowd_scene_%s%s.tscn" % [e[1], "_low" if e[2] == 0 else ""]})
		a.free()
		Game.settings.graphics = keep
	return out
