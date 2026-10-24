extends Node3D
## A match: the court and its people, the two sides, the ball, the judges, the camera and (for you) the screen's
## controls and scoreboard. It runs the game the way it is played (docs/RULES.md): a serve across the analco, the ball
## struck back and forth with the hips until it dies in a half, goes past an end, out over a side, or touches a
## player anywhere but the hip; then the judges call the raya, the count moves, and the side that won it serves.
## The rules module (game/rules.gd) says who wins each raya and what the count is; this only tells it what happened.
##
## config: home, away (team ids), venue, rules ("ulama" | "classic"), side (players a side), user_team (0, 1, -1),
## mode ("quick" | "cup" | "watch" | "attract" | "test"), stage, length (real minutes, 0 none), seed, difficulty, urria.

enum P { INTRO, SERVE, LIVE, CALL, OVER }

const STEP := 1.0 / 120.0     # the ball's physics step
const INTRO_T := 2.6
const CALL_T := 2.8
const OVER_T := 3.6

var config := {}
var phase := P.INTRO
var phase_t := 0.0
var rules := Rules.ULAMA
var court: Court
var venue: Venue
var ball: Ball
var teams: Array = []         # [{id, players, ai}]
var officials: Officials
var cam: CameraRig
var hud = null
var count: Rules.Count
var user_team := -1
var user_player: Player = null
var server: Player = null
var serve_team := 0
var ball_flight := 0          # counts the strikes: the AI re-plans on each
var ball_path: Array = []
var clock := 0.0              # real seconds played (not counting calls, pauses)
var limit_s := 0.0
var sudden := false           # time is up and level: the next raya wins
var paused := false
var rng := RandomNumberGenerator.new()
var attract := false
var tstats := [{}, {}]
var rally := 0
var longest_rally := 0
var log_rayas: Array = []     # [team, reason, count after (holder, rayas), clock]
var last_call := {}
var _acc := 0.0
var _serve_launched := false
var _idle_serve := 0.0
var _fps_t := 0.0
var _fps_frames := 0
var _gfx_checked := false
var _hitstop := 0.0


func _ready() -> void:
	attract = bool(config.get("attract", false)) or String(config.get("mode", "")) == "attract"
	user_team = int(config.get("user_team", -1))
	rng.seed = int(config.get("seed", randi()))
	var vid := String(config.get("venue", "village"))
	rules = String(config.get("rules", DB.venue(vid).rules))
	court = Court.new(rules)
	count = Rules.Count.new(rules, String(config.get("urria", Game.settings.get("urria", "3_7"))))
	limit_s = float(config.get("length", 10)) * 60.0
	for k in 2:
		tstats[k] = {"rayas": 0, "dead": 0, "end": 0, "won_out": 0, "won_touch": 0, "ring": 0, "faults_touch": 0, "faults_out": 0,
			"strikes": 0, "dives": 0, "serves": 0}
	var home := DB.team(String(config.get("home", "ESC")))
	var away := DB.team(String(config.get("away", "LLA")))
	venue = Venue.new()
	add_child(venue)
	venue.build(vid, court, home.c1, away.c1)
	ball = Ball.new()
	add_child(ball)
	ball.setup(court, String(venue.info.floor))
	officials = Officials.new()
	add_child(officials)
	officials.build(court)
	var side := int(config.get("side", Rules.default_side(rules)))
	if not (side in Rules.side_sizes(rules)):
		side = Rules.default_side(rules)
	var level := int(config.get("difficulty", Game.settings.difficulty))
	var lod := 1 if int(Game.settings.graphics) == Game.GFX_LOW else 0
	for k in 2:
		var tid := String(config.get("home" if k == 0 else "away", "ESC" if k == 0 else "LLA"))
		var roster := DB.roster(tid, side, "classic" if rules == Rules.CLASSIC else "ulama")
		var ps: Array = []
		for i in roster.size():
			var r: Dictionary = roster[i]
			var p := Player.new()
			p.name = "%s_%d" % [tid, i + 1]
			p.setup(k, i + 1, r.look)
			p.pname = String(r.name)
			p.skill = float(r.skill)
			p.power = float(r.power)
			p.max_speed = float(r.speed)
			add_child(p)
			p.set_lod(lod)
			ps.append(p)
		var lvl := level if k != user_team else 1
		if user_team < 0:
			lvl = clampi(level, 1, 2)
		var ai := TeamAI.new(self, k, ps, lvl, int(rng.seed))
		for i in ps.size():
			(ps[i] as Player).role = ai.role_of(i)
			var spot := ai.home_spot(i)
			# They walk on from the side of the court.
			(ps[i] as Player).global_position = court.clamp_feet(spot + Vector3(-Rules.dir(k) * 2.0, 0, (3.5 if not court.classic() else 3.0) * (1.0 if i % 2 == 0 else -1.0)))
		teams.append({"id": tid, "players": ps, "ai": ai})
	officials.set_lod(lod)
	if user_team >= 0:
		user_player = teams[user_team].players[0]
		user_player.user = true
	serve_team = 0
	_pick_server()
	ball.held = true
	ball.pos = Vector3(0, Ball.RADIUS, 0)
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	if not attract and String(config.get("mode", "")) != "test":
		hud = (load("res://game/hud.gd") as Script).new()
		hud.m = self
		add_child(hud)
		hud.action.connect(_on_action)
	Game.apply_graphics(get_viewport())
	if not attract:
		Sfx.crowd(0.35)
	phase = P.INTRO
	phase_t = 0.0


# ---------------------------------------------------------------- what the others ask

func is_live() -> bool:
	return phase == P.LIVE


func all_players() -> Array:
	return teams[0].players + teams[1].players


func team_of(p: Player) -> Dictionary:
	return teams[p.team]


func serve_spot(team: int) -> Vector3:
	var back := 5.0 if not court.classic() else 4.0
	return Vector3(-Rules.dir(team) * back, 0, 0.0)


func score_of(team: int) -> int:
	return count.of(team)


func set_paused(p: bool) -> void:
	paused = p
	if hud:
		hud.show_pause(p)
	Sfx.crowd(0.0 if p else 0.35)


func on_back() -> void:
	set_paused(not paused)


# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if paused:
		return
	delta = minf(delta, 0.05)
	_check_frame_rate(delta)
	if _hitstop > 0.0:
		# The heavy ball meeting a hip: a moment's weight.
		_hitstop -= delta
		delta *= 0.3
	phase_t += delta
	if phase == P.LIVE:
		clock += delta
	_user_input()
	if phase == P.LIVE:
		ball_path = ball.predict(96)
	else:
		ball_path = []
	for t in teams:
		(t.ai as TeamAI).update(delta)
	for p in all_players():
		(p as Player).update(delta, court, Rules.dir(p.team), phase == P.INTRO or phase == P.OVER)
	_phase_logic(delta)
	# The ball, in small steps.
	_acc += delta
	while _acc >= STEP:
		_acc -= STEP
		_ball_step(STEP)
	if ball.held and server != null:
		ball.pos = server.global_position + Basis(Vector3.UP, server.yaw) * Moves.HAND_BALL
	ball.show_at(ball.pos, delta)
	cam.follow(self, delta)
	if hud:
		hud.refresh()


func _phase_logic(_delta: float) -> void:
	match phase:
		P.INTRO:
			if phase_t >= INTRO_T:
				_to_serve()
		P.SERVE:
			_serve_logic()
		P.CALL:
			if phase_t >= CALL_T:
				for p in all_players():
					(p as Player).calm()
				if count.winner >= 0:
					_to_over()
				elif limit_s > 0.0 and clock >= limit_s and not sudden:
					var w := Rules.at_time(count)
					if w >= 0:
						count.winner = w
						_to_over()
					else:
						sudden = true
						if hud:
							hud.banner(tr("NEXT_RAYA_WINS"), Game.C_GOLD)
						_to_serve()
				else:
					_to_serve()
		P.OVER:
			if phase_t >= OVER_T:
				_finish()


func _to_serve() -> void:
	phase = P.SERVE
	phase_t = 0.0
	_serve_launched = false
	_idle_serve = 0.0
	ball.held = true
	ball.vel = Vector3.ZERO
	ball.grounded = false
	serve_team = Rules.server(count)
	_pick_server()
	rally = 0
	if hud:
		hud.serve_tag(serve_team, Rules.serve_kind(count))


func _pick_server() -> void:
	server = teams[serve_team].players[0]
	if user_team == serve_team and user_player != server:
		_set_user(server)


func _serve_logic() -> void:
	if _serve_launched:
		if server.action != Player.A.SERVE or server.action_t >= Moves.SERVE_T * Moves.SERVE_HIT:
			_launch_serve()
		return
	var ready := server.global_position.distance_to(serve_spot(serve_team)) < 0.6 and phase_t > 1.0
	var mine := serve_team == user_team and not attract
	if mine:
		_idle_serve += get_process_delta_time()
		# Nobody touching the screen: the serve goes by itself after a while, so a match never stalls.
		if ready and _idle_serve > 9.0:
			_begin_serve()
	elif ready and phase_t > 1.6:
		_begin_serve()


func _begin_serve() -> void:
	# He faces the other side to bowl or throw.
	server.yaw = atan2(Rules.dir(serve_team), 0.0)
	server.start_serve(Rules.serve_kind(count) == "arriba")
	_serve_launched = true


## R11: the male. Abajo: bowled along the earth across the analco; arriba: thrown high across it.
func _launch_serve() -> void:
	if not ball.held:
		return
	var d := Rules.dir(serve_team)
	var kind := Rules.serve_kind(count)
	var hand := ball.pos
	var v: Vector3
	var zt := rng.randf_range(-0.8, 0.8) * (court.half_w_at(0.0) * 0.4)
	if kind == "abajo":
		var sp := rng.randf_range(8.0, 10.0)
		v = Vector3(d * sp, 0.0, (zt - hand.z) / 4.0)
		hand = Vector3(hand.x, Ball.RADIUS, hand.z)
	else:
		var dist := rng.randf_range(10.0, 17.0) if not court.classic() else rng.randf_range(7.0, 11.0)
		var ang := deg_to_rad(40.0)
		var sp := sqrt(Ball.GRAVITY * dist / sin(2.0 * ang))
		v = Vector3(d * cos(ang) * sp, sin(ang) * sp, (zt - hand.z) / maxf(1.0, dist / 6.0))
	ball.launch(hand, v, serve_team, server)
	ball_flight += 1
	server.stats.serves += 1
	tstats[serve_team].serves += 1
	phase = P.LIVE
	phase_t = 0.0
	rally = 0
	Sfx.play("throw", -6.0)
	if hud:
		hud.serve_tag(-1, "")


func _to_over() -> void:
	phase = P.OVER
	phase_t = 0.0
	var w := count.winner
	for p in all_players():
		(p as Player).react((p as Player).team == w)
	if hud:
		hud.full_time(w)
	if not attract:
		Sfx.react("cheer", 0.0)
		if user_team >= 0 and w == user_team:
			Game.haptic("score")


func _finish() -> void:
	if attract:
		_restart_attract()
		return
	if String(config.get("mode", "")) == "test":
		set_process(false)
		return
	Game.on_match_finished(result())


func _restart_attract() -> void:
	count = Rules.Count.new(rules, "3_7")
	clock = 0.0
	sudden = false
	serve_team = 0
	_to_serve()


## Everything the result screen and the cup need.
func result() -> Dictionary:
	var ps := {}
	for p in all_players():
		var pl: Player = p
		ps[pl.name] = {"name": pl.pname, "team": pl.team, "role": pl.role, "strikes": int(pl.stats.strikes),
			"dives": int(pl.stats.dives), "rayas": int(pl.stats.rayas), "faults": int(pl.stats.faults), "serves": int(pl.stats.serves)}
	var star := ""
	var best := -99.0
	for k in ps:
		var s: Dictionary = ps[k]
		var v := float(s.rayas) * 2.0 + float(s.strikes) * 0.3 - float(s.faults) * 1.5 + (1.0 if int(s.team) == count.winner else 0.0)
		if v > best:
			best = v
			star = k
	return {"config": config, "home": teams[0].id, "away": teams[1].id, "rules": rules, "count": count.to_dict(),
		"winner": count.winner, "user_team": user_team, "tstats": tstats, "pstats": ps, "log": log_rayas,
		"longest_rally": longest_rally, "minutes": clock / 60.0, "timed": limit_s > 0.0 and clock >= limit_s, "star": star}


# ---------------------------------------------------------------- you

func _set_user(p: Player) -> void:
	if user_player == p:
		return
	if user_player:
		user_player.user = false
		user_player.steer_by_dir = false
	user_player = p
	p.user = true


## The left thumb moves your player (the one going for the ball, or the one who will); the buttons strike.
func _user_input() -> void:
	if user_team < 0 or hud == null:
		return
	var ai: TeamAI = teams[user_team].ai
	if phase == P.LIVE and ai.taker != null and ai.taker != user_player and not user_player.busy():
		_set_user(ai.taker)
	var j: Vector2 = hud.joystick()
	if j.length() > 0.15 and phase != P.SERVE:
		user_player.steer_by_dir = true
		user_player.want_dir = screen_to_world(j)
	else:
		user_player.steer_by_dir = false
	var ids: Array = []
	if phase == P.LIVE:
		ids = ["HIP", "DIVE"]
	elif phase == P.SERVE and serve_team == user_team and not _serve_launched:
		ids = ["SERVE"]
	hud.set_buttons(ids)


## The joystick's direction on the screen as a direction on the court, from the camera.
func screen_to_world(j: Vector2) -> Vector3:
	var b := cam.camera.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var w := right * j.x - fwd * j.y
	return w.limit_length(1.0)


func _on_action(id: String) -> void:
	if paused or user_player == null:
		return
	match id:
		"SERVE":
			if phase == P.SERVE and serve_team == user_team and not _serve_launched:
				_begin_serve()
		"HIP", "DIVE":
			if phase != P.LIVE:
				return
			var side := _side_toward_ball(user_player)
			var aim := _user_aim()
			if id == "HIP":
				user_player.start_strike(side, aim)
			else:
				user_player.start_dive(side, aim)


## The hip nearer the ball.
func _side_toward_ball(p: Player) -> float:
	var left := Vector3(cos(p.yaw), 0, -sin(p.yaw))
	var to := ball.pos - p.global_position
	var s := signf(left.dot(to))
	if absf(left.dot(to)) < 0.05:
		s = 1.0 if left.x * Rules.dir(p.team) > 0.0 else -1.0
	return s if s != 0.0 else 1.0


## Your aim, from the joystick as you strike: toward their end, a long high ball; back toward yours, a low hard one that
## skids on the earth; across, to that side. No thumb on it: as your teammates would choose.
func _user_aim() -> Vector3:
	var ai: TeamAI = teams[user_team].ai
	var j: Vector2 = hud.joystick() if hud else Vector2.ZERO
	if j.length() < 0.3:
		return ai.choose_aim()
	var w := screen_to_world(j)
	var d := Rules.dir(user_team)
	var along := w.x * d
	var hl := Court.ALLEY_HALF_L if court.classic() else Court.ULAMA_HALF_L
	var depth := clampf(0.6 + along * 0.3, 0.3, 0.92)
	var ang := 18.0
	if along > 0.35:
		ang = 32.0
	elif along < -0.35:
		ang = 9.0
	var x := d * depth * hl
	return Vector3(x, ang, w.z * court.half_w_at(x) * 0.85)


# ---------------------------------------------------------------- the ball

func _ball_step(dt: float) -> void:
	if ball.held:
		return
	if phase == P.LIVE:
		_contacts()
		if phase != P.LIVE:
			return
	var events := ball.step(dt)
	if phase != P.LIVE:
		# After the call the ball runs on as it will; nothing it does counts.
		for e in events:
			if e.kind == "bounce" and float(e.speed) > 2.0:
				Sfx.play("thud_stone" if court.classic() else "thud", -14.0, 1.0)
		return
	for e in events:
		match String(e.kind):
			"bounce":
				var sp := float(e.speed)
				if sp > 1.0:
					Sfx.play("thud_stone" if String(e.surface) != "earth" else "thud", clampf(-20.0 + sp * 1.6, -20.0, -2.0), rng.randf_range(0.92, 1.05))
			"ring":
				# R13: through the ring.
				_award(ball.last_team, "ring", false, ball.last_player)
				return
			"end":
				# R9 / R16: past an end line, into an end court.
				var won := Rules.over_end(float(e.side)) if not court.classic() else Rules.end_court(float(e.side))
				_award(won, "end", false, ball.last_player)
				return
			"out":
				# R10 / R15: out over a side.
				_award(Rules.out_side(ball.last_team), "out", true, ball.last_player)
				return
	if ball.dead():
		# R8: it has died in a half.
		_award(Rules.dead_ball(ball.pos.x, ball.last_team), "dead", false, ball.last_player)


## The hips meeting the ball (a strike or a dive at its moment, close enough), and the ball touching anyone anywhere
## else (R6).
func _contacts() -> void:
	for p in all_players():
		var pl: Player = p
		var w := pl.hit_window()
		if w < 0.0:
			continue
		var hip := pl.hip_point()
		var reach := Player.REACH + (0.12 if pl.user and int(Game.settings.assist) > 0 else 0.0)
		var d := ball.pos.distance_to(hip)
		if d <= reach:
			_strike(pl, w, d / reach)
			return
	for p in all_players():
		var pl: Player = p
		if pl.immune > 0.0 or pl.hit_window() >= 0.0 or pl.action == Player.A.DIVE:
			continue
		var feet := pl.global_position
		var a := feet + Vector3(0, 0.12, 0)
		var b := feet + Vector3(0, 1.55, 0)
		var q := Geometry3D.get_closest_point_to_segment(ball.pos, a, b)
		if q.distance_to(ball.pos) < Player.BODY_R + Ball.RADIUS:
			var rel := (ball.vel - pl.vel).length()
			if rel > 0.4:
				pl.stats.faults += 1
				tstats[pl.team].faults_touch += 1
				_award(Rules.body_touch(pl.team), "touch", true, pl)
				return


func _strike(p: Player, window: float, off: float) -> void:
	var quality := clampf(window * 0.55 + (1.0 - off) * 0.45, 0.05, 1.0)
	var aim := p.action_aim
	var from := ball.pos
	var d := Rules.dir(p.team)
	var target := Vector2(aim.x, aim.z)
	var h := target - Vector2(from.x, from.z)
	if h.x * d < 1.0:
		h.x = d * maxf(4.0, absf(h.x))
	var dist := h.length()
	var err := (1.0 - quality) * (1.0 - p.skill * 0.5)
	var ang := deg_to_rad(aim.y + rng.randf_range(-9.0, 9.0) * err)
	var turn := rng.randf_range(-0.3, 0.3) * err
	var hn := h.normalized().rotated(turn)
	var lift := maxf(0.0, from.y - Ball.RADIUS)
	var denom := 2.0 * cos(ang) * cos(ang) * (dist * tan(ang) + lift)
	var need := sqrt(Ball.GRAVITY * dist * dist / maxf(denom, 0.01))
	var cap := (8.5 + 7.5 * p.power) * (0.5 + 0.5 * quality)
	if p.action == Player.A.DIVE:
		cap *= 0.8
		ang = maxf(ang, deg_to_rad(12.0))
	var sp := minf(need, cap)
	var v := Vector3(hn.x * cos(ang) * sp, sin(ang) * sp, hn.y * cos(ang) * sp)
	ball.launch(from + Vector3(hn.x, 0.0, hn.y) * 0.05, v, p.team, p)
	ball_flight += 1
	p.hit_done = true
	p.immune = 0.35
	rally += 1
	longest_rally = maxi(longest_rally, rally)
	if p.action == Player.A.DIVE:
		tstats[p.team].dives += 1
	else:
		tstats[p.team].strikes += 1
	_hitstop = 0.05 + 0.05 * quality
	cam.shake = 0.4 + 0.6 * quality if p.user else 0.15
	if not attract:
		Sfx.play("hip", -3.0 + quality * 3.0, rng.randf_range(0.94, 1.04))
		if quality > 0.85:
			Sfx.react("ooh", -12.0)
	if p.user and not attract:
		Game.haptic("dive" if p.action == Player.A.DIVE else "hip")
		if hud:
			hud.strike_feedback(quality)


# ---------------------------------------------------------------- the raya

## The one place a raya is given: the rules move the count; the judges call it; the people and the players react.
func _award(team: int, reason: String, fault: bool, who) -> void:
	if phase != P.LIVE:
		return
	var res: Dictionary
	if reason == "ring":
		res = Rules.award_ring(count, team)
	else:
		res = Rules.award(count, team)
	if sudden and count.winner < 0:
		count.winner = team
	tstats[team].rayas += 1
	match reason:
		"dead":
			tstats[team].dead += 1
		"end":
			tstats[team].end += 1
		"out":
			tstats[team].won_out += 1
			tstats[Rules.other(team)].faults_out += 1
			if who is Player:
				(who as Player).stats.faults += 1
		"touch":
			tstats[team].won_touch += 1
		"ring":
			tstats[team].ring += 1
	if who is Player and (who as Player).team == team and reason in ["dead", "end", "ring"]:
		(who as Player).stats.rayas += 1
	log_rayas.append([team, reason, count.holder, count.rayas, snappedf(clock, 0.1), String(res.get("what", ""))])
	last_call = {"team": team, "reason": reason, "fault": fault, "what": res.get("what", "")}
	phase = P.CALL
	phase_t = 0.0
	officials.signal_raya(team, fault)
	for p in all_players():
		(p as Player).react((p as Player).team == team)
	var big := reason == "ring" or String(res.get("what", "")) in ["urria", "win"]
	if not attract:
		Sfx.play("call", -4.0)
		Sfx.react("cheer" if big else "applause", -4.0 if big else -10.0)
		Crowd.set_excite(1.0 if big else 0.5)
		get_tree().create_timer(1.6).timeout.connect(func(): Crowd.set_excite(0.0))
	if user_team >= 0 and not attract:
		if reason == "ring" and team == user_team:
			Game.haptic("ring")
		elif fault and Rules.other(team) == user_team:
			Game.haptic("fault")
		elif team == user_team:
			Game.haptic("score")
		else:
			Game.haptic("lose")
	if hud:
		hud.call_raya(team, reason, String(res.get("what", "")), fault, who)
	if reason == "ring":
		var rc: Vector3 = court.rings()[0 if ball.pos.z < 0 else 1]
		cam.look_from(rc + Vector3(-Rules.dir(team) * 9.0, -1.2, -signf(rc.z) * 4.0), rc, 34.0)


# ---------------------------------------------------------------- the phone

## Auto graphics: if the first seconds of play run under about 36 frames a second, a level lower from the next match
## (and a lighter render scale now).
func _check_frame_rate(delta: float) -> void:
	if _gfx_checked or attract or not bool(Game.settings.get("auto_gfx", true)) or phase == P.INTRO:
		return
	_fps_t += delta
	_fps_frames += 1
	if _fps_t >= 6.0:
		_gfx_checked = true
		var fps := _fps_frames / _fps_t
		# (Battery saver holds it near 30 on purpose: nothing to lower then.)
		if fps < 36.0 and int(Game.settings.graphics) > Game.GFX_LOW and int(Game.settings.fps) != Game.FPS_SAVER:
			Game.settings.graphics = int(Game.settings.graphics) - 1
			Game.save_settings()
			Game.apply_graphics(get_viewport())
			if hud:
				hud.note(tr("GFX_LOWERED"))
