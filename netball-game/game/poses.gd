class_name Poses
extends RefCounted
## Every pose a netball player or umpire takes, as bone angles in degrees for ToonBody.apply. Built from a few
## parameters (how far through a pass, how fast a run) rather than stored clips, so a stride always matches the speed
## the player is going (run), and nothing jumps from one pose to the next: Player blends between them.

## The ready stance: knees soft, weight forward, hands up at chest height to take a pass.
static func ready(alert := 1.0) -> Dictionary:
	var k := clampf(alert, 0.0, 1.0)
	return {
		"hips_y": -0.04 * k,
		"spine": Vector3(8.0 * k, 0, 0), "chest": Vector3(4.0 * k, 0, 0), "head": Vector3(-8.0 * k, 0, 0),
		"upperarm_l": Vector3(-20.0 * k, 0, 12), "forearm_l": Vector3(-70.0 * k, 0, 0),
		"upperarm_r": Vector3(-20.0 * k, 0, -12), "forearm_r": Vector3(-70.0 * k, 0, 0),
		"thigh_l": Vector3(-14.0 * k, 0, 4), "shin_l": Vector3(24.0 * k, 0, 0), "foot_l": Vector3(-8.0 * k, 0, 0),
		"thigh_r": Vector3(-14.0 * k, 0, -4), "shin_r": Vector3(24.0 * k, 0, 0), "foot_r": Vector3(-8.0 * k, 0, 0),
	}


## A run (or walk, slow): phase in cycles (0-1 a stride pair), speed m/s. The stride's length grows with speed, so
## the feet do not slide (Player advances phase by speed / stride_length).
static func run(phase: float, speed: float) -> Dictionary:
	var k := clampf(speed / 7.0, 0.0, 1.0)   # 0 standing .. 1 a sprint
	var s := sin(phase * TAU)
	var c := cos(phase * TAU)
	var swing := lerpf(14.0, 46.0, k)
	var arm := lerpf(10.0, 42.0, k)
	return {
		"hips_y": -0.02 - 0.03 * k + 0.035 * k * absf(c),
		"spine": Vector3(6.0 + 10.0 * k, s * 4.0 * k, 0), "chest": Vector3(2.0, -s * 8.0 * k, 0), "head": Vector3(-6.0 - 6.0 * k, 0, 0),
		"thigh_l": Vector3(-swing * s - 8.0 * k, 0, 2), "shin_l": Vector3(maxf(6.0, 70.0 * k * maxf(0.0, -c) + 18.0 * k), 0, 0),
		"thigh_r": Vector3(swing * s - 8.0 * k, 0, -2), "shin_r": Vector3(maxf(6.0, 70.0 * k * maxf(0.0, c) + 18.0 * k), 0, 0),
		"foot_l": Vector3(-6.0, 0, 0), "foot_r": Vector3(-6.0, 0, 0),
		"upperarm_l": Vector3(arm * s - 6.0, 0, 8), "forearm_l": Vector3(-70.0 - 20.0 * k, 0, 0),
		"upperarm_r": Vector3(-arm * s - 6.0, 0, -8), "forearm_r": Vector3(-70.0 - 20.0 * k, 0, 0),
	}


## Holding the ball at the chest, landed, ready to pass: pivot is handled by Player turning the whole body.
static func hold() -> Dictionary:
	var p := ready(1.0)
	p.upperarm_l = Vector3(-40, 0, 18)
	p.forearm_l = Vector3(-80, -30, 0)
	p.upperarm_r = Vector3(-40, 0, -18)
	p.forearm_r = Vector3(-80, 30, 0)
	return p


## A pass, t 0-1 through it: kind "chest" (two hands pushed from the chest), "shoulder" (one hand from behind the
## right shoulder, a long ball), "bounce" (pushed down to bounce once), "lob" (two hands up and over).
static func pass_(kind: String, t: float) -> Dictionary:
	var p := hold()
	var push := clampf((t - 0.25) / 0.45, 0.0, 1.0)
	var back := clampf(t / 0.25, 0.0, 1.0) * (1.0 - push)
	match kind:
		"shoulder":
			p.upperarm_r = Vector3(lerpf(-150.0, -95.0, push), 0, lerpf(-40.0, -10.0, push))
			p.forearm_r = Vector3(lerpf(-60.0, 0.0, push) - 30.0 * back, 0, 0)
			p.upperarm_l = Vector3(-60, 0, 30)
			p.forearm_l = Vector3(-40, 0, 0)
			p.chest = Vector3(lerpf(-6.0, 14.0, push), lerpf(30.0, -20.0, push), 0)
			p.thigh_l = Vector3(-30.0, 0, 4)
			p.shin_l = Vector3(20, 0, 0)
		"bounce":
			for side in ["l", "r"]:
				var sx := 1.0 if side == "l" else -1.0
				p["upperarm_" + side] = Vector3(lerpf(-40.0, -55.0, push), 0, 14.0 * sx)
				p["forearm_" + side] = Vector3(lerpf(-80.0, -5.0, push), 0, 0)
			p.spine = Vector3(lerpf(10.0, 28.0, push), 0, 0)
			p.hips_y = -0.08
		"lob":
			for side in ["l", "r"]:
				var sx := 1.0 if side == "l" else -1.0
				p["upperarm_" + side] = Vector3(lerpf(-120.0, -165.0, push), 0, 10.0 * sx)
				p["forearm_" + side] = Vector3(lerpf(-70.0, -10.0, push), 0, 0)
			p.spine = Vector3(-4.0, 0, 0)
		_:   # chest
			for side in ["l", "r"]:
				var sx := 1.0 if side == "l" else -1.0
				p["upperarm_" + side] = Vector3(lerpf(-40.0, -85.0, push), 0, lerpf(18.0, 6.0, push) * sx)
				p["forearm_" + side] = Vector3(lerpf(-80.0, -8.0, push) - 15.0 * back, 0, 0)
			p.spine = Vector3(lerpf(6.0, 16.0, push), 0, 0)
			p.thigh_l = Vector3(-24.0 * push - 10.0, 0, 4)
	return p


## A catch: arms reaching toward the ball (reach 0-1: from ready to full stretch), up at height up (-1 low, 0 chest,
## 1 overhead).
static func catch_(reach: float, up: float) -> Dictionary:
	var p := ready(1.0)
	var a := lerpf(-40.0, lerpf(-70.0, -165.0, clampf(up, 0.0, 1.0)), reach)
	if up < 0.0:
		a = lerpf(-40.0, -30.0, reach)
		p.spine = Vector3(lerpf(8.0, 30.0, -up * reach), 0, 0)
	for side in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0
		p["upperarm_" + side] = Vector3(a, 0, 12.0 * sx)
		p["forearm_" + side] = Vector3(lerpf(-70.0, -10.0, reach), 0, 0)
	return p


## A shot at goal, t 0-1: the ball lifted over the head, knees bent, then the legs straighten and the wrist follows
## through, one hand under the ball and the other beside it (the set shot of the game's shooters).
static func shoot(t: float) -> Dictionary:
	var dip := clampf(t / 0.4, 0.0, 1.0)
	var up := clampf((t - 0.4) / 0.35, 0.0, 1.0)
	var bend := dip * (1.0 - up)
	var p := ready(0.4)
	p.hips_y = -0.12 * bend + 0.03 * up
	p.thigh_l = Vector3(-30.0 * bend, 0, 4)
	p.shin_l = Vector3(55.0 * bend, 0, 0)
	p.foot_l = Vector3(-25.0 * bend + 18.0 * up, 0, 0)
	p.thigh_r = Vector3(-30.0 * bend, 0, -4)
	p.shin_r = Vector3(55.0 * bend, 0, 0)
	p.foot_r = Vector3(-25.0 * bend + 18.0 * up, 0, 0)
	p.spine = Vector3(-2.0, 0, 0)
	p.head = Vector3(-18.0, 0, 0)
	p.upperarm_r = Vector3(lerpf(-60.0, -165.0, maxf(dip, up)), 0, -6)
	p.forearm_r = Vector3(lerpf(-100.0, -95.0, dip) * (1.0 - up) - 8.0 * up, 0, 0)
	p.upperarm_l = Vector3(lerpf(-60.0, -150.0, maxf(dip, up)), 0, 14)
	p.forearm_l = Vector3(lerpf(-90.0, -70.0, up), 0, 0)
	return p


## Defending the player with the ball from 0.9 m: arms up and out over the ball, on her toes; lean (0-1) further into
## the defence. Or a shot defence: one arm straight up.
static func defend_ball(lean := 1.0, shot := false) -> Dictionary:
	var p := ready(1.0)
	p.hips_y = 0.02
	p.spine = Vector3(-6.0 + 14.0 * lean, 0, 0)
	if shot:
		p.upperarm_l = Vector3(-170, 0, 6)
		p.forearm_l = Vector3(-5, 0, 0)
		p.upperarm_r = Vector3(-150, 0, -20)
		p.forearm_r = Vector3(-10, 0, 0)
		p.spine = Vector3(14.0 * lean, 0, 0)
		return p
	p.upperarm_l = Vector3(-130, 0, 40)
	p.forearm_l = Vector3(-20, 0, 0)
	p.upperarm_r = Vector3(-130, 0, -40)
	p.forearm_r = Vector3(-20, 0, 0)
	return p


## Marking a player without the ball: low, side-on, one arm out toward the passing lane.
static func mark(side := 1.0) -> Dictionary:
	var p := ready(1.0)
	p.hips_y = -0.07
	p.thigh_l = Vector3(-24, 0, 14)
	p.thigh_r = Vector3(-24, 0, -14)
	p.shin_l = Vector3(36, 0, 0)
	p.shin_r = Vector3(36, 0, 0)
	if side > 0.0:
		p.upperarm_l = Vector3(-60, 0, 50)
		p.forearm_l = Vector3(-20, 0, 0)
	else:
		p.upperarm_r = Vector3(-60, 0, -50)
		p.forearm_r = Vector3(-20, 0, 0)
	return p


## A leap for the ball (an intercept, a rebound, a high catch): t 0-1 through the jump, both arms stretched to it.
static func leap(t: float) -> Dictionary:
	var air := sin(clampf(t, 0.0, 1.0) * PI)
	var p := catch_(1.0, 1.0)
	p.hips_y = 0.42 * air - 0.08 * (1.0 - air) * float(t < 0.15 or t > 0.85)
	p.thigh_l = Vector3(-20.0 * air, 0, 4)
	p.shin_l = Vector3(40.0 * air, 0, 0)
	p.thigh_r = Vector3(-5.0 * air, 0, -4)
	p.shin_r = Vector3(20.0 * air, 0, 0)
	p.foot_l = Vector3(30.0 * air, 0, 0)
	p.foot_r = Vector3(30.0 * air, 0, 0)
	return p


## Standing out of play beside the thrower after a penalty: arms down by her sides, still.
static func out_of_play() -> Dictionary:
	return {"upperarm_l": Vector3(4, 0, 6), "upperarm_r": Vector3(4, 0, -6), "forearm_l": Vector3(-10, 0, 0),
		"forearm_r": Vector3(-10, 0, 0)}


## A celebration after a goal: both fists up.
static func cheer(t: float) -> Dictionary:
	var b := 0.5 + 0.5 * sin(t * 10.0)
	return {"hips_y": 0.04 * b, "upperarm_l": Vector3(-160, 0, 30), "forearm_l": Vector3(-30 - 20 * b, 0, 0),
		"upperarm_r": Vector3(-160, 0, -30), "forearm_r": Vector3(-30 - 20 * b, 0, 0), "head": Vector3(-14, 0, 0)}


# ---------------------------------------------------------------- the umpires' signals

## An umpire's signal (World Netball's official signals, docs/RULES.md "Officials"), t seconds into it. side: +1 when
## the award goes to her left (the arm that points the direction of the pass), -1 to her right.
static func umpire_signal(kind: String, t: float, side := 1.0) -> Dictionary:
	var p := {"spine": Vector3(2, 0, 0)}
	var hand := "l" if side > 0.0 else "r"
	var other := "r" if side > 0.0 else "l"
	var sx := 1.0 if hand == "l" else -1.0
	var wave := sin(t * 9.0)
	match kind:
		"direction":
			# The arm out level toward the team's attacking goal: the award's direction.
			p["upperarm_" + hand] = Vector3(0, 0, 90.0 * sx)
			p["forearm_" + hand] = Vector3(0, 0, 0)
		"held_ball":
			# An arm straight up, three fingers shown.
			p["upperarm_" + hand] = Vector3(-178, 0, 4.0 * sx)
		"footwork":
			# Hands palms down in front, rolling up and down past each other.
			p.upperarm_l = Vector3(-60, 0, 10)
			p.upperarm_r = Vector3(-60, 0, -10)
			p.forearm_l = Vector3(-50.0 + 22.0 * wave, 0, 0)
			p.forearm_r = Vector3(-50.0 - 22.0 * wave, 0, 0)
		"short_pass":
			p.upperarm_l = Vector3(-70, 0, 14)
			p.upperarm_r = Vector3(-70, 0, -14)
			p.forearm_l = Vector3(-20, 0, 0)
			p.forearm_r = Vector3(-20, -25.0 * maxf(0.0, wave), 0)
		"obstruction":
			# Both hands in front, palms facing, a short way apart.
			p.upperarm_l = Vector3(-80, 0, 6)
			p.upperarm_r = Vector3(-80, 0, -6)
			p.forearm_l = Vector3(-15, 0, 0)
			p.forearm_r = Vector3(-15, 0, 0)
		"contact":
			# One hand tapping the other forearm, held across the body.
			p["upperarm_" + other] = Vector3(-60, 0, -30.0 * sx)
			p["forearm_" + other] = Vector3(-60, 0, 0)
			p["upperarm_" + hand] = Vector3(-55, 0, -20.0 * sx)
			p["forearm_" + hand] = Vector3(-70.0 + 12.0 * maxf(0.0, wave), 0, 0)
		"over_third":
			p["upperarm_" + hand] = Vector3(lerpf(-40.0, -150.0, clampf(t * 1.6, 0.0, 1.0)), 0, 20.0 * sx)
		"offside", "breaking", "throw_in":
			# An arm angled down toward the line or the area.
			p["upperarm_" + hand] = Vector3(0, 0, 45.0 * sx)
		"penalty":
			# The penalty: the arm pointing down at the spot beside the thrower where the infringer stands.
			p["upperarm_" + hand] = Vector3(-30, 0, 30.0 * sx)
			p["forearm_" + hand] = Vector3(0, 0, 0)
		"goal":
			# A goal: the arm raised, then the pointing to centre: kept simple, the arm up.
			p["upperarm_" + hand] = Vector3(-150, 0, 10.0 * sx)
		"time":
			# Hold time: the hands in a T.
			p.upperarm_l = Vector3(-90, 0, 10)
			p.upperarm_r = Vector3(-90, 0, -10)
			p.forearm_l = Vector3(0, 70, 0)
			p.forearm_r = Vector3(-60, 0, 0)
		"whistle":
			# The whistle to the mouth.
			p.upperarm_r = Vector3(-30, 0, -20)
			p.forearm_r = Vector3(-130, 0, 0)
	return p


## Blends two poses: a at k = 0, b at k = 1, bone by bone.
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var out := {}
	for key in a:
		var va = a[key]
		var vb = b.get(key, Vector3.ZERO if va is Vector3 else 0.0)
		out[key] = va.lerp(vb, k) if va is Vector3 else lerpf(float(va), float(vb), k)
	for key in b:
		if not out.has(key):
			var vb = b[key]
			out[key] = Vector3.ZERO.lerp(vb, k) if vb is Vector3 else lerpf(0.0, float(vb), k)
	return out


## Lays pose b's arms over pose a (a run with the ball held, a run with arms out to mark).
static func with_arms(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for key in ["upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]:
		if b.has(key):
			out[key] = b[key]
	return out
