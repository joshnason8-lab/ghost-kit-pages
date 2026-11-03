class_name VenueCrowd
extends RefCounted
## Where each ground's people sit and stand, declared for the shared crowd (WsgCrowdVenue, the foundation's ADOPTING
## 5.1: the owner's rule that every fan sits on their seat, not in it, stands with their soles on the floor, and faces
## the play). The foundation places them from this, fits each to their seat and checks them (tools/wsg/crowd_audit.gd
## with game/crowd_venues.gd); Arena draws them (WsgCrowdCards) and puts a chair or a bench under the seated.
## The sections follow what Arena builds round each kind of ground (its stands, barricades, scaffolds and stage): the
## numbers here and there are the same.
##   main: everything the cameras see; near: the near side line's middle, drawn only from behind the pole.

const BARRICADE := {"height": 1.1, "gap": 0.4}
## The monobloc chair's seat as a fan sits on it (m deep): at the shared kind's 0.42 one fan (fan4) getting up still
## goes 1 mm further into the seat than the audit allows (also after the foundation's 6a59b52); 0.36 passes.
const CHAIR_DEPTH := 0.36


## The venue's crowd for a kind of ground ("village", "school", "arena", "stadium") round field f, on Low or not.
static func build(kind: String, f: Dictionary, low: bool, part := "main") -> WsgCrowdVenue:
	var v := WsgCrowdVenue.new(Vector3.ZERO, Vector2(f.length, f.width), 0.0)
	if kind in ["arena", "stadium"]:
		_stands(v, kind, f, low, part)
	else:
		_ground(v, kind, f, low, part)
	return v


## Tiers of concrete or painted steps (Arena._stands, _near_side): each row sits on the step behind the one its feet
## are on. Row 0's feet are on the floor in front of the first step.
static func _stands(v: WsgCrowdVenue, kind: String, f: Dictionary, low: bool, part: String) -> void:
	var indoor := kind == "arena"
	var rows := (14 if not low else 9) if indoor else (16 if not low else 10)
	var L: float = f.length * 0.5 + f.lobby + 3.0
	var W: float = f.width * 0.5 + f.lobby + 3.2
	var tier := {"rows": rows, "tread": 0.85, "rise": 0.45, "seat": "step", "pitch": 0.62}
	var front := 1.275   # from a step's middle row line to the front of the floor in front of it (0.425 + 0.85)
	if part == "near":
		_add(v, tier, "near stand", Vector3(-L, 0, W - front), Vector3(L, 0, W - front))
		return
	_add(v, tier, "far stand", Vector3(-L, 0, -(W - front)), Vector3(L, 0, -(W - front)))
	for s: float in [-1.0, 1.0]:
		_add(v, tier, "end stand %s" % ("left" if s < 0 else "right"), Vector3(s * (L - front), 0, -W + 0.4),
			Vector3(s * (L - front), 0, W - 3.0))


## A tournament ground (Arena._ground_crowd, _tournament, _scaffold, _stage, _near_side): behind the barricades, the
## far side's front row on chairs (benches for the school's pupils) and people standing behind; standing at the ends
## and on the near side; the school's scaffold stands at both ends and the village's at the right; the village's
## guests on the stage.
static func _ground(v: WsgCrowdVenue, kind: String, f: Dictionary, low: bool, part: String) -> void:
	var Lt: float = f.length * 0.5 + f.lobby
	var Wt: float = f.width * 0.5 + f.lobby
	var deep := 3 if low else 5
	var far_z := -(Wt + 2.9)         # the far barricade
	var end_x := Lt + 1.4            # the end barricades
	var near_z := Wt + 1.4           # the near barricades
	var gap: float = BARRICADE.gap
	var standing := {"rows": deep, "tread": 0.9, "rise": 0.0, "seat": "floor", "pitch": 0.6, "barrier": BARRICADE}
	if part == "near":
		_add(v, standing, "near middle", Vector3(-8.5, 0, near_z + gap), Vector3(8.5, 0, near_z + gap))
		return
	var span := end_x + 0.6
	if kind == "school":
		_add(v, {"rows": 1, "tread": 0.9, "seat": "bench", "pitch": 0.6, "barrier": BARRICADE}, "pupils' benches",
			Vector3(-span, 0, far_z - gap), Vector3(span, 0, far_z - gap))
	else:
		_add(v, {"rows": 1, "tread": 0.9, "seat": "chair", "depth": CHAIR_DEPTH, "pitch": 0.75, "barrier": BARRICADE}, "front chairs",
			Vector3(-span, 0, far_z - gap), Vector3(span, 0, far_z - gap))
	_add(v, {"rows": deep - 1, "tread": 0.9, "rise": 0.0, "seat": "floor", "pitch": 0.6}, "behind the chairs",
		Vector3(-span, 0, far_z - gap - 0.9), Vector3(span, 0, far_z - gap - 0.9))
	for s: float in [-1.0, 1.0]:
		var side := "left" if s < 0 else "right"
		_add(v, standing, "end %s" % side, Vector3(s * (end_x + gap), 0, far_z + 0.5), Vector3(s * (end_x + gap), 0, near_z - 0.5))
		_add(v, standing, "near %s" % side, Vector3(s * end_x, 0, near_z + gap), Vector3(s * 9.0, 0, near_z + gap))
	# Scaffold stands: plank tiers 0.85 apart rising 0.55, a plank 0.63 up the first, the foot board 0.45 below each.
	var x0 := Lt + 7.0
	for sx: float in ([-1.0, 1.0] if kind == "school" else [1.0]):
		_add(v, {"rows": 3 if low else 5, "tread": 0.85, "rise": 0.55, "seat": "bleacher", "height": 0.45, "depth": 0.4,
			"pitch": 0.6}, "scaffold %s" % ("left" if sx < 0 else "right"),
			Vector3(sx * (x0 - 0.65), 0.18, -8.2), Vector3(sx * (x0 - 0.65), 0.18, 8.2))
	if kind == "village":
		# The guests on chairs along the back of the stage (its platform 1.2 m up, its front 2 m in front of them).
		var z := -(Wt + 11.0)
		_add(v, {"rows": 1, "tread": 1.3, "seat": "chair", "depth": CHAIR_DEPTH, "pitch": 0.9}, "stage", Vector3(-4.5, 1.2, z + 0.6),
			Vector3(4.5, 1.2, z + 0.6))


static func _add(v: WsgCrowdVenue, spec: Dictionary, name: String, a: Vector3, b: Vector3) -> void:
	var s := spec.duplicate(true)
	s.name = name
	s.a = a
	s.b = b
	v.add(s)


## The props under the seated, from the places the foundation worked out: [chairs, benches] (Props transforms). A
## bench holds two.
static func props(v: WsgCrowdVenue, placed: Dictionary) -> Array:
	var chairs: Array = []
	var benches: Array = []
	var bench_at := {}
	for i in placed.spots.size():
		var s: Dictionary = v.sections[placed.section[i]]
		var p: Vector3 = placed.spots[i]
		var fc: Vector3 = placed.facings[i]
		match String(s.seat):
			"chair":
				chairs.append(Props.at(p, atan2(fc.x, fc.z)))
			"bench":
				var key := int(placed.section[i]) * 100000 + int(floor(p.x / 1.2))
				if not bench_at.has(key):
					bench_at[key] = true
					benches.append(Props.at(Vector3((floor(p.x / 1.2) + 0.5) * 1.2, p.y, p.z), 0.0))
	return [chairs, benches]
