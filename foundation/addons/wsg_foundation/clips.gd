class_name WsgClips
extends RefCounted
## The motion-capture library, if this build has it: addons/wsg_foundation/data/mobility.res (+ .json), baked by
## tools/bake_clips.gd from the licensed MoCap Online clips at build time (tools/fetch_assets.sh). A build without it
## (a fork, a computer without the private assets) has WsgClips.available() false, and every game keeps its own
## animation.
##
## Clip names are Mobility's without "MOB1_"/"_IPC": "Run_F_Loop", "Stand_Relaxed_To_Jog_L90_Fwd",
## "Jog_R_180", "Walk_F_To_Stand_Relaxed_LU"... Loops are one second long (one gait cycle from the left foot's landing);
## meta(name) has their natural cycle, speed, stride, direction, and each foot's contacts.

const DIR := "res://addons/wsg_foundation/data/"
const LIB := "mob"

static var _lib: AnimationLibrary
static var _meta := {}
static var _tried := false


static func available() -> bool:
	_load()
	return _lib != null


static func library() -> AnimationLibrary:
	_load()
	return _lib


static func has(name: String) -> bool:
	_load()
	return _meta.has(name)


static func meta(name: String) -> Dictionary:
	_load()
	return _meta.get(name, {})


static func names() -> Array:
	_load()
	return _meta.keys()


static func _load() -> void:
	if _tried:
		return
	_tried = true
	if not ResourceLoader.exists(DIR + "mobility.res"):
		return
	_lib = load(DIR + "mobility.res")
	var j = JSON.parse_string(FileAccess.get_file_as_string(DIR + "mobility.json"))
	if j is Dictionary:
		_meta = j.get("clips", {})


## Is that foot (0 left, 1 right) on the ground at fraction t (0..1) of the clip?
static func contact(name: String, foot: int, t: float) -> bool:
	var m := meta(name)
	if m.is_empty():
		return false
	for r: Array in m.contacts[foot]:
		if t >= r[0] and t < r[1]:
			return true
	return false


## How far through the current contact or swing that foot is (0..1), and whether it is down: [down, through].
static func foot_phase(name: String, foot: int, t: float) -> Array:
	var m := meta(name)
	if m.is_empty():
		return [false, 0.0]
	var rs: Array = m.contacts[foot]
	for r: Array in rs:
		if t >= r[0] and t < r[1]:
			return [true, (t - r[0]) / maxf(0.001, r[1] - r[0])]
	return [false, 0.0]
