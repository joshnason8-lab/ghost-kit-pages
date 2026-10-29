class_name WsgLocomotor
extends Node
## Locomotion from the motion-capture library for a WsgBody: the game says where the body is going and which way it
## should face; this picks and blends the clips, keeps the feet planted and turns the head.
##
##   var loco := WsgLocomotor.attach(body)     # body: a WsgBody (it, or its parent, is moved by the game)
##   # every frame, after the game has moved the body:
##   loco.drive(delta, velocity, facing)        # world velocity (m/s), facing: world yaw (radians, 0 = +Z)
##   loco.look_at_point(ball_position)          # or loco.look_at_point(null)
##   loco.jump()                                 # a split jump: start, air (while in_air), land
##   loco.play("Stand_Relaxed_Conv_v1")          # any clip once, blended in and out (gestures, celebrations)
##
## What it does:
##   - standing: the idle (with a fidget now and then); asked to face another way, it turns on the spot (45, 90,
##     135 or 180 degree clips, the nearest);
##   - setting off: the start clip for the direction against the way it faces (0, 45, 90, 135, 180 left or right,
##     or straight back) into a walk, jog or run, by the speed it is asked for;
##   - moving: every walk, jog and run loop in 8 directions (backpedals included) blended by its speed and its
##     direction against its facing, phase-matched (every loop is one gait cycle from the left foot's landing);
##     curving: the circle loops blended in by how fast its path turns; the legs' cadence set by its speed over the
##     blended stride, so the stride matches the ground covered;
##   - a sharp change of direction while moving: the 90 or 180 degree cut, left or right;
##   - stopping: the stop from the walk, jog or run, forward, back or to either side, the one for whichever foot is
##     up at that moment;
##   - the feet planted (WsgFootPlanter) on the clips' own contacts; the head (and a little of the chest) turned to
##     what it should watch (LookAtModifier3D).
## Speeds and directions are smoothed (Kabaddi's 0.18 s ease) so a player edging about at a threshold does not flicker
## between clips. The run is the top speed until a sprint clip arrives: faster than its 6.4 m/s, the legs go faster.
## Without the clip library (WsgClips.available() false) it does nothing: the game keeps its own animation.

signal step(foot: int)          # a foot has landed (for footstep sounds)

const EASE := 0.18              # s: speed and direction smoothing
const LIB := "mob/"
const WALK := 1.3
const JOG := 3.5
const RUN := 6.4
const START_SPEED := 0.45       # m/s asked for, from standing, that sets off
const STOP_SPEED := 0.3         # m/s asked for, while moving, that stops
const CUT_ANGLE := 75.0         # degrees between the way it goes and the way it is asked to go that makes a cut
const TURN_ANGLE := 35.0        # degrees off its facing, standing, that makes it turn on the spot
const FADE := 0.22              # s cross-fade into and out of a one-off clip
const STOP_DECEL := 6.0         # m/s/s a stop is assumed to brake at until the body is seen braking harder

enum State { IDLE, START, MOVE, CUT, STOP, TURN, JUMP, SHOT }

var body: WsgBody
var tree: AnimationTree
var planter: WsgFootPlanter
var look: LookAtModifier3D
var look_chest: LookAtModifier3D
var look_target: Node3D
var state := State.IDLE
var yaw := 0.0                  # the body's facing, world (radians)
var speed := 0.0                # smoothed speed
var local_vel := Vector2.ZERO   # smoothed velocity against the facing (x: left, y: forward)
var phase := 0.0                # gait phase, 0..1 from the left foot's landing
var in_air := false             # the game says the body is in the air (a jump's air holds until it lands)
var enabled := false
var leg_scale := 1.0            # this body's leg against the clips' (strides scale with it)

var _blend := {}                # gait blend-space points: name -> Vector2
var _shot := ""                 # the one-off clip playing
var _shot_t := 0.0
var _shot_len := 1.0
var _shot_yaw0 := 0.0           # facing when it began (a turn or cut's root turn is added to it)
var _shot_next := ""            # a clip queued after this one (a jump's air, then its land)
var _slot := 0                  # which of the two one-off slots is playing (they cross-fade into each other)
var _w_shot := 0.0
var _w_move := 0.0
var _w_slot := 0.0
var _curve := 0.0
var _last_dir := 0.0            # yaw of the velocity last frame (for curving)
var _shot_rate := 1.0           # the one-off clip's playback rate now (speed-warped to the body's speed)
var _prev_speed := 0.0
var _facing := 0.0              # the facing the game asks for
var _driven := false
var _travelled := 0.0           # ground the body has covered since the one-off clip began
var _cut_from := 0.0            # a cut: the way it was going, and the way it was asked to go (world yaw)
var _cut_to := 0.0
static var _dists := {}         # clip -> its root's distance covered by each frame (m)
var _accel := 0.0               # smoothed acceleration (m/s/s), to guess the speed a start is heading for
static var _speeds := {}        # clip -> its root's speed, a frame at a time (m/s)
var _want_speed := 0.0
var _idle_for := 0.0
var _down := [true, true]


## Builds a locomotor for the body (its tree, foot planter, look-at) and adds it under the body.
static func attach(p_body: WsgBody) -> WsgLocomotor:
	var l := WsgLocomotor.new()
	l.name = "Locomotor"
	l.body = p_body
	p_body.add_child(l)
	l._setup()
	return l


func _setup() -> void:
	enabled = WsgClips.available()
	if not enabled:
		return
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	body.add_child(tree)
	tree.root_node = tree.get_path_to(body)
	tree.add_animation_library("mob", WsgClips.library())
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.tree_root = _build()
	tree.active = true
	# The body's own proportions: the clips move the hips for a 0.85 m leg (hip to ankle) and 0.98 m hips; the hips
	# move in proportion to this body's leg, and its strides are that much longer or shorter.
	var leg := (body.joints["LeftUpLeg"] as Vector3).distance_to(body.joints["LeftLeg"]) + (body.joints["LeftLeg"] as Vector3).distance_to(body.joints["LeftFoot"])
	leg_scale = leg / 0.85
	body.skeleton.motion_scale = leg_scale
	planter = WsgFootPlanter.new()
	planter.name = "FootPlanter"
	body.add_modifier(planter)
	planter.hips_offset = (body.joints["Hips"] as Vector3).y - 0.98 * leg_scale
	planter.landed.connect(func(f): step.emit(f))
	look_target = Node3D.new()
	look_target.name = "LookTarget"
	body.add_child(look_target)
	look_target.top_level = true
	look_chest = _look_mod("Spine2", 30.0, 0.5)
	look = _look_mod("Head", 70.0, 0.25)
	yaw = body.global_rotation.y if body.is_inside_tree() else 0.0


func _look_mod(bone: String, limit: float, dur: float) -> LookAtModifier3D:
	var m := LookAtModifier3D.new()
	m.name = "Look" + bone
	m.bone_name = bone
	m.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	m.primary_rotation_axis = Vector3.AXIS_Y
	m.use_secondary_rotation = true
	m.use_angle_limitation = true
	m.symmetry_limitation = true
	m.primary_limit_angle = deg_to_rad(limit * 2.0)
	m.secondary_limit_angle = deg_to_rad(limit * 0.8)
	m.primary_damp_threshold = 0.8
	m.duration = dur
	m.transition_type = Tween.TRANS_SINE
	m.ease_type = Tween.EASE_IN_OUT
	m.influence = 0.0
	body.add_modifier(m)
	m.target_node = m.get_path_to(look_target)
	return m


## The tree: idle | 8-direction gait (walk, jog, run) and its curves | two one-off slots.
func _build() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = LIB + "Stand_Relaxed_Idle"
	bt.add_node("idle", idle)
	var idle_ts := AnimationNodeTimeScale.new()
	bt.add_node("idle_ts", idle_ts)
	bt.connect_node("idle_ts", 0, "idle")
	var gait := AnimationNodeBlendSpace2D.new()
	gait.sync = true
	gait.min_space = Vector2(-7, -4)
	gait.max_space = Vector2(7, 7)
	for g in ["Walk", "Jog", "Run"]:
		for d in ["F", "FL", "FR", "L", "R", "B", "BL_BkPd", "BR_BkPd"]:
			var nm := "%s_%s_Loop" % [g, d]
			if not WsgClips.has(nm):
				continue
			var m := WsgClips.meta(nm)
			var a := deg_to_rad(float(m.dir))
			var p := Vector2(sin(a), cos(a)) * float(m.speed)
			var an := AnimationNodeAnimation.new()
			an.animation = LIB + nm
			gait.add_blend_point(an, p, -1, nm)
			_blend[nm] = p
	bt.add_node("gait", gait)
	# Curving: the circle loops (by speed), left and right, blended over the straight gait.
	for side in ["L", "R"]:
		var bs := AnimationNodeBlendSpace1D.new()
		bs.sync = true
		bs.min_space = 0.0
		bs.max_space = 7.0
		for g in ["Walk", "Jog", "Run"]:
			var nm := "%s_%s_CIR_Loop" % [g, side]
			if WsgClips.has(nm):
				var an := AnimationNodeAnimation.new()
				an.animation = LIB + nm
				bs.add_blend_point(an, float(WsgClips.meta(nm).speed), -1, nm)
		bt.add_node("cir_" + side, bs)
	var curve := AnimationNodeBlend3.new()
	curve.sync = true
	bt.add_node("curve", curve)
	bt.connect_node("curve", 0, "cir_R")
	bt.connect_node("curve", 1, "gait")
	bt.connect_node("curve", 2, "cir_L")
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("gait_ts", ts)
	bt.connect_node("gait_ts", 0, "curve")
	var seek := AnimationNodeTimeSeek.new()
	bt.add_node("gait_seek", seek)
	bt.connect_node("gait_seek", 0, "gait_ts")
	var move := AnimationNodeBlend2.new()
	bt.add_node("move", move)
	bt.connect_node("move", 0, "idle_ts")
	bt.connect_node("move", 1, "gait_seek")
	for s in 2:
		var an := AnimationNodeAnimation.new()
		an.animation = LIB + "Stand_Relaxed_Idle"
		bt.add_node("shot%d" % s, an)
		var sts := AnimationNodeTimeScale.new()
		bt.add_node("shot%d_ts" % s, sts)
		bt.connect_node("shot%d_ts" % s, 0, "shot%d" % s)
		var ssk := AnimationNodeTimeSeek.new()
		bt.add_node("shot%d_seek" % s, ssk)
		bt.connect_node("shot%d_seek" % s, 0, "shot%d_ts" % s)
	var shots := AnimationNodeBlend2.new()
	bt.add_node("shots", shots)
	bt.connect_node("shots", 0, "shot0_seek")
	bt.connect_node("shots", 1, "shot1_seek")
	var out := AnimationNodeBlend2.new()
	bt.add_node("out", out)
	bt.connect_node("out", 0, "move")
	bt.connect_node("out", 1, "shots")
	bt.connect_node("output", 0, "out")
	return bt


func _p(path: String, v) -> void:
	tree.set("parameters/" + path, v)


## Turns the head (and a little of the chest) to watch a point in the world; null: looks where it is going.
func look_at_point(p) -> void:
	if not enabled:
		return
	if p == null:
		look.influence = move_toward(look.influence, 0.0, 0.1)
		look_chest.influence = look.influence * 0.6
		return
	look_target.global_position = p
	look.influence = 1.0
	look_chest.influence = 0.6


## A clip once (a gesture, a celebration, a dive), blended in and out; the gait carries on underneath.
func play(clip: String, rate := 1.0) -> void:
	if not enabled or not WsgClips.has(clip):
		return
	_fire(clip, State.SHOT, rate)


## A split jump on the spot or on the move: start, the air for as long as in_air stays true (or the clip's own),
## then the landing.
func jump() -> void:
	if not enabled:
		return
	var moving := speed > 1.5
	var pre := "Stand_Relaxed_Jump_"
	if moving:
		var g := "Run" if speed > 4.8 else "Jog"
		var lead := "LU" if not _down[0] else "RU"
		pre = "%s_F_Jump_%s_" % [g, lead]
	if WsgClips.has(pre + "Start"):
		_fire(pre + "Start", State.JUMP)
		_shot_next = pre + "Air"


func _fire(clip: String, st: State, rate := 1.0) -> void:
	_slot = 1 - _slot
	(tree.tree_root.get_node("shot%d" % _slot) as AnimationNodeAnimation).animation = LIB + clip
	_p("shot%d_seek/seek_request" % _slot, 0.0)
	_p("shot%d_ts/scale" % _slot, rate)
	_shot = clip
	_shot_t = 0.0
	_travelled = 0.0
	_shot_rate = rate
	_shot_len = float(WsgClips.meta(clip).length)
	_shot_yaw0 = yaw
	_shot_next = ""
	state = st


## The game's say for this frame. velocity: where the body is going (world, m/s; y ignored); facing: the way it should
## face (world yaw, radians; for a player usually the way he runs, for an official the play).
## want_velocity: where the player is asking to go (the stick, the AI's target velocity), if the game has it: a sharp
## change of it makes a cut at once (the body's own velocity swings round more slowly), and a start picks the walk,
## jog or run start by its speed. Without it the speed being headed for is guessed from the acceleration.
func drive(delta: float, velocity: Vector3, facing: float, want_velocity := Vector3.INF) -> void:
	if not enabled or delta <= 0.0:
		return
	var flat := Vector2(velocity.x, velocity.z)
	var want := flat.length()
	_accel = lerpf(_accel, (want - _prev_speed) / delta, 1.0 - exp(-delta / 0.15))
	_prev_speed = want
	var intent := Vector2(want_velocity.x, want_velocity.z) if want_velocity != Vector3.INF else flat
	_want_speed = intent.length() if want_velocity != Vector3.INF else want + maxf(0.0, _accel) * 0.4
	var k := 1.0 - exp(-delta / EASE)
	speed = lerpf(speed, want, k)
	# Velocity against the facing: x left (+X is the body's left), y forward.
	var lv := Vector2(flat.dot(Vector2(cos(yaw), -sin(yaw))), flat.dot(Vector2(sin(yaw), cos(yaw))))
	local_vel = local_vel.lerp(lv, k)
	var dir := atan2(flat.x, flat.y) if want > 0.2 else _last_dir
	var turn_rate := wrapf(dir - _last_dir, -PI, PI) / delta if want > 0.2 else 0.0
	_last_dir = dir
	_facing = facing
	if not _driven:
		# A body just placed faces the way it is asked to, at once.
		_driven = true
		yaw = facing
	var face_err := wrapf(facing - yaw, -PI, PI)
	match state:
		State.IDLE:
			_idle_for += delta
			if want > START_SPEED:
				_start(flat, _want_speed)
			elif absf(face_err) > deg_to_rad(TURN_ANGLE):
				_turn(face_err)
			elif _idle_for > 6.0 and randf() < delta * 0.15:
				_idle_for = 0.0
				_fire("Stand_Relaxed_Fgt_v%d" % (randi() % 4 + 1), State.SHOT)
		State.MOVE:
			# Stopping: as soon as it is asked to (if the game says), with the stop for the speed it is going at.
			if want < STOP_SPEED or want_velocity != Vector3.INF and intent.length() < STOP_SPEED and speed > 1.0:
				_stop()
			else:
				# A sharp change of the way it goes: a cut (if it is going at a walk or more and faces its way).
				var going := atan2(local_vel.x, local_vel.y)
				var asked := wrapf((atan2(intent.x, intent.y) if intent.length() > 0.5 else dir) - yaw, -PI, PI)
				var off := wrapf(asked - going, -PI, PI)
				if speed > 1.0 and absf(going) < deg_to_rad(40) and absf(off) > deg_to_rad(CUT_ANGLE) and absf(wrapf(facing - yaw - asked, -PI, PI)) < deg_to_rad(45):
					_cut(off)
				else:
					yaw = _turn_toward(yaw, facing, delta, deg_to_rad(lerpf(300.0, 540.0, clampf(speed / RUN, 0, 1))))
		State.START, State.CUT, State.TURN, State.STOP, State.JUMP, State.SHOT:
			# Clips that travel play at the body's own speed against theirs: the ground their feet cover is the
			# ground the game covers.
			_travelled += want * delta
			if state == State.START or state == State.STOP:
				# Distance matched: a start plays to where its root has gone as far as the body has since it set off;
				# a stop, to where the ground it has left to cover is what the body will cover stopping at this
				# deceleration. Never backwards, never faster than three times its own pace.
				var target := _shot_t
				if state == State.START:
					target = _time_at_distance(_shot, _travelled)
				else:
					var decel := maxf(2.0, -_accel)
					target = _time_at_distance(_shot, _clip_dist(_shot) - want * want / (2.0 * decel))
				var step_t := clampf(target - _shot_t, delta * 0.25, delta * 3.0)
				_shot_rate = step_t / delta
			elif state == State.CUT:
				# Angle matched: the cut plays to where its own turn has gone as far through as the body's velocity
				# has turned toward where it was asked to go (the plant and push-off land where the game turns).
				var total: float = absf(wrapf(_cut_to - _cut_from, -PI, PI))
				var done: float = absf(wrapf(dir - _cut_from, -PI, PI)) if want > 0.3 else 0.0
				var clip_turn: float = absf(float(WsgClips.meta(_shot).get("turn", 90.0)))
				var target := _time_at_turn(_shot, clip_turn * clampf(done / maxf(total, 0.01), 0.0, 1.0))
				var step_t := clampf(target - _shot_t, delta * 0.4, delta * 2.5)
				_shot_rate = step_t / delta
			_p("shot%d_ts/scale" % _slot, _shot_rate)
			_shot_t += delta * _shot_rate
			# Turning clips carry the body round as they did on the stage.
			if state in [State.START, State.CUT, State.TURN, State.STOP]:
				yaw = _shot_yaw0 + deg_to_rad(_root_yaw(_shot, _shot_t / _shot_len))
			elif state == State.SHOT and want > 0.2:
				yaw = _turn_toward(yaw, facing, delta, deg_to_rad(360))
			var left := _shot_len - _shot_t
			if state == State.JUMP and _shot_next != "" and left < FADE:
				var nxt := _shot_next
				_fire(nxt, State.JUMP)
				if nxt.ends_with("_Air"):
					_shot_next = nxt.replace("_Air", "_Land")
				_shot_len = maxf(_shot_len, 0.3)
			elif state == State.JUMP and _shot.ends_with("_Air") and in_air:
				_shot_t = minf(_shot_t, _shot_len * 0.5)
			elif (state == State.STOP and _shot_t > 0.25 or state == State.TURN) and want > START_SPEED:
				# Asked to go while stopping or turning on the spot: set off at once (turning on the spot while the
				# game carries the body away would drag the planted feet).
				_start(flat, _want_speed)
			elif state == State.START and (left < 0.35 or want < STOP_SPEED and _shot_t > 0.3):
				_enter_move()
			elif state == State.CUT and left < 0.4:
				_enter_move()
			elif left <= FADE:
				if want > START_SPEED:
					_enter_move()
				else:
					state = State.IDLE
					_idle_for = 0.0
	# Weights: the one-off clip over the gait, the gait over the idle.
	var shot_on := state in [State.START, State.CUT, State.TURN, State.STOP, State.JUMP, State.SHOT]
	_w_shot = move_toward(_w_shot, 1.0 if shot_on else 0.0, delta / FADE)
	var mv := smoothstep(0.15, 0.9, speed) if state != State.IDLE else 0.0
	_w_move = move_toward(_w_move, mv, delta / 0.25)
	_w_slot = move_toward(_w_slot, float(_slot), delta / FADE)
	# Curving: how fast the path turns, against what the circle clips turn at (about 100 degrees a second).
	var want_curve := clampf(rad_to_deg(turn_rate) / 100.0, -1.0, 1.0) * smoothstep(0.8, 1.5, speed) * (1.0 if local_vel.y > 0.5 else 0.0)
	_curve = lerpf(_curve, want_curve, k * 0.5)
	# Cadence: one gait cycle per stride covered.
	var stride := _stride(local_vel)
	var rate := speed / stride if stride > 0.01 else 1.0
	phase = fposmod(phase + rate * delta, 1.0)
	_p("gait/blend_position", local_vel)
	_p("cir_L/blend_position", speed)
	_p("cir_R/blend_position", speed)
	_p("curve/blend_amount", _curve)
	_p("gait_ts/scale", rate)
	_p("idle_ts/scale", 1.0 / float(WsgClips.meta("Stand_Relaxed_Idle").get("cycle", 4.0)))
	_p("move/blend_amount", _w_move)
	_p("shots/blend_amount", _w_slot)
	_p("out/blend_amount", _w_shot)
	tree.advance(delta)
	planter.tick(delta)
	body.rotation.y = yaw
	_feet()


## The stride (m a cycle) of the gait blended at that velocity: the walk, jog and run rings, by speed, in that direction.
func _stride(v: Vector2) -> float:
	var s := v.length()
	if s < 0.05:
		return 1.0
	var a := atan2(v.x, v.y)
	var rings := []
	for g in ["Walk", "Jog", "Run"]:
		var best := ""
		var bd := INF
		for nm in _blend:
			if nm.begins_with(g + "_"):
				var p: Vector2 = _blend[nm]
				var d := absf(wrapf(atan2(p.x, p.y) - a, -PI, PI))
				if d < bd:
					bd = d
					best = nm
		if best != "":
			var m := WsgClips.meta(best)
			rings.append([float(m.speed) * leg_scale, float(m.stride) * leg_scale])
	if rings.is_empty():
		return 1.0
	if s <= rings[0][0]:
		# Below a walk the stride shortens toward a shuffle.
		return lerpf(rings[0][1] * 0.45, rings[0][1], s / rings[0][0])
	for i in range(1, rings.size()):
		if s <= rings[i][0]:
			var t: float = (s - rings[i - 1][0]) / (rings[i][0] - rings[i - 1][0])
			return lerpf(rings[i - 1][1], rings[i][1], t)
	return rings[-1][1]


## Ground a clip's root covers, by each frame (m), for this body's leg length.
func _dist_curve(clip: String) -> PackedFloat32Array:
	if not _dists.has(clip):
		var d := PackedFloat32Array()
		var m := WsgClips.meta(clip)
		var acc := 0.0
		if m.has("root"):
			var r: Array = m.root
			for i in r.size():
				if i > 0:
					acc += Vector2(float(r[i][0]) - float(r[i - 1][0]), float(r[i][1]) - float(r[i - 1][1])).length()
				d.append(acc)
		_dists[clip] = d
	return _dists[clip]


func _clip_dist(clip: String) -> float:
	var d := _dist_curve(clip)
	return d[-1] * leg_scale if d.size() > 0 else 0.0


## The time (s) at which the clip's root has covered dist (m, for this body).
func _time_at_distance(clip: String, dist: float) -> float:
	var d := _dist_curve(clip)
	if d.size() < 2:
		return 0.0
	var x := dist / leg_scale
	if x <= 0.0:
		return 0.0
	for i in range(1, d.size()):
		if d[i] >= x:
			var f := (x - d[i - 1]) / maxf(d[i] - d[i - 1], 1e-5)
			return (i - 1 + f) / 30.0
	return (d.size() - 1) / 30.0


## A clip's root speed (m/s) at time t (s), from its root path.
static func _clip_speed(clip: String, t: float) -> float:
	if not _speeds.has(clip):
		var m := WsgClips.meta(clip)
		var sp := PackedFloat32Array()
		if m.has("root"):
			var r: Array = m.root
			for i in r.size():
				var a: Array = r[maxi(0, i - 2)]
				var b: Array = r[mini(r.size() - 1, i + 2)]
				var n := mini(r.size() - 1, i + 2) - maxi(0, i - 2)
				sp.append(Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])).length() * 30.0 / maxf(n, 1))
		_speeds[clip] = sp
	var s: PackedFloat32Array = _speeds[clip]
	if s.is_empty():
		return 0.0
	return s[clampi(int(t * 30.0), 0, s.size() - 1)]


static func _turn_toward(from: float, to: float, delta: float, rate: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -rate * delta, rate * delta)


## The clip's root turn (degrees) at fraction t.
static func _root_yaw(clip: String, t: float) -> float:
	var m := WsgClips.meta(clip)
	if not m.has("root"):
		return 0.0
	var r: Array = m.root
	var f := clampf(t, 0.0, 1.0) * (r.size() - 1)
	var i := mini(int(f), r.size() - 2)
	if i < 0:
		return 0.0
	var a: float = r[i][2]
	var b: float = r[i + 1][2]
	var d := wrapf(b - a, -180.0, 180.0)
	# Unwrap from the start (a 180 turn passes the seam).
	var acc := 0.0
	for j in i:
		acc += wrapf(float(r[j + 1][2]) - float(r[j][2]), -180.0, 180.0)
	return float(r[0][2]) + acc + d * (f - i)


func _gait_name(v: float) -> String:
	return "Walk" if v < (WALK + JOG) * 0.5 else ("Jog" if v < (JOG + RUN) * 0.5 else "Run")


func _start(flat: Vector2, want: float) -> void:
	var dir := atan2(flat.x, flat.y)
	var g := _gait_name(want)
	var clip := ""
	# Going where it will face (a player setting off): the start that turns it that way (0, 45, 90, 135, 180).
	if absf(wrapf(dir - _facing, -PI, PI)) < deg_to_rad(35.0):
		var rel := rad_to_deg(wrapf(dir - yaw, -PI, PI))
		var a := absf(rel)
		var side := "L" if rel > 0.0 else "R"
		if a < 22.5:
			clip = "Stand_Relaxed_To_%s_F" % g
		else:
			var best := 45
			for s in [45, 90, 135, 180]:
				if absf(a - s) < absf(a - best):
					best = s
			clip = "Stand_Relaxed_To_%s_%s%d_Fwd" % [g, side, best]
	else:
		# Keeping its facing (backing off, shuffling across, an official): the start straight back or to the side.
		var rel := rad_to_deg(wrapf(dir - yaw, -PI, PI))
		var d := "F"
		if absf(rel) > 135.0:
			d = "B"
		elif rel > 45.0:
			d = "L"
		elif rel < -45.0:
			d = "R"
		var gg := "Jog" if g == "Run" else g
		clip = "Stand_Relaxed_To_%s_%s" % [gg, d]
	if not WsgClips.has(clip):
		clip = "Stand_Relaxed_To_%s_F" % g
	_fire(clip, State.START)


func _stop() -> void:
	var going := rad_to_deg(atan2(local_vel.x, local_vel.y))
	var d := "F"
	if absf(going) > 135.0:
		d = "B"
	elif going > 45.0:
		d = "L"
	elif going < -45.0:
		d = "R"
	# The ground it will take to stop (at the deceleration it is braking at, or a typical one), and the stop whose
	# own length fits it best, for the foot that is up now (walk, jog or run stops, LU/RU: which foot is lifting).
	var decel := maxf(-_accel, STOP_DECEL)
	var need := speed * speed / (2.0 * decel)
	var up := "LU" if not _down[0] else ("RU" if not _down[1] else "")
	var best := ""
	var err := INF
	for g in ["Walk", "Jog", "Run"]:
		for suffix in (["_" + up, ""] if up != "" else ["", "_LU", "_RU"]):
			var clip := "%s_%s_To_Stand_Relaxed%s" % [g, d, suffix]
			if not WsgClips.has(clip):
				continue
			# A stop from a much faster or slower gait looks wrong whatever its length: weigh that in.
			var gait_off := absf(float(["Walk", "Jog", "Run"].find(g)) - float(["Walk", "Jog", "Run"].find(_gait_name(speed))))
			var e := absf(_clip_dist(clip) - need) + gait_off * 0.8 + (0.0 if suffix == "_" + up else 0.3)
			if e < err:
				err = e
				best = clip
	if best == "":
		state = State.IDLE
		return
	_fire(best, State.STOP)


func _turn(err: float) -> void:
	var a := absf(rad_to_deg(err))
	var best := 45
	for s in [45, 90, 135, 180]:
		if absf(a - s) < absf(a - best):
			best = s
	var clip := "Stand_Relaxed_%s_%d" % ["L" if err > 0.0 else "R", best]
	if WsgClips.has(clip):
		_fire(clip, State.TURN)


func _cut(off: float) -> void:
	var g := _gait_name(speed)
	var a := absf(rad_to_deg(off))
	var clip := "%s_%s_%d" % [g, "L" if off > 0.0 else "R", 180 if a > 135.0 else 90]
	if WsgClips.has(clip):
		_cut_from = _last_dir
		_cut_to = _last_dir + off
		_fire(clip, State.CUT)


## The time (s) at which the clip's root has turned by deg (degrees, either way).
func _time_at_turn(clip: String, deg: float) -> float:
	var m := WsgClips.meta(clip)
	if not m.has("root"):
		return 0.0
	var r: Array = m.root
	var acc := 0.0
	for i in range(1, r.size()):
		var d: float = absf(wrapf(float(r[i][2]) - float(r[i - 1][2]), -180.0, 180.0))
		if acc + d >= deg:
			return (i - 1 + (deg - acc) / maxf(d, 1e-4)) / 30.0
		acc += d
	return (r.size() - 1) / 30.0


## Back to the gait, phase-matched: the loop starts where the one-off clip's feet are.
func _enter_move() -> void:
	state = State.MOVE
	# Which foot landed last in the one-off clip, and how long ago, picks the loop's phase.
	var t := _shot_t / maxf(_shot_len, 0.001)
	var m := WsgClips.meta(_shot)
	var best_foot := 0
	var since := INF
	for foot in 2:
		for r: Array in m.get("contacts", [[], []])[foot]:
			if r[0] <= t and t - float(r[0]) < since:
				since = t - float(r[0])
				best_foot = foot
	var g := _gait_name(maxf(speed, _want_speed))
	var loop := WsgClips.meta(g + "_F_Loop")
	var right_land := 0.5
	if loop.has("contacts") and loop.contacts[1].size() > 0:
		right_land = float(loop.contacts[1][0][0])
	var land := 0.0 if best_foot == 0 else right_land
	var secs := since * float(m.get("length", 1.0)) if since < INF else 0.0
	phase = fposmod(land + secs / maxf(float(loop.get("cycle", 0.8)), 0.1), 1.0)
	_p("gait_seek/seek_request", phase)


## Which feet are down (the planter finds them on the pose shown); it is told how fast the body goes.
func _feet() -> void:
	planter.body_speed = speed
	_down = [planter.contact[0] > 0.5, planter.contact[1] > 0.5]
