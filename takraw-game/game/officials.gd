class_name Officials
extends RefCounted
## The officials between their calls: each breathes, follows the ball with his head (a little behind it, the head
## first and the shoulders after on a long turn) and leans in while the ball is in play; those standing (the
## assistant referee and the two line judges) shift their weight from foot to foot now and then, the referee in his
## chair settles his hands. A line judge holds his flag and, while the ball is in play at his end, bends to watch his
## lines, his hands on his knees. One standing gets out of the ball's way when it comes at him, a quick step or two
## to the side, and back to his place after. Their signals (a line judge's flag, the referee's arm to the side that
## won the point) are laid over that.
##
## On Low they are posed every other frame (they move slowly).

class One:
	var body: RealBody
	var base: Dictionary          # the pose he holds: sitting or standing
	var standing := false
	var judge := false            # a line judge: his flag, and he bends to watch his lines
	var eye := 1.2                # his eyes' height (m, his own space)
	var look := Vector2.ZERO      # where his head is turned now: yaw, pitch (degrees)
	var breath := 0.0             # the breath's phase
	var breath_rate := 1.5        # radians a second (a breath every 4 s or so)
	var shift := 0.0              # his weight: -1 on his left foot .. 1 on his right (standing)
	var shift_to := 0.0
	var hands := 0.0              # sitting: 0 hands on his knees .. 1 drawn in to his lap
	var hands_to := 0.0
	var lean := 0.0               # leaning in while the ball is in play
	var bend := 0.0               # a line judge bent to watch his lines (0-1)
	var next_t := 0.0             # when he next shifts or settles
	var sig := {}                 # a signal over the pose: bone -> angles
	var sig_until := -1.0
	var sig_w := 0.0
	var home := Vector3.ZERO      # his place
	var off := Vector3.ZERO       # how far he has stepped from it, and where he is stepping to
	var off_to := Vector3.ZERO
	var vel := Vector3.ZERO
	var back_t := 0.0             # when he steps back to his place
	var stride := 0.0             # the stride's phase while he steps
	var flag: Node3D

const FLAG := Color("d8262e")
const REACH := 0.85        # the ball passing this near him (m, below 2.1 m) and he steps out of its way
const STEP_OUT := 1.25     # that far

var list: Array[One] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _skip := false
var _held := 0.0
var _ball_was := Vector3.INF
var _ball_v := Vector3.ZERO


func _init() -> void:
	_rng.seed = 11


func add(body: RealBody, base: Dictionary, standing := false, judge := false) -> void:
	var o := One.new()
	o.body = body
	o.base = base
	o.standing = standing
	o.judge = judge
	o.home = body.position
	o.eye = 1.6 if standing else 1.2
	o.breath = _rng.randf() * TAU
	o.breath_rate = _rng.randf_range(1.35, 1.75)
	o.next_t = _rng.randf_range(1.0, 5.0)
	if judge:
		o.flag = _make_flag()
		body.add_child(o.flag)
	list.append(o)
	body.apply(base)


## A signal: these bones held at these angles for secs, eased in and out.
func show_signal(body: RealBody, bones: Dictionary, secs: float) -> void:
	for o in list:
		if o.body == body:
			o.sig = bones
			o.sig_until = _t + secs


## dt: match time; ball: where it is (world); live: the ball in play.
func tick(dt: float, ball: Vector3, live: bool) -> void:
	_t += dt
	# The ball's speed from where it was (not across a jump: the ball put back for the next serve).
	if dt > 0.0:
		if _ball_was.is_finite():
			var v := (ball - _ball_was) / dt
			_ball_v = v if v.length() < 40.0 else Vector3.ZERO
		_ball_was = ball
	for o in list:
		if o.standing:
			_dodge(o, ball)
	_held += dt
	if int(Game.settings.graphics) == Game.GFX_LOW:
		_skip = not _skip
		if _skip:
			return
	var step := _held
	_held = 0.0
	for o in list:
		_pose(o, step, ball, live)


## Out of the ball's way: if it will pass within REACH of him in the next 0.7 s, below his head, a quick step to the
## side away from its line; back to his place a second or so after it has gone.
func _dodge(o: One, ball: Vector3) -> void:
	if _t >= o.back_t:
		o.off_to = Vector3.ZERO
	var flat := Vector2(_ball_v.x, _ball_v.z)
	if flat.length() < 2.5:
		return
	var me := o.home + o.off_to   # where he is going: if that is clear of it, nothing to do
	for i in range(1, 15):
		var t := i * 0.05
		var p := ball + _ball_v * t + Vector3(0, -0.5 * Ball.G * t * t, 0)
		if p.y > 2.1:
			continue
		var d := Vector2(p.x - me.x, p.z - me.z)
		if d.length() > REACH:
			continue
		# Across the ball's line, to the side of it he is on; if it comes straight at him, back toward his place, or
		# away from the court.
		var across := Vector2(-flat.y, flat.x).normalized()
		var s := -signf(across.dot(d))
		if absf(across.dot(d)) < 0.3:
			var home_d := Vector2(-o.off_to.x, -o.off_to.z)
			var away := home_d if home_d.length() > 0.2 else Vector2(o.home.x, o.home.z)
			s = 1.0 if across.dot(away) >= 0.0 else -1.0
		var to := o.off_to + Vector3(across.x, 0, across.y) * s * STEP_OUT
		if to.length() > 2.0:
			to = to.normalized() * 2.0
		o.off_to = to
		o.back_t = _t + t + _rng.randf_range(0.9, 1.4)
		return


func _pose(o: One, dt: float, ball: Vector3, live: bool) -> void:
	var p := o.base.duplicate()
	# Stepping out of the ball's way and back: quick to start, eased in to where he is going.
	var speed := 0.0
	if o.standing:
		var want := (o.off_to - o.off) * 7.0
		o.vel = o.vel.move_toward(want.limit_length(3.0), dt * 24.0)
		o.off += o.vel * dt
		o.body.position = o.home + o.off
		speed = o.vel.length()
		if speed > 0.05:
			o.stride += dt * (4.0 + speed * 2.2)
			var local := o.vel.rotated(Vector3.UP, -o.body.rotation.y)
			var side := clampf(local.x / speed, -1.0, 1.0)
			p = Moves.blend(p, Moves.run(o.stride, clampf(speed / 5.0, 0.0, 1.0), side * 0.8), smoothstep(0.05, 0.7, speed))
	# The head on the ball: yaw and pitch from his eyes, turned at most 75° (past that the shoulders would turn).
	var d: Vector3 = o.body.global_transform.affine_inverse() * ball
	var want_look := Vector2(clampf(rad_to_deg(atan2(d.x, d.z)), -75.0, 75.0),
		clampf(-rad_to_deg(atan2(d.y - o.eye, Vector2(d.x, d.z).length())), -35.0, 30.0))
	var k := 1.0 - exp(-dt * (7.0 if live else 3.0))
	o.look += (want_look - o.look) * k
	# The breath: the chest rising, the shoulders with it.
	o.breath = fmod(o.breath + dt * o.breath_rate, TAU)
	var b := sin(o.breath)
	# Now and then: a new foot to stand on, or the hands settled again.
	if _t >= o.next_t:
		o.next_t = _t + _rng.randf_range(3.0, 8.0)
		if o.standing:
			o.shift_to = (1.0 if o.shift_to <= 0.0 else -1.0) * _rng.randf_range(0.5, 1.0)
		else:
			o.hands_to = 0.0 if o.hands_to > 0.5 else _rng.randf_range(0.6, 1.0)
	var e := 1.0 - exp(-dt * 1.6)
	o.shift += (o.shift_to - o.shift) * e
	o.hands += (o.hands_to - o.hands) * e
	o.lean += ((1.0 if live else 0.0) - o.lean) * (1.0 - exp(-dt * 2.0))
	# A line judge bends to his lines while the ball is in play at his end and coming down (not while he steps).
	var watching := live and o.judge and signf(ball.x) == signf(o.home.x) and ball.y < 4.0 and speed < 0.3
	o.bend += ((1.0 if watching else 0.0) - o.bend) * (1.0 - exp(-dt * (4.0 if watching else 2.5)))
	var yaw := o.look.x
	var pitch := o.look.y
	# A slow sway from side to side, and the breath.
	var still := 1.0 - smoothstep(0.05, 0.7, speed)
	var sway := sin(_t * 0.8 + o.breath_rate * 7.0) * 1.8 * still
	_add(p, "spine", Vector3(0.8 * b + o.lean * (2.0 if o.standing else 5.0), yaw * 0.1, sway))
	_add(p, "chest", Vector3(1.4 * b, yaw * 0.14, sway * 0.5))
	_add(p, "neck", Vector3(pitch * 0.4, yaw * 0.3, -sway * 0.6))
	_add(p, "head", Vector3(pitch * 0.6, yaw * 0.46, -sway * 0.6))
	_add(p, "upperarm_l", Vector3(0, 0, 0.6 * b))
	_add(p, "upperarm_r", Vector3(0, 0, -0.6 * b))
	if o.standing:
		# His weight on one foot: the hips drop to the other side, the free knee bends, the back stays upright.
		var s := o.shift * still * (1.0 - o.bend)
		var free := absf(s)
		_add(p, "hips", Vector3(0, 0, s * 3.0))
		_add(p, "spine", Vector3(0, 0, -s * 3.5))
		_add(p, "thigh_l", Vector3(-6.0 * free * float(s > 0.0), 0, -s * 3.0))
		_add(p, "thigh_r", Vector3(-6.0 * free * float(s < 0.0), 0, -s * 3.0))
		_add(p, "shin_l", Vector3(12.0 * free * float(s > 0.0), 0, 0))
		_add(p, "shin_r", Vector3(12.0 * free * float(s < 0.0), 0, 0))
		_add(p, "foot_l", Vector3(-6.0 * free * float(s > 0.0), 0, 0))
		_add(p, "foot_r", Vector3(-6.0 * free * float(s < 0.0), 0, 0))
		if o.bend > 0.01:
			# Bent to watch: the knees bent, the back forward, the hands on his knees, the head up on the ball.
			var c := o.bend
			p.hips_y = float(p.get("hips_y", 0.0)) - 0.09 * c
			for lr in ["_l", "_r"]:
				_add(p, "thigh" + lr, Vector3(-30.0 * c, 0, 0))
				_add(p, "shin" + lr, Vector3(52.0 * c, 0, 0))
				_add(p, "foot" + lr, Vector3(-22.0 * c, 0, 0))
			_add(p, "spine", Vector3(22.0 * c, 0, 0))
			_add(p, "chest", Vector3(8.0 * c, 0, 0))
			_add(p, "neck", Vector3(-14.0 * c, 0, 0))
			_add(p, "head", Vector3(-12.0 * c, 0, 0))
			_add(p, "upperarm_l", Vector3(-34.0 * c, 0, -4.0 * c))
			_add(p, "upperarm_r", Vector3(-34.0 * c, 0, 4.0 * c))
			_add(p, "forearm_l", Vector3(-6.0 * c, 0, 0))
			_add(p, "forearm_r", Vector3(-6.0 * c, 0, 0))
	else:
		# Sitting: the hands on his knees, or drawn in to his lap.
		var h := o.hands
		_add(p, "upperarm_l", Vector3(8.0 * h, 0, -4.0 * h))
		_add(p, "upperarm_r", Vector3(8.0 * h, 0, 4.0 * h))
		_add(p, "forearm_l", Vector3(-22.0 * h, 0, 0))
		_add(p, "forearm_r", Vector3(-22.0 * h, 0, 0))
	# A signal over all that.
	o.sig_w = move_toward(o.sig_w, 1.0 if _t < o.sig_until else 0.0, dt * 7.0)
	if o.sig_w > 0.0:
		for bone in o.sig:
			p[bone] = Moves._mix(p.get(bone, Vector3.ZERO), o.sig[bone], o.sig_w)
	o.body.apply(p)
	if o.flag:
		_hold_flag(o)


## The line judge's flag: a short stick in his right fist, on along his forearm, the cloth at its far end.
func _hold_flag(o: One) -> void:
	var hand := o.body.bone_world("hand_r")
	var along := (hand - o.body.bone_world("forearm_r")).normalized()
	var out := o.body.global_transform.basis.x.normalized()
	out = (out - along * out.dot(along)).normalized()
	if not out.is_finite() or out.length() < 0.5:
		return
	o.flag.global_transform = Transform3D(Basis(out, along, out.cross(along)), hand + along * 0.06)


func _make_flag() -> Node3D:
	var g := Geo.new()   # the stick and the cloth in one mesh: one draw call
	g.cylinder(Vector3(0, -0.08, 0), Vector3(0, 0.42, 0), 0.009, 0.009, Color("1a1a1a"), 6)
	g.box(Vector3(0.135, 0.32, 0), Vector3(0.26, 0.2, 0.006), FLAG)
	var f := g.commit(Geo.material(true))
	f.top_level = true
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return f


static func _add(p: Dictionary, bone: String, v: Vector3) -> void:
	var cur = p.get(bone, Vector3.ZERO)
	if cur is Quaternion:
		p[bone] = (cur as Quaternion) * RealBody.local_rot(v)
	else:
		p[bone] = (cur as Vector3) + v
