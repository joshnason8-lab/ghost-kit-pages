class_name Rules
extends RefCounted
## The IFF Rules of the Game (edition valid from 1 July 2026), as the match uses them. Pure: no nodes, no drawing.
## The match tells it what happened (a goal, an offence, the ball out, a whistle) and it answers with the decision,
## where play restarts and what the clock and penalty bench do. Every decision here has a test in tests/test_runner.gd,
## and every rule a line in docs/RULES.md with its number.
##
## Floor coordinates are Vector2(x, z) in metres: x along the rink's length (-20 .. 20), z across it (-10 .. 10). A
## team's "end" is the sign of x at the goal it defends.

# ---------------------------------------------------------------- the rink (101-105)

const LENGTH := 40.0            # 101: 40 x 20 m, rounded corners
const WIDTH := 20.0
const HALF_L := 20.0
const HALF_W := 10.0
const CORNER_R := 1.5           # 101 leaves the radius to the board's certification: about 1.5 m on IFF boards
const BOARD_H := 0.5            # Material Regulations: boards 50 cm high
const GOAL_LINE := 16.5         # 102: the goal crease 2.85 m from the end board, the goalkeeper area 0.65 m in front
                                # of its rear line, its rear line the goal line: 2.85 + 0.65 = 3.5 m from the board
const CREASE_BACK := 17.15      # 102(3): the goal crease, 4 m deep x 5 m wide, 2.85 m from the end board
const CREASE_FRONT := 13.15
const CREASE_HALF_W := 2.5
const GK_AREA_FRONT := 15.5     # 102(4): the goalkeeper area, 1 m deep x 2.5 m wide, its rear line the goal line
const GK_AREA_HALF_W := 1.25
const GOAL_W := 1.6             # 103: the goal's opening, 160 x 115 cm, 65 cm deep
const GOAL_H := 1.15
const GOAL_D := 0.65
const DOT_FROM_BOARD := 1.5     # 102: face-off dots 1.5 m from the long sides, on the centre line and on the goal
                                # lines' extensions
const SUB_ZONE_FROM_CENTRE := 5.0   # 104: each substitution zone begins 5 m from the centre line ...
const SUB_ZONE_LEN := 10.0          # ... and is 10 m long (2022; 2026 may run it to the goal line's extension)
const HIT_IN_FROM_BOARD := 1.5  # 504: a hit-in 1.5 m from the board
const DISTANCE := 3.0           # 504, 506, 501: opponents at least 3 m from the ball, sticks included
const FREE_HIT_FROM_GK_AREA := 3.5  # 506: never nearer the goalkeeper area (the small one) than 3.5 m

const BALL_D := 0.072           # Material Regulations: 72 mm, 26 holes, about 23 g
const BALL_MASS := 0.023

# ---------------------------------------------------------------- time (201-204)

const PERIODS := 3              # 201: three periods of 20 minutes, two 10-minute intervals
const PERIOD_S := 1200.0
const INTERVAL_S := 600.0
const LAST_EFFECTIVE_S := 180.0 # 201 (2026): the last 3 minutes of regular time are always effective time
const TIMEOUT_S := 30.0         # 202: one 30-second timeout a team
const OT_IFF_S := 600.0         # 203: overtime of 10 minutes, sudden victory
const OT_LEAGUE_S := 300.0      # the national leagues' regular-season overtime: 5 minutes (SIBF 2025/26)
const SHOOTERS := 5             # 204: five different field players a team, then one a team until decided
const GK_HOLD_S := 3.0          # 507: the goalkeeper may control the ball 3 seconds at most
const PEN_MINOR_S := 120.0      # 604
const PEN_MAJOR_S := 300.0      # 606
const PEN_PERSONAL_S := 600.0   # 609
const MAX_RUNNING := 2          # 601: at most two of a team's bench penalties run at once

## Clock modes: the IFF's effective time (stopped at every whistle), or a league's running time with the last three
## minutes of regular time effective (201, 2026).
const CLOCK_EFFECTIVE := 0
const CLOCK_RUNNING := 1

# ---------------------------------------------------------------- the offences (507, 605, 607, 610, 614, 703)

## id: [rule, consequence]. The consequence is the least the offence leads to; a dangerous or violent form of a
## free-hit offence is a minor (605) or major (607) bench penalty (sanction()).
const OFFENCES := {
	"stick_hit": ["507.1", "free_hit"],          # hitting, blocking, lifting or kicking an opponent's stick
	"hook": ["507.1", "free_hit"],               # hooking the stick
	"high_stick": ["507.2", "free_hit"],         # stick above the waist in the back-swing or follow-through
	"high_ball": ["507.3", "free_hit"],          # playing the ball with the stick or foot above knee height
	"between_legs": ["507.4", "free_hit"],       # stick, foot or leg between an opponent's legs
	"push": ["507.5", "free_hit"],               # pushing: only shoulder-to-shoulder contact is allowed
	"obstruct": ["507.6", "free_hit"],           # moving to obstruct an opponent not playing the ball
	"head": ["507.8", "free_hit"],               # playing the ball with the head
	"hand": ["507.9", "free_hit"],               # a field player playing the ball with a hand or arm
	"jump": ["507.10", "free_hit"],              # jumping (both feet off the floor) to play the ball
	"lying": ["507.11", "free_hit"],             # playing the ball sitting, lying or on two knees
	"gk_area": ["507.12", "free_hit"],           # a field player in the goalkeeper area (2026: never through it)
	"gk_collision": ["507.12", "free_hit"],      # no reasonable effort to avoid the goalkeeper in the crease (2026)
	"no_stick": ["507.13", "free_hit"],          # playing without a stick, or with a broken one
	"gk_over_centre": ["507.15", "free_hit"],    # a goalkeeper's throw or kick over the centre line in the air
	"gk_hold": ["507.16", "free_hit"],           # the goalkeeper holding the ball over 3 seconds
	"gk_backpass": ["507.17", "free_hit"],       # the goalkeeper taking a team-mate's deliberate pass in the hands
	"gk_outside": ["507.18", "free_hit"],        # the goalkeeper playing the ball with the hands outside the crease
	"delay": ["507.20", "free_hit"],             # passive play, delaying a fixed situation
	"bad_restart": ["507.21", "free_hit"],       # a hit-in or free-hit dragged, flicked or lifted
	"distance": ["605", "pen2"],                 # not keeping 3 m at a fixed situation, after a warning
	"too_many": ["605", "pen2"],                 # too many players on the rink
	"hold": ["605", "pen2"],                     # holding an opponent or his stick
	"trip": ["605", "pen2"],                     # tripping / hooking the legs
	"slash": ["605", "pen2"],                    # a dangerous stick hit
	"charge": ["605", "pen2"],                   # charging, pushing into the boards
	"block_lying": ["605", "pen2"],              # lying down to block a shot
	"protest": ["605", "pen2"],                  # protesting a decision
	"rough_board": ["607", "pen5"],              # violent pushing into the board
	"violent_stick": ["607", "pen5"],            # violent hitting with the stick
	"unsporting": ["610", "pen10"],              # unsportsmanlike behaviour
	"fight": ["614", "match"],                   # brutal, violent play
}

## Which offences the AI or you can commit in a match, by how often a referee calls each in top matches (the free-hit
## offences far outnumber the penalties). Used by the match to pick what a contact was.
const CONTACT_CALLS := ["stick_hit", "hook", "push", "between_legs", "obstruct", "hold", "trip", "slash"]


static func offence_rule(id: String) -> String:
	return String(OFFENCES.get(id, ["?", ""])[0])


## The decision for an offence: free_hit, pen2, pen5, pen10 (a personal penalty, 609: always with a minor bench
## penalty, the player out 2 + 10 minutes) or match. A free-hit offence done dangerously is a minor bench
## penalty (605), violently a major one (607).
static func sanction(id: String, dangerous := false, violent := false) -> String:
	var base := String(OFFENCES.get(id, ["", "free_hit"])[1])
	if base == "free_hit":
		if violent:
			return "pen5"
		if dangerous:
			return "pen2"
	elif base == "pen2" and violent:
		return "pen5"
	return base


# ---------------------------------------------------------------- the areas

## end: the sign of x of the goal (-1 or 1).
static func in_goal_crease(p: Vector2, end: int) -> bool:
	var x := p.x * end
	return x >= CREASE_FRONT and x <= CREASE_BACK and absf(p.y) <= CREASE_HALF_W


static func in_gk_area(p: Vector2, end: int) -> bool:
	var x := p.x * end
	return x >= GK_AREA_FRONT and x <= GOAL_LINE and absf(p.y) <= GK_AREA_HALF_W


## Is a floor point inside the boards (corners rounded)?
static func in_rink(p: Vector2, margin := 0.0) -> bool:
	var hx := HALF_L - margin
	var hz := HALF_W - margin
	if absf(p.x) > hx or absf(p.y) > hz:
		return false
	var r := CORNER_R - margin
	if r <= 0.0:
		return true
	var c := Vector2(hx - r, hz - r)
	var a := Vector2(absf(p.x), absf(p.y))
	if a.x > c.x and a.y > c.y:
		return a.distance_to(c) <= r
	return true


## The nearest point on the boards' inside to a floor point, and the inward normal there.
static func board_contact(p: Vector2) -> Array:
	var s := Vector2(signf(p.x) if p.x != 0.0 else 1.0, signf(p.y) if p.y != 0.0 else 1.0)
	var a := Vector2(absf(p.x), absf(p.y))
	var c := Vector2(HALF_L - CORNER_R, HALF_W - CORNER_R)
	if a.x > c.x and a.y > c.y:
		var d := (a - c).normalized()
		return [(c + d * CORNER_R) * s, -d * s]
	if HALF_L - a.x < HALF_W - a.y:
		return [Vector2(HALF_L * s.x, p.y), Vector2(-s.x, 0)]
	return [Vector2(p.x, HALF_W * s.y), Vector2(0, -s.y)]


static func faceoff_dots() -> Array:
	var z := HALF_W - DOT_FROM_BOARD
	return [Vector2.ZERO, Vector2(0, -z), Vector2(0, z), Vector2(-GOAL_LINE, -z), Vector2(-GOAL_LINE, z),
		Vector2(GOAL_LINE, -z), Vector2(GOAL_LINE, z)]


## 503: a face-off at the nearest face-off dot to where the ball was (the centre spot only to start a period and after
## a goal, so it is not one of "the nearest").
static func nearest_faceoff(p: Vector2) -> Vector2:
	var best := Vector2(0, -(HALF_W - DOT_FROM_BOARD))
	for d in faceoff_dots().slice(1):
		if p.distance_to(d) < p.distance_to(best):
			best = d
	return best


## 504: a hit-in 1.5 m from the board where the ball left the rink, never behind the goal lines' extensions: from
## behind a goal line, at the nearest face-off dot on its extension.
static func hit_in_spot(exit: Vector2) -> Vector2:
	if absf(exit.x) > GOAL_LINE:
		return Vector2(GOAL_LINE * signf(exit.x), (HALF_W - DOT_FROM_BOARD) * (signf(exit.y) if exit.y != 0.0 else 1.0))
	var c: Array = board_contact(exit)
	var spot: Vector2 = c[0] + c[1] * HIT_IN_FROM_BOARD
	spot.x = clampf(spot.x, -(HALF_L - HIT_IN_FROM_BOARD), HALF_L - HIT_IN_FROM_BOARD)
	spot.y = clampf(spot.y, -(HALF_W - HIT_IN_FROM_BOARD), HALF_W - HIT_IN_FROM_BOARD)
	return spot


## 506: a free-hit where the offence was, but never behind a goal line's extension (then at the nearest face-off dot
## on it) and never nearer the goal crease than 3.5 m (then moved straight out from the crease to 3.5 m).
static func free_hit_spot(at: Vector2) -> Vector2:
	if absf(at.x) > GOAL_LINE:
		return Vector2(GOAL_LINE * signf(at.x), (HALF_W - DOT_FROM_BOARD) * (signf(at.y) if at.y != 0.0 else 1.0))
	var p := at
	for end: int in [-1, 1]:
		if gk_area_distance(p, end) < FREE_HIT_FROM_GK_AREA:
			# Out along the line from the centre of the goal line through the offence, to 3.5 m from the area.
			var g := Vector2(GOAL_LINE * end, 0.0)
			var dir := p - g
			if dir.length() < 0.01 or signf(dir.x) == float(end):
				dir = Vector2(-end, 0.0)
			dir = dir.normalized()
			var lo := 0.0
			var hi := 8.0
			for i in 30:
				var mid := (lo + hi) * 0.5
				if gk_area_distance(g + dir * mid, end) < FREE_HIT_FROM_GK_AREA:
					lo = mid
				else:
					hi = mid
			p = g + dir * hi
	p.y = clampf(p.y, -(HALF_W - 0.5), HALF_W - 0.5)
	return p


## The nearest point of the goal crease (4 x 5 m) of the goal at end.
static func crease_nearest(p: Vector2, end: int) -> Vector2:
	var x0 := CREASE_FRONT * end
	var x1 := CREASE_BACK * end
	return Vector2(clampf(p.x, minf(x0, x1), maxf(x0, x1)), clampf(p.y, -CREASE_HALF_W, CREASE_HALF_W))


static func crease_distance(p: Vector2, end: int) -> float:
	return p.distance_to(crease_nearest(p, end))


## How far p is from the goalkeeper area (1 x 2.5 m, its rear line the goal line) of the goal at end.
static func gk_area_distance(p: Vector2, end: int) -> float:
	var x0 := GK_AREA_FRONT * end
	var x1 := GOAL_LINE * end
	return p.distance_to(Vector2(clampf(p.x, minf(x0, x1), maxf(x0, x1)), clampf(p.y, -GK_AREA_HALF_W, GK_AREA_HALF_W)))


## A restart's own distance: the defending players keep 3 m; at a free-hit nearer than 3 m to the crease the
## defenders may stand on their own goal line in the crease (506).
static func keeps_distance(player: Vector2, ball: Vector2) -> bool:
	return player.distance_to(ball) >= DISTANCE - 0.05


# ---------------------------------------------------------------- goals (701-703)

## Whether a ball that crossed the goal line from the front counts. info:
##   attacker (team that played it last, -1 none), defending_team, how ("stick", "kick", "body", "head", "hand",
##   "gk_throw", "deflect_defender"), deliberate (bool: kicked or directed in on purpose), attack_offence (bool),
##   too_many (bool: the attacking team had too many players or a penalised player on), clock_done (bool), from_front.
## Returns {ok, reason}: reason the rule that disallowed it.
static func judge_goal(info: Dictionary) -> Dictionary:
	if not bool(info.get("from_front", true)):
		return {"ok": false, "reason": "702"}
	if bool(info.get("clock_done", false)):
		return {"ok": false, "reason": "701"}
	var last := int(info.get("last_team", -1))
	var defending := int(info.get("defending_team", -1))
	var how := String(info.get("how", "stick"))
	# An own goal counts however the defending side put it in (702).
	if last == defending:
		return {"ok": true, "reason": "702", "own_goal": true}
	if bool(info.get("too_many", false)):
		return {"ok": false, "reason": "703"}
	if bool(info.get("attack_offence", false)):
		return {"ok": false, "reason": "703"}
	match how:
		"stick", "deflect_defender":
			return {"ok": true, "reason": "702"}
		"gk_throw":
			return {"ok": true, "reason": "702"}   # 2026: a goalkeeper may score with a throw
		"body":
			# Off an attacker's body without an active movement, after correct stick play: allowed.
			return {"ok": not bool(info.get("deliberate", false)), "reason": "703" if bool(info.get("deliberate", false)) else "702"}
		"kick", "head", "hand":
			return {"ok": false, "reason": "703"}
	return {"ok": false, "reason": "703"}


# ---------------------------------------------------------------- the match's clock, score and penalty bench

class State:
	extends RefCounted
	var period := 1               # 1-3, 4 for overtime
	var clock := 0.0              # seconds played in this period
	var period_s := PERIOD_S
	var clock_mode := CLOCK_EFFECTIVE
	var knockout := false         # a draw goes to overtime and penalty shots (203, 204)
	var ot_s := OT_IFF_S
	var goals := [0, 0]
	var shots := [0, 0]
	var timeouts := [1, 1]
	var penalties := [[], []]     # each: {id, kind, left, mins, running, coincidental}
	var log := []                 # {t, period, kind, team, ...} for the box score
	var shootout := [[], []]      # each shot's result (true scored)
	var phase := "regular"        # regular | overtime | shootout | done
	var winner := -1

	func remaining() -> float:
		return maxf(0.0, (ot_s if period > PERIODS else period_s) - clock)

	## Is it the last three minutes of regular time (always effective time, 201)?
	func in_last_effective() -> bool:
		return period == PERIODS and remaining() <= LAST_EFFECTIVE_S

	## Does the clock run now? in_play: the ball is in play.
	func clock_runs(in_play: bool) -> bool:
		if phase == "done" or phase == "shootout":
			return false
		if in_play:
			return true
		return clock_mode == CLOCK_RUNNING and period <= PERIODS and not in_last_effective()

	## Advance the clock by dt. Penalties count down with the game clock. Returns "period_end" when the period's time
	## is up (the match then calls end_period()).
	func tick(dt: float, in_play: bool) -> String:
		if not clock_runs(in_play):
			return ""
		var step := minf(dt, remaining())
		clock += step
		for t in 2:
			for p in penalties[t]:
				if bool(p.running):
					p.left = maxf(0.0, float(p.left) - step)
			_expire(t)
		return "period_end" if remaining() <= 0.0 else ""

	func _expire(t: int) -> void:
		var keep := []
		for p in penalties[t]:
			if bool(p.running) and float(p.left) <= 0.0:
				log.append({"kind": "pen_end", "team": t, "id": p.id, "period": period, "t": clock})
				continue
			keep.append(p)
		penalties[t] = keep
		_start_waiting(t)

	## 603: at most two of a team's bench penalties run at once; the next starts as one ends.
	func _start_waiting(t: int) -> void:
		var running := 0
		for p in penalties[t]:
			if bool(p.running) and not bool(p.coincidental) and String(p.kind) != "pen10":
				running += 1
		for p in penalties[t]:
			if not bool(p.running) and String(p.kind) == "pen10":
				# A personal penalty runs once its own minor is over.
				var minor := false
				for q in penalties[t]:
					if String(q.id) == String(p.id) and String(q.kind) == "pen2":
						minor = true
				if not minor:
					p.running = true
				continue
			if running >= MAX_RUNNING:
				break
			if not bool(p.running):
				p.running = true
				if not bool(p.coincidental) and String(p.kind) != "pen10":
					running += 1

	## Field players a team has on the rink: five less its running bench penalties, never fewer than three.
	func strength(t: int) -> int:
		var n := 5
		for p in penalties[t]:
			if bool(p.running) and not bool(p.coincidental) and String(p.kind) in ["pen2", "pen5", "match"]:
				n -= 1
		return maxi(3, n)

	## Players of team t who may not play now (serving penalties).
	func in_box(t: int) -> Array:
		var out := []
		for p in penalties[t]:
			if String(p.id) != "" and not (p.id in out):
				out.append(p.id)
		return out

	## A penalty on team t for player id, served by server (a field player serves a goalkeeper's minor; a goalkeeper
	## sits his own major and personal penalties: the match decides). kind: pen2, pen5, pen10, match. A personal
	## penalty (pen10, 609) comes with a minor, both sat by the offender himself, the minor first; a match penalty
	## (613) with a major a team-mate serves, the player gone for the match.
	func add_penalty(t: int, id: String, kind: String, offence := "", server := "") -> void:
		var serve := server if server != "" else id
		match kind:
			"pen2":
				penalties[t].append({"id": serve, "kind": "pen2", "left": PEN_MINOR_S, "mins": 2, "running": false, "coincidental": false})
			"pen5":
				penalties[t].append({"id": serve, "kind": "pen5", "left": PEN_MAJOR_S, "mins": 5, "running": false, "coincidental": false})
			"pen10":
				# 609: the offender himself sits 2 + 10: the minor first (his team short), then the personal 10 minutes,
				# when a team-mate may take his place.
				penalties[t].append({"id": id, "kind": "pen2", "left": PEN_MINOR_S, "mins": 2, "running": false, "coincidental": false})
				penalties[t].append({"id": id, "kind": "pen10", "left": PEN_PERSONAL_S, "mins": 10, "running": false, "coincidental": false})
			"match":
				penalties[t].append({"id": server, "kind": "match", "left": PEN_MAJOR_S, "mins": 5, "running": false, "coincidental": false})
		log.append({"kind": "penalty", "team": t, "id": id, "pen": kind, "offence": offence, "period": period, "t": clock})
		_start_waiting(t)

	## 2026: penalties given to both teams at the same stoppage no longer take players off the rink: the matching
	## pairs serve their time but are replaced on the rink. Call after both are added.
	func mark_coincidental(kind: String) -> void:
		for t in 2:
			for i in range(penalties[t].size() - 1, -1, -1):
				var p: Dictionary = penalties[t][i]
				if String(p.kind) == kind and not bool(p.coincidental) and float(p.left) >= (PEN_MINOR_S if kind == "pen2" else PEN_MAJOR_S) - 0.01:
					p.coincidental = true
					p.running = true
					break
		_start_waiting(0)
		_start_waiting(1)

	## A goal for team t. 604: a minor bench penalty of the other team ends if it scores while that team is
	## outnumbered on the rink (the one with the least time left); a major never does.
	func goal(t: int, info := {}) -> void:
		goals[t] += 1
		var e := {"kind": "goal", "team": t, "period": period, "t": clock}
		e.merge(info)
		var o := 1 - t
		e.pp = strength(o) < strength(t)
		e.sh = strength(t) < strength(o)
		log.append(e)
		if strength(o) < strength(t):
			var best := -1
			for i in penalties[o].size():
				var p: Dictionary = penalties[o][i]
				if String(p.kind) == "pen2" and bool(p.running) and not bool(p.coincidental):
					if best < 0 or float(p.left) < float(penalties[o][best].left):
						best = i
			if best >= 0:
				log.append({"kind": "pen_end", "team": o, "id": penalties[o][best].id, "period": period, "t": clock, "by_goal": true})
				penalties[o].remove_at(best)
				_start_waiting(o)
		if phase == "overtime":
			phase = "done"
			winner = t

	## The end of a period's time. Returns what comes next: "interval", "overtime", "shootout" or "done".
	func end_period() -> String:
		if period < PERIODS:
			period += 1
			clock = 0.0
			return "interval"
		if goals[0] != goals[1] or not knockout:
			phase = "done"
			winner = 0 if goals[0] > goals[1] else (1 if goals[1] > goals[0] else -1)
			return "done"
		if phase == "regular":
			phase = "overtime"
			period = PERIODS + 1
			clock = 0.0
			return "overtime"
		phase = "shootout"
		return "shootout"

	## 204: a penalty shot in the competition after overtime, team t, scored or not. Returns true once decided.
	func shootout_shot(t: int, scored: bool) -> bool:
		shootout[t].append(scored)
		var a: int = shootout[0].count(true)
		var b: int = shootout[1].count(true)
		var na: int = shootout[0].size()
		var nb: int = shootout[1].size()
		var decided := false
		if na <= SHOOTERS and nb <= SHOOTERS:
			# Decided early when one side cannot catch up with the shots it has left.
			if a > b + (SHOOTERS - nb) or b > a + (SHOOTERS - na):
				decided = true
			elif na == SHOOTERS and nb == SHOOTERS and a != b:
				decided = true
		elif na == nb and a != b:
			decided = true
		if decided:
			phase = "done"
			winner = 0 if a > b else 1
		return decided

	## Who shoots next in the competition: team 0 first (the toss), then alternately.
	func shootout_next() -> int:
		return 0 if shootout[0].size() <= shootout[1].size() else 1

	## 204 (2026): the first five shots from five different field players; after that any field player, more than
	## once. Is player id allowed to take team t's next shot?
	func may_shoot(t: int, id: String, taken_by: Array) -> bool:
		var n: int = shootout[t].size()
		if n >= SHOOTERS:
			return true
		return not (id in taken_by)

	## The result's goals as recorded: a shootout win counts one goal for the winner (204).
	func final_goals() -> Array:
		var g: Array = goals.duplicate()
		if not shootout[0].is_empty() and winner >= 0:
			g[winner] += 1
		return g
