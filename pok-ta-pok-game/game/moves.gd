class_name Moves
extends RefCounted
## The poses: each a function of time or of how far through a move, returning bone angles for Body.apply (degrees;
## Body has the conventions). The ready stance of the hip game (knees bent, the body low and forward, the weight on
## the balls of the feet, the arms loose and ready), the run, the hip strike, the dive for a low ball, the two serves,
## and the judges' calls.


static func _v(x: float, y := 0.0, z := 0.0) -> Vector3:
	return Vector3(x, y, z)


## The ready stance: low (0-1) is how far down he sits. An athlete's, not a mannequin's: the hips sat back and low,
## the trunk over the knees, knees bent and over the toes, the heels just off the ground (his weight on the balls of his
## feet), the arms loose at his sides and a little in front, elbows bent, ready to go either way and to turn the hip
## into the ball. And never still (the owner, 0.6.3: "too rigid"): he breathes, shifts his weight from foot to foot,
## gives a little bounce on the balls of his feet now and then, shakes his arms loose and looks about; t carries each
## player's own offset, so no two move together. The hips' height comes from the legs' angles, so the soles stay on the
## floor through all of it.
static func stance(t: float, low := 0.6) -> Dictionary:
	var b := sin(t * 2.2) * 2.0                                   # breath
	var shift := sin(t * 0.85) * 0.7 + sin(t * 0.37 + 1.3) * 0.3   # weight from foot to foot (-1..1)
	# A bounce on the balls of his feet: a few quick dips, then a while settled.
	var spell := clampf(sin(t * 0.55 + 0.4) * 2.0 - 0.6, 0.0, 1.0)
	var bob := (0.5 - 0.5 * cos(t * 7.0)) * spell
	var pelvis := 12.0 + 12.0 * low                               # the pelvis tipped forward (the hips sat back)
	var thigh := -(18.0 + 36.0 * low) - 5.0 * bob                 # the thigh's angle from the vertical, forward
	var knee := 30.0 + 50.0 * low - b * 0.4 + 10.0 * bob          # the knee's bend
	var shin := thigh + knee                                      # the shin's angle, the knee over the toes
	var heel := 7.0 + 4.0 * low + 4.0 * bob                       # the heels off the ground
	var hips_y := _leg_drop(pelvis, thigh, shin, heel)
	# The weight over one foot: the hips across a little, that leg nearer upright, the other's knee a touch softer.
	var side := 0.03 * shift
	var lean := rad_to_deg(atan(side / 0.86))
	var soft_l := maxf(0.0, -shift) * 6.0
	var soft_r := maxf(0.0, shift) * 6.0
	# The arms hang loose and stir: a slow swing, now and then a shake of the hands.
	var sw := sin(t * 1.3 + 0.8) * 4.0
	var shake := sin(t * 9.0) * 4.0 * clampf(sin(t * 0.43 + 2.1) * 3.0 - 2.2, 0.0, 1.0)
	return {
		"hips_y": hips_y - (soft_l + soft_r) * 0.0012, "hips_side": side,
		"hips": _v(pelvis, 0.0, -shift * 2.0), "spine": _v(6.0 + 6.0 * low + b * 0.3, sin(t * 0.6) * 4.0, shift * 3.0),
		"chest": _v(2.0), "head": _v(-pelvis - 4.0 - 10.0 * low, sin(t * 0.45 + 0.7) * 10.0),
		"thigh_l": _v(thigh - pelvis - soft_l * 0.5, 0, 6.0 - lean), "shin_l": _v(knee + soft_l), "foot_l": _v(heel - shin - soft_l * 0.5),
		"thigh_r": _v(thigh - pelvis - soft_r * 0.5, 0, -6.0 - lean), "shin_r": _v(knee + soft_r), "foot_r": _v(heel - shin - soft_r * 0.5),
		"upperarm_l": _v(-14.0 - 10.0 * low + b + sw, 0, 8.0 + shake * 0.5), "forearm_l": _v(-48.0 - 14.0 * low + shake, -20),
		"upperarm_r": _v(-14.0 - 10.0 * low - b - sw, 0, -8.0 - shake * 0.5), "forearm_r": _v(-48.0 - 14.0 * low - shake, 20),
	}


## How far the hips come down (m, negative) for legs at these angles (degrees from the vertical, Body's lengths: the
## hip joint 0.05 m under the hips, the thigh 0.44, the shin 0.42, the ball of the foot 0.13 m in front of the ankle).
static func _leg_drop(pelvis: float, thigh: float, shin: float, heel: float) -> float:
	var r := deg_to_rad(1.0)
	var up := 0.05 * cos(pelvis * r) + 0.44 * cos(thigh * r) + 0.42 * cos(shin * r) + 0.13 * sin(heel * r)
	return up - 0.91


## The run at speed (m/s); phase in cycles (one cycle is two steps). Low running crouches into the stance.
static func run(phase: float, speed: float, low := 0.3) -> Dictionary:
	var a := clampf(speed / 6.5, 0.0, 1.0)
	var s := sin(phase * TAU)
	var c := cos(phase * TAU)
	var swing := 14.0 + 30.0 * a
	var knee := 20.0 + 55.0 * a
	var lift_l := maxf(0.0, -c)
	var lift_r := maxf(0.0, c)
	return {
		"hips_y": -0.03 - 0.06 * low + absf(s) * 0.03 * a,
		"hips": _v(6.0 + 8.0 * a + 8.0 * low, s * 6.0 * a), "spine": _v(6.0 + 6.0 * a + 6.0 * low, -s * 8.0 * a),
		"chest": _v(2.0), "head": _v(-8.0 - 6.0 * a),
		"thigh_l": _v(-s * swing - 10.0 * low), "shin_l": _v(12.0 + knee * lift_l + 15.0 * low), "foot_l": _v(-6.0 * lift_l),
		"thigh_r": _v(s * swing - 10.0 * low), "shin_r": _v(12.0 + knee * lift_r + 15.0 * low), "foot_r": _v(-6.0 * lift_r),
		"upperarm_l": _v(s * swing * 0.8, 0, 12), "forearm_l": _v(-50.0 - 20.0 * a),
		"upperarm_r": _v(-s * swing * 0.8, 0, -12), "forearm_r": _v(-50.0 - 20.0 * a),
	}


## A bone's turn as a quaternion, from Euler degrees (YXZ) or already one.
static func quat(e: Variant) -> Quaternion:
	if e is Quaternion:
		return e
	var v: Vector3 = e
	return Basis.from_euler(Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z)), EULER_ORDER_YXZ).get_rotation_quaternion()


## Blends two poses (w of the second). Recorded turns (quaternions) blend by slerp.
static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in a:
		if b.has(k):
			if a[k] is Quaternion or b[k] is Quaternion:
				out[k] = quat(a[k]).slerp(quat(b[k]), w)
			elif a[k] is Vector3:
				out[k] = (a[k] as Vector3).lerp(b[k], w)
			else:
				out[k] = lerpf(float(a[k]), float(b[k]), w)
		else:
			out[k] = a[k]
	for k in b:
		if not out.has(k):
			if b[k] is Quaternion:
				out[k] = Quaternion.IDENTITY.slerp(b[k], w)
			else:
				out[k] = (b[k] * w) if b[k] is Vector3 else float(b[k]) * w
	return out


const STRIKE_T := 0.62        # the hip strike's length, s
const STRIKE_HIT := 0.4       # the moment the hip meets the ball, as a fraction of it
const DIVE_T := 1.35
const DIVE_HIT := 0.3
const SERVE_T := 1.6          # the recorded underhand toss at its own speed (Mocap.TOSS)
const SERVE_HIT := 0.64       # its release


## The hip strike with the side's hip (1 the left, -1 the right), u from 0 to 1: he sinks, swings the hip into the ball
## leaning his body away from it, the far leg pushing, the arms flung up for balance, then comes back up.
static func hip_strike(u: float, side: float) -> Dictionary:
	var load := smoothstep(0.0, STRIKE_HIT, u) * (1.0 - smoothstep(STRIKE_HIT, 1.0, u))
	var thrust := sin(clampf(u / STRIKE_HIT, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(STRIKE_HIT + 0.1, 1.0, u))
	var p := stance(0.0, 0.8)
	var lean := 26.0 * thrust * side
	p.hips_y = -0.16 - 0.1 * load
	p.hips_side = 0.09 * thrust * side
	p.hips = _v(12.0, -18.0 * side * thrust, -lean)
	p.spine = _v(14.0, 10.0 * side * thrust, lean * 0.6)
	p.chest = _v(4.0, 0, lean * 0.3)
	p.head = _v(-12.0, 0, -lean * 0.5)
	var near := "l" if side > 0 else "r"
	var far := "r" if side > 0 else "l"
	var sgn := 1.0 if side > 0 else -1.0
	p["thigh_" + near] = _v(-46.0 + 10.0 * thrust, 0, sgn * (14.0 + 18.0 * thrust))
	p["shin_" + near] = _v(78.0 - 20.0 * thrust)
	p["thigh_" + far] = _v(-30.0, 0, -sgn * (6.0 + 10.0 * thrust))
	p["shin_" + far] = _v(50.0 + 20.0 * load)
	p["upperarm_" + near] = _v(-50.0 * thrust, 0, sgn * (40.0 + 60.0 * thrust))
	p["forearm_" + near] = _v(-30.0)
	p["upperarm_" + far] = _v(-30.0 - 30.0 * thrust, 0, -sgn * (30.0 + 30.0 * thrust))
	p["forearm_" + far] = _v(-60.0)
	return p


## The dive for a low ball: he throws himself down on his side so the hip meets the ball just above the ground, then
## gets up: down by DIVE_HIT, on the ground to 0.6, up by 1.
static func dive(u: float, side: float) -> Dictionary:
	var down := smoothstep(0.0, DIVE_HIT, u) * (1.0 - smoothstep(0.62, 1.0, u))
	var p := stance(0.0, 0.9)
	var sgn := 1.0 if side > 0 else -1.0
	p.hips_y = -0.62 * down - 0.12
	p.hips_side = 0.32 * down * sgn
	p.hips = _v(18.0 * (1.0 - down), 0, -72.0 * down * sgn)
	p.spine = _v(10.0, 0, 20.0 * down * sgn)
	p.chest = _v(0.0, 0, 8.0 * down * sgn)
	p.head = _v(-10.0, 0, -30.0 * down * sgn)
	var near := "l" if side > 0 else "r"
	var far := "r" if side > 0 else "l"
	p["thigh_" + near] = _v(-40.0 - 20.0 * down, 0, sgn * 10.0)
	p["shin_" + near] = _v(80.0)
	p["thigh_" + far] = _v(-60.0 * down - 20.0, 0, -sgn * 10.0 * down)
	p["shin_" + far] = _v(70.0 + 20.0 * down)
	p["upperarm_" + far] = _v(-90.0 * down - 20.0, 0, -sgn * 70.0 * down)
	p["forearm_" + far] = _v(-20.0)
	p["upperarm_" + near] = _v(-40.0 * down, 0, sgn * (20.0 + 40.0 * down))
	p["forearm_" + near] = _v(-40.0)
	return p


## The serve (the male), right-handed: the recorded underhand toss (Mocap.toss), bowled lower for abajo by blending in
## the hand-made one; the hand-made one alone if the recording is missing.
static func serve(u: float, high: bool) -> Dictionary:
	var rec := Mocap.toss(u)
	if rec.is_empty():
		return serve_made(u, high)
	return rec if high else blend(rec, serve_made(u, false), 0.35)


## The hand-made serve: abajo, bowled low along the ground; arriba, thrown up in a long underarm arc.
static func serve_made(u: float, high: bool) -> Dictionary:
	var p := stance(0.0, 0.7 if not high else 0.4)
	var back := smoothstep(0.0, SERVE_HIT * 0.8, u) * (1.0 - smoothstep(SERVE_HIT * 0.8, SERVE_HIT, u))
	var fwd := smoothstep(SERVE_HIT * 0.7, SERVE_HIT + 0.15, u) * (1.0 - smoothstep(0.8, 1.0, u))
	p.spine = _v(20.0 + (10.0 if not high else -6.0) * fwd)
	p.upperarm_r = _v(50.0 * back - (60.0 if not high else 140.0) * fwd, 0, -10.0)
	p.forearm_r = _v(-10.0)
	p.upperarm_l = _v(-30.0, 0, 30.0)
	p.thigh_l = _v(-50.0 * fwd - 20.0, 0, 8)
	p.shin_l = _v(60.0)
	return p


## The ball in the server's hand, where his right hand is (local space): for drawing it before the throw.
const HAND_BALL := Vector3(-0.22, 0.55, 0.25)


## Arms up: the raya is ours.
static func celebrate(t: float) -> Dictionary:
	var b := sin(t * 9.0) * 8.0
	return {
		"hips_y": absf(sin(t * 6.0)) * 0.05, "spine": _v(-4.0), "head": _v(-10.0),
		"upperarm_l": _v(-150.0 + b, 0, 30), "forearm_l": _v(-10.0),
		"upperarm_r": _v(-150.0 - b, 0, -30), "forearm_r": _v(-10.0),
		"thigh_l": _v(-4.0), "thigh_r": _v(-4.0),
	}


## Arms raised to the sky, palms up, face lifted: receiving the copal's smoke before the game (Ritual).
static func offering(t: float) -> Dictionary:
	var b := sin(t * 1.4) * 3.0
	return {
		"spine": _v(-6.0), "chest": _v(-4.0), "head": _v(-22.0),
		"upperarm_l": _v(-160.0 + b, 0, 22), "forearm_l": _v(-12.0),
		"upperarm_r": _v(-160.0 - b, 0, -22), "forearm_r": _v(-12.0),
	}


## Hands on knees, head down: the raya went the other way.
static func dejected(t: float) -> Dictionary:
	return {
		"hips_y": -0.08, "hips": _v(30.0), "spine": _v(20.0), "head": _v(20.0 + sin(t) * 2.0),
		"thigh_l": _v(-30.0, 0, 6), "shin_l": _v(40.0), "thigh_r": _v(-30.0, 0, -6), "shin_r": _v(40.0),
		"upperarm_l": _v(-50.0, 0, 6), "forearm_l": _v(-20.0), "upperarm_r": _v(-50.0, 0, -6), "forearm_r": _v(-20.0),
	}


## A judge standing, watching, his weight on one leg.
static func judge_idle(t: float) -> Dictionary:
	return {
		"hips": _v(0, sin(t * 0.4) * 6.0), "spine": _v(2.0), "head": _v(-4.0, sin(t * 0.7) * 20.0),
		"thigh_l": _v(-3.0, 0, 3), "thigh_r": _v(2.0, 0, -4), "shin_l": _v(4.0),
		"upperarm_l": _v(4.0, 0, 6), "forearm_l": _v(-20.0), "upperarm_r": _v(4.0, 0, -6), "forearm_r": _v(-20.0),
	}


## A judge's call (the game's: no source describes the veedores' signals): an arm raised straight toward the side
## that wins the raya (side: 1 to his left, -1 to his right), the other down. A fault: both arms crossed over the head
## first (fault true), then the arm.
static func judge_call(u: float, side: float, fault: bool) -> Dictionary:
	var p := judge_idle(0.0)
	var cross := fault and u < 0.45
	if cross:
		var k := smoothstep(0.0, 0.2, u)
		p.upperarm_l = _v(-160.0 * k, 0, -20.0 * k)
		p.forearm_l = _v(-40.0 * k)
		p.upperarm_r = _v(-160.0 * k, 0, 20.0 * k)
		p.forearm_r = _v(-40.0 * k)
		return p
	var k := smoothstep(0.45 if fault else 0.0, 0.65 if fault else 0.2, u)
	var arm := "l" if side > 0 else "r"
	var sgn := 1.0 if side > 0 else -1.0
	p["upperarm_" + arm] = _v(-20.0 * k, 0, sgn * 110.0 * k)
	p["forearm_" + arm] = _v(0.0)
	p.head = _v(-4.0, 30.0 * sgn * k)
	return p
