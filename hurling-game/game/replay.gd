class_name Replay
extends RefCounted
## The last few seconds of play kept frame by frame (where everyone stood, which way they faced, their pose; the
## sliotar), and a wide shown again from a better seat: from behind the goal, looking back up the field at the
## strike, the posts in the picture and the ball going past them into the net behind. A little slower than life,
## about four seconds; a tap skips it. The match stands still meanwhile (its clock too) and goes on as it was.
## (Round three: "if a shot goes wide maybe a quick replay at a better angle showing the ball going wide"; round
## five: "I'm not seeing replays after scores, we should have them".)

const KEEP := 7.5         # seconds of play kept (a score's cut-aways come first: game/match.gd _score_package)
const BEFORE := 2.3       # seconds shown before the ball crossed the end line
const AFTER := 0.9        # and after: into the net and down
const SPEED := 0.75       # slower than life
const WB_SPEED := 0.4     # "watch it back": slow motion
const WB_OFFER := 4.0     # seconds the button stays after a score's replay

var m: Node
var playing := false
var _buf: Array = []      # [now, ball position, [[Player, position, yaw, pose], ...]] a frame
var _t := 0.0
var _t1 := 0.0
var _i := 0
var _saved: Array = []
var _ball_saved := Vector3.ZERO
var _cam: Camera3D
var _cut := false          # High: cut to the second angle yet
var _t0 := 0.0
var _side := 1.0
## "Watch it back" (the owner's one tap after a score): the score kept apart when its replay begins - this buffer's
## frames and the foundation's bodies' (WsgReplay.clip) - and offered for WB_OFFER seconds after; tapped, it plays
## twice in slow motion, from the scorer's side behind him and low on the touchline following the ball. Not on Low
## (a budget phone keeps no second copy).
var _clip := {}
var _wb := 0               # 0 the replay; 1 watch it back from the scorer's side; 2 its second angle
var _speed := SPEED
var _live_buf: Array = []


func _init(p_match: Node) -> void:
	m = p_match


## Keep this frame (every frame the match runs, live or dead).
func record() -> void:
	if playing:
		return
	var now: float = m.now
	var people := []
	for pl in m.all_players() + m.officials.people:
		var p: Player = pl
		if p.visible:
			people.append([p, p.position, p.body.rotation.y, p.body.pose])
	_buf.append([now, m.ball.global_position, people])
	if m.wsg_replay:
		m.wsg_replay.record(now)
	while _buf.size() > 2 and float(_buf[0][0]) < now - KEEP:
		_buf.pop_front()


## Show the score or wide that crossed the end line at s (+1 or -1 on x) at the match's time t_cross, at c.
func start(t_cross: float, s: float, c: Vector3, who: Player = null) -> void:
	if _buf.size() < 10:
		return
	playing = true
	_wb = 0
	_speed = SPEED
	_t = maxf(float(_buf[0][0]), t_cross - BEFORE)
	_t1 = minf(float(_buf[-1][0]), t_cross + AFTER)
	_i = 0
	_clip = {}
	if who != null and int(Game.settings.graphics) > Game.GFX_LOW:
		var frames := []
		for f in _buf:
			if float(f[0]) >= _t - 0.1 and float(f[0]) <= _t1 + 0.1:
				frames.append(f)
		_clip = {"buf": frames, "wsg": m.wsg_replay.clip(_t, _t1) if m.wsg_replay else [], "t0": _t, "t1": _t1,
			"s": s, "c": c, "who": who}
	# Everyone as they are now, to go back to.
	_saved = []
	for e in _buf[-1][2]:
		var p: Player = e[0]
		_saved.append([p, p.position, p.body.rotation.y, p.body.pose])
	_ball_saved = m.ball.global_position
	# The seat: behind the goal, a little to the side the ball went, high on the terrace, looking back up the field to
	# where the strike came from.
	var from: Vector3 = _frame_at(_t)[1]
	_cam = Camera3D.new()
	m.add_child(_cam)
	_cam.near = 0.3
	_cam.far = 900.0
	var side := clampf(c.z * 0.35, -9.0, 9.0)
	# (Above the heads of the fans on the terrace behind it, standing and cheering: 9.5 m up.)
	_cam.global_position = Vector3(s * (Pitch.HALF_L + 15.0), 9.5, side)
	var look := c.lerp(Vector3(from.x, 0.0, from.z), 0.45)
	_cam.look_at(Vector3(look.x, 1.6, look.z * 0.8))
	# Wide enough for the strike and the posts both.
	var span := Vector2(from.x - _cam.global_position.x, from.z - _cam.global_position.z).length()
	_cam.fov = clampf(30.0 + 900.0 / maxf(span, 20.0), 34.0, 58.0)
	_cam.make_current()
	_cut = false
	_t0 = _t
	_side = 1.0 if c.z >= 0.0 else -1.0
	if m.wsg_replay:
		m.wsg_replay.play(_t, _t1)    # (the foundation's bodies as they were drawn: they do not follow the game's here)
	Sfx.duck(6.0, (_t1 - _t) / SPEED)    # (the crowd under the replay, as a broadcast holds it)
	m.hud.replay(true, stop)
	m.controls.set_meta("was_visible", m.controls.visible)
	m.controls.visible = false


func _frame_at(t: float) -> Array:
	while _i < _buf.size() - 1 and float(_buf[_i + 1][0]) <= t:
		_i += 1
	return _buf[_i]


func step(delta: float) -> void:
	_t += minf(delta, 0.05) * _speed
	if _t >= _t1:
		if _wb == 1:
			# The second angle: low on the touchline, following the ball into the posts.
			_wb = 2
			_t = _t0
			_i = 0
			_cut = true
			_cam.fov = 28.0
			return
		stop()
		return
	var f := _frame_at(_t)
	m.ball.show_at(f[1])
	if Ultra.lit() or _wb == 2:
		_broadcast(f[1])
	for e in f[2]:
		_put(e)
	if m.wsg_replay:
		m.wsg_replay.seek(_t)
	m.hud.redraw_marks()


## High (on Vulkan): as television does, the second half of the replay from another camera: low on the touchline on the side
## the ball went, tight, following it into the posts.
func _broadcast(ball: Vector3) -> void:
	if not _cut and _t > lerpf(_t0, _t1, 0.45):
		_cut = true
		_cam.fov = 26.0
	if _cut:
		# (Between the touchline and the boards: further out is the stand, with its 3D fans.)
		var at := Vector3(clampf(ball.x * 0.85, -Pitch.HALF_L + 6.0, Pitch.HALF_L - 6.0), 3.2, _side * (Pitch.HALF_W + 2.5))
		# (Off anyone standing there - the linesman walks that line - along it, the nearer way.)
		for b in m.get_tree().get_nodes_in_group("wsg_bodies"):
			var bp: Vector3 = (b as Node3D).global_position
			if (b as Node3D).is_visible_in_tree() and Vector2(bp.x - at.x, bp.z - at.z).length() < 3.0:
				at.x = bp.x + (3.5 if at.x >= bp.x else -3.5)
		_cam.global_position = _cam.global_position.lerp(at, 0.2) if _cam.global_position.distance_to(at) < 30.0 else at
		_cam.look_at(ball.lerp(Vector3(ball.x, 1.2, ball.z), 0.5))


func _put(e: Array) -> void:
	var p: Player = e[0]
	if not is_instance_valid(p):
		return
	p.position = e[1]
	p.body.rotation.y = e[2]
	p.body.apply(e[3])


## Back to the match as it was (the replay's end, or a tap).
func stop() -> void:
	if not playing:
		return
	playing = false
	var was := _wb
	if _wb > 0:
		_buf = _live_buf
		_live_buf = []
		_wb = 0
		_speed = SPEED
	for e in _saved:
		_put(e)
	if m.wsg_replay:
		m.wsg_replay.stop()
	m.ball.show_at(_ball_saved)
	_saved = []
	if _cam != null:
		_cam.queue_free()
		_cam = null
	m.cam.camera.make_current()
	m.hud.replay(false, Callable())
	m.hud.redraw_marks()
	m.controls.visible = bool(m.controls.get_meta("was_visible", m.controls.visible))
	if was == 0 and not _clip.is_empty():
		m.hud.watch_back(true, watch_back)
		var clip := _clip
		m.get_tree().create_timer(WB_OFFER).timeout.connect(func():
			if _clip == clip:
				_clip = {}
				m.hud.watch_back(false, Callable()))


## The score shown again in slow motion (the button after its replay): from behind the scorer, then from the
## touchline. The match stands still meanwhile, as for any replay.
func watch_back() -> void:
	if _clip.is_empty() or playing:
		return
	var clip := _clip
	_clip = {}
	m.hud.watch_back(false, Callable())
	if (clip.buf as Array).size() < 4 or not is_instance_valid(clip.who):
		return
	var who: Player = clip.who
	_live_buf = _buf
	_buf = clip.buf
	playing = true
	_wb = 1
	_speed = WB_SPEED
	_t = clip.t0
	_t1 = clip.t1
	_t0 = _t
	_i = 0
	_cut = false
	_saved = []
	for e in _live_buf[-1][2]:
		var p: Player = e[0]
		_saved.append([p, p.position, p.body.rotation.y, p.body.pose])
	_ball_saved = m.ball.global_position
	# The scorer's side: behind him, a little up and off his shoulder, looking past him at the goal.
	var at: Vector3 = who.position
	for e in _frame_at(lerpf(_t, _t1, 0.25))[2]:
		if e[0] == who:
			at = e[1]
	_i = 0
	var c: Vector3 = clip.c
	var away := Vector3(at.x - c.x, 0, at.z - c.z).normalized()
	_side = 1.0 if c.z >= 0.0 else -1.0
	_cam = Camera3D.new()
	m.add_child(_cam)
	_cam.near = 0.3
	_cam.far = 900.0
	_cam.fov = 46.0
	_cam.global_position = at + away * 4.5 + away.cross(Vector3.UP) * 1.2 + Vector3(0, 2.3, 0)
	_cam.look_at(at.lerp(Vector3(c.x, 1.2, c.z), 0.35) + Vector3(0, 1.0, 0))
	_cam.make_current()
	if m.wsg_replay:
		m.wsg_replay.play(_t, _t1, clip.wsg)
	Sfx.duck(6.0, 2.0 * (_t1 - _t) / WB_SPEED)
	m.hud.replay(true, stop)
	m.controls.set_meta("was_visible", m.controls.visible)
	m.controls.visible = false
