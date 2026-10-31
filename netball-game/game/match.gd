class_name Match
extends Node3D
## A match: four quarters (or the length chosen), the court and the venue, fourteen players, two umpires and the
## ball, played to the Rules of Netball (Rules). The phases of play:
##   setup  everyone goes to the spots for the next restart (a centre pass, a free or penalty pass, a throw-in);
##          the taker has the ball once she is on her spot
##   live   the ball in play; the clock runs
##   stop   the whistle: the umpire calls and signals the decision, then the award is set up
##   goal   the ball through the ring: the goal is signalled, then the next centre pass is set up
##   break  between quarters (the HUD shows the quarter's score; Continue skips the interval)
##   over   the final whistle
## The AI (TeamAI) and your controls only ever set where players want to go and what they try; this script decides
## what happens, by the rules, and keeps the score, the clock and the box score.

signal finished(result: Dictionary)
signal game_event(kind: String, info: Dictionary)

var config := {}
var demo := false                   # an AI v AI match (the home screen's, a test's): no player, no buzz
var user_team := -1
var players: Array = [[], []]       # on court, by team: GS, GA, WA, C, WD, GD, GK
var bench: Array = [[], []]         # squad entries not on court
var umpires: Array = []
var ball: Ball
var arena: Arena
var cam: CameraRig
var hud = null                      # HUD (CanvasLayer)
var controls = null                 # TouchControls
var ai: TeamAI
var rng := RandomNumberGenerator.new()

var phase := "setup"
var phase_t := 0.0
var q := 1                          # the period: 1-4 the quarters, 5-6 extra time's halves, 7 on to a two-goal lead
var quarter_min := 5.0
var time_left := 300.0
var live_s := 0.0                   # playing time so far (the coach waits for some before the areas tip)
var score := [0, 0]
var q_scores: Array = []            # [[team 0, team 1] for each period]
var first_dir := 1                  # the end team 0 attacks in the first quarter
var cp_first := 0                   # the team that took the match's first centre pass
var cp_n := 0                       # centre passes taken
var possession := -1                # the team with the ball (held or passed by it)
var last_possession := 0
var last_touch := 0
var holder: Player = null
var hold_t := 0.0
var hold_ready := false             # the taker is on her spot: the three seconds run
var from_free := false              # she has a free pass in the circle: she may pass, not shoot
var footwork: Rules.Footwork
var pass_info := {}                 # the pass in the air: from, to, kind, thrown_x, centre, cut (a defender going for it)
var shot_info := {}
var restart := {}                   # the award being set up: to, kind, at, shot, why, taker, out (the penalised player)
var paused := false
var me: Player = null               # the player you control
var me_idle := 0.0
var need_winner := false
var double_zone := false
var rolling := false                # the league option: team changes at any time (the pause menu)
var timeouts := [0, 0]              # the league option: time-outs left this half, by team
var _timeout_until := 0.0
var stats := {}                     # player id -> counters
var log: Array = []                 # what happened, for the tests and the result
var calls := {}                     # infringement kind -> count (the tests check the rules are used)
var _cp_whistled := false
var _stop_award := {}
var _goal_team := -1
var _break_skip := false
var _break_next := 0                # the period after this break (the HUD's interval screen)
var _break_shown := false
var _ended := false
var _auto_gfx := WsgAutoTier.new(Game.frame_cap())   # the shared foundation's: when to lower the graphics
var _detail_t := 0.0
var clock := 0.0                    # seconds of the match drawn (not paused, not in a replay): the replay's clock
var wsg_replay: WsgReplay           # the foundation's bodies as drawn, kept for the replays (FoundationLink)
var _ball_ring: Array = []          # [clock, the ball's position] for the replays
var _replay := {}                   # the replay playing: {t, t1, cam, ball_at, hud, then}
var _goal_clock := 0.0
var _miss_clock := -INF             # the last shot off the ring (a rebound scored: its replay starts at that shot)
var _highlight := {}                # an intercept or deflection that won the ball, kept for the next stoppage:
                                    # {t0, t1, frames, balls, by, at}
var _step_k := {}                   # player -> how far through her stride (the footstep sounds)
var _last_vel := {}                 # player -> her velocity last frame (a hard cut squeaks)
var _step_gap := 0.0
var _squeak_gap := 0.0


func _ready() -> void:
	demo = bool(config.get("demo", false)) or int(config.get("user_team", 0)) < 0
	user_team = -1 if demo else int(config.get("user_team", 0))
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	quarter_min = float(config.get("quarter", Game.quarter_minutes()))
	need_winner = bool(config.get("need_winner", false))
	double_zone = bool(config.get("double_zone", false))
	rolling = bool(config.get("rolling", false))
	if bool(config.get("timeouts", false)):
		timeouts = [Rules.TIMEOUTS_PER_HALF, Rules.TIMEOUTS_PER_HALF]
	time_left = Rules.period_length(1, quarter_min)
	if config.has("quarter_s"):
		time_left = float(config.quarter_s)   # the tests: short quarters
	q_scores = [[0, 0]]
	footwork = Rules.Footwork.new()
	# The umpires' toss: the winner takes the first centre pass (R4); ends at random.
	cp_first = rng.randi_range(0, 1)
	first_dir = 1 if rng.randf() < 0.5 else -1
	var home := String(config.get("home", "AUS"))
	var away := String(config.get("away", "NZL"))
	arena = Arena.new(String(config.get("venue", "arena")), [DB.team(home).get("c1", Color.WHITE), DB.team(home).get("c2", Color.WHITE)])
	add_child(arena)
	for t in 2:
		var squad: Array = DB.squad(home if t == 0 else away)
		var lineup: Array = config.get("lineup_%d" % t, [])
		for i in 7:
			var entry: Dictionary = squad[i]
			if lineup.size() == 7:
				entry = lineup[i]
			var pl := Player.new(t, entry, Rules.POSITIONS[i])
			pl.match_ref = self
			add_child(pl)
			players[t].append(pl)
			stats[String(entry.id)] = _blank_stats(t, entry)
		for entry in squad:
			if not _on_court(String(entry.id)):
				bench[t].append(entry)
	_reserves()
	for h in [-1, 1]:
		var u := Umpire.new(h)
		add_child(u)
		umpires.append(u)
	ball = Ball.new()
	add_child(ball)
	cam = CameraRig.new()
	cam.mode = int(Game.settings.camera)
	add_child(cam)
	ai = TeamAI.new(self)
	_set_ends()
	if not bool(config.get("attract", false)) and not bool(config.get("headless_hud", false)) or not demo:
		hud = (load("res://game/hud.gd") as Script).new(self)
		add_child(hud)
	if not demo:
		controls = TouchControls.new()
		controls.action.connect(_on_action)
		hud.add_controls(controls)
		_pick_me()
	Game.apply_graphics(get_viewport())
	_setup_centre(true)
	if not demo:
		# The venue's sound: its crowd and surroundings, and the sounds on court heard from where they happen.
		Sfx.venue(arena.kind())
		Sfx.crowd(arena.atmosphere() * 0.5)
		Sfx.attach_3d(self)
		ball.bounced.connect(_on_bounce)
	if Game.settings.dev and not demo:
		add_child(DevOverlay.new(self))
	# The replays (FoundationLink): the shared foundation's bodies kept as drawn. Medium and High (Low draws the game's
	# own bodies), not in the home screen's match.
	if FoundationLink.enabled() and not bool(config.get("attract", false)):
		wsg_replay = WsgReplay.new()
		add_child(wsg_replay)


## The reserves (bench) standing in a row in front of their team's bench, in tracksuits (the code-built figure, one
## shared mesh a team, no shadow): Medium and High only, so Low draws what it did. Rebuilt after a team change.
func _reserves() -> void:
	var old := get_node_or_null("Reserves")
	if old:
		old.name = "ReservesOld"
		old.queue_free()
	if int(Game.settings.graphics) <= Game.GFX_LOW:
		return
	var root := Node3D.new()
	root.name = "Reserves"
	add_child(root)
	for t in 2:
		var tm := DB.team(team_id(t))
		var n: int = bench[t].size()
		for i in n:
			var e: Dictionary = bench[t][i]
			var b := ToonBody.new({"umpire": true, "skin": Color(String(e.get("skin", "c48f62"))), "dress": tm.get("c1", Color.WHITE),
				"trim": tm.get("c2", Color.BLACK), "hair": Color("15100c"), "hair_style": int(e.get("hair", 0)),
				"height": float(e.get("height", 1.75)), "pos": ""})
			root.add_child(b)
			b.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var at := TeamAI.bench_spot(t) + Vector2((float(i) - (n - 1) * 0.5) * 0.75, 1.3)
			b.position = Vector3(at.x, 0.0, at.y)
			b.rotation.y = PI
			b.apply(Poses.at_ease())
			# On the player's model in a tracksuit of the team's colours (the foundation, Medium and High): posed once.
			if FoundationLink.enabled():
				var l := FoundationLink.new(b, b, "reserve")
				root.add_child(l)
				l.update(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO, PI, "")


func _blank_stats(t: int, entry: Dictionary) -> Dictionary:
	return {"team": t, "name": String(entry.name), "pos": "", "goals": 0, "attempts": 0, "super": 0, "feeds": 0,
		"assists": 0, "cpr": 0, "gains": 0, "intercepts": 0, "deflections": 0, "rebounds": 0, "penalties": 0,
		"turnovers": 0, "passes": 0}


func _on_court(id: String) -> bool:
	for t in 2:
		for pl in players[t]:
			if String(pl.data.id) == id:
				return true
	return false


func _set_ends() -> void:
	for t in 2:
		for pl in players[t]:
			pl.dir = Rules.ends_for_quarter(t, mini(q, 6), first_dir)
			stats[String(pl.data.id)].pos = pl.pos


func team_dir(t: int) -> int:
	return Rules.ends_for_quarter(t, mini(q, 6), first_dir)


func player_at(t: int, pos: String) -> Player:
	for pl in players[t]:
		if pl.pos == pos:
			return pl
	return null


func team_id(t: int) -> String:
	return String(config.get("home" if t == 0 else "away", ""))


# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if paused:
		return
	# (Ranked before they are posed: a body made full detail after its pose this frame shows its hands open on the
	# ball till its next pose.)
	_rank_detail(delta)
	if phase == "replay":
		_replay_step(delta)
		return
	var dt := minf(delta, 0.05)
	phase_t += dt
	clock += dt
	_auto_graphics(delta)
	match phase:
		"setup":
			_run_setup(dt)
		"live":
			_run_live(dt)
		"stop":
			# An intercept or deflection that won the ball, shown again once the umpire has called this stoppage.
			if phase_t > 1.0 and not _highlight.is_empty() and wsg_replay and not _stop_award.has("injured") and _start_replay("gain"):
				pass
			elif phase_t > 1.0:
				if _stop_award.has("injured") and not _stop_award.get("treated", false):
					_injury_stop()
				else:
					_apply_award(_stop_award)
		"injury":
			if (demo and phase_t > 3.0) or _break_skip or phase_t > Rules.INJURY_STOP:
				_end_injury()
		"goal":
			# The replay follows the TV camera's close shot of the post (it is over by now: CameraRig CLOSE_TAIL).
			if phase_t > 2.4 and not (wsg_replay and _start_replay("goal")):
				_setup_centre()
		"break":
			_run_break(dt)
		"timeout":
			if demo and phase_t > 0.6 or _break_skip or phase_t > Rules.TIMEOUT_LEN:
				_end_timeout()
		"over":
			if phase_t > 2.5 and not _ended:
				_end()
	if phase in ["setup", "live", "stop", "goal"] and _clock_runs():
		_tick_clock(dt)
	if phase != "break" and phase != "over":
		ai.think(dt)
		_drive_me(dt)
	elif phase == "break":
		ai.huddle()
	for t in 2:
		for pl in players[t]:
			pl.moves = 0
			pl.advance(dt)
	for u in umpires:
		if phase == "break":
			u.to_middle()
		else:
			u.follow(ball.court_pos())
		u.advance(dt, ball.court_pos())
	ball.step(dt)
	if not demo and phase in ["setup", "live", "goal"]:
		_movement_sounds(dt)
	if Game.test_quarter_s > 0.0 and OS.has_feature("web") and Engine.get_process_frames() % 15 == 0 and Game.current == self:
		# A browser playtest reads the match's state from the page (tools/playtest/play.js).
		JavaScriptBridge.eval("window.cpn = %s" % JSON.stringify({"phase": phase, "q": q, "score": score, "me": me.pos if me else "",
			"buttons": button_set(), "holder": holder.pos if holder else "", "mine": holder != null and holder.team == user_team}))
	var att := team_dir(possession) if possession >= 0 else 0
	cam.end_dir = team_dir(maxi(user_team, 0))
	# At a break the camera looks over to the huddles by the benches.
	cam.track(Vector2(0.0, Court.HALF_W) if phase == "break" else ball.court_pos(), 0 if phase == "break" else att, dt)
	if wsg_replay:
		wsg_replay.record(clock)
		_ball_ring.append([clock, ball.position])
		while _ball_ring.size() > 2 and float(_ball_ring[0][0]) < clock - wsg_replay.seconds:
			_ball_ring.pop_front()
		_keep_highlight()


func _clock_runs() -> bool:
	# Time runs through play and its short stops (it is held only for injuries and time-outs, R10); it waits for the
	# first centre pass whistle of each quarter.
	return _cp_whistled


func _tick_clock(dt: float) -> void:
	time_left -= dt
	live_s += dt
	# Suspensions run on playing time; she comes back on to her own area.
	for t in 2:
		for pl in players[t]:
			if pl.suspended > 0.0:
				pl.suspended -= dt
				if pl.suspended <= 0.0 and pl.ordered_off:
					# Four minutes on: a replacement may come on (if the bench has one); else the place stays empty.
					if substitute(pl):
						pl.ordered_off = false
						pl.suspensions = 0
						pl.warned = false
						pl.pens = 0
						pl.suspended = 0.0
						game_event.emit("replacement", {"team": t, "by": pl.pos})
					else:
						pl.suspended = 9999.0
					continue
				if pl.suspended <= 0.0:
					pl.suspended = 0.0
					pl.fenced = pl != me or bool(Game.settings.onside)
					game_event.emit("return", {"team": t, "by": pl.pos})
	if time_left <= 0.0:
		time_left = 0.0
		_end_period()


# ---------------------------------------------------------------- restarts

## The next centre pass (R8): the team whose turn it is, alternating whoever scored. Everyone goes to her spot: the C
## taking it in the centre circle, the other C anywhere in the centre third, the rest in their goal thirds.
func _setup_centre(snap := false) -> void:
	var t := Rules.centre_pass_team(cp_first, cp_n)
	restart = {"to": t, "kind": Rules.CENTRE, "at": Vector2.ZERO, "shot": false, "why": "centre"}
	restart.taker = player_at(t, "C")
	_enter("setup")
	pass_info = {}
	shot_info = {}
	holder = null
	ball.dead(Vector3(0, Ball.R, 0))
	ai.place_centre(t, snap)
	if snap:
		cam.track(Vector2.ZERO, 0, 0.0, true)
	game_event.emit("centre_setup", {"team": t})


func _enter(p: String) -> void:
	phase = p
	phase_t = 0.0


func _run_setup(_dt: float) -> void:
	var taker: Player = restart.get("taker")
	if taker == null or not is_instance_valid(taker):
		_choose_taker()
		taker = restart.taker
	var spot: Vector2 = restart.get("spot", restart.at)
	taker.target = spot
	taker.want_speed = 4.5
	var there := taker.p.distance_to(spot) < 0.35
	if there and ball.state != "held":
		taker.target = taker.p
		_give(taker, false)
		from_free = String(restart.kind) == Rules.FREE or (String(restart.kind) == Rules.PENALTY and not bool(restart.shot))
		taker.stopped = true
	if ball.state == "held" and holder == taker:
		if String(restart.kind) == Rules.CENTRE:
			# The centre pass: everyone in her third, then the whistle.
			var settle := 3.0 if not _cp_whistled else 3.2
			if phase_t > settle and (ai.settled() or phase_t > settle + 2.5):
				_go_live()
		else:
			# A free or penalty pass, a throw-in: taken as soon as the taker is on her spot (and the penalised player
			# beside her).
			var out: Player = restart.get("out")
			var ready := out == null or not is_instance_valid(out) or out.p.distance_to(out.target) < 0.4
			if (phase_t > 0.5 and ready) or phase_t > 2.5:
				_go_live()
	elif phase_t > 9.0 and taker.p.distance_to(spot) < 1.5:
		# Near enough (another player stood on the spot): the pass is taken from where she is.
		restart.spot = taker.p


func _choose_taker() -> void:
	var t := int(restart.to)
	var dir := team_dir(t)
	var at: Vector2 = restart.at
	var ok := Rules.takers(at, dir)
	var best: Player = null
	var bd := INF
	for pl in players[t]:
		if not (pl.pos in ok) or pl.away():
			continue
		if bool(restart.shot) and not (pl.pos in ["GS", "GA"]):
			continue
		var d: float = pl.p.distance_to(at)
		if d < bd:
			bd = d
			best = pl
	if best == null:
		best = player_at(t, ok[0] if not ok.is_empty() else "C")
	restart.taker = best
	var spot := at
	if String(restart.kind) == Rules.THROW_IN:
		spot = Rules.throw_in_spot(at)
	else:
		spot = Rules.onside_point(best.pos, at, dir, 0.05)
	restart.spot = spot


func _go_live() -> void:
	_enter("live")
	hold_t = 0.0
	hold_ready = true
	if String(restart.kind) == Rules.CENTRE:
		_cp_whistled = true
		cp_n += 1
	_whistle("long" if String(restart.kind) == Rules.CENTRE else "short", -6.0)
	if String(restart.kind) == Rules.CENTRE:
		ai.on_centre_whistle(int(restart.to))
	game_event.emit("whistle", {"kind": restart.kind})


## The ball to a player: she has caught it (or been handed it for a restart).
func _give(pl: Player, caught := true) -> void:
	holder = pl
	ball.hold(pl)
	possession = pl.team
	last_possession = pl.team
	last_touch = pl.team
	hold_t = 0.0
	hold_ready = caught
	from_free = false
	footwork = Rules.Footwork.new()
	var foot := "both" if pl.vel.length() < 1.0 else ("l" if rng.randf() < 0.5 else "r")
	footwork.land(foot)
	pl.landing = pl.p + pl.vel * 0.12
	if caught:
		pl.start_landing(foot)   # her body lands on that foot (motion capture) and stops on it
	pl.stopped = true
	pl.set_act("hold")
	pl.look_on = false
	if caught and not demo:
		Sfx.play_at("catch", ball.pos, -6.0, randf_range(0.94, 1.06))
	if caught and pl.team == user_team and not demo:
		Game.haptic("catch")
	if user_team >= 0 and int(Game.settings.control) == Game.CONTROL_TEAM and pl.team == user_team:
		_set_me(pl)


func _release_holder() -> void:
	if holder:
		holder.stopped = false
		holder.out_until = 0.0
	holder = null


# ---------------------------------------------------------------- live play

func _run_live(dt: float) -> void:
	# Out-of-play players rejoin once the ball is released.
	if shot_info.has("by"):
		_run_shot(dt)
		return
	if holder:
		if hold_ready:
			hold_t += dt
		holder.look_on = true
		holder.look_at_p = ai.holder_look(holder)
		if Rules.held_ball(hold_t):
			_infringe("held_ball", holder, holder.p)
			return
		if footwork.fault != "":
			_infringe("footwork", holder, holder.p)
			return
	_check_offside()
	if phase != "live":
		return
	match ball.state:
		"flight":
			_run_flight()
		"loose":
			_run_loose()


## Offside: any player touching the ground in an area her position may not enter. The AI keeps to its areas;
## your player can stray (unless Keep me onside is on), and a few AI mistakes are made on purpose (TeamAI.slip).
func _check_offside() -> void:
	for t in 2:
		for pl in players[t]:
			var off := Rules.offside(pl.pos, pl.p, pl.dir)
			var stepped: bool = off and not pl.was_offside
			pl.was_offside = off
			if pl.away() or not stepped:
				continue
			_infringe("offside", pl, pl.p)
			return


## A pass from the holder to a team-mate. kind: chest, shoulder, bounce, lob. The flight time follows the pass's kind
## and length; the receiver runs to meet it; a defender who can reach its path in time may go for it (TeamAI).
func throw_pass(to: Player, kind: String) -> void:
	if holder == null or phase != "live":
		return
	var from := holder
	var catch_at := ai.catch_point(to, kind)
	var dist := from.p.distance_to(catch_at)
	var spd: float = {"chest": 11.5, "shoulder": 14.5, "bounce": 9.0, "lob": 8.5}.get(kind, 11.0)
	var dur := clampf(dist / spd, 0.25, 2.0)
	var apex: float = {"chest": 0.25, "shoulder": 0.6, "bounce": 0.0, "lob": 1.6 + dist * 0.06}.get(kind, 0.3)
	var hand := from.hand_point()
	var arrive := Vector3(catch_at.x, clampf(to.reach() * 0.62, 1.1, 1.5), catch_at.y)
	if kind == "lob":
		arrive.y = to.reach() * 0.86
	from.set_act("pass", kind)
	ball.throw(hand, arrive, dur, apex, 0.55 if kind == "bounce" else -1.0)
	stats[String(from.data.id)].passes += 1
	pass_info = {"from": from, "to": to, "kind": kind, "thrown_x": from.p.x, "thrown_at": from.p, "centre": String(restart.get("kind", "")) == Rules.CENTRE and not restart.get("cp_done", false),
		"t": 0.0, "dur": dur, "cut": null, "cut_k": 1.0, "short": Rules.short_pass(from.p, catch_at), "feed": to.pos in ["GS", "GA"] and Court.in_circle(catch_at, to.dir)}
	restart.cp_done = true
	_release_holder()
	to.target = catch_at
	to.want_speed = to.speed_cap()
	to.look_on = true
	to.look_at_p = from.p
	ai.on_pass(pass_info)
	Sfx.play("pass", -10.0, rng.randf_range(0.95, 1.05))
	game_event.emit("pass", {"from": from.pos, "to": to.pos, "kind": kind})


func _run_flight() -> void:
	var k := ball.f_t / ball.f_dur
	var cut: Player = pass_info.get("cut")
	if cut != null and k >= float(pass_info.cut_k) and not pass_info.get("cut_done", false):
		pass_info.cut_done = true
		var res: String = pass_info.get("cut_result", "miss")
		if res == "take":
			_gain(cut, "intercept")
			return
		if res == "tip":
			stats[String(cut.data.id)].deflections += 1
			last_touch = cut.team
			_tipped_by = cut.team
			_tipped_at = clock
			var v := (Vector3(ball.f_to - ball.f_from)).normalized() * 3.0
			v = v.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
			v.y = 1.5
			ball.loose(ball.pos, v)
			pass_info = {}
			game_event.emit("deflection", {"by": cut.pos})
			return
		if res == "contact":
			_infringe("contact", cut, cut.p)
			return
	if k >= 1.0:
		_arrive()


## The ball reaches the receiver: caught (with the rules checked), fumbled, or past her.
func _arrive() -> void:
	var to: Player = pass_info.to
	var from: Player = pass_info.from
	var at := ball.court_pos()
	if to.p.distance_to(at) > 1.3:
		# She was not there: the ball runs on.
		var v := (ball.f_to - ball.f_from).normalized() * 4.0
		v.y = 0.0
		ball.loose(ball.pos, v)
		stats[String(from.data.id)].turnovers += 1
		pass_info = {}
		return
	var p_catch := 0.985 - (0.04 if pass_info.kind == "bounce" else 0.0) - (0.03 if pass_info.kind == "lob" else 0.0)
	if rng.randf() > p_catch:
		var v := Vector3(rng.randf_range(-2, 2), 1.5, rng.randf_range(-2, 2))
		last_touch = to.team
		ball.loose(ball.pos, v)
		stats[String(to.data.id)].turnovers += 1
		if not demo:
			Sfx.react("groan", -16.0)
		game_event.emit("fumble", {"by": to.pos})
		pass_info = {}
		return
	var info := pass_info
	pass_info = {}
	_give(to)
	to.set_act("catch")
	to.act_up = clampf((ball.pos.y - 1.3) / 1.0, -1.0, 1.0)
	# The rules at the catch.
	if bool(info.get("centre", false)):
		if Rules.centre_pass_ok(to.pos, to.landing):
			stats[String(to.data.id)].cpr += 1
		else:
			_infringe("centre_pass_fault", to, to.p)
			return
	if bool(info.get("short", false)):
		_infringe("short_pass", from, from.p)
		return
	if Rules.over_third(float(info.thrown_x), to.landing.x):
		_infringe("over_third", from, Vector2(Court.THIRD_X * signf(to.landing.x), to.landing.y))
		return
	if bool(info.get("feed", false)):
		stats[String(from.data.id)].feeds += 1
	game_event.emit("catch", {"by": to.pos, "team": to.team})


## A loose ball: the nearest players chase it; the first to reach it takes it. Over a line it is out of court.
func _run_loose() -> void:
	var b := ball.court_pos()
	if not Court.on_court(b) and ball.pos.y < 0.4:
		var crossed := Court.clamp_court(b)
		_award(Rules.throw_in(last_touch, crossed), null, "throw_in")
		return
	if ball.pos.y > 2.6:
		return
	var best: Player = null
	var bd := 0.75
	for t in 2:
		for pl in players[t]:
			if pl.away():
				continue
			var d: float = pl.p.distance_to(b)
			if d < bd and ball.pos.y < pl.reach(true) and not Rules.offside(pl.pos, b, pl.dir):
				bd = d
				best = pl
	if best:
		if best.team != possession:
			_gain(best, "loose")
		else:
			_give(best)
			best.set_act("catch")
		if shot_info.get("rebound", false):
			stats[String(best.data.id)].rebounds += 1
			shot_info = {}


## A defender takes the ball: an intercept, a loose ball, a rebound.
func _gain(pl: Player, how: String) -> void:
	var other := 1 - pl.team
	if possession == other:
		var lost: Player = pass_info.get("from") if pass_info.has("from") else null
		if lost:
			stats[String(lost.data.id)].turnovers += 1
	pass_info = {}
	stats[String(pl.data.id)].gains += 1
	if how == "intercept":
		stats[String(pl.data.id)].intercepts += 1
	if how == "intercept" or (how == "loose" and _tipped_by == pl.team and clock - _tipped_at < 2.5):
		_mark_highlight(pl)
	_give(pl)
	pl.set_act("catch")
	pl.act_up = 0.6
	if pl.team == user_team and not demo:
		Game.haptic("intercept")
	if not demo:
		Sfx.react("ooh", -10.0)
	game_event.emit("gain", {"by": pl.pos, "team": pl.team, "how": how})


# ---------------------------------------------------------------- sounds on court

## The umpire's whistle (Sfx.whistle: "short", "long", "double" or "final"), from the umpire controlling where it
## happened (at; the ball by default), her whistle at head height. The home screen's match whistles quietly.
func _whistle(kind: String, volume_db: float, at = null) -> void:
	var spot: Vector2 = at if at is Vector2 else ball.court_pos()
	var from := Vector3(spot.x, 1.6, spot.y)
	var best := INF
	for u in umpires:
		var d: float = Vector2(u.global_position.x, u.global_position.z).distance_to(spot) - (1000.0 if u.controls(spot) else 0.0)
		if d < best:
			best = d
			from = (u.global_position as Vector3) + Vector3(0, 1.6, 0)
	if bool(config.get("attract", false)):
		volume_db -= 12.0
	Sfx.whistle(kind, from, volume_db)


func _goal_whistle() -> void:
	if is_inside_tree() and not paused:
		_whistle("long", -8.0)


## The ball on the floor (a bounce pass, a loose ball): timber indoors, asphalt outdoors; louder the harder it lands.
func _on_bounce(at: Vector3, speed: float) -> void:
	if speed < 0.8:
		return
	Sfx.play_at("bounce_floor" if arena.indoor() else "bounce_court", at, -10.0 + 4.0 * clampf(speed / 6.0, 0.0, 1.0), randf_range(0.95, 1.05))


## Footsteps of the players running near the ball, and indoors the squeak of a shoe on a hard cut. Kept sparse (a
## step at most every 0.12 s, a squeak every 0.9 s) so fourteen players never make a din.
func _movement_sounds(dt: float) -> void:
	_step_gap -= dt
	_squeak_gap -= dt
	var b := ball.court_pos()
	var surface := "step_floor" if arena.indoor() else "step_court"
	for t in 2:
		for pl in players[t]:
			var v: Vector2 = pl.vel
			var before: Vector2 = _last_vel.get(pl, v)
			_last_vel[pl] = v
			if pl.away() or pl.p.distance_to(b) > 9.0:
				continue
			var spd := v.length()
			var k := float(_step_k.get(pl, 0.0)) + spd * dt / 1.4
			if k >= 1.0 and spd > 2.5 and _step_gap <= 0.0:
				_step_gap = 0.12
				Sfx.play_at(surface, Vector3(pl.p.x, 0.0, pl.p.y), -16.0 + 4.0 * clampf((spd - 2.5) / 4.0, 0.0, 1.0), randf_range(0.9, 1.1))
			_step_k[pl] = fmod(k, 1.0)
			if arena.indoor() and _squeak_gap <= 0.0 and before.length() > 3.5 and dt > 0.0 \
					and (v - before).length() / dt > 14.0 and v.dot(before) < before.length_squared() * 0.6 and randf() < 0.5:
				_squeak_gap = 0.9
				Sfx.play_at("squeak", Vector3(pl.p.x, 0.0, pl.p.y), -12.0, randf_range(0.9, 1.12))


# ---------------------------------------------------------------- shooting (R9)

## A shot by the holder (GS or GA, in her circle; not from a free pass). Its chance follows the distance from the
## post, her shooting, and a defender's arm over the ball from 0.9 m. The ball leaves her hands 0.75 s into the
## shot (_run_shot).
func shoot() -> void:
	if holder == null or phase != "live" or shot_info.get("by") == holder:
		return
	var pl := holder
	if not Rules.may_shoot(pl.pos, pl.landing, pl.dir, from_free):
		return
	var post := Court.goal_post(pl.dir)
	var dist := pl.landing.distance_to(post)
	var pressure := ai.shot_pressure(pl)
	var chance := shot_chance(dist, float(pl.data.shoot), pressure)
	if pl.team == user_team and not demo:
		chance = clampf(chance + float(config.get("user_shot_bonus", 0.0)), 0.05, 0.99)
	var goal := rng.randf() < chance
	var value := 1
	if double_zone and Rules.double_zone_live(time_left, quarter_min):
		value = Rules.goal_value(pl.landing, pl.dir, true, 0.0)
	shot_info = {"by": pl, "goal": goal, "value": value, "dist": dist, "t": 0.0, "released": false}
	pl.set_act("shoot")
	stats[String(pl.data.id)].attempts += 1
	game_event.emit("shot_start", {"by": pl.pos, "dist": dist, "value": value})


## The shot's flight, frame by frame: released at 0.75 s, through the ring (or off it) when it arrives.
func _run_shot(dt: float) -> void:
	var pl: Player = shot_info.by
	shot_info.t = float(shot_info.t) + dt
	if not shot_info.released:
		if float(shot_info.t) >= 0.75:
			_release_holder()
			shot_info.released = true
			var ring := Court.ring_centre(pl.dir)
			var to := ring + Vector3(0, 0.05, 0)
			if not shot_info.goal:
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.17, 0.28)
				to += Vector3(off.x, 0.0, off.y)
			ball.throw(pl.hand_point() + Vector3(0, 0.15, 0), to, 0.95 + float(shot_info.dist) * 0.03, 1.1 + float(shot_info.dist) * 0.08)
			Sfx.play("pass", -12.0, 0.9)
		return
	if ball.state == "flight" and ball.f_t >= ball.f_dur:
		var ring := Court.ring_centre(pl.dir)
		if shot_info.goal:
			_goal(pl, int(shot_info.value))
			return
		# Off the ring: a rebound. The shooter may take it herself (it touched the goal post).
		var away := Vector3(pl.p.x - ring.x, 0, pl.p.y - ring.z).normalized()
		var v := away.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0)) * rng.randf_range(1.5, 3.2)
		v.y = rng.randf_range(0.5, 2.0)
		ball.loose(ring, v)
		last_touch = pl.team
		shot_info = {"rebound": true}
		_miss_clock = clock - 0.95 - float(pl.p.distance_to(Vector2(ring.x, ring.z))) * 0.03 - 0.75
		Sfx.play_at("rim", ring, -6.0)
		if not demo:
			Sfx.react("groan", -12.0)
		game_event.emit("miss", {"by": pl.pos, "team": pl.team})


## The chance a shot goes in: about 95% under the post, 87% at 2.5 m, 62% at the circle's edge for a shooter of 85;
## a defender's arm over the ball takes up to an eighth off it. (Real shooters: GS about 86%, GA about 77%, the GA's
## shots longer: docs/RULES.md "Numbers".)
static func shot_chance(dist: float, shooting: float, pressure: float) -> float:
	var base := clampf(0.995 - 0.045 * dist - 0.008 * dist * dist, 0.3, 0.98)
	var skill := lerpf(0.84, 1.07, clampf((shooting - 40.0) / 59.0, 0.0, 1.0))
	return clampf(base * skill * (1.0 - 0.12 * pressure), 0.05, 0.98)


func _goal(pl: Player, value: int) -> void:
	score[pl.team] += value
	q_scores[q_scores.size() - 1][pl.team] += value
	var s: Dictionary = stats[String(pl.data.id)]
	s.goals += 1
	if value == 2:
		s.super += 1
	var feeder: Player = ai.last_passer
	if feeder and feeder.team == pl.team and feeder != pl:
		stats[String(feeder.data.id)].assists += 1
	ball.loose(Court.ring_centre(pl.dir), Vector3(0, -1.5, 0))
	shot_info = {}
	_goal_team = pl.team
	_goal_clock = clock
	_highlight = {}          # (the goal's own replay shows the play)
	_enter("goal")
	holder = null
	possession = -1
	for u in umpires:
		if u.controls(Court.goal_post(pl.dir)):
			u.call_signal("goal", pl.dir)
	Sfx.play_at("swish", Court.ring_centre(pl.dir), -4.0)
	if not demo:
		Sfx.react("cheer", -6.0 if pl.team == 0 else -9.0)
		# The umpire's whistle for the goal, a beat after the net.
		get_tree().create_timer(0.45, false).timeout.connect(_goal_whistle)
	if pl.team == user_team and not demo:
		Game.haptic("goal")
	pl.set_act("cheer")
	log.append({"t": _elapsed(), "q": q, "goal": pl.team, "by": pl.pos, "value": value})
	# A side four or more behind may call a time-out after the goal (the AI's; yours is in the pause menu).
	var other := 1 - pl.team
	if other != user_team and int(timeouts[other]) > 0 and score[pl.team] - score[other] >= 4 and rng.randf() < 0.35:
		call_timeout.call_deferred(other)
	game_event.emit("goal", {"team": pl.team, "by": pl.pos, "value": value})


func _elapsed() -> float:
	return Rules.period_length(mini(q, 6), quarter_min) - time_left


# ---------------------------------------------------------------- infringements and awards

## An infringement by `by` at `at`. The umpire whose half it is in blows and calls it, unless she plays advantage
## (R7): the other team has the ball and stopping play would cost it (a shooter set to shoot, a clear break).
func _infringe(kind: String, by: Player, at: Vector2) -> void:
	if phase != "live" and phase != "setup":
		return
	calls[kind] = int(calls.get(kind, 0)) + 1
	var other := 1 - by.team
	if Rules.INFRINGEMENTS.get(kind, "") == Rules.PENALTY and holder and holder.team == other and holder.pos in ["GS", "GA"] \
			and Court.in_circle(holder.landing, holder.dir) and not from_free and rng.randf() < 0.6:
		# Advantage: the shooter is set to shoot; the umpire calls "Advantage", the infringement and plays on.
		stats[String(by.data.id)].penalties += 1
		game_event.emit("advantage", {"kind": kind, "by": by.pos, "team": by.team})
		log.append({"t": _elapsed(), "q": q, "advantage": kind, "team": by.team})
		return
	var taker_pos := "GS"
	var a := Rules.award(kind, by.team, at, taker_pos, team_dir(other))
	if Rules.INFRINGEMENTS.get(kind, "") == Rules.THROW_IN:
		a = Rules.throw_in(by.team, at)
	elif by.warned and String(a.kind) == Rules.FREE and kind in ["held_ball", "footwork", "offside", "breaking"]:
		# A warned player infringing again: the umpire escalates the free pass to a penalty pass (R18).
		a = Rules.escalate(a, team_dir(other))
		game_event.emit("escalate", {"team": by.team, "by": by.pos})
	elif by.warned and String(a.kind) == Rules.PENALTY:
		# ... or advances the penalty pass up to half a third (R18).
		a.at = Rules.advance(a.at, team_dir(other))
		a.shot = bool(a.shot) or Court.in_circle(a.at, team_dir(other))
		a.advanced = true
		game_event.emit("advance", {"team": by.team, "by": by.pos})
	stats[String(by.data.id)].penalties += 1
	if by.team == user_team and by == me and not demo:
		Game.haptic("penalty")
	_award(a, by, kind)
	_sanction(by, kind)


## Game management (R18, 2024): proactive advice, then a warning for a player who keeps infringing, then a suspension
## of two minutes of playing time (her team plays a player short), and ordering off for the worst. The game's
## umpires warn a player at her fourth penalty since her last sanction and suspend her at the third after a warning.
const WARN_AT := 4
const SUSPEND_AT := 3


func _sanction(pl: Player, kind: String) -> void:
	if Rules.INFRINGEMENTS.get(kind, "") != Rules.PENALTY:
		return
	pl.pens += 1
	if not pl.warned and pl.pens >= WARN_AT:
		pl.warned = true
		pl.pens = 0
		game_event.emit("warning", {"team": pl.team, "by": pl.pos})
		log.append({"t": _elapsed(), "q": q, "warning": pl.pos, "team": pl.team})
	elif pl.warned and pl.pens >= SUSPEND_AT:
		pl.pens = 0
		suspend(pl)


## Suspends a player for two minutes of playing time: she goes to her bench, and no one stands out of play for the
## penalty (2024).
func suspend(pl: Player) -> void:
	pl.suspensions += 1
	if pl.suspensions >= Rules.SUSPENSIONS_TO_ORDER_OFF:
		order_off(pl)
		return
	pl.suspended = Rules.SUSPENSION
	pl.out_until = 0.0
	if restart.get("out") == pl:
		restart.erase("out")
	if _stop_award.get("by") == pl:
		_stop_award.by = null
	if me == pl and int(Game.settings.control) == Game.CONTROL_TEAM:
		var n := ai.nearest_defender(pl.team, pl)
		if n:
			_set_me(n)
	game_event.emit("suspension", {"team": pl.team, "by": pl.pos})
	log.append({"t": _elapsed(), "q": q, "suspension": pl.pos, "team": pl.team})


## Ordering off (R18): she takes no further part. Her team plays a player short, and may bring on a replacement after
## four minutes of playing time (2024): the game does so if the bench has a player for the position.
func order_off(pl: Player) -> void:
	pl.ordered_off = true
	pl.suspended = Rules.ORDERED_OFF_REPLACE
	pl.out_until = 0.0
	if restart.get("out") == pl:
		restart.erase("out")
	if _stop_award.get("by") == pl:
		_stop_award.by = null
	if me == pl:
		var n := ai.nearest_defender(pl.team, pl)
		if n:
			_set_me(n)
	game_event.emit("ordered_off", {"team": pl.team, "by": pl.pos})
	log.append({"t": _elapsed(), "q": q, "ordered_off": pl.pos, "team": pl.team})


## Stops play for an award: the whistle, the call and the signal, then (in "stop") the restart is set up.
func _award(a: Dictionary, by: Player, kind: String) -> void:
	_stop_award = a
	_stop_award.by = by
	_stop_award.signal = kind
	pass_info = {}
	shot_info = {}
	if holder:
		holder.stopped = false
	holder = null
	ball.dead(ball.pos if ball.state != "held" else ball.pos)
	_enter("stop")
	var at: Vector2 = a.at
	for u in umpires:
		if u.controls(at):
			u.call_signal(_signal_for(kind), team_dir(int(a.to)))
	_whistle("short", -4.0, at)
	# Now and then a player is hurt in the contact: the umpire will hold time (R10).
	if kind == "contact" and by and not bool(config.get("no_injuries", false)) and rng.randf() < 0.04:
		var hurt: Player = null
		var hd := INF
		for pl in players[1 - by.team]:
			if pl.p.distance_to(at) < hd and not pl.away():
				hd = pl.p.distance_to(at)
				hurt = pl
		if hurt:
			_stop_award.injured = hurt
	log.append({"t": _elapsed(), "q": q, "call": kind, "to": a.to, "award": a.kind, "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]})
	game_event.emit("call", {"kind": kind, "award": a.kind, "to": a.to, "by": by.pos if by else "", "shot": a.shot})


static func _signal_for(kind: String) -> String:
	match kind:
		"centre_pass_fault":
			return "offside"
		"incorrect_throw_in", "out_of_court", "throw_in":
			return "throw_in"
		"intimidation":
			return "obstruction"
	return kind


## After the call: the restart is set up. For a penalty the infringer stands out of play beside the thrower until
## the ball is released (R6).
func _apply_award(a: Dictionary) -> void:
	restart = {"to": int(a.to), "kind": String(a.kind), "at": a.at, "shot": bool(a.shot), "why": String(a.get("why", ""))}
	_choose_taker()
	var by: Player = a.get("by")
	if String(a.kind) == Rules.PENALTY and by and is_instance_valid(by) and by.suspended <= 0.0:
		var taker: Player = restart.taker
		var dirv := Vector2(0, 1 if taker.p.y < 0 else -1)
		var spot: Vector2 = restart.spot + dirv * Rules.OUT_OF_PLAY_GAP
		spot = Rules.onside_point(by.pos, spot, by.dir, 0.05)
		by.target = spot
		by.out_until = 99.0
		restart.out = by
	_enter("setup")


# ---------------------------------------------------------------- time

func _end_period() -> void:
	if phase == "over" or phase == "break":
		return
	# A shot in the air when the whistle goes counts if it goes in (2024): it lands first.
	if shot_info.get("released", false):
		return
	var nxt := Rules.next_period(q, score, need_winner)
	_whistle("final" if nxt == 0 else "long", -2.0)
	game_event.emit("period_end", {"q": q})
	if nxt == 0:
		_enter("over")
		# The coach's tips were for a first match: after one played to the end they stop (Settings brings them back).
		if hud and hud.coach and not bool(Game.settings.get("coached", false)):
			Game.settings.coached = true
			Game.settings.coach = false
			Game.save_settings()
		Sfx.react("applause", -6.0)
		for t in 2:
			for pl in players[t]:
				pl.set_act("cheer" if score[t] > score[1 - t] else "ready")
		return
	_enter("break")
	if not demo:
		Sfx.react("applause", -10.0)
	_break_skip = false
	_break_next = nxt
	_break_shown = false
	if holder:
		holder.stopped = false
	holder = null
	pass_info = {}
	shot_info = {}
	ball.dead(ball.pos)


## Seconds of the teams going to their huddles before the interval screen comes up over them: once they are all
## there, after HUDDLE_MIN at least and HUDDLE_S at most.
const HUDDLE_S := 6.5
const HUDDLE_MIN := 2.5


func _run_break(_dt: float) -> void:
	# The teams huddle by their benches (TeamAI.huddle), then the interval screen; yours waits for Continue (the
	# interval's real length is shown on the HUD). A demo match goes straight on (the home screen's after its huddle).
	if hud and not _break_shown and (phase_t > HUDDLE_S or phase_t > HUDDLE_MIN and ai.huddled()):
		_break_shown = true
		hud.show_break(q, _break_next)
	var demo_wait := HUDDLE_S if bool(config.get("attract", false)) else 0.6
	if demo and phase_t > demo_wait or _break_skip:
		_next_period()


## A time-out (the league option): 90 seconds with time held, taken after a goal (the next centre pass not yet
## whistled), two a team each half.
func can_timeout(t: int) -> bool:
	return t >= 0 and int(timeouts[t]) > 0 and (phase == "goal" or (phase == "setup" and String(restart.get("kind", "")) == Rules.CENTRE))


func call_timeout(t: int) -> void:
	if not can_timeout(t):
		return
	timeouts[t] = int(timeouts[t]) - 1
	if phase == "goal":
		_setup_centre()
	_enter("timeout")
	_break_skip = false
	_whistle("double", -6.0)
	game_event.emit("timeout", {"team": t})
	if hud:
		hud.show_break(-1, q, t)


## An injury stoppage (R10): time is held; the team has 30 seconds to get her off (or she plays on), and both teams
## may make changes. The AI's injured players are replaced when the bench has someone for the position.
func _injury_stop() -> void:
	_stop_award.treated = true
	var hurt: Player = _stop_award.injured
	_enter("injury")
	_break_skip = false
	for u in umpires:
		if u.controls(hurt.p):
			u.call_signal("time", 1)
	_whistle("double", -6.0, hurt.p)
	game_event.emit("injury", {"team": hurt.team, "by": hurt.pos})
	log.append({"t": _elapsed(), "q": q, "injury": hurt.pos, "team": hurt.team})
	if hud:
		hud.show_break(-2, q, hurt.team)


func _end_injury() -> void:
	var hurt: Player = _stop_award.get("injured")
	if hurt and hurt.team != user_team and rng.randf() < 0.7:
		substitute(hurt)
	_break_skip = false
	if hud:
		hud.hide_break()
	_apply_award(_stop_award)


func _end_timeout() -> void:
	_break_skip = false
	if hud:
		hud.hide_break()
	_enter("setup")


func skip_break() -> void:
	_break_skip = true


func _next_period() -> void:
	q = Rules.next_period(q, score, need_winner)
	time_left = Rules.period_length(mini(q, 6), quarter_min)
	if config.has("quarter_s") and q <= 4:
		time_left = float(config.quarter_s)
	elif config.has("quarter_s"):
		time_left = float(config.quarter_s) * 0.5 if q <= 6 else INF
	q_scores.append([0, 0])
	_cp_whistled = false
	if q == 3 and bool(config.get("timeouts", false)):
		timeouts = [Rules.TIMEOUTS_PER_HALF, Rules.TIMEOUTS_PER_HALF]
	_set_ends()
	for t in 2:
		for pl in players[t]:
			pl.out_until = 0.0
			pl.fenced = pl != me or bool(Game.settings.onside)   # back from the huddle, to her areas
			pl.look_on = false
	if hud:
		hud.hide_break()
	_setup_centre(true)


func _end() -> void:
	_ended = true
	var result := result_dict()
	finished.emit(result)
	if not demo and is_inside_tree() and Game.current == self:
		Game.on_match_finished(result)


func result_dict() -> Dictionary:
	var best := ""
	var bv := -1.0
	for id in stats:
		var s: Dictionary = stats[id]
		var v := float(s.goals) * 1.2 + float(s.gains) * 3.0 + float(s.intercepts) * 1.0 + float(s.feeds) * 0.6 + float(s.cpr) * 0.4 + float(s.rebounds) * 1.5 - float(s.penalties) * 0.3 - float(s.turnovers) * 1.0
		if int(s.team) == (0 if score[0] >= score[1] else 1):
			v += 3.0
		if v > bv:
			bv = v
			best = id
	return {"config": config, "score": score.duplicate(), "q_scores": q_scores.duplicate(true), "stats": stats.duplicate(true),
		"winner": 0 if score[0] > score[1] else (1 if score[1] > score[0] else -1), "potm": best, "user_team": user_team,
		"log": log, "calls": calls.duplicate(), "periods": q}


# ---------------------------------------------------------------- you

func _pick_me() -> void:
	if user_team < 0:
		return
	if int(Game.settings.control) == Game.CONTROL_BIB:
		_set_me(player_at(user_team, String(config.get("bib", Game.settings.bib))))
	else:
		_set_me(player_at(user_team, "C"))


func _set_me(pl: Player) -> void:
	if pl == null or (int(Game.settings.control) == Game.CONTROL_BIB and me != null and pl != me):
		return
	if me:
		me.fenced = true
	me = pl
	me.fenced = bool(Game.settings.onside)
	ai.me = pl
	if hud:
		hud.on_me(pl)


## Your player: the stick moves her (or, with the ball, turns her and picks whom to pass to); the buttons do the rest
## (_on_action). In whole-team play the player you control follows the ball.
func _drive_me(dt: float) -> void:
	if me == null or controls == null:
		return
	if int(Game.settings.control) == Game.CONTROL_TEAM and phase == "live":
		var att := possession == user_team
		if att and holder == null and pass_info.has("to") and (pass_info.to as Player).team == user_team:
			_set_me(pass_info.to)
		elif not att and me.team == user_team and controls.joystick.length() < 0.1:
			me_idle += dt
			if me_idle > 1.0:
				var near := ai.nearest_defender(user_team)
				if near and near != me:
					_set_me(near)
	var j: Vector2 = controls.joystick
	if j.length() > 0.1:
		me_idle = 0.0
	var d := cam.court_dir(j)
	if me == holder:
		ai.user_aim = d
		return
	if phase == "setup" and String(restart.get("kind", "")) == Rules.CENTRE:
		return   # the centre pass: everyone to her spot first
	if ball.state == "flight" and pass_info.get("to") == me and j.length() < 0.1:
		return   # running on to the pass (TeamAI)
	if out_of_play(me):
		return
	if j.length() > 0.1:
		var to := me.p + d.normalized() * 3.0
		if bool(Game.settings.onside):
			to = Rules.onside_point(me.pos, to, me.dir, 0.12)
		me.target = to
		me.want_speed = me.speed_cap() * clampf(j.length(), 0.3, 1.0)
		me.look_on = false
	elif not ai.is_assisted(me):
		me.target = me.p
		me.want_speed = 0.0
		me.look_on = true
		me.look_at_p = ball.court_pos()


func out_of_play(pl: Player) -> bool:
	return pl.away()


func _on_action(id: String) -> void:
	if paused or me == null:
		return
	match id:
		"PASS", "LOB":
			if me == holder:
				var target: Player = ai.user_target()
				if target:
					var kind := "lob" if id == "LOB" else ai.pass_kind(me, target)
					throw_pass(target, kind)
		"SHOOT":
			if me == holder:
				shoot()
		"INTERCEPT":
			ai.user_intercept(me)
		"DEFEND":
			ai.user_defend(me)
		"SWITCH":
			var n := ai.nearest_defender(user_team, me)
			if n:
				_set_me(n)


## What your buttons are now (TouchControls draws them): with the ball, pass and lob, and shoot when she may; in
## defence, intercept, defend and switch; otherwise none.
func button_set() -> Array:
	if me == null:
		return []
	if me == holder:
		if Rules.may_shoot(me.pos, me.landing, me.dir, from_free) and phase == "live":
			return ["SHOOT", "PASS", "LOB"]
		return ["PASS", "LOB"]
	if possession >= 0 and possession != user_team or (ball.state == "flight" and pass_info.has("from") and (pass_info.from as Player).team != user_team):
		if int(Game.settings.control) == Game.CONTROL_TEAM:
			return ["INTERCEPT", "DEFEND", "SWITCH"]
		return ["INTERCEPT", "DEFEND"]
	return []


# ---------------------------------------------------------------- pause, back, graphics

func set_paused(p: bool) -> void:
	paused = p
	Sfx.pause(p)
	if hud:
		hud.show_pause(p)
	get_tree().paused = false


func on_back() -> void:
	if phase == "replay" and not paused:
		_end_replay()
		return
	if paused and hud and hud.close_layer():
		return
	set_paused(not paused)


func quit_to_menu() -> void:
	paused = false
	Sfx.pause(false)
	Game.goto_menu()


## The auto graphics level (WsgAutoTier, the shared foundation's): all match long, two windows of stutter in a row
## (slow, or hitching) take a level off at once; again later if it still stutters. In the game itself only (the
## tests and tools play at fixed rates or draw in software), never in an AI v AI match.
func _auto_graphics(delta: float) -> void:
	if demo or not bool(Game.settings.get("auto_gfx", true)) or Game.main == null or Game.main.scene_file_path != "res://main.tscn":
		return
	if _auto_gfx.feed(delta) and int(Game.settings.graphics) > Game.GFX_LOW:
		lower_graphics()


## A graphics level down, now, mid-match: the setting (kept), the picture's size and smoothing, the outlines, the
## people's shadows, the foundation's tier (its bodies in full detail ranked again; its replay); on Low the game's own
## bodies again (Low draws exactly what it did) and no reserves. (The court, the venue and the crowd are built for a
## level when the match starts: the next match builds them at the new one.)
func lower_graphics() -> void:
	var fps := float(_auto_gfx.last[0])
	Game.settings.graphics = int(Game.settings.graphics) - 1
	Game.save_settings()
	Game.apply_graphics(get_viewport())
	WsgFoundation.tier = int(Game.settings.graphics)
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if low and phase == "replay":
		_end_replay()
	for who in players[0] + players[1] + umpires:
		if who.link == null:
			continue
		if low:
			who.link.release()
			who.link = null
		else:
			who.link.body.mesh_instance.cast_shadow = sh
		who.body.mesh_instance.cast_shadow = sh
	if low:
		_reserves()
		if wsg_replay:
			wsg_replay.queue_free()
			wsg_replay = null
		_highlight = {}
	_detail_t = 0.0
	_auto_gfx.reset()
	game_event.emit("graphics_down", {"level": Game.settings.graphics, "fps": fps})


## The foundation's bodies in full detail nearest the camera only, as the game's profile allows (WsgFoundation:
## Netball is "premium": the nearest 14 on Medium, 22 on High), and the far ones posed every second or third frame
## (each on her own frames: Player._pose_link), twice a second.
func _rank_detail(dt: float) -> void:
	_detail_t -= dt
	if _detail_t > 0.0 or wsg_replay == null and not FoundationLink.enabled():
		return
	_detail_t = 0.5
	WsgFoundation.tier = int(Game.settings.graphics)
	var bodies := []
	var cam3 := get_viewport().get_camera_3d()
	var camp := cam3.global_position if cam3 else Vector3.ZERO
	var near: Array = POSE_NEAR[clampi(int(Game.settings.graphics), 0, 2)]
	for who in players[0] + players[1] + umpires:
		if who.link and who.link.body and who.is_visible_in_tree():
			bodies.append(who.link.body)
			if who is Player:
				var d: float = who.global_position.distance_to(camp)
				who.pose_every = 1 if d < float(near[0]) else (2 if d < float(near[1]) else 3)
	if not bodies.is_empty():
		WsgFoundation.rank_detail(bodies, camp)


## Metres from the camera within which a player is posed every frame, and every second (beyond: every third), by
## graphics level (the TV camera is 15-35 m from the play).
const POSE_NEAR := [[12.0, 20.0], [16.0, 26.0], [22.0, 36.0]]


# ---------------------------------------------------------------- replays (the shared foundation's WsgReplay)

const REPLAY_BEFORE := 4.0      # s of play before the goal shown again
const REPLAY_AFTER := 0.8
const REPLAY_RATE := 0.6        # slowed
const GAIN_BEFORE := 2.6        # an intercept's or deflection's: the pass and the take
const GAIN_AFTER := 1.0
const GAIN_STALE := 25.0        # s of play after which a kept intercept is no longer shown

var _tipped_by := -1            # the team that last deflected a pass, and when (a deflection that wins the ball)
var _tipped_at := -INF


## An intercept, or a deflection her team then took: kept to be shown at the next stoppage.
func _mark_highlight(pl: Player) -> void:
	if wsg_replay == null:
		return
	_highlight = {"t0": clock - GAIN_BEFORE, "t1": clock + GAIN_AFTER, "frames": [], "balls": [], "by": pl,
		"at": Vector3(pl.p.x, 0.0, pl.p.y)}


## Once its last moment has been drawn, the intercept's frames are copied out of the ring (which goes on and forgets
## them); a kept one goes stale.
func _keep_highlight() -> void:
	if _highlight.is_empty():
		return
	if (_highlight.frames as Array).is_empty() and clock >= float(_highlight.t1):
		_clip_highlight()
	elif clock > float(_highlight.t1) + GAIN_STALE:
		_highlight = {}


func _clip_highlight() -> void:
	_highlight.frames = wsg_replay.clip(float(_highlight.t0), float(_highlight.t1))
	var balls := []
	for b in _ball_ring:
		if float(b[0]) >= float(_highlight.t0) - 0.1 and float(b[0]) <= float(_highlight.t1) + 0.1:
			balls.append(b)
	_highlight.balls = balls


## A replay: a goal's after the TV camera's close shot of the post (from beside the post, the feed and the shot
## again, from the shot before when a rebound was scored), or a kept intercept's at a stoppage (from the side line);
## slowed, the foundation's bodies as they were drawn (WsgReplay) and the ball where it was. A tap skips it. False
## when there is nothing kept to show.
func _start_replay(kind: String) -> bool:
	if wsg_replay == null:
		return false
	var span := wsg_replay.span()
	var t0: float
	var t1: float
	var frames: Array = []
	var balls: Array = _ball_ring
	var rc := Camera3D.new()
	if kind == "goal":
		t0 = _goal_clock - REPLAY_BEFORE
		if _miss_clock > _goal_clock - 6.5:
			t0 = minf(t0, _miss_clock - 0.6)
		t1 = _goal_clock + REPLAY_AFTER
		if span.is_empty() or float(span[0]) > t0 + 1.5 or balls.is_empty():
			rc.free()
			return false
		t0 = maxf(t0, float(span[0]))
		var end := signf(ball.position.x) if absf(ball.position.x) > 1.0 else 1.0
		var ring := Court.ring_centre(int(end))
		# Low beside the post, out past the goal line, looking back up the circle.
		var side := 1.0 if _ring_at(balls, t0).z >= 0.0 else -1.0
		rc.fov = 44.0
		rc.position = Vector3(end * (Court.HALF_L + 1.6), 2.4, side * 3.6)
		_replay_look = ring
	else:
		var h := _highlight
		_highlight = {}
		if (h.frames as Array).is_empty():
			_highlight = h
			_clip_highlight()
			h = _highlight
			_highlight = {}
		frames = h.frames
		balls = h.balls
		if frames.is_empty() or balls.is_empty():
			rc.free()
			return false
		t0 = maxf(float(h.t0), float(frames[0][0]))
		t1 = minf(float(h.t1), float(frames[-1][0]))
		var at: Vector3 = h.at
		# From the side line nearer the play, level with it, a little up.
		var side := 1.0 if at.z >= 0.0 else -1.0
		rc.fov = 34.0
		rc.position = Vector3(clampf(at.x, -Court.HALF_L + 3.0, Court.HALF_L - 3.0) - signf(at.x + 0.01) * 3.0, 2.6, side * (Court.HALF_W + 4.5))
		_replay_look = at + Vector3.UP * 1.0
	if t1 <= t0 + 0.5:
		rc.free()
		return false
	add_child(rc)
	rc.look_at(_replay_look)
	rc.make_current()
	_replay = {"t": t0, "t1": t1, "cam": rc, "ball_at": ball.position, "hud": hud.visible if hud else false,
		"kind": kind, "balls": balls, "phase": phase, "phase_t": phase_t}
	if hud:
		hud.visible = false
	wsg_replay.play(t0, t1, frames)
	_enter("replay")
	_replay_step(0.0)
	game_event.emit("replay", {"kind": kind})
	return true


var _replay_look := Vector3.ZERO


static func _ring_at(ring: Array, t: float) -> Vector3:
	if ring.is_empty():
		return Vector3.ZERO
	var i := 0
	while i < ring.size() - 1 and float(ring[i + 1][0]) <= t:
		i += 1
	var a: Array = ring[i]
	var b: Array = ring[mini(i + 1, ring.size() - 1)]
	var w := 0.0 if a == b else clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	return (a[1] as Vector3).lerp(b[1], w)


func _replay_step(delta: float) -> void:
	var t: float = float(_replay.t) + minf(delta, 0.05) * REPLAY_RATE
	_replay.t = t
	if t >= float(_replay.t1):
		_end_replay()
		return
	wsg_replay.seek(t)
	var b := _ring_at(_replay.balls, t)
	ball.position = b
	# The camera stays put and follows the ball, smoothly (a goal's: between the ball and the ring).
	# (Never looking up past 2 m: the shooter and the players under the post stay in the picture as the ball drops in.)
	var want := Vector3(b.x, clampf(b.y, 0.9, 2.0), b.z)
	if String(_replay.kind) == "goal":
		var circle: Vector3 = _replay_look * Vector3(0.82, 0.0, 0.0) + Vector3(0.0, 1.3, 0.0)
		want = want.lerp(circle, 0.35)
	_replay["look"] = (_replay.get("look", want) as Vector3).lerp(want, minf(1.0, delta * 4.0)) if delta > 0.0 else want
	(_replay.cam as Camera3D).look_at(_replay.look)


## Back to the match: the bodies, the ball and the camera as they were; then what the match was about to do (the next
## centre pass after a goal; the award after a stoppage).
func _end_replay() -> void:
	if _replay.is_empty():
		return
	var r := _replay
	_replay = {}
	if wsg_replay:
		wsg_replay.stop()
	ball.position = r.ball_at
	(r.cam as Camera3D).queue_free()
	cam.close_dir = 0
	cam.make_current()
	if hud:
		hud.visible = bool(r.hud)
	phase = String(r.phase)
	phase_t = float(r.phase_t)
	if String(r.kind) == "goal":
		_setup_centre()
	# (A stoppage: its award is applied on the next frame, phase_t being past the call.)


## A tap (or a key) skips the replay.
func _input(event: InputEvent) -> void:
	if phase != "replay" or paused:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_end_replay()


## A team change (R3): at an interval, the player in pos comes off for the next one on the bench who plays it (her
## position or a neighbouring one). Returns whether anyone came on.
func substitute(pl: Player) -> bool:
	var t := pl.team
	var i := next_on(pl)
	if i >= 0:
		var e: Dictionary = bench[t][i]
		bench[t].remove_at(i)
		bench[t].append(pl.data)
		pl.data = e
		if not stats.has(String(e.id)):
			stats[String(e.id)] = _blank_stats(t, e)
		stats[String(e.id)].pos = pl.pos
		pl.body.queue_free()
		pl._ready()
		pl.place(pl.p, pl.facing)
		_reserves()
		game_event.emit("substitution", {"team": t, "pos": pl.pos})
		return true
	return false


## Who on the bench would come on for pl: the index in bench[pl.team], or -1 when no one plays her position.
func next_on(pl: Player) -> int:
	for i in bench[pl.team].size():
		var e: Dictionary = bench[pl.team][i]
		if String(e.pos) == pl.pos or pl.pos in (e.alt as Array):
			return i
	return -1
