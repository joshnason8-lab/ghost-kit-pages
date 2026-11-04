class_name Poses
extends RefCounted
## Every pose a netball player or umpire takes, as bone angles in degrees for ToonBody.apply. Built from a few
## parameters (how far through a pass, a shot, a leap) rather than stored clips, and nothing jumps from one pose to
## the next: Player blends between them. Running and walking are Gait's (the feet stepping with the floor), with
## these laid over it.

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


## Standing in play at ease (the owner: "their stance is too rigid when not moving, with their hands out"): knees
## soft, upright, arms hanging relaxed with the elbows a little bent and the hands by her hips; breathing, her weight
## shifting slowly from foot to foot, her head turning a little now and then. hands (0-1): her hands lifted loosely in
## front of her at her waist, ready for a pass (only while it may come to her). t: seconds (never restarting: nothing
## jumps); v: her own way of standing (each 0-1: how bent her elbows are and how far her arms hang out, her stance's
## depth, the rhythm of her breathing and swaying, her head's), so no two stand alike. down: arms straight down, still
## (out of play beside the thrower).
static func idle(t: float, hands := 0.0, v := Vector4(0.5, 0.5, 0.5, 0.5), down := false) -> Dictionary:
	var br := sin(t * TAU / lerpf(3.4, 4.8, v.z))
	var sway := sin(t * TAU / lerpf(5.5, 9.0, v.y) + v.x * 6.0)
	var look := sin(t * TAU / lerpf(6.0, 11.0, v.w) + v.w * 9.0) * smoothstep(0.2, 0.9, absf(sin(t * TAU / 13.0 + v.z * 5.0)))
	var bend := lerpf(12.0, 30.0, v.x)
	var out := lerpf(5.0, 11.0, v.y)
	var k := clampf(hands, 0.0, 1.0)
	var p := {
		"hips_y": -0.012 - 0.022 * v.y,
		"hips_x": 0.022 * sway,
		"hips": Vector3(1.5, 0, -2.5 * sway),
		"spine": Vector3(2.0 + 1.0 * br + 3.0 * k, 0, 1.6 * sway),
		"chest": Vector3(1.0 - 1.5 * br, 0, 1.2 * sway),
		"neck": Vector3.ZERO,
		"head": Vector3(-2.0 - 2.0 * k, 9.0 * look * (1.0 - k), -1.5 * sway),
		"upperarm_l": Vector3(lerpf(-4.0 + 1.5 * br, -20.0, k), 0, lerpf(out, 12.0, k)),
		"forearm_l": Vector3(lerpf(-bend, -62.0, k), lerpf(-8.0, -25.0, k), 0),
		"hand_l": Vector3(0, 0, lerpf(-4.0, 0.0, k)),
		"upperarm_r": Vector3(lerpf(-4.0 + 1.5 * br, -20.0, k), 0, -lerpf(out, 12.0, k)),
		"forearm_r": Vector3(lerpf(-bend, -62.0, k), lerpf(8.0, 25.0, k), 0),
		"hand_r": Vector3(0, 0, lerpf(4.0, 0.0, k)),
		"thigh_l": Vector3(-6, 0, 3), "shin_l": Vector3(10, 0, 0), "foot_l": Vector3(-4, 0, 0),
		"thigh_r": Vector3(-6, 0, -3), "shin_r": Vector3(10, 0, 0), "foot_r": Vector3(-4, 0, 0),
	}
	if down:
		for s in ["l", "r"]:
			var sx := 1.0 if s == "l" else -1.0
			p["upperarm_" + s] = Vector3(3, 0, 6.0 * sx)
			p["forearm_" + s] = Vector3(-10, -8.0 * sx, 0)
	return p


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
		# (Soft elbows into the hands on a ball at chest height or below; nearly straight only reaching up high. Straight
		# arms reaching out at chest height on the run read as arms held out stiff.)
		p["forearm_" + side] = Vector3(lerpf(-70.0, lerpf(-32.0, -10.0, clampf(up, 0.0, 1.0)), reach), 0, 0)
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


## Defending the player with the ball from 0.9 m: both arms raised up and toward the ball, the hands above her head
## and a little apart, the elbows soft, on her toes; lean (0-1) further into the defence. Or a shot defence: one arm
## up high over the ball, the other up beside it. (Not out to the sides: the old arms, out at 110 degrees from
## hanging with nearly straight elbows, read as a T-pose, and blended with the run's swing as she closed in or moved
## off they passed through arms held straight out sideways - the owner's "arms just stretched out when running".)
static func defend_ball(lean := 1.0, shot := false) -> Dictionary:
	var p := ready(1.0)
	p.hips_y = 0.02
	p.spine = Vector3(-6.0 + 14.0 * lean, 0, 0)
	if shot:
		p.upperarm_l = Vector3(-168, 0, 6)
		p.forearm_l = Vector3(-36, 0, 0)
		p.upperarm_r = Vector3(-145, 0, -14)
		p.forearm_r = Vector3(-36, 0, 0)
		p.spine = Vector3(14.0 * lean, 0, 0)
		return p
	p.upperarm_l = Vector3(-150, 0, 16)
	p.forearm_l = Vector3(-34, 0, 0)
	p.upperarm_r = Vector3(-150, 0, -16)
	p.forearm_r = Vector3(-34, 0, 0)
	return p


## Marking a player without the ball: low and side-on, her arms loose and a little out from her sides, ready (not held
## out: the owner's "too rigid ... hands out"); lift (0-1): now and then one arm out toward the passing lane (side 1:
## her left), for a moment. v: her own way of standing (idle).
static func mark(side := 1.0, lift := 0.0, v := Vector4(0.5, 0.5, 0.5, 0.5)) -> Dictionary:
	var p := ready(0.6)
	p.hips_y = -0.05
	p.spine = Vector3(7, 0, 0)
	p.thigh_l = Vector3(-18, 0, 12)
	p.thigh_r = Vector3(-18, 0, -12)
	p.shin_l = Vector3(28, 0, 0)
	p.shin_r = Vector3(28, 0, 0)
	var bend := lerpf(28.0, 42.0, v.x)
	for s in ["l", "r"]:
		var sx := 1.0 if s == "l" else -1.0
		p["upperarm_" + s] = Vector3(-12, 0, 16.0 * sx)
		p["forearm_" + s] = Vector3(-bend, -10.0 * sx, 0)
	var arm := "l" if side > 0.0 else "r"
	var ax := 1.0 if arm == "l" else -1.0
	p["upperarm_" + arm] = (p["upperarm_" + arm] as Vector3).lerp(Vector3(-55, 0, 45.0 * ax), lift)
	p["forearm_" + arm] = (p["forearm_" + arm] as Vector3).lerp(Vector3(-38, 0, 0), lift)    # (its elbow soft)
	return p


## A shooter holding (posting) by the post: feet wide, low, her defender on her back, one arm out where she wants the
## ball (side "l" or "r": her left or right arm; out 0-1: held out, or lowered between calls), the other bent back to
## feel for her defender.
static func post(side := "l", out := 1.0) -> Dictionary:
	var p := ready(1.0)
	var o := "r" if side == "l" else "l"
	var sx := 1.0 if side == "l" else -1.0
	p.hips_y = -0.08
	p.thigh_l = Vector3(-18, 0, 16)
	p.thigh_r = Vector3(-18, 0, -16)
	p.shin_l = Vector3(30, 0, 0)
	p.shin_r = Vector3(30, 0, 0)
	# (out 0-1: the arm held out for the ball, or lowered between calls.)
	p["upperarm_" + side] = Vector3(-14, 0, 14.0 * sx).lerp(Vector3(-95, 0, 28.0 * sx), out)
	p["forearm_" + side] = Vector3(-38, 0, 0).lerp(Vector3(-32, 0, 0), out)    # (the elbow soft: a target, not a bar)
	p["upperarm_" + o] = Vector3(10, 0, -30.0 * sx)
	p["forearm_" + o] = Vector3(-40, 0, 0)
	return p


## In the huddle at a break: leaning in, arms out round her team-mates' shoulders.
static func huddle() -> Dictionary:
	var p := ready(0.5)
	p.spine = Vector3(16, 0, 0)
	p.chest = Vector3(6, 0, 0)
	p.head = Vector3(6, 0, 0)
	p.upperarm_l = Vector3(-55, 0, 55)
	p.forearm_l = Vector3(-25, 0, 0)
	p.upperarm_r = Vector3(-55, 0, -55)
	p.forearm_r = Vector3(-25, 0, 0)
	return p


## A reserve by the bench, where a venue has no seat for her (Match._reserves): standing at ease, hands together.
static func at_ease() -> Dictionary:
	var p := ready(0.2)
	p.upperarm_l = Vector3(-14, 0, 6)
	p.forearm_l = Vector3(-40, -30, 0)
	p.upperarm_r = Vector3(-14, 0, -6)
	p.forearm_r = Vector3(-40, 30, 0)
	return p


## How far the hip joints sit above the seat (m, the body's own units): the seat of her trousers on it, not in it.
const SIT_CLEAR := 0.085
## ToonBody's legs at rest: the hips bone's height, the hip joint below it, thigh and shin, the ankle's height.
const LEG_HIPS := 0.93
const LEG_HIP_DROP := 0.05
const LEG_THIGH := 0.43
const LEG_SHIN := 0.41
const LEG_ANKLE := 0.04


## A reserve sitting on her team's bench: seat (m, the seat's top over the floor) and back (m, how far behind where she
## stands her hips are: the node stands in front of the bench, her hips go back over the seat), both in the body's own
## units. Her hip joints SIT_CLEAR over the seat, her thighs forward along it and sloping down just enough that her
## shins hang straight to her feet flat on the floor where she would stand, her back a little forward, her hands on
## her thighs (the foundation crowd's seated fans: the soles on the floor, the seat of the trousers on the seat).
static func seated(seat: float, back: float) -> Dictionary:
	var hip_joint := seat + SIT_CLEAR
	# The knee's drop below the hip joint so the shin, hanging straight, puts the ankle at its standing height.
	var drop := hip_joint - LEG_SHIN - LEG_ANKLE
	var a := rad_to_deg(asin(clampf(drop / LEG_THIGH, -0.3, 0.95)))
	var p := {
		"hips_y": hip_joint + LEG_HIP_DROP - LEG_HIPS,
		"hips_fwd": -back,
		"hips": Vector3.ZERO,
		"spine": Vector3(6, 0, 0), "chest": Vector3(3, 0, 0), "neck": Vector3.ZERO, "head": Vector3(-7, 0, 0),
		"thigh_l": Vector3(-(90.0 - a), 0, 3), "shin_l": Vector3(90.0 - a, 0, 0), "foot_l": Vector3.ZERO,
		"thigh_r": Vector3(-(90.0 - a), 0, -3), "shin_r": Vector3(90.0 - a, 0, 0), "foot_r": Vector3.ZERO,
		# The hands resting on her thighs, a little in from the knees.
		"upperarm_l": Vector3(-8, 0, 7), "forearm_l": Vector3(-62, -14, 0), "hand_l": Vector3(12, 0, 0),
		"upperarm_r": Vector3(-8, 0, -7), "forearm_r": Vector3(-62, 14, 0), "hand_r": Vector3(12, 0, 0),
	}
	return p


## Standing up from the bench to clap a goal (t: seconds into it): upright, the hands meeting in front of her chest
## and parting again, a few claps a second.
static func clap(t: float) -> Dictionary:
	var p := ready(0.15)
	p.hips_y = 0.0
	var open := 0.5 + 0.5 * sin(t * 15.0)
	p.upperarm_l = Vector3(-48, 0, lerpf(-14.0, -2.0, open))
	p.upperarm_r = Vector3(-48, 0, lerpf(14.0, 2.0, open))
	p.forearm_l = Vector3(-62, -30, 0)
	p.forearm_r = Vector3(-62, 30, 0)
	p.head = Vector3(-6, 0, 0)
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

## The obstruction signal's arms (degrees, ToonBody's convention): the upper hand's arm raised forward a little above
## level, the lower's a little below, each drawn in toward the middle, the forearms turned so the palms face.
const OBSTRUCTION_UPPER := -97.0
const OBSTRUCTION_LOWER := -76.0
const OBSTRUCTION_IN := 16.0
const OBSTRUCTION_TURN := 90.0

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
			# Obstruction: both arms out in front, one hand over the other, palms facing: the arms straight, drawn
			# in toward the middle so the hands are in line; the upper hand (the award's side) palm down, the lower
			# palm up, the forearms turned a quarter about themselves (OBSTRUCTION_*: the test reads these).
			p["upperarm_" + hand] = Vector3(OBSTRUCTION_UPPER, 0, -OBSTRUCTION_IN * sx)
			p["upperarm_" + other] = Vector3(OBSTRUCTION_LOWER, 0, OBSTRUCTION_IN * sx)
			# (The same turn on both forearms: the upper hand's palm comes round to face down, the lower's up.)
			p["forearm_" + hand] = Vector3(0, -OBSTRUCTION_TURN * sx, 0)
			p["forearm_" + other] = Vector3(0, -OBSTRUCTION_TURN * sx, 0)
			p["hand_" + hand] = Vector3.ZERO
			p["hand_" + other] = Vector3.ZERO
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
