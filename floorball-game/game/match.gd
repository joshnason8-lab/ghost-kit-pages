extends Node3D
## A floorball match: 5 + 1 a side on a 40 x 20 m rink, to the IFF Rules of the Game (Rules: the decisions, the
## clock and the penalty bench), two referees who whistle and signal them, the team AI (TeamAI), and you running
## one player of your team with the joystick and buttons (TouchControls). With user_team -1 nobody plays: the AI
## match behind the home screen, and the tests' matches.
##
## Each physics tick: the AI and your controls say what every player wants, the contacts and the ball's pick-ups are
## judged, then every player steps (Player.step, the one writer of a player's position) and the ball moves (Ball.step,
## the one writer of its position), and the rules see what happened.

signal finished(result: Dictionary)

const WHISTLE_S := 1.6          # the stop after a whistle while the referee shows the call
const GOAL_S := 3.4
const SETUP_MAX_S := 7.0        # players walk to a restart; after this the restart is taken anyway
const PICKUP_SPEED := 15.0      # a ball faster than this past a blade is not controlled, only deflected
const PASSIVE_S := 40.0         # a team that keeps the ball this long without an attack is warned of passive play
const PASSIVE_WARN_S := 8.0     # after the warning: a shot, or the ball goes to the other team
const RESTART_DELAY_S := 9.0    # your free-hit or hit-in not taken by then: delaying a fixed situation
const ADVANTAGE_S := 2.6        # how long advantage is played before the free-hit is forgotten (play went on)

var config := {}
var rules: Rules.State
var arena: Arena
var ball: Ball
var cam: Camera3D
var hud = null
var touch = null
var ai: Array = []
var players := [[], []]          # [goalkeeper, slot 0..4]
var refs: Array = []
var squads := [[], []]
var kits: Array = []
var user_team := -1
var user_player = null
var demo := false
var watch := false
var paused := false
var phase := "intro"
var phase_t := 0.0
var restart := {}
var possession_time := 0.0
var _goal_scorer: Player = null   # the last goal's scorer, whom his team-mates run to
var carry_time := 0.0          # how long the carrier has had the ball himself (a first-time shot comes before 0.6 s)
var stats := {}                  # player id -> {g, a, sog, pim, saves, sa, name, num, team}
var team_stats := [{}, {}]
var advantage := {}              # a foul being played on: {team (fouled), offence, at, sanction, offender, left}
var gk_hold := 0.0
var gk_throw_air := false        # a goalkeeper's throw not yet touched anything (507.15)
var shooters_used := [[], []]
var calls: Array = []            # the referees' decisions, for the box score
var speed_k := 1.0
var _rng := RandomNumberGenerator.new()
var _last_carrier = null
var _assist_candidate = null
var _shot_live := {}             # the shot in the air: {by, team, keeper, decided, outcome}
var _auto_gfx := WsgAutoTier.new(Game.frame_cap())   # the shared foundation's: when to lower the graphics
var _detail_t := 0.0
var wsg_replay: WsgReplay        # the shared foundation's bodies as drawn, kept for the goal's replay (FoundationLink)
var _ball_ring: Array = []       # [clock, ball position] for the replay
var _replay := {}                # the goal's replay playing: {t, t1, cam, ball_at, hud}
var _goal_clock := 0.0
var _intro_left := 0.0
var _sim_left := -1.0
var passive := {"team": -1, "t": 0.0, "warned": false, "w": 0.0}   # 507.20: passive play
var pulled := [false, false]     # the goalkeeper off for a sixth outfield player (an empty net)
var sixth: Array = [null, null]  # each team's extra outfield player, off the rink until its keeper is pulled
var sitters := [[], []]          # each team's two figures for its penalised players: they walk to the penalty bench


func _ready() -> void:
	_rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	user_team = int(config.get("user_team", -1))
	# Watch a match (config "watch"): nobody plays, but it is a match like any other, with its scoreboard, pause and
	# result; the home screen's match behind the menus is a demo (no HUD, nothing kept).
	watch = bool(config.get("watch", false))
	demo = bool(config.get("demo", false)) or (user_team < 0 and not watch)
	var minutes := float(config.get("period", Game.PERIODS[clampi(int(Game.settings.period), 0, Game.PERIODS.size() - 1)]))
	rules = Rules.State.new()
	rules.period_s = minutes * 60.0
	rules.clock_mode = int(config.get("rules", Game.settings.rules))
	rules.knockout = bool(config.get("knockout", false))
	rules.ot_s = Rules.OT_IFF_S if rules.clock_mode == Rules.CLOCK_EFFECTIVE else Rules.OT_LEAGUE_S
	rules.ot_s = minf(rules.ot_s, rules.period_s * 0.5)
	speed_k = 1.0 if demo else [0.8, 1.0][clampi(int(Game.settings.get("game_speed", 0)), 0, 1)]
	var women := bool(config.get("women", false))
	var ids := [String(config.home), String(config.away)]
	kits = DB.kits(ids[0], ids[1])
	for t in 2:
		squads[t] = DB.squad(ids[t], women)
	Game.apply_graphics(get_viewport())
	arena = Arena.new(String(config.get("venue", "hall")), [kits[0][0]], [kits[1][0]])
	add_child(arena)
	ball = Ball.new()
	add_child(ball)
	ball.out_of_play.connect(_on_out)
	ball.crossed_goal_line.connect(_on_goal_line)
	ball.hit.connect(_on_ball_hit)
	for t in 2:
		var level := 1.0
		if t != user_team and user_team >= 0:
			level = [0.78, 0.92, 1.04, 1.15][clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, 3)]
		ai.append(TeamAI.new(self, t, level, int(config.get("seed", 1))))
		var gk := _make_player(squads[t][0], t, "G", 5)
		players[t].append(gk)
		var line: Array = _line(t, 0)
		for s in 5:
			players[t].append(_make_player(line[s], t, line[s].role, s))
		var six := _make_player(_line(t, 1)[0], t, "F", 6)
		six.on_rink = false
		six.visible = false
		players[t].append(six)
		sixth[t] = six
		for k in 2:
			var s := _make_player(_line(t, 2)[0], t, "F", 9)
			s.on_rink = false
			s.visible = false
			s.off_boards = true
			s.set_meta("sits", "")
			sitters[t].append(s)
	for i in 2:
		var r := Player.new({"skin": DB.SKIN[_rng.randi_range(0, 2)], "hair": DB.HAIR[_rng.randi_range(0, 5)], "height": 1.82, "hair_style": _rng.randi_range(0, 1),
			"shirt": _referee_shirt()}, -1, "R", i)
		r.match_node = self
		add_child(r)
		r.pos = Vector2(-4.0 + i * 8.0, 8.8 if i == 0 else -8.8)
		refs.append(r)
	for t in 2:
		for p in squads[t]:
			stats[p.id] = {"g": 0, "a": 0, "sog": 0, "pim": 0, "saves": 0, "sa": 0, "name": p.name, "num": p.num, "team": t, "role": p.role}
		team_stats[t] = {"shots": 0, "sog": 0, "fo": 0, "ppg": 0, "pp": 0, "blocked": 0, "passes": 0, "own_passes": 0}
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	# The goal's replay (FoundationLink): the shared foundation's bodies kept as drawn, a little over the replay's
	# reach before the goal plus the celebration that comes first. Not on Low, nor in the menu's match.
	if FoundationLink.enabled() and not demo and not bool(config.get("practice", false)) and int(Game.settings.graphics) > Game.GFX_LOW:
		wsg_replay = WsgReplay.new()
		add_child(wsg_replay)
		wsg_replay.seconds = maxf(wsg_replay.seconds, REPLAY_BEFORE + GOAL_S + 1.5)
	if bool(config.get("menu", false)):
		# Behind the home screen's whiteboard: the picture shifted so the play shows in the hall to its right.
		cam.mode = Game.CAM_HIGH
		cam.h_offset = -11.0
	if not demo:
		var hud_s: Script = load("res://game/hud.gd")
		hud = hud_s.new()
		add_child(hud)
		hud.setup(self)
		touch = hud.touch
		touch.action.connect(_on_action)
		touch.visible = user_team >= 0
		Sfx.crowd(0.4)
	_place_for_faceoff(Vector2.ZERO, true)
	phase = "intro"
	_intro_left = 2.6 if not demo else 0.2
	if demo and config.has("sim_seconds"):
		_sim_left = float(config.sim_seconds)
	if bool(config.get("practice", false)):
		_practice_start.call_deferred()


func _make_player(d: Dictionary, t: int, role: String, slot: int) -> Player:
	var dd := d.duplicate()
	dd.kit = kits[t]
	var p := Player.new(dd, t, role, slot)
	p.match_node = self
	add_child(p)
	return p


func _line(t: int, l: int) -> Array:
	var out := []
	for p in squads[t]:
		if int(p.line) == l:
			out.append(p)
	return out


# ---------------------------------------------------------------- who is where

## The direction team t attacks along x this period: team 0 toward +x in the first and third (the teams change ends
## at each interval, 201; the overtime is played as the third period ended).
func attack_dir(t: int) -> float:
	var p := mini(rules.period, 3)
	var s := 1.0 if p % 2 == 1 else -1.0
	return s if t == 0 else -s


## The team's substitution zone on the far side, as the x range [from, to]: its bench stays the same all match (104).
func sub_zone(t: int) -> Vector2:
	var s := -1.0 if t == 0 else 1.0
	return Vector2(Rules.SUB_ZONE_FROM_CENTRE * s, (Rules.SUB_ZONE_FROM_CENTRE + Rules.SUB_ZONE_LEN) * s)


func skaters(t: int) -> Array:
	var out := []
	for i in range(1, players[t].size()):
		var p: Player = players[t][i]
		if p.on_rink and not p.in_box:
			out.append(p)
	return out


func keeper(t: int) -> Player:
	return players[t][0]


func everyone() -> Array:
	var out: Array = []
	for t in 2:
		out.append_array(players[t])
	out.append_array(refs)
	return out


func has_ball(p) -> bool:
	return ball.carrier == p


func in_play() -> bool:
	return phase == "live"


func nearest_opponent(p) -> Player:
	var best: Player = null
	var bd := 1e9
	for o: Player in skaters(1 - p.team):
		var d: float = o.pos.distance_to(p.pos)
		if d < bd:
			bd = d
			best = o
	return best


## How open the line from a to b is: 1 with no opponent near it, 0 with one on it.
func pass_lane_open(a: Vector2, b: Vector2, t: int) -> float:
	var worst := 1.0
	var ab := b - a
	var l := ab.length()
	if l < 0.01:
		return 1.0
	for o: Player in skaters(1 - t):
		var k := clampf((o.pos - a).dot(ab) / (l * l), 0.0, 1.0)
		var d: float = o.pos.distance_to(a + ab * k)
		worst = minf(worst, clampf((d - 0.4) / 1.6, 0.0, 1.0))
	return worst


func shot_lane_open(p, g: Vector2) -> float:
	var worst := 1.0
	var ab: Vector2 = g - p.pos
	var l := ab.length()
	for o: Player in skaters(1 - p.team):
		var k := clampf((o.pos - p.pos).dot(ab) / (l * l), 0.0, 1.0)
		if k < 0.05:
			continue
		var d: float = o.pos.distance_to(p.pos + ab * k)
		worst = minf(worst, clampf((d - 0.25) / 1.2, 0.0, 1.0))
	return worst


# ---------------------------------------------------------------- the tick

func _physics_process(delta: float) -> void:
	if paused:
		return
	var dt := delta * speed_k
	# (Ranked before they are posed: a body made full detail after its pose this frame showed its hand open on the
	# stick till its next pose.)
	_rank_detail(delta)
	if phase == "replay":
		_replay_step(delta)
		return
	phase_t += dt
	match phase:
		"intro":
			_intro_left -= delta
			_step_all(dt)
			if _intro_left <= 0.0:
				_begin_restart({"kind": "faceoff", "spot": Vector2.ZERO})
		"live":
			_live(dt)
		"whistle":
			_stop_players()
			_step_all(dt)
			_tick_clock(dt, false)
			if phase_t >= WHISTLE_S:
				_setup_restart()
		"setup":
			_setup(dt)
			_tick_clock(dt, false)
		"goal":
			_celebrate()
			_step_all(dt)
			if phase_t >= GOAL_S:
				_after_goal()
		"interval":
			_stop_players()
			_step_all(dt)
			if demo and phase_t > 1.0:
				_next_period()
		"shootout":
			_shootout(dt)
		"over":
			_stop_players()
			_step_all(dt)
	if _sim_left > 0.0:
		_sim_left -= delta
	_officials(dt)
	cam.follow(ball.pos, delta, self)
	if hud:
		hud.refresh()
	if OS.has_feature("web") and Engine.get_physics_frames() % 6 == 0 and not demo:
		_web_probe()
	if wsg_replay:
		var now := FoundationLink.clock()
		wsg_replay.record(now)
		_ball_ring.append([now, ball.position])
		while _ball_ring.size() > 2 and float(_ball_ring[0][0]) < now - wsg_replay.seconds:
			_ball_ring.pop_front()


func _step_all(dt: float) -> void:
	_separate()
	for t in 2:
		for p: Player in players[t]:
			p.writes = 0
			p.step(dt)
	_carry_ball()
	ball.step(dt)


func _stop_players() -> void:
	for p: Player in everyone():
		p.want_vel = Vector2.ZERO


func _tick_clock(dt: float, live: bool) -> void:
	var n: int = rules.penalties[0].size() + rules.penalties[1].size()
	var s := [rules.strength(0), rules.strength(1)]
	var end := rules.tick(dt, live)
	# A penalty over: the player back from the penalty bench, his team whole again.
	if rules.penalties[0].size() + rules.penalties[1].size() != n or s != [rules.strength(0), rules.strength(1)]:
		_update_boxes()
	if end == "period_end":
		_period_over()


func _live(dt: float) -> void:
	possession_time += dt
	carry_time += dt
	for t in 2:
		ai[t].play(dt)
		if not pulled[t]:
			ai[t].keeper(keeper(t), dt)
	_empty_net()
	_user(dt)
	_pickups()
	_keeper_block()
	_keeper_hold(dt)
	_check_shot()
	_advantage_tick(dt)
	_passive_tick(dt)
	_step_all(dt)
	_tick_clock(dt, true)
	_crowd_noise()


## Bodies keep apart: each pushes the other's wanted velocity away a little (never their positions: Player.step is
## the one place those change).
func _separate() -> void:
	var all: Array = []
	for t in 2:
		all.append_array(players[t])
	for i in all.size():
		var a: Player = all[i]
		if a.in_box or not a.on_rink:
			continue
		for j in range(i + 1, all.size()):
			var b: Player = all[j]
			if b.in_box or not b.on_rink:
				continue
			var d := a.pos - b.pos
			var l := d.length()
			if l < 0.62 and l > 0.001:
				var push := d / l * (0.62 - l) * 6.0
				a.want_vel += push
				b.want_vel -= push


## The carrier's blade holds the ball: the ball is told where, and moves there itself.
func _carry_ball() -> void:
	if ball.carrier != null:
		var c: Player = ball.carrier
		ball.carry(c, c.ball_spot())
	elif ball.held_by != null:
		var g: Player = ball.held_by
		ball.hold(g, Vector3(g.pos.x, 0.7, g.pos.y) + Vector3(g.dir().x, 0, g.dir().y) * 0.3)


# ---------------------------------------------------------------- the ball: control, passes, shots, tackles

## Loose balls: the nearest blade that can reach it takes it, if it is low (507.3: not above the knee) and slow
## enough to control; a fast ball past a blade may be deflected instead.
func _pickups() -> void:
	if ball.carrier != null or ball.held_by != null or ball.in_goal != 0:
		return
	if ball.pos.y > 0.42:
		return
	var now := Time.get_ticks_msec()
	var best: Player = null
	var bd := 1e9
	for t in 2:
		for p: Player in skaters(t):
			if p.act in ["shoot", "pass"] and p.act_t < 0.25:
				continue
			if p == ball.last_player and p.act != "" and possession_time < 0.35:
				continue
			if int(p.get_meta("no_pick_until", 0)) > Engine.get_physics_frames():
				continue
			var d := p.blade_floor().distance_to(ball.floor_pos())
			if d < 0.55 and d < bd:
				bd = d
				best = p
	if best == null:
		return
	var sp := ball.speed()
	# A moving ball gives each player one try at it as it passes (a stick reaches for it once, not every frame); a
	# ball that has all but stopped can be gathered by whoever gets there.
	var key := str(best.get_instance_id())
	if sp > 3.0:
		if ball.tries.has(key):
			return
		ball.tries[key] = now
	var rel := (Vector2(ball.vel.x, ball.vel.z) - best.vel).length()
	var intended: bool = _pass_target == best
	var control := clampf(1.0 - (rel - 4.0) / PICKUP_SPEED, 0.0, 1.0) * (0.7 + best.stat("stick") / 330.0)
	if intended:
		control = maxf(control, 0.85)
	elif ball.last_team != best.team and sp > 6.0:
		control *= 0.6   # cutting out a pass is harder than taking one
	if _rng.randf() < control:
		_take(best)
	elif sp > 4.0 and _rng.randf() < clampf(0.35 - sp / 80.0, 0.05, 0.3):
		# A touch that only deflects it: likelier on a slower ball (a hard shot is past before the stick moves).
		ball.strike(Vector3(ball.vel.x * 0.5 + _rng.randf_range(-2, 2), 0.0, ball.vel.z * 0.5 + _rng.randf_range(-2, 2)), best, best.team, "stick")
		Sfx.play("touch", -10.0)


var _pass_target = null


func _take(p: Player) -> void:
	var prev_team := ball.last_team
	if ball.last_player != null and ball.last_player != p and prev_team == p.team and ball.last_player.role != "G":
		_assist_candidate = ball.last_player
	elif prev_team != p.team:
		_assist_candidate = null
		possession_time = 0.0
		_on_turnover(p.team)
	ball.carrier = p
	ball.last_player = p
	carry_time = 0.0
	ball.last_team = p.team
	ball.last_how = "stick"
	gk_throw_air = false
	_pass_target = null
	_shot_live = {}
	Sfx.play("touch", -9.0)
	if p.team == user_team:
		if p != user_player:
			_set_user(p)
		if prev_team != user_team and prev_team >= 0:
			Game.haptic("steal")


func pass_to(p: Player, q: Player) -> void:
	if ball.carrier != p:
		return
	var lead: Vector2 = q.pos + q.vel * 0.5
	var d := p.pos.distance_to(lead)
	var sp := clampf(6.0 + d * 0.75, 8.0, 18.0) * (0.92 + p.stat("pass") / 900.0)
	var err := (105.0 - p.stat("pass")) / 100.0 * 0.12
	var dir := (lead - p.pos).normalized().rotated(_rng.randf_range(-err, err))
	p.do("pass", 0.32)
	p.want_face = dir.angle()
	team_stats[p.team].passes += 1
	if p.pos.x * attack_dir(p.team) < 0.0 and (lead.x - p.pos.x) * attack_dir(p.team) < 2.0:
		team_stats[p.team].own_passes += 1   # in our own half and not forward: the recycling a coach counts
	ball.release()
	# Struck along the floor; a long pass a little lifted (a "lob" stays under the knee near its end).
	var lift := 0.0 if d < 12.0 else 1.6
	ball.strike(Vector3(dir.x * sp, lift, dir.y * sp), p, p.team, "stick")
	_pass_target = q
	_assist_candidate = p
	Sfx.play("pass", -6.0)


## A shot at aim (a point in the goal's mouth). slap: wound up, harder, less accurate.
func shoot(p: Player, aim: Vector3, slap := false) -> void:
	if ball.carrier != p:
		return
	passive = {"team": p.team, "t": 0.0, "warned": false, "w": 0.0}
	var from := ball.pos
	var to := aim - from
	var flat := Vector2(to.x, to.z)
	var d := flat.length()
	var sp := (22.0 if not slap else 30.0) * (0.75 + p.stat("shot") / 300.0) * _rng.randf_range(0.92, 1.06)
	# The lift that brings it to the aimed height at the goal line, against gravity (drag ignored for the aim: the
	# real ball slows and so dips a little: shots aimed high come in lower, as they do).
	var tt := d / sp
	var vy := (aim.y - from.y) / tt + 0.5 * Ball.G * tt
	var v := Vector3(flat.x / d * sp, vy, flat.y / d * sp)
	p.do("shoot", 0.42 if not slap else 0.6)
	p.want_face = flat.angle()
	ball.release()
	ball.strike(v, p, p.team, "stick")
	team_stats[p.team].shots += 1
	_shot_live = {"by": p, "team": p.team, "decided": false, "speed": sp, "slap": slap, "aim": aim}
	Sfx.play("shot", -2.0 if slap else -4.0)
	Sfx.voice("hup", -14.0)
	if p.team == user_team and p == user_player:
		Game.haptic("shot")


## A tackle: def's stick goes for the ball. It is won, missed, or a foul: hitting or hooking the stick (507.1), from
## behind more often; now and then a trip or slash, a minor bench penalty (605).
func tackle(def: Player, car: Player) -> void:
	if def.act != "":
		return
	def.do("tackle", 0.35)
	def.want_face = (ball.floor_pos() - def.pos).angle()
	var reach := def.blade_floor().distance_to(ball.floor_pos())
	if reach > 1.15:
		return
	var behind: float = clampf(car.dir().dot((car.pos - def.pos).normalized()), 0.0, 1.0)   # 1: straight from behind
	var skill: float = (def.stat("defence") - car.stat("stick")) / 160.0
	var win := clampf(0.36 + skill - behind * 0.25, 0.08, 0.75)
	var foul := clampf(0.012 + behind * 0.06 - def.stat("defence") / 5000.0, 0.004, 0.12)
	if ai[def.team].level < 1.0 and def.team != user_team:
		foul *= 0.8
	var r := _rng.randf()
	Sfx.play("clack", -7.0)
	if r < win:
		# Won cleanly: the stick lifts the carrier's and the ball comes away on the tackler's blade; the player who
		# lost it cannot take it straight back (half a second).
		ball.release()
		car.set_meta("no_pick_until", Engine.get_physics_frames() + 30)
		_take(def)
	elif r < win + foul:
		var kind: String = ["stick_hit", "hook", "stick_hit", "hook", "between_legs", "trip", "slash", "hold"][_rng.randi_range(0, 7) if behind > 0.4 else _rng.randi_range(0, 4)]
		offence(def, car, kind)


## An offence by p against victim. The referees play advantage when the fouled team keeps the ball; otherwise the
## whistle, the consequence and, for a penalty, the penalty.
func offence(p: Player, victim: Player, kind: String, dangerous := false) -> void:
	var sanction := Rules.sanction(kind, dangerous)
	var at := ball.floor_pos() if victim == null else victim.pos
	if p.team == user_team and p == user_player:
		Game.haptic("foul")
	var fouled := 1 - p.team
	var keeps: bool = ball.carrier != null and ball.carrier.team == fouled
	if keeps and advantage.is_empty():
		# 602 and the advantage rule: play on while they have it; a penalty waits with the arm up.
		advantage = {"team": fouled, "offence": kind, "at": at, "sanction": sanction, "offender": p, "left": ADVANTAGE_S}
		_ref_signal("delayed" if sanction != "free_hit" else "advantage", Vector2(attack_dir(fouled), 0))
		if hud:
			hud.call_card(tr("CALL_ADVANTAGE") if sanction == "free_hit" else tr("CALL_DELAYED"), _offence_line(kind), fouled)
		return
	_whistle_offence(p, kind, sanction, at, victim)


func _whistle_offence(p: Player, kind: String, sanction: String, at: Vector2, victim: Player = null) -> void:
	var fouled := 1 - p.team
	var line := _offence_line(kind)
	if sanction != "free_hit":
		_penalise(p, sanction, kind)
	if victim and _clear_chance(victim, p):
		_award_penalty_shot(victim, kind)
		return
	_stop("free_hit", {"team": fouled, "spot": Rules.free_hit_spot(at), "why": kind, "sanction": sanction, "line": line})


## A clear chance of a goal (the penalty shot's condition, chapter 8): the fouled player near the goal he attacks, in
## front of it, with no defender but the goalkeeper between him and it.
func _clear_chance(v: Player, offender: Player) -> bool:
	var a := attack_dir(v.team)
	var g := Vector2(Rules.GOAL_LINE * a, 0)
	if v.pos.x * a < 4.0 or v.pos.distance_to(g) > 12.0 or absf(v.pos.y) > 6.0:
		return false
	for o: Player in skaters(1 - v.team):
		if o == offender:
			continue
		if (o.pos - v.pos).dot(g - v.pos) > 0.0 and o.pos.distance_to(g) < v.pos.distance_to(g):
			return false
	return true


## The referee points to the centre spot and crosses his arms: a penalty shot by the fouled player, the game clock
## stopped (2026). A 2-minute penalty for the same offence ends if it scores (the goal ends it, as a power-play goal).
func _award_penalty_shot(v: Player, why: String) -> void:
	ball.live = false
	ball.release()
	_shot_live = {}
	_ref_signal("penalty_shot", Vector2.ZERO)
	_whistle("short", -2.0)
	calls.append({"kind": "penalty_shot", "team": v.team, "why": why, "period": rules.period, "t": rules.clock})
	rules.log.append({"kind": "penalty_shot", "team": v.team, "id": String(v.data.id), "period": rules.period, "t": rules.clock})
	if hud:
		hud.call_card(tr("SIGN_PENALTY_SHOT"), _offence_line(why), v.team)
	_so = {"stage": "setup", "t": 0.0, "in_match": true, "team": v.team, "dir": attack_dir(v.team), "pick": v}
	_set_phase("shootout")


func _offence_line(kind: String) -> String:
	return "%s (%s)" % [tr("OFF_" + kind.to_upper()), Rules.offence_rule(kind)]


## A bench penalty on p's team. A goalkeeper's minor or match penalty is served by an outfield player; he sits his own
## major and personal penalties, and the reserve goalkeeper comes on (603). The player goes to the penalty bench; his
## team plays one fewer while it runs.
func _penalise(p: Player, kind: String, why: String) -> void:
	var server := p
	if p.role == "G" and kind in ["pen2", "match"]:
		server = skaters(p.team)[0] if not skaters(p.team).is_empty() else p
	rules.add_penalty(p.team, String(p.data.id), kind, why, String(server.data.id))
	var mins = {"pen2": 2, "pen5": 5, "pen10": 12, "match": 25}.get(kind, 2)
	stats[p.data.id].pim += int(mins)
	calls.append({"kind": kind, "team": p.team, "id": p.data.id, "why": why, "period": rules.period, "t": rules.clock})
	_ref_signal(kind, Vector2.ZERO)
	_update_boxes()
	if hud and user_team >= 0:
		hud.coach("TIP_PENALTY")


## Who sits in the penalty bench now, from the rules' list. A penalised player on the rink is replaced in his place by
## a team-mate from the bench (he sits out his time); then the team has as many places filled as its strength: short,
## the wingers step off first, so a team a man down plays the centre and both defenders and a forward.
func _update_boxes() -> void:
	_send_to_box()
	for t in 2:
		var boxed: Array = rules.in_box(t)
		var gk: Player = players[t][0]
		if String(gk.data.id) in boxed:
			for d in squads[t]:
				if d.role == "G" and not (String(d.id) in boxed):
					gk.become(_kit(d, t))
					break
		for i in range(1, players[t].size()):
			var p: Player = players[t][i]
			if String(p.data.id) in boxed:
				var bench := _bench_player(t, boxed)
				if not bench.is_empty():
					p.become(_kit(bench, t))
		var n := rules.strength(t)
		var keep := [1, 4, 5, 2, 3]   # the centre, the defenders, then the left and right forwards
		for k in keep.size():
			var p: Player = players[t][keep[k]]
			var was := p.in_box
			p.in_box = k >= n
			if was and not p.in_box:
				# Back on from the penalty bench, on the near side by the centre line (105).
				p.respawn(Vector2(2.2 * (-1.0 if t == 0 else 1.0), Rules.HALF_W - 0.6))
			p.visible = not p.in_box
			if p.in_box and ball.carrier == p:
				ball.release()
			if p.in_box and p == user_player:
				_set_user(null)


## The referees' shirts: black, as in the Nordic leagues; yellow when either team plays in a dark shirt (they must
## stand out from both).
func _referee_shirt() -> String:
	for k: Array in kits:
		if (k[0] as Color).get_luminance() < 0.3:
			return "f2d21b"
	return "1c1e22"


func _kit(d: Dictionary, t: int) -> Dictionary:
	var dd := d.duplicate()
	dd.kit = kits[t]
	return dd


## A player from the bench not on the rink and not penalised, for a place on the rink.
func _bench_player(t: int, boxed: Array) -> Dictionary:
	var on_ids := []
	for i in range(1, players[t].size()):
		on_ids.append(String(players[t][i].data.id))
	for p in squads[t]:
		if p.role != "G" and not (String(p.id) in on_ids) and not (String(p.id) in boxed):
			return p
	return {}


## A line change: the place p held is taken by line l's player of the same slot.
func change_player(p: Player, l: int) -> void:
	var line := _line(p.team, l)
	if p.slot < line.size():
		var nd: Dictionary = line[p.slot]
		if String(nd.id) in rules.in_box(p.team):
			return
		var was_user: bool = p == user_player
		p.become(_kit(nd, p.team))
		p.stamina = 1.0
		if was_user:
			_set_user(p)


func _on_turnover(new_team: int) -> void:
	if not advantage.is_empty() and new_team != int(advantage.team):
		# The offending team has the ball: the delayed call is whistled now (602).
		var adv := advantage
		advantage = {}
		_whistle_offence(adv.offender, String(adv.offence), String(adv.sanction), adv.at)


## 507.20, passive play: a team keeping the ball without trying to attack is warned (the referee's arm held up),
## then gives a free-hit to the other team if it has not shot within PASSIVE_WARN_S. Time in front of the
## opponents' goal resets the count before a warning, building in their half holds it, and in its own end or behind
## their goal it runs. Only a shot (or
## losing the ball) ends a warning.
func _passive_tick(dt: float) -> void:
	var t: int = ball.carrier.team if ball.carrier else (ball.held_by.team if ball.held_by else ball.last_team)
	if t < 0:
		return
	if t != int(passive.team):
		passive = {"team": t, "t": 0.0, "warned": false, "w": 0.0}
		return
	# An attack: the ball in front of their goal in their end. Behind their goal, or back in our own end, is not one.
	var x := ball.floor_pos().x * attack_dir(t)
	if x > 6.0 and x < Rules.GOAL_LINE and not bool(passive.warned):
		passive.t = 0.0
		return
	if x > 0.0 and x < Rules.GOAL_LINE and not bool(passive.warned):
		return   # past the centre line, building: the count waits
	passive.t = float(passive.t) + dt
	if not bool(passive.warned):
		if float(passive.t) > PASSIVE_S:
			passive.warned = true
			calls.append({"kind": "passive", "team": t, "period": rules.period, "t": rules.clock})
			passive.w = 0.0
			_ref_signal("passive", Vector2(attack_dir(t), 0))
			if hud:
				hud.call_card(tr("CALL_PASSIVE"), tr("PASSIVE_LINE"), -1)
		return
	passive.w = float(passive.w) + dt
	if float(passive.w) > PASSIVE_WARN_S:
		var at := ball.floor_pos()
		calls.append({"kind": "free_hit", "team": 1 - t, "why": "delay", "period": rules.period, "t": rules.clock})
		_stop("free_hit", {"team": 1 - t, "spot": Rules.free_hit_spot(at), "why": "delay", "sanction": "free_hit", "line": _offence_line("delay")})


func _advantage_tick(dt: float) -> void:
	if advantage.is_empty():
		return
	if String(advantage.sanction) == "free_hit":
		advantage.left = float(advantage.left) - dt
		if float(advantage.left) <= 0.0:
			advantage = {}   # advantage played: the free-hit is gone
	elif ball.carrier == null and ball.last_team != int(advantage.team) and ball.last_team >= 0:
		_on_turnover(ball.last_team)


# ---------------------------------------------------------------- the goalkeeper

## A shot on its way: the goalkeeper of the goal it is heading for reads it once, as it crosses into the goalkeeper
## area's depth: a catch, a save that spills, or beaten.
func _check_shot() -> void:
	if _shot_live.is_empty() or bool(_shot_live.decided) or ball.carrier != null:
		return
	var t: int = int(_shot_live.team)
	var gk := keeper(1 - t)
	var a := attack_dir(t)
	var gx := Rules.GOAL_LINE * a
	var bx := ball.pos.x * a
	if ball.vel.x * a <= 0.5:
		_shot_live = {}
		return
	# Blocked by a defender on the way (a field player stands in the lane; lying down to block would be a penalty).
	for o: Player in skaters(1 - t):
		var bk := "block" + str(o.get_instance_id())
		if o.pos.distance_to(ball.floor_pos()) < 0.32 and ball.pos.y < 0.9 and not ball.tries.has(bk):
			ball.tries[bk] = true
			if _rng.randf() >= 0.45:
				continue
			ball.strike(Vector3(-ball.vel.x * 0.25 + _rng.randf_range(-3, 3), 0.8, _rng.randf_range(-4, 4)), o, o.team, "deflect_defender")
			team_stats[1 - t].blocked += 1
			_shot_live = {}
			Sfx.play("save", -8.0)
			return
	if bx < Rules.GOAL_LINE - 1.6:
		return
	_shot_live.decided = true
	# Where it crosses the goal line.
	var tt := (gx - ball.pos.x) / ball.vel.x
	var cross := ball.pos + ball.vel * tt
	cross.y = ball.pos.y + ball.vel.y * tt - 0.5 * Ball.G * tt * tt
	var on_target := absf(cross.z) < Rules.GOAL_W * 0.5 - Ball.R and cross.y < Rules.GOAL_H - Ball.R and cross.y > 0.0
	if not on_target:
		return
	if pulled[1 - t] or not gk.on_rink:
		_shot_live.outcome = "goal"   # the net is empty
		return
	# The save: harder far from his body, high in a corner, fast, and through bodies in front (a screen).
	var reach := Vector2(cross.z - gk.pos.y, cross.y - 0.45).length()
	var screen := 0.0
	for o: Player in skaters(t):
		if absf(o.pos.x - gx) < 4.0 and absf(o.pos.y - ball.pos.z) < 1.0:
			screen += 0.12
	var sp: float = float(_shot_live.speed)
	var save := clampf(1.01 - reach * 0.3 - (sp - 20.0) * 0.007 - screen + (gk.stat("reflex") - 70.0) / 160.0, 0.35, 0.95)
	if _shot_live.has("forced"):
		# Your penalty shot (_breakaway_shot): saved or not was settled by where the goalkeeper was and how fast he
		# could get across to it.
		save = 1.0 if String(_shot_live.forced) == "save" else 0.0
	if gk.team != user_team and user_team >= 0:
		save *= [0.9, 0.97, 1.0, 1.04][clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, 3)]
	if _rng.randf() < save:
		_shot_live.outcome = "save"
		var catch_it := reach < 0.45 and sp < 26.0 and _rng.randf() < 0.55
		var low := cross.y < 0.45
		gk.do("save_low" if low else ("save_high_l" if cross.z * a > gk.pos.y * a else "save_high_r"), 0.55)
		# A shot on goal is one the goalkeeper saves or one that scores (counted with the goal, _goal()).
		stats[gk.data.id].saves += 1
		stats[gk.data.id].sa += 1
		team_stats[t].sog += 1
		stats[_shot_live.by.data.id].sog += 1
		get_tree().create_timer(maxf(0.02, tt * 0.9) / speed_k).timeout.connect(func(): _keeper_stops(gk, catch_it))
	else:
		_shot_live.outcome = "goal"
		gk.do("save_low" if cross.y < 0.5 else ("save_high_l" if _rng.randf() < 0.5 else "save_high_r"), 0.55)


func _keeper_stops(gk: Player, catch_it: bool) -> void:
	if phase != "live" or ball.carrier != null or ball.in_goal != 0:
		return
	if gk.pos.distance_to(ball.floor_pos()) > 2.2:
		return
	Sfx.play("save", -4.0)
	if gk.team == user_team:
		Game.haptic("save")
	if catch_it:
		ball.hold(gk, Vector3(gk.pos.x, 0.7, gk.pos.y))
		ball.last_player = gk
		ball.last_team = gk.team
		gk.do("catch", 0.4)
		gk_hold = 0.0
		possession_time = 0.0
		_on_turnover(gk.team)
	else:
		# Spilled: off the pads to the side, a rebound.
		var a := attack_dir(gk.team)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		ball.strike(Vector3(a * _rng.randf_range(2.0, 5.0), 0.3, side * _rng.randf_range(2.5, 6.0)), gk, gk.team, "body")
	_shot_live = {}
	Sfx.react("ooh", -10.0)


## The goalkeeper's body is in the way: a loose ball, a pass across the goal mouth or a shot he has read as saved
## that reaches him stops on him (in the crease he may use his hands, 303): slow, he catches it; fast, it spills.
func _keeper_block() -> void:
	if ball.carrier != null or ball.held_by != null or ball.in_goal != 0:
		return
	if not _shot_live.is_empty() and String(_shot_live.get("outcome", "")) == "goal":
		return
	for t in 2:
		var gk := keeper(t)
		if not gk.on_rink:
			continue
		var b := ball.floor_pos()
		if not Rules.in_goal_crease(b, int(signf(gk.pos.x)) if gk.pos.x != 0.0 else 1):
			continue
		var reach := 0.62 if gk.act in ["kneel", "save_low"] else 0.45
		if ball.pos.y > 1.3 or gk.pos.distance_to(b) > reach:
			continue
		if ball.last_player == gk and ball.speed() < 3.0:
			continue
		if ball.speed() < 7.0:
			ball.hold(gk, Vector3(gk.pos.x, 0.7, gk.pos.y))
			ball.last_player = gk
			ball.last_team = gk.team
			gk.do("catch", 0.35)
			gk_hold = 0.0
			if ball.last_team != t:
				possession_time = 0.0
			_on_turnover(gk.team)
		else:
			var a := attack_dir(gk.team)
			ball.strike(Vector3(a * randf_range(1.5, 4.0), 0.25, randf_range(-5.0, 5.0)), gk, gk.team, "body")
			Sfx.play("save", -6.0)
		_shot_live = {}
		return


## The goalkeeper holds a caught ball at most 3 seconds (507.16), then throws it out to a free team-mate, along the
## floor or bounced short of the centre line (507.15: a throw over the centre line must touch something first).
func _keeper_hold(dt: float) -> void:
	if ball.held_by == null:
		return
	var gk: Player = ball.held_by
	gk_hold += dt
	var lazy = ai[gk.team].level < 0.85 and _rng.randf() < 0.004
	var when := 1.4 if not lazy else 3.4
	if gk_hold > Rules.GK_HOLD_S:
		# Held too long: a free-hit to the other team (from the nearest face-off dot on the goal line's extension).
		ball.held_by = null
		_stop("free_hit", {"team": 1 - gk.team, "spot": Rules.free_hit_spot(gk.pos), "why": "gk_hold", "sanction": "free_hit", "line": _offence_line("gk_hold")})
		return
	if gk_hold < when:
		return
	var best: Player = null
	var bs := -1e9
	for q: Player in skaters(gk.team):
		var s := pass_lane_open(gk.pos, q.pos, gk.team) * 2.0 - q.pos.distance_to(gk.pos) / 20.0
		if s > bs:
			bs = s
			best = q
	if best == null:
		return
	var to := best.pos + best.vel * 0.4 - gk.pos
	var d := to.length()
	var sp := clampf(7.0 + d * 0.5, 8.0, 15.0)
	gk.do("throw", 0.45)
	ball.held_by = null
	ball.strike(Vector3(to.x / d * sp, 0.6, to.y / d * sp), gk, gk.team, "gk_throw")
	gk_throw_air = true
	_pass_target = best
	gk_hold = 0.0


# ---------------------------------------------------------------- the ball out, goals

func _on_out(exit: Vector2) -> void:
	if phase != "live":
		return
	_stop("hit_in", {"team": 1 - ball.last_team if ball.last_team >= 0 else 0, "spot": Rules.hit_in_spot(exit), "why": "out"})


func _on_ball_hit(what: String, sp: float) -> void:
	if what == "floor" or what == "board":
		gk_throw_air = false
	match what:
		"board":
			Sfx.play("board", linear_to_db(clampf(sp / 12.0, 0.1, 1.0)) - 4.0)
		"post":
			Sfx.play("post", -3.0)
			Sfx.react("ooh", -8.0)
		"net":
			Sfx.play("net", -6.0)


func _on_goal_line(end: int, from_front: bool) -> void:
	if phase != "live":
		return
	var scoring := 0 if attack_dir(0) * end > 0.0 else 1
	var defending := 1 - scoring
	var info := {"last_team": ball.last_team, "defending_team": defending, "how": ball.last_how, "from_front": from_front,
		"deliberate": ball.last_how in ["kick", "head", "hand"], "too_many": false, "attack_offence": false, "clock_done": rules.remaining() <= 0.0}
	var j := Rules.judge_goal(info)
	if not bool(j.ok):
		_stop("free_hit" if String(ball.last_how) in ["kick", "head", "hand"] else "faceoff", {"team": defending, "spot": Rules.free_hit_spot(Vector2(end * 12.0, 0)), "why": "no_goal", "line": tr("CALL_NO_GOAL") + " (" + String(j.reason) + ")"})
		return
	_goal(scoring, bool(j.get("own_goal", false)))


func _goal(t: int, own: bool) -> void:
	var scorer: Player = ball.last_player if not own and ball.last_player != null and ball.last_player.team == t else null
	var assist: Player = _assist_candidate if scorer and _assist_candidate and _assist_candidate != scorer and _assist_candidate.team == t else null
	var o := 1 - t
	var pp := rules.strength(o) < rules.strength(t)
	# A delayed minor against the team that conceded is cancelled by the goal; anything bigger is still given (602).
	if not advantage.is_empty() and int(advantage.team) == t:
		var adv := advantage
		advantage = {}
		if String(adv.sanction) not in ["free_hit", "pen2"]:
			_penalise(adv.offender, String(adv.sanction), String(adv.offence))
	rules.goal(t, {"scorer": String(scorer.data.id) if scorer else "", "assist": String(assist.data.id) if assist else "", "own": own})
	_goal_scorer = scorer
	_goal_clock = FoundationLink.clock()
	if scorer:
		stats[scorer.data.id].g += 1
		stats[scorer.data.id].sog += 1
	if not own:
		team_stats[t].sog += 1
		if not pulled[o]:
			stats[keeper(o).data.id].sa += 1
	if assist:
		stats[assist.data.id].a += 1
	if pp:
		team_stats[t].ppg += 1
	_update_boxes()
	_shot_live = {}
	_set_phase("goal")
	if hud and user_team >= 0:
		hud.coach("TIP_GOAL")
	_whistle("long", -3.0)
	Sfx.play("horn", -8.0)
	Sfx.play("roar", -4.0)
	Sfx.react("cheer", -2.0)
	Crowd.set_excite(1.0)
	arena.goal_lights(int(signf(attack_dir(t))))
	_ref_signal("goal", Vector2(-ball.pos.x, -ball.pos.z).normalized())
	if user_team >= 0:
		Game.haptic("goal" if t == user_team else "conceded")
	if hud:
		var who := ("#%d %s" % [int(scorer.data.num), String(scorer.data.name)]) if scorer else tr("OWN_GOAL")
		if assist:
			who += " · " + tr("ASSIST_SHORT") + " #%d" % int(assist.data.num)
		hud.goal_banner(t, who, pp)
	if rules.phase == "done":
		get_tree().create_timer(GOAL_S / speed_k).timeout.connect(_finish)


func _celebrate() -> void:
	var t = rules.log.back().team if not rules.log.is_empty() and String(rules.log.back().kind) == "goal" else 0
	var scorer: Player = _goal_scorer if _goal_scorer != null and is_instance_valid(_goal_scorer) and _goal_scorer.team == t else null
	for p: Player in skaters(t):
		if p.act == "":
			p.do("celebrate", 1.2)
		var to: Vector2
		if scorer == null:
			to = ball.floor_pos() * 0.5 - p.pos
		elif p == scorer:
			# The scorer wheels away toward the boards on his side, arms up...
			to = Vector2(p.pos.x * 0.85, signf(p.pos.y if p.pos.y != 0.0 else 1.0) * 7.5) - p.pos
		else:
			# ... and his team-mates run to him and pile round him (as the league's players do), a step apart.
			var at := scorer.pos - p.pos
			to = at - at.normalized() * 0.9 if at.length() > 0.9 else Vector2.ZERO
		p.want_vel = to.normalized() * minf(4.5 if p != scorer else 3.0, to.length() * 2.0) if to.length() > 0.05 else Vector2.ZERO
	for p: Player in skaters(1 - t):
		p.want_vel = Vector2.ZERO


func _after_goal() -> void:
	Crowd.set_excite(0.0)
	if rules.phase == "done":
		return
	if wsg_replay and _start_replay():
		return
	_begin_restart({"kind": "faceoff", "spot": Vector2.ZERO})


# ---------------------------------------------------------------- the goal's replay

const REPLAY_BEFORE := 4.2      # s of play before the goal shown again
const REPLAY_AFTER := 0.8
const REPLAY_RATE := 0.6        # slowed


## After the celebration: the last seconds before the goal again, slowed, from a camera on the goal line beside the
## goal, the shared foundation's bodies as they were drawn (WsgReplay) and the ball where it was. A tap skips it.
## False when there is nothing kept to show.
func _start_replay() -> bool:
	var t0 := _goal_clock - REPLAY_BEFORE
	var span := wsg_replay.span()
	if span.is_empty() or float(span[0]) > t0 + 1.5 or _ball_ring.is_empty():
		return false
	t0 = maxf(t0, float(span[0]))
	var end := signf(ball.position.x) if absf(ball.position.x) > 1.0 else 1.0
	var rc := Camera3D.new()
	rc.fov = 38.0
	add_child(rc)
	# On the goal line's extension, toward the boards, up a little: the shot comes toward the camera's side of the goal.
	var side := 1.0 if _ring_at(t0).z >= 0.0 else -1.0
	rc.global_position = Vector3(end * (Rules.GOAL_LINE + 0.6), 2.3, side * 5.2)
	rc.look_at(Vector3(end * (Rules.GOAL_LINE - 6.0), 0.4, 0.0))
	rc.make_current()
	_replay = {"t": t0, "t1": _goal_clock + REPLAY_AFTER, "cam": rc, "ball_at": ball.position, "look": _ring_at(t0),
		"hud": hud.visible if hud else false, "marker": user_player.marker.visible if user_player and user_player.marker else false,
		"halo": ball._halo.visible if ball._halo else false}
	if hud:
		hud.visible = false
	if user_player and user_player.marker:
		user_player.marker.visible = false
	wsg_replay.play(t0, float(_replay.t1))
	FoundationLink.replay_at = t0
	_set_phase("replay")
	_replay_step(0.0)
	return true


func _ring_at(t: float) -> Vector3:
	var i := 0
	while i < _ball_ring.size() - 1 and float(_ball_ring[i + 1][0]) <= t:
		i += 1
	var a: Array = _ball_ring[i]
	var b: Array = _ball_ring[mini(i + 1, _ball_ring.size() - 1)]
	var w := 0.0 if a == b else clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	return (a[1] as Vector3).lerp(b[1], w)


func _replay_step(delta: float) -> void:
	var t: float = float(_replay.t) + delta * REPLAY_RATE
	_replay.t = t
	if t >= float(_replay.t1):
		_end_replay()
		return
	FoundationLink.replay_at = t
	wsg_replay.seek(t)
	var b := _ring_at(t)
	ball.position = b
	if ball._shadow:
		ball._shadow.global_position = Vector3(b.x, 0.004, b.z)
	for n: Node3D in [ball._halo, ball._streak]:
		if n:
			n.visible = false
	# The camera stays put and follows the ball, smoothly.
	_replay.look = (_replay.look as Vector3).lerp(b, minf(1.0, delta * 4.0)) if delta > 0.0 else b
	var rc: Camera3D = _replay.cam
	rc.look_at((_replay.look as Vector3) * Vector3(1.0, 0.0, 1.0) + Vector3(0, 0.5, 0))


func _end_replay() -> void:
	if _replay.is_empty():
		return
	FoundationLink.replay_at = INF
	wsg_replay.stop()
	ball.position = _replay.ball_at
	if ball._halo:
		ball._halo.visible = bool(_replay.halo)
	(_replay.cam as Camera3D).queue_free()
	cam.make_current()
	if hud:
		hud.visible = bool(_replay.hud)
	if user_player and user_player.marker:
		user_player.marker.visible = bool(_replay.marker)
	_replay = {}
	_begin_restart({"kind": "faceoff", "spot": Vector2.ZERO})


## A tap (or a key) skips the replay.
func _input(event: InputEvent) -> void:
	if phase != "replay" or paused:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		_end_replay()


# ---------------------------------------------------------------- stoppages and restarts

func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	if p in ["goal", "interval", "over", "shootout"]:
		for t in 2:
			_restore_keeper(t)


# ---------------------------------------------------------------- the empty net

## A team a goal or two down late in the last period pulls its goalkeeper for a sixth outfield player, as any
## substitution (302): he skates off in his team's substitution zone and the extra player comes on there. He is
## back after a goal, at the end of the period, or when the team is no longer behind (at the next stoppage).
func _empty_net() -> void:
	if demo and bool(config.get("menu", false)):
		return
	for t in 2:
		var gk := keeper(t)
		if not pulled[t]:
			if ai[t].wants_empty_net() and ball.carrier != null and ball.carrier.team == t and ball.held_by == null \
					and ball.floor_pos().x * attack_dir(t) > 0.0 and rules.strength(t) >= rules.strength(1 - t):
				pulled[t] = true
				calls.append({"kind": "empty_net", "team": t, "period": rules.period, "t": rules.clock})
				if hud:
					hud.hint(tr("HINT_EMPTY_NET").format({"team": DB.team_name(String(config.home if t == 0 else config.away))}))
			continue
		if not gk.on_rink:
			continue
		# Off to the bench: the sixth player comes on when he is over the board.
		var zone: Vector2 = sub_zone(t)
		var at := Vector2((zone.x + zone.y) * 0.5, -Rules.HALF_W + 0.35)
		var d := at - gk.pos
		if d.length() > 0.7:
			gk.want_vel = d.normalized() * minf(gk.MAX_SPEED * 0.85, d.length() * 3.0)
			gk.want_face = NAN
			continue
		gk.want_vel = Vector2.ZERO
		gk.on_rink = false
		gk.visible = false
		var six: Player = sixth[t]
		var fresh := _bench_player(t, rules.in_box(t))
		if not fresh.is_empty():
			six.become(_kit(fresh, t))
		six.respawn(at)
		six.on_rink = true
		six.visible = true


## The penalised players seen: one figure each of the first two in the penalty bench walks there from where he was
## (on the near side, at the secretariat, 105) and sits out his time; when it is over he is gone (his team-mate
## comes back on the rink from the bench, _update_boxes()).
func _send_to_box() -> void:
	for t in 2:
		var boxed: Array = rules.in_box(t)
		for k in sitters[t].size():
			var s: Player = sitters[t][k]
			var id: String = boxed[k] if k < boxed.size() else ""
			if String(s.get_meta("sits")) == id:
				continue
			s.set_meta("sits", id)
			if id == "":
				s.visible = false
				continue
			var from := Vector2(0.0, Rules.HALF_W - 1.0)
			for p: Player in players[t]:
				if p.visible and p.on_rink and String(p.data.id) == id and p.slot != 9:
					from = p.pos
			for d in squads[t]:
				if String(d.id) == id:
					s.become(_kit(d, t))
			s.respawn(from)
			s.visible = true


func _box_seat(t: int, k: int) -> Vector2:
	var side := -1.0 if t == 0 else 1.0
	return Vector2(side * (2.6 + k * 0.8), Rules.HALF_W + 0.75)


func _walk_to_box() -> void:
	for t in 2:
		for k in sitters[t].size():
			var s: Player = sitters[t][k]
			s.writes = 0
			if s.visible:
				var seat := _box_seat(t, k)
				# Along the rink to the door, then through it.
				var want := seat if absf(s.pos.x - seat.x) < 0.6 else Vector2(seat.x, Rules.HALF_W - 0.6)
				var d := want - s.pos
				s.want_vel = d.normalized() * minf(3.2, d.length() * 2.0) if d.length() > 0.1 else Vector2.ZERO
				s.want_face = NAN if d.length() > 0.1 else -PI * 0.5
				s.step(get_physics_process_delta_time() * speed_k)


## The goalkeeper back in his goal, the sixth player off.
func _restore_keeper(t: int) -> void:
	if not pulled[t]:
		return
	pulled[t] = false
	var six: Player = sixth[t]
	if ball.carrier == six:
		ball.release()
	if six == user_player:
		_set_user(null)
	six.on_rink = false
	six.visible = false
	var gk := keeper(t)
	if not gk.on_rink:
		gk.respawn(Vector2(-Rules.GOAL_LINE * attack_dir(t) + attack_dir(t) * 0.6, 0.0))
	gk.on_rink = true
	gk.visible = true


## The whistle: kind of restart and its details. The ball is dead until the restart.
func _stop(kind: String, d: Dictionary) -> void:
	if phase != "live":
		return
	ball.live = false
	ball.release()
	_shot_live = {}
	var r := d.duplicate()
	r.kind = kind
	restart = r
	_set_phase("whistle")
	_whistle("short", -2.0)
	passive = {"team": -1, "t": 0.0, "warned": false, "w": 0.0}
	for t in 2:
		# Still behind: the net stays empty (the goalkeeper still on his way off comes back).
		if pulled[t] and (not ai[t].wants_empty_net() or keeper(t).on_rink):
			_restore_keeper(t)
	if hud and user_team >= 0 and int(d.get("team", -1)) != user_team:
		hud.coach("TIP_WHISTLE")
	_ai_timeout()
	if _timeout_team >= 0:
		phase_t = -1.5   # a longer stop: the time-out
		_take_timeout()
	var why := String(d.get("why", ""))
	var dirx := Vector2(attack_dir(int(d.get("team", 0))), 0)
	match kind:
		"free_hit":
			if String(d.get("sanction", "free_hit")) == "free_hit":
				_ref_signal("free_hit", dirx)
			calls.append({"kind": "free_hit", "team": int(d.get("team", 0)), "why": why, "period": rules.period, "t": rules.clock})
			if hud:
				var title := tr("CALL_FREE_HIT") if String(d.get("sanction", "free_hit")) == "free_hit" else tr("CALL_" + String(d.sanction).to_upper())
				hud.call_card(title, String(d.get("line", "")), int(d.get("team", 0)))
		"hit_in":
			_ref_signal("hit_in", dirx)
			if hud:
				hud.call_card(tr("CALL_HIT_IN"), tr("CALL_OUT_LINE"), int(d.get("team", 0)))
		"faceoff":
			_ref_signal("face_off", Vector2.ZERO)
			if hud:
				hud.call_card(tr("CALL_FACE_OFF"), String(d.get("line", "")), -1)


func _setup_restart() -> void:
	_begin_restart(restart)


## Set a restart up: the ball on its spot, the players walking to their places (opponents 3 m off), then the whistle
## for a face-off, or the taker's hit.
func _begin_restart(r: Dictionary) -> void:
	restart = r
	var spot: Vector2 = r.spot
	ball.set_spot(spot)
	ball.live = false
	_set_phase("setup")
	advantage = {} if String(r.kind) != "faceoff" else advantage
	if String(r.kind) == "faceoff":
		_place_for_faceoff(spot, false)
	else:
		_place_for_hit(r)


func _place_for_faceoff(spot: Vector2, now: bool) -> void:
	# 501: the two centres face each other at the dot, feet square to the centre line, each on his own side; everyone
	# else 3 m away. At the centre spot, each team in its own half.
	for t in 2:
		var a := attack_dir(t)
		for i in range(1, players[t].size()):
			var p: Player = players[t][i]
			var want: Vector2
			match int(p.slot):
				0:
					want = spot + Vector2(-a * 0.55, 0)
				1, 2:
					var s := (-1.0 if p.slot == 1 else 1.0) * a
					want = spot + Vector2(-a * 3.2, s * 3.6)
				_:
					var s := (-1.0 if p.slot == 3 else 1.0) * a
					want = spot + Vector2(-a * 7.5, s * 3.0)
			want = Vector2(clampf(want.x, -18.5, 18.5), clampf(want.y, -9.2, 9.2))
			want = TeamAI._keep_out_of_gk_area(want)
			p.set_meta("spot", want)
			p.set_meta("face", 0.0 if a > 0 else PI)
			if now:
				p.pos = want
				p.facing = p.get_meta("face")
		var gk := keeper(t)
		var gp := Vector2(-Rules.GOAL_LINE * a + a * 0.6, 0) if not pulled[t] else gk.pos
		gk.set_meta("spot", gp)
		gk.set_meta("face", 0.0 if a > 0 else PI)
		if now:
			gk.pos = gp
			gk.facing = gk.get_meta("face")


func _place_for_hit(r: Dictionary) -> void:
	var t: int = int(r.team)
	var spot: Vector2 = r.spot
	var a := attack_dir(t)
	# The taker: the nearest of the team to the spot, behind the ball facing up the rink.
	var taker: Player = null
	var bd := 1e9
	for p: Player in skaters(t):
		var d := p.pos.distance_to(spot)
		if d < bd:
			bd = d
			taker = p
	restart.taker = taker
	for tt in 2:
		var at := attack_dir(tt)
		for p: Player in skaters(tt):
			var want: Vector2
			if p == taker:
				want = spot - Vector2(a * 0.75, 0)
				p.set_meta("face", 0.0 if a > 0 else PI)
			else:
				var shape: Vector2 = ai[tt]._support(p, spot, taker) if tt == t else ai[tt]._shape_defence(p, spot)
				want = shape
				if tt != t and want.distance_to(spot) < Rules.DISTANCE + 0.3:
					# 506: 3 m from the ball, sticks included.
					want = spot + (want - spot).normalized() * (Rules.DISTANCE + 0.6) if want.distance_to(spot) > 0.1 else spot - Vector2(at * (Rules.DISTANCE + 0.6), 0)
				p.set_meta("face", (spot - want).angle())
			want = Vector2(clampf(want.x, -18.8, 18.8), clampf(want.y, -9.3, 9.3))
			p.set_meta("spot", TeamAI._keep_out_of_gk_area(want))
		var gk := keeper(tt)
		gk.set_meta("spot", Vector2(-Rules.GOAL_LINE * at + at * 0.6, clampf(spot.y * 0.05, -0.5, 0.5)) if not pulled[tt] else gk.pos)
		gk.set_meta("face", 0.0 if at > 0 else PI)
	if taker and taker.team == user_team:
		_set_user(taker)
		if touch:
			touch.set_buttons(["SHOOT", "PASS", "SPRINT"])


func _setup(dt: float) -> void:
	var ready := true
	for t in 2:
		for p: Player in players[t]:
			if p.in_box:
				continue
			var want: Vector2 = p.get_meta("spot", p.pos)
			var d := want - p.pos
			var urgent := phase_t > SETUP_MAX_S * 0.6
			if d.length() > 0.12:
				p.want_vel = d.normalized() * minf(6.5 if urgent else 4.5, d.length() * 2.5)
				p.want_face = NAN if d.length() > 1.0 else float(p.get_meta("face", p.facing))
				if d.length() > 0.6:
					ready = false
			else:
				p.want_vel = Vector2.ZERO
				p.want_face = float(p.get_meta("face", p.facing))
	_step_all(dt)
	if phase_t < 0.8:
		return
	if not ready and phase_t < SETUP_MAX_S:
		return
	match String(restart.kind):
		"faceoff":
			_faceoff()
		"free_hit", "hit_in":
			var taker: Player = restart.get("taker")
			if taker == null:
				_resume()
				return
			if taker.team == user_team and taker == user_player and not demo:
				if touch:
					touch.set_buttons(["SHOOT", "PASS", "SPRINT"])
				if hud:
					hud.hint(tr("HINT_RESTART"))
					hud.coach("TIP_RESTART")
				# You take it: PASS or SHOOT (it must be a hit: 504, 506), without delay: a fixed situation kept waiting
				# goes to the other team (507.20). A warning first.
				if phase_t > RESTART_DELAY_S - 3.0 and not restart.get("warned", false):
					restart.warned = true
					if hud:
						hud.hint(tr("HINT_DELAY"))
				if phase_t > RESTART_DELAY_S:
					_delay_of_game(taker)
				return
			if phase_t > 1.4:
				_take_restart(taker, false)
		"penalty_shot":
			_resume()


func _faceoff() -> void:
	_whistle("long", -4.0)
	# 501: on the whistle; the better stick and quicker hands win it, back to a team-mate.
	var c0: Player = _slot(0, 0)
	var c1: Player = _slot(1, 0)
	var w := 0
	if c0 and c1:
		var k := 0.5 + (c0.stat("stick") - c1.stat("stick")) / 200.0
		w = 0 if _rng.randf() < k else 1
	var winner: Player = c0 if w == 0 else c1
	team_stats[w].fo += 1
	ball.live = true
	_set_phase("live")
	possession_time = 0.0
	if winner:
		var back := Vector2(-attack_dir(w), _rng.randf_range(-0.6, 0.6)).normalized()
		ball.strike(Vector3(back.x * 4.5, 0, back.y * 4.5), winner, w, "stick")
		winner.do("pass", 0.25)


func _slot(t: int, s: int) -> Player:
	for p: Player in skaters(t):
		if int(p.slot) == s:
			return p
	return null


## The taker plays the free-hit or hit-in: a pass, or at goal when it is near enough (a goal may be scored straight
## from either, 504 and 506).
## A free-hit or hit-in kept waiting: the referee gives it to the other team where it was (507.20).
func _delay_of_game(taker: Player) -> void:
	var t := 1 - taker.team
	var spot: Vector2 = restart.spot
	calls.append({"kind": "free_hit", "team": t, "why": "delay", "period": rules.period, "t": rules.clock})
	_ref_signal("free_hit", Vector2(attack_dir(t), 0))
	_whistle("short", -2.0)
	if hud:
		hud.call_card(tr("CALL_FREE_HIT"), _offence_line("delay"), t)
	_begin_restart({"kind": "free_hit", "team": t, "spot": Rules.free_hit_spot(spot), "why": "delay", "sanction": "free_hit", "line": _offence_line("delay")})


func _take_restart(taker: Player, shot: bool) -> void:
	ball.live = true
	ball.carrier = taker
	ball.last_team = taker.team
	ball.last_player = taker
	_set_phase("live")
	possession_time = 0.0
	var g: Vector2 = ai[taker.team].target_goal()
	if shot or (taker.pos.distance_to(g) < 9.0 and _rng.randf() < 0.5 and taker.team != user_team):
		shoot(taker, ai[taker.team]._aim(taker, g), false)
		return
	var best: Player = null
	var bs := -1e9
	for q: Player in skaters(taker.team):
		if q == taker:
			continue
		var s: float = ai[taker.team]._pass_value(taker, q)
		if s > bs:
			bs = s
			best = q
	if best:
		pass_to(taker, best)
	else:
		_resume()


func _resume() -> void:
	ball.live = true
	_set_phase("live")


# ---------------------------------------------------------------- periods, the end

func _period_over() -> void:
	Sfx.play("horn", -2.0)
	if not demo:
		Sfx.react("applause", -4.0)   # the hall applauds the teams off
	ball.live = false
	ball.release()
	ball.held_by = null
	advantage = {}
	var next := rules.end_period()
	_whistle("final" if next == "done" else "hall", -2.0)
	match next:
		"interval":
			_set_phase("interval")
			if hud:
				hud.interval(rules.period - 1)
		"overtime":
			_set_phase("interval")
			if hud:
				hud.interval(-1)
		"shootout":
			_start_shootout()
		"done":
			_set_phase("over")
			get_tree().create_timer(1.8 / speed_k).timeout.connect(_finish)


## From the interval card (or by itself in a match nobody plays): the next period's face-off at the centre.
func _next_period() -> void:
	ai[0].shift = 0.0
	ai[1].shift = 0.0
	_begin_restart({"kind": "faceoff", "spot": Vector2.ZERO})


var _so := {}


## 204: penalty shots after overtime: five different field players a team, alternately at the same goal, then one
## each until it is decided.
func _start_shootout() -> void:
	_set_phase("shootout")
	_so = {"stage": "setup", "t": 0.0, "in_match": false, "dir": 1.0}
	if hud:
		hud.banner(tr("SHOOTOUT"))


func _shootout(dt: float) -> void:
	_so.t = float(_so.t) + dt
	var in_match := bool(_so.get("in_match", false))
	var t := int(_so.team) if in_match else rules.shootout_next()
	var s := float(_so.get("dir", 1.0))     # the goal shot at: the competition's both at +x, a match's the one attacked
	var g := Vector2(Rules.GOAL_LINE * s, 0)
	match String(_so.stage):
		"setup":
			# Everyone off to the far side; the shooter at the centre spot; the goalkeeper on his line.
			var shooter: Player = null
			if in_match:
				var pick: Player = _so.pick
				shooter = pick if pick in skaters(t) else (skaters(t)[0] if not skaters(t).is_empty() else null)
			else:
				for p: Player in skaters(t):
					if rules.may_shoot(t, String(p.data.id), shooters_used[t]) and shooter == null:
						shooter = p
			if shooter == null:
				_bring_shooter(t)
				shooter = skaters(t)[0]
			_so.shooter = shooter
			if touch and shooter.team == user_team and not demo:
				touch.set_buttons(["SHOOT", "DEKE"])
			for tt in 2:
				for p: Player in skaters(tt):
					p.set_meta("spot", Vector2((-8.0 + skaters(tt).find(p) * 1.2 + tt * 8.0) * s, -8.5) if p != shooter else Vector2(-0.6 * s, 0))
				var gk := keeper(tt)
				gk.set_meta("spot", Vector2((Rules.GOAL_LINE - 0.4) * s, 0) if tt != t else Vector2((-12.0 + tt * 1.0) * s, -8.6))
			ball.set_spot(Vector2.ZERO)
			ball.live = true
			_so.stage = "walk"
			_so.t = 0.0
			if hud and not in_match:
				hud.shootout(rules.shootout)
		"walk":
			var ready := true
			for p: Player in players[0] + players[1]:
				var want: Vector2 = p.get_meta("spot", p.pos)
				var d: Vector2 = want - p.pos
				p.want_vel = d.normalized() * minf(5.0, d.length() * 2.5) if d.length() > 0.1 else Vector2.ZERO
				var toward := 0.0 if s > 0.0 else PI
				p.want_face = NAN if d.length() > 0.8 else (toward if p == _so.shooter or p.role == "G" and p.team == t else toward + PI)
				if d.length() > 0.5:
					ready = false
			var gk := keeper(1 - t)
			gk.want_face = PI if s > 0.0 else 0.0
			_step_all(dt)
			if (ready and _so.t > 1.0) or _so.t > 6.0:
				_whistle("long", -4.0)
				_so.stage = "run"
				_so.t = 0.0
				ball.carrier = _so.shooter
				ball.last_team = t
				ball.last_player = _so.shooter
				_so.shot = false
		"run":
			var sh: Player = _so.shooter
			var gk := keeper(1 - t)
			# The ball must keep moving toward the goal (no stopping, no going back): the shooter skates in.
			if sh.team == user_team and not demo:
				_breakaway(sh, gk, s, dt)
			else:
				sh.want_vel = Vector2(6.0 * s, clampf(-sh.pos.y * 0.6 + sin(_so.t * 2.0) * 2.0, -3.0, 3.0))
				_keeper_mirror(gk, s, dt)
			gk.want_face = PI if s > 0.0 else 0.0
			if not bool(_so.shot) and (sh.pos.x * s > 9.5 + _rng.randf() * 3.0 and (sh.team != user_team or demo)):
				_so_shot(sh, g)
			_check_shot()
			_step_all(dt)
			var done = ball.in_goal != 0 or (bool(_so.shot) and (ball.speed() < 1.0 or ball.vel.x * s < 0.0 or ball.held_by != null)) or _so.t > 7.0
			if done and bool(_so.get("practice", false)):
				_so.stage = "end"
				ball.held_by = null
				_practice_shot_done(ball.in_goal != 0)
				return
			if done and in_match:
				_so.stage = "end"
				ball.held_by = null
				if ball.in_goal != 0:
					_set_phase("live")
					_goal(t, false)
				else:
					Sfx.react("groan", -6.0)
					ball.release()
					_begin_restart({"kind": "faceoff", "spot": Rules.nearest_faceoff(Vector2(Rules.GOAL_LINE * s, 1.0))})
				return
			if done:
				var scored := ball.in_goal != 0
				shooters_used[t].append(String(sh.data.id))
				var decided := rules.shootout_shot(t, scored)
				_whistle("short", -4.0)
				if scored:
					Sfx.react("cheer", -4.0)
					Sfx.play("horn", -10.0)
				else:
					Sfx.react("groan", -6.0)
				if hud:
					hud.shootout(rules.shootout)
				ball.release()
				ball.held_by = null
				if decided:
					_so.stage = "end"
					_set_phase("over")
					get_tree().create_timer(2.4 / speed_k).timeout.connect(_finish)
				else:
					_so.stage = "setup"
					_so.t = 0.0


func _so_shot(sh: Player, g: Vector2) -> void:
	_so.shot = true
	shoot(sh, ai[sh.team]._aim(sh, g), false)


func _on_goal_line_so() -> void:
	pass


## The next shooter from the bench: a field player not yet used (the first five must be five different players).
func _bring_shooter(t: int) -> void:
	for p in squads[t]:
		if p.role != "G" and rules.may_shoot(t, String(p.id), shooters_used[t]):
			skaters(t)[0].become(_kit(p, t))
			return


func _finish() -> void:
	if phase == "done_sent":
		return
	phase = "done_sent"
	Sfx.crowd(-1.0)
	var res := result()
	finished.emit(res)
	if not demo and Game.current == self:
		Game.on_match_finished(res)
	elif demo and Game.current == self and config.get("loop", false):
		pass


func result() -> Dictionary:
	var g := rules.final_goals()
	var w := 0 if g[0] > g[1] else (1 if g[1] > g[0] else -1)
	# Player of the match: goals and assists, a goalkeeper's saves.
	var best := ""
	var bv := -1.0
	for id in stats:
		var s: Dictionary = stats[id]
		var v := float(s.g) * 3.0 + float(s.a) * 2.0 + float(s.saves) * 0.35 + float(s.sog) * 0.3 - float(s.pim) * 0.2
		if int(s.team) == w:
			v += 1.0
		if v > bv:
			bv = v
			best = id
	return {"config": config, "goals": g, "winner": w, "user_team": user_team, "log": rules.log, "stats": stats,
		"team_stats": team_stats, "calls": calls, "shootout": rules.shootout, "periods": rules.period, "potm": best,
		"ot": rules.period > Rules.PERIODS, "so": not rules.shootout[0].is_empty()}


# ---------------------------------------------------------------- the officials

## The two referees move up and down the long sides as the play does: one ahead of it on the near side, one behind it
## on the far side, the diagonal system, so between them they see both goals.
func _officials(dt: float) -> void:
	var b := ball.floor_pos()
	var dirx := 1.0
	if ball.last_team >= 0:
		dirx = attack_dir(ball.last_team)
	for i in refs.size():
		var r: Player = refs[i]
		var want: Vector2
		if i == 0:
			want = Vector2(clampf(b.x + dirx * 5.0, -16.5, 16.5), 9.0)
		else:
			want = Vector2(clampf(b.x - dirx * 5.0, -16.5, 16.5), -8.6)
		if phase == "shootout":
			want = Vector2(Rules.GOAL_LINE - 2.0, 8.6) if i == 0 else Vector2(1.0, -8.6)
		var d := want - r.pos
		r.want_vel = d.normalized() * minf(5.5, d.length() * 1.5) if d.length() > 0.4 else Vector2.ZERO
		if r.act.begins_with("signal_"):
			r.want_vel *= 0.2
			r.want_face = (b - r.pos).angle() if not r.act.contains("free_hit") else NAN
		else:
			r.want_face = (b - r.pos).angle()
		r.max_speed = 6.0
		r.writes = 0
		r.step(dt)
	_walk_to_box()


## The nearer referee whistles and shows the sign: the consequence first, then the offence where needed (306).
## The nearer referee's whistle, heard from where he stands. Not in the menu's match (the music plays there).
func _whistle(kind: String, volume_db := 0.0) -> void:
	if demo:
		return
	var b := ball.floor_pos()
	var r: Player = refs[0] if refs[0].pos.distance_to(b) < refs[1].pos.distance_to(b) else refs[1]
	Sfx.whistle(kind, Vector3(r.pos.x, 1.6, r.pos.y), volume_db)


func _ref_signal(kind: String, dir: Vector2) -> void:
	var b := ball.floor_pos()
	var r: Player = refs[0] if refs[0].pos.distance_to(b) < refs[1].pos.distance_to(b) else refs[1]
	r.signal_arm = dir if dir.length() > 0.1 else (b - r.pos).normalized()
	r.facing = r.facing   # the arm is placed relative to how he stands now
	r.do("signal_" + kind, 3.0 if kind in ["delayed", "advantage", "passive"] else 1.8)


# ---------------------------------------------------------------- you

func _set_user(p: Player) -> void:
	if user_player and is_instance_valid(user_player):
		user_player.mark(false)
	user_player = p
	if p:
		p.mark(true)


func _user(dt: float) -> void:
	if user_team < 0 or demo:
		return
	if user_player == null or not is_instance_valid(user_player) or user_player.in_box or user_player.team != user_team:
		_auto_switch(true)
	if user_player == null:
		return
	# Off the rink in a line change: the AI runs him to the bench and back; you get the nearest.
	if user_player.get_meta("going_off", false):
		_auto_switch(true)
		return
	if bool(Game.settings.auto_switch) and ball.carrier == null and phase_t > 0.0:
		_auto_switch(false)
	var j: Vector2 = touch.joystick if touch else Vector2.ZERO
	var sprint: bool = touch != null and touch.held("SPRINT")
	var top = user_player.MAX_SPEED * (1.0 if sprint else 0.86)
	user_player.want_vel = j * top
	user_player.want_face = NAN
	if sprint:
		user_player.stamina = maxf(0.35, user_player.stamina - 0.03 * dt)
	# 2026: no field player in the goalkeeper area; you are stopped at its edge.
	# Looking as far ahead as he needs to stop (he cannot stop dead), and only from outside: from in it, he can leave.
	for end: int in [-1, 1]:
		var ahead: float = 0.12 + user_player.vel.length() / Player.DECEL * 0.5
		var nxt = user_player.pos + user_player.want_vel.normalized() * user_player.vel.length() * ahead
		if Rules.in_gk_area(nxt, end) and not Rules.in_gk_area(user_player.pos, end):
			user_player.want_vel.x = 0.0
	if touch:
		touch.set_buttons(["SHOOT", "PASS", "SPRINT"] if ball.carrier == user_player else ["TACKLE", "SWITCH", "SPRINT"])
	# A first match: the coach's tips, each once, as the moment for it comes.
	if hud and phase == "live":
		hud.coach("TIP_MOVE")
		if ball.carrier == user_player:
			hud.coach("TIP_BALL")
		elif ball.carrier != null and ball.carrier.team != user_team:
			hud.coach("TIP_DEFEND")


var _switch_cool := 0.0


func _auto_switch(force: bool) -> void:
	_switch_cool -= get_physics_process_delta_time()
	if not force and _switch_cool > 0.0:
		return
	var b := ball.predict(0.2)
	var best: Player = null
	var bd := 1e9
	for p: Player in skaters(user_team):
		if p.get_meta("going_off", false):
			continue
		var d := p.pos.distance_to(b)
		if p == user_player:
			d -= 1.5   # stay with the one you have unless another is clearly nearer
		if d < bd:
			bd = d
			best = p
	if best and best != user_player:
		_set_user(best)
		_switch_cool = 0.6


func _on_action(id: String) -> void:
	if paused:
		return
	# Your penalty shot (_breakaway): SHOOT held winds up, let go it shoots; DEKE fakes.
	if phase == "shootout" and _so.get("shooter") != null and (_so.shooter as Player).team == user_team and not demo:
		if String(_so.get("stage", "")) == "run" and not bool(_so.get("shot", false)):
			if id == "SHOOT" or id == "TACKLE":
				_so.winding = true
				_so.wind = 0.0
			elif id == "DEKE" or id == "PASS":
				_deke(_so.shooter)
		return
	if user_player == null:
		return
	if phase == "setup" and restart.get("taker") == user_player:
		# Your free-hit or hit-in: the buttons show SHOOT and PASS (a tap that came as the old ones still counts).
		if id in ["SHOOT", "PASS", "TACKLE", "SWITCH"]:
			_take_restart(user_player, id in ["SHOOT", "TACKLE"])
		return
	if phase != "live":
		return
	match id:
		"SHOOT":
			if ball.carrier == user_player:
				var g: Vector2 = ai[user_team].target_goal()
				if user_player.pos.x * attack_dir(user_team) > Rules.GOAL_LINE - 0.4:
					# Behind their goal there is no shot: the ball goes out in front, to the best-placed team-mate.
					var best: Player = null
					var bs := -1e9
					for q: Player in skaters(user_team):
						if q != user_player and q.pos.x * attack_dir(user_team) < Rules.GOAL_LINE - 1.0:
							var s: float = ai[user_team]._pass_value(user_player, q) - q.pos.distance_to(g) / 10.0
							if s > bs:
								bs = s
								best = q
					if best:
						pass_to(user_player, best)
					return
				var aim: Vector3 = ai[user_team]._aim(user_player, g)
				# The joystick's sideways push picks the corner.
				var j: Vector2 = touch.joystick if touch else Vector2.ZERO
				if absf(j.y) > 0.3:
					aim.z = signf(j.y) * Rules.GOAL_W * 0.36
				shoot(user_player, aim, user_player.pos.distance_to(g) > 9.0)
		"PASS":
			if ball.carrier == user_player:
				pass_to(user_player, _pass_pick())
		"TACKLE":
			var car: Player = ball.carrier
			if car and car.team != user_team:
				if user_player.blade_floor().distance_to(ball.floor_pos()) < 1.2:
					tackle(user_player, car)
				else:
					user_player.do("tackle", 0.3)
			elif ball.carrier == null and ball.pos.y > 0.5 and user_player.blade_floor().distance_to(ball.floor_pos()) < 1.0:
				# Swinging at a ball above the knee: an offence (507.3).
				user_player.do("tackle", 0.3)
				offence(user_player, nearest_opponent(user_player), "high_ball")
			else:
				user_player.do("tackle", 0.3)
		"SWITCH":
			var b := ball.floor_pos()
			var best: Player = null
			var bd := 1e9
			for p: Player in skaters(user_team):
				if p == user_player:
					continue
				var d := p.pos.distance_to(b)
				if d < bd:
					bd = d
					best = p
			if best:
				_set_user(best)
				_switch_cool = 1.2


# ---------------------------------------------------------------- your penalty shot

## Your penalty shot (509), as one is really taken: you skate in from the centre spot with the ball (the joystick:
## left and right, and up for faster; the ball must keep going forward, so you cannot stop); DEKE fakes a shot to
## one side, and a goalkeeper close enough bites on it, going across and down that way; SHOOT held winds the stick
## back (the longer, the harder, but held too long the shot runs wild), let go it shoots, at the corner the joystick
## points to (up for high), or, left alone, at the side the goalkeeper has left open. Whether he saves it is where
## he is and how fast he can get across before the ball arrives (_breakaway_shot).
const BITE_S := 0.9            # how long a goalkeeper who bit on a deke is out of position
const WIND_S := 0.55           # seconds to a full wind-up
const WILD_S := 1.1            # held longer than this, the shot runs wild


func _breakaway(sh: Player, gk: Player, s: float, dt: float) -> void:
	var j: Vector2 = touch.joystick if touch else Vector2.ZERO
	# The camera is behind him: the joystick's right is his right (+z going toward +x), up is toward the goal.
	var fwd := clampf(4.4 - j.y * 1.6, 3.0, 6.2)
	sh.want_vel = Vector2(fwd * s, j.x * s * 3.6)
	sh.want_face = 0.0 if s > 0.0 else PI
	_so.bite = maxf(0.0, float(_so.get("bite", 0.0)) - dt)
	if bool(_so.get("winding", false)):
		_so.wind = float(_so.get("wind", 0.0)) + dt
		sh.windup = clampf(float(_so.wind) / WIND_S, 0.0, 1.0)
		var held: bool = touch != null and (touch.held("SHOOT") or touch.held("TACKLE"))
		if not held or float(_so.wind) > WILD_S + 0.4 or sh.pos.x * s > Rules.GOAL_LINE - 2.2:
			_breakaway_shot(sh, gk, s, j)
	elif sh.pos.x * s > Rules.GOAL_LINE - 2.0 and not bool(_so.shot):
		# Into the goalkeeper's lap without a shot: he smothers it.
		_so.winding = true
		_so.wind = 0.1
		_breakaway_shot(sh, gk, s, Vector2.ZERO)
	_keeper_mirror(gk, s, dt)


## The goalkeeper facing a penalty shot: out on his line, square to the ball, mirroring it across; down on his knees
## as the shooter comes close; after biting on a deke, across and down to that side until he can recover.
func _keeper_mirror(gk: Player, s: float, dt: float) -> void:
	var want_z := clampf(ball.pos.z * 0.45, -0.55, 0.55)
	if float(_so.get("bite", 0.0)) > 0.0:
		want_z = float(_so.get("bite_side", 0.0)) * 0.75
	var want_x := (Rules.GOAL_LINE - 0.9) * s
	gk.want_vel = Vector2((want_x - gk.pos.x) * 2.5, clampf((want_z - gk.pos.y) * 5.0, -3.2, 3.2))


## DEKE: the blade pulls the ball across to a side (the joystick's, or the other side from where it is), as if to
## shoot there. A goalkeeper close enough reads it as the shot and goes: the closer, the surer he bites.
func _deke(sh: Player) -> void:
	if float(_so.get("deke_cool", -1.0)) > float(_so.t):
		return
	_so.deke_cool = float(_so.t) + 0.45
	var s := float(_so.get("dir", 1.0))
	var j: Vector2 = touch.joystick if touch else Vector2.ZERO
	var side := signf(j.x) * s if absf(j.x) > 0.3 else -signf(ball.pos.z - sh.pos.y + 0.001)
	sh.do("deke", 0.45)
	sh.deke_side = side
	var dist := absf(Rules.GOAL_LINE * s - sh.pos.x)
	var gk := keeper(1 - sh.team)
	var chance := clampf((9.0 - dist) / 5.5, 0.15, 0.95) * (0.75 if int(_so.get("dekes", 0)) > 0 else 1.0)
	_so.dekes = int(_so.get("dekes", 0)) + 1
	if _rng.randf() < chance:
		_so.bite = BITE_S
		_so.bite_side = side
		if dist < 6.5:
			gk.do("save_low", 0.8)
	Sfx.play("tap", -10.0)


## The shot: where at, how hard, and whether the goalkeeper gets there.
func _breakaway_shot(sh: Player, gk: Player, s: float, j: Vector2) -> void:
	_so.winding = false
	var wind := float(_so.get("wind", 0.0))
	var gz := gk.pos.y
	var z := 0.0
	if absf(j.x) > 0.25:
		z = signf(j.x) * s * 0.6
	else:
		z = (-signf(gz) if absf(gz) > 0.05 else (1.0 if _rng.randf() < 0.5 else -1.0)) * 0.6
	var high := j.y < -0.45
	var aim := Vector3(Rules.GOAL_LINE * s, 0.95 if high else 0.22, z)
	if wind > WILD_S:
		aim += Vector3(0, _rng.randf_range(-0.15, 0.3), _rng.randf_range(-0.4, 0.4))
	else:
		aim += Vector3(0, _rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.08, 0.08))
	_so.shot = true
	_so.aim = aim
	_so.t = minf(float(_so.t), 4.0)
	var k := clampf(wind / WIND_S, 0.0, 1.0)
	sh.windup = maxf(k, 0.35)   # the swing comes from the wind-up (Player.do keeps it for the follow-through)
	shoot(sh, aim, k > 0.6)
	sh.windup = 0.0
	sh.act_len = 0.85           # a penalty shot's swing seen whole, through to the follow-through
	if _shot_live.is_empty():
		return
	# Faster with a full wind-up (a wrist shot 19 m/s, a slapped one 30).
	var sp := lerpf(19.0, 30.0, k)
	var v: Vector3 = ball.vel
	var flat := Vector2(v.x, v.z).normalized()
	var d := Vector2(aim.x - ball.pos.x, aim.z - ball.pos.z).length()
	var tt := d / sp
	ball.vel = Vector3(flat.x * sp, (aim.y - ball.pos.y) / tt + 0.5 * Ball.G * tt, flat.y * sp)
	_shot_live.speed = sp
	# Does he get there? He is on his knees (or standing), so far across; he sees it after a moment (later if he bit
	# the other way), then moves across at his speed; his reach is his body, his pads and his arms, less over the
	# shoulder of a kneeling goalkeeper.
	var on_target: bool = PenaltyShot.in_goal(aim)
	var bitten := float(_so.get("bite", 0.0)) > 0.0
	var wrong_way := bitten and signf(float(_so.get("bite_side", 0.0))) != signf(aim.z - gz)
	var saved: bool = on_target and PenaltyShot.keeper_gets_there(aim, gz, tt, wrong_way, gk.stat("reflex")) and _rng.randf() < 0.92
	_shot_live.forced = "save" if saved else ("goal" if on_target else "wide")


## The close camera for a penalty shot: low behind the shooter as he skates in, the goal ahead; after the shot it stays
## and turns with the ball (in Penalty shots, until the next shot comes). [] when there is none.
func penalty_view() -> Array:
	if phase != "shootout" or _so.is_empty() or _so.get("shooter") == null or String(_so.get("stage", "")) == "setup" \
			or (String(_so.get("stage", "")) == "end" and not bool(_so.get("practice", false))):
		ball.show_k = Ball.SHOW_K
		return []
	var sh: Player = _so.shooter
	var s := float(_so.get("dir", 1.0))
	ball.show_k = 1.15   # near its real size up close (Ball.show_k; back to SHOW_K after)
	var behind := 2.9 if String(_so.stage) != "walk" else 4.2
	# Low behind him and off his stick side, so he stands at the edge of the picture and the goal is clear.
	var at := Vector3(sh.pos.x - s * behind, 1.25, sh.pos.y * 0.8 + s * 1.05)
	var look := Vector3(Rules.GOAL_LINE * s, 0.45, sh.pos.y * 0.2 - s * 0.35)
	if bool(_so.get("shot", false)):
		look = look.lerp(ball.pos, 0.5)
	return [at, look]


## Who a pass goes to: the team-mate most in the joystick's direction, or the best one by the AI's reading.
func _pass_pick() -> Player:
	var j: Vector2 = touch.joystick if touch else Vector2.ZERO
	var best: Player = null
	var bs := -1e9
	for q: Player in skaters(user_team):
		if q == user_player:
			continue
		var s: float = ai[user_team]._pass_value(user_player, q)
		if j.length() > 0.3:
			var to: Vector2 = (q.pos - user_player.pos).normalized()
			s = to.dot(j.normalized()) * 2.0 + s * 0.3
		if s > bs:
			bs = s
			best = q
	return best


func _user_side() -> int:
	return user_team


# ---------------------------------------------------------------- pause, the back button

func set_paused(p: bool) -> void:
	paused = p
	Sfx.set_paused(p)
	if hud:
		hud.show_pause(p)


func on_back() -> void:
	if phase == "replay":
		_end_replay()
		return
	if hud and hud.has_method("on_back") and hud.on_back():
		return
	set_paused(not paused)


# ---------------------------------------------------------------- penalty-shot practice

## Penalty shots (the home screen's mini game): your country's best shooter takes ten penalty shots at the other side's
## goalkeeper, taken as in a match (_breakaway): skate in, fake, pick your corner. A goal is a point; one in a top
## corner ("top shelf") two.
## The rest of both teams are off the rink; the referees stay. The best score is kept (Game.settings.penalty_best).
const PRACTICE_SHOTS := 10
var _practice := {}


func _practice_start() -> void:
	_practice = {"shot": 0, "points": 0, "marks": [], "best": int(Game.settings.get("penalty_best", -1))}
	var shooter: Player = skaters(0)[0]
	var best := -1.0
	for p: Player in skaters(0):
		if p.stat("shot") > best:
			best = p.stat("shot")
			shooter = p
	_practice.shooter = shooter
	for t in 2:
		for p: Player in players[t]:
			if p != shooter and p != keeper(1):
				p.visible = false
				p.on_rink = false if p.role == "G" else p.on_rink
	Crowd.set_excite(0.0)
	_practice_next()


func _practice_next() -> void:
	_practice.shot = int(_practice.shot) + 1
	var n := int(_practice.shot)
	_so = {"stage": "setup", "t": 0.0, "in_match": true, "team": 0, "dir": 1.0, "pick": _practice.shooter,
		"practice": true}
	_set_phase("shootout")
	if hud:
		hud.practice_panel(_practice)
		if n == 1:
			hud.hint(tr("SO_HINT"))


func _practice_shot_done(scored: bool) -> void:
	var aim: Vector3 = _so.get("aim", Vector3.ZERO)
	var double: bool = scored and PenaltyShot.top_corner(aim)
	var pts := (2 if double else 1) if scored else 0
	_practice.points = int(_practice.points) + pts
	(_practice.marks as Array).append(pts)
	_whistle("short", -4.0)
	if scored:
		Sfx.react("cheer", -4.0 if not double else -1.0)
		Crowd.set_excite(1.0 if double else 0.8)
		if hud:
			hud.banner(tr("PRACTICE_DOUBLE") if double else tr("GOAL"))
	else:
		Sfx.react("groan", -6.0)
		Crowd.set_excite(0.25)
	if hud:
		hud.practice_panel(_practice)
	ball.release()
	get_tree().create_timer(2.4).timeout.connect(func():
		if not is_inside_tree():
			return
		Crowd.set_excite(0.0)
		ball.in_goal = 0
		ball.live = true
		if int(_practice.shot) >= PRACTICE_SHOTS:
			_practice_end()
		else:
			_practice_next())


func _practice_end() -> void:
	_set_phase("over")
	var pts := int(_practice.points)
	var new_best := pts > int(_practice.best)
	if new_best:
		Game.settings.penalty_best = pts
		Game.save_settings()
	if hud:
		hud.practice_end(pts, maxi(pts, int(_practice.best)), new_best)


## Start the ten again (the pause menu, the end card).
func practice_restart() -> void:
	_practice.shot = 0
	_practice.points = 0
	_practice.marks = []
	_practice.best = int(Game.settings.get("penalty_best", -1))
	_shot_live = {}
	ball.release()
	ball.in_goal = 0
	ball.live = true
	_practice_next()


func quit_to_menu() -> void:
	Sfx.set_paused(false)
	Sfx.crowd(-1.0)
	Game.goto_menu()


func continue_after_interval() -> void:
	if phase == "interval":
		_next_period()


var _timeout_team := -1


## A time-out (202): one a team, 30 seconds, asked for any time and granted at the next stoppage.
func call_timeout(team := -2) -> bool:
	var t := user_team if team == -2 else team
	if t < 0 or rules.timeouts[t] <= 0 or _timeout_team >= 0:
		return false
	rules.timeouts[t] -= 1
	_timeout_team = t
	return true


## At a stoppage: a time-out asked for is taken now, the referee making the T. The 30 seconds are shown, not waited.
func _take_timeout() -> void:
	if _timeout_team < 0:
		return
	rules.log.append({"kind": "timeout", "team": _timeout_team, "period": rules.period, "t": rules.clock})
	_ref_signal("timeout", Vector2.ZERO)
	_whistle("double", -3.0)
	if hud:
		hud.banner(tr("SIGN_TIMEOUT") + " · " + DB.team_name(String(config.home if _timeout_team == 0 else config.away)))
	_timeout_team = -1


## The AI's coach calls his time-out a goal down late in the third period, as coaches do.
func _ai_timeout() -> void:
	if rules.period != Rules.PERIODS or rules.remaining() > 180.0:
		return
	for t in 2:
		if t != user_team and rules.timeouts[t] > 0 and int(rules.goals[t]) == int(rules.goals[1 - t]) - 1:
			call_timeout(t)


## In a browser build, the state a playtest script reads (window.fs): where the ball and your player are on the
## screen, the phase, the score. Nothing reads it in the game itself.
func _web_probe() -> void:
	var vp := get_viewport()
	var k := vp.get_visible_rect().size
	var bs := cam.unproject_position(ball.pos)
	var us := cam.unproject_position(Vector3(user_player.pos.x, 0.9, user_player.pos.y)) if user_player else Vector2(-1, -1)
	var g: Vector2 = ai[user_team].target_goal() if user_team >= 0 else Vector2.ZERO
	var gs := cam.unproject_position(Vector3(g.x, 0.5, g.y))
	var st := {"phase": phase, "score": rules.goals, "clock": int(rules.clock), "period": rules.period, "vw": k.x, "vh": k.y,
		"ball": [bs.x, bs.y], "me": [us.x, us.y], "goal": [gs.x, gs.y], "mine": ball.carrier == user_player and user_player != null,
		"ours": ball.carrier != null and ball.carrier.team == user_team, "buttons": touch.ids if touch else [],
		"taker": phase == "setup" and restart.get("taker") == user_player, "so": phase == "shootout"}
	JavaScriptBridge.eval("window.fs = " + JSON.stringify(st) + ";")


# ---------------------------------------------------------------- performance

## The auto graphics level (WsgAutoTier, the shared foundation's): all match long, two windows of stutter in a row
## (slow, or hitching: a phone at 50 a second that stalls twice a second stutters as badly as one at 25) take a level
## off at once; again later if it still stutters. The frames are the drawn ones (_process), not the fixed physics
## steps. Only in the game itself: the tests and tools play at fixed rates or draw in software.
func _process(delta: float) -> void:
	if Game.main != null and Game.main.scene_file_path == "res://main.tscn":
		watch_frames(delta)


## A frame's time (s) to the auto graphics level.
func watch_frames(delta: float) -> void:
	if demo or paused or not bool(Game.settings.get("auto_gfx", true)) or phase == "replay":
		return
	if _auto_gfx.feed(delta) and int(Game.settings.graphics) > Game.GFX_LOW:
		lower_graphics()


## A graphics level down, now, mid-match: the setting (kept), the picture's size and smoothing, the sun's shadows and
## the people's shadows, the foundation's tier (its bodies in full detail ranked again; its replay ring), a word on
## the screen. (The rink, the hall and the crowd are built for a level when the match starts: the next match builds
## them at the new one.)
func lower_graphics() -> void:
	print("auto graphics: %d -> %d (%.0f frames a second, %d hitches)" % [int(Game.settings.graphics),
		int(Game.settings.graphics) - 1, float(_auto_gfx.last[0]), int(_auto_gfx.last[1])])
	Game.settings.graphics = int(Game.settings.graphics) - 1
	Game.save_settings()
	Game.apply_graphics(get_viewport())
	WsgFoundation.tier = int(Game.settings.graphics)
	var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for p: Player in everyone() + sitters[0] + sitters[1]:
		if p.link and p.link.body:
			p.link.body.mesh_instance.cast_shadow = sh
			if p.link.stick:
				p.link.stick.cast_shadow = sh
		elif p.body and p.body.rig:
			p.body.rig.mesh.cast_shadow = sh
			if p.body.rig.stick:
				p.body.rig.stick.cast_shadow = sh
	# Low keeps no replay.
	if wsg_replay and int(Game.settings.graphics) == Game.GFX_LOW and phase != "replay":
		wsg_replay.queue_free()
		wsg_replay = null
	_detail_t = 0.0
	_auto_gfx.reset()
	if hud:
		hud.hint(tr("GFX_LOWERED"))


## The foundation's bodies in full detail nearest the camera only, as the game's profile allows (WsgFoundation:
## Floorball is "premium": the nearest 8, 14 and 22 on Low, Medium and High - every body on the rink but on Low),
## twice a second.
func _rank_detail(dt: float) -> void:
	_detail_t -= dt
	if _detail_t > 0.0 or not FoundationLink.enabled():
		return
	_detail_t = 0.5
	WsgFoundation.tier = int(Game.settings.graphics)
	var bodies := []
	for p: Player in everyone() + sitters[0] + sitters[1]:
		if p.link and p.link.body and p.is_visible_in_tree():
			bodies.append(p.link.body)
	var cam3 := get_viewport().get_camera_3d()
	WsgFoundation.rank_detail(bodies, cam3.global_position if cam3 else Vector3.ZERO)


var _crowd_look := Vector2.ZERO


func _crowd_noise() -> void:
	var b := ball.floor_pos()
	# The crowd watches the ball: their eyes on it, their bodies turning after it a moment behind.
	_crowd_look = _crowd_look.lerp(b, 0.05)
	Crowd.set_focus(_crowd_look, 0.9)
	if demo:
		return
	var near_goal := clampf((absf(b.x) - 8.0) / 8.0, 0.0, 1.0)
	Sfx.crowd(0.35 + near_goal * 0.4)
	Crowd.set_excite(near_goal * 0.3)
