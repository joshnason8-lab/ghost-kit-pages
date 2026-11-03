class_name RuleChecks
extends RefCounted
## The sport's rules, checked after every simulated step of a match (match_sim; the shared WsgSim): anything here is a
## bug, never a judgement call. One per match: it keeps what it saw last step.
##   var rc := RuleChecks.new()
##   ... after each step: for v in rc.step(match): print(v)
## The count (R2-R5, R12, R13): legal, and each change exactly the next raya of its history; the clock (R14): only
## forward, only in play, stopping at time; the serve (R11): the side that won the last raya; the players: each in his
## own half (R1) and inside the court's bounds, never two places in a step; the ball: never inside the court's stone
## or a prop, never faster than a hip can send it, never lost; the hip: never meets the ball over its cap; the end: no
## play once a side has won; and no phase that never ends.

const MAX_BALL_SPEED := 45.0      # m/s: far above any strike or serve (Match._strike, _launch_serve)
const MAX_STEP := 1.0             # m a player may move in one step (a sprint is ~0.25)
const STUCK_S := 150.0            # s one phase may last (a raya's rally, a replay, the copal)

var violations: Array = []        # every one, "t=12.3s: what"
var _hist := 0
var _clock := 0.0
var _phase := -1
var _phase_t := 0.0
var _pos := {}                    # player -> last position
var _rally := 0
var _t := 0.0


func step(m: Node, dt := 1.0 / 30.0) -> Array:
	_t += dt
	var out: Array = []
	var c: Rules.Count = m.count
	var classic: bool = m.court.classic()
	# The count, legal.
	if c.rules == Rules.CLASSIC:
		for k in 2:
			if int(c.points[k]) < 0 or int(c.points[k]) > Rules.CLASSIC_TARGET:
				out.append("points %s outside 0..%d" % [str(c.points), Rules.CLASSIC_TARGET])
		if c.winner >= 0 and not c.ring and int(c.points[c.winner]) < Rules.CLASSIC_TARGET and not _at_time(m) and not bool(m.sudden):
			out.append("side %d won on %d points" % [c.winner, int(c.points[c.winner])])
	else:
		if c.holder < -1 or c.holder > 1 or c.rayas < 0 or c.rayas > Rules.TARGET:
			out.append("count holder %d rayas %d" % [c.holder, c.rayas])
		if (c.holder == -1) != (c.rayas == 0):
			out.append("count holder %d with %d rayas" % [c.holder, c.rayas])
		if c.winner >= 0 and not c.ring and (c.holder != c.winner or c.rayas < Rules.TARGET) and not (_at_time(m) and c.holder == c.winner) and not bool(m.sudden):
			out.append("side %d won holding %d (holder %d)" % [c.winner, c.rayas, c.holder])
	# Each change of the count exactly its history replayed (one raya at a time, by the rules).
	if c.history.size() != _hist:
		if c.history.size() > _hist + 1:
			out.append("%d rayas in one step" % (c.history.size() - _hist))
		var again := Rules.Count.new(c.rules)
		again.urria = c.urria
		for h in c.history:
			if String(h[1]) == "ring":
				Rules.award_ring(again, int(h[0]))
			else:
				Rules.award(again, int(h[0]))
		# Sudden death (R14): time up and level, the next raya wins the match whatever the count.
		if bool(m.sudden) and again.winner < 0 and c.history.size() > 0:
			again.winner = int(c.history[-1][0])
		if again.to_dict() != c.to_dict():
			out.append("the count %s is not its history replayed %s" % [JSON.stringify(c.to_dict()), JSON.stringify(again.to_dict())])
		_hist = c.history.size()
	# The clock.
	var clock: float = m.clock
	if clock < _clock - 0.0001:
		out.append("the clock went back %.2f -> %.2f" % [_clock, clock])
	if clock > _clock + 0.0001 and m.phase != m.P.LIVE and _phase != m.P.LIVE:
		out.append("the clock ran outside play (phase %d)" % m.phase)
	if float(m.limit_s) > 0.0 and clock > float(m.limit_s) + STUCK_S:
		out.append("the clock %.0f s past its limit %.0f s" % [clock, float(m.limit_s)])
	_clock = clock
	# The serve: the side that won the last raya.
	if m.phase == m.P.SERVE and c.winner < 0 and int(m.serve_team) != Rules.server(c):
		out.append("side %d serves; the last raya was side %d's" % [int(m.serve_team), Rules.server(c)])
	# The end: no play after a win.
	if c.winner >= 0 and m.phase == m.P.LIVE:
		out.append("play goes on after side %d won" % c.winner)
	if m.phase == m.P.OVER and c.winner < 0 and float(m.limit_s) <= 0.0:
		out.append("the match is over with no winner and no time limit")
	# The players.
	for p: Player in m.all_players():
		var at := p.global_position
		if not at.is_finite():
			out.append("%s is nowhere" % p.name)
			continue
		var crossing: bool = m.phase == m.P.INTRO or m.phase == m.P.OVER
		if not crossing and at.x * Rules.dir(p.team) > -0.4 + 0.01:
			out.append("%s (side %d) over the analco at x %.2f" % [p.name, p.team, at.x])
		var keep: Vector3 = m.court.clamp_feet(at)
		if Vector2(keep.x - at.x, keep.z - at.z).length() > 0.02:
			out.append("%s outside the court's bounds at %s" % [p.name, at])
		if _pos.has(p) and Vector2(at.x - _pos[p].x, at.z - _pos[p].z).length() > MAX_STEP and m.phase == _phase:
			out.append("%s jumped %.2f m in a step" % [p.name, (at - (_pos[p] as Vector3)).length()])
		_pos[p] = at
	# The ball.
	var b: Ball = m.ball
	if not b.pos.is_finite() or not b.vel.is_finite():
		out.append("the ball is nowhere (%s, %s)" % [b.pos, b.vel])
	elif not b.held:
		if b.vel.length() > MAX_BALL_SPEED:
			out.append("the ball at %.1f m/s" % b.vel.length())
		if classic:
			var hit: Array = m.court.contact(b.pos, Ball.RADIUS)
			if not hit.is_empty() and float(hit[1]) > 0.03:
				out.append("the ball %.2f m into the %s" % [float(hit[1]), hit[2]])
		if m.court.solid != null:
			var pen: Dictionary = m.court.solid.sweep(b.pos, b.pos, Ball.RADIUS)
			if pen.hit and float(pen.get("depth", 0.0)) > 0.03:
				out.append("the ball %.2f m into the %s" % [float(pen.depth), pen.name])
		if b.pos.y < -0.05:
			out.append("the ball under the ground (y %.2f)" % b.pos.y)
	# The hip, never over its cap.
	if float(m.top_strike) > Player.STRIKE_MAX_UP + 0.001:
		out.append("a hip met the ball %.2f m over the hip" % float(m.top_strike))
	# Rallies count only in play.
	if int(m.rally) > _rally and m.phase != m.P.LIVE and _phase != m.P.LIVE:
		out.append("a touch counted out of play (phase %d)" % m.phase)
	_rally = int(m.rally)
	# No phase forever.
	if m.phase != _phase:
		_phase = m.phase
		_phase_t = 0.0
	else:
		_phase_t += dt
		if _phase_t > STUCK_S and m.phase != m.P.OVER:
			out.append("stuck in phase %d for %.0f s" % [m.phase, _phase_t])
			_phase_t = -1e9   # (once)
	for v in out:
		violations.append("t=%.1fs: %s" % [_t, v])
	return out


## Time is up (R14): the side holding the count, or ahead on points, wins as it stands.
func _at_time(m: Node) -> bool:
	return float(m.limit_s) > 0.0 and float(m.clock) >= float(m.limit_s) - 0.001


## The cup after the person's game (R: the town tournament, game/cup.gd): the game's winner in the draw, the round
## played out, and every round from the last one's winners; once the town is out, played through to a champion.
static func cup(c, r: Dictionary) -> Array:
	var out := []
	var rounds: Array = (c.history as Array).duplicate()
	if not (c.draw as Array).is_empty():
		rounds.append(c.draw)
	if rounds.is_empty():
		return ["the cup has no rounds"]
	var mine := false
	for pair in rounds[0]:
		if String(pair[0]) == String(r.home) and String(pair[1]) == String(r.away):
			mine = true
			if int(pair[2]) != int(r.winner):
				out.append("the cup has %s v %s won by %d, the game by %d" % [pair[0], pair[1], int(pair[2]), int(r.winner)])
	if not mine:
		out.append("the cup's first round has no %s v %s" % [r.home, r.away])
	for k in range(1, rounds.size()):
		var winners := []
		for pair in rounds[k - 1]:
			if int(pair[2]) < 0 or int(pair[2]) > 1:
				out.append("round %d: %s v %s not played (%d)" % [k, pair[0], pair[1], int(pair[2])])
				continue
			winners.append(String(pair[int(pair[2])]))
		var drawn := []
		for pair in rounds[k]:
			drawn.append(String(pair[0]))
			drawn.append(String(pair[1]))
		if drawn != winners:
			out.append("round %d drawn %s, the winners were %s" % [k + 1, str(drawn), str(winners)])
	var team_won := int(r.winner) == int(r.user_team)
	if team_won == bool(c.out):
		out.append("the town %s the game but the cup has it %s" % ["won" if team_won else "lost", "out" if c.out else "in"])
	if bool(c.out) and String(c.champion) == "":
		out.append("the town is out and the cup was not played to a champion")
	return out

