class_name Mocap
## Walking and running from real people: stride cycles from the CMU motion capture database (mocap.cs.cmu.edu),
## turned onto the game's skeleton by tools/mocap/bvh_to_clip.py and kept in assets/mocap/ (one cycle each, 30 frames
## a second, a quaternion per bone and the hips' offset). Each cycle starts as the left foot reaches its farthest
## forward, so cycles of different speeds blend at the same phase, and its feet are held still on the floor while
## they are down: advanced by the ground covered (game/player.gd), they do not slide. The clips move on the spot; the
## game's movement alone moves a player.

## The cycles by speed: the speed (m/s) each was captured at is in the file.
const GAITS := ["walk", "jog", "run"]

static var _clips := {}


## A cycle: {stride (m a cycle), speed (m/s), lean (the trunk's, degrees), bones (names), frames (Array of
## PackedFloat32Array), source}, or {} if missing.
static func clip(name: String) -> Dictionary:
	if _clips.has(name):
		return _clips[name]
	var c := {}
	var f := FileAccess.open("res://assets/mocap/%s.json" % name, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			var frames: Array[PackedFloat32Array] = []
			for row in d.frames:
				frames.append(PackedFloat32Array(row))
			c = {"stride": float(d.stride), "speed": float(d.speed), "lean": float(d.get("lean", 0.0)), "contacts": d.get("contacts", {}), "bones": d.bones, "frames": frames,
				"source": String(d.get("source", ""))}
	_clips[name] = c
	return c


static func available() -> bool:
	for g in GAITS:
		if clip(g).is_empty():
			return false
	return true


## The two cycles to blend at a speed and the weight of the second: [a, b, w].
static func gaits_at(speed: float) -> Array:
	var lo := clip(GAITS[0])
	for i in range(1, GAITS.size()):
		var hi := clip(GAITS[i])
		if speed <= hi.speed:
			return [lo, hi, clampf((speed - lo.speed) / (hi.speed - lo.speed), 0.0, 1.0)]
		lo = hi
	return [lo, lo, 0.0]


## The pose of a cycle at a phase (0..1): bone name -> Quaternion, and "hips_off" (Vector3, m).
static func sample(c: Dictionary, phase: float) -> Dictionary:
	var frames: Array = c.frames
	var n := frames.size()
	var fi := fposmod(phase, 1.0) * n
	var a: PackedFloat32Array = frames[int(fi) % n]
	var b: PackedFloat32Array = frames[(int(fi) + 1) % n]
	var u := fi - floorf(fi)
	var out := {"hips_off": Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), u)}
	var bones: Array = c.bones
	for i in bones.size():
		var k := 3 + i * 4
		var qa := Quaternion(a[k], a[k + 1], a[k + 2], a[k + 3])
		var qb := Quaternion(b[k], b[k + 1], b[k + 2], b[k + 3])
		out[bones[i]] = qa.normalized().slerp(qb.normalized(), u)
	return out


## Whether a foot ("l" or "r") is down on the floor at a phase of a cycle (its feet are held still while down).
static func down(c: Dictionary, side: String, phase: float) -> bool:
	var n: int = c.frames.size()
	var f := fposmod(phase, 1.0) * n
	for w in c.contacts.get(side, []):
		var a := float(w[0])
		var b := float(w[1])
		if b < a:
			b += n
		if (f >= a and f <= b) or (f + n >= a and f + n <= b):
			return true
	return false


## Two poses blended (w the weight of b).
static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var out := {}
	for k in a:
		if k == "hips_off":
			out[k] = (a[k] as Vector3).lerp(b[k], w)
		else:
			out[k] = (a[k] as Quaternion).slerp(b[k], w)
	return out
