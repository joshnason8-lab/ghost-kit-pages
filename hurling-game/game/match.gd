extends Node3D
## A match of hurling, to the playing rules (Rules, docs/RULES.md): fifteen a side; two halves (35 minutes at
## senior county level, 30 at club), time added on; goals worth three points and points one; the throw-in to start
## each half; puck-outs, frees, 65s, sideline cuts and penalties; the four-step and two-catch rules; the tackle and
## its fouls; yellow, red and (in senior county hurling) black cards; advantage; in a knock-out game, extra time and
## then a penalty shoot-out.
##
## The match's clock runs faster than real time (Settings, Match length), so a full match fits a sitting; the play
## itself runs at real speed. One player on your side is yours (the lit ring): the joystick runs him, and he does
## what you press; the rest of your side, and the other side, play as the AI (TeamAI) has them.

enum P {INTRO, THROW_IN, LIVE, DEAD, SETUP, SET, HALF_TIME, SHOOTOUT, OVER}

const DEAD_T := 1.6          # s from the whistle to the players going to their places
const SETUP_MAX := 7.0       # s to get to them at most
const REACH := 1.25          # m from a player to a ball he can play with the hurley
const CATCH_H := 2.75        # m: the highest a player catches standing; jumping adds up to half a metre

var config := {}
var paused := false
var attract := false         # behind the home screen: no HUD, no sound to speak of, no haptics

var stadium: Stadium
var ball: Sliotar
var cam: CameraRig
var hud: MatchHud
var controls: TouchControls
var officials: Officials
var rng := RandomNumberGenerator.new()

# The teams: [home, away]: {id, name, short, c1, c2, players (on the field), bench (data), subs}.
var teams: Array = []
var ai: Array = []
var user_team := -1
var active: Player = null    # your player
var grade := Rules.GRADE_SENIOR
var knockout := false

# Time.
var phase := P.INTRO
var phase_t := 0.0
var now := 0.0               # real seconds since the start (the players' and the ball's clock)
var half := 1                # 1, 2; 3 and 4 the halves of extra time
var clock := 0.0             # seconds of match time played in this half
var clock_k := 5.0           # match seconds a real second
var half_len := 35.0 * 60.0
var added := 0.0             # added time this half, in match seconds (shown in whole minutes)
var _added_shown := false
var _stoppage := 0.0         # time lost this half to stoppages (cards, injuries, scores), for the added time

# The score: [goals, points] each side.
var score := [[0, 0], [0, 0]]
var shootout := {}           # {goals: [a, b], taken: [a, b], next: team, order: [[...], [...]]}

# The ball and who has it.
var carrier: Player = null
var carries := {}            # Player -> Rules.Carry
var restart := {}            # the set piece to come: {kind, team, spot, taker}
var taker: Player = null
var _pending: Array = []     # [time, Callable] the moments actions meet the ball
var _path: Array = []        # the free ball's flight ahead (Sliotar.path), from _path_t
var _path_t := 0.0
var chasers := [[], []]      # each side's players going for a loose ball, best first
var _chase_t := 0.0
var advantage := {}          # advantage being played: {team (fouled), foul, spot, by, card, until, denial}
var _last_owner := -1        # the side that last had the ball in hand or on the hurley
var _puck_travel := {}       # a puck-out's start, for the 13 m rule: {team, from}
var _set_t := 0.0
var _sideline_taker: Player = null

# The record of the match: what the box score is made of.
var events: Array = []       # {t (match minute), team, kind, by (player id), how}
var pstats := {}             # player id -> {goals, points, frees, w (wides), ...}
var tstats := [{}, {}]       # shots, wides, frees, 65s, puckouts, puckouts_won, yellow, red, black

var _cooldown := {}          # player -> earliest time he tries another tackle
var _spot_plan := {}         # player -> [where he means to stand, when to look again]
var _hold_still := 0.0
var _fps_hist: Array = []    # recent frame times (ms) for the dev overlay and the auto graphics level
var _early_frames := 0
var _early_slow := 0


func _ready() -> void:
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	attract = bool(config.get("attract", false))
	user_team = int(config.get("user_team", 0)) if not attract else -1
	grade = int(config.get("grade", Game.settings.get("grade", 0)))
	knockout = bool(config.get("knockout", false))
	half_len = float(config.get("half", Rules.half_minutes(grade))) * 60.0
	var length_min := float(config.get("length", Game.LENGTHS[clampi(int(Game.settings.get("length", 1)), 0, Game.LENGTHS.size() - 1)]))
	clock_k = (half_len * 2.0 / 60.0) / maxf(1.0, length_min)
	var venue := String(config.get("venue", "county"))
	var home_t := DB.team(String(config.home))
	stadium = Stadium.new(venue, [home_t.c1, home_t.c2])
	add_child(stadium)
	ball = Sliotar.new()
	add_child(ball)
	ball.place(Vector3.ZERO)
	_make_teams()
	officials = Officials.new(self)
	add_child(officials)
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	Game.apply_graphics(get_viewport())
	hud = MatchHud.new()
	add_child(hud)
	hud.setup(self)
	controls = TouchControls.new()
	hud.root.add_child(controls)
	controls.action.connect(_on_action)
	controls.visible = user_team >= 0
	if attract:
		hud.visible = false
		controls.visible = false
		Sfx.crowd(0.12)
	else:
		Sfx.crowd(stadium.atmosphere() * 0.55)
	for k in 2:
		var t := TeamAI.new(self, k)
		var diff := int(config.get("difficulty", Game.settings.get("difficulty", 1)))
		if k != user_team and user_team >= 0:
			t.skill = [0.82, 0.95, 1.05, 1.15][clampi(diff, 0, 3)]
		ai.append(t)
	_place_for_throw_in(true)
	phase = P.INTRO
	phase_t = 0.0
	if not attract:
		hud.intro(_intro_line())


func _intro_line() -> String:
	var stage := String(config.get("stage", ""))
	var venue_name := tr(String(DB.venue(String(config.get("venue", "county")))[0]))
	return ("%s · %s" % [stage, venue_name]) if stage != "" else venue_name


# ---------------------------------------------------------------- the teams

func _make_teams() -> void:
	var ids := [String(config.home), String(config.away)]
	var clash := DB.colours_clash(ids[0], ids[1])
	for k in 2:
		var t := DB.team(ids[k])
		var c1: Color = t.c1
		var c2: Color = t.c2
		if k == 1 and clash:
			# The away side changes: its second colour for the jersey.
			var tmp := c1
			c1 = c2
			c2 = tmp
			if DB.colours_clash(ids[0], ids[1]) and Vector3(c1.r - DB.team(ids[0]).c1.r, c1.g - DB.team(ids[0]).c1.g, c1.b - DB.team(ids[0]).c1.b).length() < 0.35:
				c1 = Color("f2f2ee")
		var team := {"id": ids[k], "c1": c1, "c2": c2, "design": int(t.design), "players": [], "bench": DB.squad(ids[k]).slice(15),
			"subs": 0, "temp": 0}
		var helmet := c2.darkened(0.2) if c2.get_luminance() > 0.85 else c2
		for pd in DB.starters(ids[k]):
			var look := {"skin": _skin(int(pd.skin)), "hair": _hair(int(pd.hair)), "hair_style": int(pd.hair_style),
				"jersey": c1, "trim": c2, "shorts": Color("f6f6f2") if c1.get_luminance() < 0.6 else Color("1a1a1a"),
				"socks": c1, "helmet": helmet, "design": int(t.design), "height": float(pd.height), "kind": "player"}
			if int(pd.line) == DB.POS_GK:
				# The goalkeeper in a different jersey from both sides.
				look.jersey = Color("2a9d5c") if k == 0 else Color("d9772b")
				look.socks = look.jersey
				look.design = 0
			var pl := Player.new(pd, k, look)
			add_child(pl)
			team.players.append(pl)
			carries[pl] = Rules.Carry.new()
			pstats[pd.id] = {"goals": 0, "points": 0, "free_g": 0, "free_p": 0, "wides": 0, "team": k, "num": int(pd.num)}
		teams.append(team)
		tstats[k] = {"shots": 0, "wides": 0, "frees": 0, "s65": 0, "sidelines": 0, "puckouts": 0, "puckouts_won": 0,
			"yellow": 0, "red": 0, "black": 0, "scores_play": 0, "scores_placed": 0, "shots_play": 0, "shots_placed": 0}
	_set_lods()


static func _skin(i: int) -> Color:
	return [Color("f1cdb0"), Color("e8bc9a"), Color("dba985"), Color("c98f6a")][clampi(i, 0, 3)]


static func _hair(i: int) -> Color:
	return [Color("2b1d14"), Color("4a3221"), Color("7a5232"), Color("b07a3a"), Color("15100c")][clampi(i, 0, 4)]


func _set_lods() -> void:
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for k in 2:
		for pl in teams[k].players:
			(pl as Player).body.set_lod(1 if low else 0)


func team_players(k: int) -> Array:
	return teams[k].players


func all_players() -> Array:
	return teams[0].players + teams[1].players


func player_by_num(k: int, n: int) -> Player:
	for pl in teams[k].players:
		if (pl as Player).num == n:
			return pl
	return null


func keeper_of(k: int) -> Player:
	return player_by_num(k, 1)


func carry_of(pl: Player) -> Rules.Carry:
	return carries[pl]


## The direction team k attacks this half: +1 toward +x.
func dir(k: int) -> float:
	return Pitch.attack_dir(k, half)


func possession_team() -> int:
	if carrier != null:
		return carrier.team
	if phase in [P.SETUP, P.SET] and not restart.is_empty():
		return int(restart.team)
	return _last_owner


func nearest_opponent(pl: Player, within: float) -> Player:
	var best: Player = null
	var bd := within
	for q in teams[1 - pl.team].players:
		var o: Player = q
		if not o.on_pitch():
			continue
		var d := o.global_position.distance_to(pl.global_position)
		if d < bd:
			bd = d
			best = o
	return best


func nearest_to(k: int, p: Vector3, skip_keeper := true) -> Player:
	var best: Player = null
	var bd := 1e9
	for q in teams[k].players:
		var o: Player = q
		if not o.on_pitch() or (skip_keeper and o.is_keeper()):
			continue
		var d := o.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = o
	return best


func match_minute() -> int:
	var base := 0.0 if half == 1 else (half_len if half == 2 else (half_len * 2.0 + (0.0 if half == 3 else Rules.EXTRA_HALF * 60.0)))
	return int((base + minf(clock, half_len_now() + added)) / 60.0) + 1


## Match seconds played since the throw-in, through the halves (and extra time).
func total_clock() -> float:
	var base := 0.0 if half == 1 else (half_len if half == 2 else (half_len * 2.0 + (0.0 if half == 3 else Rules.EXTRA_HALF * 60.0)))
	return base + clock


func half_len_now() -> float:
	return half_len if half <= 2 else Rules.EXTRA_HALF * 60.0


# ---------------------------------------------------------------- the loop

func _process(delta: float) -> void:
	_frame_stats(delta)
	if paused:
		return
	var dt := minf(delta, 0.05)
	now += dt
	phase_t += dt
	_run_pending()
	match phase:
		P.INTRO:
			_brains(dt)
			if phase_t > 3.0:
				_begin_throw_in()
		P.THROW_IN, P.LIVE:
			_live(dt)
		P.DEAD:
			_brains(dt)
			_run_clock(dt)
			if phase_t > DEAD_T:
				_begin_setup()
		P.SETUP:
			_brains(dt)
			_run_clock(dt)
			_setup_step()
		P.SET:
			_brains(dt)
			_run_clock(dt)
			_set_step(dt)
		P.HALF_TIME:
			if phase_t > (5.0 if not attract else 2.0):
				_second_half()
		P.SHOOTOUT:
			_brains(dt)
			_shootout_step(dt)
		P.OVER:
			_brains(dt)
	_move_all(dt)
	_carry_ball(dt)
	var cross: Array = ball.step(dt)
	if phase in [P.THROW_IN, P.LIVE, P.SHOOTOUT] and ball.state == Sliotar.FREE:
		_check_ball(cross[0], cross[1])
	officials.tick(dt)
	cam.follow(self, delta)
	if not attract:
		hud.tick(delta)
		_user_buttons()


func _frame_stats(delta: float) -> void:
	_fps_hist.append(delta * 1000.0)
	if _fps_hist.size() > 240:
		_fps_hist.pop_front()
	# The auto graphics level: if the first seconds of play run under about 36 frames a second, drop a level.
	if phase in [P.LIVE, P.THROW_IN] and bool(Game.settings.get("auto_gfx", true)) and not attract and _early_frames < 600:
		_early_frames += 1
		if delta > 1.0 / 36.0:
			_early_slow += 1
		if _early_frames == 600 and _early_slow > 300 and int(Game.settings.graphics) > Game.GFX_LOW:
			Game.settings.graphics = int(Game.settings.graphics) - 1
			Game.save_settings()
			Game.apply_graphics(get_viewport())
			ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
			hud.toast(tr("GFX_LOWERED"))


func frame_percentiles() -> Array:
	var s := _fps_hist.duplicate()
	s.sort()
	if s.is_empty():
		return [0.0, 0.0, 0.0, 0]
	var hitches := 0
	for v in _fps_hist:
		if float(v) > 50.0:
			hitches += 1
	return [float(s[s.size() / 2]), float(s[int(s.size() * 0.95)]), float(s[s.size() - 1]), hitches]


func _run_pending() -> void:
	var i := 0
	while i < _pending.size():
		if now >= float(_pending[i][0]):
			var f: Callable = _pending[i][1]
			_pending.remove_at(i)
			f.call()
		else:
			i += 1


func _after(t: float, f: Callable) -> void:
	_pending.append([now + t, f])


## Every player moved once a frame (Player.integrate is the only writer of a player's position), then posed. Players
## the camera cannot see are not posed; far ones every second or third frame.
func _move_all(dt: float) -> void:
	var camp: Vector3 = cam.camera.global_position
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	for pl in all_players() + officials.people:
		var p: Player = pl
		if not p.visible:
			continue
		p.integrate(dt, now)
		var d := p.global_position.distance_to(camp)
		p.visible_on_screen = cam.camera.is_position_in_frustum(p.global_position + Vector3(0, 1, 0)) or d < 12.0
		p.set_pose_rate(1 if d < 60.0 else (2 if d < 95.0 or not low else 3))
		p.animate(now)
	_separate(dt)


## Players do not run through one another: a gentle push apart for anyone closer than a body's width, added to what
## each wants (the next frame's integrate applies it).
func _separate(_dt: float) -> void:
	var ps := all_players()
	for i in ps.size():
		var a: Player = ps[i]
		if not a.on_pitch():
			continue
		for j in range(i + 1, ps.size()):
			var b: Player = ps[j]
			if not b.on_pitch():
				continue
			var d := b.global_position - a.global_position
			d.y = 0
			var l := d.length()
			if l < 0.75 and l > 0.001:
				var push := d / l * (0.75 - l) * 3.0
				a.want_vel -= push
				b.want_vel += push


## The ball where its holder has it: in his left hand, or riding on his bas.
func _carry_ball(dt: float) -> void:
	if carrier == null or ball.state == Sliotar.FREE:
		return
	if carrier.ball_hand:
		ball.global_position = carrier.body.bone_world("hand_l") + Vector3(0, -0.06, 0)
	elif carrier.ball_stick:
		var hop := absf(sin(now * 7.0)) * 0.12
		ball.global_position = carrier.body.bas_world() + Vector3(0, 0.06 + hop, 0)
	# The carrying rules: steps and time with it in the hand.
	var c: Rules.Carry = carries[carrier]
	var foul := Rules.carry_step(c, carrier.take_steps(), dt)
	if foul == "" and c.in_hand and c.steps >= 3 and _wants_auto_solo(carrier):
		_do_solo(carrier)
	elif foul != "" and phase == P.LIVE:
		_technical_foul(carrier, foul)


func _wants_auto_solo(pl: Player) -> bool:
	if pl.busy():
		return false
	if pl != active:
		return true
	return int(Game.settings.get("assist", 1)) >= 1


# ---------------------------------------------------------------- open play

## The referee's watch runs on through stoppages (the time lost is added on at the end of the half). With the clock
## sped up to fit a short match, a restart would eat minutes of it, so while the ball is dead it runs at 40%.
func _run_clock(dt: float) -> void:
	var k := clock_k if phase in [P.LIVE, P.THROW_IN] else maxf(1.0, clock_k * 0.4)
	clock += dt * k
	if not _added_shown and clock >= half_len_now() - 60.0:
		_end_of_half_check()


func _live(dt: float) -> void:
	_run_clock(dt)
	_brains(dt)
	_loose_ball(dt)
	_tackles(dt)
	_advantage_step()
	_end_of_half_check()
	_sin_bins()


## Each player's wish for this frame: where to run and what to do. Your player runs where the joystick says.
func _brains(dt: float) -> void:
	for k in 2:
		var t: TeamAI = ai[k]
		var press: Player = null
		if carrier != null and carrier.team != k and phase == P.LIVE:
			press = _presser(k)
		var press2: Player = null
		if press != null and carrier != null and Pitch.from_goal_line(carrier.global_position, dir(carrier.team)) < 45.0:
			press2 = _presser(k, press)
		for q in teams[k].players:
			var pl: Player = q
			if not pl.on_pitch():
				_walk_off(pl)
				continue
			if pl == active and phase in [P.LIVE, P.THROW_IN, P.SET, P.SETUP] and controls.visible:
				_user_move(pl, dt)
				continue
			var target := pl.global_position
			var speed := pl.top_speed()
			pl.face_to = Vector3.ZERO
			if phase in [P.INTRO, P.DEAD, P.OVER, P.HALF_TIME]:
				target = _rest_spot(pl)
				speed = 2.2
				pl.face_to = ball.global_position
			elif phase in [P.SETUP, P.SET]:
				target = _set_spot(pl)
				speed = 4.5 if pl != taker else 5.0
				pl.face_to = ball.global_position
			elif phase == P.SHOOTOUT:
				target = _shootout_spot(pl)
				speed = 3.0
				pl.face_to = ball.global_position
			elif pl == carrier:
				_carrier_brain(pl, t)
				continue
			elif pl.is_keeper():
				target = _keeper_spot(pl)
				speed = 5.0
				pl.face_to = ball.global_position
				if ball.state == Sliotar.FREE and pl in chasers[k] and chasers[k].find(pl) == 0 and _keeper_may_come(pl):
					target = _chase_target(pl)
					speed = pl.top_speed()
					pl.face_to = Vector3.ZERO
			elif ball.state == Sliotar.FREE and pl in chasers[k]:
				target = _chase_target(pl)
				speed = pl.top_speed() * (1.0 if chasers[k].find(pl) == 0 else 0.85)
			elif pl == press or pl == press2:
				target = _press_spot(pl, carrier)
				speed = pl.top_speed()
			else:
				# Off the ball: where to stand is looked at again about seven times a second (a phone's CPU is
				# spared thirty players' marking sums every frame); he steers to it every frame.
				var plan: Array = _spot_plan.get(pl, [])
				if plan.is_empty() or now >= float(plan[1]):
					var spot: Vector3
					if carrier != null and carrier.team == k:
						spot = t.attack_spot(pl, carrier)
					elif carrier != null:
						spot = t.defend_spot(pl)
					else:
						spot = t.home_spot(pl) if _last_owner != k else t.attack_spot(pl, null)
					plan = [spot, now + 0.12 + rng.randf() * 0.06]
					_spot_plan[pl] = plan
				target = plan[0]
				speed = _jog(pl, target)
			_steer(pl, target, speed)


func _jog(pl: Player, target: Vector3) -> float:
	var d := pl.global_position.distance_to(target)
	return clampf(d * 0.6, 0.0, pl.top_speed() * (0.92 if d > 10.0 else 0.6))


## Run toward target at up to speed, easing in over the last metre or two so he stops on it.
func _steer(pl: Player, target: Vector3, speed: float) -> void:
	var d := target - pl.global_position
	d.y = 0
	var l := d.length()
	if l < 0.3:
		pl.want_vel = Vector3.ZERO
		return
	var s := minf(speed, l * 2.2)
	pl.want_vel = d / l * s


func _rest_spot(pl: Player) -> Vector3:
	if phase == P.INTRO or phase == P.HALF_TIME:
		return _throw_in_spot(pl)
	return pl.global_position + pl.vel * 0.0


## The defender who goes to the man on the ball: the nearest goal-side one, else the nearest.
func _presser(k: int, not_this: Player = null) -> Player:
	var best: Player = null
	var bd := 1e9
	for q in teams[k].players:
		var pl: Player = q
		if not pl.on_pitch() or pl.is_keeper() or pl == not_this or pl.down(now):
			continue
		var d := pl.global_position.distance_to(carrier.global_position)
		if d < bd:
			bd = d
			best = pl
	return best


func _press_spot(pl: Player, c: Player) -> Vector3:
	# Close him down from the goal side, at his shoulder.
	var own_goal := Vector3(-Pitch.HALF_L * dir(pl.team), 0, 0)
	var cp := c.global_position + c.vel * 0.35
	var to := (own_goal - cp).normalized()
	return cp + to * 0.9


# ---------------------------------------------------------------- the loose ball

## Who goes for a ball in the air or on the ground: each side's two who can get to it first. Its flight is worked
## out once (Sliotar.path) and again after it bounces or is touched.
func _loose_ball(dt: float) -> void:
	if ball.state != Sliotar.FREE:
		chasers = [[], []]
		return
	_chase_t -= dt
	if _chase_t <= 0.0 or _path.is_empty():
		_chase_t = 0.15
		_path = Sliotar.path(ball.global_position, ball.vel, 5.0)
		_path_t = now
		for k in 2:
			chasers[k] = _pick_chasers(k)
	# Anyone who can reach it now plays it.
	_try_contacts()


func _pick_chasers(k: int) -> Array:
	var best := []
	for q in teams[k].players:
		var pl: Player = q
		if not pl.on_pitch() or pl.down(now):
			continue
		var t := _reach_time(pl)
		if t < 0.0:
			continue
		if pl.is_keeper() and not _keeper_may_come(pl):
			continue
		best.append([t, pl])
	best.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out := []
	for i in mini(2, best.size()):
		out.append(best[i][1])
	return out


## The soonest a player could be at the ball along its path (in the air within his reach, or on the ground), or the
## end of the path if he cannot catch it up before it stops.
func _reach_time(pl: Player) -> float:
	var p := pl.global_position
	var sp := pl.top_speed()
	for e in _path:
		var t: float = e[0]
		var b: Vector3 = e[1]
		if b.y > CATCH_H + 0.4:
			continue
		var run := maxf(0.0, Vector2(b.x - p.x, b.z - p.z).length() - REACH)
		if run / sp + 0.2 <= t:
			return t
	var last: Array = _path[_path.size() - 1]
	var lp: Vector3 = last[1]
	return float(last[0]) + Vector2(lp.x - p.x, lp.z - p.z).length() / sp


func _chase_target(pl: Player) -> Vector3:
	var p := pl.global_position
	var sp := pl.top_speed()
	var el := now - _path_t
	for e in _path:
		var t: float = float(e[0]) - el
		if t < 0.0:
			continue
		var b: Vector3 = e[1]
		if b.y > CATCH_H + 0.4:
			continue
		var run := maxf(0.0, Vector2(b.x - p.x, b.z - p.z).length() - REACH * 0.6)
		if run / sp <= t + 0.05:
			return Vector3(b.x, 0, b.z)
	var last: Array = _path[_path.size() - 1]
	var lp: Vector3 = last[1]
	return Vector3(lp.x, 0, lp.z)


func _keeper_may_come(pl: Player) -> bool:
	# The goalkeeper leaves his line only for a ball dropping into or near his own small rectangle area.
	var land: Vector3 = _path[_path.size() - 1][1] if not _path.is_empty() else ball.global_position
	return Pitch.from_goal_line(land, -dir(pl.team)) < 14.0 and absf(land.z) < 14.0


## The ball is within someone's reach: the AI's players play it; yours waits for your button (CATCH, LIFT, PULL),
## unless the ball comes straight to him.
func _try_contacts() -> void:
	var b := ball.global_position
	if b.y > CATCH_H + 0.6:
		return
	# The nearest player in reach goes for it first, whichever side he is on.
	var best: Player = null
	var bd := REACH + 0.3
	for pl in all_players():
		var p: Player = pl
		if not p.on_pitch() or p.busy() or p.down(now):
			continue
		var hd := Vector2(b.x - p.global_position.x, b.z - p.global_position.z).length()
		if hd > bd:
			continue
		if ball.last_touch == p and now - float(ball.get_meta("t_launch", 0.0)) < 0.5:
			continue
		if _puck_out_blocked(p):
			continue
		if p == active and controls.visible:
			continue
		bd = hd
		best = p
	if best != null:
		_attempt(best, "catch" if b.y > 1.3 else "lift")


## The 13 m rule: a puck-out must travel 13 m before another of the taker's side plays it.
func _puck_out_blocked(p: Player) -> bool:
	if _puck_travel.is_empty():
		return false
	if ball.global_position.distance_to(_puck_travel.from) >= Rules.PUCK_OUT_TRAVEL:
		_puck_travel = {}
		return false
	return p.team == int(_puck_travel.team)


## A player goes for the ball: the move starts now and meets the ball at its contact time, if it is still there.
func _attempt(p: Player, kind: String) -> void:
	var ct := p.contact_time(kind)
	var at := Sliotar.predict(ball.global_position, ball.vel, ct)
	p.play(kind, Vector3(0, clampf(at.y - CATCH_H + 0.2, 0.0, 0.6), 0))
	p.face_to = Vector3(at.x, 0, at.z)
	_after(ct, func(): _contact(p, kind))


func _contact(p: Player, kind: String) -> void:
	if ball.state != Sliotar.FREE or not (phase in [P.LIVE, P.THROW_IN]):
		return
	var b := ball.global_position
	var reach := p.global_position + Vector3(0, 0, 0)
	var hd := Vector2(b.x - reach.x, b.z - reach.z).length()
	var max_h := CATCH_H + (0.5 if kind == "catch" else 0.0)
	if hd > REACH + 0.45 or b.y > max_h + 0.2:
		return   # it has gone past him
	var skill := float(p.data.get("catching", 70)) / 100.0
	var speed := ball.vel.length()
	var chance := 0.0
	if kind == "catch":
		chance = 0.55 + skill * 0.4 - maxf(0.0, speed - 20.0) * 0.012 - maxf(0.0, b.y - CATCH_H) * 0.6
	else:
		chance = 0.62 + skill * 0.32 - maxf(0.0, speed - 12.0) * 0.015
	# A contest: an opponent at the ball too.
	var rival: Player = null
	for q in teams[1 - p.team].players:
		var o: Player = q
		if o.on_pitch() and o.global_position.distance_to(p.global_position) < 1.6 and not o.down(now):
			rival = o
			break
	if rival != null:
		var rs := float(rival.data.get("catching", 70)) / 100.0
		chance *= lerpf(0.5, 0.85, skill / maxf(0.01, skill + rs) * 2.0 - 0.5)
	if p == active:
		chance += 0.08
	if rng.randf() < chance:
		_gain(p, kind)
	else:
		# It breaks: off his hand or hurley, a few metres away.
		var v := ball.vel * 0.2 + Vector3(rng.randf_range(-4, 4), rng.randf_range(1.5, 4.0), rng.randf_range(-4, 4))
		ball.launch(v, p, "deflect")
		ball.set_meta("t_launch", now)
		_chase_t = 0.0
		Sfx.play("clash", -10.0, rng.randf_range(0.9, 1.1))


## He has it: caught into his hand (one of his two catches), or lifted onto his hurley.
func _gain(p: Player, kind: String) -> void:
	if phase == P.SHOOTOUT:
		ball.vel = Vector3.ZERO
		_shootout_result("", ball.global_position)
		return
	carrier = p
	_last_owner = p.team
	ball.state = Sliotar.HELD
	ball.holder = p
	ball.vel = Vector3.ZERO
	ball.last_touch = p
	ball.last_team = p.team
	_puck_travel = {}
	var c: Rules.Carry = carries[p]
	Rules.release(c)
	if kind == "catch":
		p.ball_hand = true
		p.ball_stick = false
		var foul := Rules.take_in_hand(c)
		if foul != "":
			_technical_foul(p, foul)
		Sfx.play("catch", -8.0)
		if p == active:
			Game.haptic("catch")
	else:
		p.ball_hand = false
		p.ball_stick = true
		Rules.to_hurley(c)
		Sfx.play("tap", -10.0)
	p.take_steps()
	ai[p.team].think_t[p] = now + 0.15
	if user_team >= 0 and p.team == user_team:
		_set_active(p)
	elif user_team >= 0 and active != null and active.team == user_team:
		pass
	if not advantage.is_empty() and int(advantage.team) != p.team:
		_advantage_lost()


# ---------------------------------------------------------------- on the ball

func _carrier_brain(pl: Player, t: TeamAI) -> void:
	if pl.busy():
		pl.want_vel = pl.vel * 0.9
		return
	var nt: float = t.think_t.get(pl, 0.0)
	var pressed := nearest_opponent(pl, 2.5) != null
	if now >= nt or (pressed and now >= nt - 0.15):
		t.think_t[pl] = now + rng.randf_range(0.25, 0.45)
		var d: Dictionary = t.decide(pl)
		t.plan[pl] = d
		match String(d.kind):
			"shoot":
				_shoot(pl, false)
				return
			"goal":
				_shoot(pl, true)
				return
			"pass":
				_strike_pass(pl, d.to)
				return
			"hand_pass":
				if pl.ball_hand:
					_hand_pass(pl, d.to)
				else:
					_strike_pass(pl, d.to)
				return
			"solo":
				_do_solo(pl)
			"to_hand":
				_do_to_hand(pl)
	var plan: Dictionary = t.plan.get(pl, {})
	var target: Vector3 = plan.get("target", pl.global_position + Vector3(dir(pl.team) * 10.0, 0, 0))
	_steer(pl, target, pl.top_speed())


func _wind_dir(pl: Player, target: Vector3) -> void:
	pl.face_to = Vector3(target.x, 0, target.z)


## A shot: for a point (over the bar) or a goal (low, away from the goalkeeper). Struck from the hand if he has it
## there, else flicked up off the hurley and struck.
func _shoot(pl: Player, for_goal: bool, placed := "") -> void:
	var d := dir(pl.team)
	var kp: Player = keeper_of(1 - pl.team)
	var target := TeamAI.goal_target(d, kp.global_position.z if kp else 0.0) if for_goal else TeamAI.point_target(d, pl.global_position)
	var kind := "strike" if pl.ball_hand or placed != "" else "strike_stick"
	if placed == "sideline":
		kind = "cut"
	elif placed == "puck_out":
		kind = "puck_out"
	_wind_dir(pl, target)
	pl.play(kind)
	var ct := pl.contact_time(kind)
	var shot := {"goal": for_goal, "placed": placed}
	_after(ct, func(): _strike_contact(pl, target, shot))


## The moment of the strike: the sliotar leaves the bas toward target, with the striker's error. For a point the
## error grows with distance and pressure; struck too short it drops under the bar or short.
func _strike_contact(pl: Player, target: Vector3, shot: Dictionary) -> void:
	if carrier != pl and not (phase == P.SET and pl == taker) and not (phase == P.SHOOTOUT and pl == taker):
		return
	var from := pl.global_position + pl.forward() * 0.75 + Vector3(0, 1.05, 0)
	if String(shot.get("placed", "")) in ["sideline", "free_ground"]:
		from = pl.global_position + pl.forward() * 0.6 + Vector3(0, 0.1, 0)
	var dist := Vector2(target.x - from.x, target.z - from.z).length()
	var acc := float(pl.data.get("accuracy" if String(shot.get("placed", "")) == "" else "free", 70)) / 100.0
	var pressure := 0.0
	var near := nearest_opponent(pl, 4.0)
	if near != null:
		pressure = 1.0 - near.global_position.distance_to(pl.global_position) / 4.0
	var skill_k: float = 1.0 / float(ai[pl.team].skill) if pl != active else 0.9
	# From 35 m about three in four go over, from 50 m about three in five (55% from play in 2026, 75% from frees).
	var sigma := (0.8 + dist * 0.075) * (1.6 - acc) * (1.0 + pressure * 1.2) * skill_k
	if String(shot.get("placed", "")) != "":
		sigma *= 0.72
	if bool(shot.get("goal", false)):
		sigma = (0.4 + dist * 0.03) * (1.5 - acc) * (1.0 + pressure)
	var aim := target + Vector3(0, rng.randfn(0.0, sigma * 0.5), rng.randfn(0.0, sigma))
	var power := float(pl.data.get("striking", 70)) / 100.0
	var speed := clampf(dist * 0.42 + 16.0, 22.0, 30.0 + power * 12.0)
	if bool(shot.get("goal", false)):
		speed = 30.0 + power * 10.0
	var sol := Sliotar.solve(from, aim, speed)
	var v: Vector3
	if sol.is_empty():
		var flat := Vector3(aim.x - from.x, 0, aim.z - from.z).normalized()
		v = (flat * cos(deg_to_rad(32.0)) + Vector3(0, sin(deg_to_rad(32.0)), 0)) * (30.0 + power * 12.0)
	else:
		v = sol[0]
	_release(pl)
	ball.global_position = from
	var how := "strike"
	var placed := String(shot.get("placed", ""))
	if placed != "":
		how = placed if placed != "free_ground" else "free"
	ball.launch(v, pl, how)
	ball.set_meta("t_launch", now)
	ball.set_meta("shot", {"by": pl, "placed": placed, "goal": bool(shot.get("goal", false)), "from": from})
	tstats[pl.team].shots += 1
	if placed == "" or placed == "pull":
		tstats[pl.team].shots_play += 1
	else:
		tstats[pl.team].shots_placed += 1
	_chase_t = 0.0
	_path = []
	Sfx.play("strike", -2.0, rng.randf_range(0.94, 1.06))
	if pl == active:
		Game.haptic("strike")
	_keeper_reacts(pl.team)
	if not advantage.is_empty() and int(advantage.team) == pl.team:
		advantage.shot = true


## A strike to a teammate: long and dropping into his path at a height he can catch.
func _strike_pass(pl: Player, to: Player, placed := "") -> void:
	var lead := to.vel * clampf(pl.global_position.distance_to(to.global_position) / 28.0, 0.3, 2.0)
	var target := Pitch.clamp_in(to.global_position + lead, 1.5)
	# A ball into the forwards drops in front of the square, not into the net or over the bar.
	var d := dir(pl.team)
	if Pitch.from_goal_line(target, d) < 14.0:
		target.x = (Pitch.HALF_L - 14.0) * d
	target += Vector3(0, 1.9, 0)
	var kind := "strike" if pl.ball_hand or placed != "" else "strike_stick"
	if placed == "sideline":
		kind = "cut"
	elif placed == "puck_out":
		kind = "puck_out"
	_wind_dir(pl, target)
	pl.play(kind)
	var ct := pl.contact_time(kind)
	_after(ct, func(): _pass_contact(pl, target, placed))


func _strike_to(pl: Player, target: Vector3, placed := "") -> void:
	var kind := "strike" if pl.ball_hand or placed != "" else "strike_stick"
	if placed == "sideline":
		kind = "cut"
	elif placed == "puck_out":
		kind = "puck_out"
	_wind_dir(pl, target)
	pl.play(kind)
	_after(pl.contact_time(kind), func(): _pass_contact(pl, target + Vector3(0, 1.0, 0), placed))


func _pass_contact(pl: Player, target: Vector3, placed: String) -> void:
	if carrier != pl and not (phase == P.SET and pl == taker):
		return
	var from := pl.global_position + pl.forward() * 0.75 + Vector3(0, 1.05 if placed != "sideline" else 0.1, 0)
	var dist := Vector2(target.x - from.x, target.z - from.z).length()
	var acc := float(pl.data.get("accuracy", 70)) / 100.0
	var sigma := (0.5 + dist * 0.05) * (1.5 - acc)
	var aim := target + Vector3(rng.randfn(0.0, sigma), 0, rng.randfn(0.0, sigma))
	var speed := clampf(dist * 0.45 + 10.0, 16.0, 38.0)
	var near_goal := Pitch.from_goal_line(target, dir(pl.team)) < 30.0
	var sol := Sliotar.solve(from, aim, speed, dist > 55.0 or near_goal)
	var v: Vector3 = sol[0] if not sol.is_empty() else (Vector3(aim.x - from.x, 0, aim.z - from.z).normalized() * 0.8 + Vector3(0, 0.6, 0)) * 36.0
	_release(pl)
	ball.global_position = from
	ball.launch(v, pl, placed if placed != "" else "strike")
	ball.set_meta("t_launch", now)
	ball.set_meta("shot", {})
	if placed == "puck_out":
		_puck_travel = {"team": pl.team, "from": from}
	_chase_t = 0.0
	_path = []
	Sfx.play("strike", -4.0, rng.randf_range(0.94, 1.06))
	if pl == active:
		Game.haptic("strike")
	if user_team >= 0 and pl.team == user_team and controls.visible:
		_switch_to_receiver(pl.team)


## A hand-pass: the sliotar in the left hand, struck away with the right palm (a definite striking action, as the
## rules ask), to a teammate a few metres off.
func _hand_pass(pl: Player, to: Player) -> void:
	if not pl.ball_hand:
		return
	_wind_dir(pl, to.global_position)
	pl.play("hand_pass")
	_after(pl.contact_time("hand_pass"), func():
		if carrier != pl:
			return
		var from := pl.body.bone_world("hand_l")
		var target := to.global_position + to.vel * 0.5 + Vector3(0, 1.3, 0)
		var sol := Sliotar.solve(from, target, clampf(from.distance_to(target) * 0.9 + 6.0, 9.0, 18.0))
		var v: Vector3 = sol[0] if not sol.is_empty() else (target - from).normalized() * 12.0
		_release(pl)
		ball.global_position = from
		ball.launch(v, pl, "hand_pass")
		ball.set_meta("t_launch", now)
		ball.set_meta("shot", {})
		_chase_t = 0.0
		_path = []
		Sfx.play("tap", -9.0)
		if user_team >= 0 and pl.team == user_team and controls.visible:
			_switch_to_receiver(pl.team))


## Out of his hand onto the hurley (a solo): the steps start again when he takes it back.
func _do_solo(pl: Player) -> void:
	if not pl.ball_hand or pl.busy():
		return
	pl.play("solo")
	_after(pl.contact_time("solo"), func():
		if carrier != pl:
			return
		pl.ball_hand = false
		pl.ball_stick = true
		Rules.to_hurley(carries[pl])
		Sfx.play("tap", -12.0))


## Off the hurley back into the hand: his second catch of this possession, or a foul if it would be his third.
func _do_to_hand(pl: Player) -> void:
	if not pl.ball_stick or pl.busy():
		return
	pl.play("to_hand")
	_after(pl.contact_time("to_hand"), func():
		if carrier != pl:
			return
		pl.ball_stick = false
		pl.ball_hand = true
		pl.take_steps()
		var foul := Rules.take_in_hand(carries[pl])
		if foul != "":
			_technical_foul(pl, foul))


func _release(pl: Player) -> void:
	Rules.release(carries[pl])
	pl.ball_hand = false
	pl.ball_stick = false
	if carrier == pl:
		carrier = null
	ball.state = Sliotar.FREE


## The goalkeeper sees a shot coming: if it will cross under the bar he goes for it (a dive, a block with the
## hurley), with a chance by his keeping and how near it passes him; if it is dropping short over the bar where he
## can reach, he may catch it.
func _keeper_reacts(shooter_team: int) -> void:
	var k: Player = keeper_of(1 - shooter_team)
	if k == null or not k.on_pitch():
		return
	var d := dir(shooter_team)
	var gx := Pitch.HALF_L * d
	# Where the shot crosses the goal line.
	var p := ball.global_position
	var v := ball.vel
	var t := 0.0
	var dt := 1.0 / 60.0
	while t < 4.0 and (gx - p.x) * d > 0.0:
		var r := Sliotar.fly(p, v, dt)
		p = r[0]
		v = r[1]
		t += dt
	if t >= 4.0 or absf(p.z) > Pitch.POST_GAP * 0.5 + 0.6:
		return
	var reach := k.global_position.distance_to(Vector3(gx, 0, p.z))
	var keep := float(k.data.get("keeping", 70)) / 100.0
	var reaction := maxf(0.05, t - 0.22)
	var cover := 1.0 + reaction * 3.5    # how far he can get to, and reach, in the time
	if p.y < Pitch.BAR_H:
		var chance := clampf((cover - absf(p.z - k.global_position.z) * 0.8) / cover, 0.0, 1.0) * lerpf(0.45, 0.8, keep)
		chance *= clampf(1.3 - v.length() / 45.0, 0.4, 1.0)
		k.play("save", Vector3(p.z - k.global_position.z, 0, 0))
		if rng.randf() < chance:
			_after(minf(t, 1.0) * 0.92, func(): _save(k, d))
	elif p.y < Pitch.BAR_H + 0.6 and rng.randf() < 0.55 * keep:
		# Dropping short, under his hand: he catches it on the line.
		_after(maxf(0.0, t - 0.15), func():
			if ball.state == Sliotar.FREE:
				_gain(k, "catch"))


func _save(k: Player, shooter_dir: float) -> void:
	if ball.state != Sliotar.FREE:
		return
	Sfx.play("save", -4.0)
	Sfx.react("ooh", -4.0)
	if rng.randf() < 0.35:
		# Held.
		_gain(k, "catch")
		hud.call_line(tr("CALL_SAVE"))
		return
	# Parried: out past the post for a 65, or back out into play.
	var out := rng.randf() < 0.5
	var v := Vector3(-shooter_dir * rng.randf_range(4.0, 9.0), rng.randf_range(2.0, 6.0), rng.randf_range(-8.0, 8.0))
	if out:
		v = Vector3(shooter_dir * 3.0, rng.randf_range(3.0, 6.0), signf(rng.randf() - 0.5) * 9.0)
	ball.launch(v, k, "deflect")
	ball.set_meta("t_launch", now)
	ball.set_meta("shot", {})
	_chase_t = 0.0
	hud.call_line(tr("CALL_SAVE"))


func _keeper_spot(k: Player) -> Vector3:
	var own := -dir(k.team)
	var gx := Pitch.HALF_L * own
	var b := ball.global_position
	var to_ball := Vector3(b.x - gx, 0, b.z)
	var near := clampf(1.0 - to_ball.length() / 60.0, 0.0, 1.0)
	var off := 1.0 + near * 2.2
	var z := clampf(b.z * (0.08 + near * 0.06), -2.6, 2.6)
	return Vector3(gx - own * off, 0, z)


# ---------------------------------------------------------------- over a line, off a post

func _check_ball(prev: Vector3, cur: Vector3) -> void:
	# The posts and the crossbar: the sliotar hits them and comes back.
	for s: float in [-1.0, 1.0]:
		var gx := Pitch.HALF_L * s
		if (prev.x - gx) * (cur.x - gx) <= 0.0 and absf(cur.x - prev.x) > 0.0001:
			var k := (gx - prev.x) / (cur.x - prev.x)
			var c := prev.lerp(cur, k)
			var hit_post := absf(absf(c.z) - (Pitch.POST_GAP * 0.5 + Pitch.POST_W * 0.5)) < Pitch.POST_W * 0.5 + Sliotar.RADIUS and c.y < Pitch.POST_H
			var hit_bar := absf(c.z) < Pitch.POST_GAP * 0.5 and absf(c.y - (Pitch.BAR_H + Pitch.POST_W * 0.5)) < Pitch.POST_W * 0.5 + Sliotar.RADIUS
			if hit_post or hit_bar:
				ball.global_position = Vector3(gx - s * 0.1, c.y, c.z)
				ball.vel = Vector3(-ball.vel.x * 0.45, ball.vel.y * 0.6 + (2.0 if hit_bar else 0.0), ball.vel.z * 0.6 + rng.randf_range(-2, 2))
				ball.last_kind = "deflect"
				Sfx.play("post", -2.0)
				Sfx.react("ooh", -3.0)
				hud.call_line(tr("CALL_POST") if hit_post else tr("CALL_BAR"))
				_chase_t = 0.0
				return
			if phase == P.SHOOTOUT:
				_shootout_result(Pitch.score_kind(c), c)
				return
			_over_end_line(c, s)
			return
	if absf(cur.z) > Pitch.HALF_W + Sliotar.RADIUS and phase == P.LIVE:
		var k := (signf(cur.z) * Pitch.HALF_W - prev.z) / maxf(0.0001, cur.z - prev.z)
		var c := prev.lerp(cur, clampf(k, 0.0, 1.0))
		_over_side_line(c)
	if phase == P.SHOOTOUT and ball.state == Sliotar.FREE and ball.vel.length() < 0.5:
		_shootout_result("", ball.global_position)


func _over_end_line(c: Vector3, s: float) -> void:
	# s: the end line at +x (1) or -x (-1). The side attacking it this half:
	var att := 0 if dir(0) == s else 1
	var kind := Pitch.score_kind(c)
	var shot: Dictionary = ball.get_meta("shot", {})
	if not advantage.is_empty():
		advantage.shot = true
	if kind != "":
		# A score: whoever played it last, a ball between the posts scores for the side attacking that goal.
		if Rules.score_counts(kind, ball.last_kind):
			_score(att, kind, shot)
			return
		_disallowed(att, c, s)
		return
	_whistle_dead()
	if ball.last_team == att:
		tstats[att].wides += 1
		var by = shot.get("by")
		if by is Player and is_instance_valid(by):
			pstats[(by as Player).data.id].wides += 1
		officials.umpire_signal(s, "sig_wide", c.z)
		hud.call_line(tr("CALL_WIDE"))
		Sfx.react("groan", -8.0)
		_award(Rules.over_end_line(c, ball.last_team, att, s), 2.2)
	else:
		officials.umpire_signal(s, "sig_65", c.z)
		hud.call_line(tr("CALL_65"))
		_award(Rules.over_end_line(c, ball.last_team, att, s), 2.2)


func _disallowed(att: int, c: Vector3, s: float) -> void:
	# A goal by a hand-pass, a throw or carried in: not allowed; the defenders puck it out.
	_whistle_dead()
	officials.umpire_signal(s, "sig_wide", c.z)
	hud.banner(tr("CALL_NO_GOAL"), Game.C_DANGER)
	hud.call_line(tr("NO_GOAL_HAND"))
	_award({"kind": "puck_out", "team": 1 - att, "spot": Vector3((Pitch.HALF_L - Pitch.SMALL_D * 0.5) * s, 0, 0)}, 2.4)


func _over_side_line(c: Vector3) -> void:
	_whistle_dead()
	var r := Rules.over_side_line(c, ball.last_team)
	officials.linesman_signal(c, dir(int(r.team)))
	hud.call_line(tr("CALL_SIDELINE"))
	_award(r, 1.6)


func _score(team: int, kind: String, shot: Dictionary) -> void:
	_whistle_dead(false)
	var s := Pitch.HALF_L * dir(team)
	var by = shot.get("by")
	var placed := String(shot.get("placed", ""))
	if kind == "goal":
		score[team][0] += 1
		officials.umpire_signal(signf(s), "sig_goal", 0.0)
		hud.banner(tr("CALL_GOAL"), Game.C_GOLD)
		Sfx.react("cheer", 0.0)
		Sfx.play("roar", -2.0)
	else:
		score[team][1] += 1
		officials.umpire_signal(signf(s), "sig_point", 0.0)
		hud.banner(tr("CALL_POINT"), Game.C_INK)
		Sfx.react("cheer", -5.0)
	Crowd.set_excite(1.0 if kind == "goal" else 0.6)
	_after(2.5, func(): Crowd.set_excite(0.0))
	var pid := ""
	if by is Player and is_instance_valid(by) and (by as Player).team == team:
		var bp: Player = by
		pid = String(bp.data.id)
		if kind == "goal":
			pstats[pid].goals += 1
			if placed != "" and placed != "pull":
				pstats[pid].free_g += 1
		else:
			pstats[pid].points += 1
			if placed != "" and placed != "pull":
				pstats[pid].free_p += 1
		bp.play("celebrate")
	if placed != "" and placed != "pull":
		tstats[team].scores_placed += 1
	else:
		tstats[team].scores_play += 1
	events.append({"t": match_minute(), "team": team, "kind": kind, "by": pid, "how": placed if placed != "" else ball.last_kind + ("/shot" if not shot.is_empty() else "")})
	if user_team >= 0 and team == user_team:
		Game.haptic("score")
	for q in teams[1 - team].players:
		if rng.randf() < 0.3:
			(q as Player).play("dejected")
	_stoppage += 20.0
	hud.set_score()
	_award(Rules.after_score(team, dir(team)), 3.2)


## The referee's whistle: the ball dead. A restart is about to be awarded.
func _whistle_dead(sound := true) -> void:
	if sound:
		Sfx.play("whistle", -4.0)
	phase = P.DEAD
	phase_t = 0.0
	if carrier != null:
		_release(carrier)
	ball.state = Sliotar.DEAD
	ball.vel = Vector3.ZERO
	advantage = {}
	officials.end_advantage()
	_puck_travel = {}
	_pending.clear()
	for pl in all_players():
		var p: Player = pl
		if p.busy() and not (p.action in ["celebrate", "dejected", "fall"]):
			p.stop_action()


# ---------------------------------------------------------------- the tackle and its fouls

## The men pressing the ball-carrier try to dispossess him: a side-to-side shoulder, a flick off his hurley as he
## solos, a hook from behind or a block from in front as he strikes. Each can be a foul: from behind, too late, too
## high with the hurley, a pull or a trip when he is through on goal.
func _tackles(_dt: float) -> void:
	if carrier == null or phase != P.LIVE:
		return
	var c := carrier
	for q in teams[1 - c.team].players:
		var d: Player = q
		if not d.on_pitch() or d.busy() or d.down(now) or d.is_keeper():
			continue
		var dist := d.global_position.distance_to(c.global_position)
		if dist > (2.6 if c.action in ["strike", "strike_stick"] else 1.5):
			continue
		if now < float(_cooldown.get(d, 0.0)):
			continue
		if d == active and controls.visible:
			continue   # your player tackles when you press
		var rate := 0.9 * float(d.data.get("tackling", 70)) / 75.0 * float(ai[d.team].skill)
		if rng.randf() > rate * get_process_delta_time() * 3.0:
			continue
		_tackle(d, c)
		return


func _tackle(d: Player, c: Player) -> void:
	_cooldown[d] = now + rng.randf_range(0.9, 1.6)
	var to_c := c.global_position - d.global_position
	to_c.y = 0
	var behind := c.forward().dot(to_c.normalized()) > 0.5      # coming in from behind him
	var kind := "tackle"
	if c.action in ["strike", "strike_stick"] and c.action_t < c.contact_time(c.action):
		kind = "hook" if behind else "block"
	elif c.ball_stick:
		kind = "flick"
	d.play(kind, Vector3.ZERO, -1.0 if to_c.cross(Vector3.UP).dot(c.forward()) > 0.0 else 1.0)
	var tk := float(d.data.get("tackling", 70)) / 100.0
	var through := _goal_chance(c)
	var foul_p := 0.08 + (0.22 if behind and kind in ["tackle", "hook"] else 0.0) - tk * 0.06
	if through:
		# The cynical foul: a pull-down or a trip to stop a goal. Rare (a penalty and the sin bin cost more than
		# the goal chance most times): about one black card in four or five senior games.
		foul_p *= 0.3
	# Defenders in their own large rectangle, where a foul is a penalty, go in more carefully.
	if Pitch.in_large_rect(c.global_position, dir(c.team)):
		foul_p *= 0.35
	if int(Game.settings.get("difficulty", 1)) == 0 and c.team == user_team:
		foul_p += 0.04
	var ok_p: float = {"tackle": 0.22, "flick": 0.38, "hook": 0.45, "block": 0.5}[kind] * lerpf(0.7, 1.2, tk)
	_after(d.contact_time(kind), func():
		if carrier != c or phase != P.LIVE:
			return
		if d.global_position.distance_to(c.global_position) > 2.8:
			return
		var r := rng.randf()
		if r < foul_p:
			var foul := "FOUL_PUSH"
			match kind:
				"tackle":
					foul = ["FOUL_PULL_DOWN", "FOUL_TRIP", "FOUL_HOLD_MAN"][rng.randi() % 3] if through else ("FOUL_CHARGE" if behind else ["FOUL_PUSH", "FOUL_HOLD_MAN"][rng.randi() % 2])
				"hook", "flick":
					foul = "FOUL_HOOK_HURLEY" if not through else "FOUL_HURLEY"
				"block":
					foul = "FOUL_HURLEY" if rng.randf() < 0.4 else "FOUL_PUSH"
			_aggressive_foul(d, c, foul, through)
			return
		if r < foul_p + ok_p:
			_dispossess(d, c, kind)
		elif c == active:
			Game.haptic("tackled"))


## The tackle wins the ball: the strike is hooked or blocked, the sliotar knocked off his hurley or out of his hand.
func _dispossess(d: Player, c: Player, kind: String) -> void:
	var away := (c.global_position - d.global_position)
	away.y = 0
	_release(c)
	c.stop_action()
	var v := away.normalized() * rng.randf_range(2.0, 6.0) + Vector3(rng.randf_range(-2, 2), rng.randf_range(0.5, 3.0), rng.randf_range(-2, 2))
	if kind == "block":
		v = Vector3(rng.randf_range(-6, 6), rng.randf_range(3, 8), rng.randf_range(-6, 6))
	ball.global_position = c.global_position + Vector3(0, 0.6, 0) + c.forward() * 0.5
	ball.launch(v, d, "deflect")
	ball.set_meta("t_launch", now - 0.6)
	ball.set_meta("shot", {})
	_chase_t = 0.0
	_path = []
	Sfx.play("clash", -4.0, rng.randf_range(0.9, 1.1))
	hud.call_line(tr({"tackle": "CALL_SHOULDER", "flick": "CALL_FLICK", "hook": "CALL_HOOK", "block": "CALL_BLOCK"}[kind]))
	if c == active:
		Game.haptic("tackled")
	if rng.randf() < 0.18:
		c.play("fall")
		c.down_until = now + 1.2


## Is the carrier through on goal: inside the 20 m line or the arc, in front of the posts, with the goal before him?
func _goal_chance(c: Player) -> bool:
	var d := dir(c.team)
	var p := c.global_position
	var inside := Pitch.from_goal_line(p, d) <= 20.0 or Pitch.penalty_spot(d).distance_to(Vector3(p.x, 0, p.z)) <= Pitch.ARC_R
	if not inside or absf(p.z) > 14.0:
		return false
	# No other defender (the goalkeeper aside) between him and the goal.
	var gx := Pitch.HALF_L * d
	for q in teams[1 - c.team].players:
		var o: Player = q
		if o.is_keeper() or not o.on_pitch():
			continue
		if (o.global_position.x - p.x) * d > 0.5 and absf(o.global_position.z - p.z) < 4.0 and (gx - o.global_position.x) * d > 0.0:
			return false
	return true


## An aggressive foul: the referee plays advantage if the fouled side has the ball with time and space (or a clear
## chance), else blows for the free (or the penalty), and shows the card it calls for.
func _aggressive_foul(by: Player, on: Player, foul: String, denial: bool) -> void:
	var fouled := on.team
	var spot := on.global_position
	var award := Rules.free_for(foul, spot, fouled, dir(fouled), denial)
	var card := Rules.card_for(foul, denial or rng.randf() < 0.25, denial, grade, by.yellows, by.blacks)
	if foul in ["FOUL_PULL_DOWN", "FOUL_TRIP", "FOUL_CHARGE"] and rng.randf() < 0.6:
		on.play("fall")
		on.down_until = now + 1.1
		if carrier == on:
			_release(on)
			ball.launch(Vector3(rng.randf_range(-3, 3), 1.0, rng.randf_range(-3, 3)), on, "deflect")
	var keeps := carrier == on and not on.down(now)
	var space := nearest_opponent(on, 3.0) == null or rng.randf() < 0.3
	if keeps and String(award.kind) != "penalty" and Rules.may_play_advantage(foul, _goal_chance(on), space):
		advantage = {"team": fouled, "foul": foul, "award": award, "by": by, "card": card, "until": now + Rules.ADVANTAGE_S, "shot": false}
		officials.signal_advantage()
		hud.call_line(tr("CALL_ADVANTAGE"))
		return
	_blow_free(by, foul, award, card, denial)


func _technical_foul(by: Player, foul: String) -> void:
	var fouled := 1 - by.team
	var award := Rules.free_for(foul, by.global_position, fouled, dir(fouled), false)
	_blow_free(by, foul, award, "", false)


func _blow_free(by: Player, foul: String, award: Dictionary, card: String, denial: bool) -> void:
	_whistle_dead()
	tstats[int(award.team)].frees += 1
	officials.signal_free(award, dir(int(award.team)))
	var line := tr(foul) + " · " + tr("FREE_TO").format({"team": DB.short_name(String(teams[int(award.team)].id))})
	if String(award.kind) == "penalty":
		hud.banner(tr("CALL_PENALTY"), Game.C_GOLD)
	else:
		hud.banner(tr("CALL_FREE"), Game.C_INK)
	hud.call_line(line)
	if by == active or (by.team == user_team and controls.visible):
		Game.haptic("free")
	if card != "":
		_after(0.9, func(): _show_card(by, card))
	_award(award, 2.2 + (1.5 if card != "" else 0.0))
	events.append({"t": match_minute(), "team": by.team, "kind": "foul", "by": String(by.data.id), "how": foul})
	# Now and then a player protests the decision (dissent, 2026): the free goes 30 m on.
	if rng.randf() < 0.03 and String(award.kind) == "free":
		_after(1.4, func():
			if restart.is_empty():
				return
			restart.spot = Rules.dissent_spot(restart.spot, dir(int(restart.team)))
			ball.place(restart.spot)
			hud.call_line(tr("CALL_DISSENT")))


func _show_card(pl: Player, card: String) -> void:
	officials.show_card(pl, card)
	_stoppage += 40.0
	var name := DB.player_name(pl.data, true)
	match card:
		"yellow":
			pl.yellows += 1
			tstats[pl.team].yellow += 1
			hud.banner(tr("CARD_YELLOW"), Color("f2d21e"))
		"black":
			pl.blacks += 1
			tstats[pl.team].black += 1
			pl.sin_bin_until = total_clock() + Rules.SIN_BIN_MIN * 60.0
			hud.banner(tr("CARD_BLACK"), Color("dddddd"))
			hud.call_line(tr("SIN_BIN_LINE").format({"name": name}))
		"red":
			pl.sent_off = true
			if pl.yellows > 0:
				hud.call_line(tr("SECOND_YELLOW").format({"name": name}))
			tstats[pl.team].red += 1
			hud.banner(tr("CARD_RED"), Color("d4202a"))
	events.append({"t": match_minute(), "team": pl.team, "kind": card, "by": String(pl.data.id), "how": ""})
	if pl.team == user_team and controls.visible:
		Game.haptic("card")
	if pl == carrier:
		_release(pl)
	if pl == active:
		_switch()


func _walk_off(pl: Player) -> void:
	var off := Vector3(pl.global_position.x, 0, -Pitch.HALF_W - 5.0)
	_steer(pl, off, 3.0)
	if pl.global_position.distance_to(off) < 1.0:
		pl.visible = false


## A player in the sin bin comes back once his ten minutes are up, at a break in play.
func _sin_bins() -> void:
	for pl in all_players():
		var p: Player = pl
		if p.sin_bin_until >= 0.0 and not p.sent_off and total_clock() >= p.sin_bin_until and phase != P.LIVE:
			p.sin_bin_until = -1.0
			p.visible = true


## Advantage: up to five seconds (Rules.ADVANTAGE_S, shortened with the clock) to see if the fouled side gains. A
## shot, a score or a good pass is the advantage; if they lose the ball first, the free.
func _advantage_step() -> void:
	if advantage.is_empty():
		return
	if bool(advantage.get("shot", false)) or now > float(advantage.until):
		var card: String = advantage.card
		var by: Player = advantage.by
		advantage = {}
		officials.end_advantage()
		if card != "" and is_instance_valid(by):
			_after(0.1, func(): _show_card(by, card))
		return
	if carrier != null and carrier.team != int(advantage.team):
		_advantage_lost()


func _advantage_lost() -> void:
	var a := advantage
	advantage = {}
	officials.end_advantage()
	_blow_free(a.by, a.foul, a.award, a.card, false)


# ---------------------------------------------------------------- restarts

## A restart is due: the players go to their places once the signals are made (after delay), the taker to the ball.
func _award(r: Dictionary, delay := 2.0) -> void:
	restart = r
	taker = null
	phase = P.DEAD
	phase_t = DEAD_T - delay
	_stoppage += 8.0
	match String(r.kind):
		"puck_out":
			tstats[int(r.team)].puckouts += 1
		"65":
			tstats[int(r.team)].s65 += 1
		"sideline":
			tstats[int(r.team)].sidelines += 1


func _begin_setup() -> void:
	if restart.is_empty():
		_begin_throw_in()
		return
	# The end of a half comes at a break in play once the time is up.
	if _time_up() and String(restart.kind) != "penalty":
		_end_half()
		return
	phase = P.SETUP
	phase_t = 0.0
	ball.place(restart.spot)
	taker = _pick_taker(restart)
	if user_team >= 0 and int(restart.team) == user_team and controls.visible:
		_set_active(taker)
	elif user_team >= 0 and controls.visible:
		_set_active(nearest_to(user_team, ball.global_position))
	hud.restart_tag(restart)
	_sideline_taker = null


func _pick_taker(r: Dictionary) -> Player:
	var k := int(r.team)
	match String(r.kind):
		"puck_out":
			return keeper_of(k)
		"free", "65", "penalty":
			var spot: Vector3 = r.spot
			var from_goal := Pitch.from_goal_line(spot, dir(k))
			if from_goal > 95.0:
				# Deep in his own half: a defender nearby strikes it long, as they do.
				return nearest_to(k, spot)
			var best: Player = null
			for q in teams[k].players:
				var p: Player = q
				if p.on_pitch() and not p.is_keeper() and (best == null or int(p.data.free) > int(best.data.free)):
					best = p
			return best
		_:
			return nearest_to(k, r.spot)


## Where everyone goes for the set piece: the taker to the ball; the rest to their places, kept where the rules want
## them (Rules.position_ok): 13 m from a free, outside the 20 m line at a puck-out, one defender on the line for a
## penalty, the rest outside the 20 m line and the arc.
func _set_spot(pl: Player) -> Vector3:
	if pl == taker:
		var behind := -Vector3(dir(pl.team), 0, 0) * 0.9
		if String(restart.kind) == "sideline":
			behind = Vector3(0, 0, signf(restart.spot.z) * 0.9)
		return restart.spot + behind
	var kind := String(restart.kind)
	var k := int(restart.team)
	var t: TeamAI = ai[pl.team]
	var spot: Vector3
	if pl.is_keeper():
		spot = Vector3(Pitch.HALF_L * -dir(pl.team), 0, 0) + Vector3(dir(pl.team) * 1.5, 0, 0)
		if kind == "penalty" and pl.team != k:
			spot = Vector3(Pitch.HALF_L * dir(k), 0, 0)
	elif pl.team == k:
		spot = t.attack_spot(pl, taker)
	else:
		spot = t.defend_spot(pl)
	return legal_spot(spot, pl)


## The nearest legal place to spot for pl at the coming restart.
func legal_spot(spot: Vector3, pl: Player) -> Vector3:
	var kind := String(restart.kind)
	var k := int(restart.team)
	var d := dir(k)
	var rs: Vector3 = restart.spot
	match kind:
		"puck_out":
			if not pl.is_keeper() and pl != taker:
				# Outside the 20 m line of the end the puck-out is taken from (the taking side's own end, at -d).
				var line_x := (-Pitch.HALF_L + Rules.PUCK_OUT_CLEAR + 1.5) * d
				if (spot.x - line_x) * d < 0.0:
					spot.x = line_x
		"penalty":
			if not (pl.is_keeper() and pl.team != k):
				var lim := (Pitch.HALF_L - 20.0 - 1.0) * d
				if (spot.x - lim) * d > 0.0:
					spot.x = lim
				var c := Pitch.penalty_spot(d)
				var off := Vector3(spot.x, 0, spot.z) - c
				if off.length() < Pitch.ARC_R + 1.0:
					spot = c + (off.normalized() if off.length() > 0.1 else Vector3(-d, 0, 0)) * (Pitch.ARC_R + 1.0)
		_:
			if pl.team != k:
				var off := Vector3(spot.x - rs.x, 0, spot.z - rs.z)
				if off.length() < Rules.FREE_DISTANCE + 0.5:
					spot = rs + (off.normalized() if off.length() > 0.1 else Vector3(-d, 0, 0)) * (Rules.FREE_DISTANCE + 0.5)
	return Pitch.clamp_in(spot, 0.5)


func _setup_step() -> void:
	if taker == null or not is_instance_valid(taker):
		taker = _pick_taker(restart)
	var at := taker.global_position.distance_to(restart.spot) < 1.4
	if (at and phase_t > 1.6) or phase_t > SETUP_MAX:
		phase = P.SET
		phase_t = 0.0
		_set_t = rng.randf_range(0.8, 2.0)
		if String(restart.kind) in ["puck_out"]:
			_set_t = rng.randf_range(0.5, 1.4)
		# The taker has the ball: in his hand for a puck-out, at his feet for the rest.
		carrier = null
		ball.place(restart.spot)


## The set piece is ready: the computer's taker takes it after a moment; yours when you press (or after 12 s).
func _set_step(_dt: float) -> void:
	if taker.busy():
		return
	var yours := user_team >= 0 and taker.team == user_team and controls.visible
	if yours and phase_t < 8.0:
		return
	if phase_t < _set_t:
		return
	_take_restart(taker, "")


## Take the restart: choice "" for the AI's own choice, else what you pressed ("STRIKE", "PASS", "SHORT", "LONG",
## "GOAL").
func _take_restart(pl: Player, choice: String) -> void:
	var kind := String(restart.kind)
	var k := pl.team
	var d := dir(k)
	var t: TeamAI = ai[k]
	var spot: Vector3 = restart.spot
	_stoppage += 4.0
	phase = P.LIVE
	phase_t = 0.0
	hud.restart_tag({})
	carrier = pl
	_last_owner = k
	ball.state = Sliotar.HELD
	ball.holder = pl
	pl.ball_hand = kind == "puck_out"
	pl.ball_stick = false
	Rules.release(carries[pl])
	restart = {}
	match kind:
		"puck_out":
			var po: Dictionary = t.puck_out_choice(pl)
			if choice == "SHORT" or (choice == "" and String(po.kind) == "short"):
				var to: Player = po.get("to") if po.has("to") else _short_option(pl)
				if choice == "SHORT":
					to = _short_option(pl, controls.joystick)
				_strike_pass(pl, to, "puck_out")
			else:
				var land: Vector3 = po.get("target", Vector3((-Pitch.HALF_L + 80.0) * d, 0, 0))
				if choice == "LONG" and controls.joystick.length() > 0.3:
					land = Pitch.clamp_in(spot + _cam_dir(controls.joystick) * 80.0, 6.0)
				_strike_to(pl, land, "puck_out")
		"penalty":
			_shoot(pl, true, "penalty")
		"sideline":
			var dist := Pitch.from_goal_line(spot, d)
			if (choice == "STRIKE" and dist < 60.0) or (choice == "" and dist < 38.0 and rng.randf() < 0.5):
				_shoot(pl, false, "sideline")
			else:
				var to: Player = _pass_option(pl, controls.joystick if choice != "" else Vector2.ZERO)
				if to != null:
					_strike_pass(pl, to, "sideline")
				else:
					_strike_to(pl, Pitch.clamp_in(spot + Vector3(d * 40.0, 0, -signf(spot.z) * 25.0), 5.0), "sideline")
		_:
			# A free or a 65: lifted and struck, at the posts when in range.
			var dist := Pitch.from_goal_line(spot, d)
			var off := absf(spot.z)
			var chance := TeamAI.shot_chance(pl, dist, off, 99.0) * (1.08 if dist < 75.0 else 1.0)
			var shoot := chance > 0.42 or kind == "65"
			if choice == "PASS":
				shoot = false
			elif choice == "STRIKE" or choice == "GOAL":
				shoot = true
			var placed := "65" if kind == "65" else "free"
			if shoot:
				_shoot(pl, choice == "GOAL" or (choice == "" and dist <= 21.0 and rng.randf() < 0.15), placed)
			else:
				var to: Player = _pass_option(pl, controls.joystick if choice != "" else Vector2.ZERO)
				if to != null:
					_strike_pass(pl, to, placed)
				else:
					_strike_to(pl, Pitch.clamp_in(spot + Vector3(d * 50.0, 0, 0), 5.0), placed)


func _short_option(pl: Player, joy := Vector2.ZERO) -> Player:
	var best: Player = null
	var bv := -1e9
	for q in teams[pl.team].players:
		var r: Player = q
		if r == pl or not r.on_pitch() or not (r.line() in [DB.POS_FB, DB.POS_HB]):
			continue
		var dd := r.global_position.distance_to(pl.global_position)
		if dd < Rules.PUCK_OUT_TRAVEL + 2.0:
			continue
		var v := -dd * 0.2 + float(ai[pl.team]._openness(r))
		if joy.length() > 0.3:
			v += _cam_dir(joy).dot((r.global_position - pl.global_position).normalized()) * 20.0
		if v > bv:
			bv = v
			best = r
	return best if best != null else nearest_to(pl.team, pl.global_position + Vector3(dir(pl.team) * 30.0, 0, 0))


## The teammate in the joystick's direction (or the AI's best), for a pass.
func _pass_option(pl: Player, joy: Vector2) -> Player:
	if joy.length() < 0.3:
		var b: Dictionary = ai[pl.team].best_pass(pl, 99.0)
		return b.get("to")
	var want := _cam_dir(joy)
	var best: Player = null
	var bv := -1e9
	for q in teams[pl.team].players:
		var r: Player = q
		if r == pl or not r.on_pitch() or r.is_keeper():
			continue
		var to := r.global_position - pl.global_position
		var dd := to.length()
		if dd < 4.0 or dd > 75.0:
			continue
		var v := want.dot(to / dd) * 30.0 - dd * 0.15 + float(ai[pl.team]._openness(r)) * 0.8
		if v > bv:
			bv = v
			best = r
	return best


# ---------------------------------------------------------------- the throw-in, the halves

func _throw_in_spot(pl: Player) -> Vector3:
	var d := dir(pl.team)
	if pl.line() == DB.POS_MF:
		# The two midfielders on their own side of the halfway line, beside the referee.
		return Vector3(-d * 1.2, 0, 1.2 if pl.num == 8 else -1.2)
	var home: Vector3 = ai[pl.team].home_spot(pl)
	# Everyone else in position, out of the centre.
	if absf(home.x) < 10.0 and absf(home.z) < 10.0:
		home.z += 12.0 * signf(home.z + 0.01)
	return home


func _place_for_throw_in(snap: bool) -> void:
	if snap:
		ball.place(Vector3.ZERO)
		for pl in all_players():
			var p: Player = pl
			p.position = _throw_in_spot(p)
			p.vel = Vector3.ZERO
			p.yaw = atan2(dir(p.team), 0.0)
			p.body.rotation.y = p.yaw
		officials.place_for_throw_in()


func _begin_throw_in() -> void:
	phase = P.THROW_IN
	phase_t = 0.0
	restart = {}
	carrier = null
	ball.place(Vector3(0, 1.6, 0))
	officials.throw_in()
	_after(0.55, func():
		Sfx.play("whistle", -4.0)
		ball.global_position = Vector3(0, 1.7, 0)
		ball.launch(Vector3(rng.randf_range(-0.6, 0.6), 7.5, rng.randf_range(-0.6, 0.6)), null, "throw_in")
		ball.last_team = -1
		ball.set_meta("t_launch", now - 1.0)
		ball.set_meta("shot", {})
		_chase_t = 0.0
		_path = []
		phase = P.LIVE)
	if user_team >= 0 and controls.visible:
		_set_active(player_by_num(user_team, 8))


func _time_up() -> bool:
	return clock >= half_len_now() + added


## Added time: shown in whole minutes as the half's time comes up (two or three minutes a half is usual: the
## stoppages, the scores, the cards), the referee ending the half at the first break once it is up, or once the
## ball is out of the scoring zones.
func _end_of_half_check() -> void:
	if not _added_shown and clock >= half_len_now() - 60.0:
		_added_shown = true
		var mins := clampi(roundi(_stoppage / 60.0 * 0.5) + 1, 1, 6) if half <= 2 else 1
		added = mins * 60.0
		hud.added_time(mins)
	if not _time_up():
		return
	var b := ball.global_position
	var neutral := absf(b.x) < Pitch.HALF_L - 45.0
	if (neutral and carrier == null) or clock > half_len_now() + added + 45.0:
		_end_half()


func _end_half() -> void:
	Sfx.play("whistle_long", -2.0)
	phase = P.HALF_TIME
	phase_t = 0.0
	if carrier != null:
		_release(carrier)
	ball.state = Sliotar.DEAD
	_pending.clear()
	advantage = {}
	var level: bool = Rules.total(score[0][0], score[0][1]) == Rules.total(score[1][0], score[1][1])
	if half == 2 and not (knockout and level):
		_finish()
		return
	if half == 4:
		if level:
			_begin_shootout()
			return
		_finish()
		return
	hud.half_time(half)


func _second_half() -> void:
	half += 1
	clock = 0.0
	added = 0.0
	_added_shown = false
	_stoppage = 0.0
	hud.end_half_time()
	_place_for_throw_in(true)
	phase = P.INTRO
	phase_t = 1.2
	hud.set_score()


# ---------------------------------------------------------------- the shoot-out

## Level after extra time in a knock-out game: five penalties each from the 20 m line, goals only, then sudden
## death, the same five taking them again.
func _begin_shootout() -> void:
	phase = P.SHOOTOUT
	phase_t = 0.0
	half = 4
	var order := [[], []]
	for k in 2:
		var ps: Array = teams[k].players.filter(func(p): return (p as Player).on_pitch() and not (p as Player).is_keeper())
		ps.sort_custom(func(a, b): return int(a.data.accuracy) + int(a.data.free) > int(b.data.accuracy) + int(b.data.free))
		order[k] = ps.slice(0, Rules.SHOOTOUT_TAKERS)
	shootout = {"goals": [0, 0], "taken": [0, 0], "next": rng.randi() % 2, "order": order, "state": "walk", "t": 0.0}
	hud.shootout(shootout)
	_shootout_next()


func _shootout_goal_dir() -> float:
	return 1.0


func _shootout_spot(pl: Player) -> Vector3:
	var gx := Pitch.HALF_L * _shootout_goal_dir()
	if pl == taker:
		return Pitch.penalty_spot(1.0) + Vector3(-0.9, 0, 0)
	if pl.is_keeper() and pl.team != int(shootout.next):
		return Vector3(gx, 0, 0)
	# Everyone else at the halfway line, the goalkeeper waiting his turn beside them.
	var i: int = teams[pl.team].players.find(pl)
	return Vector3(-2.0 - (pl.team * 2.0), 0, -20.0 + i * 2.6)


func _shootout_next() -> void:
	var k := int(shootout.next)
	var n := int(shootout.taken[k])
	var order: Array = shootout.order[k]
	taker = order[n % order.size()]
	shootout.state = "walk"
	shootout.t = now
	ball.place(Pitch.penalty_spot(1.0))
	restart = {"kind": "penalty", "team": k, "spot": Pitch.penalty_spot(1.0)}
	if user_team >= 0 and controls.visible:
		_set_active(taker if k == user_team else keeper_of(user_team))


func _shootout_step(_dt: float) -> void:
	if String(shootout.state) == "walk":
		if (taker.global_position.distance_to(restart.spot) < 1.5 and now - float(shootout.t) > 3.0) or now - float(shootout.t) > 8.0:
			shootout.state = "ready"
			shootout.t = now
	elif String(shootout.state) == "ready":
		var yours := user_team >= 0 and taker.team == user_team and controls.visible
		if (not yours and now - float(shootout.t) > 1.2) or now - float(shootout.t) > 8.0:
			_shootout_strike("")
	elif String(shootout.state) == "done":
		if now - float(shootout.t) > 2.2:
			var w := Rules.shootout_winner(shootout.goals, shootout.taken)
			if w >= 0:
				_finish(w)
				return
			shootout.next = 1 - int(shootout.next)
			_shootout_next()


func _shootout_strike(_choice: String) -> void:
	shootout.state = "struck"
	carrier = taker
	ball.state = Sliotar.HELD
	taker.ball_hand = false
	taker.ball_stick = false
	_shoot(taker, true, "penalty")


func _shootout_result(kind: String, _c: Vector3) -> void:
	if String(shootout.get("state", "")) != "struck":
		return
	var k := int(shootout.next)
	shootout.taken[k] += 1
	var scored := Rules.shootout_counts(kind) and ball.last_team == k and ball.last_kind == "penalty"
	if scored:
		shootout.goals[k] += 1
		hud.banner(tr("CALL_GOAL"), Game.C_GOLD)
		Sfx.react("cheer", -2.0)
	else:
		hud.banner(tr("CALL_SAVED") if kind == "" else tr("CALL_MISSED"), Game.C_INK)
		Sfx.react("groan", -4.0)
	if not shootout.has("log"):
		shootout.log = []
	(shootout.log as Array).append([k, scored])
	ball.state = Sliotar.DEAD
	ball.vel = Vector3.ZERO
	shootout.state = "done"
	shootout.t = now
	hud.shootout(shootout)


# ---------------------------------------------------------------- full time

func _finish(shootout_winner := -1) -> void:
	phase = P.OVER
	phase_t = 0.0
	Sfx.play("whistle_long", -2.0)
	var a := Rules.total(score[0][0], score[0][1])
	var b := Rules.total(score[1][0], score[1][1])
	var winner := 0 if a > b else (1 if b > a else shootout_winner)
	if winner >= 0:
		for q in teams[winner].players:
			(q as Player).play("celebrate")
		Sfx.react("cheer", 0.0)
	if attract:
		_after(3.0, func(): _restart_attract())
		return
	hud.full_time(winner)
	var result := {"config": config, "home": String(teams[0].id), "away": String(teams[1].id), "score": score.duplicate(true),
		"winner": winner, "user_team": user_team, "pstats": pstats, "tstats": tstats, "events": events,
		"extra_time": half >= 3, "shootout": shootout.duplicate(true) if not shootout.is_empty() else {},
		"star": _player_of_match(winner)}
	_after(4.5, func(): Game.on_match_finished(result))


## The best player on the pitch: the top scorer of the winning side (goals counted as three).
func _player_of_match(winner: int) -> String:
	var best := ""
	var bv := -1
	for id in pstats:
		var s: Dictionary = pstats[id]
		var v := int(s.goals) * 3 + int(s.points)
		if winner >= 0 and int(s.team) == winner:
			v += 2
		if v > bv:
			bv = v
			best = id
	return best


func _restart_attract() -> void:
	score = [[0, 0], [0, 0]]
	half = 1
	clock = 0.0
	_place_for_throw_in(true)
	phase = P.INTRO
	phase_t = 0.0


# ---------------------------------------------------------------- your player

func _set_active(pl: Player) -> void:
	if pl == null or user_team < 0:
		return
	active = pl
	hud.set_active(pl)


## Your player changes: to the teammate best placed for the ball (or the one it is passed to).
func _switch() -> void:
	if user_team < 0:
		return
	var best: Player = null
	if ball.state == Sliotar.FREE and not chasers[user_team].is_empty():
		best = chasers[user_team][0]
		if best == active and chasers[user_team].size() > 1:
			best = chasers[user_team][1]
	else:
		var target := carrier.global_position if carrier != null else ball.global_position
		var bd := 1e9
		for q in teams[user_team].players:
			var p: Player = q
			if p == active or not p.on_pitch() or p.is_keeper():
				continue
			var d := p.global_position.distance_to(target)
			if d < bd:
				bd = d
				best = p
	if best != null:
		_set_active(best)


func _switch_to_receiver(k: int) -> void:
	_path = Sliotar.path(ball.global_position, ball.vel, 5.0)
	_path_t = now
	chasers[k] = _pick_chasers(k)
	if not chasers[k].is_empty():
		_set_active(chasers[k][0])


## The joystick, as a direction on the pitch from the camera's view.
func _cam_dir(j: Vector2) -> Vector3:
	var b := cam.camera.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	return (right * j.x - fwd * j.y).normalized() if j.length() > 0.05 else Vector3.ZERO


var _idle_t := 0.0


func _user_move(pl: Player, dt: float) -> void:
	var j: Vector2 = controls.joystick
	pl.face_to = Vector3.ZERO
	if phase == P.SET and pl == taker:
		pl.want_vel = Vector3.ZERO
		pl.face_to = pl.global_position + (_cam_dir(j) if j.length() > 0.2 else Vector3(dir(pl.team), 0, 0)) * 10.0
		return
	if j.length() > 0.12:
		_idle_t = 0.0
		pl.want_vel = _cam_dir(j) * pl.top_speed() * clampf(j.length() * 1.15, 0.0, 1.0)
		return
	# Hands off the joystick: he keeps his place in the side's shape (Full assist: he runs for the ball too).
	_idle_t += dt
	if pl == carrier:
		pl.want_vel = Vector3.ZERO
		return
	var t: TeamAI = ai[pl.team]
	var target := pl.global_position
	if phase in [P.SETUP, P.SET]:
		target = _set_spot(pl)
	elif ball.state == Sliotar.FREE and int(Game.settings.get("assist", 1)) >= 2 and pl in chasers[pl.team]:
		target = _chase_target(pl)
	elif carrier != null and carrier.team == pl.team:
		target = t.attack_spot(pl, carrier)
	elif carrier != null:
		target = t.defend_spot(pl)
	else:
		target = t.home_spot(pl)
	if _idle_t > 0.6:
		_steer(pl, target, _jog(pl, target))
	else:
		pl.want_vel = Vector3.ZERO


## The buttons for what your player can do now.
func user_buttons() -> Array:
	if user_team < 0 or active == null or not controls.visible:
		return []
	var a := active
	var b := ball.global_position
	if phase == P.SET and a == taker:
		match String(restart.kind):
			"puck_out":
				return ["LONG", "SHORT"]
			"penalty":
				return ["GOAL"]
			"sideline":
				return ["STRIKE", "PASS"]
			_:
				return ["STRIKE", "PASS"] + (["GOAL"] if Pitch.from_goal_line(restart.spot, dir(a.team)) <= 21.0 else [])
	if phase == P.SHOOTOUT:
		return ["GOAL"] if a == taker and String(shootout.get("state", "")) == "ready" else []
	if phase != P.LIVE:
		return []
	if a == carrier:
		var out := ["STRIKE"]
		var dist := Pitch.from_goal_line(a.global_position, dir(a.team))
		if dist < 30.0 and absf(a.global_position.z) < 18.0:
			out.append("GOAL")
		if a.ball_hand:
			out.append("PASS")
			out.append("SOLO")
		elif a.ball_stick:
			out.append("PASS")
			if carries[a].catches < Rules.MAX_CATCHES:
				out.append("HAND")
		return out
	var out := []
	if ball.state == Sliotar.FREE:
		var hd := Vector2(b.x - a.global_position.x, b.z - a.global_position.z).length()
		if hd < REACH + 1.4 and b.y < CATCH_H + 0.6:
			out = ["CATCH" if b.y > 1.3 else "LIFT", "PULL"]
	elif carrier != null and carrier.team != a.team:
		var cd := carrier.global_position.distance_to(a.global_position)
		if cd < 3.5:
			out = ["TACKLE", "BLOCK"] if carrier.action in ["strike", "strike_stick"] else ["TACKLE"]
	out.append("SWITCH")
	return out


func _user_buttons() -> void:
	var ids := user_buttons()
	if ids != controls.ids:
		controls.set_buttons(ids)


func _on_action(id: String) -> void:
	if paused or active == null:
		return
	var a := active
	if id == "SWITCH":
		_switch()
		return
	if phase == P.SET and a == taker:
		_take_restart(a, id)
		return
	if phase == P.SHOOTOUT and a == taker and id == "GOAL":
		_shootout_strike(id)
		return
	if phase != P.LIVE or a.busy():
		return
	var j: Vector2 = controls.joystick
	match id:
		"STRIKE":
			if a != carrier:
				return
			var want := _cam_dir(j)
			var to_goal := (Vector3(Pitch.HALF_L * dir(a.team), 0, 0) - a.global_position).normalized()
			var dist := Pitch.from_goal_line(a.global_position, dir(a.team))
			if (j.length() < 0.3 or want.dot(to_goal) > 0.5) and dist < 85.0:
				_shoot(a, false)
			else:
				var to: Player = _pass_option(a, j)
				if to != null:
					_strike_pass(a, to)
				else:
					_strike_to(a, Pitch.clamp_in(a.global_position + (want if want != Vector3.ZERO else to_goal) * 45.0, 4.0))
		"GOAL":
			if a == carrier:
				_shoot(a, true)
		"PASS":
			if a != carrier:
				return
			var to: Player = _pass_option(a, j)
			if to == null:
				return
			if a.ball_hand and a.global_position.distance_to(to.global_position) < 16.0:
				_hand_pass(a, to)
			else:
				_strike_pass(a, to)
		"SOLO":
			_do_solo(a)
		"HAND":
			_do_to_hand(a)
		"CATCH", "LIFT":
			if ball.state == Sliotar.FREE:
				_attempt(a, "catch" if id == "CATCH" else "lift")
		"PULL":
			# First time: struck on the run, on the ground or in the air, without taking it.
			if ball.state == Sliotar.FREE:
				_pull(a)
		"TACKLE":
			if carrier != null and carrier.team != a.team:
				_tackle(a, carrier)
		"BLOCK":
			if carrier != null and carrier.team != a.team:
				_tackle(a, carrier)


func _pull(a: Player) -> void:
	var kind := "pull" if ball.global_position.y > 0.7 else "ground"
	a.play(kind)
	_after(a.contact_time(kind), func():
		if ball.state != Sliotar.FREE:
			return
		var b := ball.global_position
		if Vector2(b.x - a.global_position.x, b.z - a.global_position.z).length() > REACH + 0.6 or b.y > CATCH_H:
			return
		var d := dir(a.team)
		var want := _cam_dir(controls.joystick)
		var target := Vector3(Pitch.HALF_L * d, Pitch.BAR_H + 2.0, 0) if want == Vector3.ZERO else b + want * 40.0
		var aim := target + Vector3(0, 0, rng.randfn(0.0, 3.0))
		var sol := Sliotar.solve(b, aim, 30.0)
		var v: Vector3 = sol[0] if not sol.is_empty() else (aim - b).normalized() * 30.0
		ball.launch(v, a, "strike")
		ball.set_meta("t_launch", now)
		ball.set_meta("shot", {"by": a, "placed": "pull"} if want == Vector3.ZERO else {})
		_last_owner = a.team
		_chase_t = 0.0
		_path = []
		Sfx.play("strike", -3.0)
		Game.haptic("strike"))


# ---------------------------------------------------------------- pause, back

func set_paused(on: bool) -> void:
	paused = on
	hud.show_pause(on)


func on_back() -> void:
	set_paused(not paused)


func quit_match() -> void:
	Sfx.crowd(-1.0)
	Game.goto_menu()


## A line for the scoreboard: "1-14 (17)".
func score_text(k: int) -> String:
	return "%s (%d)" % [Rules.fmt(score[k][0], score[k][1]), Rules.total(score[k][0], score[k][1])]
