class_name Officials
extends RefCounted
## The officials between their calls: each breathes, follows the ball with his head (a little behind it, the head
## first and the shoulders after on a long turn) and leans in while the ball is in play; the one standing (the
## assistant referee) shifts his weight from foot to foot now and then, those sitting settle their hands. Their
## signals (a line judge's arm, the referee's to the side that won the point) are laid over that.
##
## On Low they are posed every other frame (they move slowly).

class One:
	var body: RealBody
	var base: Dictionary          # the pose he holds: sitting or standing
	var standing := false
	var eye := 1.2                # his eyes' height (m, his own space)
	var look := Vector2.ZERO      # where his head is turned now: yaw, pitch (degrees)
	var breath := 0.0             # the breath's phase
	var breath_rate := 1.5        # radians a second (a breath every 4 s or so)
	var shift := 0.0              # his weight: -1 on his left foot .. 1 on his right (standing)
	var shift_to := 0.0
	var hands := 0.0              # sitting: 0 hands on his knees .. 1 drawn in to his lap
	var hands_to := 0.0
	var lean := 0.0               # leaning in while the ball is in play
	var next_t := 0.0             # when he next shifts or settles
	var sig := {}                 # a signal over the pose: bone -> angles
	var sig_until := -1.0
	var sig_w := 0.0

var list: Array[One] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _skip := false
var _held := 0.0


func _init() -> void:
	_rng.seed = 11


func add(body: RealBody, base: Dictionary, standing := false) -> void:
	var o := One.new()
	o.body = body
	o.base = base
	o.standing = standing
	o.eye = 1.6 if standing else 1.2
	o.breath = _rng.randf() * TAU
	o.breath_rate = _rng.randf_range(1.35, 1.75)
	o.next_t = _rng.randf_range(1.0, 5.0)
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
	_held += dt
	if int(Game.settings.graphics) == Game.GFX_LOW:
		_skip = not _skip
		if _skip:
			return
	var step := _held
	_held = 0.0
	for o in list:
		_pose(o, step, ball, live)


func _pose(o: One, dt: float, ball: Vector3, live: bool) -> void:
	var p := o.base.duplicate()
	# The head on the ball: yaw and pitch from his eyes, turned at most 75° (past that the shoulders would turn).
	var d: Vector3 = o.body.global_transform.affine_inverse() * ball
	var want := Vector2(clampf(rad_to_deg(atan2(d.x, d.z)), -75.0, 75.0),
		clampf(-rad_to_deg(atan2(d.y - o.eye, Vector2(d.x, d.z).length())), -35.0, 30.0))
	var k := 1.0 - exp(-dt * (7.0 if live else 3.0))
	o.look += (want - o.look) * k
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
	var yaw := o.look.x
	var pitch := o.look.y
	# A slow sway from side to side, and the breath.
	var sway := sin(_t * 0.8 + o.breath_rate * 7.0) * 1.8
	_add(p, "spine", Vector3(0.8 * b + o.lean * (2.0 if o.standing else 5.0), yaw * 0.1, sway))
	_add(p, "chest", Vector3(1.4 * b, yaw * 0.14, sway * 0.5))
	_add(p, "neck", Vector3(pitch * 0.4, yaw * 0.3, -sway * 0.6))
	_add(p, "head", Vector3(pitch * 0.6, yaw * 0.46, -sway * 0.6))
	_add(p, "upperarm_l", Vector3(0, 0, 0.6 * b))
	_add(p, "upperarm_r", Vector3(0, 0, -0.6 * b))
	if o.standing:
		# His weight on one foot: the hips drop to the other side, the free knee bends, the back stays upright.
		var s := o.shift
		var free := absf(s)
		_add(p, "hips", Vector3(0, 0, s * 3.0))
		_add(p, "spine", Vector3(0, 0, -s * 3.5))
		_add(p, "thigh_l", Vector3(-6.0 * free * float(s > 0.0), 0, -s * 3.0))
		_add(p, "thigh_r", Vector3(-6.0 * free * float(s < 0.0), 0, -s * 3.0))
		_add(p, "shin_l", Vector3(12.0 * free * float(s > 0.0), 0, 0))
		_add(p, "shin_r", Vector3(12.0 * free * float(s < 0.0), 0, 0))
		_add(p, "foot_l", Vector3(-6.0 * free * float(s > 0.0), 0, 0))
		_add(p, "foot_r", Vector3(-6.0 * free * float(s < 0.0), 0, 0))
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
			p[bone] = (p.get(bone, Vector3.ZERO) as Vector3).lerp(o.sig[bone], o.sig_w)
	o.body.apply(p)


static func _add(p: Dictionary, bone: String, v: Vector3) -> void:
	p[bone] = (p.get(bone, Vector3.ZERO) as Vector3) + v
