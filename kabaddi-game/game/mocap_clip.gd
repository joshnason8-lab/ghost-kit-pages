class_name MocapClip
extends RefCounted
## Captured animation the athletes play instead of the hand-made pose. Two kinds:
## - version 1, joint angles from match footage (tools/mocap/to_clip.py): one bend per joint;
## - version 2, full 3D joint rotations from Mixamo or Meshy animations (tools/mocap/fbx_to_clip.gd).
## Put clips in res://assets/mocap/<name>.json. A clip named in FOR_STATE plays for that move; clips named
## move_* are the running set (run, jog, walk, strafes, backpedal), played whenever a player moves the way
## and about the speed they were captured at, at the rate that keeps the feet planted.

## Athlete state -> which clips can play for it (every clip whose name starts so; each player gets his own
## pick) and how: "loop" round and round, "fit" stretched over the move's length in the game, "once" at its
## own speed, holding the last pose.
const FOR_STATE := {
	"ready": ["ready_", "loop"],
	"raid": ["raid_", "loop"],
	"idle": ["idle_", "loop"],
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

var name := ""
var length := 0.0
var frames: Array = []
var version := 1
var joints := PackedStringArray()     # version 2: the joints, in the order of each frame's rotations
var times := PackedFloat32Array()
var heights := PackedFloat32Array()    # hips' height against standing, per frame
var quats: Array[PackedFloat32Array] = []   # per frame: x, y, z, w for each joint
var speed := 0.0                       # m/s a 1.78 m player travels at in this clip (0: on the spot)
var dir := Vector2.ZERO                # which way: x to his right, y forward
var low := false                       # crouched all through (a defender's shuffle)

static var _library := {}
static var _scanned := false


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
	_scanned = true
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".json"):
			var c := load_file(DIR.path_join(f))
			if c:
				_library[c.name] = c


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
			c.quats.append(PackedFloat32Array(f.q))
		c.speed = float(parsed.get("speed", 0.0))
		var d: Array = parsed.get("dir", [0, 0])
		c.dir = Vector2(float(d[0]), float(d[1]))
		c.low = float(parsed.get("h_max", 1.0)) < 0.9
	else:
		c.frames = parsed.frames
	c.length = float(parsed.get("length", float(parsed.frames[-1].t)))
	return c


## Version 2: the pose at time t: {"h": hips' height against standing, joint name: Quaternion}.
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
	var out := {"h": lerpf(heights[lo], heights[hi], k)}
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
