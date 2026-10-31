class_name MocapClip
extends RefCounted
## Captured animation the athletes play instead of the hand-made pose. Two kinds:
## - version 1, joint angles from match footage (tools/mocap/to_clip.py): one bend per joint;
## - version 2, full 3D joint rotations from Mixamo or Meshy animations or the CMU motion capture library
##   (tools/mocap/fbx_to_clip.gd).
## Put clips in res://assets/mocap/<name>.json. A clip named in FOR_STATE plays for that move; clips named
## move_* are the running set (run, jog, walk, strafes, backpedal, crouched shuffle and walks), played whenever a
## player moves the way and about the speed they were captured at, at the rate that keeps the feet planted.

## Athlete state -> which clips can play for it (every clip whose name starts so; each player gets his own
## pick) and how: "loop" round and round, "fit" stretched over the move's length in the game, "once" at its
## own speed, holding the last pose.
const FOR_STATE := {
	"ready": ["ready_", "loop"],
	"raid": ["raid_", "loop"],
	"idle": ["idle_", "loop"],
	"touch": ["touch_", "fit"],
	"kick": ["kick_", "fit"],
	"backkick": ["backkick_", "fit"],
	"dodge": ["dodge_", "fit"],
	"evade": ["evade_", "fit"],
	"dubki": ["dubki_", "fit"],
	"jump": ["jump_", "fit"],
	"dive": ["dive_", "fit"],
	"held": ["held_", "loop"],
	"fallen": ["fall_", "once"],
	"recover": ["getup_", "fit"],
	"celebrate": ["cele_", "loop"],
	"slump": ["slump_", "once"],
}
const DIR := "res://assets/mocap"
## The game's plain skeleton for a 1.78 m player, as HumanModel builds it: the pelvis' joint over the floor, each hip
## off it, and the thigh and shin, for working out where a clip puts the feet (foot_speed).
const HIP_H := 0.98
const HIP := Vector3(0.1, -0.04, 0.0)
const LEG := 0.44

var name := ""
var length := 0.0
var frames: Array = []
var version := 1
var joints := PackedStringArray()     # version 2: the joints, in the order of each frame's rotations
var times := PackedFloat32Array()
var heights := PackedFloat32Array()    # hips' height against standing, per frame
var airs := PackedFloat32Array()       # how high the body's lowest point is off the floor (m, 1.78 m player)
var quats: Array[PackedFloat32Array] = []   # per frame: x, y, z, w for each joint
var speed := 0.0                       # m/s a 1.78 m player travels at in this clip (0: on the spot)
var dir := Vector2.ZERO                # which way: x to his right, y forward
var low := false                       # crouched all through (a defender's shuffle, a crouched walk)
var arms := "both"                     # "r": only the right arm is the clip's, the left keeps the game's pose

var _landing := -2.0                   # see landing()
var _takeoff := -2.0                   # see takeoff()
var _ducked := -2.0                    # see ducked()
var _stride := -2.0                    # see stride()

static var _library := {}
static var _scanned := false
static var _to_read := PackedStringArray()   # files still to read (scan_step)
static var _to_read_total := 0


## The running set: clips named move_*, each travelling some way at some speed.
static func moves() -> Array:
	if not _scanned:
		_scan()
	var out := []
	for c in _library.values():
		if (c as MocapClip).name.begins_with("move_") and (c as MocapClip).speed > 0.2:
			out.append(c)
	return out


## The clips that can play for a state; variant narrows them (a celebration's kind, a dodge's side).
static func options(state: String, variant := "") -> Array:
	if not _scanned:
		_scan()
	if not FOR_STATE.has(state):
		return []
	var prefix: String = FOR_STATE[state][0]
	var out := []
	var narrowed := []
	for c in _library.values():
		var n: String = (c as MocapClip).name
		if n.begins_with(prefix) and not n.begins_with("move_"):
			out.append(c)
			if variant != "" and n.begins_with(prefix + variant):
				narrowed.append(c)
	if state in ["celebrate", "dive"]:
		return narrowed   # only the kind asked for: a celebration's, a tackle's
	return narrowed if not narrowed.is_empty() else out


## "loop", "fit" or "once" (see FOR_STATE).
static func how(state: String) -> String:
	return String(FOR_STATE[state][1]) if FOR_STATE.has(state) else "loop"


static func _scan() -> void:
	while scan_step():
		pass


## Reads the next clip into the library, so the loading screen can read them a few at a time: false once they
## are all in.
static func scan_step() -> bool:
	if _scanned:
		return false
	if _to_read.is_empty() and _to_read_total == 0:
		var d := DirAccess.open(DIR)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".json"):
					_to_read.append(f)
		_to_read_total = maxi(1, _to_read.size())
	if _to_read.is_empty():
		_scanned = true
		return false
	var c := load_file(DIR.path_join(_to_read[0]))
	_to_read.remove_at(0)
	if c:
		_library[c.name] = c
	return true


## How much of the library is read, 0..1 (scan_step).
static func scan_progress() -> float:
	if _scanned:
		return 1.0
	if _to_read_total == 0:
		return 0.0
	return 1.0 - float(_to_read.size()) / float(_to_read_total)


static func load_file(path: String) -> MocapClip:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("frames") or parsed.frames.is_empty():
		return null
	var c := MocapClip.new()
	c.name = String(parsed.get("name", path.get_file().get_basename()))
	c.version = int(parsed.get("version", 1))
	if c.version >= 2:
		c.joints = PackedStringArray(parsed.joints)
		for f in parsed.frames:
			c.times.append(float(f.t))
			c.heights.append(float(f.h))
			c.airs.append(float(f.get("a", 0.0)))
			c.quats.append(PackedFloat32Array(f.q))
		c.speed = float(parsed.get("speed", 0.0))
		var d: Array = parsed.get("dir", [0, 0])
		c.dir = Vector2(float(d[0]), float(d[1]))
		# Crouched by its hips, or by its own say (a crouched walk's hips bob up past the shuffle's).
		c.low = bool(parsed.get("low", false)) or float(parsed.get("h_max", 1.0)) < 0.9
		c.arms = String(parsed.get("arms", "both"))
	else:
		c.frames = parsed.frames
	c.length = float(parsed.get("length", float(parsed.frames[-1].t)))
	return c


## Where in its loop (0..1) a running clip has the left leg furthest out the way it travels: about when that foot
## comes down. The clips do not start at the same point of the stride (a jog with the left leg out at 0.12, the run
## at 0.19, the walk at 0.29, running backward at 0.32-0.38), so a switch from one to another is made at the same
## point of the stride by this, not at the same fraction of the loop: that put the legs up to a fifth of a stride
## out of step with themselves through the cross-fade, one passing through the other.
func stride() -> float:
	if _stride > -2.0:
		return _stride
	_stride = 0.0
	var pi := joints.find("pelvis")
	var li := joints.find("hip_l")
	var ri := joints.find("hip_r")
	if version < 2 or quats.is_empty() or pi < 0 or li < 0 or ri < 0 or dir.length() < 0.1:
		return _stride
	var way := Vector3(dir.x, 0.0, -dir.y).normalized()
	var best := -INF
	for k in quats.size():
		var f: PackedFloat32Array = quats[k]
		var pel := Quaternion(f[pi * 4], f[pi * 4 + 1], f[pi * 4 + 2], f[pi * 4 + 3])
		var l := (pel * Quaternion(f[li * 4], f[li * 4 + 1], f[li * 4 + 2], f[li * 4 + 3])) * Vector3.DOWN
		var r := (pel * Quaternion(f[ri * 4], f[ri * 4 + 1], f[ri * 4 + 2], f[ri * 4 + 3])) * Vector3.DOWN
		var ahead := (l - r).dot(way)
		if ahead > best:
			best = ahead
			_stride = float(k) / float(quats.size())
	return _stride


## A travelling clip on the game's own skeleton: how fast a foot on the floor goes back under the body (m/s for a
## 1.78 m player, along the way the clip goes), which is the speed that holds the feet still as the game plays it;
## and how fast a foot on the floor slides about at the clip's own speed (the median, m/s). A clip turns each joint
## as its source did, but the source's proportions are not the game's (the CMU subjects' legs are longer for their height),
## so the stride, and the speed it carries the body at, is measured here. Zero for a clip that does not travel.
func foot_speed() -> Vector2:
	var n := quats.size()
	if version < 2 or n < 3 or dir.length() < 0.1:
		return Vector2.ZERO
	var way := Vector3(dir.x, 0.0, -dir.y).normalized()
	var at := []
	var lo := [INF, INF]
	for k in n:
		var f := feet(k)
		at.append(f)
		lo[0] = minf(lo[0], (f[0] as Vector3).y)
		lo[1] = minf(lo[1], (f[1] as Vector3).y)
	# Frame to frame, and round from the last to the first for a loop.
	var pairs := []
	for k in n - 1:
		pairs.append([k, k + 1, times[k + 1] - times[k]])
	if length - times[n - 1] > 0.001:
		pairs.append([n - 1, 0, length - times[n - 1]])
	var back := []
	var moved := []
	for pr in pairs:
		for s in 2:
			var a: Vector3 = at[pr[0]][s]
			var b: Vector3 = at[pr[1]][s]
			if a.y < lo[s] + 0.025 and b.y < lo[s] + 0.025 and float(pr[2]) > 0.0:
				back.append(-(b - a).dot(way) / float(pr[2]))
				moved.append([b - a, float(pr[2])])
	if back.is_empty():
		return Vector2.ZERO
	back.sort()
	var slides := []
	for m in moved:
		var d: Vector3 = (m[0] as Vector3) + way * speed * float(m[1])
		slides.append(Vector2(d.x, d.z).length() / float(m[1]))
	slides.sort()
	return Vector2(back[back.size() / 2], slides[slides.size() / 2])


## Where frame k of a version 2 clip puts the feet (the ankles) on the game's plain skeleton for a 1.78 m player,
## from the spot under his pelvis: [left, right].
func feet(k: int) -> Array:
	var f: PackedFloat32Array = quats[k]
	var rot := func(j: String) -> Quaternion:
		var i := joints.find(j) * 4
		return Quaternion(f[i], f[i + 1], f[i + 2], f[i + 3]).normalized()
	var pel: Quaternion = rot.call("pelvis")
	var out := []
	for side in ["l", "r"]:
		var hip: Quaternion = pel * rot.call("hip_" + side)
		var knee: Quaternion = hip * rot.call("kn_" + side)
		var x := -HIP.x if side == "l" else HIP.x
		out.append(Vector3(0.0, HIP_H * heights[k], 0.0) + pel * Vector3(x, HIP.y, 0.0) + hip * Vector3(0.0, -LEG, 0.0)
			+ knee * Vector3(0.0, -LEG, 0.0))
	return out


## When a fall reaches the floor (s): the first frame its hips are within 0.04 of their lowest. -1 for a clip
## that does not come down (it starts on the floor, or never gets low).
func landing() -> float:
	if _landing > -2.0:
		return _landing
	_landing = -1.0
	if version < 2 or heights.is_empty():
		return _landing
	var lo := INF
	for h in heights:
		lo = minf(lo, h)
	if heights[0] - lo < 0.3:
		return _landing
	for i in heights.size():
		if heights[i] <= lo + 0.04:
			_landing = times[i]
			break
	return _landing


## When a jump leaves the floor (s): the first frame the body's lowest point is more than 3 cm off it. -1 for a
## clip that never leaves it, or starts off it.
func takeoff() -> float:
	if _takeoff > -2.0:
		return _takeoff
	_takeoff = -1.0
	if version < 2 or airs.is_empty() or airs[0] > 0.03:
		return _takeoff
	for i in airs.size():
		if airs[i] > 0.03:
			_takeoff = times[i]
			break
	return _takeoff


## When a duck is down (s): the first frame its hips are within 0.02 of their lowest (a dubki under the arms
## round him). -1 for a clip that does not go down.
func ducked() -> float:
	if _ducked > -2.0:
		return _ducked
	_ducked = -1.0
	if version < 2 or heights.is_empty():
		return _ducked
	var lo := INF
	for h in heights:
		lo = minf(lo, h)
	if heights[0] - lo < 0.08:
		return _ducked
	for i in heights.size():
		if heights[i] <= lo + 0.02:
			_ducked = times[i]
			break
	return _ducked


## Version 2: the pose at time t: {"h": hips' height against standing, "a": the body's lowest point off the
## floor, joint name: Quaternion}.
func sample_pose(t: float, loop: bool) -> Dictionary:
	var n := times.size()
	t = fposmod(t, length) if loop and length > 0.0 else clampf(t, 0.0, length)
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if times[mid] <= t:
			lo = mid
		else:
			hi = mid
	var k := 0.0
	if loop and t > times[n - 1]:
		# Between the last frame and the first, round the loop.
		lo = n - 1
		hi = 0
		k = clampf((t - times[n - 1]) / maxf(length - times[n - 1], 0.0001), 0.0, 1.0)
	elif times[hi] > times[lo]:
		k = clampf((t - times[lo]) / (times[hi] - times[lo]), 0.0, 1.0)
	var a := quats[lo]
	var b := quats[hi]
	var out := {"h": lerpf(heights[lo], heights[hi], k), "a": lerpf(airs[lo], airs[hi], k)}
	for j in joints.size():
		var i := j * 4
		var qa := Quaternion(a[i], a[i + 1], a[i + 2], a[i + 3]).normalized()
		var qb := Quaternion(b[i], b[i + 1], b[i + 2], b[i + 3]).normalized()
		out[joints[j]] = qa.slerp(qb, k)
	return out


## Joint values at time t (seconds), interpolated between captured frames.
func sample(t: float, loop: bool) -> Dictionary:
	if length <= 0.0:
		return frames[0]
	t = fposmod(t, length) if loop else clampf(t, 0.0, length)
	var lo := 0
	var hi := frames.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(frames[mid].t) <= t:
			lo = mid
		else:
			hi = mid
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	var span := float(b.t) - float(a.t)
	var k := 0.0 if span <= 0.0 else clampf((t - float(a.t)) / span, 0.0, 1.0)
	var out := {}
	for key in a.keys():
		if key != "t" and b.has(key):
			out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out
