class_name Replay
extends RefCounted
## The last few seconds of play kept frame by frame (where everyone stood, which way they faced, their pose; the
## sliotar), and a wide shown again from a better seat: from behind the goal, looking back up the field at the
## strike, the posts in the picture and the ball going past them into the net behind. A little slower than life,
## about four seconds; a tap skips it. The match stands still meanwhile (its clock too) and goes on as it was.
## (Round three: "if a shot goes wide maybe a quick replay at a better angle showing the ball going wide".)

const KEEP := 4.0         # seconds of play kept
const BEFORE := 2.3       # seconds shown before the ball crossed the end line
const AFTER := 0.9        # and after: into the net and down
const SPEED := 0.75       # slower than life

var m: Node
var playing := false
var _buf: Array = []      # [now, ball position, [[Player, position, yaw, pose], ...]] a frame
var _t := 0.0
var _t1 := 0.0
var _i := 0
var _saved: Array = []
var _ball_saved := Vector3.ZERO
var _cam: Camera3D


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
	while _buf.size() > 2 and float(_buf[0][0]) < now - KEEP:
		_buf.pop_front()


## Show the wide that crossed the end line at s (+1 or -1 on x) at the match's time t_cross, at c.
func start(t_cross: float, s: float, c: Vector3) -> void:
	if _buf.size() < 10:
		return
	playing = true
	_t = maxf(float(_buf[0][0]), t_cross - BEFORE)
	_t1 = minf(float(_buf[-1][0]), t_cross + AFTER)
	_i = 0
	# Everyone as they are now, to go back to.
	_saved = []
	for e in _buf[-1][2]:
		var p: Player = e[0]
		_saved.append([p, p.position, p.body.rotation.y, p.body.pose])
	_ball_saved = m.ball.global_position
	# The seat: behind the goal, a little to the side the ball went, up on the terrace, looking back up the field to
	# where the strike came from.
	var from: Vector3 = _frame_at(_t)[1]
	_cam = Camera3D.new()
	m.add_child(_cam)
	_cam.near = 0.3
	_cam.far = 900.0
	var side := clampf(c.z * 0.35, -9.0, 9.0)
	_cam.global_position = Vector3(s * (Pitch.HALF_L + 15.0), 6.0, side)
	var look := c.lerp(Vector3(from.x, 0.0, from.z), 0.45)
	_cam.look_at(Vector3(look.x, 1.6, look.z * 0.8))
	# Wide enough for the strike and the posts both.
	var span := Vector2(from.x - _cam.global_position.x, from.z - _cam.global_position.z).length()
	_cam.fov = clampf(30.0 + 900.0 / maxf(span, 20.0), 34.0, 58.0)
	_cam.make_current()
	m.hud.replay(true, stop)
	m.controls.set_meta("was_visible", m.controls.visible)
	m.controls.visible = false


func _frame_at(t: float) -> Array:
	while _i < _buf.size() - 1 and float(_buf[_i + 1][0]) <= t:
		_i += 1
	return _buf[_i]


func step(delta: float) -> void:
	_t += minf(delta, 0.05) * SPEED
	if _t >= _t1:
		stop()
		return
	var f := _frame_at(_t)
	m.ball.show_at(f[1])
	for e in f[2]:
		_put(e)


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
	for e in _saved:
		_put(e)
	m.ball.show_at(_ball_saved)
	_saved = []
	if _cam != null:
		_cam.queue_free()
		_cam = null
	m.cam.camera.make_current()
	m.hud.replay(false, Callable())
	m.controls.visible = bool(m.controls.get_meta("was_visible", m.controls.visible))
