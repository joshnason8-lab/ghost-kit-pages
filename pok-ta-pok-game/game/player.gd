class_name Player
extends Node3D
## A player: where he is and how he moves, what he is doing (running, a hip strike, a dive, the serve) and how he
## looks doing it. Each frame the match calls update() once and only update() moves him (the one writer of his
## position, as Kabaddi's motion audit asked): toward where his brain (TeamAI, or your thumb) wants him, no faster
## than he can run and no quicker than he can speed up, turn and stop. His strides match the ground he covers.

const ACCEL := 9.0            # m/s²: from a standstill to full speed in about two-thirds of a second
const DECEL := 13.0
const TURN := 9.0             # how quickly he turns to face where he is going (rad/s at most, eased)
const HIP_H := 0.7            # how high his hip meets the ball in a hip strike (m), sunk in the stance
const DIVE_H := 0.24          # and in a dive, on the ground
const REACH := 0.62           # how far from his hip the ball can be and still be met
const STRIKE_MIN_Y := 0.34    # standing, the hip cannot get under a ball lower than this (its centre, m): dive for it
const BODY_R := 0.16          # his body, for the ball touching it (R6)

enum A { NONE, STRIKE, DIVE, SERVE, CELEBRATE, DEJECTED }

var team := 0
var num := 1
var role := ""                # chivero, topador, medio, malero (docs/RULES.md "Positions")
var pname := ""
var look := {}
var body: Body
var vel := Vector3.ZERO
var yaw := 0.0
var max_speed := 6.2
var skill := 0.6              # 0-1: timing, reading and power
var power := 0.6
var want := Vector3.ZERO      # where he wants to be (AI), or
var want_dir := Vector3.ZERO  # the way your thumb pushes (length 0-1)
var steer_by_dir := false
var face_to := Vector3.INF    # a point to face when standing (the ball)
var face_yaw := NAN           # a way to face, side-on, as the ball comes (TeamAI)
var action := A.NONE
var action_t := 0.0
var action_side := 1.0
var action_aim := Vector3.ZERO
var hit_done := false         # this strike has met the ball
var immune := 0.0             # just struck it: the ball leaving him is not a touch
var recent_attempt := 0.0     # swung at it lately: a near miss is not then a body-touch fault
var phase := 0.0              # the run's cycle
var action_ring := 0          # a strike aimed at the ring on that side (classic court), or 0
var steps_taken := 0          # steps since the tests last read it
var blocked := false          # stopped by a line or wall this frame (the audit counts these apart)
var written := Vector3.INF     # where update() last put him (the movement audit: nothing else moves him)
var low := 0.5                # how low he sits: lower as the ball comes
var user := false             # you play him
var stats := {"strikes": 0, "dives": 0, "rayas": 0, "faults": 0, "serves": 0}
var _t := 0.0
var _half_step := 0


func setup(p_team: int, p_num: int, p_look: Dictionary) -> void:
	team = p_team
	num = p_num
	look = p_look
	body = Body.new(p_look)
	add_child(body)


func set_lod(l: int) -> void:
	if body:
		body.set_lod(l)


func busy() -> bool:
	return action in [A.STRIKE, A.DIVE, A.SERVE]


## Starts a hip strike with the side's hip (1 left, -1 right), aiming the ball toward aim.
func start_strike(side: float, aim: Vector3, ring := 0) -> bool:
	if busy():
		return false
	action_ring = ring
	action = A.STRIKE
	action_t = 0.0
	action_side = side
	action_aim = aim
	hit_done = false
	stats.strikes += 1
	return true


func start_dive(side: float, aim: Vector3) -> bool:
	if busy():
		return false
	action = A.DIVE
	action_t = 0.0
	action_side = side
	action_aim = aim
	hit_done = false
	stats.dives += 1
	return true


func start_serve(high: bool) -> void:
	action = A.SERVE
	action_t = 0.0
	action_side = 1.0 if high else 0.0
	hit_done = false


func react(won: bool) -> void:
	if busy():
		return
	action = A.CELEBRATE if won else A.DEJECTED
	action_t = 0.0


func calm() -> void:
	if action in [A.CELEBRATE, A.DEJECTED]:
		action = A.NONE


## How far into the action, 0-1.
func action_u() -> float:
	match action:
		A.STRIKE:
			return action_t / Moves.STRIKE_T
		A.DIVE:
			return action_t / Moves.DIVE_T
		A.SERVE:
			return action_t / Moves.SERVE_T
	return 0.0


## Is the hip able to meet the ball now (the strike's or dive's moment, give or take)? Returns how good the moment
## is, 0-1, or -1 when not.
func hit_window() -> float:
	if hit_done:
		return -1.0
	var hit := Moves.STRIKE_HIT if action == A.STRIKE else Moves.DIVE_HIT
	var len := Moves.STRIKE_T if action == A.STRIKE else Moves.DIVE_T
	if action != A.STRIKE and action != A.DIVE:
		return -1.0
	var dt := absf(action_t - hit * len)
	var half := 0.13
	if dt > half:
		return -1.0
	return 1.0 - dt / half


## Where his hip is in the world when meeting the ball: the side's hip, at a strike's height or a dive's.
func hip_point() -> Vector3:
	var right := Vector3(cos(yaw), 0, -sin(yaw))   # his left is +X locally: basis x
	var h := HIP_H if action != A.DIVE else DIVE_H
	var out := 0.2 if action != A.DIVE else 0.45
	return global_position + Vector3(0, h, 0) + right * action_side * out


## Forward, flat.
func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


## The one place this player's position is written. dt seconds; court for where he may stand; half_x for his own half's
## limit (he stays on his side of the analco: half_x is the analco, his side given by dir).
func update(dt: float, court: Court, dirn: float, can_cross := false) -> void:
	_t += dt
	if action != A.NONE:
		action_t += dt
	immune = maxf(0.0, immune - dt)
	recent_attempt = maxf(0.0, recent_attempt - dt)
	if action in [A.STRIKE, A.DIVE]:
		recent_attempt = 0.5
	var desired := Vector3.ZERO
	var top := max_speed
	if action == A.STRIKE:
		top *= 0.35
	elif action == A.DIVE:
		top = 0.0
	elif action == A.SERVE:
		top = 0.0
	if steer_by_dir:
		desired = Vector3(want_dir.x, 0, want_dir.z)
		if desired.length() > 1.0:
			desired = desired.normalized()
		desired *= top
	else:
		var to := want - global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.05:
			# Arrive: slow down to stop on the spot.
			var sp := minf(top, sqrt(2.0 * DECEL * 0.8 * d))
			desired = to / d * sp
	# The dive carries him a little toward the ball as he goes down.
	if action == A.DIVE and action_t < Moves.DIVE_T * Moves.DIVE_HIT:
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		desired = right * action_side * 2.6
	# Lines and walls ahead: he slows to stop at them rather than running into them.
	var here := global_position
	var bnd := court.bounds_at(here)
	var x_lo: float = bnd[0]
	var x_hi: float = bnd[1]
	if not can_cross:
		if dirn > 0.0:
			x_hi = minf(x_hi, -0.4)
		else:
			x_lo = maxf(x_lo, 0.4)
	var z_lo: float = bnd[2]
	var z_hi: float = bnd[3]
	var room := func(d: float) -> float: return sqrt(2.0 * DECEL * 0.3 * maxf(0.0, d))
	if desired.x > 0.0:
		desired.x = minf(desired.x, room.call(x_hi - here.x))
	else:
		desired.x = maxf(desired.x, -room.call(here.x - x_lo))
	if desired.z > 0.0:
		desired.z = minf(desired.z, room.call(z_hi - here.z))
	else:
		desired.z = maxf(desired.z, -room.call(here.z - z_lo))
	var dv := desired - vel
	# Braking on either axis (a wall ahead), he brakes as hard as he can.
	var braking := absf(desired.x) < absf(vel.x) - 0.01 or absf(desired.z) < absf(vel.z) - 0.01
	var lim := (ACCEL if desired.length() > vel.length() and not braking else DECEL) * dt
	if dv.length() > lim:
		dv = dv.normalized() * lim
	vel += dv
	vel.y = 0.0
	var p := global_position + vel * dt
	var keep := court.clamp_feet(p)
	if not can_cross:
		# His own side of the analco.
		if (keep.x - 0.0) * dirn > -0.4:
			keep.x = -0.4 * dirn
	blocked = keep.distance_to(p) > 0.001
	if blocked:
		# Stopped by a line or a wall: what he cannot go on with, he loses.
		var lost := (p - keep) / dt
		vel -= lost
	global_position = keep
	written = keep
	# Facing: where he runs; standing, the ball; striking, as he was.
	if not busy():
		var face := yaw
		var hs := Vector2(vel.x, vel.z).length()
		if not is_nan(face_yaw):
			face = face_yaw
		elif hs > 1.2:
			face = atan2(vel.x, vel.z)
		elif face_to != Vector3.INF:
			var f := face_to - global_position
			if Vector2(f.x, f.z).length() > 0.3:
				face = atan2(f.x, f.z)
		yaw = rotate_toward(yaw, face, TURN * dt)
	rotation = Vector3(0, yaw, 0)
	# Strides: a cycle is two steps; a step about 0.9 m at a jog to 1.7 at a sprint, for a man of 1.80 (shorter legs,
	# shorter steps: the recorded run's feet stay planted at any height).
	var speed := Vector2(vel.x, vel.z).length()
	var stride := Player.stride_at(speed) * (body.scale.x if body else 1.0)
	phase += speed / (2.0 * stride) * dt
	var hs2 := int(floor(phase * 2.0))
	if hs2 != _half_step:
		if speed > 0.3:
			steps_taken += absi(hs2 - _half_step)
		_half_step = hs2
	_pose(speed)
	if action == A.STRIKE and action_t >= Moves.STRIKE_T:
		action = A.NONE
	elif action == A.DIVE and action_t >= Moves.DIVE_T:
		action = A.NONE
	elif action == A.SERVE and action_t >= Moves.SERVE_T:
		action = A.NONE
	elif action in [A.CELEBRATE, A.DEJECTED] and action_t > 2.6:
		action = A.NONE


## A step's length (m) at a speed, for a man of 1.80.
static func stride_at(speed: float) -> float:
	return 0.9 + 0.12 * speed


func _pose(speed: float) -> void:
	if body == null:
		return
	var p: Dictionary
	match action:
		A.STRIKE:
			p = Moves.hip_strike(action_u(), action_side)
		A.DIVE:
			p = Moves.dive(action_u(), action_side)
		A.SERVE:
			p = Moves.serve(action_u(), action_side > 0.5)
		A.CELEBRATE:
			p = Moves.celebrate(action_t)
		A.DEJECTED:
			p = Moves.dejected(action_t)
		_:
			var st := Moves.stance(_t + num, low)
			if speed > 0.25:
				var w := clampf(speed / 2.0, 0.0, 1.0)
				var run := Moves.run(phase, speed, low * 0.5)
				# At a run, the recorded run (Mocap.RUN) takes over from the hand-made one; crouched less so.
				var rw := smoothstep(2.0, 3.2, speed) * (1.0 - low * 0.6)
				if rw > 0.0:
					var rec := Mocap.run(phase)
					if not rec.is_empty():
						run = Moves.blend(run, rec, rw)
				p = Moves.blend(st, run, w)
			else:
				p = st
	body.apply(p)
