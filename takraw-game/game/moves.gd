class_name Moves
extends RefCounted
## The players' moves as key poses (ToonBody's angles, in degrees), played over a move's length. Each move that meets
## the ball knows when (contact, a fraction of its length) and where: the height the ball is met at and how far in
## front of the player, so a player can be sent to the right spot at the right moment and start the move so his foot,
## knee or head arrives with the ball. Moves are made for the right foot; mirrored for the left (and for kicks to
## the other side).
##
## Besides the bones, a key may set "y" (the body's lift off the floor, m: a jump), "yaw" (degrees the body turns from
## facing the net) and "hips_y" (the hips lowered, m).

const READY := {
	"hips": Vector3(0, 0, 0), "hips_y": -0.07, "y": 0.0, "yaw": 0.0,
	"spine": Vector3(10, 0, 0), "chest": Vector3(4, 0, 0), "neck": Vector3(-4, 0, 0), "head": Vector3(-8, 0, 0),
	"upperarm_l": Vector3(-12, 0, 24), "forearm_l": Vector3(-40, 0, 0), "hand_l": Vector3.ZERO,
	"upperarm_r": Vector3(-12, 0, -24), "forearm_r": Vector3(-40, 0, 0), "hand_r": Vector3.ZERO,
	"thigh_l": Vector3(-22, 0, 7), "shin_l": Vector3(38, 0, 0), "foot_l": Vector3(-14, 0, -7),
	"thigh_r": Vector3(-22, 0, -7), "shin_r": Vector3(38, 0, 0), "foot_r": Vector3(-14, 0, 7),
}

## Where a move meets the ball: [height above the floor (m), how far in front of the player toward the net (m), how
## far to his kicking side (m)], the move's length (s) and when in it the ball is met (0-1).
const CONTACT := {
	"sila": [0.62, 0.28, 0.05, 0.55, 0.45],
	"kuda": [0.55, 0.62, 0.12, 0.6, 0.45],
	"thigh": [0.88, 0.36, 0.12, 0.55, 0.45],
	"chest": [1.30, 0.22, 0.0, 0.6, 0.45],
	"header": [1.78, 0.18, 0.0, 0.55, 0.45],
	"dig": [0.28, 0.95, 0.25, 0.8, 0.38],
	"serve": [1.08, 0.58, 0.16, 1.0, 0.55],
	"horse": [1.62, 0.42, 0.1, 1.1, 0.55],
	"toss": [1.05, 0.35, 0.0, 0.7, 0.5],
	"roll": [2.50, 0.42, 0.0, 1.15, 0.48],
	"sunback": [2.20, 0.34, 0.32, 1.0, 0.45],
	"tapak": [2.00, 0.50, 0.12, 0.9, 0.45],
	"head_spike": [2.25, 0.30, 0.0, 0.95, 0.45],
	"feint": [1.80, 0.46, 0.1, 0.75, 0.45],
	"block": [2.05, 0.30, 0.0, 0.9, 0.45],
}

static var _moves := {}


static func _build() -> void:
	if not _moves.is_empty():
		return
	_moves = {
		"sila": [
			[0.0, {}],
			[0.28, {"hips_y": -0.06, "spine": Vector3(8, 0, -8), "thigh_r": Vector3(-10, 0, -12), "shin_r": Vector3(62, 0, 0)}],
			[0.45, {"spine": Vector3(5, 0, -6), "head": Vector3(26, 0, 0), "thigh_r": Vector3(-52, 42, -36), "shin_r": Vector3(78, 0, 0),
				"foot_r": Vector3(-8, 0, 30), "upperarm_l": Vector3(-10, 0, 62), "upperarm_r": Vector3(-10, 0, -55)}],
			[0.72, {"thigh_r": Vector3(-30, 15, -16), "shin_r": Vector3(42, 0, 0), "head": Vector3(10, 0, 0)}],
			[1.0, {}],
		],
		"kuda": [
			[0.0, {}],
			[0.25, {"thigh_r": Vector3(25, 0, -6), "shin_r": Vector3(70, 0, 0), "spine": Vector3(14, 0, 0)}],
			[0.45, {"spine": Vector3(-12, 0, 0), "thigh_r": Vector3(-78, 0, -6), "shin_r": Vector3(8, 0, 0), "foot_r": Vector3(42, 0, 0),
				"upperarm_l": Vector3(10, 0, 55), "upperarm_r": Vector3(10, 0, -55), "head": Vector3(22, 0, 0)}],
			[0.7, {"thigh_r": Vector3(-60, 0, -6), "shin_r": Vector3(25, 0, 0)}],
			[1.0, {}],
		],
		"thigh": [
			[0.0, {}],
			[0.45, {"thigh_r": Vector3(-86, 0, -4), "shin_r": Vector3(88, 0, 0), "foot_r": Vector3(0, 0, 0), "head": Vector3(28, 0, 0),
				"upperarm_l": Vector3(-5, 0, 58), "upperarm_r": Vector3(-5, 0, -58), "spine": Vector3(2, 0, 0)}],
			[0.7, {"thigh_r": Vector3(-50, 0, -4), "shin_r": Vector3(60, 0, 0)}],
			[1.0, {}],
		],
		"chest": [
			[0.0, {}],
			[0.45, {"spine": Vector3(-18, 0, 0), "chest": Vector3(-14, 0, 0), "head": Vector3(18, 0, 0),
				"upperarm_l": Vector3(35, 0, 48), "upperarm_r": Vector3(35, 0, -48), "forearm_l": Vector3(-20, 0, 0), "forearm_r": Vector3(-20, 0, 0),
				"thigh_l": Vector3(-12, 0, 8), "thigh_r": Vector3(-12, 0, -8), "shin_l": Vector3(30, 0, 0), "shin_r": Vector3(30, 0, 0)}],
			[1.0, {}],
		],
		"header": [
			[0.0, {}],
			[0.25, {"hips_y": -0.14, "spine": Vector3(-8, 0, 0), "head": Vector3(-30, 0, 0), "thigh_l": Vector3(-40, 0, 7), "thigh_r": Vector3(-40, 0, -7),
				"shin_l": Vector3(70, 0, 0), "shin_r": Vector3(70, 0, 0)}],
			[0.45, {"y": 0.16, "spine": Vector3(18, 0, 0), "head": Vector3(24, 0, 0), "upperarm_l": Vector3(15, 0, 40), "upperarm_r": Vector3(15, 0, -40),
				"thigh_l": Vector3(-8, 0, 5), "thigh_r": Vector3(-8, 0, -5), "shin_l": Vector3(20, 0, 0), "shin_r": Vector3(20, 0, 0)}],
			[0.75, {"y": 0.0}],
			[1.0, {}],
		],
		"dig": [
			[0.0, {}],
			[0.38, {"hips_y": -0.42, "spine": Vector3(30, 0, -10), "thigh_r": Vector3(-82, 0, -14), "shin_r": Vector3(4, 0, 0), "foot_r": Vector3(40, 0, 0),
				"thigh_l": Vector3(-6, 0, 10), "shin_l": Vector3(118, 0, 0), "upperarm_l": Vector3(-30, 0, 70), "upperarm_r": Vector3(-30, 0, -70),
				"head": Vector3(10, 0, 0)}],
			[0.7, {"hips_y": -0.3, "thigh_r": Vector3(-60, 0, -10), "shin_r": Vector3(30, 0, 0), "shin_l": Vector3(100, 0, 0)}],
			[1.0, {}],
		],
		"serve": [
			[0.0, {}],
			[0.3, {"spine": Vector3(8, 0, 0), "thigh_r": Vector3(42, 0, -10), "shin_r": Vector3(72, 0, 0), "upperarm_l": Vector3(-10, 0, 50), "upperarm_r": Vector3(10, 0, -50),
				"thigh_l": Vector3(-12, 0, 6), "shin_l": Vector3(26, 0, 0)}],
			[0.55, {"spine": Vector3(-24, 0, -6), "chest": Vector3(-8, 0, 0), "head": Vector3(30, 0, 0), "thigh_r": Vector3(-102, 0, -8),
				"shin_r": Vector3(6, 0, 0), "foot_r": Vector3(42, 0, 0), "upperarm_l": Vector3(-30, 0, 72), "upperarm_r": Vector3(-10, 0, -70),
				"thigh_l": Vector3(-6, 0, 6), "shin_l": Vector3(14, 0, 0)}],
			[0.78, {"spine": Vector3(-30, 0, -4), "thigh_r": Vector3(-122, 0, -6), "shin_r": Vector3(22, 0, 0)}],
			[1.0, {}],
		],
		"horse": [
			[0.0, {}],
			[0.3, {"yaw": 160.0, "spine": Vector3(30, 0, 0), "thigh_r": Vector3(-30, 0, -8), "shin_r": Vector3(60, 0, 0)}],
			[0.55, {"yaw": 172.0, "spine": Vector3(55, 0, 0), "chest": Vector3(15, 0, 0), "head": Vector3(-30, 0, 0), "thigh_r": Vector3(152, 0, -10),
				"shin_r": Vector3(16, 0, 0), "foot_r": Vector3(-20, 0, 0), "upperarm_l": Vector3(-40, 0, 60), "upperarm_r": Vector3(-40, 0, -60),
				"thigh_l": Vector3(-30, 0, 6), "shin_l": Vector3(30, 0, 0)}],
			[0.8, {"yaw": 100.0, "spine": Vector3(30, 0, 0), "thigh_r": Vector3(60, 0, -8), "shin_r": Vector3(40, 0, 0)}],
			[1.0, {}],
		],
		"toss": [
			[0.0, {"upperarm_l": Vector3(-48, 0, 12), "upperarm_r": Vector3(-48, 0, -12), "forearm_l": Vector3(-40, 0, 0), "forearm_r": Vector3(-40, 0, 0)}],
			[0.28, {"spine": Vector3(18, 0, 0), "upperarm_l": Vector3(22, 0, 10), "upperarm_r": Vector3(22, 0, -10), "forearm_l": Vector3(-15, 0, 0), "forearm_r": Vector3(-15, 0, 0)}],
			[0.5, {"spine": Vector3(4, 0, 0), "upperarm_l": Vector3(-78, 0, 8), "upperarm_r": Vector3(-78, 0, -8), "forearm_l": Vector3(-25, 0, 0), "forearm_r": Vector3(-25, 0, 0)}],
			[1.0, {}],
		],
		"roll": [
			[0.0, {}],
			[0.18, {"hips_y": -0.26, "spine": Vector3(26, 0, 0), "thigh_l": Vector3(-62, 0, 7), "thigh_r": Vector3(-62, 0, -7), "shin_l": Vector3(95, 0, 0),
				"shin_r": Vector3(95, 0, 0), "foot_l": Vector3(-30, 0, 0), "foot_r": Vector3(-30, 0, 0), "upperarm_l": Vector3(45, 0, 20), "upperarm_r": Vector3(45, 0, -20)}],
			[0.32, {"y": 0.55, "hips": Vector3(-45, 0, 0), "spine": Vector3(0, 0, 0), "thigh_l": Vector3(-20, 0, 6), "shin_l": Vector3(30, 0, 0),
				"thigh_r": Vector3(-40, 0, -6), "shin_r": Vector3(40, 0, 0), "upperarm_l": Vector3(-150, 0, 20), "upperarm_r": Vector3(-150, 0, -20)}],
			[0.48, {"y": 0.82, "hips": Vector3(-132, 0, 0), "spine": Vector3(-10, 0, 0), "head": Vector3(-20, 0, 0), "thigh_r": Vector3(-24, 0, -4),
				"shin_r": Vector3(4, 0, 0), "foot_r": Vector3(30, 0, 0), "thigh_l": Vector3(70, 0, 8), "shin_l": Vector3(50, 0, 0),
				"upperarm_l": Vector3(-60, 0, 85), "upperarm_r": Vector3(-60, 0, -85)}],
			[0.66, {"y": 0.6, "hips": Vector3(-250, 0, 0), "thigh_r": Vector3(-30, 0, -6), "thigh_l": Vector3(-20, 0, 6), "shin_l": Vector3(60, 0, 0), "shin_r": Vector3(60, 0, 0)}],
			[0.84, {"y": 0.02, "hips": Vector3(-340, 0, 0), "hips_y": -0.3, "thigh_l": Vector3(-70, 0, 8), "thigh_r": Vector3(-70, 0, -8), "shin_l": Vector3(105, 0, 0),
				"shin_r": Vector3(105, 0, 0), "foot_l": Vector3(-35, 0, 0), "foot_r": Vector3(-35, 0, 0), "upperarm_l": Vector3(-40, 0, 60), "upperarm_r": Vector3(-40, 0, -60)}],
			[1.0, {"hips": Vector3(-360, 0, 0)}],
		],
		"sunback": [
			[0.0, {}],
			[0.2, {"hips_y": -0.2, "yaw": 30.0, "thigh_l": Vector3(-55, 0, 7), "thigh_r": Vector3(-55, 0, -7), "shin_l": Vector3(85, 0, 0), "shin_r": Vector3(85, 0, 0),
				"upperarm_l": Vector3(40, 0, 25), "upperarm_r": Vector3(40, 0, -25)}],
			[0.45, {"y": 0.68, "yaw": 72.0, "spine": Vector3(-6, 0, -38), "chest": Vector3(0, 0, -10), "head": Vector3(10, -30, 20),
				"thigh_r": Vector3(-38, 0, -112), "shin_r": Vector3(8, 0, 0), "foot_r": Vector3(30, 0, 0),
				"thigh_l": Vector3(-62, 0, 18), "shin_l": Vector3(84, 0, 0), "upperarm_l": Vector3(-30, 0, 100), "upperarm_r": Vector3(-20, 0, -60)}],
			[0.7, {"y": 0.3, "yaw": 40.0, "thigh_r": Vector3(-40, 0, -40), "spine": Vector3(5, 0, -10)}],
			[0.88, {"y": 0.0, "hips_y": -0.22, "thigh_l": Vector3(-50, 0, 7), "thigh_r": Vector3(-50, 0, -7), "shin_l": Vector3(80, 0, 0), "shin_r": Vector3(80, 0, 0)}],
			[1.0, {}],
		],
		"tapak": [
			[0.0, {}],
			[0.2, {"hips_y": -0.2, "thigh_l": Vector3(-55, 0, 7), "thigh_r": Vector3(-55, 0, -7), "shin_l": Vector3(85, 0, 0), "shin_r": Vector3(85, 0, 0),
				"upperarm_l": Vector3(40, 0, 25), "upperarm_r": Vector3(40, 0, -25)}],
			[0.45, {"y": 0.6, "spine": Vector3(-22, 0, 0), "head": Vector3(25, 0, 0), "thigh_r": Vector3(-122, 0, -6), "shin_r": Vector3(28, 0, 0),
				"foot_r": Vector3(-40, 0, 0), "thigh_l": Vector3(-20, 0, 6), "shin_l": Vector3(60, 0, 0), "upperarm_l": Vector3(-40, 0, 70), "upperarm_r": Vector3(-40, 0, -70)}],
			[0.75, {"y": 0.15, "thigh_r": Vector3(-50, 0, -6), "shin_r": Vector3(60, 0, 0), "spine": Vector3(10, 0, 0)}],
			[1.0, {}],
		],
		"head_spike": [
			[0.0, {}],
			[0.2, {"hips_y": -0.22, "thigh_l": Vector3(-58, 0, 7), "thigh_r": Vector3(-58, 0, -7), "shin_l": Vector3(90, 0, 0), "shin_r": Vector3(90, 0, 0),
				"upperarm_l": Vector3(45, 0, 22), "upperarm_r": Vector3(45, 0, -22)}],
			[0.36, {"y": 0.55, "spine": Vector3(-26, 0, 0), "head": Vector3(-34, 0, 0), "upperarm_l": Vector3(-120, 0, 30), "upperarm_r": Vector3(-120, 0, -30)}],
			[0.45, {"y": 0.68, "spine": Vector3(26, 0, 0), "chest": Vector3(10, 0, 0), "head": Vector3(38, 0, 0), "thigh_l": Vector3(-30, 0, 6),
				"thigh_r": Vector3(-30, 0, -6), "shin_l": Vector3(70, 0, 0), "shin_r": Vector3(70, 0, 0), "upperarm_l": Vector3(20, 0, 50), "upperarm_r": Vector3(20, 0, -50)}],
			[0.75, {"y": 0.1}],
			[1.0, {}],
		],
		"feint": [
			[0.0, {}],
			[0.25, {"hips_y": -0.15, "thigh_l": Vector3(-40, 0, 7), "thigh_r": Vector3(-40, 0, -7), "shin_l": Vector3(70, 0, 0), "shin_r": Vector3(70, 0, 0)}],
			[0.45, {"y": 0.34, "thigh_r": Vector3(-102, 0, -6), "shin_r": Vector3(70, 0, 0), "foot_r": Vector3(20, 0, 0), "spine": Vector3(-6, 0, 0),
				"head": Vector3(22, 0, 0), "upperarm_l": Vector3(-20, 0, 50), "upperarm_r": Vector3(-20, 0, -50)}],
			[0.75, {"y": 0.0}],
			[1.0, {}],
		],
		"block": [
			[0.0, {}],
			[0.22, {"hips_y": -0.24, "thigh_l": Vector3(-60, 0, 7), "thigh_r": Vector3(-60, 0, -7), "shin_l": Vector3(92, 0, 0), "shin_r": Vector3(92, 0, 0),
				"upperarm_l": Vector3(40, 0, 15), "upperarm_r": Vector3(40, 0, -15)}],
			[0.45, {"y": 0.78, "spine": Vector3(-12, 0, 0), "head": Vector3(14, 0, 0), "thigh_l": Vector3(-78, 0, 12), "thigh_r": Vector3(-78, 0, -12),
				"shin_l": Vector3(96, 0, 0), "shin_r": Vector3(96, 0, 0), "foot_l": Vector3(-20, 0, 0), "foot_r": Vector3(-20, 0, 0),
				"upperarm_l": Vector3(55, 0, 20), "upperarm_r": Vector3(55, 0, -20), "forearm_l": Vector3(-10, 0, 0), "forearm_r": Vector3(-10, 0, 0)}],
			[0.75, {"y": 0.2}],
			[0.9, {"y": 0.0, "hips_y": -0.2}],
			[1.0, {}],
		],
		"celebrate": [
			[0.0, {}],
			[0.25, {"y": 0.38, "upperarm_l": Vector3(-170, 0, 22), "upperarm_r": Vector3(-170, 0, -22), "forearm_l": Vector3(0, 0, 0), "forearm_r": Vector3(0, 0, 0),
				"head": Vector3(-25, 0, 0), "thigh_l": Vector3(-30, 0, 10), "thigh_r": Vector3(-5, 0, -10), "shin_l": Vector3(60, 0, 0), "shin_r": Vector3(20, 0, 0)}],
			[0.55, {"y": 0.0, "upperarm_l": Vector3(-165, 0, 30), "upperarm_r": Vector3(-165, 0, -30), "forearm_l": Vector3(0, 0, 0), "forearm_r": Vector3(0, 0, 0)}],
			[1.0, {}],
		],
		"fist": [
			[0.0, {}],
			[0.3, {"spine": Vector3(20, 0, 0), "upperarm_r": Vector3(-60, 0, -15), "forearm_r": Vector3(-120, 0, 0), "head": Vector3(-10, 0, 0)}],
			[0.5, {"spine": Vector3(-5, 0, 0), "upperarm_r": Vector3(-20, 0, -10), "forearm_r": Vector3(-140, 0, 0), "head": Vector3(-30, 0, 0)}],
			[0.7, {"spine": Vector3(20, 0, 0), "upperarm_r": Vector3(-60, 0, -15), "forearm_r": Vector3(-120, 0, 0)}],
			[1.0, {}],
		],
		"slump": [
			[0.0, {}],
			[0.35, {"hips_y": -0.12, "spine": Vector3(48, 0, 0), "chest": Vector3(12, 0, 0), "head": Vector3(10, 0, 0),
				"upperarm_l": Vector3(-50, 0, 10), "upperarm_r": Vector3(-50, 0, -10), "forearm_l": Vector3(-5, 0, 0), "forearm_r": Vector3(-5, 0, 0)}],
			[0.8, {"hips_y": -0.12, "spine": Vector3(48, 0, 0), "chest": Vector3(12, 0, 0), "head": Vector3(10, 0, 0),
				"upperarm_l": Vector3(-50, 0, 10), "upperarm_r": Vector3(-50, 0, -10), "forearm_l": Vector3(-5, 0, 0), "forearm_r": Vector3(-5, 0, 0)}],
			[1.0, {}],
		],
	}
	# Every key is a whole pose: the ready stance with the key's changes.
	for name in _moves:
		for key in _moves[name]:
			var full := READY.duplicate()
			full.merge(key[1], true)
			key[1] = full


## Poses held still: an official sitting in his chair, a line judge's signals.
static func static_pose(name: String) -> Dictionary:
	var p := READY.duplicate()
	p.hips_y = 0.0
	p.spine = Vector3(2, 0, 0)
	p.thigh_l = Vector3(0, 0, 3)
	p.thigh_r = Vector3(0, 0, -3)
	p.shin_l = Vector3.ZERO
	p.shin_r = Vector3.ZERO
	p.foot_l = Vector3.ZERO
	p.foot_r = Vector3.ZERO
	p.upperarm_l = Vector3(0, 0, 8)
	p.upperarm_r = Vector3(0, 0, -8)
	p.forearm_l = Vector3(-10, 0, 0)
	p.forearm_r = Vector3(-10, 0, 0)
	match name:
		"sit":
			p.hips_y = -0.48
			p.thigh_l = Vector3(-88, 0, 6)
			p.thigh_r = Vector3(-88, 0, -6)
			p.shin_l = Vector3(80, 0, 0)
			p.shin_r = Vector3(80, 0, 0)
			p.upperarm_l = Vector3(-30, 0, 10)
			p.upperarm_r = Vector3(-30, 0, -10)
			p.forearm_l = Vector3(-50, 0, 0)
			p.forearm_r = Vector3(-50, 0, 0)
		"signal_out":
			p.upperarm_r = Vector3(-176, 0, -6)
			p.forearm_r = Vector3(0, 0, 0)
		"signal_in":
			p.upperarm_r = Vector3(-42, 0, -10)
			p.forearm_r = Vector3(0, 0, 0)
			p.spine = Vector3(14, 0, 0)
	return p


static func has(name: String) -> bool:
	_build()
	return _moves.has(name)


static func length(name: String) -> float:
	if CONTACT.has(name):
		return float(CONTACT[name][3])
	return {"celebrate": 1.3, "fist": 1.1, "slump": 2.2}.get(name, 1.0)


## When in a move the ball is met, in seconds from its start.
static func contact_time(name: String) -> float:
	return float(CONTACT[name][3]) * float(CONTACT[name][4]) if CONTACT.has(name) else 0.0


## The pose part way (t: 0-1) through a move; mirrored for the left foot.
static func sample(name: String, t: float, mirror := false) -> Dictionary:
	_build()
	var keys: Array = _moves.get(name, [])
	if keys.is_empty():
		return READY.duplicate()
	t = clampf(t, 0.0, 1.0)
	var i := 0
	while i < keys.size() - 2 and t > float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]
	var b: Array = keys[mini(i + 1, keys.size() - 1)]
	var span := maxf(0.0001, float(b[0]) - float(a[0]))
	var k := clampf((t - float(a[0])) / span, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var p := blend(a[1], b[1], k)
	return Moves.mirrored(p) if mirror else p


## a to b by k (0-1): angles, lifts and turns alike.
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var va = a[key]
		var vb = b.get(key, va)
		if va is Vector3:
			out[key] = (va as Vector3).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out


## The same pose for the other foot: left and right swapped, and twists and side leans turned the other way.
static func mirrored(p: Dictionary) -> Dictionary:
	var out := {}
	for key in p:
		var v = p[key]
		var k: String = key
		if k.ends_with("_l"):
			k = k.left(-2) + "_r"
		elif k.ends_with("_r"):
			k = k.left(-2) + "_l"
		if v is Vector3:
			out[k] = Vector3(v.x, -v.y, -v.z)
		elif key == "yaw":
			out[k] = -float(v)
		else:
			out[k] = v
	return out


## The running stride at phase ph (radians), at speed k (0-1 of a sprint), and a side-shuffle for sideways steps.
static func run(ph: float, k: float, side := 0.0) -> Dictionary:
	var p := READY.duplicate()
	var s := sin(ph)
	var c := cos(ph)
	var swing := 42.0 * k
	p.hips_y = -0.05 - 0.03 * k + 0.035 * absf(c) * k
	p.spine = Vector3(10 + 10 * k, 0, 0)
	p.thigh_l = Vector3(-22 - swing * s * (1.0 - absf(side)), 0, 7 + 18 * side * maxf(0.0, s))
	p.thigh_r = Vector3(-22 + swing * s * (1.0 - absf(side)), 0, -7 + 18 * side * maxf(0.0, -s))
	p.shin_l = Vector3(38 + 55 * k * maxf(0.0, -c), 0, 0)
	p.shin_r = Vector3(38 + 55 * k * maxf(0.0, c), 0, 0)
	p.upperarm_l = Vector3(-12 + 38 * k * s, 0, 22)
	p.upperarm_r = Vector3(-12 - 38 * k * s, 0, -22)
	p.forearm_l = Vector3(-60 * k - 30, 0, 0)
	p.forearm_r = Vector3(-60 * k - 30, 0, 0)
	return p
