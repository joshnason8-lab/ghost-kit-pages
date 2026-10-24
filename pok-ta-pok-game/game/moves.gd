class_name Moves
extends RefCounted
## The poses: each a function of time or of how far through a move, returning bone angles for Body.apply (degrees;
## Body has the conventions). The ready stance of the hip game (knees bent, the body low and forward, the arms out
## for balance), the run, the hip strike, the dive for a low ball, the two serves, and the judges' calls.


static func _v(x: float, y := 0.0, z := 0.0) -> Vector3:
	return Vector3(x, y, z)


## The ready stance, breathing a little: low (0-1) is how far down he sits.
static func stance(t: float, low := 0.6) -> Dictionary:
	var b := sin(t * 2.2) * 2.0
	var k := 18.0 + 32.0 * low
	return {
		"hips_y": -0.04 - 0.12 * low,
		"hips": _v(10.0 * low), "spine": _v(10.0 + 8.0 * low + b * 0.3), "chest": _v(4.0), "head": _v(-14.0 * low),
		"thigh_l": _v(-k, 0, 9), "shin_l": _v(k * 1.5), "foot_l": _v(-k * 0.5),
		"thigh_r": _v(-k, 0, -9), "shin_r": _v(k * 1.5), "foot_r": _v(-k * 0.5),
		"upperarm_l": _v(-20 + b, 0, 26), "forearm_l": _v(-35),
		"upperarm_r": _v(-20 - b, 0, -26), "forearm_r": _v(-35),
	}


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


## Blends two poses (w of the second).
static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in a:
		if b.has(k):
			if a[k] is Vector3:
				out[k] = (a[k] as Vector3).lerp(b[k], w)
			else:
				out[k] = lerpf(float(a[k]), float(b[k]), w)
		else:
			out[k] = a[k]
	for k in b:
		if not out.has(k):
			out[k] = (b[k] * w) if b[k] is Vector3 else float(b[k]) * w
	return out


const STRIKE_T := 0.62        # the hip strike's length, s
const STRIKE_HIT := 0.4       # the moment the hip meets the ball, as a fraction of it
const DIVE_T := 1.35
const DIVE_HIT := 0.3
const SERVE_T := 0.9
const SERVE_HIT := 0.55


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


## The serve (the male), right-handed: abajo, bowled low along the ground; arriba, thrown up in a long underarm arc.
static func serve(u: float, high: bool) -> Dictionary:
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
