class_name TeamAI
extends RefCounted
## How a team plays, as floorball is played (docs/RULES.md, "How the AI plays"): five outfield players in a line of a
## centre, two forwards and two defenders, changing every 40-60 seconds of play. Without the ball, the IFF's most
## common defence, a 2-1-2: two forwards high, the centre in the middle, the two defenders low in front of the goal
## crease, the nearest player pressing the ball on its goal side; with the ball deep in the other end, a 2-2-1
## forecheck. With the ball: the wingers wide along the boards and ahead, the centre to the slot, the defenders back
## and wide as the safety, the carrier reading pass, shot or carry from where he is and who is near.
##
## The numbers it plays by (from match analysis, docs/RULES.md): about ten goals a match between them, about 10% of
## all shots scoring and 27% of shots on target, three-quarters of possessions over in 15 seconds.

const SHIFT_S := 48.0           # a line's time on the rink before it changes (top teams: 40-60 s)
const THINK_S := 0.18           # how often a carrier reconsiders

var m                           # the match
var t := 0                      # this team
var level := 1.0                # difficulty: 0.75 Rookie ... 1.15 World class (the user's opponents)
var shift := 0.0
var line := 0                   # the line on the rink (0-2)
var changing := false
var _think := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_match, p_team: int, p_level := 1.0, seed_ := 1) -> void:
	m = p_match
	t = p_team
	level = p_level
	_rng.seed = seed_ * 31 + p_team


func att() -> float:
	return m.attack_dir(t)


## The goal this team attacks, on the floor.
func target_goal() -> Vector2:
	return Vector2(Rules.GOAL_LINE * att(), 0)


func own_goal() -> Vector2:
	return Vector2(-Rules.GOAL_LINE * att(), 0)


## Each frame in open play: where every one of this team's outfield players wants to be, and what the one with the
## ball does. Players run by the user are skipped (except while he is off on a line change).
func play(dt: float) -> void:
	_think -= dt
	var b: Vector2 = m.ball.floor_pos()
	var carrier = m.ball.carrier
	var ours: bool = carrier != null and carrier.team == t
	var theirs: bool = carrier != null and carrier.team != t
	var players: Array = m.skaters(t)
	var chaser = _chaser(players, b)
	var presser = _presser(players, carrier) if theirs else null
	for p in players:
		if p == m.user_player and not p.get_meta("going_off", false):
			continue
		if p.get_meta("going_off", false):
			_go_off(p)
			continue
		if p == carrier:
			_carry(p, dt)
			continue
		var want: Vector2
		if carrier == null:
			want = _loose(p, b, chaser)
		elif ours:
			want = _support(p, b, carrier)
		else:
			want = _defend(p, b, carrier, presser)
		_run_to(p, want, 1.0 if (p == chaser or p == presser) else 0.8)
		if p == presser:
			_try_tackle(p, carrier)
	_line_change(dt, players, ours, b)


func _run_to(p: Player, at: Vector2, urgency: float) -> void:
	at = _keep_out_of_gk_area(at)
	var d: Vector2 = at - p.pos
	var dist := d.length()
	var top: float = p.MAX_SPEED * clampf(0.55 + p.stat("speed") / 220.0, 0.6, 1.0) * urgency * lerpf(0.9, 1.05, clampf(level - 0.75, 0.0, 0.4) / 0.4)
	# Arrive: slow over the last couple of metres rather than overrun.
	var sp := minf(top, dist * 2.2)
	p.want_vel = d.normalized() * sp if dist > 0.05 else Vector2.ZERO
	p.want_face = NAN


## 2026: field players may not pass through the goalkeeper area; keep every target out of both.
static func _keep_out_of_gk_area(at: Vector2) -> Vector2:
	for end: int in [-1, 1]:
		if Rules.in_gk_area(at, end):
			at.x = Rules.GK_AREA_FRONT * end - 0.3 * end
	return at


func _chaser(players: Array, b: Vector2):
	var best = null
	var bd := 1e9
	for p in players:
		if p.get_meta("going_off", false):
			continue
		var d: float = p.pos.distance_to(b)
		if d < bd:
			bd = d
			best = p
	return best


## The first defender: the nearest to the carrier, unless a team-mate is much better placed goal side.
func _presser(players: Array, carrier):
	var best = null
	var bd := 1e9
	var g := own_goal()
	for p in players:
		if p.get_meta("going_off", false):
			continue
		var d: float = p.pos.distance_to(carrier.pos)
		# Goal side counts double: a defender behind the play is slow to stop it.
		if (p.pos - carrier.pos).dot(g - carrier.pos) < 0.0:
			d *= 1.6
		if d < bd:
			bd = d
			best = p
	return best


func _loose(p: Player, b: Vector2, chaser) -> Vector2:
	if p == chaser:
		return m.ball.predict(0.25)
	# The rest take up shape as if the other team will win it.
	return _shape_defence(p, b)


func _support(p: Player, b: Vector2, carrier) -> Vector2:
	var a := att()
	var gx := Rules.GOAL_LINE * a
	var deep := clampf((b.x * a + 20.0) / 40.0, 0.0, 1.0)   # 0 own end .. 1 their end
	match int(p.slot):
		0:   # centre: the slot in front of their goal, or in support behind the ball; with the ball deep in their end,
			# on the edge of the goalkeeper area, screening the goalkeeper and waiting for the rebound (as the Swedish
			# league's forwards do: most goals come from the crease)
			if deep > 0.75:
				return Vector2(a * (Rules.GK_AREA_FRONT - 1.3), clampf(b.y * 0.15, -1.2, 1.2))
			var x := lerpf(b.x - a * 3.0, gx - a * 6.5, deep)
			return Vector2(x, clampf(b.y * -0.3, -3.0, 3.0))
		6:   # the sixth player, the goalkeeper pulled: in front of their goal, for the rebound and the screen
			return Vector2(lerpf(b.x, gx - a * 3.0, deep), clampf(b.y * 0.25, -2.0, 2.0))
		1, 2:   # wings: wide, ahead of the ball
			var s := -1.0 if p.slot == 1 else 1.0
			s *= a
			var x := clampf(b.x + a * 4.0, -16.0, 16.0) if deep < 0.7 else gx - a * 3.5
			if deep < 0.55 and m.possession_time < 2.5:
				# The ball just won: away up the rink for the long pass (the counter the league's teams score from).
				x = clampf(b.x + a * 10.0, -15.0, 15.0)
			return Vector2(x, s * 6.2)
		_:   # defenders: back and wide, the safety valve
			var s := -1.0 if p.slot == 3 else 1.0
			s *= a
			var x := clampf(b.x - a * 6.5, -15.0, 15.0)
			if deep > 0.55:
				x = a * 2.0 + a * (deep - 0.55) * 14.0
			return Vector2(x, s * 4.0)


func _defend(p: Player, b: Vector2, carrier, presser) -> Vector2:
	if p == presser:
		# Press on the goal side of the ball, a stick's length off.
		var g := own_goal()
		var to_goal: Vector2 = (g - carrier.pos).normalized()
		if absf(carrier.pos.x) > Rules.GOAL_LINE - 0.3:
			# Behind our goal: from the side he must come out on, not through the cage.
			to_goal = Vector2(0.0, -signf(carrier.pos.y) if carrier.pos.y != 0.0 else 1.0)
		return carrier.pos + to_goal * 1.1
	return _shape_defence(p, b)


## The 2-1-2 (or the 2-2-1 forecheck with the ball deep in their end).
func _shape_defence(p: Player, b: Vector2) -> Vector2:
	var a := att()
	var gx := -Rules.GOAL_LINE * a          # our goal line
	var deep := clampf((b.x * a + 20.0) / 40.0, 0.0, 1.0)   # 1: the ball deep in their end (we forecheck)
	match int(p.slot):
		6:
			return Vector2(lerpf(gx + a * 10.0, b.x - a * 3.0, 0.5), clampf(b.y * 0.5, -4.0, 4.0))
		0:
			return Vector2(lerpf(gx + a * 7.5, b.x - a * 4.0, 0.35 + deep * 0.3), clampf(b.y * 0.35, -3.0, 3.0))
		1, 2:
			var s := -1.0 if p.slot == 1 else 1.0
			s *= a
			if deep > 0.7:
				return Vector2(b.x - a * 2.0, s * 3.5 + b.y * 0.3)   # forecheck: high and on the ball
			if deep < 0.3:
				# The ball in our end: down into the box round the slot, the shooting lanes shut (the slot is where
				# goals come from; a shot from out wide is the goalkeeper's).
				return Vector2(gx + a * 8.0, s * 3.0 + b.y * 0.2)
			return Vector2(lerpf(gx + a * 12.0, b.x - a * 2.0, 0.45), s * 4.2 + b.y * 0.3)
		_:
			var s := -1.0 if p.slot == 3 else 1.0
			s *= a
			var x := gx + a * lerpf(4.5, 9.0, deep)
			return Vector2(x, clampf(s * 2.2 + b.y * 0.35, -6.0, 6.0))


func _try_tackle(p: Player, carrier) -> void:
	if p.act != "" or carrier == null:
		return
	var d: float = p.blade_floor().distance_to(m.ball.floor_pos())
	if d > 1.05:
		return
	# Not every step: a defender waits for the moment, more often the better he is.
	if _rng.randf() > 0.045 * level * (p.stat("defence") / 70.0):
		return
	m.tackle(p, carrier)


## Late in the last period, a goal or two behind: the goalkeeper off for a sixth outfield player (the match does it).
func wants_empty_net() -> bool:
	var r: Rules.State = m.rules
	if r.period != Rules.PERIODS:
		return false
	var behind := int(r.goals[1 - t]) - int(r.goals[t])
	if behind < 1 or behind > 2:
		return false
	return r.remaining() < maxf(20.0, r.period_s * 0.08)


## The carrier: shoot, pass or carry on. Decided a few times a second, not every frame.
func _carry(p: Player, dt: float) -> void:
	var a := att()
	var g := target_goal()
	var to_g: Vector2 = g - p.pos
	var dist := to_g.length()
	# Carry: toward goal, round the nearest opponent.
	var press = m.nearest_opponent(p)
	var pd: float = press.pos.distance_to(p.pos) if press else 99.0
	var lane := to_g.normalized()
	if dist < 5.0:
		lane = Vector2(-a, signf(p.pos.y) if p.pos.y != 0.0 else 1.0).normalized() * 0.4 + lane * 0.6
	if press and pd < 3.0:
		var away: Vector2 = (p.pos - press.pos).normalized()
		lane = (lane + away * (3.0 - pd) * 0.45).normalized()
	var top: float = p.MAX_SPEED * (0.62 + p.stat("speed") / 400.0)
	p.want_vel = lane * top
	p.want_face = NAN
	if _think > 0.0 or p.act != "":
		return
	_think = THINK_S * _rng.randf_range(0.8, 1.3)
	# Shot: close enough, in front of goal, a sight of it.
	var behind: bool = p.pos.x * a > Rules.GOAL_LINE - 0.6
	var angle_ok: bool = not behind and absf(p.pos.y) < dist * 0.75 + 0.5
	var held: float = m.possession_time
	# Their net empty: a shot from anywhere with a clear lane.
	if m.pulled[1 - t] and not behind and dist < 32.0 and m.shot_lane_open(p, g) > 0.7 and _rng.randf() < 0.35:
		m.shoot(p, Vector3(g.x, 0.25, _rng.randf_range(-0.4, 0.4)), false)
		return
	# A pass into the slot shot first time, before the goalkeeper has moved across (the league's most common goal).
	if angle_ok and dist < 10.0 and m.carry_time < 0.6 and held > 0.6 and absf(p.pos.y) < 4.5 and _rng.randf() < 0.16 * level:
		m.shoot(p, _aim(p, g), false)
		return
	if angle_ok and dist < 14.0:
		var open: float = m.shot_lane_open(p, g)
		var want := clampf((14.0 - dist) / 10.0, 0.0, 1.0) * (0.25 + open * 0.75) * (0.55 + p.stat("shot") / 200.0)
		if dist < 7.0:
			want += 0.15
		if _rng.randf() < want * 0.12 * level:
			m.shoot(p, _aim(p, g), _rng.randf() < 0.35 and dist > 8.0)
			return
	# Pass: someone open and further on, or under pressure.
	var best = null
	var best_s := -1e9
	for q: Player in m.skaters(t):
		if q == p or q.get_meta("going_off", false):
			continue
		var s := _pass_value(p, q)
		if s > best_s:
			best_s = s
			best = q
	# In our own end with nobody on him he carries it up the rink rather than passing it round (the CPU passed back and
	# forth in its own end for half a minute: the playtest); pressed, he moves it on.
	var own_end: bool = p.pos.x * a < 0.0
	var urge := (0.05 if own_end and pd > 3.0 else 0.15) + (0.45 if pd < 1.8 else 0.0) + clampf(held - 2.5, 0.0, 4.0) * 0.12
	if best and best_s > 0.35 and _rng.randf() < urge * clampf(best_s, 0.0, 1.5):
		m.pass_to(p, best)


## How good a pass to q is: open (no opponent near the lane or near q), forward, and not across our own goal.
func _pass_value(p: Player, q: Player) -> float:
	var a := att()
	var lead: Vector2 = q.pos + q.vel * 0.4
	var d: float = p.pos.distance_to(lead)
	if d < 2.0 or d > 22.0:
		return -1.0
	var open: float = m.pass_lane_open(p.pos, lead, t)
	var near_q := 99.0
	for o: Player in m.skaters(1 - t):
		near_q = minf(near_q, o.pos.distance_to(lead))
	var forward := (lead.x - p.pos.x) * a / 10.0
	var danger := 0.0
	if lead.x * a < -10.0 and absf(lead.y) < 4.0:
		danger = 0.8   # across the front of our own goal: never
	var value := open * 0.8 + clampf(near_q / 4.0, 0.0, 1.0) * 0.6 + clampf(forward, -0.5, 0.8) - danger - d / 60.0
	var g := target_goal()
	if lead.distance_to(g) < 10.0 and absf(lead.y) < 4.0 and lead.x * a < Rules.GOAL_LINE:
		# Into the slot, and better still across it from the side: the pass goals come from.
		value += 0.3 + (0.15 if absf(p.pos.y) > 2.0 and signf(p.pos.y) != signf(lead.y) else 0.0)
	if m.possession_time < 2.5 and p.pos.x * a < 0.0 and forward > 0.6:
		value += 0.25   # the ball just won: the long pass ahead to the forward away
	if p.pos.x * a < 0.0 and (lead.x - p.pos.x) * a < 1.5:
		# Back or across in our own end: worth less the longer we have had the ball.
		value -= 0.25 + clampf(m.possession_time / 6.0, 0.0, 1.0) * 0.6
	return value


## Where in the goal to shoot: a corner, low more often (the goalkeeper's hands are up), with an error by skill.
func _aim(p: Player, g: Vector2) -> Vector3:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var gk = m.keeper(1 - t)
	if gk:
		# The far side of the goalkeeper.
		side = -signf(gk.pos.y - p.pos.y * 0.15) if absf(gk.pos.y) > 0.05 else side
	var z := side * Rules.GOAL_W * 0.5 * _rng.randf_range(0.45, 0.95)
	var y := _rng.randf_range(0.05, 0.45) if _rng.randf() < 0.65 else _rng.randf_range(0.6, 1.0)
	var err = (115.0 - p.stat("shot")) / 100.0 * 0.8 / level
	return Vector3(g.x, clampf(y + _rng.randf_range(-err, err) * 0.6, 0.04, 1.5), z + _rng.randf_range(-err, err))


# ---------------------------------------------------------------- line changes (302)

func _line_change(dt: float, players: Array, ours: bool, b: Vector2) -> void:
	if not m.in_play():
		return
	shift += dt
	if changing:
		var any := false
		for p in players:
			if p.get_meta("going_off", false):
				any = true
		if not any:
			changing = false
			shift = 0.0
		return
	# A flying change: when the line has had its shift and the ball is safe (ours, or far up the rink).
	var safe: bool = ours or b.x * att() > 4.0
	if shift > SHIFT_S * _rng.randf_range(0.9, 1.25) and safe:
		changing = true
		line = (line + 1) % 3
		for p in players:
			if p.slot != 6:   # the sixth player (an empty net) stays on
				p.set_meta("going_off", true)


## Off over the board in the team's substitution zone; the next line's player comes on in the same place (302: the
## change in the team's own zone).
func _go_off(p: Player) -> void:
	var zone: Vector2 = m.sub_zone(t)
	var at := Vector2(clampf(p.pos.x, minf(zone.x, zone.y), maxf(zone.x, zone.y)), -Rules.HALF_W + 0.35)
	if p.pos.distance_to(at) < 0.6 or p == m.ball.carrier:
		if p == m.ball.carrier:
			p.set_meta("going_off", false)   # never with the ball: he finishes the play
			return
		m.change_player(p, line)
		p.set_meta("going_off", false)
		return
	_run_to(p, at, 0.9)


# ---------------------------------------------------------------- the goalkeeper (303, 403)

## The goalkeeper's place: on the line between the ball and the middle of his goal, a step out from the goal line,
## inside the goalkeeper area; nearer the post when the ball is wide.
func keeper(gk: Player, dt: float) -> void:
	if gk.act in ["save_low", "save_high_l", "save_high_r", "throw", "catch"] and gk.act_t < gk.act_len:
		gk.want_vel = Vector2.ZERO
		return
	var g := own_goal()
	var b: Vector2 = m.ball.floor_pos()
	var to_b := (b - g)
	var out := clampf(0.55 + (1.0 - absf(to_b.normalized().y)) * 0.55, 0.4, 1.0)
	var want := g + to_b.normalized() * out
	want.x = clampf(want.x, minf(g.x, g.x + att() * 1.1), maxf(g.x, g.x + att() * 1.1))
	want.y = clampf(want.y, -0.75, 0.75)
	var d: Vector2 = want - gk.pos
	gk.want_vel = d * 6.0 if d.length() > 0.03 else Vector2.ZERO
	if gk.want_vel.length() > 4.0:
		gk.want_vel = gk.want_vel.normalized() * 4.0
	gk.want_face = (b - gk.pos).angle()
	# Down in the butterfly when the ball is close in front and low.
	if b.distance_to(g) < 6.0 and gk.act == "":
		gk.do("kneel", 0.3)
