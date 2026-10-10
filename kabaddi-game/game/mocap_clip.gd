class_name MocapClip
extends RefCounted
## Joint-angle animation captured from real footage (tools/mocap/to_clip.py).
## Put clips in res://assets/mocap/<name>.json and the placeholder athletes play them
## for that move instead of the hand-made animation.

# Athlete state -> clip name, and whether the clip loops.
const FOR_STATE := {
	"dive": ["tackle_dive", false],
	"held": ["struggle", true],
	"touch": ["hand_touch", false],
	"kick": ["toe_touch", false],
	"ready": ["defend_idle", true],
	"raid": ["raid_idle", true],
	"holding": ["hold", true],
	"celebrate": ["celebrate", true],
}
const DIR := "res://assets/mocap"

var name := ""
var length := 0.0
var frames: Array = []

static var _library := {}
static var _scanned := false


static func for_state(state: String):
	if not _scanned:
		_scan()
	if not FOR_STATE.has(state):
		return null
	return _library.get(FOR_STATE[state][0], null)


static func loops(state: String) -> bool:
	return FOR_STATE.has(state) and bool(FOR_STATE[state][1])


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
	c.frames = parsed.frames
	c.length = float(parsed.get("length", float(c.frames[-1].t)))
	return c


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
