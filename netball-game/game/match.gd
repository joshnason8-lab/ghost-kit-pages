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
var watch := false                  # Watch AI (an AI v AI match from the menus, watched): the broadcast with its sound,
                                    # the scoreboard, the intervals and the result, nobody's buttons, and the speed
var speed := 1                      # Watch AI's speed: play steps a frame (1 or 2), each the step a match always takes
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
## The after-goal tactical change (World Netball 2024, R3): after a goal, until the next centre pass is whistled, either
## team may ask for a substitution; it is made as the teams line up for that centre pass (_setup_centre), and the
## centre pass waits no longer for it than it always does.
var goal_changes: Array = [[], []]   # by team: the players on court asked to come off, made at the centre pass
var _after_goal := false            # a goal was scored and the next centre pass not yet whistled
## Positional changes (R3): two players on court swap positions, at the moments a substitution may be made (an
## interval, an injury stoppage, a time-out, after a goal). Asked for, they are made as the teams next line up: at the
## centre pass (_setup_centre), or as play restarts after an injury or a time-out; asked for while the teams line up
## for the centre pass after a goal, at once. Each must play her new position (her own or one of her alt positions).
var swaps: Array = [[], []]         # by team: [position, position] pairs asked for
var _ai_change_q := [0, 0]          # the period of each team's last after-goal change by the AI (one a quarter)
var _hurt_on := {}                  # Player -> true: hurt in a contact, played on (the AI takes her off after a goal)
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
var _loose_from: Player = null      # a pass nobody reached, running on loose: its thrower may not touch it first (R11)
var _loose_cp := false              # ... and it was the centre pass: whoever touches it first must be in the centre third (R8)
var _adv_by: Player = null          # advantage played on her infringement against _adv_on, in this hold (_adv_hold):
var _adv_on: Player = null          # the same infringement again is called at once (R7)
var _adv_hold := -1
var _holds := 0                     # the ball taken (caught, picked up, handed for a restart): a new hold each time


## Built by the loading overlay's steps (Game.start_match_loading: build_steps, each followed by a drawn frame) rather
## than all at once in _ready. The same parts, in the same order, either way.
var staged := false
## Under the loading overlay's warm-up and settle: the match runs (the bodies posed, the camera on the court) but the
## centre pass's whistle, the HUD (its team card) and the graphics' auto level wait for kick_off().
var held := false


func _ready() -> void:
	_setup()
	if staged:
		held = true
		return
	for s in build_steps():
		(s[1] as Callable).call()


## The match's rules and the umpires' toss, from its config (no nodes made).
func _setup() -> void:
	demo = bool(config.get("demo", false)) or int(config.get("user_team", 0)) < 0
	user_team = -1 if demo else int(config.get("user_team", 0))
	watch = demo and bool(config.get("watch", false))
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


## The match's building, in order, as [label, work, weight] steps: the venue, its draw calls, the crowd, each team's
## seven (a player at a time), the bench, the officials and ball and camera, the HUD, and the last touches. _ready runs
## them straight through; the loading overlay (LD, Game.start_match_loading) runs each in a frame of its own, the
## teams and the bench cut between players (WsgLoading.checkpoint), so no slice holds the main thread long on a slow
## phone. Under the overlay the teams' flags (the scoreboard's and the team card's) are drawn on a worker thread
## meanwhile (nothing of that in the match: the card finds them made).
func build_steps(ld: WsgLoading = null) -> Array:
	var steps := [
		["Venue", _build_venue, 2.0],
		["Court", func(): arena.build_draw(), 1.0],
		["Crowd", func(): arena.build_crowd(), 2.0],
		["Home team", func(): await _build_team(0, ld), 3.0],
		["Away team", func(): await _build_team(1, ld), 3.0],
		["Bench", func(): await _build_bench(ld), 1.0],
		["Umpires", _build_officials, 1.0],
		["Scoreboard", _build_hud, 1.0],
		["Centre pass", _build_last, 1.0],
	]
	if ld:
		var jobs := []
		for id in [String(config.get("home", "AUS")), String(config.get("away", "NZL"))]:
			if String(DB.team(id).get("kind", "")) == "country":
				jobs.append_array([[id, 300, 200], [id, 72, 48]])     # TeamCard's flag (150 x 100), the scoreboard's
		if not jobs.is_empty():
			var job := Flags.draw_async(jobs)
			steps.insert(steps.size() - 2, ["Flags", func(): await Flags.collect(job), 0.5])
	return steps


## The loading overlay has gone (Game.start_match_loading, after its warm-up and settle): the HUD and its team card
## come up and the centre pass's count starts, as on the first frame of a match built at once.
func kick_off() -> void:
	if not held:
		return
	held = false
	phase_t = 0.0
	if hud:
		hud.process_mode = Node.PROCESS_MODE_INHERIT
		hud.visible = true


func _build_venue() -> void:
	var home := String(config.get("home", "AUS"))
	arena = Arena.new(String(config.get("venue", "arena")), [DB.team(home).get("c1", Color.WHITE), DB.team(home).get("c2", Color.WHITE)])
	arena.staged = true
	add_child(arena)
	arena.build_venue()


## Team T's seven on court (a step's worth each player under the overlay), her stats, and the squad left on the bench.
func _build_team(t: int, ld: WsgLoading = null) -> void:
	var home := String(config.get("home", "AUS"))
	var away := String(config.get("away", "NZL"))
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
		if ld:
			await ld.checkpoint((i + 1) / 7.0)
	for entry in squad:
		if not _on_court(String(entry.id)):
			bench[t].append(entry)


func _build_bench(ld: WsgLoading = null) -> void:
	await _reserves(ld)


func _build_officials() -> void:
	for h in [-1, 1]:
		var u := Umpire.new(h)
		add_child(u)
		umpires.append(u)
	ball = Ball.new()
	ball.solid = arena.solid   # off the venue's props (WsgSolidProps)
	ball.struck.connect(_on_struck)
	add_child(ball)
	cam = CameraRig.new()
	cam.mode = Game.CAM_TV if watch else int(Game.settings.camera)   # Watch AI: the broadcast's camera
	add_child(cam)
	ai = TeamAI.new(self)
	_set_ends()


func _build_hud() -> void:
	if not bool(config.get("attract", false)) and not bool(config.get("headless_hud", false)) or not demo:
		hud = (load("res://game/hud.gd") as Script).new(self)
		add_child(hud)
		# Under the loading overlay: the HUD (and its team card's time) waits for kick_off().
		if held:
			hud.visible = false
			hud.process_mode = Node.PROCESS_MODE_DISABLED
	if not demo:
		controls = TouchControls.new()
		controls.action.connect(_on_action)
		hud.add_controls(controls)
		_pick_me()
	elif watch:
		hud.add_watch_bar()


func _build_last() -> void:
	Game.apply_graphics(get_viewport())
	_setup_centre(true)
	if heard():
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


## The reserves (bench) sitting on their team's bench (Arena.bench_seats), in tracksuits (the code-built figure, one
## shared mesh a team, no shadow): Medium and High only, so Low draws what it did. Rebuilt after a team change. Each
## stands where her feet are, in front of the bench, her hips SIT_BACK behind her over the seat (Poses.seated); at a
## goal her team's reserves stand and clap, then sit again (_bench_step). Where a venue has no seats, they stand at
## ease in front of the bench, as before.
func _reserves(ld: WsgLoading = null) -> void:
	var old := get_node_or_null("Reserves")
	if old:
		old.name = "ReservesOld"
		old.queue_free()
	if int(Game.settings.graphics) <= Game.GFX_LOW:
		return
	var root := Node3D.new()
	root.name = "Reserves"
	add_child(root)
	var all: int = bench[0].size() + bench[1].size()
	var made := 0
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
			b.set_meta("team", t)
			var seats: Array = arena.bench_seats[t]
			if i < seats.size():
				# On her seat: where her feet are, SIT_BACK in front of her hips, facing the court.
				var st: Dictionary = seats[i]
				var yaw := float(st.yaw)
				var hips: Vector3 = st.hips
				b.position = Vector3(hips.x, 0.0, hips.z) + Vector3(sin(yaw), 0.0, cos(yaw)) * SIT_BACK
				b.rotation.y = yaw
				b.set_meta("seat", st)
				b.apply(_seated_pose(b))
			else:
				var at := TeamAI.bench_spot(t) + Vector2((float(i) - (n - 1) * 0.5) * 0.75, 1.3)
				# On the floor in front of the bench, clear of it and the boards (never in a prop: WsgSolidProps.free_spot).
				b.position = arena.solid.free_spot(Vector3(at.x, 0.0, at.y), Player.BODY_R, Player.BODY_H)
				b.rotation.y = PI
				b.apply(Poses.at_ease())
			# On the player's model in a tracksuit of the team's colours (the foundation, Medium and High): posed once
			# (and again while she claps a goal).
			if FoundationLink.enabled():
				var l := FoundationLink.new(b, b, "reserve")
				root.add_child(l)
				b.set_meta("link", l)
				l.update(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO, b.rotation.y, "")
				# (On the bench, always the light mesh: the tier's full-detail bodies are the players' and umpires'.)
				if l.body:
					l.body.set_detail(false)
			made += 1
			if ld:
				await ld.checkpoint(float(made) / all)    # the loading overlay: a frame between reserves


## A seated reserve's hips this far behind where she stands (m): her feet just in front of the seat's edge, and
## standing up she is clear of the bench (Player.BODY_R and more from it).
const SIT_BACK := 0.5
## A goal on the bench: seconds the scorers' reserves are up clapping (standing up, clapping, sitting down).
const BENCH_CHEER_S := 4.0
var _bench_cheer := [-1.0, -1.0]    # seconds into each team's reserves' clap of a goal (-1: seated)


## A reserve's seated pose on her seat (in her body's own units: ToonBody is scaled to her height).
func _seated_pose(b: ToonBody) -> Dictionary:
	var st: Dictionary = b.get_meta("seat")
	var s := maxf(b.scale.y, 0.01)
	return Poses.seated(float((st.hips as Vector3).y) / s, SIT_BACK / s)


## How far up a seated reserve is standing (0 seated, 1 up), u seconds into her team's clap of a goal.
static func bench_stand(u: float) -> float:
	if u < 0.0:
		return 0.0
	return smoothstep(0.15, 0.75, u) * (1.0 - smoothstep(BENCH_CHEER_S - 0.8, BENCH_CHEER_S - 0.1, u))


## A goal: the scoring team's reserves stand and clap it (Medium and High: there are none on Low).
func _bench_goal(t: int) -> void:
	if get_node_or_null("Reserves") != null:
		_bench_cheer[t] = 0.0


## The reserves clapping a goal: up from the bench, clapping, down again; the others sit still (posed once).
func _bench_step(dt: float) -> void:
	for t in 2:
		if _bench_cheer[t] < 0.0:
			continue
		_bench_cheer[t] += dt
		var u: float = _bench_cheer[t]
		var done := u >= BENCH_CHEER_S
		var rs := get_node_or_null("Reserves")
		if rs:
			for b in rs.get_children():
				if not (b is ToonBody) or int(b.get_meta("team", -1)) != t or not b.has_meta("seat"):
					continue
				var k := 0.0 if done else bench_stand(u)
				b.apply(Poses.blend(_seated_pose(b), Poses.clap(u), k))
				var l: FoundationLink = b.get_meta("link") if b.has_meta("link") else null
				if l and is_instance_valid(l):
					l.update(dt, Vector2.ZERO, Vector2.ZERO, b.rotation.y, "")
		if done:
			_bench_cheer[t] = -1.0


## What of a reserve the props must keep out of (the props' audit, tests/prop_runs.gd): [[position, radius, height],
## ...] in world space. Standing (at ease, or up clapping): her whole body where she stands. Seated: her body above
## the seat over her hips, and her lower legs in front of the seat to the floor (her thighs lie along the seat's top).
static func reserve_parts(b: Node3D) -> Array:
	var u := -1.0
	var m := b.get_parent().get_parent() if b.get_parent() else null
	if m is Match:
		u = float((m as Match)._bench_cheer[int(b.get_meta("team", 0))])
	if not b.has_meta("seat") or bench_stand(u) > 0.5:
		return [[b.global_position, Player.BODY_R, Player.BODY_H]]
	var st: Dictionary = b.get_meta("seat")
	var hips: Vector3 = st.hips
	var fwd := Vector3(sin(float(st.yaw)), 0.0, cos(float(st.yaw)))
	return [[Vector3(hips.x, hips.y + 0.03, hips.z), 0.17, 0.9],
		[Vector3(hips.x, 0.0, hips.z) + fwd * (float(st.edge) + 0.17), 0.12, hips.y - 0.03]]


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
	_bench_step(delta)
	if phase == "replay":
		_replay_step(delta)
		return
	if not held:
		_auto_graphics(delta)    # (not the warm-up's and settle's frames)
	# Watch AI at 2x: the match takes two of its steps a frame, each exactly the step it takes at 1x (the same dt, cut
	# at 0.05 s as always), so the AI, the players and their bodies, the ball, the umpires, the clock and the sounds
	# they make all run twice as fast together and play as they would at 1x. A replay keeps its own slowed pace (a tap
	# skips it); the bodies are kept for it once a frame, as they are drawn.
	for i in maxi(speed, 1):
		_step(delta)
		if phase == "replay" or paused or _ended:
			break
	if wsg_replay and phase != "replay":
		wsg_replay.record(clock)
		_ball_ring.append([clock, ball.position])
		while _ball_ring.size() > 2 and float(_ball_ring[0][0]) < clock - wsg_replay.seconds:
			_ball_ring.pop_front()
		_keep_highlight()


## One step of play: the phase, the clock, the AI, everyone's movement and the ball, the camera.
func _step(delta: float) -> void:
	var dt := minf(delta, 0.05)
	phase_t += dt
	clock += dt
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
	_off_court.clear()
	for t in 2:
		for pl in players[t]:
			if not Court.on_court(pl.p) and not pl.away():
				_off_court.append(pl.p)
	if phase == "setup" and String(restart.get("kind", "")) == Rules.THROW_IN and restart.has("spot"):
		_off_court.append(restart.spot)
	elif phase == "stop" and String(_stop_award.get("kind", "")) == Rules.THROW_IN:
		_off_court.append(Rules.throw_in_spot(_stop_award.at))   # (the spot from the whistle: she steps off it)
	for u in umpires:
		if phase == "break":
			u.to_middle()
		else:
			u.follow(ball.court_pos())
			u.keep_clear(_off_court)
		u.advance(dt, ball.court_pos())
	ball.step(dt)
	if heard() and phase in ["setup", "live", "goal"]:
		_movement_sounds(dt)
	if Game.test_quarter_s > 0.0 and OS.has_feature("web") and Engine.get_process_frames() % 15 == 0 and Game.current == self:
		# A browser playtest reads the match's state from the page (tools/playtest/play.js).
		JavaScriptBridge.eval("window.cpn = %s" % JSON.stringify({"phase": phase, "q": q, "score": score, "me": me.pos if me else "",
			"buttons": button_set(), "holder": holder.pos if holder else "", "mine": holder != null and holder.team == user_team}))
	var att := team_dir(possession) if possession >= 0 else 0
	cam.end_dir = team_dir(maxi(user_team, 0))
	# At a break the camera looks over to the huddles by the benches.
	cam.track(Vector2(0.0, Court.HALF_W) if phase == "break" else ball.court_pos(), 0 if phase == "break" else att, dt)


## The players outside the lines and a throw-in's spot (from its whistle) this step: the umpires stand off them (Umpire.keep_clear).
var _off_court: Array = []


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
	_apply_goal_changes()
	_apply_swaps()
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
	taker.target = round_circles(taker.pos, taker.dir, taker.p, spot)
	taker.want_speed = 4.5
	var there := taker.p.distance_to(spot) < 0.35
	# (A ball tossed on to her is hers once it has come down, not out of the air above her.)
	var down := not (ball.state == "dead" and ball._moving and ball.carrier == null and ball.pos.y > Ball.R + 0.05)
	if there and down and ball.state != "held" and (_out_clear(taker) or phase_t > 3.0):
		taker.target = taker.p
		_give(taker, false)
		from_free = String(restart.kind) == Rules.FREE or (String(restart.kind) == Rules.PENALTY and not bool(restart.shot))
		taker.stopped = true
		var out: Player = restart.get("out")
		if out and is_instance_valid(out):
			# Beside her where she has stopped (a step from the mark at most), clear of her body and her landing foot.
			restart.out_at = Rules.out_of_play_spot(out.pos, out.dir, taker.landing, taker.dir, taker.p)
	if held:
		return    # under the loading overlay: the whistle waits for kick_off()
	if ball.state == "held" and holder == taker:
		if String(restart.kind) == Rules.CENTRE:
			# The centre pass: everyone in her third, then the whistle.
			var settle := 3.0 if not _cp_whistled else 3.2
			if phase_t > settle and (ai.settled() or phase_t > settle + 2.5):
				_go_live()
		else:
			# A free or penalty pass, a throw-in: taken as soon as the taker is on her spot (and the penalised player
			# beside her, the others 0.9 m and more off her: the umpire waits for them).
			var out: Player = restart.get("out")
			var ready := (out == null or not is_instance_valid(out) or out.p.distance_to(restart.get("out_at", out.target)) < 0.15) and ai.nearest_opponent(taker) >= Court.DEFEND_DIST
			if (phase_t > 0.5 and ready) or phase_t > 4.0:
				_go_live()
	elif phase_t > 9.0 and taker.p.distance_to(spot) < 1.5:
		# Near enough (another player stood on the spot): the pass is taken from where she is.
		restart.spot = taker.p


## At a penalty pass the thrower takes the ball on her spot once the penalised player has stepped clear of her
## (Rules.OUT_OF_PLAY_MIN and more off her and the spot, and not in front of her): the umpire sees to it first.
func _out_clear(taker: Player) -> bool:
	var out: Player = restart.get("out")
	if out == null or not is_instance_valid(out) or not out.away():
		return true
	var spot: Vector2 = restart.get("spot", restart.at)
	var near := Rules.OUT_OF_PLAY_MIN - 0.02
	if out.p.distance_to(taker.p) < near or out.p.distance_to(spot) < near:
		return false
	var u := (Court.goal_post(taker.dir) - taker.p).normalized()
	var rel := out.p - taker.p
	return not (rel.dot(u) > 0.25 and absf(rel.cross(u)) < 0.8)


## The next point on the way from p to spot for a player in position pos (attacking toward dir): round a goal circle she
## may not enter, along its edge, rather than straight at it (she would stop at the line and never get there: a
## throw-in over the goal line beyond the circle, a stall). The spot itself once the straight way is clear.
static func round_circles(pos: String, dir: int, p: Vector2, spot: Vector2) -> Vector2:
	var a: Array = Rules.AREAS[pos]
	for end: int in [dir, -dir]:
		var circle := Court.A_ATT_CIRCLE if end == dir else Court.A_DEF_CIRCLE
		if circle in a:
			continue
		var c := Court.goal_post(end)
		var seg := spot - p
		var t := clampf((c - p).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
		if (p + seg * t).distance_to(c) >= Court.CIRCLE_R + Court.LINE_W:
			continue   # (the straight way stays out of it: a spot just outside the circle is reached straight)
		# Along the edge (a little outside it), a step of the arc at a time, the short way round toward the spot.
		var a0 := (p - c).angle()
		var turn := wrapf((spot - c).angle() - a0, -PI, PI)
		var r := maxf(Court.CIRCLE_R + 0.5, (p - c).length())
		return c + Vector2.from_angle(a0 + clampf(turn, -0.35, 0.35)) * r
	return spot


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
	_after_goal = false
	hold_t = 0.0
	hold_ready = true
	if String(restart.kind) == Rules.CENTRE:
		_cp_whistled = true
		cp_n += 1
	_whistle("long" if String(restart.kind) == Rules.CENTRE else "short", -6.0)
	if String(restart.kind) == Rules.CENTRE:
		ai.on_centre_whistle(int(restart.to))
	game_event.emit("whistle", {"kind": restart.kind})


## The ball to a player: she has caught it (or been handed it for a restart). ease: a loose ball she met within her
## reach, brought in to her hands over that many seconds (Ball.hold), not put there.
func _give(pl: Player, caught := true, ease := 0.0) -> void:
	holder = pl
	_holds += 1
	_loose_from = null
	_loose_cp = false
	ball.hold(pl, ease)
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
	if caught and heard():
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


## A pass from the holder to a team-mate. kind: chest, shoulder, bounce, lob. The flight follows the pass's kind and
## length under gravity (Ball.plan); the receiver runs to meet it; a defender who can reach its path in time may go
## for it (TeamAI).
func throw_pass(to: Player, kind: String) -> void:
	if holder == null or phase != "live":
		return
	var from := holder
	var catch_at := ai.catch_point(to, kind)
	var hand := from.hand_point()
	var arrive := Vector3(catch_at.x, TeamAI.catch_height(to, kind), catch_at.y)
	from.set_act("pass", kind)
	var dur := float(ball.throw(kind, hand, arrive).dur)
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
	var at := Vector2(ball.f_to.x, ball.f_to.z)
	if to.p.distance_to(at) > 1.3:
		# She was not there: the ball goes on as it was going, falls, bounces and rolls (Ball._fall). Nobody has touched
		# it: its thrower may not be the first to (replayed ball), and a centre pass is still to be touched in the
		# centre third (_run_loose).
		ball.loose(ball.pos, ball.velocity())
		stats[String(from.data.id)].turnovers += 1
		_loose_cp = bool(pass_info.get("centre", false))
		pass_info = {}
		_loose_from = from
		return
	var p_catch := 0.985 - (0.04 if pass_info.kind == "bounce" else 0.0) - (0.03 if pass_info.kind == "lob" else 0.0)
	if rng.randf() > p_catch:
		var v := Vector3(rng.randf_range(-2, 2), 1.5, rng.randf_range(-2, 2))
		last_touch = to.team
		ball.loose(ball.pos, v)
		stats[String(to.data.id)].turnovers += 1
		if heard():
			Sfx.react("groan", -16.0)
		game_event.emit("fumble", {"by": to.pos})
		pass_info = {}
		return
	var info := pass_info
	pass_info = {}
	var leap_t := to.act_t if to.act == "leap" else -1.0
	_give(to)
	if leap_t >= 0.0:
		# A lob taken at the top of her leap: she comes down with it (TeamAI._holder then has her hold it).
		to.set_act("leap")
		to.act_t = leap_t
	else:
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


const LOOSE_EASE := 0.22           # s: a loose ball she meets, brought from where she met it into her hands (Ball.hold)


## A loose ball: the nearest players chase it; the first to reach it takes it. Over a line it is out of court.
func _run_loose() -> void:
	var b := ball.court_pos()
	if not Court.on_court(b) and ball.pos.y < 0.4:
		var crossed := Court.clamp_court(b)
		_award(Rules.throw_in(last_touch, crossed), null, "throw_in")   # (it rolls on, off the boards or the bench)
		return
	if ball.pos.y > 2.6:
		return
	# The first within reach takes it: her hands (Player.LOOSE_REACH round her) up to where they are now, standing or
	# at her leap (Player.meets: her hands go out to it, and up for a high one, TeamAI). Out of reach, she waits for it
	# to come down to her.
	var best: Player = null
	var bd := Player.LOOSE_REACH
	for t in 2:
		for pl in players[t]:
			if pl.away():
				continue
			if pl == _loose_from and pl != me:
				continue   # (she leaves her own pass for someone else: the AI knows the rule)
			var d: float = pl.p.distance_to(b)
			if d < bd and pl.meets(ball.pos) and not Rules.offside(pl.pos, b, pl.dir):
				bd = d
				best = pl
	if best:
		if best == _loose_from:
			# Her own pass, untouched since she threw it (R11): a free pass to the other team where she played it.
			_infringe("replayed_ball", best, b)
			return
		if _loose_cp and not Rules.centre_pass_ok(best.pos, best.p):
			# A centre pass first touched outside the centre third (or by a GS or GK, R8).
			_infringe("centre_pass_fault", best, b)
			return
		# (Brought in from where she met it to her hands: never a jump into them.)
		if best.team != possession:
			_gain(best, "loose", LOOSE_EASE)
		else:
			_give(best, true, LOOSE_EASE)
			best.set_act("catch")
		best.act_up = clampf((ball.pos.y - 1.3) / 1.0, -1.0, 1.0)
		if shot_info.get("rebound", false):
			stats[String(best.data.id)].rebounds += 1
			shot_info = {}


## A defender takes the ball: an intercept, a loose ball, a rebound.
func _gain(pl: Player, how: String, ease := 0.0) -> void:
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
	_give(pl, true, ease)
	pl.set_act("catch")
	pl.act_up = 0.6
	if pl.team == user_team and not demo:
		Game.haptic("intercept")
	if heard():
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


## The ball off one of the venue's props (Ball.struck, WsgSolidProps): its knock, and the rules. The goal post, its
## pad and the ring are in play (R: a ball off the post is play on); anything else stands outside the court, so a ball
## in play that touches it is out of court there (a throw-in from where it crossed), and rolls on from it, dead.
const GOAL_PROPS := ["goal post", "post pad", "ring", "ring arm", "goal light"]


func _on_struck(hit: Dictionary) -> void:
	var at: Vector3 = hit.pos
	var speed := float(hit.get("speed", 0.0))
	if heard() and speed > 0.8 and not (ball.f_struck and ball.state == "flight"):
		var metal := String(hit.get("sound", "")) == "clang"
		Sfx.play_at("rim" if metal else "bounce", at, -14.0 + 6.0 * clampf(speed / 8.0, 0.0, 1.0), randf_range(0.92, 1.08))
	if phase != "live" or ball.state == "flight":
		return
	var outside := not (String(hit.name) in GOAL_PROPS)
	if not pass_info.is_empty():
		# A pass that met a prop on its way is loose from there (and lost, if it went out).
		var from: Player = pass_info.get("from")
		if from and outside:
			stats[String(from.data.id)].turnovers += 1
		pass_info = {}
	if not outside:
		_loose_from = null   # (off the goal post: its thrower may play it again, R11)
		return
	_award(Rules.throw_in(last_touch, Court.clamp_court(Vector2(at.x, at.z))), null, "throw_in")   # (rolling on from it)


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
## shot (_run_shot), counted from when she faces the post (Player.squaring: one who caught facing away pivots first).
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


## How far (m, across the floor) from the ring's middle a shot leaves the hands at least: the ring's tube and the ball
## as it rises past the tube's level.
const SHOT_CLEAR := 0.45


## The shot's flight, frame by frame: released at 0.75 s, through the ring (or off it) when it arrives.
func _run_shot(dt: float) -> void:
	var pl: Player = shot_info.by
	if not shot_info.released and pl.squaring:
		return      # (she turns to the post first: Player.squaring)
	shot_info.t = float(shot_info.t) + dt
	if not shot_info.released:
		if float(shot_info.t) >= 0.75:
			_release_holder()
			shot_info.released = true
			var ring := Court.ring_centre(pl.dir)
			var to := ring + Vector3(0, 0.05, 0)
			if not shot_info.goal:
				# On the ring's rim (the ball's middle just outside its inside edge).
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.21, 0.29)
				to += Vector3(off.x, 0.0, off.y)
			var from := pl.hand_point() + Vector3(0, 0.15, 0)
			# Released over her head, not from under the ring (it goes up past the ring's tube, never through it).
			var off_r := Vector2(from.x - ring.x, from.z - ring.z)
			var axis := Vector2(pl.p.x - ring.x, pl.p.y - ring.z)
			if off_r.length() < SHOT_CLEAR and axis.length() > off_r.length():
				var k := clampf((SHOT_CLEAR - off_r.length()) / (axis.length() - off_r.length()), 0.0, 1.0)
				var o := off_r.lerp(axis, k)
				from = Vector3(ring.x + o.x, from.y, ring.z + o.y)
			ball.throw("shot", from, to)
			ball.through_ring = bool(shot_info.goal)   # (in, by the rules' call: through the ring's middle)
			Sfx.play("pass", -12.0, 0.9)
		return
	if ball.state == "flight" and ball.f_t >= ball.f_dur:
		var ring := Court.ring_centre(pl.dir)
		# (A miss stops where it touched the ring, the post or its arm (Ball.f_struck), so the rebound starts clear of it.)
		if shot_info.goal and not ball.f_struck:
			_goal(pl, int(shot_info.value))
			return
		# Off the ring: a rebound. The shooter may take it herself (it touched the goal post).
		var away := Vector3(pl.p.x - ring.x, 0, pl.p.y - ring.z).normalized()
		var v := away.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0)) * rng.randf_range(1.5, 3.2)
		v.y = rng.randf_range(0.5, 2.0)
		ball.loose(ball.pos, v)
		last_touch = pl.team
		shot_info = {"rebound": true}
		_miss_clock = clock - ball.f_dur - 0.75
		Sfx.play_at("rim", ring, -6.0)
		if heard():
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
	if ball.state == "flight":
		# On through the net, as fast as it dropped in (the net holds it back: Ball.step).
		var v := ball.flight_vel(1.0)
		ball.loose(ball.pos, Vector3(v.x * 0.3, minf(v.y, -1.5), v.z * 0.3))
	else:
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
	if heard():
		Sfx.react("cheer", -6.0 if pl.team == 0 else -9.0)
		# The umpire's whistle for the goal, a beat after the net.
		get_tree().create_timer(0.45, false).timeout.connect(_goal_whistle)
	if pl.team == user_team and not demo:
		Game.haptic("goal")
	pl.set_act("cheer")
	_bench_goal(pl.team)
	_after_goal = true
	for t in 2:
		if t != user_team:
			_ai_goal_change(t)
	log.append({"t": _elapsed(), "q": q, "goal": pl.team, "by": pl.pos, "value": value})
	# A side four or more behind may call a time-out after the goal (the AI's; yours is in the pause menu).
	var other := 1 - pl.team
	if other != user_team and int(timeouts[other]) > 0 and score[pl.team] - score[other] >= 4 and rng.randf() < 0.35:
		call_timeout.call_deferred(other)
	game_event.emit("goal", {"team": pl.team, "by": pl.pos, "value": value})
	# Played on to a two-goal lead (level after extra time): this goal may have won it.
	if q >= 7 and Rules.match_over(q, false, score, need_winner):
		_end_period()


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
	# Advantage is played once for a player's infringement on the shooter: the same player infringing her again while
	# she still holds that ball is called at once (the umpire does not wave play on a second time).
	var again: bool = by == _adv_by and holder == _adv_on and _holds == _adv_hold
	if Rules.INFRINGEMENTS.get(kind, "") == Rules.PENALTY and holder and holder.team == other and holder.pos in ["GS", "GA"] \
			and Court.in_circle(holder.landing, holder.dir) and not from_free and not again and rng.randf() < 0.6:
		_advantage(kind, by)
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


## Advantage (R7): the shooter is set to shoot; the umpire calls "Advantage", the infringement, and plays on. The
## offender steps clear of the player she infringed (TeamAI.give_way).
func _advantage(kind: String, by: Player) -> void:
	stats[String(by.data.id)].penalties += 1
	_adv_by = by
	_adv_on = holder
	_adv_hold = _holds
	if holder:
		ai.give_way(by, holder)
	game_event.emit("advantage", {"kind": kind, "by": by.pos, "team": by.team})
	log.append({"t": _elapsed(), "q": q, "advantage": kind, "team": by.team})


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
	ai.end_slips()
	_loose_from = null
	_loose_cp = false
	_stop_award = a
	_stop_award.by = by
	_stop_award.signal = kind
	pass_info = {}
	shot_info = {}
	if holder:
		holder.stopped = false
	var had: Player = ball.holder if ball.state == "held" else null
	holder = null
	# (In the air or rolling when the whistle goes, it carries on and falls; in her hands, she keeps it: Ball.dead.)
	ball.dead(ball.pos, had == null, had)
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
## the ball is released (R6): an arm's length and more to her side (Rules.OUT_OF_PLAY_GAP, never touching her), square
## to her line to the goal she attacks or a little behind it, never in front of her (out_of_play_spot). Everyone
## else keeps 0.9 m and more off the spot as it is set up (TeamAI.keep_clear).
func _apply_award(a: Dictionary) -> void:
	restart = {"to": int(a.to), "kind": String(a.kind), "at": a.at, "shot": bool(a.shot), "why": String(a.get("why", ""))}
	_choose_taker()
	if ball.state == "dead" and ball.carrier and ball.carrier != restart.taker:
		# She hands it on: a toss to the spot, a bounce on the way.
		var to_spot := Vector3(restart.spot.x, Ball.R, restart.spot.y)
		ball.toss(to_spot, clampf(ball.pos.distance_to(to_spot) / 7.0, 0.35, 0.9))
	var by: Player = a.get("by")
	if String(a.kind) == Rules.PENALTY and by and is_instance_valid(by) and by.suspended <= 0.0:
		var taker: Player = restart.taker
		restart.out_at = Rules.out_of_play_spot(by.pos, by.dir, restart.spot, taker.dir)
		by.target = restart.out_at
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
	if heard():
		Sfx.react("applause", -10.0)
	_break_skip = false
	_break_next = nxt
	_break_shown = false
	if holder:
		holder.stopped = false
	holder = null
	pass_info = {}
	shot_info = {}
	var had: Player = ball.holder if ball.state == "held" else null
	ball.dead(ball.pos, had == null, had)


## Seconds of the teams going to their huddles before the interval screen comes up over them: once they are all
## there, after HUDDLE_MIN at least and HUDDLE_S at most.
const HUDDLE_S := 6.5
const HUDDLE_MIN := 2.5
## Seconds Watch AI's interval screen stays up before play goes on by itself (at the match's speed).
const WATCH_BREAK_S := 7.0


func _run_break(_dt: float) -> void:
	# The teams huddle by their benches (TeamAI.huddle), then the interval screen; yours waits for Continue (the
	# interval's real length is shown on the HUD). A demo match goes straight on (the home screen's after its huddle).
	if hud and not _break_shown and (phase_t > HUDDLE_S or phase_t > HUDDLE_MIN and ai.huddled()):
		_break_shown = true
		hud.show_break(q, _break_next)
	var demo_wait := HUDDLE_S if bool(config.get("attract", false)) else 0.6
	if watch:
		demo_wait = HUDDLE_S + WATCH_BREAK_S   # Watch AI: the huddles, then the interval screen a while (Continue skips)
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
	elif hurt:
		_hurt_on[hurt] = true   # (she plays on: the AI may take her off after a goal)
	_apply_swaps()
	_break_skip = false
	if hud:
		hud.hide_break()
	_apply_award(_stop_award)


func _end_timeout() -> void:
	_apply_swaps()
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
	_after_goal = false     # (an interval: changes at the break; one asked for after the last goal is still made)
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
	if (not demo or watch) and is_inside_tree() and Game.current == self:
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
		me.bounds = Rect2()
	me = pl
	me.fenced = bool(Game.settings.onside)
	me.bounds = Rect2(-RUN_OFF_MAX, RUN_OFF_MAX * 2.0)
	ai.me = pl
	if hud:
		hud.on_me(pl)


const RUN_OFF_MAX := Vector2(Court.HALF_L + Court.RUNOFF - Player.BODY_R, Court.HALF_W + Court.RUNOFF - Player.BODY_R)


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
	var d := cam.court_dir(j, Vector3(me.p.x, 0.0, me.p.y))
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
		# No further than the run-off round the court (with Keep me onside off nothing else holds her: the hall's floor
		# goes on 8 m and more past it to its walls, the park's 1.5 m to its fences). She pulls up at its edge
		# (Player.bounds).
		to = to.clamp(-RUN_OFF_MAX, RUN_OFF_MAX)
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

## Whether the match is heard: yours, and Watch AI's (not the home screen's or a test's AI v AI match).
func heard() -> bool:
	return not demo or watch


## Watch AI's speed: 1 or 2 play steps a frame (the HUD's chip, the pause menu).
func set_speed(n: int) -> void:
	if not watch:
		return
	speed = clampi(n, 1, 2)
	game_event.emit("speed", {"speed": speed})


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
	speed = 1
	Sfx.pause(false)
	Game.goto_menu()


## The auto graphics level (WsgAutoTier, the shared foundation's): all match long, two windows of stutter in a row
## (slow, or hitching) take a level off at once; again later if it still stutters. In the game itself only (the
## tests and tools play at fixed rates or draw in software), never in an AI v AI match but Watch AI's.
func _auto_graphics(delta: float) -> void:
	if demo and not watch or not bool(Game.settings.get("auto_gfx", true)) or Game.main == null or Game.main.scene_file_path != "res://main.tscn":
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
		if who.link and who.link.body:   # (hidden ones too: under the loading overlay, she is shown at full detail else)
			bodies.append(who.link.body)
			if who is Player:
				var d: float = who.global_position.distance_to(camp)
				who.pose_every = 1 if d < float(near[0]) else (2 if d < float(near[1]) else 3)
	if not bodies.is_empty():
		_rank_full(bodies, camp)


## The players' and umpires' full detail: the nearest to the camera, WsgFoundation.full_bodies() of them at most (the
## tier's cap), the rest on the light mesh. A body near the cut keeps what it has (it changes only when its place in
## the order moves two or more), so none flickers between the two meshes as the play moves.
func _rank_full(bodies: Array, camp: Vector3) -> void:
	var n := WsgFoundation.full_bodies()
	var order := bodies.duplicate()
	order.sort_custom(func(a, b): return (a as Node3D).global_position.distance_squared_to(camp) < (b as Node3D).global_position.distance_squared_to(camp))
	var want := []
	for i in order.size():
		var b: WsgBody = order[i]
		if i < n - 1 or (i <= n and b.full):
			want.append(b)
	# (At most the cap, nearest first; any place left, the next nearest.)
	want = want.slice(0, n)
	for b in order:
		if want.size() >= n:
			break
		if not want.has(b):
			want.append(b)
	for b: WsgBody in order:
		b.set_detail(want.has(b))


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
		# (Everyone shown back where play stopped at once: each foundation planter lets go of its feet - a cut.)
		for who in players[0] + players[1] + umpires:
			if who.link and is_instance_valid(who.link):
				who.link.placed()
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


## The after-goal tactical change (R3, since 2024): whether team t may ask for one now. Only after a goal, until the
## next centre pass is whistled (the goal's stoppage, its replay, the line-up for the centre pass); never in play.
func can_goal_change(t: int) -> bool:
	if t < 0 or t > 1 or not _after_goal:
		return false
	return phase in ["goal", "replay"] or (phase == "setup" and String(restart.get("kind", "")) == Rules.CENTRE)


## Asks for pl to come off in an after-goal change (for the next one on the bench who plays her position, as at an
## interval). Asked in the goal's stoppage, it is made as the teams line up for the centre pass; asked once they are
## lining up, at once. Asking again for one already asked for takes it back. Returns whether it is now asked for (or
## made).
func goal_change(pl: Player) -> bool:
	if pl == null or not can_goal_change(pl.team):
		return false
	var asked: Array = goal_changes[pl.team]
	if pl in asked:
		asked.erase(pl)
		return false
	if next_on(pl) < 0:
		return false
	if phase == "setup":
		return _goal_substitute(pl)
	asked.append(pl)
	return true


## The changes asked for after the goal, made as the teams line up for the centre pass.
func _apply_goal_changes() -> void:
	for t in 2:
		var asked: Array = goal_changes[t]
		goal_changes[t] = []
		for pl: Player in asked:
			if is_instance_valid(pl) and not pl.away():
				_goal_substitute(pl)


func _goal_substitute(pl: Player) -> bool:
	var off := String(pl.data.name)
	if not substitute(pl):
		return false
	log.append({"t": _elapsed(), "q": q, "goal_change": pl.pos, "team": pl.team})
	game_event.emit("goal_change", {"team": pl.team, "pos": pl.pos, "off": off, "on": String(pl.data.name)})
	return true


## The AI's after-goal change (one a quarter at most): a player hurt in a contact who played on comes off; else, now
## and then, a shooter well off her range (five shots and more, under half in) is rested. (The game models no
## tiredness, so none for that.) Chosen from the score, not the match's random stream, so play is otherwise unchanged.
func _ai_goal_change(t: int) -> void:
	if int(_ai_change_q[t]) == q or not (goal_changes[t] as Array).is_empty():
		return
	var pick: Player = null
	for pl: Player in players[t]:
		if _hurt_on.has(pl) and not pl.away() and next_on(pl) >= 0:
			pick = pl
			break
	if pick == null and (score[0] + score[1] + q) % 2 == 0:
		for pl: Player in players[t]:
			if not (pl.pos in ["GS", "GA"]) or pl.away() or next_on(pl) < 0:
				continue
			var s: Dictionary = stats.get(String(pl.data.id), {})
			var att := int(s.get("attempts", 0))
			if att >= 5 and int(s.get("goals", 0)) * 2 < att:
				pick = pl
				break
	if pick:
		_ai_change_q[t] = q
		(goal_changes[t] as Array).append(pick)


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
		_hurt_on.erase(pl)
		for pair: Array in (swaps[t] as Array).duplicate():
			if not swap_ok(t, String(pair[0]), String(pair[1])):
				(swaps[t] as Array).erase(pair)   # (she does not play the other position: the swap is off)
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


# ---------------------------------------------------------------- positional changes

## Whether team t may ask for a positional change now: at the moments a substitution may be made (an interval, an
## injury stoppage, a time-out; after a goal until the centre pass is whistled). Never in play, rolling changes or not.
func can_swap(t: int) -> bool:
	if t < 0 or t > 1:
		return false
	return phase in ["break", "injury", "timeout"] or can_goal_change(t)


## Whether a squad entry plays pos: her own position or one of her alt positions (DB.squad).
static func plays(e: Dictionary, pos: String) -> bool:
	return String(e.get("pos", "")) == pos or pos in (e.get("alt", []) as Array)


## Whether the players in positions a and b of team t could swap now: both on court (not suspended or ordered off) and
## each able to play the other's position.
func swap_ok(t: int, a: String, b: String) -> bool:
	if a == b:
		return false
	var pa := player_at(t, a)
	var pb := player_at(t, b)
	if pa == null or pb == null:
		return false
	for pl: Player in [pa, pb]:
		if pl.suspended > 0.0 or pl.ordered_off:
			return false
	return plays(pa.data, b) and plays(pb.data, a)


## The swap asked for that involves position pos for team t ([a, b]), or [] when none.
func swap_with(t: int, pos: String) -> Array:
	for pair: Array in swaps[t]:
		if pos in pair:
			return pair
	return []


## Asks for the players in positions a and b of team t to swap, or, asked again, takes it back. Each player is in one
## swap at most, and not in one with an after-goal substitution asked for. Asked while the teams line up for the
## centre pass after a goal, it is made at once. Returns whether it is now asked for (or made).
func ask_swap(t: int, a: String, b: String) -> bool:
	if not can_swap(t):
		return false
	var mine := swap_with(t, a)
	if not mine.is_empty() and b in mine:
		(swaps[t] as Array).erase(mine)
		return false
	if not mine.is_empty() or not swap_with(t, b).is_empty() or not swap_ok(t, a, b):
		return false
	for pl: Player in goal_changes[t]:
		if pl.pos == a or pl.pos == b:
			return false
	if phase == "setup":
		return _swap(t, a, b)
	(swaps[t] as Array).append([a, b])
	return true


## The positional changes asked for, made as the teams line up (each checked again: a substitution since may have
## brought on someone who does not play the other position).
func _apply_swaps() -> void:
	for t in 2:
		var asked: Array = swaps[t]
		swaps[t] = []
		for pair: Array in asked:
			_swap(t, String(pair[0]), String(pair[1]))


## Swaps the players in positions a and b of team t: each takes the other's bib (and so its areas), staying where she
## stands, and goes to her new position's spot from there. What is hers (a warning, suspensions, penalties since her
## last sanction, a knock she played on with) goes with her. The Player nodes stay with their positions.
func _swap(t: int, a: String, b: String) -> bool:
	if not swap_ok(t, a, b):
		return false
	var pa := player_at(t, a)
	var pb := player_at(t, b)
	var na := String(pa.data.name)
	var nb := String(pb.data.name)
	var d: Dictionary = pa.data
	pa.data = pb.data
	pb.data = d
	var at := [pb.p, pa.p]
	var face := [pb.facing, pa.facing]
	for k in ["warned", "suspensions", "pens"]:
		var v = pa.get(k)
		pa.set(k, pb.get(k))
		pb.set(k, v)
	var hurt_a := _hurt_on.has(pa)
	var hurt_b := _hurt_on.has(pb)
	_hurt_on.erase(pa)
	_hurt_on.erase(pb)
	if hurt_b:
		_hurt_on[pa] = true
	if hurt_a:
		_hurt_on[pb] = true
	var i := 0
	for pl: Player in [pa, pb]:
		var id := String(pl.data.id)
		if not stats.has(id):
			stats[id] = _blank_stats(t, pl.data)
		stats[id].pos = pl.pos
		pl.body.queue_free()
		pl._ready()
		pl.place(at[i], face[i])
		i += 1
	log.append({"t": _elapsed(), "q": q, "swap": [a, b], "team": t})
	game_event.emit("swap", {"team": t, "a": a, "b": b, "on_a": nb, "on_b": na})
	return true
