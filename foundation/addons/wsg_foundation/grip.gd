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
##   body.grip_sphere("Right", 0.112)   # or round a ball (solve_sphere), the ball at body.ball_point("Right", 0.112)

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


## axis_point moved toward the palm's side just as far as it must for every finger's first bone (the knuckle to the
## next joint) to clear a handle of radius r: on a hand whose knuckles sit low on the palm the handle through
## axis_point ran into them. Hold a handle there with solve(..., [clear_axis_point(...), Vector3.BACK]).
static func clear_axis_point(joints: Dictionary, side: String, r: float) -> Vector3:
	var c := axis_point(joints, side, r)
	var need := 0.0
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var a: Vector3 = joints[side + "Hand" + f + "1"]
		var b: Vector3 = joints[side + "Hand" + f + "2"]
		for t in [0.5, 1.0]:
			var p := a.lerp(b, t)
			need = maxf(need, r + FINGER_HALF - _dist_to_axis(p, c, Vector3.BACK))
	return c - Vector3(0, need, 0)


## {bone: Quaternion} closing the hand on a handle of radius r: across the palm (axis_point), or along line - [a point
## on the handle's axis, its direction], in the rest (the joints' space) - when the handle is drawn where the game
## puts it (a hurley through the fist at its own angle): each finger curls till it touches that handle.
static func solve(joints: Dictionary, side: String, r: float, line := []) -> Dictionary:
	if not line.is_empty():
		# (Rounded: a line that moves a little each frame - a second hand on a handle - is solved once a few mm.)
		line = [(line[0] as Vector3).snapped(Vector3.ONE * 0.005), (line[1] as Vector3).normalized().snapped(Vector3.ONE * 0.05)]
	var key := "%s|%s|%.4f|%s" % [joints.hash(), side, r, line]
	if _cache.has(key):
		return _cache[key]
	var c := axis_point(joints, side, r) if line.is_empty() else line[0] as Vector3
	var d := Vector3.BACK if line.is_empty() else (line[1] as Vector3).normalized()
	var out := _close(joints, side, r, func(p: Vector3) -> float: return _dist_to_axis(p, c, d))
	_cache[key] = out
	return out


## A ball's centre (in the rest) for a hand holding a ball of radius r: under the palm where a handle's axis would
## be (axis_point), lowered just as far as it must for every finger's knuckle to be outside it. A big ball's centre
## at axis_point had the knuckles, which sit lower than the wrist, up to 2 cm inside it (no curl can lift a knuckle).
static func sphere_point(joints: Dictionary, side: String, r: float) -> Vector3:
	var c := axis_point(joints, side, r)
	var need := 0.0
	var rr := r + FINGER_HALF
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		# The centre moved down by t: |v + t up| = rr, the root that clears it.
		var v: Vector3 = (joints[side + "Hand" + f + "1"] as Vector3) - c
		var disc := v.y * v.y - v.length_squared() + rr * rr
		if v.length() < rr and disc > 0.0:
			need = maxf(need, -v.y + sqrt(disc))
	return c - Vector3(0, need, 0)


## {bone: Quaternion} closing the hand on a sphere of radius r (a ball) centred at centre (in the rest, the joints'
## space; by default sphere_point: the ball in the palm, clear of the knuckles). Each finger curls till it touches
## the ball itself, not a cylinder across the palm: a ball-sized handle (solve) let the index and little fingers lie
## inside or off the ball where it curves away at the palm's sides (Netball). Cached too.
##   body.grip_sphere("Right", 0.112)       # and the ball at body.ball_point("Right", 0.112)
static func solve_sphere(joints: Dictionary, side: String, r: float, centre := Vector3.INF) -> Dictionary:
	if centre != Vector3.INF:
		centre = centre.snapped(Vector3.ONE * 0.005)
	var key := "sphere|%s|%s|%.4f|%s" % [joints.hash(), side, r, centre]
	if _cache.has(key):
		return _cache[key]
	var c := sphere_point(joints, side, r) if centre == Vector3.INF else centre
	var out := _close(joints, side, r, func(p: Vector3) -> float: return p.distance_to(c), true)
	_cache[key] = out
	return out


## The fingers curled and the thumb brought round till they touch the surface dist measures (a point's distance from
## the handle's axis, or from the ball's centre), radius r.
## nearest: a finger that never touches it (too short, or too far off at the hand's side) stops where it comes
## nearest, not curled right in (a fist under a ball: the little finger of a hand on a netball).
static func _close(joints: Dictionary, side: String, r: float, dist: Callable, nearest := false) -> Dictionary:
	var s := 1.0 if side == "Left" else -1.0
	var out := {}
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var names := [side + "Hand" + f + "1", side + "Hand" + f + "2", side + "Hand" + f + "3"]
		var pts: Array = names.map(func(n): return joints[n])
		pts.append(pts[2] + (pts[2] - pts[1]).normalized() * (pts[2] - pts[1]).length() * 0.85)
		# Curl about the hand's width (z): toward the palm is -y.
		var axis := Vector3(0, 0, -s)
		for k in 3:
			var best := deg_to_rad(100.0)
			var near_a := 0.0
			var near_d := INF
			var touched := false
			for step in range(-30, 101, 2):
				var a := deg_to_rad(step)
				var q := Quaternion(axis, a)
				var hit := false
				for m in range(k + 1, 4):
					var p: Vector3 = pts[k] + q * (pts[m] - pts[k])
					# (And the middle of the bone before it: the joints can clear a handle the bone runs through.)
					var mid: Vector3 = pts[k] + q * ((pts[m] + pts[m - 1]) * 0.5 - pts[k])
					var dp: float = dist.call(p)
					var dm: float = dist.call(mid)
					if nearest and step >= 0 and minf(dp, dm) < near_d:
						near_d = minf(dp, dm)
						near_a = a
					if dp < r + FINGER_HALF or dm < r + FINGER_HALF:
						hit = true
						break
				if hit:
					best = a
					touched = true
					break
			if nearest and not touched:
				best = near_a
			var qk := Quaternion(axis, best)
			for m in range(k + 1, 4):
				pts[m] = pts[k] + qk * (pts[m] - pts[k])
			out[names[k]] = qk
		# (Every curl is about the same axis, so each joint's turn relative to its parent is its own curl.)
	# The thumb comes round the handle from the other side: turned in toward the fingers and curled - as far as the
	# handle lets it (a handle at its own angle can be where the thumb would tuck in: it opens, or lies along the
	# handle, till it is clear).
	var best_t := []
	var best_clear := -INF
	for spread in [-15.0, 5.0, 25.0, 45.0]:
		for turn in [35.0, 25.0, 15.0, 5.0, -5.0, -15.0, -25.0, -35.0, -45.0]:
			for curl in [1.0, 0.6, 0.3, 0.0]:
				var q := _thumb(s, turn, curl, spread)
				var clear := _thumb_clear_by(joints, side, q, dist) - r - FINGER_HALF
				if clear > best_clear:
					best_clear = clear
					best_t = q
				if clear >= 0.0:
					break
			if best_clear >= 0.0:
				break
		if best_clear >= 0.0:
			break
	out[side + "HandThumb1"] = best_t[0]
	out[side + "HandThumb2"] = best_t[1]
	out[side + "HandThumb3"] = best_t[2]
	return out


## The thumb's three turns: turned in (degrees) toward the fingers, curled (0-1 of its full curl), spread (degrees:
## -15 tucked toward the fingers; more lays it along the handle).
static func _thumb(s: float, turn: float, curl: float, spread := -15.0) -> Array:
	return [Quaternion(Vector3(s, 0, 0), deg_to_rad(turn)) * Quaternion(Vector3(0, s, 0), deg_to_rad(spread)),
		Quaternion(Vector3(0, 0, -s), deg_to_rad(30.0 * curl)), Quaternion(Vector3(0, 0, -s), deg_to_rad(25.0 * curl))]


## The least distance from the thumb (its joints, the middles between, its tip) to the handle's axis.
static func _thumb_clear(joints: Dictionary, side: String, q: Array, c: Vector3, d: Vector3) -> float:
	return _thumb_clear_by(joints, side, q, func(p: Vector3) -> float: return _dist_to_axis(p, c, d))


## The least of dist (a point's distance from the surface's axis or centre) over the thumb.
static func _thumb_clear_by(joints: Dictionary, side: String, q: Array, dist: Callable) -> float:
	var p1: Vector3 = joints[side + "HandThumb1"]
	var p2: Vector3 = joints[side + "HandThumb2"]
	var p3: Vector3 = joints[side + "HandThumb3"]
	var tip := p3 + (p3 - p2) * 0.85
	var g1: Quaternion = q[0]
	var g2: Quaternion = g1 * (q[1] as Quaternion)
	var g3: Quaternion = g2 * (q[2] as Quaternion)
	var a2 := p1 + g1 * (p2 - p1)
	var a3 := a2 + g2 * (p3 - p2)
	var at := a3 + g3 * (tip - p3)
	var least := INF
	for p in [a2, a3, at, (p1 + a2) * 0.5, (a2 + a3) * 0.5, (a3 + at) * 0.5]:
		least = minf(least, dist.call(p))
	return least


## Distance from p to the handle's axis (along d) through c.
static func _dist_to_axis(p: Vector3, c: Vector3, d: Vector3) -> float:
	var v := p - c
	return (v - d * v.dot(d)).length()
