class_name KhoRules
extends RefCounted
## The laws of kho kho, with nothing of the match's drawing or AI in it: the match asks, these answer. Each rule is in
## docs/RULES.md with its source, and tests/test_runner.gd checks each one (_rules).
##
## Field space: x runs along the central lane (the poles at x = -pole_gap/2 and +pole_gap/2), z across it (the side
## lines at z = -width/2 and +width/2). A "half" is the side of the central lane: +1 (z > 0) or -1. A chaser's
## "direction" is the pole he is running toward along x: +1, -1, or 0 before he has taken one.

const CLASSIC := 0
const FAST := 1

## Outs and the fouls the umpires whistle.
const OUT_TOUCH := "touch"          # touched by the active chaser's hand
const OUT_DIVE := "dive"            # touched in a sky dive
const OUT_POLE := "pole"            # touched in a pole dive
const OUT_LIMITS := "limits"        # went out of the field's limits
const OUT_LATE := "late"            # entered late
const FOUL_TURN := "turn_back"      # the active chaser turned back off his direction
const FOUL_LANE := "cross_lane"     # he crossed the central lane outside the free zones
const FOUL_LATE_KHO := "late_kho"   # the kho came after he had passed the seated chaser's cross lane
const FOUL_EARLY := "early_rise"    # a seated chaser rose before the kho
const FOUL_CALL := "kho_call"       # "kho" called before the touch, or a touch with no call

const REACH := 0.95          # m: how far the active chaser's hand reaches, from his centre, for a touch or a kho
const KHO_LATE_TOL := 0.15   # m past the cross lane's far edge that an umpire still lets go
const TURN_TOL := 0.45       # m/s backwards before an umpire calls him turning back


## The field for a rule book (docs/RULES.md "The field"). Classic: 27 x 16 m, 24 m between the poles, eight cross lanes
## 35 cm wide, the first 2.55 m from each pole and the rest 2.30 m apart, 1.5 m free zones. Fast: 22 x 16 m, 1.5 m free
## zones so 19 m between the poles, six cross lanes 40 cm wide, set out at the same 2.55 m and 2.30 m.
static func field(fmt: int) -> Dictionary:
	var fast := fmt == FAST
	var n := 6 if fast else 8
	var cross := 0.40 if fast else 0.35
	var gap := 19.0 if fast else 24.0
	var first := 2.55
	var spacing := 2.30
	var xs := []
	var x := -gap * 0.5 + first + cross * 0.5
	for i in n:
		xs.append(x)
		x += cross + spacing
	return {
		"length": 22.0 if fast else 27.0, "width": 16.0, "pole_gap": gap, "free_zone": 1.5,
		"lobby": 2.0 if fast else 1.5, "lane_w": 0.30, "cross_w": cross, "squares": n, "square_x": xs,
		"pole_h": 1.225, "pole_d": 0.095,
	}


## Which way the seated chaser in square i faces: +1 (toward z > 0) or -1; the squares alternate.
static func square_face(i: int) -> int:
	return 1 if i % 2 == 0 else -1


static func half_of(z: float) -> int:
	return 1 if z >= 0.0 else -1


## In a free zone: past a pole, where a chaser may move as he likes.
static func in_free_zone(f: Dictionary, p: Vector3) -> bool:
	return absf(p.x) >= float(f.pole_gap) * 0.5


## Inside the limits: the field's lines are its limits (a defender with a foot on the line is still in).
static func in_limits(f: Dictionary, p: Vector3, margin := 0.0) -> bool:
	return absf(p.x) <= float(f.length) * 0.5 + margin and absf(p.z) <= float(f.width) * 0.5 + margin


## On the central lane (between the poles, within its 30 cm), where a chaser only sits or rises.
static func on_lane(f: Dictionary, p: Vector3, body := 0.0) -> bool:
	return not in_free_zone(f, p) and absf(p.z) < float(f.lane_w) * 0.5 + body


# ---------------------------------------------------------------- the active chaser

## What the umpires watch on the active chaser: his direction, his side of the lane, and any foul not yet put right.
class Chase:
	var dir := 0           # +1 or -1: the pole he must run toward; 0 until he takes one
	var half := 1          # the side of the central lane he is on
	var foul := ""         # a foul being whistled until it is put right, by a kho or the free zone ("" none)
	var mended := 0.0      # m run his proper way since a turning-back foul
	var wazir := false     # the fast game's wazir: free of the direction rule, not of the lane
	var start_x := 0.0     # where he rose: he takes his direction once he leaves it
	var settled := true    # out of a free zone, his side is the one he takes once clear of the lane

	func reset_at(x: float, p_half: int, p_wazir := false) -> void:
		dir = 0
		half = p_half
		foul = ""
		mended = 0.0
		wazir = p_wazir
		start_x = x


## The active chaser's run this frame, from pos with velocity vel over dt: takes his direction, frees it in a free
## zone, and returns the foul he has just committed ("" none). The foul stays on c until it is put right.
static func step_chase(f: Dictionary, c: Chase, pos: Vector3, vel: Vector3, dt: float) -> String:
	var fz := in_free_zone(f, pos)
	if fz:
		# Round the pole: in the free zone he may go either way and come out on either side; he comes out toward the
		# middle, so that is his direction, and the foul of crossing the lane cannot be his here.
		c.dir = -1 if pos.x > 0.0 else 1
		c.half = half_of(pos.z)
		c.settled = false
		if c.foul == FOUL_TURN or c.foul == FOUL_LANE:
			c.foul = ""
		return ""
	var new_foul := ""
	if not c.settled:
		if absf(pos.z) > float(f.lane_w) * 0.5 + 0.25:
			c.half = half_of(pos.z)
			c.settled = true
		return ""
	# The lane: he may not cross it between the poles.
	var side := half_of(pos.z) if absf(pos.z) > float(f.lane_w) * 0.5 else c.half
	if side != c.half and c.foul == "":
		new_foul = FOUL_LANE
		c.foul = FOUL_LANE   # put right, as a turning-back foul is, by a kho or the free zone
	# His direction: the way he first goes once he leaves where he rose.
	if c.dir == 0:
		if absf(pos.x - c.start_x) > 0.25 or absf(vel.x) > 1.2:
			c.dir = 1 if vel.x >= 0.0 else -1
	elif not c.wazir:
		var back := -vel.x * float(c.dir)
		if back > TURN_TOL and c.foul == "":
			new_foul = FOUL_TURN
			c.foul = FOUL_TURN
			c.mended = 0.0
		elif c.foul == FOUL_TURN:
			# Made to go his proper way again; the foul stands until he gives a kho (a new Chase) or reaches a
			# free zone (rules text via search: "compel the attacker to go in the direction opposite"; cleared
			# by a kho or the free zone, the glossary).
			var fwd := vel.x * float(c.dir) * dt
			if fwd > 0.0:
				c.mended += fwd
	if c.wazir and vel.length() > 1.0 and absf(vel.x) > 0.6:
		c.dir = 1 if vel.x > 0.0 else -1   # the wazir runs where he likes; his "direction" is just the way he goes
	return new_foul


## Can the active chaser at pos (running c.dir) give a kho to the seated chaser in square i at sq_x, facing face?
## "ok", "late" (he has passed the cross lane: a foul), "front" (he is not behind him), "far" (out of reach).
static func kho_check(f: Dictionary, c: Chase, pos: Vector3, sq_x: float, face: int) -> String:
	# From behind: the giver is on the side the seated chaser's back is to.
	if half_of(pos.z) != -face and absf(pos.z) > float(f.lane_w) * 0.5:
		return "front"
	var dx := pos.x - sq_x
	if Vector2(dx, pos.z).length() > REACH + 0.35:
		return "far"
	if c.dir != 0 and not c.wazir and dx * float(c.dir) > float(f.cross_w) * 0.5 + KHO_LATE_TOL:
		return "late"
	return "ok"


## A touch by the active chaser on a defender: counts unless a foul is being whistled, either of them is out of the
## limits, or the defender is across the lane from him (he may not reach over it).
static func touch_counts(f: Dictionary, c: Chase, chaser: Vector3, defender: Vector3) -> bool:
	if c.foul != "":
		return false
	if not in_limits(f, chaser, 0.05) or not in_limits(f, defender):
		return false
	if not in_free_zone(f, chaser) and float(c.half) * defender.z < -float(f.lane_w) * 0.5:
		return false
	return true


## A defender is out of the limits once he is past a line (Rules: losing contact with the ground inside the limits).
static func out_of_limits(f: Dictionary, p: Vector3) -> bool:
	return not in_limits(f, p)


# ---------------------------------------------------------------- scoring and the clock

## The chasing side's points for an out: 1 in the classic game, 2 in the fast one.
static func points_for_out(fmt: int) -> int:
	return 2 if fmt == FAST else 1


## The fast game's dream run: the defending side's points for a batch on the field t seconds: 1 at three minutes,
## another every 30 s after. The classic game has none.
static func dream_points(fmt: int, t: float) -> int:
	if fmt != FAST or t < 180.0:
		return 0
	return 1 + int(floor((t - 180.0) / 30.0))


## A turn's real length: 9 minutes in the classic game (seniors), 7 in the fast one.
static func real_turn(fmt: int) -> float:
	return 420.0 if fmt == FAST else 540.0


## Seconds a new batch has to come on after the last of the batch before is out, in the fast game; the classic game
## gives them until the successful chaser's next kho (late_entry).
const BATCH_WINDOW := 30.0


## Is the next batch late? Classic: if a kho has been given since the last defender went out and they are not yet in.
## Fast: if more than BATCH_WINDOW seconds have gone since.
static func late_entry(fmt: int, since_out: float, khos_since: int) -> bool:
	if fmt == FAST:
		return since_out > BATCH_WINDOW
	return khos_since > 0


## The defenders in batches of three, in the order the side gave; when every batch has been out the order starts again.
static func batch(order: Array, k: int) -> Array:
	var n := order.size() / 3
	if n <= 0:
		return []
	var b := k % n
	return order.slice(b * 3, b * 3 + 3)


## Who chases in each of the four turns: the side that chases first (a) and the other (b) take turns, A B A B; with
## the follow-on made (after the first innings) B chases twice running: A B B A.
static func chase_order(first: int, follow_on := false) -> Array:
	var a := first
	var b := 1 - first
	return [a, b, b, a] if follow_on else [a, b, a, b]


## The lead that lets a side make the other follow on: 9 points in the classic game, scaled to a shorter turn
## (docs/RULES.md "Follow-on"); never less than 3. The fast game has no follow-on.
static func follow_on_lead(fmt: int, turn_len: float) -> int:
	if fmt == FAST:
		return 0
	return maxi(3, roundi(9.0 * turn_len / real_turn(fmt)))


## After the first innings (turns 1 and 2, A then B): may A, the side that chased first, make B follow on? A must lead
## by the follow-on lead or more.
static func can_follow_on(fmt: int, turn_len: float, first: int, score: Array) -> bool:
	if fmt == FAST:
		return false
	return int(score[first]) - int(score[1 - first]) >= follow_on_lead(fmt, turn_len)


## Is the match over after turn t (0-3) with the order given, and the score? A side that made the other follow on
## wins without its second chase if the other is still behind after its own.
static func over_after(t: int, order: Array, score: Array) -> bool:
	if t >= 3:
		return true
	if t == 2 and order[1] == order[2]:
		# The follow-on: the side chasing twice (order[1]) has had both its turns; the other chases again only if
		# it needs to.
		var follower := int(order[1])
		return int(score[follower]) < int(score[1 - follower])
	return false


## The winner (0, 1) or -1 for a tie.
static func winner(score: Array) -> int:
	if int(score[0]) == int(score[1]):
		return -1
	return 0 if int(score[0]) > int(score[1]) else 1


## A tied knockout match goes to one more innings (each side chases a turn); still tied, to minimum chases: each side
## chases until its first out, and the quicker out wins. min_times: [side 0's seconds, side 1's] (-1: no out in the
## turn). Returns the winner, or -1 while still tied (another minimum chase).
static func min_chase_winner(min_times: Array) -> int:
	var a := float(min_times[0])
	var b := float(min_times[1])
	if a < 0.0 and b < 0.0:
		return -1
	if a < 0.0:
		return 1
	if b < 0.0:
		return 0
	if is_equal_approx(a, b):
		return -1
	return 0 if a < b else 1
