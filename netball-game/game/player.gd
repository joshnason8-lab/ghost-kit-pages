class_name Player
extends Node3D
## One player on the court: her squad entry (data), her position, the body that draws her, and her movement. Her
## position is written in one place only, advance(), once a frame by the match: the AI and the controls set where she
## wants to go (target) and how fast (want_speed), never her position. She accelerates and turns at a person's rate,
## so nothing snaps from one frame to the next; her stride is matched to her speed (Poses.run). tests/test_runner
## checks both ("_motion").

const ACCEL := 9.0           # m/s² speeding up
const DECEL := 12.0          # m/s² stopping (a landing on the catch takes about one step)
const TURN := 9.0            # rad/s
const TOP := 7.2             # m/s, a sprint at speed 99
const LAND_DECEL := 40.0     # m/s² at most, landing with the ball: the landing's own pace (it takes about a step)
const LAND_MIN := 1.5        # m/s: caught slower than this, she simply stops (no landing)
const SLIDE_TOP := 4.0       # m/s: side-stepping faster than this, she runs

var match_ref = null         # the Match
var team := 0
var pos := "C"               # her position (bib) now
var data := {}               # her squad entry (DB.squad)
var dir := 1                 # the end her team attacks this quarter
var body: ToonBody

var p := Vector2.ZERO        # where she is on the court (x along, y across), metres
var vel := Vector2.ZERO
var facing := 0.0            # yaw, radians: 0 faces +z
var target := Vector2.ZERO
var want_speed := 0.0        # m/s she wants to go toward target
var look_at_p := Vector2.ZERO
var look_on := false         # face look_at_p (the ball) rather than where she runs

var act := "ready"           # what her body does: ready, run, hold, pass, catch, shoot, defend, defend_shot, mark,
                             # leap, out_of_play, cheer, post (a shooter holding by the post), huddle (a break)
var act_t := 0.0
var act_kind := ""           # the pass's kind, for "pass"
var act_up := 0.0            # where the ball is met, for "catch" (-1 low .. 1 high)
var landing := Vector2.ZERO  # her landing foot while she holds the ball
var stopped := false         # holding the ball: she may not run (footwork), only pivot
var reaction := 0.0          # seconds before she reacts to a new read (the AI's)
var lead_t := 0.0            # the AI: time left on her current lead or hold
var lead_to := Vector2.ZERO
var moves := 0               # tests: how many times this frame her position was written (must be 1)
var stride_phase := 0.0
var out_until := 0.0         # standing out of play beside the thrower of a penalty pass
var suspended := 0.0         # seconds of playing time left on a suspension (R18): off the court, by the bench
var warned := false          # the umpire has warned her (R18)
var suspensions := 0         # how many times she has been suspended
var ordered_off := false     # ordered off: no further part (a replacement may come on after four minutes)
var pens := 0                # penalties since her last sanction
var was_offside := false     # offside last frame (an offside is called when she steps in, not while she walks out)
var fenced := true           # she keeps to her areas (the AI always; you with Keep me onside): she pulls up at a line
                             # rather than running over it
var clip_body := 0.0         # how much of her legs and body the stride clips take now (0-1), eased
var clip_arms := 0.0         # and of her arms
var slide := 0.0             # how much of the run is the defensive side-step (motion capture), eased
var slide_phase := 0.0       # through its cycle (0-1)
var slide_side := 1.0        # +1 stepping to her left, -1 to her right (eased between)
var land_clip := ""          # the landing (motion capture) she is in: land_l or land_r (her landing foot), or ""
var land_d := 0.0            # how far along the clip's path she is (m of the clip)
var land_w := 0.0            # how much of her legs and body it has
var land_dir := Vector2.ZERO # the way she was going as she caught it
var land_t := 0.0            # seconds since she caught it
var land_t0 := 0.0           # the clip's time she came in at
var _pose := {}
var _airborne := 0.0


func _init(p_team: int, p_data: Dictionary, p_pos: String) -> void:
	team = p_team
	data = p_data
	pos = p_pos


func _ready() -> void:
	var t := DB.team(String(data.team))
	var c1: Color = t.get("c1", Color.WHITE)
	var c2: Color = t.get("c2", Color.BLACK)
	body = HeroBody.new({"skin": Color(String(data.skin)), "dress": c1, "trim": c2, "bib": DB.bib_colour(String(data.team)),
		"shoe": Color("f3f1ee"), "hair": Color("15100c") if int(data.hair) != 2 else Color("2a1d14"),
		"hair_style": int(data.hair), "height": float(data.height), "pos": pos})
	add_child(body)
	_pose = Poses.ready(0.6)
	body.apply(_pose)


func speed_cap() -> float:
	return TOP * lerpf(0.78, 1.0, float(data.get("speed", 70)) / 99.0)


## Puts her on a spot at once: only between plays (the start of a quarter), never while she is seen running.
func place(at: Vector2, face_dir := 0.0) -> void:
	p = at
	vel = Vector2.ZERO
	target = at
	want_speed = 0.0
	facing = face_dir
	position = Vector3(p.x, 0, p.y)
	rotation.y = facing


## The one place her position changes, once a frame.
func advance(dt: float) -> void:
	moves += 1
	var to := target - p
	var dist := to.length()
	var cap := minf(want_speed, speed_cap())
	if stopped:
		cap = 0.0
	# The speed she wants: slowing as she arrives, so she stops on the spot rather than past it.
	var desired := Vector2.ZERO
	if dist > 0.05 and cap > 0.0:
		var arrive := sqrt(2.0 * DECEL * 0.8 * dist)
		desired = to / dist * minf(cap, arrive)
	# Pulling up at a line she may not cross: no faster than she can stop before it.
	if fenced and desired.length() > 0.1:
		var room := _room_along(desired.normalized())
		if room < 3.0:
			desired = desired.limit_length(sqrt(2.0 * DECEL * 0.85 * maxf(0.0, room - 0.12)))
	var rate := ACCEL if desired.length() > vel.length() else DECEL
	if stopped and land_clip != "":
		# Landing with the ball: she stops as the landing does (motion capture), at its pace, never faster than she
		# was going, so the landing foot stays where it came down.
		desired = land_dir * minf(HeroBody.mocap_speed(land_clip, land_d) * _scale(), vel.length())
		rate = LAND_DECEL
	var dv := desired - vel
	var step := rate * dt
	vel = vel + dv.limit_length(step)
	var next := p + vel * dt
	if fenced and Rules.offside(pos, next, dir) and not Rules.offside(pos, p, dir):
		# At the line: she stops on her side of it.
		next = Rules.onside_point(pos, next, dir, 0.02)
		vel = (next - p) / maxf(dt, 0.001)
	if land_clip != "":
		land_d += (next - p).length() / _scale()
	p = next
	position = Vector3(p.x, 0, p.y)
	# Facing: the ball (or a look target) when set, else where she runs.
	var want_face := facing
	if look_on:
		var d := look_at_p - p
		if d.length() > 0.05:
			want_face = atan2(d.x, d.y)
	elif vel.length() > 0.4:
		want_face = atan2(vel.x, vel.y)
	facing = rotate_toward(facing, want_face, TURN * dt)
	rotation.y = facing
	_animate(dt)


## How far she can run in direction d before a line her position may not cross (up to 3 m).
func _room_along(d: Vector2) -> float:
	var s := 0.25
	while s <= 3.0:
		if Rules.offside(pos, p + d * s, dir):
			return s - 0.25
		s += 0.25
	return 3.0


## Picks her body's pose from what she is doing and blends to it (nothing jumps).
func _animate(dt: float) -> void:
	act_t += dt
	var spd := vel.length()
	# Strides: a stride pair is longer the faster she runs, so her feet keep pace with the floor.
	var pair := lerpf(1.3, 2.9, clampf(spd / 7.0, 0.0, 1.0))
	stride_phase = fposmod(stride_phase + spd / pair * dt, 1.0)
	var want: Dictionary
	match act:
		"hold":
			want = Poses.hold()
		"pass":
			want = Poses.pass_(act_kind, clampf(act_t / 0.45, 0.0, 1.0))
		"catch":
			want = Poses.catch_(clampf(act_t / 0.2, 0.0, 1.0), act_up)
		"shoot":
			want = Poses.shoot(clampf(act_t / 0.9, 0.0, 1.0))
		"defend":
			want = Poses.defend_ball(1.0)
		"defend_shot":
			want = Poses.defend_ball(1.0, true)
		"leap":
			want = Poses.leap(clampf(act_t / 0.7, 0.0, 1.0))
		"out_of_play":
			want = Poses.blend(Poses.ready(0.2), Poses.out_of_play(), 1.0)
		"cheer":
			want = Poses.cheer(act_t)
		"post":
			want = Poses.with_arms(Poses.run(stride_phase, spd), Poses.post(act_kind)) if spd > 0.3 else Poses.post(act_kind)
		"huddle":
			want = Poses.huddle()
		"mark":
			want = Poses.with_arms(Poses.run(stride_phase, spd), Poses.mark(1.0 if int(act_t * 0.7) % 2 == 0 else -1.0)) if spd > 0.6 else Poses.mark()
		_:
			want = Poses.run(stride_phase, spd) if spd > 0.3 else Poses.ready(0.9)
	if act == "run" or act == "ready":
		if spd > 0.3 and spd < 1.2:
			want = Poses.blend(Poses.ready(0.9), want, (spd - 0.3) / 0.9)
	var k := 1.0 - exp(-14.0 * dt)
	_pose = Poses.blend(_pose, want, k)
	# On her feet and moving, the legs and body (and, when they are free, the arms) come from the owner's Mixamo
	# clips in step with her stride; what her arms are doing (a catch, a pass, marking) stays the code's pose.
	var moving := spd > 0.3 and act in ["run", "ready", "mark", "post"]
	var arms_free := act == "run" or act == "ready"
	var kc := 1.0 - exp(-8.0 * dt)
	clip_body = lerpf(clip_body, smoothstep(0.3, 1.1, spd) if moving else 0.0, kc)
	clip_arms = lerpf(clip_arms, clip_body if arms_free else 0.0, kc)
	# Side-on to where she is going (marking, or keeping her eyes on the ball), she side-steps as a defender does
	# rather than running crabwise: the motion-capture slide, its cycle locked to how far she goes sideways.
	var lat := vel.dot(Vector2(cos(facing), -sin(facing)))   # toward her left (+) or right (-), m/s
	var want_slide := 0.0
	if moving:
		want_slide = smoothstep(0.6, 0.85, absf(lat) / maxf(spd, 0.01)) * (1.0 - smoothstep(SLIDE_TOP - 0.8, SLIDE_TOP, spd))
	slide = lerpf(slide, want_slide, kc)
	if absf(lat) > 0.2:
		slide_side = move_toward(slide_side, signf(lat), dt * 6.0)
	if slide > 0.01:
		slide_phase = fposmod(slide_phase + absf(lat) / (HeroBody.mocap_travel("slide_left") * _scale()) * dt, 1.0)
	# The landing with the ball: her legs and body from the motion capture while she holds it where she came down.
	if land_clip != "":
		land_t += dt
		var keep := stopped and act in ["hold", "catch"]
		land_w = lerpf(land_w, 1.0 if keep else 0.0, 1.0 - exp(-(30.0 if keep else 6.0) * dt))
		if not keep and land_w < 0.02:
			land_clip = ""
			land_w = 0.0
	if body:
		var out: Dictionary = _with_clips(_pose, spd) if clip_body > 0.01 and body is HeroBody else _pose
		if land_w > 0.01:
			out = _with_landing(out)
		body.apply(out)


## The landing laid over pose p (her legs and body; her arms, on the ball, stay p's), at the point of the clip
## that matches how far she has come since the catch.
func _with_landing(p: Dictionary) -> Dictionary:
	var t := maxf(HeroBody.mocap_time_at(land_clip, land_d), land_t0 + land_t - 0.15)
	var c := HeroBody.mocap_pose(land_clip, t)
	var out := p.duplicate()
	for i in ToonBody.BONES.size():
		var n: String = ToonBody.BONES[i][0]
		if n in _MOCAP_BONES:
			out[n] = HeroBody.turn(p.get(n, Vector3.ZERO)).slerp(c[0][i], land_w)
	var sh: Vector3 = c[1]
	out.hips_y = lerpf(float(p.get("hips_y", 0.0)), sh.y, land_w)
	out.hips_x = lerpf(float(p.get("hips_x", 0.0)), sh.x, land_w)
	out.hips_fwd = lerpf(float(p.get("hips_fwd", 0.0)), sh.z, land_w)
	return out


const _BODY_BONES := ["hips", "spine", "chest", "neck", "head", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const _ARM_BONES := ["upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]
## The bones the motion capture moves under her own pose: not her neck and head, which keep watching the play.
const _MOCAP_BONES := ["hips", "spine", "chest", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]


## The stride clips at her speed, phase-locked to her stride: the model's own walk, then her run, then the sprint
## (Fast_Run, shared with Hurling), each blended into the next; laid over the code pose p by clip_body and clip_arms.
func _with_clips(p: Dictionary, spd: float) -> Dictionary:
	var walk := HeroBody.stride_pose("Walking", stride_phase)
	var jog := HeroBody.stride_pose("Running", stride_phase)
	var sprint := HeroBody.stride_pose("Fast_Run", stride_phase)
	var a := smoothstep(1.8, 3.2, spd)       # walk -> run
	var b := smoothstep(4.0, 5.6, spd)       # run -> sprint
	# The side-step (slide_left or slide_right, the way she is going), and how much of it: through the middle of a
	# change of direction it gives way to the run.
	var ws := slide * absf(slide_side)
	var sl: Array = []
	if ws > 0.01:
		var sname := "slide_left" if slide_side > 0.0 else "slide_right"
		sl = HeroBody.mocap_pose(sname, slide_phase * HeroBody.mocap_length(sname), true)
	var out := p.duplicate()
	for i in ToonBody.BONES.size():
		var n: String = ToonBody.BONES[i][0]
		var body_bone: bool = n in _BODY_BONES
		var w := clip_body if body_bone else clip_arms
		var q: Quaternion = (walk[0][i] as Quaternion).slerp(jog[0][i], a).slerp(sprint[0][i], b)
		if not sl.is_empty():
			# The whole of her goes with the slide, arms out wide and balanced as a defender's are (the run's
			# swinging arms and its head, set for an upright torso, do not sit on the slide's crouch).
			q = q.slerp(sl[0][i], ws)
			if not body_bone:
				w = maxf(w, clip_body * ws)
		if w <= 0.0:
			continue
		out[n] = HeroBody.turn(p.get(n, Vector3.ZERO)).slerp(q, w)
	var lift := lerpf(lerpf(float(walk[1]), float(jog[1]), a), float(sprint[1]), b)
	var shift := Vector3(0.0, lift, 0.0)
	if not sl.is_empty():
		shift = shift.lerp(sl[1], ws)
	out.hips_y = lerpf(float(p.get("hips_y", 0.0)), shift.y, clip_body)
	out.hips_x = shift.x * clip_body
	out.hips_fwd = shift.z * clip_body
	return out


## Her body's size against the model's (the clips' metres are the model's).
func _scale() -> float:
	return body.scale.x if body else 1.0


## She has caught the ball on the move and lands on foot ("l", "r"; "both" when she was all but stopped): the
## landing from the motion capture, picked up at the moment of its stride that matches her speed.
func start_landing(foot: String) -> void:
	land_clip = ""
	var spd := vel.length()
	if foot == "both" or spd < LAND_MIN or not (body is HeroBody):
		return
	land_clip = "land_" + foot
	land_dir = vel / spd
	land_d = HeroBody.mocap_travel_at_speed(land_clip, spd / _scale())
	land_t = 0.0
	land_t0 = HeroBody.mocap_time_at(land_clip, land_d)
	# Where her landing foot comes down: ahead of her by what is left of the clip's path to that moment.
	var at := HeroBody.mocap_plant_at(land_clip, foot)   # the foot against the clip's path then (her left, ahead)
	var left := Vector2(land_dir.y, -land_dir.x)
	landing = p + (land_dir * (maxf(0.0, HeroBody.mocap_plant_travel(land_clip, foot) - land_d) + at.y) + left * at.x) * _scale()
	if fenced and Rules.offside(pos, landing, dir) and not Rules.offside(pos, p, dir):
		landing = Rules.onside_point(pos, landing, dir, 0.02)


func set_act(a: String, kind := "") -> void:
	if a == act and kind == act_kind:
		return
	act = a
	act_kind = kind
	act_t = 0.0


## Where her hands hold the ball, in the world.
func hand_point() -> Vector3:
	if body == null or body.skeleton == null:
		return position + Vector3(0, 1.3, 0)
	return (body.bone_world("hand_l") + body.bone_world("hand_r")) * 0.5 + Vector3(0, -0.04, 0)


## The height she can reach for a ball, standing (and with a leap).
func reach(leap := false) -> float:
	var h := float(data.get("height", 1.75))
	return h * 1.28 + (0.45 if leap else 0.0)


## Not available to play: out of play for a penalty, or suspended.
func away() -> bool:
	return out_until > 0.0 or suspended > 0.0


func tag() -> String:
	return pos


func surname() -> String:
	var n := String(data.get("name", ""))
	var i := n.find(" ")
	return n.substr(i + 1) if i > 0 else n
