class_name AutoGfx
extends RefCounted
## "Lower it by itself if a match runs slowly": watches every frame of a match in windows of WINDOW seconds. A window
## is bad when its frames come slower than min_fps on average, or when HITCHES of them stall (over HITCH_K times the
## window's middle frame and over HITCH_MS): a phone that averages 50 a second but stalls for a tenth of a second
## twice a second stutters as badly as one at 25. BAD_WINDOWS bad windows in a row: a level down (the match applies
## it, Match.lower_graphics) and then reset() - nothing for SETTLE seconds while the new level's first frames draw.
## (It watched only the first ten seconds of play and only the average; the owner's Galaxy A16 stuttered on High
## and nothing dropped.)

const WINDOW := 1.5
const BAD_WINDOWS := 2
const HITCHES := 3
const HITCH_K := 2.5
const HITCH_MS := 45.0
const SETTLE := 2.0

## Slower than this on average is bad: 36 a second, or a little under the frame cap when that is lower (Battery
## saver's 30 is not a stutter).
var min_fps := 36.0
var _frames := PackedFloat32Array()
var _t := 0.0
var _bad := 0
var _settle := SETTLE
## The last window: [frames a second, hitches, bad windows in a row] (for the log and the tests).
var last := [0.0, 0, 0]


## For a frame cap of cap a second (0: none, the screen's rate).
func _init(cap := 0) -> void:
	if cap > 0:
		min_fps = minf(min_fps, cap * 0.8)


func reset() -> void:
	_frames.clear()
	_t = 0.0
	_bad = 0
	_settle = SETTLE


## One frame's time (s). True when the level should come down now.
func feed(delta: float) -> bool:
	if _settle > 0.0:
		_settle -= delta
		return false
	_frames.append(delta * 1000.0)
	_t += delta
	if _t < WINDOW:
		return false
	var s := _frames.duplicate()
	s.sort()
	var limit := maxf(s[s.size() / 2] * HITCH_K, HITCH_MS)
	var hitches := 0
	for ms in _frames:
		if ms > limit:
			hitches += 1
	var fps := _frames.size() / _t
	_bad = _bad + 1 if fps < min_fps or hitches >= HITCHES else 0
	last = [fps, hitches, _bad]
	_frames.clear()
	_t = 0.0
	if _bad >= BAD_WINDOWS:
		_bad = 0
		return true
	return false
