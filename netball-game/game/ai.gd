class_name TeamAI
extends RefCounted
## How both teams play, as netball is played: each position in its areas, attackers leading into space and holding
## ("posting") when the ball comes, defenders marking their opposite number goal-side and defending the ball from
## 0.9 m with arms over it. The player with the ball looks for the pass that gets the ball nearer the circle without
## being picked off, and passes in about a second (never past three); shooters shoot from close, the GA from further.
## It sets where players want to go and what they try; Match decides what happens.
##
## The numbers it plays to (docs/RULES.md "How the AI plays"): about 75% of centre passes scored, GS about 86% and GA
## about 77% shooting, 9-12 gains and some 15 turnovers a team in 60 minutes, and a penalty about every 70 seconds of
## play for each team (a third of the real rate, so the game is not all whistle: real teams give away 50-58 a match).

var m                       # the Match
var me: Player = null       # your player: the AI leaves her to you
var user_aim := Vector2.ZERO
var last_passer: Player = null
var _decide := {}           # holder -> when she passes (s held)
var _arms := {}             # player -> seconds left with arms up (your DEFEND)
var _cp_spots := {}         # player -> centre pass spot
var _user_target: Player = null


func _init(p_match) -> void:
	m = p_match


func rng() -> RandomNumberGenerator:
	return m.rng


## How sharp the team plays: the side you play against is sharper on harder levels; AI v AI both at 1.
func sharp(t: int) -> float:
	if m.user_team < 0 or t == m.user_team:
		return 1.0
	return [0.72, 0.88, 1.0, 1.12][clampi(int(m.config.get("difficulty", Game.settings.difficulty)), 0, 3)]


# ---------------------------------------------------------------- the centre pass

## Everyone's spot for a centre pass taken by team t: the C taking it in the centre circle; the other C in the centre
## third beside it; the others in their own goal thirds, attackers at the transverse line ready to drive in,
## defenders beside them, goal-side. snap: put them there at once (the start of a quarter).
func place_centre(t: int, snap: bool) -> void:
	_cp_spots.clear()
	var d: int = m.team_dir(t)       # the end team t attacks
	var tl := Court.THIRD_X
	var a := {
		"C": Vector2(0.0, 0.0),
		"GA": Vector2(d * (tl + 0.45), -2.2), "WA": Vector2(d * (tl + 0.45), 4.0), "GS": Vector2(d * (Court.HALF_L - 2.6), -0.6),
		"WD": Vector2(-d * (tl + 0.45), 4.3), "GD": Vector2(-d * (tl + 0.45), -2.6), "GK": Vector2(-d * (Court.HALF_L - 3.0), 0.3),
	}
	# The defending side stands with its opposite numbers: goal-side and a little toward the middle.
	var o := 1 - t
	var b := {}
	for pos in a:
		var opp: String = Rules.OPPOSITE[pos]
		var spot: Vector2 = a[opp]
		# Team o's defenders stand goal-side of their players (toward the goal team t attacks, x = d * HALF_L); its
		# attackers beside theirs, toward the goal they attack.
		var toward := (Vector2(d * Court.HALF_L, 0.0) - spot).normalized() if pos in ["WD", "GD", "GK"] else (Vector2(-d * Court.HALF_L, 0.0) - spot).normalized()
		b[pos] = spot + toward * 0.9 + Vector2(0, 0.5 * signf(-spot.y + 0.01))
	b["C"] = Vector2(d * 1.4, 1.3)
	for pos in a:
		_set_cp(m.player_at(t, pos), a[pos], snap, d)
		var ob: Player = m.player_at(o, pos)
		var spot: Vector2 = b[pos]
		if pos != "C":
			spot = Rules.onside_point(pos, spot, -d, 0.35)
			# Before the whistle only the Cs may be in the centre third.
			spot.x = signf(spot.x) * maxf(absf(spot.x), Court.THIRD_X + 0.4)
		_set_cp(ob, spot, snap, -d)


func _set_cp(pl: Player, spot: Vector2, snap: bool, d: int) -> void:
	if pl == null:
		return
	_cp_spots[pl] = spot
	pl.out_until = 0.0
	pl.stopped = false
	pl.set_act("ready")
	if snap:
		pl.place(spot, PI * 0.5 * d)
	pl.target = spot
	pl.want_speed = 4.2


## Everyone is on her spot (or near enough) for the restart.
func settled() -> bool:
	for t in 2:
		for pl in m.players[t]:
			if pl == m.holder or pl.away():
				continue
			if pl.vel.length() > 1.2:
				return false
	return true


# ---------------------------------------------------------------- every frame

func think(dt: float) -> void:
	for pl in _arms.keys():
		_arms[pl] = float(_arms[pl]) - dt
		if float(_arms[pl]) <= 0.0:
			_arms.erase(pl)
	var centre_setup: bool = m.phase == "setup" and String(m.restart.get("kind", "")) == Rules.CENTRE
	for t in 2:
		for pl in m.players[t]:
			pl.reaction -= dt
			if pl == me and pl != m.holder:
				if not _arms.has(pl) and pl.act in ["defend", "defend_shot"]:
					pl.set_act("ready")
				# A pass coming to you: she runs on to it unless you steer her.
				var incoming: bool = m.ball.state == "flight" and m.pass_info.get("to") == pl
				if not (incoming and m.controls and m.controls.joystick.length() < 0.1):
					continue
			if pl.suspended > 0.0:
				_suspended(pl)
				continue
			if pl == m.holder:
				_holder(pl, dt)
				continue
			if pl.away():
				_out_of_play(pl)
				continue
			if centre_setup:
				if _cp_spots.has(pl) and pl != m.restart.get("taker"):
					pl.target = _cp_spots[pl]
					pl.want_speed = 4.0
					pl.look_on = true
					pl.look_at_p = Vector2.ZERO
				continue
			match m.phase:
				"stop":
					pl.target = pl.p + pl.vel * 0.3
					pl.want_speed = 1.0
					pl.look_on = true
					pl.look_at_p = m.ball.court_pos()
					continue
				"goal":
					pl.want_speed = 0.0
					pl.target = pl.p
					continue
			if pl == m.restart.get("taker") and m.phase == "setup":
				continue
			if _rejoin(pl):
				continue
			_play(pl, dt)
	if m.phase == "live":
		_slips(dt)


func _out_of_play(pl: Player) -> void:
	# The penalised player stands beside the thrower until the ball is released; then she is back in play.
	if m.holder == null and m.phase == "live":
		pl.out_until = 0.0
		pl.set_act("ready")
		return
	pl.want_speed = 3.0
	pl.look_on = true
	pl.look_at_p = m.ball.court_pos()
	if pl.p.distance_to(pl.target) < 0.3:
		pl.set_act("out_of_play")


## Suspended (R18, game management): she waits by her team's bench, off the court, for two minutes of playing time.
func _suspended(pl: Player) -> void:
	pl.target = bench_spot(pl.team)
	pl.want_speed = 3.0
	pl.fenced = false
	pl.look_on = true
	pl.look_at_p = m.ball.court_pos()
	if pl.p.distance_to(pl.target) < 0.4:
		pl.set_act("ready")


## Back from the bench (or from fetching a ball): off the court, she walks along outside the line until she is level
## with her own areas, then steps on, so she never crosses an area she may not enter.
func _rejoin(pl: Player) -> bool:
	if Court.on_court(pl.p) or pl == m.holder or m.ball.state == "loose":
		if pl.suspended <= 0.0 and not pl.fenced and pl != me:
			pl.fenced = true
		return false
	var edge := Court.clamp_court(pl.p, 0.4)
	var inside := Rules.onside_point(pl.pos, edge, pl.dir, 0.3)
	pl.fenced = false
	pl.want_speed = 4.0
	pl.set_act("run")
	if inside.distance_to(edge) > 0.5:
		pl.target = Vector2(inside.x, pl.p.y)
	else:
		pl.target = inside
	return true


## Beside the officials' table, on the near side: team 0's bench to the left, team 1's to the right.
static func bench_spot(t: int) -> Vector2:
	return Vector2(-6.5 if t == 0 else 6.5, Court.HALF_W + Court.RUNOFF * 0.6)


## One player in open play (or as a restart is set up): chase a loose ball, meet a pass, take a cut at one, or move
## with the play: lead and post in attack, mark in defence.
func _play(pl: Player, dt: float) -> void:
	var b: Vector2 = m.ball.court_pos()
	pl.look_on = true
	pl.look_at_p = b
	if m.ball.state == "flight" and m.pass_info.has("to"):
		if m.pass_info.to == pl:
			pl.set_act("catch" if m.ball.flight_left() < 0.35 else "run")
			return   # running to the catch point the pass set
		if m.pass_info.get("cut") == pl:
			_cut(pl)
			return
	if m.ball.state == "loose":
		if _chaser(pl):
			var to := Rules.onside_point(pl.pos, b, pl.dir, 0.1)
			pl.target = to
			pl.want_speed = pl.speed_cap()
			pl.set_act("run")
			return
	var attacking: bool = m.possession == pl.team
	if m.possession < 0:
		attacking = m.last_possession == pl.team
	if attacking:
		_attack(pl, dt)
	else:
		_defend(pl, dt)


## Is she one of the two nearest her team's players to a loose ball (and allowed where it is)?
func _chaser(pl: Player) -> bool:
	var b: Vector2 = m.ball.court_pos()
	if Rules.offside(pl.pos, Court.clamp_court(b, 0.05), pl.dir):
		return false
	var mine := pl.p.distance_to(b)
	var closer := 0
	for o in m.players[pl.team]:
		if o != pl and o.p.distance_to(b) < mine and not Rules.offside(o.pos, Court.clamp_court(b, 0.05), o.dir):
			closer += 1
	return closer < 2


# ---------------------------------------------------------------- attack

## Where each attacker works, in her team's frame (ax along the court toward the goal she attacks, z across), from
## where the ball is: GS round the post, GA at the circle's edge or driving through the centre third, WA wide and
## ahead of the ball and in the pocket by the circle, C in support of the ball, the defenders behind it.
func _anchor(pl: Player) -> Vector2:
	var b: Vector2 = m.ball.court_pos()
	var d := pl.dir
	var bax := b.x * d
	var hl := Court.HALF_L
	var tl := Court.THIRD_X
	var ax := 0.0
	var z := 0.0
	match pl.pos:
		"GS":
			ax = hl - (2.0 if bax > tl else 3.6)
			z = -0.8
		"GA":
			ax = clampf(bax + 6.0, -tl + 1.0, hl - 4.6)
			z = -2.6
		"WA":
			ax = clampf(bax + 5.0, -tl + 1.0, hl - 5.6)
			z = 4.2
		"C":
			ax = clampf(bax + 3.5, -hl + 5.6, hl - 5.6)
			z = 1.0
		"WD":
			ax = clampf(bax - 1.5, -hl + 5.6, tl - 0.6)
			z = -4.0
		"GD":
			ax = clampf(bax - 3.5, -hl + 3.0, tl - 0.8)
			z = -1.5
		"GK":
			ax = clampf(bax - 6.0, -hl + 2.2, -tl - 1.2)
			z = 1.2
	return Vector2(ax * d, z)


func _attack(pl: Player, dt: float) -> void:
	pl.lead_t -= dt
	var anchor := _anchor(pl)
	if pl.lead_t <= 0.0 or pl.lead_to.distance_to(anchor) > 7.0:
		# A new lead: a few spots round the anchor; the one furthest from her marker and her team-mates.
		var mk := marker_of(pl)
		var best := anchor
		var bv := -INF
		for i in 5:
			var c := anchor + Vector2(rng().randf_range(-2.5, 2.5), rng().randf_range(-3.0, 3.0))
			if pl.pos == "GS" or (pl.pos == "GA" and anchor.x * pl.dir > Court.HALF_L - 5.0):
				c = anchor + Vector2(rng().randf_range(-1.6, 1.6), rng().randf_range(-2.4, 2.4))
			c = Rules.onside_point(pl.pos, c, pl.dir, 0.3)
			var v := 0.0
			if mk:
				v += minf(mk.p.distance_to(c), 4.0)
			for o in m.players[pl.team]:
				if o != pl:
					v += minf(o.p.distance_to(c), 3.0) * 0.4
			v -= c.distance_to(anchor) * 0.3
			if v > bv:
				bv = v
				best = c
		pl.lead_to = best
		pl.lead_t = rng().randf_range(1.2, 2.4)
	var dist := pl.p.distance_to(pl.lead_to)
	pl.target = pl.lead_to
	# Drive hard into the space, then hold it (posting) for the ball.
	pl.want_speed = pl.speed_cap() * (0.95 if dist > 1.5 else 0.5)
	pl.set_act("run")


## The opponent marking her (her opposite number).
func marker_of(pl: Player) -> Player:
	return m.player_at(1 - pl.team, Rules.OPPOSITE[pl.pos])


# ---------------------------------------------------------------- defence

func _defend(pl: Player, _dt: float) -> void:
	var mark: Player = m.player_at(1 - pl.team, Rules.OPPOSITE[pl.pos])
	if mark == null:
		return
	var own_goal := Court.goal_post(-pl.dir)
	var b: Vector2 = m.ball.court_pos()
	if mark == m.holder:
		# Defend the ball: arms over it from 0.9 m (a little more on the lower levels), between her and the goal.
		var from := mark.landing
		var gap := Court.DEFEND_DIST + lerpf(0.25, 0.04, clampf(sharp(pl.team) - 0.7, 0.0, 0.42) / 0.42)
		var to := from + (own_goal - from).normalized() * gap
		pl.target = Rules.onside_point(pl.pos, to, pl.dir, 0.05)
		pl.want_speed = 4.0
		pl.look_at_p = from
		pl.set_act("defend_shot" if mark.pos in ["GS", "GA"] and Court.in_circle(mark.landing, mark.dir) else "defend")
		return
	# Mark: goal-side of her player and toward the ball, reacting a beat late (sharper players sooner).
	if pl.reaction <= 0.0:
		pl.reaction = lerpf(0.34, 0.12, clampf(float(pl.data.defend) / 99.0 * sharp(pl.team), 0.0, 1.0))
		var to := mark.p + mark.vel * 0.25
		var toward_ball := (b - to).normalized()
		var toward_goal := (own_goal - to).normalized()
		to += toward_ball * 0.7 + toward_goal * 0.55
		pl.lead_to = Rules.onside_point(pl.pos, to, pl.dir, 0.1)
	pl.target = pl.lead_to
	pl.want_speed = minf(pl.speed_cap(), maxf(2.5, mark.vel.length() * 1.15))
	pl.set_act("mark" if pl.p.distance_to(mark.p) < 2.5 else "run")


func nearest_defender(team: int, except: Player = null) -> Player:
	var b: Vector2 = m.ball.court_pos()
	var best: Player = null
	var bd := INF
	for pl in m.players[team]:
		if pl == except or pl.away():
			continue
		var d: float = pl.p.distance_to(b)
		if Rules.offside(pl.pos, Court.clamp_court(b, 0.05), pl.dir):
			d += 6.0
		if d < bd:
			bd = d
			best = pl
	return best


func is_assisted(_pl: Player) -> bool:
	return false


# ---------------------------------------------------------------- the player with the ball

func holder_look(pl: Player) -> Vector2:
	if pl == me and user_aim.length() > 0.1:
		return pl.p + user_aim * 3.0
	var t := _user_target if pl == me and _user_target else _best_option(pl)[0] as Player
	if t:
		return t.p
	return Court.goal_post(pl.dir)


## The holder: shoot from close (GS) or in range (GA), or pass when the best option opens, inside her three seconds.
func _holder(pl: Player, _dt: float) -> void:
	if pl == me or m.phase != "live" or m.shot_info.has("by"):
		if pl == me:
			_user_target = _pick_user_target(pl)
		return
	if not _decide.has(pl):
		var quick := clampf(float(pl.data.pass) / 99.0, 0.3, 1.0)
		_decide.clear()
		_decide[pl] = rng().randf_range(0.55, 1.45) * lerpf(1.2, 0.85, quick)
	if m.hold_t < float(_decide[pl]):
		return
	# Shooters in the circle: shoot from close, pass in nearer if a team-mate is under the post.
	if Rules.may_shoot(pl.pos, pl.landing, pl.dir, m.from_free):
		var dist := pl.landing.distance_to(Court.goal_post(pl.dir))
		var other: Player = m.player_at(pl.team, "GA" if pl.pos == "GS" else "GS")
		var range_ok := dist < (3.6 if pl.pos == "GS" else 4.5)
		var closer_mate := other != null and Court.in_circle(other.p, other.dir) and other.p.distance_to(Court.goal_post(pl.dir)) < dist - 1.5 and _pass_value(pl, other) > 1.0
		if m.double_zone and Rules.double_zone_live(m.time_left, m.quarter_min) and dist >= Rules.DZ_FROM and rng().randf() < 0.35:
			range_ok = true   # a long two
		if range_ok and not (closer_mate and m.hold_t < 1.8):
			_decide.erase(pl)
			m.shoot()
			return
	var opt: Array = _best_option(pl)
	var to: Player = opt[0]
	var val: float = opt[1]
	if to and (val > 1.0 or m.hold_t > 1.9):
		_decide.erase(pl)
		m.throw_pass(to, pass_kind(pl, to))


## The pass a holder would make: [player, value].
func _best_option(pl: Player) -> Array:
	var best: Player = null
	var bv := -INF
	for o in m.players[pl.team]:
		if o == pl or o.away():
			continue
		var v := _pass_value(pl, o)
		if v > bv:
			bv = v
			best = o
	return [best, bv]


## How good a pass to `to` is: forward progress, a shooter in the circle best of all, minus the risk of an
## intercept; nothing the rules forbid (a short pass, over a third, the centre pass to anyone outside the centre third).
func _pass_value(from: Player, to: Player, noise := true) -> float:
	var kind := pass_kind(from, to)
	var at := catch_point(to, kind)
	if Rules.short_pass(from.p, at) or from.p.distance_to(at) < 2.2:
		return -100.0
	if Rules.over_third(from.p.x, at.x):
		return -100.0
	if String(m.restart.get("kind", "")) == Rules.CENTRE and not m.restart.get("cp_done", false) and not Rules.centre_pass_ok(to.pos, at):
		return -100.0
	var d := from.dir
	var progress := (at.x - from.p.x) * d
	var v := progress * 0.42
	if to == last_passer and m.hold_t < 1.6:
		v -= 1.4   # straight back to the player who just passed it: only when nothing else is on
	if String(m.restart.get("kind", "")) == Rules.CENTRE and not m.restart.get("cp_done", false):
		# The centre pass goes forward: to the GA or WA driving in, as nearly all do (C to GA to WA to GS is the most
		# common start of a passage of play).
		v += 3.0 if to.pos in ["GA", "WA"] else -2.0
	if to.pos in ["GS", "GA"] and Court.in_circle(at, d):
		v += 4.5 - at.distance_to(Court.goal_post(d)) * 0.7
	var dist := from.p.distance_to(at)
	if dist > 12.0:
		v -= (dist - 12.0) * 0.6
	# Open: how far her nearest opponent is from the catch.
	var open := 9.0
	for o in m.players[1 - from.team]:
		if not o.away():
			open = minf(open, o.p.distance_to(at))
	v += minf(open, 3.0) * 0.5
	v -= _risk(from, to, at, kind) * 7.0
	return v + (rng().randf_range(-0.3, 0.3) if noise else 0.0)


func pass_kind(from: Player, to: Player) -> String:
	var dist := from.p.distance_to(to.p)
	if dist > 10.5:
		return "shoulder"
	# A lob over the defender to a tall shooter under the post.
	if to.pos in ["GS", "GA"] and Court.in_circle(to.p, to.dir):
		var mk := marker_of(to)
		if mk and mk.p.distance_to(to.p) < 1.4:
			return "lob"
	# A bounce pass under the arms of a defender up close.
	var mkh := marker_of(from)
	if mkh and mkh.p.distance_to(from.p) < 1.4 and dist < 6.0 and float(from.data.pass) > 70.0 and dist > 3.0 and int(from.p.x * 10.0) % 5 == 0:
		return "bounce"
	return "chest"


## Where a pass to `to` would be caught: where she is running to, a little ahead (she leads onto it).
func catch_point(to: Player, kind: String) -> Vector2:
	var t := 0.45 if kind != "lob" else 0.8
	var at := to.p + to.vel * t
	return Rules.onside_point(to.pos, at, to.dir, 0.15)


## The chance a pass is picked off: the best opponent's margin to reach its path (seconds to spare).
func _risk(from: Player, to: Player, at: Vector2, kind: String) -> float:
	var worst := 0.0
	var dist := from.p.distance_to(at)
	var spd: float = {"chest": 11.5, "shoulder": 14.5, "bounce": 9.0, "lob": 8.5}.get(kind, 11.0)
	var dur := clampf(dist / spd, 0.25, 2.0)
	for d in m.players[1 - from.team]:
		if d.away() or d == marker_of(from) and d.p.distance_to(from.p) < 1.3 and kind == "lob":
			continue
		for k: float in [0.3, 0.5, 0.7, 0.9]:
			var pt := from.p.lerp(at, k)
			var h: float = 1.4 + (4.0 * {"lob": 1.6, "shoulder": 0.6, "bounce": -0.9, "chest": 0.25}.get(kind, 0.25) * k * (1.0 - k))
			if h > d.reach(true):
				continue
			var need: float = maxf(0.0, d.p.distance_to(pt) - 0.7) / d.speed_cap() + 0.22
			var margin: float = k * dur - need
			if margin > 0.0:
				worst = maxf(worst, clampf(0.25 + margin * 1.4, 0.0, 1.0))
	return worst


## A pass has gone: the opponents' best chance at it (if any) goes for it (Match resolves it where she meets it).
func on_pass(info: Dictionary) -> void:
	var from: Player = info.from
	last_passer = from
	var best: Player = null
	var best_margin := 0.0
	var best_k := 1.0
	var dur: float = info.dur
	for d in m.players[1 - from.team]:
		if d.away() or d == me:
			continue
		for k: float in [0.25, 0.4, 0.55, 0.7, 0.85, 0.95]:
			var pt: Vector3 = m.ball.flight_at(k)
			if pt.y > d.reach(true):
				continue
			if Rules.offside(d.pos, Vector2(pt.x, pt.z), d.dir):
				continue
			var need: float = maxf(0.0, d.p.distance_to(Vector2(pt.x, pt.z)) - 0.75) / d.speed_cap() + lerpf(0.45, 0.28, float(d.data.defend) / 99.0) / sharp(d.team)
			var margin: float = k * dur - need
			if margin > best_margin:
				best_margin = margin
				best = d
				best_k = k
	if best == null:
		return
	# A defender commits only when she reads it early; most passes she could just reach she leaves, staying with her
	# player (real teams make some 10 gains a match from some 250 passes).
	if best_margin < 0.12:
		return
	var go := clampf(best_margin * 0.9 - 0.05 + (float(best.data.defend) - 75.0) / 150.0, 0.0, 0.8) * sharp(best.team)
	if rng().randf() > go:
		return
	info.cut = best
	info.cut_k = best_k
	var take := clampf(0.3 + best_margin * 0.6 + (float(best.data.defend) - float(from.data.pass)) / 150.0, 0.1, 0.8) * sharp(best.team)
	var r := rng().randf()
	if r < take:
		info.cut_result = "take"
	elif r < take + (1.0 - take) * 0.45:
		info.cut_result = "tip"
	elif r < take + (1.0 - take) * 0.55:
		info.cut_result = "contact"   # she goes through the receiver: contact
	else:
		info.cut_result = "miss"


## Going for a pass: run to where she meets it, leap as it comes.
func _cut(pl: Player) -> void:
	var pt: Vector3 = m.ball.flight_at(float(m.pass_info.cut_k))
	pl.target = Vector2(pt.x, pt.z)
	pl.want_speed = pl.speed_cap()
	var left: float = (float(m.pass_info.cut_k) * m.ball.f_dur) - m.ball.f_t
	if left < 0.35:
		pl.set_act("leap")
	else:
		pl.set_act("run")


## How much a defender's arm is over the shot (0-1): from 0.9-1.2 m, arms up, a tall keeper more.
func shot_pressure(shooter: Player) -> float:
	var mk := marker_of(shooter)
	if mk == null:
		return 0.0
	var d := mk.p.distance_to(shooter.landing)
	if d < Court.DEFEND_DIST - 0.05 or d > 2.2:
		return 0.0
	var arms := 1.0 if mk.act in ["defend", "defend_shot"] else 0.4
	return clampf((2.2 - d) / 1.3, 0.0, 1.0) * arms * clampf(float(mk.data.height) / 1.85, 0.8, 1.1) * lerpf(0.6, 1.0, float(mk.data.defend) / 99.0)


# ---------------------------------------------------------------- slips: the infringements real players make

## How often the AI infringes, against the game's standard (Settings > Umpiring): fewer whistles, standard (about a
## third of real elite matches' rate), or the real rate (50-58 penalties a team a match).
func whistle_rate() -> float:
	return [0.5, 1.0, 3.0][clampi(int(m.config.get("whistles", Game.settings.get("whistles", 1))), 0, 2)]


## Contact and obstruction by the defender on the ball, a footwork slip, a step offside: at rates scaled from real
## matches (docs/RULES.md "How the AI plays"). Your own player makes only the mistakes you make.
func _slips(dt: float) -> void:
	if m.holder == null:
		return
	var h: Player = m.holder
	var dm := marker_of(h)
	if dm and dm != me and not dm.away() and dm.p.distance_to(h.landing) < 1.35:
		var disc := clampf(float(dm.data.defend) / 99.0, 0.4, 1.0)
		var lam := 0.075 * (1.45 - disc) * whistle_rate()
		if rng().randf() < lam * dt:
			if rng().randf() < 0.55:
				m._infringe("contact", dm, dm.p)
			else:
				m._infringe("obstruction", dm, dm.p)
			return
	if h != me and rng().randf() < 0.006 * dt * whistle_rate():
		h.landing += Vector2(0.05, 0)
		m.footwork.drag("l" if m.footwork.landing != "r" else "r")
		if m.footwork.fault == "":
			m.footwork.fault = "footwork"
		return
	if rng().randf() < 0.0035 * dt * whistle_rate():
		var t := rng().randi_range(0, 1)
		var pl: Player = m.players[t][rng().randi_range(0, 6)]
		if pl != me and pl != h and not pl.away():
			m._infringe("offside", pl, pl.p)


# ---------------------------------------------------------------- you

## Whom your PASS goes to. With the stick pushed: the team-mate in that direction (within about 50 degrees), the
## safest of them if there are several; with the stick at rest, the best pass on, as the AI would choose it. No
## randomness, so the ring showing who it is stays put; it changes only when it should, and holds for a moment.
func _pick_user_target(pl: Player) -> Player:
	var best: Player = null
	var bv := -INF
	var aim := user_aim.length() > 0.2
	for o in m.players[pl.team]:
		if o == pl or o.away():
			continue
		var v := _pass_value(pl, o, false)
		# You may throw the moment it is shown, before the AI would judge it open: a pass a defender can reach counts
		# against it more than it does for the AI.
		v -= _risk(pl, o, catch_point(o, pass_kind(pl, o)), pass_kind(pl, o)) * 4.0
		if aim:
			var d: Vector2 = (o.p - pl.p)
			var c := user_aim.normalized().dot(d.normalized())
			if c < 0.64:
				v = -1000.0 + c * 10.0   # out of the cone: only if no one is in it
			else:
				v = c * 6.0 + clampf(v, -6.0, 6.0)
		if o == _user_target and v > 0.0:
			v += 0.8   # keep the one already shown unless another is clearly better
		if v > bv:
			bv = v
			best = o
	return best


func user_target() -> Player:
	if m.holder == me and me:
		_user_target = _pick_user_target(me)
	return _user_target


## Your INTERCEPT: at a pass in the air, a leap for it if she can reach its path in time (the same reach and timing
## the AI's defenders have); at the player holding the ball, a lunge for it, which the umpire calls as contact if she
## gets there (a hand on the ball held by an opponent is interference).
func user_intercept(pl: Player) -> void:
	if pl == null:
		return
	if m.ball.state == "flight" and m.pass_info.has("from") and (m.pass_info.from as Player).team != pl.team and not m.pass_info.get("cut"):
		var dur: float = m.ball.f_dur
		var now: float = m.ball.f_t / dur
		var best_margin := -1.0
		var best_k := 1.0
		for i in 8:
			var k := lerpf(now + 0.08, 0.98, float(i) / 7.0)
			var pt: Vector3 = m.ball.flight_at(k)
			if pt.y > pl.reach(true):
				continue
			var need := maxf(0.0, pl.p.distance_to(Vector2(pt.x, pt.z)) - 0.8) / pl.speed_cap() + 0.12
			var margin := (k - now) * dur - need
			if margin > best_margin:
				best_margin = margin
				best_k = k
		pl.set_act("leap")
		if best_margin < -0.12:
			return
		m.pass_info.cut = pl
		m.pass_info.cut_k = best_k
		var take := clampf(0.55 + best_margin * 0.9, 0.2, 0.92)
		var r := rng().randf()
		m.pass_info.cut_result = "take" if r < take else ("tip" if r < take + (1.0 - take) * 0.6 else "miss")
		var pt2: Vector3 = m.ball.flight_at(best_k)
		pl.target = Vector2(pt2.x, pt2.z)
		pl.want_speed = pl.speed_cap()
		return
	if m.holder and m.holder.team != pl.team:
		var dist := pl.p.distance_to(m.holder.landing)
		pl.set_act("leap")
		if dist < 1.2:
			if Rules.contact(0.6, true):
				m._infringe("contact", pl, pl.p)


## Your DEFEND: arms up over the ball for a second and a half. Closer than 0.9 m to the landing foot it is
## obstruction, and the umpire sees most of them.
func user_defend(pl: Player) -> void:
	if pl == null:
		return
	_arms[pl] = 1.5
	var h: Player = m.holder
	var shot: bool = h != null and h.pos in ["GS", "GA"] and Court.in_circle(h.landing, h.dir)
	pl.set_act("defend_shot" if shot else "defend")
	if h and h.team != pl.team and Rules.obstruction(h.landing, pl.p, true) and rng().randf() < 0.85:
		m._infringe("obstruction", pl, pl.p)
