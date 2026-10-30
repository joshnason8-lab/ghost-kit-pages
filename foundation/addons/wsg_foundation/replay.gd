class_name WsgReplay
extends Node
## The last few seconds of every foundation body as it was drawn - each bone's final turn (after the clips, the
## game's poses, the hands on the stick, the drivers and helpers) and where the body stood - kept in a ring and played
## back exactly, at any speed: a replay shows what the player saw, slowed down. Bodies join by themselves (WsgBody
## puts itself in the "wsg_bodies" group); the game feeds the clock.
##   var rp := WsgReplay.new(); add_child(rp)
##   rp.record(now)                   # every frame of live play (the game's own clock)
##   rp.play(t0, t1)                  # a replay of t0..t1 begins: the bodies stop following the game
##   rp.seek(t)                       # each frame of the replay (slower than life: the game's step)
##   rp.stop()                        # back to live play
## How much is kept is the profile's (WsgFoundation.replay_spec(): seconds and frames a second for the tier; a
## budget phone keeps 4 s at 15 a second: 1.3 MB for 38 bodies; a premium High 6 s at 30, 4 MB). A bone's turn is kept in 16 bits a number.

var seconds := 6.0
var rate := 30.0
var playing := false
## [time, {body instance id: PackedInt32Array}] oldest first.
var _frames: Array = []
var _latest := {}             # body id -> its last final pose (taken when it was drawn)
var _bodies := {}             # body id -> WsgBody
var _last_t := -INF
var _saved := {}              # body id -> [its transform, shown] before the replay


func _ready() -> void:
	var spec := WsgFoundation.replay_spec()
	seconds = spec[0]
	rate = spec[1]


## Keep this moment (call every frame of live play; frames come at the profile's rate).
func record(now: float) -> void:
	if playing or not is_inside_tree():
		return
	for b in get_tree().get_nodes_in_group("wsg_bodies"):
		var body := b as WsgBody
		var id := body.get_instance_id()
		if not _bodies.has(id):
			_bodies[id] = body
			body.posed.connect(_take.bind(id))
	if now - _last_t < 1.0 / rate - 0.001:
		return
	_last_t = now
	var snap := {}
	for id in _latest:
		if is_instance_valid(_bodies.get(id)) and (_bodies[id] as WsgBody).is_visible_in_tree():
			snap[id] = _latest[id]
	_frames.append([now, snap])
	while _frames.size() > 2 and float(_frames[0][0]) < now - seconds:
		_frames.pop_front()


## The times kept: [first, last] (empty: nothing yet).
func span() -> Array:
	return [] if _frames.is_empty() else [_frames[0][0], _frames[-1][0]]


## A body's final pose as it is drawn (its skeleton's update, after every modifier): kept until the next frame.
func _take(id: int) -> void:
	if playing:
		return
	var body: WsgBody = _bodies.get(id)
	if not is_instance_valid(body):
		return
	var sk := body.skeleton
	var n := sk.get_bone_count()
	var out := PackedInt32Array()
	out.resize(12 + 3 + n * 2)
	var xf := body.global_transform
	var k := 0
	for v in [xf.basis.x, xf.basis.y, xf.basis.z, xf.origin]:
		for c in 3:
			out[k] = _f(v[c])
			k += 1
	var hips := sk.get_bone_pose_position(0)
	for c in 3:
		out[k] = _f(hips[c])
		k += 1
	for i in n:
		var q := sk.get_bone_pose_rotation(i)
		out[k] = _pack(q.x, q.y)
		out[k + 1] = _pack(q.z, q.w)
		k += 2
	_latest[id] = out


## Replay t0..t1: the bodies stop following the game and show what was kept.
func play(t0: float, t1: float) -> void:
	if _frames.is_empty():
		return
	playing = true
	_saved.clear()
	for id in _bodies:
		var body: WsgBody = _bodies[id]
		if not is_instance_valid(body):
			continue
		_saved[id] = [body.transform, body.visible]
		var m := _modifier(body)
		m.active = true
	seek(t0)


## Show the moment t (between two kept frames, blended).
func seek(t: float) -> void:
	if not playing or _frames.is_empty():
		return
	var i := 0
	while i < _frames.size() - 1 and float(_frames[i + 1][0]) <= t:
		i += 1
	var a: Array = _frames[i]
	var b: Array = _frames[mini(i + 1, _frames.size() - 1)]
	var w := 0.0 if b == a else clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	for id in _bodies:
		var body: WsgBody = _bodies[id]
		if not is_instance_valid(body):
			continue
		var pa: Variant = (a[1] as Dictionary).get(id)
		var pb: Variant = (b[1] as Dictionary).get(id, pa)
		body.visible = pa != null
		if pa == null:
			continue
		var m := _modifier(body)
		m.set_frames(pa, pb, w)
		body.global_transform = _xf(pa).interpolate_with(_xf(pb), w)


## Back to live play: the bodies where they were, following the game again.
func stop() -> void:
	if not playing:
		return
	playing = false
	for id in _bodies:
		var body: WsgBody = _bodies[id]
		if not is_instance_valid(body):
			continue
		_modifier(body).active = false
		if _saved.has(id):
			body.transform = _saved[id][0]
			body.visible = _saved[id][1]
	_saved.clear()


## Bytes kept now (the ring's size).
func memory() -> int:
	var total := 0
	for f in _frames:
		for id in f[1]:
			total += (f[1][id] as PackedInt32Array).size() * 4
	return total


func _modifier(body: WsgBody) -> WsgReplayPose:
	for c in body.skeleton.get_children():
		if c is WsgReplayPose:
			return c
	var m := WsgReplayPose.new()
	m.name = "Replay"
	m.active = false
	body.skeleton.add_child(m)   # (last: after the drivers and helpers, it has the final word)
	return m


static func _f(x: float) -> int:
	return int(round(x * 10000.0))


static func _pack(a: float, b: float) -> int:
	return (int(round(clampf(a, -1.0, 1.0) * 32767.0)) & 0xFFFF) | ((int(round(clampf(b, -1.0, 1.0) * 32767.0)) & 0xFFFF) << 16)


static func _xf(p: PackedInt32Array) -> Transform3D:
	var v := func(k: int) -> Vector3: return Vector3(p[k], p[k + 1], p[k + 2]) / 10000.0
	return Transform3D(Basis(v.call(0), v.call(3), v.call(6)), v.call(9))
