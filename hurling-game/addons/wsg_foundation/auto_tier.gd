class_name WsgAutoTier
extends RefCounted
## "Lower the graphics by itself": watches a match's frames and says when to step the tier down - within a few
## seconds of sustained stutter, whether the frames are slow on average or mostly fine with hitches between (a phone
## that averages 50 a second but stalls for a tenth of a second twice a second stutters as badly as one at 25). The
## game applies the step (WsgFoundation.tier and whatever it builds from it) and calls reset().
##   var auto := WsgAutoTier.new()
##   if auto.feed(delta) and tier > WsgFoundation.LOW: (lower it); auto.reset()
## Windows of WINDOW seconds: a window is bad when its frames average under min_fps, or when HITCHES of them take
## over HITCH_K times its middle frame (and at least HITCH_MS). BAD_WINDOWS bad windows in a row: step down. Not in
## the first SETTLE seconds after a reset (loading, the first draws compiling their shaders).

const WINDOW := 1.5
const BAD_WINDOWS := 2
const HITCHES := 3
const HITCH_K := 2.5
const HITCH_MS := 45.0
const SETTLE := 2.0

var min_fps := 36.0
var _frames := PackedFloat32Array()
var _t := 0.0
var _bad := 0
var _settle := SETTLE
## The last window's numbers, for a log: [average fps, hitches, bad windows in a row].
var last := [0.0, 0, 0]


func reset() -> void:
	_frames.clear()
	_t = 0.0
	_bad = 0
	_settle = SETTLE


## One frame's time (s). True when the tier should step down now.
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
	var mid := s[s.size() / 2]
	var limit := maxf(mid * HITCH_K, HITCH_MS)
	var hitches := 0
	for ms in _frames:
		if ms > limit:
			hitches += 1
	var fps := _frames.size() / _t
	var bad := fps < min_fps or hitches >= HITCHES
	_bad = _bad + 1 if bad else 0
	last = [fps, hitches, _bad]
	_frames.clear()
	_t = 0.0
	if _bad >= BAD_WINDOWS:
		_bad = 0
		return true
	return false
