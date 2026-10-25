class_name Moves
extends RefCounted
## The players' moves as key poses (RealBody's angles, in degrees), played over a move's length. Each move that meets
## the ball knows when (contact, a fraction of its length) and where: the height the ball is met at and how far in
## front of the player, so a player can be sent to the right spot at the right moment and start the move so his foot,
## knee or head arrives with the ball. Moves are made for the right foot; mirrored for the left (and for kicks to
## the other side).
##
## Besides the bones, a key may set "y" (the body's lift off the floor, m: a jump), "yaw" (degrees the body turns from
## facing the net), "hips_y" (the hips lowered, m), "hips_fwd" and "hips_side" (the hips moved toward the net and to
## his right, m) and "plant" (0: leave the body's height as it is, for motion capture; RealBody keeps a foot on the
## floor otherwise).

const READY := {
	"hips": Vector3(0, 0, 0), "hips_y": -0.07, "y": 0.0, "yaw": 0.0,
	"spine": Vector3(10, 0, 0), "chest": Vector3(4, 0, 0), "neck": Vector3(-4, 0, 0), "head": Vector3(-8, 0, 0),
	"upperarm_l": Vector3(-12, 0, 24), "forearm_l": Vector3(-40, 0, 0), "hand_l": Vector3.ZERO,
	"upperarm_r": Vector3(-12, 0, -24), "forearm_r": Vector3(-40, 0, 0), "hand_r": Vector3.ZERO,
	"thigh_l": Vector3(-22, 0, 7), "shin_l": Vector3(38, 0, 0), "foot_l": Vector3(-14, 0, -7),
	"thigh_r": Vector3(-22, 0, -7), "shin_r": Vector3(38, 0, 0), "foot_r": Vector3(-14, 0, 7),
}

## Where a move meets the ball: [height above the floor (m), how far in front of the player toward the net (m), how
## far to his kicking side (m)], the move's length (s) and when in it the ball is met (0-1). The moves from motion
## capture (CLIPS) have theirs measured on the man's model by tools/models/fbx_to_move.gd, which prints these rows.
const CONTACT := {
	"sila": [0.62, 0.28, 0.05, 0.55, 0.45],
	"kuda": [0.55, 0.62, 0.12, 0.6, 0.45],
	"thigh": [0.91, 0.29, 0.28, 0.62, 0.42],
	"chest": [1.30, 0.22, 0.0, 0.6, 0.45],
	"header": [1.78, 0.18, 0.0, 0.55, 0.45],
	"dig": [0.28, 0.95, 0.25, 0.8, 0.38],
	"serve": [1.19, 0.92, -0.13, 1.1, 0.5],
	"horse": [1.62, 0.42, 0.1, 1.1, 0.55],
	"toss": [1.05, 0.35, 0.0, 0.7, 0.5],
	"roll": [2.07, 0.73, 0.14, 1.65, 0.36],
	"sunback": [1.95, 0.79, -0.17, 1.05, 0.43],
	"tapak": [1.91, 0.97, -0.15, 1.05, 0.42],
	"head_spike": [2.34, 0.34, -0.05, 0.95, 0.45],
	"feint": [1.80, 0.46, 0.1, 0.75, 0.45],
	"block": [2.1, 0.68, -0.28, 0.9, 0.45],
}

## The moves taken from motion capture (tools/models/fbx_to_move.gd): a pose for each frame.
const CLIPS := ["serve", "roll", "sunback", "tapak", "thigh", "run", "walk", "block", "head_spike", "celebrate"]
## Of those, the ones built on a real jump from the CMU library (mocap.cs.cmu.edu; the clip each comes from), with the
## part of the move that is takraw's own (the raised leg, the nod) laid over it from the keys written here (drawn).
const CMU := {"block": "118_04", "head_spike": "118_04", "celebrate": "118_04"}
const CLIP_DIR := "res://assets/moves/"

static var _moves := {}
static var _clips := {}


static func _build() -> void:
	if not _moves.is_empty():
		return
	for name in CLIPS:
		var frames := load_clip(CLIP_DIR + name + ".json")
		if not frames.is_empty():
			_clips[name] = frames
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
		# The block is made with the feet: a jump at the net, turned side on, one leg raised high with its sole to the
		# spike (the arms out for balance, never up: a hand on the ball is a fault).
		"block": [
			[0.0, {}],
			[0.22, {"hips_y": -0.24, "yaw": 20.0, "thigh_l": Vector3(-60, 0, 7), "thigh_r": Vector3(-60, 0, -7), "shin_l": Vector3(92, 0, 0),
				"shin_r": Vector3(92, 0, 0), "upperarm_l": Vector3(35, 0, 18), "upperarm_r": Vector3(35, 0, -18)}],
			[0.45, {"y": 0.6, "yaw": 60.0, "hips": Vector3(0, 0, -12), "spine": Vector3(-4, 0, 14), "chest": Vector3(0, 0, 6), "head": Vector3(10, -40, -10),
				"thigh_r": Vector3(-128, 0, -34), "shin_r": Vector3(6, 0, 0), "foot_r": Vector3(-25, 0, 0),
				"thigh_l": Vector3(-28, 0, 10), "shin_l": Vector3(58, 0, 0), "foot_l": Vector3(20, 0, 0),
				"upperarm_l": Vector3(-15, 0, 72), "upperarm_r": Vector3(-10, 0, -62), "forearm_l": Vector3(-20, 0, 0), "forearm_r": Vector3(-25, 0, 0)}],
			[0.7, {"y": 0.22, "yaw": 40.0, "thigh_r": Vector3(-55, 0, -16), "shin_r": Vector3(35, 0, 0), "thigh_l": Vector3(-30, 0, 8), "shin_l": Vector3(45, 0, 0),
				"upperarm_l": Vector3(-10, 0, 45), "upperarm_r": Vector3(-10, 0, -45)}],
			[0.88, {"y": 0.0, "hips_y": -0.2, "yaw": 15.0, "thigh_l": Vector3(-50, 0, 7), "thigh_r": Vector3(-50, 0, -7), "shin_l": Vector3(80, 0, 0),
				"shin_r": Vector3(80, 0, 0)}],
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
		"clap": [
			[0.0, {}],
			[0.15, {"upperarm_l": Vector3(-62, 0, 14), "upperarm_r": Vector3(-62, 0, -14), "forearm_l": Vector3(-55, 0, 0), "forearm_r": Vector3(-55, 0, 0), "head": Vector3(-8, 0, 0)}],
			[0.27, {"upperarm_l": Vector3(-62, 0, -18), "upperarm_r": Vector3(-62, 0, 18), "forearm_l": Vector3(-62, 0, 0), "forearm_r": Vector3(-62, 0, 0)}],
			[0.42, {"upperarm_l": Vector3(-62, 0, 14), "upperarm_r": Vector3(-62, 0, -14), "forearm_l": Vector3(-55, 0, 0), "forearm_r": Vector3(-55, 0, 0)}],
			[0.54, {"upperarm_l": Vector3(-62, 0, -18), "upperarm_r": Vector3(-62, 0, 18), "forearm_l": Vector3(-62, 0, 0), "forearm_r": Vector3(-62, 0, 0)}],
			[0.69, {"upperarm_l": Vector3(-62, 0, 14), "upperarm_r": Vector3(-62, 0, -14), "forearm_l": Vector3(-55, 0, 0), "forearm_r": Vector3(-55, 0, 0)}],
			[0.81, {"upperarm_l": Vector3(-62, 0, -18), "upperarm_r": Vector3(-62, 0, 18), "forearm_l": Vector3(-62, 0, 0), "forearm_r": Vector3(-62, 0, 0)}],
			[1.0, {}],
		],
		"point": [
			[0.0, {}],
			[0.3, {"spine": Vector3(-8, 0, 0), "head": Vector3(-20, 0, 0), "upperarm_r": Vector3(-150, 0, -18), "forearm_r": Vector3(-8, 0, 0),
				"upperarm_l": Vector3(-20, 0, 12), "forearm_l": Vector3(-60, 0, 0)}],
			[0.75, {"spine": Vector3(-8, 0, 0), "head": Vector3(-22, 0, 0), "upperarm_r": Vector3(-155, 0, -22), "forearm_r": Vector3(-5, 0, 0),
				"upperarm_l": Vector3(-20, 0, 12), "forearm_l": Vector3(-60, 0, 0)}],
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


## A move from motion capture, as poses: each bone's turn a Quaternion.
static func load_clip(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return []
	var frames := []
	for fr in data.get("frames", []):
		var pose := {}
		for key in fr:
			var v = fr[key]
			pose[key] = Quaternion(v[0], v[1], v[2], v[3]) if v is Array else float(v)
		frames.append(pose)
	return frames


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
			# The hands resting on the thighs, the arms relaxed (not held out in front).
			p.upperarm_l = Vector3(-12, 0, 5)
			p.upperarm_r = Vector3(-12, 0, -5)
			p.forearm_l = Vector3(-45, 0, 0)
			p.forearm_r = Vector3(-45, 0, 0)
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
	return _moves.has(name) or _clips.has(name)


## Whether a move plays from motion capture (its clip loaded).
static func is_clip(name: String) -> bool:
	_build()
	return _clips.has(name)


static func length(name: String) -> float:
	if CONTACT.has(name):
		return float(CONTACT[name][3])
	return {"celebrate": 1.3, "fist": 1.1, "clap": 1.4, "point": 1.5, "slump": 2.2}.get(name, 1.0)


## When in a move the ball is met, in seconds from its start.
static func contact_time(name: String) -> float:
	return float(CONTACT[name][3]) * float(CONTACT[name][4]) if CONTACT.has(name) else 0.0


## The pose part way (t: 0-1) through a move; mirrored for the left foot.
static func sample(name: String, t: float, mirror := false) -> Dictionary:
	_build()
	t = clampf(t, 0.0, 1.0)
	if _clips.has(name):
		# A move from motion capture: a pose for every frame, played straight through.
		var frames: Array = _clips[name]
		var f := t * float(frames.size() - 1)
		var i := mini(int(f), frames.size() - 2)
		var pc := blend(frames[i], frames[i + 1], f - float(i))
		return Moves.mirrored(pc) if mirror else pc
	return drawn(name, t, mirror)


## The pose part way through a move as its keys here have it (not motion capture).
static func drawn(name: String, t: float, mirror := false) -> Dictionary:
	_build()
	t = clampf(t, 0.0, 1.0)
	var keys: Array = _moves.get(name, [])
	if keys.is_empty():
		return READY.duplicate()
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


## a to b by k (0-1): angles, lifts and turns alike. A bone's angles (degrees) and a turn from motion capture (a
## Quaternion) blend as turns.
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var va = a[key]
		var vb = b.get(key, _rest_of(key, va))
		out[key] = _mix(va, vb, k)
	for key in b:
		if not a.has(key):
			out[key] = _mix(_rest_of(key, b[key]), b[key], k)
	return out


static func _mix(va, vb, k: float):
	if va is Quaternion or vb is Quaternion:
		return RealBody.local_rot(va).slerp(RealBody.local_rot(vb), k)
	if va is Vector3:
		return (va as Vector3).lerp(vb, k)
	return lerpf(float(va), float(vb), k)


## What a pose without the key means by it.
static func _rest_of(key: String, like):
	if like is Vector3 or like is Quaternion:
		return Vector3.ZERO
	return 1.0 if key == "plant" else 0.0


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
		elif v is Quaternion:
			out[k] = Quaternion(v.x, -v.y, -v.z, v.w)
		elif key == "yaw" or key == "hips_side":
			out[k] = -float(v)
		else:
			out[k] = v
	return out


## The running stride at phase ph (radians, a stride each turn), at speed k (0-1 of a sprint), and a side-shuffle for
## sideways steps: the models' own walk and run (from motion capture), the shuffle drawn.
static func run(ph: float, k: float, side := 0.0) -> Dictionary:
	var p := _drawn_run(ph, k, side)
	_build()
	if not _clips.has("run") or k < 0.02:
		return p
	var cyc := fposmod(ph / TAU, 1.0)
	var stride := _cycle("run", cyc)
	if _clips.has("walk") and k < 0.6:
		stride = blend(_cycle("walk", cyc), stride, smoothstep(0.3, 0.6, k))
	return blend(p, stride, smoothstep(0.02, 0.2, k) * (1.0 - absf(side)))


## A stride's pose part way (0-1) round its cycle.
static func _cycle(name: String, c: float) -> Dictionary:
	var frames: Array = _clips[name]
	var f := c * float(frames.size())
	var i := int(f) % frames.size()
	return blend(frames[i], frames[(i + 1) % frames.size()], f - floorf(f))


## The stride drawn by hand: standing (k 0) to a sprint, and the side-shuffle.
static func _drawn_run(ph: float, k: float, side: float) -> Dictionary:
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
