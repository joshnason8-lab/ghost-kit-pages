class_name Rules
extends RefCounted
## The Rules of Netball (World Netball, 2024 edition, in force since 1 January 2024 and still current in October
## 2026), as pure functions the match calls and the tests check (tests/test_runner.gd, "_rules"). Nothing here moves
## a player or draws anything. docs/RULES.md has each rule's number, its source and how the game plays it.
##
## Teams are 0 and 1. A team attacks the goal at the end dir (+1 or -1) given by ends_for_quarter.

const POSITIONS := ["GS", "GA", "WA", "C", "WD", "GD", "GK"]

## Each position's playing areas (the rules' areas 1-5, from the end the team attacks: 1 the attacking circle, 2 the
## rest of the attacking third, 3 the centre third, 4 the rest of the defending third, 5 the defending circle).
const AREAS := {
	"GS": [Court.A_ATT_CIRCLE, Court.A_ATT_THIRD],
	"GA": [Court.A_ATT_CIRCLE, Court.A_ATT_THIRD, Court.A_CENTRE],
	"WA": [Court.A_ATT_THIRD, Court.A_CENTRE],
	"C": [Court.A_ATT_THIRD, Court.A_CENTRE, Court.A_DEF_THIRD],
	"WD": [Court.A_CENTRE, Court.A_DEF_THIRD],
	"GD": [Court.A_CENTRE, Court.A_DEF_THIRD, Court.A_DEF_CIRCLE],
	"GK": [Court.A_DEF_THIRD, Court.A_DEF_CIRCLE],
}

## Who marks whom: each position and the opposing position she usually guards (and is guarded by).
const OPPOSITE := {"GS": "GK", "GA": "GD", "WA": "WD", "C": "C", "WD": "WA", "GD": "GA", "GK": "GS"}

const HOLD_LIMIT := 3.0              # seconds a player may hold the ball (held ball)
const SHORT_PASS_MIN := 0.9          # metres between thrower and catcher: room for an opponent to intercept
const OUT_OF_PLAY_GAP := 0.9         # the penalised player stands beside the thrower, away from her

## Free passes and penalty passes (R6): what each infringement gives the other team (R11 playing the ball, R12 passing
## distances, R13 footwork, R14 offside, R15 out of court, R16 obstruction, R17 contact).
const FREE := "free_pass"
const PENALTY := "penalty_pass"
const THROW_IN := "throw_in"
const CENTRE := "centre_pass"

const INFRINGEMENTS := {
	"offside": FREE,
	"breaking": FREE,            # entering the centre third before the centre pass whistle
	"held_ball": FREE,           # held more than three seconds
	"footwork": FREE,
	"short_pass": FREE,
	"over_third": FREE,          # the ball over a whole third untouched
	"replayed_ball": FREE,
	"centre_pass_fault": FREE,   # the centre pass not caught in the centre third, or caught by GS/GK
	"incorrect_throw_in": THROW_IN,
	"obstruction": PENALTY,
	"contact": PENALTY,
	"intimidation": PENALTY,
}

## Time (R2): four quarters of 15 minutes; four minutes after the first and third, twelve
## at half-time (eight if both teams and the organiser agree). Extra time when a winner is needed: two halves of not
## more than seven minutes with one minute between them, then on until one team leads by two.
const QUARTER_MIN := 15.0
const INTERVALS := [4.0, 12.0, 4.0]      # minutes, after quarters 1, 2 and 3
const HALF_TIME_SHORT := 8.0
const ET_HALF_MIN := 7.0
const ET_BREAK_MIN := 1.0
const ET_LEAD := 2

## Stoppages and game management (R10, R18).
const INJURY_STOP := 30.0                # seconds to get an injured or bleeding player off
const SUSPENSION := 120.0
const SUSPENSIONS_TO_ORDER_OFF := 2      # the game's umpires order off a player suspended a second time                # seconds of playing time
const ORDERED_OFF_REPLACE := 240.0       # seconds of playing time before the team may replace her
const MIN_PLAYERS := 5

## League variants (the game's own names, docs/RULES.md "Variants"): the Double Zone, worth two in the last five
## minutes of each quarter from 3.0 m or more out; time-outs of 90 s, two a half; rolling substitutions.
const DZ_FROM := 3.0
const DZ_LAST := 300.0
const TIMEOUT_LEN := 90.0
const TIMEOUTS_PER_HALF := 2


# ---------------------------------------------------------------- areas

static func may_enter(pos: String, area: String) -> bool:
	return area in AREAS.get(pos, [])


## Offside (R14): a player is offside when she touches the ground in an area her position may not go into, with or
## without the ball. A line between two areas belongs to both, and since 2024 a player touching the line of her own
## area, without going over it, is not offside ("on the line is fine"): so a GS with a toe on the transverse line is
## onside; a foot beyond it, in the centre third, is offside. In the air above an area is not offside: callers test
## where a foot lands.
static func offside(pos: String, foot: Vector2, dir: int) -> bool:
	var areas := Court.areas_at(foot, dir)
	if areas.has(Court.A_OUT):
		return false   # off the court (fetching the ball, a throw-in): not an area of the court
	for a in areas:
		if may_enter(pos, a):
			return false   # in one of her areas, or on its line
	return true


## The nearest point to p that pos may stand on, margin metres inside her areas (for the AI and Keep me onside).
static func onside_point(pos: String, p: Vector2, dir: int, margin := 0.25) -> Vector2:
	# Clear of the line itself too: a line belongs to the areas either side of it.
	margin += Court.LINE_W * 0.5 + 0.01
	var q := Court.clamp_court(p, 0.15)
	var a: Array = AREAS[pos]
	# Along the court, in the team's own frame: the thirds she may be in.
	var can_def := Court.A_DEF_THIRD in a or Court.A_DEF_CIRCLE in a
	var can_cen := Court.A_CENTRE in a
	var can_att := Court.A_ATT_THIRD in a or Court.A_ATT_CIRCLE in a
	var fmin := -Court.HALF_L if can_def else (-Court.THIRD_X + margin if can_cen else Court.THIRD_X + margin)
	var fmax := Court.HALF_L if can_att else (Court.THIRD_X - margin if can_cen else -Court.THIRD_X - margin)
	var ax := clampf(q.x * dir, fmin, fmax)
	q.x = ax * dir
	# The circles: out of one she may not enter, into the third round it.
	for end in [dir, -dir]:
		var circle := Court.A_ATT_CIRCLE if end == dir else Court.A_DEF_CIRCLE
		if not (circle in a) and q.distance_to(Court.goal_post(end)) < Court.CIRCLE_R + margin:
			var from := Court.goal_post(end)
			var d := (q - from)
			if d.length() < 0.01:
				d = Vector2(-end, 0)
			q = from + d.normalized() * (Court.CIRCLE_R + margin)
			q = Court.clamp_court(q, 0.15)
	return q


# ---------------------------------------------------------------- the centre pass (R8)

## The team taking the next centre pass: they alternate through the match, whoever scored. first is the team that
## took the match's first centre pass; n the number of centre passes taken so far.
static func centre_pass_team(first: int, n: int) -> int:
	return first if n % 2 == 0 else 1 - first


## Before the whistle: the C taking the pass has a foot wholly inside the centre circle; the other C anywhere in the
## centre third; everyone else in her own goal third (she may not be in the centre third). Returns the positions of
## team t that are wrong (stood in the centre third early: "breaking", a free pass).
static func centre_setup_faults(t: int, cp_team: int, spots: Dictionary, dir: int) -> Array:
	var bad := []
	for pos in spots:
		var p: Vector2 = spots[pos]
		if pos == "C":
			if t == cp_team:
				if p.length() > Court.CENTRE_R - 0.12:
					bad.append(pos)
			elif Court.third_abs(p.x) != 1:
				bad.append(pos)
		elif absf(p.x) <= Court.THIRD_X + Court.LINE_W * 0.5:
			bad.append(pos)
	return bad


## The centre pass is good when it is caught (or touched) in the centre third by a player standing wholly in it, or
## whose first landing foot is wholly in it; GS and GK may not be in the centre third at all.
static func centre_pass_ok(pos: String, landing_foot: Vector2) -> bool:
	if pos == "GS" or pos == "GK":
		return false
	return absf(landing_foot.x) < Court.THIRD_X - Court.LINE_W * 0.5


# ---------------------------------------------------------------- playing the ball (R11), passing distances (R12), footwork (R13)

## Held ball: more than three seconds.
static func held_ball(held_for: float) -> bool:
	return held_for > HOLD_LIMIT


## Short pass: there must be room for an opponent to intercept between the thrower's and the catcher's hands.
static func short_pass(from: Vector2, to: Vector2) -> bool:
	return from.distance_to(to) < SHORT_PASS_MIN


## Over a third: the ball may not cross a whole third without being caught or touched by a player in it. thrown_x
## and caught_x are where it left the thrower's hands and where it was caught, along the court.
static func over_third(thrown_x: float, caught_x: float) -> bool:
	return absi(Court.third_abs(thrown_x) - Court.third_abs(caught_x)) >= 2


## Replayed ball: a player may not catch the ball again after throwing it until another player (or the goal post)
## has touched it.
static func replayed_ball(thrower: int, catcher: int, touched_since: bool) -> bool:
	return thrower == catcher and not touched_since


## Footwork (R13): the landing foot, and what the other may do. A player who lands on one foot may step with the other
## and pivot on the landing foot as often as she likes; once she lifts the landing foot she must pass or shoot before
## it is grounded again. Landing on both feet, she chooses which is her landing foot. She may not drag or slide the
## landing foot, hop on either foot, or jump from both feet and land on both before she releases the ball.
class Footwork:
	var landing := ""          # "l" or "r" once fixed; "both" when she landed on both and has not moved yet
	var lifted := false        # the landing foot is off the ground
	var fault := ""            # the infringement, once there is one

	func land(foot: String) -> void:
		landing = foot   # "l", "r" or "both"
		lifted = false

	## A foot leaves the ground. With both down, the first foot lifted makes the other the landing foot.
	func lift(foot: String) -> void:
		if landing == "both":
			landing = "r" if foot == "l" else "l"
			return
		if foot == landing:
			lifted = true

	## A foot comes down. The landing foot regrounded after lifting it, while still holding the ball, is footwork.
	func ground(foot: String) -> void:
		if landing == "both":
			return
		if foot == landing and lifted:
			fault = "footwork"
		if foot != landing and lifted:
			# Stepping off the landing foot onto the other is fine; that foot must not then be hopped on.
			pass

	## The landing foot dragged or slid along the floor while it bears weight.
	func drag(foot: String) -> void:
		if foot == landing and not lifted:
			fault = "footwork"

	## A hop: one foot leaves the ground and comes down on the same foot (either foot).
	func hop(_foot: String) -> void:
		fault = "footwork"

	## Jumping from both feet and landing on both while holding the ball.
	func jump_both() -> void:
		fault = "footwork"


# ---------------------------------------------------------------- obstruction (R16) and contact (R17)

## Obstruction of the player with the ball: a defender trying to intercept or defend her must have at least 0.9 m
## on the ground between her nearer foot and the attacker's landing foot. Standing closer without defending is not
## obstruction (arms down, not trying to take the ball). A defender may jump from 0.9 m and land closer, if she did
## not leap toward the attacker.
static func obstruction(landing_foot: Vector2, defender_foot: Vector2, defending: bool, leapt_toward := false) -> bool:
	if not defending:
		return false
	return landing_foot.distance_to(defender_foot) < Court.DEFEND_DIST - 0.001 or leapt_toward


## Contact (R16): play is penalised when contact interferes with the play of an opponent (pushing, tripping, holding,
## charging, a hand on the ball held by an opponent, not giving a player who has won the ball in the air room to land).
## Incidental contact that does not affect play is not penalised. impact: how hard (0-1); affected: whether the
## opponent's play was changed by it.
static func contact(impact: float, affected: bool) -> bool:
	return affected and impact > 0.15


# ---------------------------------------------------------------- scoring (R9)

## A goal may be scored only by GS or GA, from inside the goal circle her team attacks (its line included); a free
## pass in the circle may not be shot.
static func may_shoot(pos: String, foot: Vector2, dir: int, from_free_pass := false) -> bool:
	if from_free_pass:
		return false
	if pos != "GS" and pos != "GA":
		return false
	return Court.in_circle(foot, dir)


## Advance (R18, game management): an umpire may move a free or penalty pass up to half a third toward the goal the
## team taking it attacks (into the goal circle if the infringement was in that goal third). dir: the end it attacks.
static func advance(at: Vector2, dir: int) -> Vector2:
	var in_goal_third := at.x * dir > Court.THIRD_X
	var to := at + Vector2(Court.THIRD * 0.5 * dir, 0.0)
	var lim := Court.HALF_L - 0.3 if in_goal_third else Court.HALF_L - Court.CIRCLE_R - 0.3
	to.x = clampf(to.x * dir, -Court.HALF_L, lim) * dir
	return to


## Escalate (R18): a free pass may be raised to a penalty pass (in the goal circle it attacks, a penalty pass or shot).
static func escalate(a: Dictionary, dir: int) -> Dictionary:
	var b := a.duplicate()
	b.kind = PENALTY
	b.shot = Court.in_circle(a.at, dir)
	b.escalated = true
	return b


## A goal's worth: 1 under the World Netball rules; with the Double Zone variant, 2 from 3.0 m or more from the post in
## the last five minutes of a quarter (and in extra time's last five).
static func goal_value(foot: Vector2, dir: int, double_zone: bool, time_left: float) -> int:
	if not double_zone or time_left > DZ_LAST:
		return 1
	return 2 if foot.distance_to(Court.goal_post(dir)) >= DZ_FROM else 1


## A shot that left the shooter's hands before the whistle ending a period counts if it goes in (2024).
static func goal_counts(released_before_whistle: bool, through_ring: bool) -> bool:
	return released_before_whistle and through_ring


# ---------------------------------------------------------------- awards

## What an infringement by team `by` gives the other team, and whether it may be a shot: a penalty in the goal circle
## the non-offending team attacks, taken by its GS or GA, is a "penalty pass or shot".
static func award(kind: String, by: int, at: Vector2, taker_pos: String, taker_dir: int) -> Dictionary:
	var a := {"to": 1 - by, "kind": String(INFRINGEMENTS.get(kind, FREE)), "at": at, "shot": false, "why": kind}
	if a.kind == PENALTY and (taker_pos == "GS" or taker_pos == "GA") and Court.in_circle(at, taker_dir):
		a.shot = true
	return a


## Two players of opposite teams infringe at once (2024: no more toss-up): the team last in possession keeps the
## ball, where it was when play stopped; in the goal circle it attacks, its GS or GA may shoot (dir: the end that team
## attacks).
static func simultaneous(last_possession: int, at: Vector2, dir := 0) -> Dictionary:
	var shot := dir != 0 and Court.in_circle(at, dir)
	return {"to": last_possession, "kind": FREE, "at": at, "shot": shot, "why": "simultaneous"}


## The ball out of court: a throw-in to the team that did not last touch it, from where it crossed the line. The
## thrower stands outside with one foot within 15 cm of the line.
static func throw_in(last_touch: int, crossed: Vector2) -> Dictionary:
	var at := Vector2(clampf(crossed.x, -Court.HALF_L, Court.HALF_L), clampf(crossed.y, -Court.HALF_W, Court.HALF_W))
	return {"to": 1 - last_touch, "kind": THROW_IN, "at": at, "shot": false, "why": "out_of_court"}


## Where the thrower of a throw-in stands: just outside the line where the ball crossed it.
static func throw_in_spot(at: Vector2) -> Vector2:
	var out := at
	if absf(at.y) >= Court.HALF_W - 0.01:
		out.y = signf(at.y) * (Court.HALF_W + 0.1)
	if absf(at.x) >= Court.HALF_L - 0.01:
		out.x = signf(at.x) * (Court.HALF_L + 0.1)
	return out


## Whose positions may take a pass at p for a team attacking dir: everyone allowed in that area (the AI picks the
## nearest of them).
static func takers(at: Vector2, dir: int) -> Array:
	var area := Court.area_of(at, dir)
	if area == Court.A_OUT:
		# A throw-in: the area just inside the line.
		area = Court.area_of(Court.clamp_court(at, 0.3), dir)
	var out := []
	for pos in POSITIONS:
		if may_enter(pos, area):
			out.append(pos)
	return out


# ---------------------------------------------------------------- time

## Which end team t attacks in quarter q (1-4; 5 and 6 the halves of extra time). The teams change ends every
## quarter, and at the break in extra time. first_dir: team 0's end in the first quarter.
static func ends_for_quarter(t: int, q: int, first_dir: int) -> int:
	var d := first_dir if t == 0 else -first_dir
	return d if q % 2 == 1 else -d


## The interval after period q, in minutes: four after the first and third quarters, twelve at half-time (eight by
## agreement), one between the halves of extra time, and four between full time and extra time (q 4).
static func interval_after(q: int, short_half := false) -> float:
	match q:
		1, 3:
			return INTERVALS[0]
		2:
			return HALF_TIME_SHORT if short_half else INTERVALS[1]
		4:
			return INTERVALS[0]
		5:
			return ET_BREAK_MIN
	return 0.0


## Whether the match is over: after the fourth quarter unless it is level and a winner is needed; extra time's two
## halves; then play on until one team leads by two.
static func match_over(q: int, clock_done: bool, score: Array, need_winner: bool) -> bool:
	if q < 4 or (q == 4 and not clock_done):
		return false
	var level: bool = int(score[0]) == int(score[1])
	if q == 4:
		return not (level and need_winner)
	if q == 5:
		return false
	if q == 6 and clock_done:
		return not level
	if q >= 7:
		return absi(int(score[0]) - int(score[1])) >= ET_LEAD
	return false


## The number of the next period after q, with the score as it stands (5, 6: extra time's halves; 7: on to a two-goal
## lead), or 0 when the match is over.
static func next_period(q: int, score: Array, need_winner: bool) -> int:
	if q < 4:
		return q + 1
	var level: bool = int(score[0]) == int(score[1])
	if q == 4:
		return 5 if level and need_winner else 0
	if q == 5:
		return 6
	if q == 6:
		return 7 if level else 0
	return 0


## A period's length in seconds. quarter_min: the quarter length chosen (15 is the real one); extra time scales with
## it (7 of 15).
static func period_length(q: int, quarter_min: float) -> float:
	if q <= 4:
		return quarter_min * 60.0
	if q <= 6:
		return ET_HALF_MIN * 60.0 * quarter_min / QUARTER_MIN
	return INF   # on to a two-goal lead


## The Double Zone is live in the last five minutes of a quarter (scaled to a shorter quarter: its last third).
static func double_zone_live(time_left: float, quarter_min: float) -> bool:
	return time_left <= DZ_LAST * minf(1.0, quarter_min / QUARTER_MIN)


## A team may play with five or six, leaving positions empty; it may not start or go on with fewer than five.
static func enough_players(on_court: int) -> bool:
	return on_court >= MIN_PLAYERS
