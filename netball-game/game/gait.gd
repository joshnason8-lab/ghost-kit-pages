class_name Gait
extends RefCounted
## The one place a body's locomotion is made, for the players and the umpires on every graphics level (the game's own
## seventeen bones: HeroBody, ToonBody): where each foot is on the floor, the legs reaching it, the hips, the lean and
## the arms' swing. The game's moves (Player: the catch, the pass, holding the ball, defending, the leap) are laid
## over what it makes; a locomotor that supplies the legs and arms another way (the shared foundation's, later) takes
## this one's place behind the same calls: update(), loco_pose(), solve().
##
## Her feet step with the ground, never glide: the stride's phase goes on by the distance she covers (a stride pair
## is longer the faster she goes), each foot comes down where her hips will be over it and stays there, rolling from
## the heel onto the ball of the foot, until it lifts; the leg reaches it (two-bone IK) wherever she runs, forwards,
## sideways or backwards. Slowing to a stop, the foot in the air comes down and the other is brought alongside in a
## step; standing, she steps to keep her feet under her as she edges or turns. Her arms swing against her legs, bent
## at the elbow, close to her sides.
##
## Space: world positions are court metres (x, z); the body's local space is the figure's (ToonBody: she faces +Z, her
## left +X, soles at y = 0), scaled by her height.

const TOE := 0.11            # the ankle to the ball of the foot (the figure's m)
const HEEL := 0.05           # the ankle to the back of the heel
const REACH := 0.99          # of the leg's full length, at most (never quite straight)
const ON := 0.7              # m/s: faster than this the stride's phase drives the feet
const OFF := 0.45            # slower than this she stops striding (and settles her feet in steps of their own)
const SETTLE_T := 0.26       # s: a step of her own (standing, edging, turning)
const SETTLE_AT := 0.13      # m (of the figure) a foot may be from its place under her before she steps
const SETTLE_TURN := 0.6     # rad a foot may point away from her before she steps round
const MIN_SWING := 0.25      # of a stride pair: the shortest swing a foot takes
const LAND_OVER := 0.85      # of a swing or a step: the foot is over its spot, and comes straight down on it

var body: ToonBody
var phase := 0.0             # through a stride pair (0-1): the left foot comes down at 0, the right at 0.5
var striding := false
var speed := 0.0             # m/s over the floor
var move := 0.0              # how much she is on the move (0 standing .. 1 running), for laying the game's moves over
var dir := Vector2(0, 1)     # her direction of travel (world), last kept
var yaw := 0.0               # where her body faces (world yaw; 0 faces +z)
var width := 0.0             # extra width between her feet standing (each side, m of the figure): marking, posting
var pinned := Vector2.INF    # a foot that may not step (her landing foot while she holds the ball), world x, z
var feet: Array = []         # [left, right] Foot
var side_on := 0.0           # how much she is going sideways (0 forwards or back .. 1 a side-step)
var epoch := 0               # counts the times the feet were put down afresh (reset, follow_body): not steps
var swing := 0.0             # the arms' swing (-1 .. 1: the left leg furthest back .. forward)
var _pos := Vector2.INF
var _st := Vector2(0.6, 0.0)  # this frame's stride: (duty, how far ahead a foot comes down)
var _sc := 1.0
var _hip_h := 0.9            # the hip joint's height at rest (figure m)
var _ankle_h := 0.07         # the ankle's height at rest, the foot flat
var _leg := 0.84             # thigh + shin
var _hip_w := 0.095          # the hip joint's x
var _off := []               # each bone's rest offset
var _len := {}


class Foot:
	var side := 1.0          # +1 left, -1 right
	var down := true
	var at := Vector2.ZERO   # planted: the ankle's spot on the floor, the foot flat (world)
	var yaw := 0.0
	var u := 0.4             # through the stance (0 the heel down .. 1 lifting), for the roll
	var from := Vector3.ZERO # swinging: the ankle where it lifted (world)
	var from_yaw := 0.0
	var from_pitch := 0.0
	var to := Vector2.ZERO   # where it will come down (the flat ankle's spot)
	var to_yaw := 0.0
	var s := 0.0             # through the swing (0-1)
	var lift_psi := 0.0      # the stride's phase it lifted at
	var settle := false      # a step of her own (timed), not the stride's
	var h := 0.06            # the step's height (world m)
	var ankle := Vector3.ZERO  # this frame: where the ankle goes (world)
	var pitch := 0.0           # and the foot's pitch (rad, toe down +)
	var fyaw := 0.0            # and its heading (world)


func _init(p_body: ToonBody) -> void:
	body = p_body
	feet = [Foot.new(), Foot.new()]
	feet[1].side = -1.0


## The figure's measures, from its skeleton (once it is built).
func _measure() -> bool:
	if not _off.is_empty():
		return true
	if body == null or body.skeleton == null:
		return false
	var sk := body.skeleton
	for i in sk.get_bone_count():
		_off.append(sk.get_bone_rest(i).origin)
	var th: Vector3 = _off[body.bone("thigh_l")]
	_hip_h = (_off[0] as Vector3).y + th.y
	_hip_w = absf(th.x)
	for s in ["l", "r"]:
		_len[s] = [(_off[body.bone("shin_" + s)] as Vector3).length(), (_off[body.bone("foot_" + s)] as Vector3).length()]
	_leg = float(_len.l[0]) + float(_len.l[1])
	_ankle_h = _hip_h - _leg
	return true


# ---------------------------------------------------------------- the stride's measures (the figure's m, by speed)

## A stride pair's length (m of the figure) at speed v (m/s): 1.1 m walking, 2.15 jogging, 3.5 sprinting.
static func pair_length(v: float) -> float:
	return _curve(v, [0.0, 0.7, 1.4, 1.1, 2.5, 1.65, 3.5, 2.15, 5.0, 2.75, 7.0, 3.5, 9.0, 3.9])


## The stride pair she takes (m of the figure): shorter side-stepping.
func _pair(v: float) -> float:
	return pair_length(v) * lerpf(1.0, 0.7, side_on)


## How far the hips sink (m of the figure) at speed v: a running crouch.
static func drop(v: float) -> float:
	return _curve(v, [0.0, 0.0, 1.4, 0.025, 3.5, 0.055, 7.0, 0.075])


static func _curve(v: float, pts: Array) -> float:
	if v <= pts[0]:
		return pts[1]
	for i in range(2, pts.size(), 2):
		if v <= pts[i]:
			return lerpf(pts[i - 1], pts[i + 1], (v - pts[i - 2]) / (pts[i] - pts[i - 2]))
	return pts[pts.size() - 1]


## How much of the stride a foot is down (the stride's duty) and how far ahead of the hips it comes down (m of the
## figure), at speed v: as far as the leg reaches with the hips at their height, front and back.
func _stance(v: float) -> Vector2:
	var hip := _hip_h - drop(v)
	var r := _leg * REACH
	var j := smoothstep(1.4, 3.0, v)
	# Coming down: the ankle a little higher on the heel (walking) or flat (running); lifting, on the ball of the foot.
	var hs := _ankle_at_roll(lerpf(-0.21, -0.05, j))
	var to := _ankle_at_roll(lerpf(0.55, 0.7, j))
	var front := sqrt(maxf(0.0, r * r - pow(hip - hs.y, 2))) - hs.x
	var back := sqrt(maxf(0.0, r * r - pow(hip - to.y, 2))) + to.x
	var s := (front + back) * 0.96 * lerpf(0.55, 1.0, smoothstep(0.0, 1.2, v))
	var l := _pair(v)
	var duty := clampf(s / l, 0.22, 0.62)
	s = duty * l
	return Vector2(duty, s * front / (front + back))


## Where the ankle is against the foot's flat spot, rolled by pitch (rad; on the heel when negative, the ball of the
## foot when positive): (forward, up), m of the figure.
func _ankle_at_roll(pitch: float) -> Vector2:
	if pitch >= 0.0:
		return Vector2(TOE - (TOE * cos(pitch) - _ankle_h * sin(pitch)), TOE * sin(pitch) + _ankle_h * cos(pitch))
	return Vector2(-HEEL + (HEEL * cos(pitch) + _ankle_h * sin(pitch)), -HEEL * sin(pitch) + _ankle_h * cos(pitch))


# ---------------------------------------------------------------- each frame

## Put down where she stands (a new body, a restart): both feet under her.
func reset(pos: Vector2, p_yaw: float) -> void:
	_pos = pos
	yaw = p_yaw
	epoch += 1
	striding = false
	speed = 0.0
	move = 0.0
	for f: Foot in feet:
		f.down = true
		f.settle = false
		f.at = _home(f, pos)
		f.yaw = p_yaw
		f.u = 0.4


## Moves the feet on for this frame: pos is where she is (world x, z), vel how fast she is going, p_yaw where her
## body faces.
func update(dt: float, pos: Vector2, vel: Vector2, p_yaw: float) -> void:
	if not _measure():
		return
	_sc = body.global_transform.basis.get_scale().x if body.is_inside_tree() else body.scale.x
	if _pos == Vector2.INF or pos.distance_to(_pos) > 1.5:
		reset(pos, p_yaw)
	var dist := pos.distance_to(_pos)
	_pos = pos
	yaw = p_yaw
	speed = vel.length()
	if speed > 0.05:
		dir = vel / speed
	move = smoothstep(0.3, 1.5, speed)
	side_on = smoothstep(0.55, 0.9, absf(dir.dot(_left())))
	var st := _stance(speed)
	_st = st
	var duty := st.x
	var l := _pair(speed) * _sc
	if not striding and speed > ON and not _any_settling():
		_start_striding(pos, st, l)
	elif striding and speed < OFF:
		striding = false
		for f: Foot in feet:
			if not f.down:
				# (The foot in the air finishes as a step of her own, from where it is now: carried on from where it
				# lifted, it went back there in a frame and dragged along the floor to its place.)
				f.settle = true
				f.from = f.ankle
				f.from_yaw = f.fyaw
				f.from_pitch = f.pitch
				f.s = 0.0
				f.h = maxf(f.h, 0.08 * _sc)
	if striding:
		var was := phase
		phase = fposmod(phase + dist / l, 1.0)
		for f: Foot in feet:
			var psi := fposmod(phase - (0.0 if f.side > 0.0 else 0.5), 1.0)
			var prev := fposmod(was - (0.0 if f.side > 0.0 else 0.5), 1.0)
			if f.down:
				# (It lifts when the stride says, or sooner if her hips have left it behind further than it reaches:
				# a sudden change of pace or direction.)
				var behind := -(f.at - pos).dot(dir) / _sc
				if (psi >= duty and psi < 0.995 and prev <= psi) or behind > (duty * l / _sc - st.y) * 1.2 + 0.05:
					_lift(f, psi)
				else:
					f.u = clampf(psi / duty, 0.0, 1.0) if prev <= psi else 0.0
			else:
				# Through its swing by the stride's phase, coming down at the swing's end - and never a swing shorter than
				# MIN_SWING of the stride: a foot lifted as the stride started, late in its own phase, went the whole way
				# in two frames (87 cm in one: WsgSim's Low matches, a jump).
				var span := maxf(1.0 - f.lift_psi, MIN_SWING)
				f.s = minf(1.0, f.s + fposmod(psi - prev, 1.0) / span)
				if f.s >= 1.0:
					_land(f)
				elif f.s < LAND_OVER:
					# (Its spot kept from there: following her pace on, it slid in its last few cm - _place.)
					var rest := (1.0 - f.s) * span * l
					f.to = pos + dir * (rest + st.y * _sc) + _left() * f.side * _width_run() * _sc
					f.to_yaw = yaw
	else:
		_settle(dt, pos, vel)
	for f: Foot in feet:
		_place(f, st, duty)
	_swing()


func _any_settling() -> bool:
	for f: Foot in feet:
		if not f.down:
			return true
	return false


## Setting off: the stride's phase taken from where her feet are: the foot further ahead is down as if it came down
## there (so it stays down only as long as it can reach), the other lifts as soon as the stride asks.
func _start_striding(pos: Vector2, st: Vector2, l: float) -> void:
	striding = true
	var ahead: Foot = feet[0]
	if (feet[1].at - pos).dot(dir) > (feet[0].at - pos).dot(dir):
		ahead = feet[1]
	var along := (ahead.at - pos).dot(dir)
	var psi := clampf((st.y * _sc - along) / l, 0.0, st.x - 0.02)
	phase = fposmod(psi + (0.0 if ahead.side > 0.0 else 0.5), 1.0)
	for f: Foot in feet:
		f.u = 0.4


func _lift(f: Foot, psi: float) -> void:
	f.down = false
	f.settle = false
	f.lift_psi = psi
	f.s = 0.0
	f.from = _planted_ankle(f)
	f.from_yaw = f.yaw
	f.from_pitch = _roll(f.u)
	f.to = f.at
	f.to_yaw = f.yaw
	var j := smoothstep(1.4, 3.0, speed)
	var k := clampf(speed / 7.0, 0.0, 1.0)
	# (Never skimming the floor: a side-step's low swing came in flat and still going - a skid as it touched.)
	f.h = maxf(lerpf(0.05, lerpf(0.17, 0.48, k), j) * lerpf(1.0, 0.45, side_on), 0.045) * _sc


func _land(f: Foot) -> void:
	f.down = true
	f.settle = false
	f.at = f.to
	f.yaw = f.to_yaw
	f.u = 0.0
	f.s = 0.0


## Standing or edging: a foot strayed from under her (or turned away) steps back under her, one at a time; the landing
## foot (pinned) stays.
func _settle(dt: float, pos: Vector2, vel: Vector2) -> void:
	var stepping := false
	for f: Foot in feet:
		if f.down:
			f.u = move_toward(f.u, 0.4, dt * 3.0)
			continue
		stepping = true
		var rate := 1.0 / SETTLE_T
		if not f.settle:
			rate = maxf(rate, 1.0 / 0.18)
		f.s = minf(1.0, f.s + dt * rate)
		if f.s < LAND_OVER:
			# (Over its spot from 85% of the step, it comes straight down there: still following her then, it landed
			# 2-3.5 cm on from where it was coming down, a slide as it touched.)
			f.to = _home(f, pos + vel * (1.0 - f.s) * SETTLE_T)
			f.to_yaw = yaw
		if f.s >= 1.0:
			_land(f)
			f.u = 0.4
	if stepping:
		return
	var worst: Foot = null
	var err := 0.0
	for f: Foot in feet:
		if pinned != Vector2.INF and f.at.distance_to(pinned) < 0.25:
			# (Pivoting on it: it turns on the ball of the foot, where it is.)
			var ball := f.at + _fwd(f.yaw) * TOE * _sc
			f.yaw = rotate_toward(f.yaw, yaw, dt * 6.0)
			f.at = ball - _fwd(f.yaw) * TOE * _sc
			continue
		var e := f.at.distance_to(_home(f, pos)) / (SETTLE_AT * _sc)
		e = maxf(e, absf(angle_difference(f.yaw, yaw)) / SETTLE_TURN)
		if e > 1.0 and e > err:
			err = e
			worst = f
	if worst:
		worst.down = false
		worst.settle = true
		worst.s = 0.0
		worst.from = _planted_ankle(worst)
		worst.from_yaw = worst.yaw
		worst.from_pitch = _roll(worst.u)
		worst.h = 0.08 * _sc
		worst.to = _home(worst, pos)
		worst.to_yaw = yaw


## A foot's place standing: under her hip, a little wider marking or posting.
func _home(f: Foot, pos: Vector2) -> Vector2:
	return pos + _left() * f.side * (_hip_w + width) * _sc


## How far from her line each foot comes down on the run: under her running forwards or back; side-stepping, wide,
## so her feet never cross.
func _width_run() -> float:
	return lerpf(lerpf(_hip_w, 0.045, smoothstep(0.5, 3.0, speed)), 0.18, side_on)


func _left() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


static func _fwd(y: float) -> Vector2:
	return Vector2(sin(y), cos(y))


## The roll through the stance (u 0-1): on the heel as it comes down (walking), flat, onto the ball as it lifts.
func _roll(u: float) -> float:
	var j := smoothstep(1.4, 3.0, speed)
	var hs := lerpf(-0.21, -0.05, j) * (1.0 - smoothstep(0.0, 0.22, u))
	var to := lerpf(0.55, 0.7, j) * smoothstep(0.55, 1.0, u)
	return hs + to


## A planted foot's ankle (world), rolled on its heel or its ball, which stays where it is on the floor.
func _planted_ankle(f: Foot) -> Vector3:
	var r := _ankle_at_roll(_roll(f.u)) * _sc
	var fw := _fwd(f.yaw)
	var g := f.at + fw * r.x
	return Vector3(g.x, r.y, g.y)


## Where each foot's ankle goes this frame, its pitch and heading.
func _place(f: Foot, st: Vector2, _duty: float) -> void:
	if f.down:
		f.ankle = _planted_ankle(f)
		f.pitch = _roll(f.u)
		f.fyaw = f.yaw
		return
	var j := smoothstep(1.4, 3.0, speed)
	var k := clampf(speed / 7.0, 0.0, 1.0)
	var land_pitch := lerpf(-0.21, -0.05, j) if not f.settle else 0.0
	var a1 := _ankle_at_roll(land_pitch) * _sc
	var to := f.to + _fwd(f.to_yaw) * a1.x
	# Running, the heel comes up behind first and the foot reaches forward late (the knee drives through, the shin
	# swings out under it); a walk's or a settling step's foot goes evenly.
	# The toe clears the floor before the foot goes anywhere, and it comes down where it lands: a foot dragged along
	# the floor its first or last frames off it - lifting at a walk or a side-step, a step of her own standing, the
	# step that brings her feet together as she stops - is a planted foot sliding (the world check's feet_low read
	# 2.7 cm walking; WsgSim's Low matches 3-10 cm). Walking, the foot rises in place for the swing's first tenth, and
	# at any pace it is over its spot by LAND_OVER of the swing and comes straight down on it (low and flat, still
	# going, it read as skidding: 2-7 cm in a frame); a step of her own goes over between 15% and 85% of it.
	var lag := lerpf(1.3, lerpf(1.35, 1.6, k), j) if not f.settle else 1.0
	var s0 := 0.1 * (1.0 - j)
	var e := smoothstep(0.15, LAND_OVER, f.s) if f.settle else \
		smoothstep(0.0, 1.0, pow(clampf((f.s - s0) / (LAND_OVER - s0), 0.0, 1.0), lag))
	var g := Vector2(f.from.x, f.from.z).lerp(to, e)
	var peak := lerpf(0.6, lerpf(0.72, 0.6, k), j) if not f.settle else 1.0
	var y := lerpf(f.from.y, a1.y, f.s) + f.h * sin(PI * pow(f.s, peak))
	f.ankle = Vector3(g.x, y, g.y)
	var hang := 0.45 * k * j if not f.settle else 0.0
	f.pitch = lerpf(f.from_pitch, land_pitch, smoothstep(0.15, 0.9, f.s)) + hang * sin(PI * f.s)
	f.fyaw = lerp_angle(f.from_yaw, f.to_yaw, e)


## The arms' swing, against the legs: from how far each foot is ahead of the other along her heading.
func _swing() -> void:
	var fw := _fwd(yaw)
	var a: Foot = feet[0]
	var b: Foot = feet[1]
	var dz := (Vector2(a.ankle.x, a.ankle.z) - Vector2(b.ankle.x, b.ankle.z)).dot(fw) / _sc
	var span := maxf(_st.y * 2.2, 0.25)
	swing = clampf(dz / span, -1.0, 1.0)


# ---------------------------------------------------------------- the pose

## Her locomotion from the hips up (degrees, as Poses has them): the lean, the hips' sink and bob, the twist, and the
## arms swinging bent at the elbow, close to her sides. Her legs are solve()'s.
func loco_pose() -> Dictionary:
	var j := smoothstep(1.4, 3.0, speed)          # walking .. running
	var k := clampf(speed / 7.0, 0.0, 1.0)        # .. sprinting
	var m := move
	var q := swing
	var bob := 0.0
	if striding:
		var duty := _st.x
		bob = -cos(TAU * 2.0 * (phase - duty * 0.5)) * lerpf(0.008, 0.022, j) * m
	var arm := lerpf(16.0, lerpf(34.0, 52.0, k), j) * m
	var bend := lerpf(22.0, lerpf(78.0, 92.0, k), j) * m + 8.0
	var lean := (3.0 + 9.0 * j + 14.0 * k) * m
	return {
		"hips_y": -drop(speed) * m + bob,
		"hips": Vector3(lean * 0.25, -5.0 * q * j * m, 0),
		"spine": Vector3(lean * 0.45, 4.0 * q * j * m, 0),
		"chest": Vector3(lean * 0.4, 6.0 * q * j * m, 0),
		"neck": Vector3.ZERO,
		"head": Vector3(-lean * 0.5, -5.0 * q * j * m, 0),
		# The left arm goes back as the left leg comes through (q > 0: the left foot ahead); the elbow folds a little
		# more as the arm comes forward.
		"upperarm_l": Vector3(-4.0 * m + arm * q * (1.0 if q > 0.0 else 0.75), 0, 7),
		"forearm_l": Vector3(-bend - 14.0 * maxf(0.0, -q) * j, -12.0 * j, 0),
		"hand_l": Vector3(0, 0, -6),
		"upperarm_r": Vector3(-4.0 * m - arm * q * (1.0 if q < 0.0 else 0.75), 0, -7),
		"forearm_r": Vector3(-bend - 14.0 * maxf(0.0, q) * j, 12.0 * j, 0),
		"hand_r": Vector3(0, 0, 6),
	}


## Her legs reaching her feet (two-bone IK), into pose p (bone -> degrees or Quaternion; hips_y and the hips' turn
## taken as they are, the hips lowered if a planted foot is out of reach); w: how much of the legs is this (the rest
## stays p's: a leap, a landing).
func solve(p: Dictionary, w := 1.0) -> Dictionary:
	if w <= 0.0 or not _measure() or not body.is_inside_tree():
		return p
	var out := p.duplicate()
	var inv := body.global_transform.affine_inverse()
	var qh := HeroBody.turn(p.get("hips", Vector3.ZERO))
	var hips := (_off[0] as Vector3) + Vector3(float(p.get("hips_x", 0.0)), float(p.get("hips_y", 0.0)),
		float(p.get("hips_fwd", 0.0)))
	# The hips no higher than both planted feet (and a foot about to come down) can reach.
	var cap := INF
	for i in 2:
		var f: Foot = feet[i]
		var s := "l" if i == 0 else "r"
		# (And a foot just lifted, still behind her: hips risen at once left it out of the leg's reach, the drawn foot
		# dragged after the ball of the foot as it left the floor - 1.8 cm a frame at a run.)
		var wt := 1.0 if f.down else maxf(smoothstep(0.75, 1.0, f.s), 1.0 - smoothstep(0.0, 0.3, f.s))
		if wt <= 0.0:
			continue
		var a: Vector3 = inv * f.ankle
		var jo := qh * (_off[body.bone("thigh_" + s)] as Vector3)
		var r := (float(_len[s][0]) + float(_len[s][1])) * REACH
		var hz := Vector2(a.x - hips.x - jo.x, a.z - hips.z - jo.z).length()
		if hz < r:
			var top := a.y + sqrt(r * r - hz * hz) - jo.y - (_off[0] as Vector3).y
			cap = minf(cap, lerpf(top + 0.3, top, wt))
	var hy := float(p.get("hips_y", 0.0))
	if cap != INF:
		hy = minf(hy, cap)
	if w >= 1.0:
		out.hips_y = hy
	else:
		out.hips_y = lerpf(float(p.get("hips_y", 0.0)), hy, w)
	hips.y = (_off[0] as Vector3).y + float(out.hips_y)
	var bz := body.global_transform.basis.z
	var body_yaw := atan2(bz.x, bz.z)
	for i in 2:
		var f: Foot = feet[i]
		var s := "l" if i == 0 else "r"
		var a: Vector3 = inv * f.ankle
		var leg := _leg_ik(hips, qh, s, a, f.fyaw - body_yaw, f.pitch)
		for n in leg:
			out[n] = leg[n] if w >= 1.0 else HeroBody.turn(p.get(n, Vector3.ZERO)).slerp(leg[n], w)
	return out


## One leg's thigh, shin and foot (local turns) for its ankle at a (the body's space), the foot heading fy (against
## the body) at pitch (toe down +).
func _leg_ik(hips: Vector3, qh: Quaternion, s: String, a: Vector3, fy: float, pitch: float) -> Dictionary:
	var la: float = _len[s][0]
	var lb: float = _len[s][1]
	var jt := hips + qh * (_off[body.bone("thigh_" + s)] as Vector3)
	var d := a - jt
	var r := clampf(d.length(), absf(la - lb) + 0.02, (la + lb) * 0.999)
	var dn := d.normalized() if d.length() > 0.001 else Vector3.DOWN
	var fwd := (Vector3(sin(fy), 0.0, cos(fy)) + Vector3(0, 0, 0.6)).normalized()
	# The knee never bends behind her: toward the foot's heading, but at least a quarter forward of her body and of her
	# hips. (A foot turned well round from her body - a marker's feet as she turns to the ball - took the knee round
	# with it, 12 cm behind its hip-ankle line: the foundation's "knees" rule.)
	# (Measured square to the hip-ankle line, where the knee goes: a folded leg mid-swing, the foot up behind or ahead,
	# as her body turned round at a run, bent it 17 cm back with a heading that was forward of her.)
	fwd -= dn * fwd.dot(dn)
	for ahead: Vector3 in [Vector3(0, 0, 1), qh * Vector3(0, 0, 1)]:
		ahead -= dn * ahead.dot(dn)
		if ahead.length() < 0.2:
			continue           # (the leg along it: no side of it to keep to)
		ahead = ahead.normalized()
		var k := fwd.normalized().dot(ahead) if fwd.length() > 0.001 else -1.0
		if k < 0.25:
			fwd = fwd.normalized() + ahead * (0.25 - k) if fwd.length() > 0.001 else ahead
		fwd -= dn * fwd.dot(dn)
	var h := fwd.cross(dn)
	if h.length() < 0.05:
		h = qh * Vector3.RIGHT
	h = h.normalized()
	var alpha := acos(clampf((la * la + r * r - lb * lb) / (2.0 * la * r), -1.0, 1.0))
	var u := dn.rotated(h, -alpha)
	var yb := -u
	var thigh := Basis(h, yb, h.cross(yb)).orthonormalized().get_rotation_quaternion()
	var bend := PI - acos(clampf((la * la + lb * lb - r * r) / (2.0 * la * lb), -1.0, 1.0))
	var shin := Quaternion(Vector3.RIGHT, bend)
	var foot_b := (Basis(Vector3.UP, fy) * Basis(Vector3.RIGHT, pitch)).get_rotation_quaternion()
	var t_local := qh.inverse() * thigh
	var f_local := (thigh * shin).inverse() * foot_b
	return {"thigh_" + s: t_local, "shin_" + s: shin, "foot_" + s: f_local}


## While the game's own move has her legs (a leap, a landing): her feet kept where that move has them, so they are
## where she is standing when the stride takes them back.
func follow_body() -> void:
	if not _measure() or body.skeleton == null or not body.is_inside_tree():
		return
	for i in 2:
		var f: Foot = feet[i]
		var s := "l" if i == 0 else "r"
		var t := body.skeleton.global_transform * body.skeleton.get_bone_global_pose(body.bone("foot_" + s))
		f.down = true
		f.settle = false
		f.at = Vector2(t.origin.x, t.origin.z)
		var z := t.basis * Vector3.BACK
		f.yaw = atan2(z.x, z.z) if Vector2(z.x, z.z).length() > 0.1 else yaw
		f.u = 0.4
	striding = false
	epoch += 1


## Where a foot is on the floor as drawn (world): the spot under its ankle were it flat, from the ball of the foot or
## the heel, whichever it stands on (so rolling from one to the other does not move it): the tests' measure of a
## planted foot.
## (ball: the ball of the foot itself, what a pivot turns on.)
func contact(side: String, ball_only := false) -> Vector3:
	var t := body.skeleton.global_transform * body.skeleton.get_bone_global_pose(body.bone("foot_" + side))
	var fw := t.basis * Vector3.BACK
	var flat := Vector3(fw.x, 0.0, fw.z).normalized() * t.basis.get_scale().z
	var ball := t * Vector3(0, -_ankle_h, TOE)
	var heel := t * Vector3(0, -_ankle_h, -HEEL)
	if ball_only:
		return ball
	return ball - flat * TOE if ball.y <= heel.y else heel + flat * HEEL


## Both feet as drawn, as the foundation's checks read a body (WsgNoteChecks.feet; the world check's feet_low, WsgSim's
## "feet" for a body the game draws itself at Low): [left ankle, left ball of the foot, right ankle, right ball of the
## foot] (world). The game's body has no modifiers: its bones as posed are as drawn.
func drawn_feet() -> Array:
	var sk := body.skeleton
	var out := []
	for s in ["l", "r"]:
		out.append((sk.global_transform * sk.get_bone_global_pose(body.bone("foot_" + s))).origin)
		out.append(contact(s, true))
	return out

const _UPPER := ["hips", "spine", "chest", "neck", "head"]
const _ARMS := ["upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]


## The game's move (pose m, degrees) laid over the locomotion (loco, from loco_pose()): its arms by arms_w, its lean,
## head and crouch by body_w (standing: all of it; running: the run's); its legs kept for solve() to blend from. twist
## (rad): how far she looks away from where her body faces (at the ball, running another way): the chest and head
## turn to it.
static func lay(loco: Dictionary, m: Dictionary, arms_w: float, body_w: float, twist := 0.0) -> Dictionary:
	var out := m.duplicate()
	for b in _UPPER:
		var a: Vector3 = loco.get(b, Vector3.ZERO)
		out[b] = a.lerp(m.get(b, Vector3.ZERO), body_w)
	for b in _ARMS:
		var a: Vector3 = loco.get(b, Vector3.ZERO)
		out[b] = a.lerp(m.get(b, Vector3.ZERO), arms_w)
	out.hips_y = lerpf(float(loco.get("hips_y", 0.0)), float(m.get("hips_y", 0.0)), body_w)
	if absf(twist) > 0.01:
		var t := rad_to_deg(twist)
		var c := clampf(t * 0.3, -25.0, 25.0)
		out.chest = (out.chest as Vector3) + Vector3(0, c, 0)
		out.head = (out.head as Vector3) + Vector3(0, clampf(t - c, -65.0, 65.0), 0)
	return out
