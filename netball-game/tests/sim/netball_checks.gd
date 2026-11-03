extends RefCounted
## Netball's rules and the match's physical sense, checked from outside the match after every simulated step and at
## every game_event (tests/sim/run_batch.gd; docs/SIM.md). Plain checks, no game code changed: each reads the match's
## state (Match, Player, Ball) and, where it can, works the rule out on its own rather than asking the game's Rules
## (the court's geometry is redone here; Rules is used only for what a position may enter and the centre pass
## line-up, which test_runner's `_rules` checks against the rulebook).
##
##   var c := NetballChecks.new()
##   c.begin(m)                          # after the match is added (its config read)
##   m.game_event.connect(func(k, i): c.check_event(m, k, i))
##   c.check_frame(m, dt)                # after each step (dt: that step's seconds)
##   c.finish(m, result, finished)       # at the end (result {} when it never finished)
##
## Each violation: {t (s of play), q, phase, check, severity, msg}. Severity "error": a state the rules or physics
## forbid that the game produced (a bug); "warn": an infringement left uncalled or called without one (the umpire's
## discretion, or a simplification docs/RULES.md admits), counted to rank.

const HALF_L := 15.25
const HALF_W := 7.625
const CIRCLE_R := 4.9
const LINE_HW := 0.025
const THIRD_X := 30.5 / 6.0
const RUNOFF := 3.05
const RING_H := 3.05
const RING_R := 0.19
const BALL_R := 0.112
const TOP_SPEED := 7.2             # Player.TOP: the fastest sprint (speed 99)
const HOLD_LIMIT := 3.0
const DEFEND_DIST := 0.9
const STALL_S := 60.0              # s of play with nothing happening: a stall
const DZ_FROM := 3.0
const POSITIONS := ["GS", "GA", "WA", "C", "WD", "GD", "GK"]
const PHASES := ["setup", "live", "stop", "goal", "break", "over", "injury", "timeout", "replay"]
const CLOCK_HELD := ["break", "timeout", "injury", "over", "replay"]

var violations: Array = []
var counts := {}                   # check -> how many times it fired
var stats := {}                    # what was seen (for the batch's summary): steps, goals, calls ...
var max_cap := 50                  # violations kept per match per check (the counts go on)

var t := 0.0                       # s of play stepped
var _m = null
var _prev_score := [0, 0]
var _prev_time := 0.0
var _prev_q := 1
var _prev_phase := ""
var _prev_p := {}                  # Player -> Vector2
var _prev_ball := Vector3.ZERO
var _prev_holder = null
var _goal_pending: Array = []      # goal events this step: [team, value]
var _events_step: Array = []       # event kinds this step
var _last_event_t := 0.0
var _hold_t := 0.0                 # live seconds the holder has had the ball (independent of the match's hold_t)
var _hold_from := Vector2.ZERO     # where she was when she got it
var _hold_settled := Vector2.INF   # where she was 0.8 s into it (after the landing)
var _hold_max := 0.0               # the furthest a holder went from her catch
var _offside_t := {}               # Player -> s offside in live play
var _close_t := {}                 # Player -> s defending within 0.9 m of the landing foot
var _cp_team := -1                 # the team that took the last centre pass
var _cp_whistled_q := false        # the first centre pass of this period has been whistled
var _cp_wait := -1                 # the team whose centre pass is in the air (its first catch decides it)
var _shot := {}                    # the shot in hand: by (Player), landing, dir, value, dist, from_free, time_left, q
var _free_taker = null             # the taker of a free pass in the circle (may not shoot it) until she passes
var _period_start := {}            # q -> time_left when it began
var _timeouts := [[0, 0]]          # [half][team]
var _dirs := [0, 0]
var _feet_k := 0
var _ended := false


func begin(m) -> void:
	_m = m
	t = 0.0
	_prev_score = [int(m.score[0]), int(m.score[1])]
	_prev_time = float(m.time_left)
	_prev_q = int(m.q)
	_prev_phase = String(m.phase)
	_prev_ball = m.ball.pos
	_period_start[int(m.q)] = float(m.time_left)
	_dirs = [m.team_dir(0), m.team_dir(1)]
	for tm in 2:
		for pl in m.players[tm]:
			_prev_p[pl] = pl.p
	_expect_period_length(m, int(m.q), float(m.time_left))
	stats = {"steps": 0, "goals": 0, "two_pointers": 0, "shots": 0, "calls": {}, "centre_passes": 0, "hold_max": 0.0,
		"periods": 0, "advantages": 0, "timeouts": 0, "subs": 0, "suspensions": 0, "injuries": 0}


func _flag(check: String, severity: String, msg: String) -> void:
	counts[check] = int(counts.get(check, 0)) + 1
	if int(counts[check]) > max_cap:
		return
	violations.append({"t": snappedf(t, 0.01), "q": int(_m.q) if _m else 0, "phase": String(_m.phase) if _m else "",
		"check": check, "severity": severity, "msg": msg})


# ---------------------------------------------------------------- geometry, redone here

static func _post(dir: int) -> Vector2:
	return Vector2(HALF_L * dir, 0.0)


static func _in_circle(p: Vector2, dir: int) -> bool:
	if absf(p.x) > HALF_L or (p.x != 0.0 and signf(p.x) != float(dir)):
		return false
	return p.distance_to(_post(dir)) <= CIRCLE_R + LINE_HW


static func _on_court(p: Vector2) -> bool:
	return absf(p.x) <= HALF_L and absf(p.y) <= HALF_W


static func _finite2(v: Vector2) -> bool:
	return is_finite(v.x) and is_finite(v.y)


static func _finite3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


## A period's length as the match was set up: quarters config.quarter_s (the tests' short ones) or quarter minutes;
## extra time's halves half that (7 of 15 minutes); then on to a two-goal lead.
static func period_length(cfg: Dictionary, q: int) -> float:
	var qm := float(cfg.get("quarter", 5))
	if cfg.has("quarter_s"):
		if q <= 4:
			return float(cfg.quarter_s)
		return float(cfg.quarter_s) * 0.5 if q <= 6 else INF
	if q <= 4:
		return qm * 60.0
	if q <= 6:
		return 7.0 * 60.0 * qm / 15.0
	return INF


func _expect_period_length(m, q: int, tl: float) -> void:
	var want := period_length(m.config, q)
	if is_inf(want) != is_inf(tl) or (not is_inf(want) and absf(want - tl) > 0.06):
		_flag("clock_period_length", "error", "period %d began with %.2f s on the clock, not %.2f" % [q, tl, want])


# ---------------------------------------------------------------- every step

func check_frame(m, dt: float) -> void:
	t += dt
	stats.steps = int(stats.steps) + 1
	var phase := String(m.phase)
	if not (phase in PHASES):
		_flag("phase_unknown", "error", "phase %s" % phase)
	if phase != "replay":
		_check_score(m)
		_check_clock(m, dt, phase)
		_check_ball(m, dt, phase)
		_check_players(m, dt, phase)
		_check_holder(m, dt, phase)
		_check_offside(m, dt, phase)
		_check_close(m, dt, phase)
		_feet_k += 1
		if _feet_k % 15 == 0:
			_check_feet(m)
	else:
		# (A replay: nothing moves in the match; where everyone was at its start is where the next step starts from.)
		for tm in 2:
			for pl in m.players[tm]:
				_prev_p[pl] = pl.p
		_prev_ball = m.ball.pos
	if phase in ["setup", "live", "stop", "goal"] and t - _last_event_t > STALL_S:
		_flag("stall", "error", "%.0f s of play without an event (phase %s, ball %s, holder %s)" % [t - _last_event_t, phase,
			m.ball.state, m.holder.pos if m.holder else "-"])
		_last_event_t = t
	_check_centre_pass(m)
	if int(m.q) != _prev_q:
		_new_period(m)
	_prev_phase = phase
	_prev_q = int(m.q)
	_goal_pending.clear()
	_events_step.clear()


func _check_score(m) -> void:
	for tm in 2:
		var s := int(m.score[tm])
		var d := s - int(_prev_score[tm])
		if d < 0:
			_flag("score_down", "error", "team %d's score went down %d -> %d" % [tm, _prev_score[tm], s])
		elif d > 0:
			var want := 0
			for g in _goal_pending:
				if int(g[0]) == tm:
					want += int(g[1])
			if d != want:
				_flag("score_without_goal", "error", "team %d's score went up %d with %d from goals this step" % [tm, d, want])
	var sum := [0, 0]
	for qs in m.q_scores:
		sum[0] += int(qs[0])
		sum[1] += int(qs[1])
	if sum[0] != int(m.score[0]) or sum[1] != int(m.score[1]):
		_flag("score_periods", "error", "the periods' scores %s do not add up to the score %s" % [sum, m.score])
	if m.q_scores.size() != int(m.q):
		_flag("score_periods", "error", "%d periods' scores in period %d" % [m.q_scores.size(), m.q])
	_prev_score = [int(m.score[0]), int(m.score[1])]


func _check_clock(m, dt: float, phase: String) -> void:
	var tl := float(m.time_left)
	if is_nan(tl) or tl < 0.0:
		_flag("clock_bad", "error", "time left %s" % tl)
	if int(m.q) != _prev_q:
		_prev_time = tl
		return
	if is_inf(tl) and is_inf(_prev_time):
		return
	var d := _prev_time - tl
	if d < -1e-4:
		_flag("clock_up", "error", "the clock went up %.3f s in period %d" % [-d, m.q])
	elif d > dt + 1e-3:
		_flag("clock_fast", "error", "the clock ran %.3f s in a %.3f s step" % [d, dt])
	if phase in CLOCK_HELD and phase == _prev_phase and d > 1e-5 and tl > 0.0:
		_flag("clock_held", "error", "the clock ran %.3f s in %s (time is held)" % [d, phase])
	if phase == "live" and _prev_phase == "live" and tl > 0.0 and d < dt * 0.5:
		_flag("clock_stopped", "error", "the clock stood in live play (%.3f s of a %.3f s step)" % [d, dt])
	if phase == "setup" and _prev_phase == "setup" and not _cp_whistled_q and d > 1e-5 and m.restart.get("kind", "") == "centre_pass":
		_flag("clock_before_cp", "error", "the clock ran before the period's first centre pass (%.3f s)" % d)
	_prev_time = tl


func _check_ball(m, dt: float, phase: String) -> void:
	var b: Vector3 = m.ball.pos
	if not _finite3(b):
		_flag("ball_nan", "error", "the ball at %s" % b)
		return
	if b.y < -0.02:
		_flag("ball_below_floor", "error", "the ball %.2f m below the floor (%s)" % [-b.y, m.ball.state])
	if absf(b.x) > HALF_L + RUNOFF + 3.0 or absf(b.z) > HALF_W + RUNOFF + 3.0 or b.y > 15.0:
		_flag("ball_lost", "error", "the ball off in the distance at %s (%s)" % [b, m.ball.state])
	if (m.ball.position - b).length() > 0.05:
		_flag("ball_two_places", "error", "the ball drawn %.2f m from where the match has it" % (m.ball.position - b).length())
	var held: bool = m.ball.state == "held"
	if held != (m.holder != null):
		_flag("ball_holder", "error", "the ball %s, the match's holder %s" % [m.ball.state, m.holder.pos if m.holder else "-"])
	elif held and m.ball.holder != m.holder:
		_flag("ball_holder", "error", "the ball in %s's hands, the match's holder %s" % [m.ball.holder.pos if m.ball.holder else "-", m.holder.pos])
	if held and m.holder:
		var hp: Vector2 = m.holder.p
		var off := Vector2(b.x, b.z).distance_to(hp)
		if off > 1.2:
			_flag("ball_off_hands", "error", "the held ball %.2f m from %s" % [off, m.holder.pos])
	# Jumps: the fastest the ball goes is a shoulder pass (about 16 m/s, 20 with a shot's rise); a step's change beyond
	# that is a teleport. At restarts the match puts the ball on the spot (centre pass) or in the taker's hands.
	var jump := (b - _prev_ball).length()
	var restart := phase == "setup" or _prev_phase != phase or "centre_setup" in _events_step or "call" in _events_step
	if jump > 25.0 * dt + 0.15:
		if restart:
			stats["restart_jumps"] = int(stats.get("restart_jumps", 0)) + 1
			if jump > 3.0:
				_flag("ball_jump_restart", "warn", "the ball jumped %.1f m at a restart (%s -> %s, %s)" % [jump, _prev_phase, phase, m.ball.state])
		elif "catch" in _events_step or "gain" in _events_step or "fumble" in _events_step:
			# Into the catcher's hands from where the flight ended (she may be up to 1.3 m from it: Match._arrive).
			stats["catch_snaps"] = int(stats.get("catch_snaps", 0)) + 1
			if jump > 0.6:
				_flag("ball_snap_catch", "warn", "the ball jumped %.2f m into %s's hands at the catch" % [jump, m.holder.pos if m.holder else "-"])
		else:
			var h = m.holder
			_flag("ball_teleport", "error", "the ball jumped %.2f m in a step (%s, %s, events %s): %s -> %s%s" % [jump, phase, m.ball.state, _events_step,
				_prev_ball.snappedf(0.01), b.snappedf(0.01), (", in %s%d's hands (%s, at %s)" % [h.pos, h.team, h.act, h.p.snappedf(0.01)]) if h else ""])
	_prev_ball = b


func _check_players(m, dt: float, phase: String) -> void:
	var seen := {}
	for tm in 2:
		if m.players[tm].size() != 7:
			_flag("team_size", "error", "team %d has %d players on its list" % [tm, m.players[tm].size()])
		var poss := {}
		for pl in m.players[tm]:
			if seen.has(pl):
				_flag("player_twice", "error", "%s is on both teams' lists" % pl.pos)
			seen[pl] = true
			if poss.has(pl.pos):
				_flag("position_twice", "error", "team %d has two %s" % [tm, pl.pos])
			poss[pl.pos] = true
			if not (pl.pos in POSITIONS):
				_flag("position_bad", "error", "a player's position %s" % pl.pos)
			if pl.team != tm:
				_flag("player_team", "error", "%s on team %d's list says team %d" % [pl.pos, tm, pl.team])
			var p: Vector2 = pl.p
			if not _finite2(p) or not _finite2(pl.vel) or not is_finite(pl.facing):
				_flag("player_nan", "error", "%s%d at %s, velocity %s" % [pl.pos, tm, p, pl.vel])
				continue
			if absf(p.x) > HALF_L + RUNOFF + 4.0 or absf(p.y) > HALF_W + RUNOFF + 4.0:
				_flag("player_lost", "error", "%s%d at %s, off the floor" % [pl.pos, tm, p])
			if absf(pl.position.y) > 0.01:
				_flag("player_height", "error", "%s%d's root %.2f m off the floor" % [pl.pos, tm, pl.position.y])
			if pl.vel.length() > TOP_SPEED * 1.05:
				_flag("player_speed", "error", "%s%d running %.1f m/s (the fastest is %.1f)" % [pl.pos, tm, pl.vel.length(), TOP_SPEED])
			var was: Vector2 = _prev_p.get(pl, p)
			var moved := p.distance_to(was)
			# Placed at a spot at once only at a period's start (the teams snapped to the centre pass after a break).
			var snap: bool = _prev_phase == "break" or int(m.q) != _prev_q or "substitution" in _events_step
			if moved > TOP_SPEED * 1.1 * dt + 0.02 and not snap:
				_flag("player_teleport", "error", "%s%d jumped %.2f m in a %.3f s step (%s)" % [pl.pos, tm, moved, dt, phase])
			_prev_p[pl] = p
			if m.holder == pl and pl.away():
				_flag("away_holds", "error", "%s%d holds the ball while out of play or suspended" % [pl.pos, tm])
	if phase in ["setup", "live"] and m.restart.get("kind", "") == "centre_pass":
		for tm in 2:
			var on := 0
			for pl in m.players[tm]:
				if pl.suspended <= 0.0:
					on += 1
			if on < 5:
				_flag("too_few", "error", "team %d plays on with %d" % [tm, on])


func _check_holder(m, dt: float, phase: String) -> void:
	var h = m.holder
	if h != _prev_holder:
		_hold_t = 0.0
		_hold_from = h.p if h else Vector2.ZERO
		_hold_settled = Vector2.INF
		_prev_holder = h
	if h == null:
		return
	if phase != "live":
		_hold_t = 0.0
		_hold_from = h.p
		_hold_settled = Vector2.INF
		return
	_hold_t += dt
	if _hold_t > HOLD_LIMIT + dt * 1.5 + 1e-3:
		var shooting: bool = m.shot_info.get("by") == h
		_flag("held_ball_late" if shooting else "held_ball_uncalled", "warn",
			"%s%d has had the ball %.2f s in play%s" % [h.pos, h.team, _hold_t, " (a shot still in her hands)" if shooting else ""])
		_hold_t = -INF   # once a holding
	# Footwork: the landing takes her a step; after it she only pivots on her landing foot.
	var from: float = h.p.distance_to(_hold_from)
	_hold_max = maxf(_hold_max, from)
	stats.hold_max = maxf(float(stats.hold_max), from)
	if from > 1.6:
		_flag("footwork_travel", "error", "%s%d went %.2f m with the ball" % [h.pos, h.team, from])
		_hold_from = h.p
	if _hold_t > 0.8 and _hold_settled == Vector2.INF:
		_hold_settled = h.p
	elif _hold_settled != Vector2.INF and h.p.distance_to(_hold_settled) > 0.45:
		_flag("footwork_after_landing", "error", "%s%d moved %.2f m after landing with the ball" % [h.pos, h.team, h.p.distance_to(_hold_settled)])
		_hold_settled = h.p
	# A thrower off the court is only the taker of a throw-in.
	if not _on_court(h.p) and (h.p.distance_to(Vector2(clampf(h.p.x, -HALF_L, HALF_L), clampf(h.p.y, -HALF_W, HALF_W))) > 0.6):
		_flag("holder_off_court", "error", "%s%d holds the ball %.1f m off the court" % [h.pos, h.team,
			h.p.distance_to(Vector2(clampf(h.p.x, -HALF_L, HALF_L), clampf(h.p.y, -HALF_W, HALF_W)))])


## The centre pass (R8): the first player after the C to take it, if of her own team, must take it in the centre third
## (the first landing foot wholly in it), and not be GS or GK; else the umpire calls it. A pass she was not there for
## runs on loose: the first to pick it up decides it the same way. A touch by the other side (an intercept, a
## deflection) or the receiver's fumble ends it.
func _check_centre_pass(m) -> void:
	if _cp_wait < 0 or String(m.phase) != "live":
		if String(m.phase) != "live" and String(m.phase) != "setup":
			_cp_wait = -1
		return
	var h = m.holder
	if h == null or (h.pos == "C" and h.team == _cp_wait and String(m.restart.get("kind", "")) == "centre_pass" and not m.restart.get("cp_done", false)):
		return
	if h.team == _cp_wait and (h.pos in ["GS", "GK"] or absf(h.landing.x) >= THIRD_X - LINE_HW):
		_flag("cp_taken_outside", "error", "the centre pass taken by %s at x %.2f without a call (%s)" % [h.pos, h.landing.x,
			"caught" if "catch" in _events_step else "picked up loose"])
	_cp_wait = -1


## Offside in play: a player (not out of play) in an area her position may not enter is called the moment she steps
## there; one left standing in it is a missed call.
func _check_offside(m, dt: float, phase: String) -> void:
	for tm in 2:
		for pl in m.players[tm]:
			var off: bool = phase == "live" and not pl.away() and _offside(pl.pos, pl.p, pl.dir)
			if off:
				_offside_t[pl] = float(_offside_t.get(pl, 0.0)) + dt
				if float(_offside_t[pl]) > 0.5 and float(_offside_t[pl]) - dt <= 0.5:
					_flag("offside_uncalled", "error", "%s%d has stood offside %.1f s in play at (%.1f, %.1f)" % [pl.pos, tm, _offside_t[pl], pl.p.x, pl.p.y])
			else:
				_offside_t[pl] = 0.0


## The area test redone: thirds by x (the lines belong to both sides), circles by distance from the post.
static func _areas(p: Vector2, dir: int) -> Array:
	if not _on_court(p):
		return []
	var out := []
	var ax := p.x * dir
	if ax >= THIRD_X - LINE_HW:
		out.append("att_circle" if _in_circle(p, dir) else "att_third")
		if _in_circle(p, dir) and p.distance_to(_post(dir)) >= CIRCLE_R - LINE_HW:
			out.append("att_third")
	if absf(p.x) <= THIRD_X + LINE_HW:
		out.append("centre")
	if ax <= -THIRD_X + LINE_HW:
		out.append("def_circle" if _in_circle(p, -dir) else "def_third")
		if _in_circle(p, -dir) and p.distance_to(_post(-dir)) >= CIRCLE_R - LINE_HW:
			out.append("def_third")
	return out


const AREAS := {
	"GS": ["att_circle", "att_third"], "GA": ["att_circle", "att_third", "centre"], "WA": ["att_third", "centre"],
	"C": ["att_third", "centre", "def_third"], "WD": ["centre", "def_third"], "GD": ["centre", "def_third", "def_circle"],
	"GK": ["def_third", "def_circle"],
}


static func _offside(pos: String, p: Vector2, dir: int) -> bool:
	var a := _areas(p, dir)
	if a.is_empty():
		return false
	for x in a:
		if x in AREAS[pos]:
			return false
	return true


## Obstruction: a defender defending the player with the ball from closer than 0.9 m to her landing foot, a second
## and more, uncalled (the game's umpires see most, not all: TeamAI._defend).
func _check_close(m, dt: float, phase: String) -> void:
	var h = m.holder
	for tm in 2:
		for pl in m.players[tm]:
			var close: bool = phase == "live" and h != null and pl.team != h.team and not pl.away() and pl.act in ["defend", "defend_shot"] \
					and pl.p.distance_to(h.landing) < DEFEND_DIST - 0.05
			if close:
				_close_t[pl] = float(_close_t.get(pl, 0.0)) + dt
				if float(_close_t[pl]) > 1.0 and float(_close_t[pl]) - dt <= 1.0:
					_flag("obstruction_uncalled", "warn", "%s%d defends %.2f m from %s%d's landing foot for a second (%s; she stands %.2f m from it)" % [pl.pos, tm,
						pl.p.distance_to(h.landing), h.pos, h.team, m.restart.get("kind", "") if m.restart.get("taker") == h else "in play", h.p.distance_to(h.landing)])
			else:
				_close_t[pl] = 0.0


## Bodies above the floor: each drawn body's ankles (the foundation's, else the game's own).
func _check_feet(m) -> void:
	for tm in 2:
		for pl in m.players[tm]:
			if not pl.is_visible_in_tree():
				continue
			var ys := []
			if pl.link and pl.link.body and pl.link.body.visible:
				for b in ["LeftFoot", "RightFoot"]:
					ys.append((pl.link.body.bone_world(b) as Transform3D).origin.y)
			elif pl.body:
				for b in ["foot_l", "foot_r"]:
					ys.append((pl.body.bone_world(b) as Vector3).y)
			for y in ys:
				if float(y) < -0.03:
					_flag("body_below_floor", "error", "%s%d's ankle %.2f m below the floor" % [pl.pos, tm, -float(y)])
					break


func _new_period(m) -> void:
	var q := int(m.q)
	stats.periods = q
	if q != _prev_q + 1:
		_flag("period_order", "error", "period %d after %d" % [q, _prev_q])
	if q > 7:
		_flag("period_order", "error", "period %d: there is no such period" % q)
	if q >= 5 and not bool(m.need_winner):
		_flag("extra_time", "error", "extra time (period %d) in a match that needs no winner" % q)
	_expect_period_length(m, q, float(m.time_left))
	_cp_whistled_q = false
	var d := [m.team_dir(0), m.team_dir(1)]
	if d[0] != -d[1]:
		_flag("ends", "error", "both teams attack the same end in period %d" % q)
	if q <= 6 and d[0] == _dirs[0]:
		_flag("ends", "error", "the teams did not change ends for period %d" % q)
	if q == 7 and d[0] != _dirs[0]:
		_flag("ends", "error", "the teams changed ends playing on to a two-goal lead")
	_dirs = d
	if q == 3:
		_timeouts.append([0, 0])


# ---------------------------------------------------------------- every event

func check_event(m, kind: String, info: Dictionary) -> void:
	_events_step.append(kind)
	if not (kind in ["speed", "graphics_down", "replay"]):
		_last_event_t = t
	match kind:
		"centre_setup":
			_free_taker = null
		"whistle":
			_on_whistle(m, String(info.get("kind", "")))
		"pass":
			_free_taker = null
		"catch":
			_on_catch(m, info)
		"gain", "deflection", "fumble":
			_cp_wait = -1
			_free_taker = null
			if m.holder and m.holder.away():
				_flag("away_holds", "error", "%s%d out of play took the ball" % [m.holder.pos, m.holder.team])
		"shot_start":
			_on_shot(m, info)
		"goal":
			_on_goal(m, info)
		"miss":
			_shot = {}
		"call":
			_on_call(m, info)
		"advantage":
			stats.advantages = int(stats.advantages) + 1
			var h = m.holder
			if h == null or h.team == int(info.get("team", -1)) or not (h.pos in ["GS", "GA"]) or not _in_circle(h.landing, h.dir):
				_flag("advantage_wrong", "error", "advantage played without the other side's shooter set in her circle (%s)" % [info])
		"substitution":
			stats.subs = int(stats.subs) + 1
			_on_sub(m, info)
		"timeout":
			stats.timeouts = int(stats.timeouts) + 1
			var tm := int(info.get("team", -1))
			if not bool(m.config.get("timeouts", false)):
				_flag("timeout_off", "error", "team %d called a time-out with time-outs off" % tm)
			if not (_prev_phase == "goal" or (_prev_phase == "setup" and m.restart.get("kind", "") == "centre_pass")):
				_flag("timeout_when", "error", "team %d's time-out from %s (only after a goal, before the centre pass)" % [tm, _prev_phase])
			if tm >= 0:
				var half: Array = _timeouts[-1]
				half[tm] = int(half[tm]) + 1
				if int(half[tm]) > 2:
					_flag("timeout_count", "error", "team %d's %d time-outs this half (two a half)" % [tm, half[tm]])
		"suspension", "ordered_off":
			stats.suspensions = int(stats.suspensions) + 1
		"injury":
			stats.injuries = int(stats.injuries) + 1
		"period_end":
			_on_period_end(m, info)


func _on_whistle(m, kind: String) -> void:
	var r: Dictionary = m.restart
	var taker = r.get("taker")
	if kind == "centre_pass":
		stats.centre_passes = int(stats.centre_passes) + 1
		var tm := int(r.get("to", -1))
		if _cp_team >= 0 and tm == _cp_team:
			_flag("cp_alternate", "error", "team %d takes a second centre pass in a row" % tm)
		_cp_team = tm
		_cp_whistled_q = true
		_cp_wait = tm
		# At the whistle: the taking C in the centre circle, the other C in the centre third, the rest in their goal
		# thirds (an early step into the centre third is breaking: a free pass).
		for side in 2:
			for pl in m.players[side]:
				if pl.away():
					continue
				var bad := false
				if pl.pos == "C":
					bad = pl.p.length() > 0.45 if side == tm else absf(pl.p.x) > THIRD_X + LINE_HW
				else:
					bad = absf(pl.p.x) <= THIRD_X + LINE_HW
				if bad:
					_flag("cp_lineup", "warn", "at the centre pass whistle %s%d stands at (%.2f, %.2f): breaking, not called" % [pl.pos, side, pl.p.x, pl.p.y])
				if _offside(pl.pos, pl.p, pl.dir):
					_flag("offside_at_whistle", "error", "%s%d offside at the centre pass whistle (%.1f, %.1f)" % [pl.pos, side, pl.p.x, pl.p.y])
		return
	if taker == null:
		return
	var at: Vector2 = r.get("at", Vector2.ZERO)
	for side in 2:
		for pl in m.players[side]:
			if not pl.away() and pl != taker and _offside(pl.pos, pl.p, pl.dir):
				_flag("offside_at_whistle", "error", "%s%d offside as a %s is taken (%.1f, %.1f)" % [pl.pos, side, kind, pl.p.x, pl.p.y])
	if kind == "throw_in":
		var line := Vector2(clampf(taker.p.x, -HALF_L, HALF_L), clampf(taker.p.y, -HALF_W, HALF_W))
		if _on_court(taker.p) and absf(taker.p.x) < HALF_L - 0.01 and absf(taker.p.y) < HALF_W - 0.01:
			_flag("throw_in_inside", "warn", "%s%d takes the throw-in from inside the court (%.2f, %.2f)" % [taker.pos, taker.team, taker.p.x, taker.p.y])
		elif taker.p.distance_to(line) > 0.5:
			_flag("throw_in_far", "warn", "%s%d takes the throw-in %.2f m back from the line" % [taker.pos, taker.team, taker.p.distance_to(line)])
		if taker.p.distance_to(at) > 2.0:
			_flag("throw_in_spot", "warn", "the throw-in taken %.1f m from where the ball went out" % taker.p.distance_to(at))
		return
	# A free or penalty pass: taken where the infringement was, by a player allowed there.
	if taker.p.distance_to(at) > 1.6:
		_flag("restart_spot", "warn", "the %s taken %.1f m from where it was given" % [kind, taker.p.distance_to(at)])
	if _offside(taker.pos, taker.p, taker.dir):
		_flag("restart_taker", "error", "%s takes a %s offside" % [taker.pos, kind])
	if kind == "free_pass" and _in_circle(taker.p, taker.dir) or kind == "penalty_pass" and not bool(r.get("shot", false)) and _in_circle(taker.p, taker.dir):
		_free_taker = taker
	if kind == "penalty_pass":
		var out = r.get("out")
		if out and is_instance_valid(out) and not (out.suspended > 0.0):
			var gap: float = out.p.distance_to(taker.p)
			if gap > 1.8:
				_flag("penalty_out_of_play", "warn", "the penalised %s%d %.1f m from the thrower at the whistle" % [out.pos, out.team, gap])
		# The others defending her from 0.9 m (the penalised player stands out of play, arms down).
		for pl in m.players[1 - taker.team]:
			if pl != out and not pl.away() and pl.act in ["defend", "defend_shot"] and pl.p.distance_to(taker.p) < DEFEND_DIST - 0.05:
				_flag("penalty_defender_close", "warn", "%s%d defends the penalty pass from %.2f m" % [pl.pos, pl.team, pl.p.distance_to(taker.p)])


func _on_catch(m, info: Dictionary) -> void:
	var h = m.holder
	if h == null:
		return
	if h.away():
		_flag("away_holds", "error", "%s%d out of play caught the ball" % [h.pos, h.team])
	_free_taker = null


func _on_shot(m, info: Dictionary) -> void:
	stats.shots = int(stats.shots) + 1
	var h = m.holder
	if h == null:
		_flag("shot_no_holder", "error", "a shot with no one holding the ball")
		return
	var dist: float = h.landing.distance_to(_post(h.dir))
	_shot = {"by": h, "landing": h.landing, "dir": h.dir, "dist": dist, "value": int(info.get("value", 1)), "time_left": float(m.time_left), "q": int(m.q)}
	if not (h.pos in ["GS", "GA"]):
		_flag("shot_position", "error", "%s%d shoots (only GS and GA may)" % [h.pos, h.team])
	if not _in_circle(h.landing, h.dir):
		_flag("shot_outside", "error", "%s%d shoots from %.2f m, outside her circle" % [h.pos, h.team, dist])
	if _free_taker == h:
		_flag("shot_free_pass", "error", "%s%d shoots a free pass (it may not be shot)" % [h.pos, h.team])
	var dz: bool = bool(m.double_zone) and Rules.double_zone_live(float(m.time_left), float(m.quarter_min))
	var want := 2 if dz and dist >= DZ_FROM else 1
	if int(info.get("value", 1)) != want:
		_flag("shot_value", "error", "a shot from %.2f m worth %d (want %d; Double Zone %s)" % [dist, info.get("value", 1), want, "live" if dz else "off"])


func _on_goal(m, info: Dictionary) -> void:
	var tm := int(info.get("team", -1))
	var value := int(info.get("value", 1))
	stats.goals = int(stats.goals) + 1
	if value == 2:
		stats.two_pointers = int(stats.two_pointers) + 1
	_goal_pending.append([tm, value])
	if not (String(info.get("by", "")) in ["GS", "GA"]):
		_flag("goal_position", "error", "a goal by %s" % info.get("by", ""))
	if value != 1 and value != 2 or value == 2 and not bool(m.double_zone):
		_flag("goal_value", "error", "a goal worth %d (Double Zone %s)" % [value, "on" if m.double_zone else "off"])
	if _shot.is_empty():
		_flag("goal_without_shot", "error", "a goal for team %d with no shot taken" % tm)
	else:
		if int(_shot.value) != value:
			_flag("goal_value", "error", "a shot worth %d scored %d" % [_shot.value, value])
		if (_shot.by as Object) and _shot.by.team != tm:
			_flag("goal_team", "error", "team %d's shot scored for team %d" % [_shot.by.team, tm])
		if int(_shot.q) != int(m.q):
			_flag("goal_late", "error", "a shot from period %d scored in period %d" % [_shot.q, m.q])
	# The whole ball through the ring: its middle within the ring less its radius, at the ring's height.
	var dir := int(_shot.get("dir", signf(m.ball.pos.x)))
	var rc := Vector3((HALF_L - 0.15 - RING_R) * dir, RING_H, 0.0)
	var b: Vector3 = m.ball.pos
	var off := Vector2(b.x - rc.x, b.z - rc.z).length()
	if off > RING_R - BALL_R + 0.02 or absf(b.y - RING_H) > 0.6:
		_flag("goal_not_through", "error", "a goal with the ball %.2f m off the ring's middle, %.2f m from its height" % [off, b.y - RING_H])
	_shot = {}


func _on_call(m, info: Dictionary) -> void:
	var kind := String(info.get("kind", ""))
	stats.calls[kind] = int(stats.calls.get(kind, 0)) + 1
	_cp_wait = -1
	_free_taker = null
	_shot = {}
	var to := int(info.get("to", -1))
	var by_pos := String(info.get("by", ""))
	var by = m.player_at(1 - to, by_pos) if by_pos != "" and to >= 0 else null
	match kind:
		"out_of_court", "throw_in":
			var bp: Vector2 = m.ball.court_pos()
			if _on_court(bp) and absf(bp.x) < HALF_L - 0.2 and absf(bp.y) < HALF_W - 0.2:
				_flag("throw_in_on_court", "error", "out of court called with the ball on the court at (%.1f, %.1f)" % [bp.x, bp.y])
		"offside":
			if by and not _offside(by.pos, by.p, by.dir):
				_flag("offside_phantom", "warn", "%s%d called offside standing in her own area (%.1f, %.1f)" % [by.pos, by.team, by.p.x, by.p.y])
		"held_ball":
			if _hold_t >= 0.0 and _hold_t < HOLD_LIMIT - 0.1:
				_flag("held_ball_early", "error", "held ball called after %.2f s" % _hold_t)
		"obstruction":
			var h = _prev_holder
			if by and h and is_instance_valid(h) and h.team != by.team and by.p.distance_to(h.landing) >= DEFEND_DIST + 0.05:
				_flag("obstruction_phantom", "warn", "obstruction called on %s%d from %.2f m (it needs closer than 0.9 m)" % [by.pos, by.team, by.p.distance_to(h.landing)])
		"centre_pass_fault":
			pass
	if kind != "contact" and kind != "obstruction" and not kind in ["offside", "breaking", "held_ball", "footwork", "short_pass", "over_third",
			"replayed_ball", "centre_pass_fault", "incorrect_throw_in", "intimidation", "out_of_court", "throw_in"]:
		_flag("call_unknown", "error", "an unknown call %s" % kind)


func _on_sub(m, info: Dictionary) -> void:
	var tm := int(info.get("team", -1))
	var pos := String(info.get("pos", ""))
	var pl = m.player_at(tm, pos) if tm >= 0 else null
	var replacing: bool = pl != null and pl.ordered_off
	var ok: bool = _prev_phase in ["break", "injury", "timeout"] or String(m.phase) in ["break", "injury", "timeout"] or bool(m.rolling) or replacing
	if not ok:
		_flag("sub_when", "error", "team %d changed its %s in %s (only at an interval, an injury or a time-out)" % [tm, pos, _prev_phase])


func _on_period_end(m, info: Dictionary) -> void:
	var q := int(info.get("q", m.q))
	if float(m.time_left) > 0.0 and not (q >= 7):
		_flag("period_end_early", "error", "period %d ended with %.1f s left" % [q, m.time_left])
	var lead := absi(int(m.score[0]) - int(m.score[1]))
	if q >= 7 and lead < 2:
		_flag("et_lead", "error", "playing on ended with a %d-goal lead (it needs two)" % lead)


## At the end: the match finished, by the rules, and its result adds up.
func finish(m, result: Dictionary, finished: bool) -> void:
	_ended = true
	if not finished:
		_flag("no_end", "error", "the match did not finish (period %d, %s, %.0f s of play)" % [m.q, m.phase, t])
		return
	var q := int(m.q)
	var sc: Array = result.get("score", m.score)
	var level := int(sc[0]) == int(sc[1])
	if q < 4:
		_flag("end_early", "error", "the match ended in period %d" % q)
	if bool(m.need_winner) and level:
		_flag("end_level", "error", "a knockout ended level %s" % [sc])
	if not bool(m.need_winner) and q != 4:
		_flag("end_periods", "error", "a match that needs no winner ended after period %d" % q)
	if q == 4 and bool(m.need_winner) and level:
		_flag("end_level", "error", "a knockout ended level after four quarters")
	if q == 7 and absi(int(sc[0]) - int(sc[1])) != 2:
		_flag("et_lead", "error", "playing on ended %s (on to a two-goal lead)" % [sc])
	if int(result.get("periods", q)) != q or (result.get("q_scores", []) as Array).size() != q:
		_flag("result_periods", "error", "the result has %s periods and %d periods' scores, the match %d" % [result.get("periods"), (result.get("q_scores", []) as Array).size(), q])
	var box := [0, 0]
	for id in result.get("stats", {}):
		var s: Dictionary = result.stats[id]
		box[int(s.team)] += int(s.goals) + int(s.get("super", 0))
		if int(s.goals) > 0 and not (String(s.pos) in ["GS", "GA"]):
			_flag("box_scorer", "error", "%s scored %d (only GS and GA score)" % [s.pos, s.goals])
	if box[0] != int(sc[0]) or box[1] != int(sc[1]):
		_flag("box_score", "error", "the box score %s does not add up to the score %s" % [box, sc])
	for tm in 2:
		if int(sc[tm]) < 0:
			_flag("score_down", "error", "a negative score %s" % [sc])
