class_name WsgGrip
extends RefCounted
## Hands that close round a handle: a hurley's, a stick's, a flag's, a pole's.
##
## The handle is a cylinder across the palm (along the hand's width, +-Z in the rest), radius r. Each finger curls
## joint by joint, knuckle first, until that joint's segment touches the handle (the usual "curl to contact"); the
## thumb wraps the other way round it. Solved once per hand and radius from the rest joints, then cached: holding a
## grip costs a dozen set_bone_pose_rotation calls a frame.
##
##   body.grip("Right", 0.016)          # close the right hand on a 3.2 cm handle
##   body.grip_point("Right")           # where the handle's axis runs through that hand (world), to put the stick

const FINGER_HALF := 0.009      # a finger's half-thickness (m)
const PALM_HALF := 0.016        # half the palm's thickness

static var _cache := {}


## The handle's axis (a point on it, in the rest) for a hand: under the palm, between the palm's middle and the
## knuckles, a radius plus the palm's half-thickness below it.
static func axis_point(joints: Dictionary, side: String, r: float) -> Vector3:
	var w: Vector3 = joints[side + "Hand"]
	var k: Vector3 = joints[side + "HandMiddle1"]
	var p := w.lerp(k, 0.72)
	return Vector3(p.x, w.y - PALM_HALF - r, (joints[side + "HandIndex1"].z + joints[side + "HandPinky1"].z) * 0.5)


## {bone: Quaternion} closing the hand on a handle of radius r.
static func solve(joints: Dictionary, side: String, r: float) -> Dictionary:
	var key := "%s|%s|%.4f" % [joints.hash(), side, r]
	if _cache.has(key):
		return _cache[key]
	var s := 1.0 if side == "Left" else -1.0
	var c := axis_point(joints, side, r)
	var out := {}
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var names := [side + "Hand" + f + "1", side + "Hand" + f + "2", side + "Hand" + f + "3"]
		var pts: Array = names.map(func(n): return joints[n])
		pts.append(pts[2] + (pts[2] - pts[1]).normalized() * (pts[2] - pts[1]).length() * 0.85)
		# Curl about the hand's width (z): toward the palm is -y.
		var axis := Vector3(0, 0, -s)
		for k in 3:
			var best := deg_to_rad(100.0)
			for step in range(-30, 101, 2):
				var a := deg_to_rad(step)
				var q := Quaternion(axis, a)
				var hit := false
				for m in range(k + 1, 4):
					var p: Vector3 = pts[k] + q * (pts[m] - pts[k])
					if _dist_to_axis(p, c) < r + FINGER_HALF:
						hit = true
						break
				if hit:
					best = a
					break
			var qk := Quaternion(axis, best)
			for m in range(k + 1, 4):
				pts[m] = pts[k] + qk * (pts[m] - pts[k])
			out[names[k]] = qk
		# (Every curl is about the same axis, so each joint's turn relative to its parent is its own curl.)
	# The thumb comes round the handle from the other side: turned in toward the fingers and curled.
	out[side + "HandThumb1"] = Quaternion(Vector3(s, 0, 0), deg_to_rad(35)) * Quaternion(Vector3(0, s, 0), deg_to_rad(-15))
	out[side + "HandThumb2"] = Quaternion(Vector3(0, 0, -s), deg_to_rad(30))
	out[side + "HandThumb3"] = Quaternion(Vector3(0, 0, -s), deg_to_rad(25))
	_cache[key] = out
	return out


## Distance from p to the handle's axis (along z) through c.
static func _dist_to_axis(p: Vector3, c: Vector3) -> float:
	return Vector2(p.x - c.x, p.y - c.y).length()
