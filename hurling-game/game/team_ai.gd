class_name TeamAI
extends RefCounted
## How a side plays when the computer runs it (and the players on your side you are not controlling): its shape,
## who marks whom, who goes for the ball, and what the player on the ball does with it. The numbers come from
## analysis of senior inter-county hurling (docs/AI.md): about 77 shots a game, 55% scored from play and 75% from
## placed balls; about 33 puck-outs a side, 37% short; players' top speed 8.4 m/s; possessions of four to seven
## passes, stick-passes and hand-passes in about a 5:3 ratio.

var m: Node            # the Match
var team := 0
var skill := 1.0       # 0.8 to 1.2 with the difficulty, for the computer's side
var think_t := {}      # player -> next time his decision is looked at again
var plan := {}         # player -> what he means to do with the ball: {kind, target, t}

## Line -> metres from his own end line in the team's shape when the ball is at midfield.
const LINE_X := {DB.POS_GK: 1.5, DB.POS_FB: 22.0, DB.POS_HB: 45.0, DB.POS_MF: 70.0, DB.POS_HF: 95.0, DB.POS_FF: 117.0}
const LANE_Z := 25.0   # a wing player's distance in from the centre of the pitch


func _init(p_match: Node, p_team: int) -> void:
	m = p_match
	team = p_team


func dir() -> float:
	return m.dir(team)


## The player each of ours marks: the direct opponent by the numbers (the right corner-back on the left
## corner-forward ... the midfielders on each other). The goalkeeper marks no one.
static func mark_number(n: int) -> int:
	return {2: 15, 3: 14, 4: 13, 5: 12, 6: 11, 7: 10, 8: 9, 9: 8, 10: 7, 11: 6, 12: 5, 13: 4, 14: 3, 15: 2}.get(n, 0)


## Where a player stands in the team's shape: his line's depth, shifted toward the ball and up the pitch when his
## side has it; his lane across the pitch, drawn toward the ball's side.
func home_spot(pl: Player) -> Vector3:
	var d := dir()
	var ln := pl.line()
	var bx: float = m.ball.global_position.x
	var bz: float = m.ball.global_position.z
	var ball_prog := Pitch.HALF_L + bx * d          # metres from our own end line to the ball
	var ours: bool = m.possession_team() == team
	var base: float = LINE_X.get(ln, 70.0)
	var x_from_own := base
	if ln != DB.POS_GK:
		# The whole side slides with the ball, the lines keeping their gaps (tighter when defending).
		var shift := (ball_prog - 70.0) * (0.55 if ours else 0.45)
		x_from_own = base + shift
		if ours:
			x_from_own += {DB.POS_FB: 4.0, DB.POS_HB: 8.0, DB.POS_MF: 6.0, DB.POS_HF: 2.0, DB.POS_FF: 0.0}.get(ln, 0.0)
		else:
			x_from_own -= {DB.POS_FB: 2.0, DB.POS_HB: 4.0, DB.POS_MF: 8.0, DB.POS_HF: 10.0, DB.POS_FF: 8.0}.get(ln, 0.0)
		var lo: float = {DB.POS_FB: 8.0, DB.POS_HB: 18.0, DB.POS_MF: 30.0, DB.POS_HF: 45.0, DB.POS_FF: 60.0}.get(ln, 10.0)
		var hi: float = {DB.POS_FB: 85.0, DB.POS_HB: 105.0, DB.POS_MF: 118.0, DB.POS_HF: 128.0, DB.POS_FF: 134.0}.get(ln, 130.0)
		x_from_own = clampf(x_from_own, lo, hi)
	var place := float(pl.data.get("place", 0.0))
	var z := -place * LANE_Z * d
	if ln == DB.POS_MF:
		z = -place * 14.0 * d
	if ln != DB.POS_GK:
		z = lerpf(z, bz, 0.22 if ln in [DB.POS_FB, DB.POS_FF] else 0.3)
	else:
		z = clampf(bz * 0.06, -2.0, 2.0)
	var x := (x_from_own - Pitch.HALF_L) * d
	return Vector3(x, 0, clampf(z, -Pitch.HALF_W + 3.0, Pitch.HALF_W - 3.0))


## The opponent a player marks (or null).
func mark_of(pl: Player) -> Player:
	var n := mark_number(pl.pos_num)
	if n == 0:
		return null
	var opp: Player = m.player_by_num(1 - team, n)
	if opp == null or not opp.on_pitch():
		return null
	return opp


## Off the ball, out of possession: goal-side of his man, between him and the goal we defend, closer the nearer the
## ball is; drawn toward his place in the shape when his man wanders far from it.
func defend_spot(pl: Player) -> Vector3:
	var home := home_spot(pl)
	var mk := mark_of(pl)
	if mk == null:
		return home
	var own_goal := Vector3(-Pitch.HALF_L * dir(), 0, 0)
	var mp := mk.global_position
	var to_goal := (own_goal - mp)
	to_goal.y = 0
	var near_ball: float = mp.distance_to(m.ball.global_position)
	var gap := lerpf(1.4, 4.5, clampf(near_ball / 50.0, 0.0, 1.0))
	var spot := mp + to_goal.normalized() * gap
	# A defender keeps nearer his own zone when the man runs off across the pitch.
	var pull := clampf((spot.distance_to(home) - 25.0) / 30.0, 0.0, 0.5)
	return spot.lerp(home, pull)


## In possession, off the ball: forwards find space away from their markers, wing players hold the width, the
## nearest teammates come close for a hand-pass (the support runner).
func attack_spot(pl: Player, carrier: Player) -> Vector3:
	var home := home_spot(pl)
	if carrier == null:
		return home
	var d := dir()
	var line := pl.line()
	var cp := carrier.global_position
	var spot := home
	if line in [DB.POS_HF, DB.POS_FF]:
		# Run into space: the home spot moved away from the nearest defender.
		var near: Player = m.nearest_opponent(pl, 12.0)
		if near != null:
			var away := pl.global_position - near.global_position
			away.y = 0
			spot += away.normalized() * 6.0
	# The support runner: the nearest of ours behind or beside the carrier comes to about 6 m off his shoulder.
	if support_runner(carrier) == pl:
		spot = cp + Vector3(-d * 3.0, 0, (5.5 if cp.z < 0.0 else -5.5))
	return Pitch.clamp_in(spot, 2.0)


func support_runner(carrier: Player) -> Player:
	var best: Player = null
	var bd := 1e9
	for p in m.team_players(team):
		var pl: Player = p
		if pl == carrier or pl.is_keeper() or not pl.on_pitch():
			continue
		var dd := pl.global_position.distance_to(carrier.global_position)
		if dd < bd:
			bd = dd
			best = pl
	return best if bd < 18.0 else null


# ---------------------------------------------------------------- the player on the ball

## What the carrier does now: {kind: "shoot" | "goal" | "pass" | "hand_pass" | "carry" | "solo" | "to_hand",
## target (Vector3), to (Player)}. Looked at every few tenths of a second, and at once when he is pressed.
func decide(pl: Player) -> Dictionary:
	var d := dir()
	var p := pl.global_position
	var goal := Vector3(Pitch.HALF_L * d, 0, 0)
	var dist := Vector2(goal.x - p.x, p.z).length()
	var press: Player = m.nearest_opponent(pl, 30.0)
	var press_d := press.global_position.distance_to(p) if press != null else 99.0
	var in_hand: bool = pl.ball_hand
	var c: Rules.Carry = m.carry_of(pl)
	# A shot: a point from where he is, or a goal if he is through.
	var chance := shot_chance(pl, dist, absf(p.z), press_d)
	var goal_chance := goal_shot_chance(pl, dist, absf(p.z), press_d)
	# A goal is gone for only with a clear sight of it: inside the 20 m line, no defender but the goalkeeper close.
	if goal_chance > 0.32 and goal_chance > chance * 0.5 and nearest_opponent_d(pl, 3.5) and rng_ok():
		return {"kind": "goal"}
	if chance >= lerpf(0.5, 0.4, clampf((60.0 - dist) / 40.0, 0.0, 1.0)) / skill:
		return {"kind": "shoot"}
	# A pass to someone better placed.
	var best := best_pass(pl, press_d)
	if not best.is_empty() and (press_d < 5.0 or float(best.gain) > 18.0 or dist > 95.0):
		return best
	# Carry it on: solo when the hand's steps are nearly up (or take it back into the hand to strike).
	if in_hand and c.steps >= 3:
		if c.catches < Rules.MAX_CATCHES:
			return {"kind": "solo"}
		return best if not best.is_empty() else {"kind": "shoot"}
	if press_d < 2.2 and not best.is_empty():
		return best
	return {"kind": "carry", "target": _carry_target(pl)}


## A carrier's run: toward the goal, bending away from whoever is closing in.
func _carry_target(pl: Player) -> Vector3:
	var d := dir()
	var p := pl.global_position
	var t := p + Vector3(d * 12.0, 0, -p.z * 0.15)
	var near: Player = m.nearest_opponent(pl, 10.0)
	if near != null:
		var away := p - near.global_position
		away.y = 0
		t += away.normalized() * 5.0
	return Pitch.clamp_in(t, 3.0)


## The chance of a point from here, as the game plays it: about 80% from 20-30 m in front of the posts, about half
## from 45 m, falling off past 65 m, less from a tight angle, less again under pressure, more for a good striker.
static func shot_chance(pl: Player, dist: float, off_centre: float, press_d: float) -> float:
	var acc := float(pl.data.get("accuracy", 70)) / 100.0
	var base := 0.97 - maxf(0.0, dist - 20.0) * 0.012
	if dist > 65.0:
		base -= (dist - 65.0) * 0.02
	var angle := atan2(off_centre, maxf(1.0, dist * 0.9))
	base -= maxf(0.0, angle - 0.45) * 0.55
	if press_d < 4.0:
		base -= (4.0 - press_d) * 0.08
	return clampf(base * lerpf(0.75, 1.1, acc), 0.0, 0.98)


## The chance of a goal: only close in (inside about 25 m), in front, with room to strike.
static func goal_shot_chance(pl: Player, dist: float, off_centre: float, press_d: float) -> float:
	if dist > 25.0 or off_centre > 14.0:
		return 0.0
	var acc := float(pl.data.get("accuracy", 70)) / 100.0
	var base := 0.62 - maxf(0.0, dist - 10.0) * 0.025 - off_centre * 0.02
	if press_d < 3.0:
		base -= 0.18
	return clampf(base * lerpf(0.8, 1.1, acc), 0.0, 0.9)


## The best pass: to a teammate further on and free of his marker, struck (up to about 70 m) or hand-passed (under
## about 13 m). {kind, to, gain} or {}.
func best_pass(pl: Player, press_d: float) -> Dictionary:
	var d := dir()
	var p := pl.global_position
	var best := {}
	var best_v := -1e9
	for q in m.team_players(team):
		var r: Player = q
		if r == pl or not r.on_pitch() or r.is_keeper() or r.down(m.now):
			continue
		var rp := r.global_position
		var dist := p.distance_to(rp)
		if dist < 4.0 or dist > 72.0:
			continue
		var gain := (rp.x - p.x) * d
		var open := _openness(r)
		if open < 2.0 and dist > 14.0:
			continue
		var hand := dist < 13.0 and pl.ball_hand
		var v := gain * 0.9 + open * 2.2 - dist * 0.12
		if hand:
			v += 6.0 if press_d < 3.5 else 0.0
		elif dist < 14.0:
			v -= 6.0
		# The lane: an opponent near the line of the pass cuts it out.
		v -= _lane_risk(p, rp) * 14.0
		if gain < -10.0 and press_d > 5.0:
			v -= 20.0
		if v > best_v:
			best_v = v
			best = {"kind": "hand_pass" if hand else "pass", "to": r, "gain": gain}
	return best if best_v > -5.0 else {}


## No outfield defender within d metres of him (the goalkeeper aside).
func nearest_opponent_d(pl: Player, d: float) -> bool:
	for q in m.team_players(1 - team):
		var o: Player = q
		if o.on_pitch() and not o.is_keeper() and o.global_position.distance_to(pl.global_position) < d:
			return false
	return true


## Most clear chances are still taken as points: a goal is gone for about one time in three.
func rng_ok() -> bool:
	return randf() < 0.6


func _openness(r: Player) -> float:
	var near: Player = m.nearest_opponent(r, 25.0)
	return 25.0 if near == null else r.global_position.distance_to(near.global_position)


func _lane_risk(a: Vector3, b: Vector3) -> float:
	var risk := 0.0
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1.0:
		return 0.0
	for q in m.team_players(1 - team):
		var o: Player = q
		var t := clampf((o.global_position - a).dot(ab) / len2, 0.0, 1.0)
		if t < 0.15 or t > 0.9:
			continue
		var dd := (a + ab * t).distance_to(o.global_position)
		if dd < 3.0:
			risk = maxf(risk, 1.0 - dd / 3.0)
	return risk


## Where to aim a point: between the posts, high over the bar, a little inside the post nearer him.
static func point_target(dir_: float, from: Vector3) -> Vector3:
	return Vector3(Pitch.HALF_L * dir_, Pitch.BAR_H + 3.5, clampf(from.z * 0.12, -1.6, 1.6))


## Where to aim a goal: low into a corner, away from the goalkeeper.
static func goal_target(dir_: float, keeper_z: float) -> Vector3:
	var side := -signf(keeper_z) if absf(keeper_z) > 0.2 else (1.0 if randf() < 0.5 else -1.0)
	return Vector3(Pitch.HALF_L * dir_, 0.7, side * 2.3)


## The puck-out: short to a corner-back or wing-back who is free (37% of puck-outs in the 2026 league), else long
## to the middle third, toward the wing where his side's half-forward is.
func puck_out_choice(keeper: Player) -> Dictionary:
	var d := dir()
	var short_best: Player = null
	var bo := 0.0
	for q in m.team_players(team):
		var r: Player = q
		if r.line() in [DB.POS_FB, DB.POS_HB] and r.on_pitch():
			var o := _openness(r)
			if o > bo:
				bo = o
				short_best = r
	if short_best != null and bo > 9.0 and randf() < 0.5:
		return {"kind": "short", "to": short_best}
	var wing := -1.0 if randf() < 0.5 else 1.0
	var land := Vector3((-Pitch.HALF_L + 70.0 + randf() * 18.0) * d, 0, wing * randf_range(8.0, 24.0))
	return {"kind": "long", "target": land}
