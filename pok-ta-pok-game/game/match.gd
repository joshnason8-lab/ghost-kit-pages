extends Node3D
## A match: the court and its people, the two sides, the ball, the judges, the camera and (for you) the screen's
## controls and scoreboard. It runs the game the way it is played (docs/RULES.md): a serve across the analco, the ball
## struck back and forth with the hips until it dies in a half, goes past an end, out over a side, or touches a
## player anywhere but the hip; then the judges call the raya, the count moves, and the side that won it serves.
## The rules module (game/rules.gd) says who wins each raya and what the count is; this only tells it what happened.
##
## config: home, away (team ids), venue, rules ("ulama" | "classic"), side (players a side), user_team (0, 1, -1),
## mode ("quick" | "cup" | "watch" | "attract" | "test"), stage, length (real minutes, 0 none), seed, difficulty, urria.

enum P { INTRO, SERVE, LIVE, CALL, OVER, REPLAY }

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
var first_serve := 0          # the side serving first (home; config first_serve swaps it)
var half := 1                 # M6 (the revival): two halves; the other side serves to open the second
var turn_team := -1           # M4 (the revival): the side that struck last this rally (-1: none since the serve)
var turn_crossed := false     # and whether the ball has crossed into the other half since
var _half_at := -1            # the count's history length when the second half began
var fetcher: Player = null    # sent for a dead ball (the simulator's fetch case: fetch()); the walk-out waits for him
var fetch_spot := Vector3.INF
var _fetch_path := PackedVector3Array()
var paused := false
## Watching the computer play (mode "watch"): 1 or 2 steps of the match a frame (the HUD's 1x / 2x).
var speed := 1
var _finished := false
var _crowd_x := 0.0           # where the crowd is watching, along the court (smoothed)
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
var _hitstop := 0.0


func _ready() -> void:
	attract = bool(config.get("attract", false)) or String(config.get("mode", "")) == "attract"
	# The shared foundation draws the players and judges made from here on (Medium and High: FoundationLink), not in
	# the match behind the menus.
	FoundationLink.in_match = not attract
	FoundationLink.frozen = false
	WsgFoundation.tier = int(Game.settings.graphics)
	user_team = int(config.get("user_team", -1))
	rng.seed = int(config.get("seed", randi()))   # wsg-rng-ok: no seed given, one drawn and kept (rng.seed) to replay it
	var vid := String(config.get("venue", "village"))
	rules = String(config.get("rules", DB.venue(vid).rules))
	court = Court.new(rules)
	court.ringed = bool(DB.venue(vid).get("rings", true))
	count = Rules.Count.new(rules, String(config.get("urria", Game.settings.get("urria", "3_7"))))
	limit_s = float(config.get("length", 10)) * 60.0
	if rules == Rules.MAYA and limit_s <= 0.0:
		# M6: the revival has no target; it always plays to the clock (two halves of 13 minutes by default).
		limit_s = Rules.MAYA_HALF_MIN * 2.0 * 60.0
	for k in 2:
		tstats[k] = {"rayas": 0, "dead": 0, "end": 0, "won_out": 0, "won_touch": 0, "ring": 0, "faults_touch": 0, "faults_out": 0,
			"strikes": 0, "dives": 0, "serves": 0}
	if bool(config.get("deferred", false)):
		# Started from a menu: built in steps under the loading overlay (Game.start_match calls build), the match
		# still until it is.
		set_process(false)
		return
	build(null)


## Everything the match is made of: the venue and its crowd, the ball, the judges, both sides, the camera, the HUD.
## LD (the loading overlay, WsgLoading): a frame drawn between the parts, so the bar moves and nothing freezes; null:
## straight through (the tests, the match behind the menus).
var built := false
func build(ld: WsgLoading) -> void:
	if ld:
		await build_venue(ld)
		await build_sides(ld)
		await build_rest(ld)
	else:
		build_venue(null)
		build_sides(null)
		build_rest(null)


## The venue, its crowd and the ball and judges.
func build_venue(ld: WsgLoading) -> void:
	var vid := String(config.get("venue", "village"))
	var home := DB.team(String(config.get("home", "ESC")))
	var away := DB.team(String(config.get("away", "LLA")))
	venue = Venue.new()
	add_child(venue)
	if ld:
		await venue.build(vid, court, home.c1, away.c1)
		await ld.checkpoint(0.8)
	else:
		venue.build(vid, court, home.c1, away.c1)
	ball = Ball.new()
	add_child(ball)
	ball.setup(court, String(venue.info.floor))
	officials = Officials.new()
	add_child(officials)
	officials.build(court)
	if ld:
		await ld.checkpoint(1.0)


## Both sides' players and their brains.
func build_sides(ld: WsgLoading) -> void:
	var side := int(config.get("side", Rules.default_side(rules)))
	if not (side in Rules.side_sizes(rules)):
		side = Rules.default_side(rules)
	var level := int(config.get("difficulty", Game.settings.difficulty))
	# The full body on High; the lighter one (a third of the triangles) on Low and Medium, which at the court-side
	# camera's distance looks the same.
	var lod := 0 if int(Game.settings.graphics) >= Game.GFX_HIGH else 1
	for k in 2:
		var tid := String(config.get("home" if k == 0 else "away", "ESC" if k == 0 else "LLA"))
		var roster := DB.roster(tid, side, "classic" if court.classic() else "ulama")
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
			if ld:
				await ld.checkpoint(float(k * roster.size() + i + 1) / float(2 * roster.size()))
		var lvl := level if k != user_team else 1
		if user_team < 0:
			lvl = clampi(level, 1, 2)
		if config.has("levels"):
			# Each side its own level (the simulations' strong against weak; the game's menus give one for both).
			lvl = clampi(int(config.levels[k]), 0, 2)
		var ai := TeamAI.new(self, k, ps, lvl, int(rng.seed))
		for i in ps.size():
			(ps[i] as Player).role = ai.role_of(i)
			var spot := ai.home_spot(i)
			# They walk on from the side of the court.
			(ps[i] as Player).global_position = court.clamp_feet(spot + Vector3(-Rules.dir(k) * 2.0, 0, (3.5 if not court.classic() else 3.0) * (1.0 if i % 2 == 0 else -1.0)))
		teams.append({"id": tid, "players": ps, "ai": ai})
	officials.set_lod(lod)
	if ld:
		await ld.checkpoint(1.0)


## The replays' keeper, the server, the camera, the HUD, the sound, the copal offering.
func build_rest(ld: WsgLoading) -> void:
	if FoundationLink.enabled():
		# The foundation's bodies as drawn, kept for the replays (as long as the game keeps its own, every frame).
		wsg_replay = WsgReplay.new()
		add_child(wsg_replay)
		wsg_replay.seconds = REPLAY_KEEP + 0.5
		wsg_replay.rate = 30.0
	if user_team >= 0:
		user_player = teams[user_team].players[0]
		user_player.user = true
	# The first serve is home's (docs/RULES.md); config first_serve lets the balance tests swap it (tests/balance_sim).
	first_serve = clampi(int(config.get("first_serve", 0)), 0, 1)
	serve_team = first_serve
	_pick_server()
	ball.held = true
	ball.pos = Vector3(0, Ball.RADIUS, 0)
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	if watching():
		# Watching: the broadcast view, whatever camera the player's own matches use (the button still changes it).
		cam.mode = Game.CAM_TV
		cam.snap(self)
	if not attract and String(config.get("mode", "")) != "test":
		hud = (load("res://game/hud.gd") as Script).new()
		hud.m = self
		add_child(hud)
		hud.action.connect(_on_action)
	Game.apply_graphics(get_viewport())
	if not attract:
		Sfx.crowd(0.35)
		Sfx.ambience(venue.id if venue else "")
	if Crowd.needs_bake():
		# The graphics level changed since the crowd's sheet was made: made again for this one (a few frames).
		Crowd.bake(self)
	phase = P.INTRO
	phase_t = 0.0
	if ld:
		await ld.checkpoint(0.5)
	# On the Yucatán stone courts the game opens with an offering of copal (Ritual).
	if bool(config.get("ritual", not attract and String(config.get("mode", "")) != "test")) and venue and venue.id in RITUAL_VENUES:
		ritual = Ritual.new()
		add_child(ritual)
		ritual.setup(self)
		if hud:
			hud.banner(tr("RITUAL_COPAL"), Game.C_GOLD)
		if not attract:
			Sfx.crowd(0.12)
	_first_pose()
	built = true
	# Under the loading overlay the clock starts once it has gone (Game.start_match: kick_off), not behind it.
	if not bool(config.get("deferred", false)):
		set_process(true)


## Everyone posed once before the first frame is drawn: the loading's warm-up draws them, and the first frame after
## the overlay shows them standing ready (the shared foundation's bodies are hidden until their first pose: the world
## check found ten players missing for a frame). Only the drawing: nothing of the play moves.
func _first_pose() -> void:
	for p in all_players():
		var pl: Player = p
		pl._link_dt = 1.0 / 30.0
		pl._pose(0.0)
	if officials:
		officials._process(1.0 / 30.0)


## The match begins: its clock, the AI, the copal (after the loading overlay's warm-up and settle: WsgLoading.done).
func kick_off() -> void:
	set_process(true)


const RITUAL_VENUES := ["stone", "night", "markers"]
var ritual: Ritual


## Is the opening offering still going on?
func in_ritual() -> bool:
	return ritual != null and not ritual.done


# ---------------------------------------------------------------- what the others ask

## M4 (the revival): may this side strike now? Not twice in a row before the ball has crossed into the other half.
func may_strike(team: int) -> bool:
	return rules != Rules.MAYA or turn_team != team or turn_crossed


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
	Sfx.pause(p)


## Watching the computer play both sides (the menu's "Watch AI").
func watching() -> bool:
	return String(config.get("mode", "")) == "watch" and user_team < 0


## The speed the match is watched at (1 or 2); only when watching.
func set_speed(s: int) -> void:
	speed = clampi(s, 1, 2) if watching() else 1
	if hud:
		hud.show_speed()


func on_back() -> void:
	set_paused(not paused)


# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if paused:
		return
	var real_delta := delta
	delta = minf(delta, 0.05)
	_check_frame_rate(delta, real_delta)
	# At 2x the match steps twice a frame, each step as at 1x (the ball's flight, the players' running unchanged).
	for i in speed:
		if _finished or paused or not is_inside_tree():
			break
		_tick(delta)


func _tick(delta: float) -> void:
	# The crowd follows the play along the court, turning their heads over about a second.
	_crowd_x = lerpf(_crowd_x, float(ball.pos.x), minf(1.0, delta * 1.8))
	Crowd.watch(_crowd_x, court.half_l())
	if wsg_replay:
		_rank_detail(delta)
	if _hitstop > 0.0:
		# The heavy ball meeting a hip: a moment's weight.
		_hitstop -= delta
		delta *= 0.3
	phase_t += delta
	if phase == P.REPLAY:
		_replay_step(delta)
		return
	if phase == P.LIVE:
		clock += delta
	_user_input()
	if phase == P.LIVE:
		ball_path = ball.predict(96)
	else:
		ball_path = []
	for t in teams:
		(t.ai as TeamAI).update(delta)
	officials.watch = ball.pos
	for p in all_players():
		(p as Player).holding = ball.held and p == server
		(p as Player).update(delta, court, Rules.dir(p.team), phase == P.INTRO or phase == P.OVER)
	_footsteps()
	_phase_logic(delta)
	# The ball, in small steps.
	_acc += delta
	while _acc >= STEP:
		_acc -= STEP
		_ball_step(STEP)
	if ball.held and server != null:
		ball.pos = server.body.hand_world() if server.body and server.action == Player.A.SERVE else server.global_position + Basis(Vector3.UP, server.yaw) * Moves.HAND_BALL
	if wsg_replay:
		_ball_in_drawn_hand()
	ball.show_at(ball.pos, delta)
	cam.follow(self, delta)
	if hud:
		hud.refresh()
	_record(delta)


## The simulator's fetch case (WsgSim, ADOPTING 5.17): the ball dead at SPOT, on the court, and the nearest player of
## the side whose half it is in sent for it as the AI sends a man anywhere (his want, Player.update's own steps, its
## push out of the props), the way round the props from the venue's WsgSolidProps.path. In the walk-out, which waits
## for him. Returns him, or null.
func fetch(spot: Vector3) -> Player:
	var side := 0 if spot.x * Rules.dir(0) < 0.0 else 1
	var best: Player = null
	for p in (teams[side].players as Array):
		if best == null or (p as Player).global_position.distance_to(spot) < best.global_position.distance_to(spot):
			best = p
	if best == null:
		return null
	phase = P.INTRO
	fetcher = best
	fetch_spot = Vector3(spot.x, 0.0, spot.z)
	_fetch_path = venue.solid.path(best.global_position, fetch_spot, Player.WALK_R) if venue and venue.solid else PackedVector3Array([fetch_spot])
	ball.held = false
	ball.vel = Vector3.ZERO
	ball.pos = fetch_spot + Vector3(0, Ball.RADIUS, 0)
	return best


## Where the fetcher heads now: the next corner of his way, the spot at the last.
func fetch_next(p: Player) -> Vector3:
	while _fetch_path.size() > 1 and Vector2(p.global_position.x - _fetch_path[0].x, p.global_position.z - _fetch_path[0].z).length() < 0.35:
		_fetch_path.remove_at(0)
	return _fetch_path[0] if _fetch_path.size() > 0 else fetch_spot


func _phase_logic(_delta: float) -> void:
	match phase:
		P.INTRO:
			if fetcher != null:
				return
			if in_ritual():
				ritual.step(_delta)
				if not ritual.done:
					return
				phase_t = INTRO_T
				if not attract:
					Sfx.crowd(0.35)
			if phase_t >= INTRO_T:
				_to_serve()
		P.SERVE:
			_serve_logic()
		P.CALL:
			if _replay_kind != "" and not _replayed and not attract and phase_t >= REPLAY_AFTER:
				_start_replay()
				return
			if phase_t >= CALL_T:
				for p in all_players():
					(p as Player).calm()
				if count.winner >= 0:
					_to_over()
				elif rules == Rules.MAYA and half == 1 and limit_s > 0.0 and clock >= limit_s * 0.5:
					# M6: half time; the side that received first serves to open the second half.
					half = 2
					_half_at = count.history.size()
					if hud:
						hud.banner(tr("HALF_TIME"), Game.C_GOLD)
					_to_serve()
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
	# The first serve (and the second half's, M6) is set; after a raya the side that won it serves (R11).
	if half == 2 and count.history.size() == _half_at:
		serve_team = Rules.other(first_serve)
	elif count.history.is_empty():
		serve_team = first_serve
	else:
		serve_team = Rules.server(count)
	turn_team = -1
	turn_crossed = false
	_pick_server()
	rally = 0
	if hud:
		hud.serve_tag(serve_team, Rules.serve_kind(count))


func _pick_server() -> void:
	server = teams[serve_team].players[0]
	if user_team == serve_team and user_player != server and not one_player():
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
	server.start_serve(Rules.serve_kind(count) != "abajo")
	_serve_launched = true


## R11: the male. Abajo: thrown low across the analco to bounce up to the receivers; arriba: thrown high across it; on
## the stone court, bote.
func _launch_serve() -> void:
	if not ball.held:
		return
	var d := Rules.dir(serve_team)
	var kind := Rules.serve_kind(count)
	var hand := ball.pos
	var v: Vector3
	var zt := rng.randf_range(-0.8, 0.8) * (court.half_w_at(0.0) * 0.4)
	if kind == "abajo" or kind == "bote":
		# Thrown so it first bounces a few metres short of the other side's front player and comes up to them off the
		# ground, to be played off the bounce: on the stone court thrown down hard (bote); the low serve of the earth
		# courts underarm, on a lower arc (the owner, 0.6.3: the ball set up to bounce, not rolled along the earth).
		var abajo := kind == "abajo"
		var land_x := d * (rng.randf_range(ABAJO_LAND.x, ABAJO_LAND.y) if abajo else rng.randf_range(BOTE_LAND.x, BOTE_LAND.y))
		var dist := maxf(2.0, absf(land_x - hand.x))
		var ang := deg_to_rad(rng.randf_range(ABAJO_ANGLE.x, ABAJO_ANGLE.y) if abajo else rng.randf_range(BOTE_ANGLE.x, BOTE_ANGLE.y))
		var dy := hand.y - Ball.RADIUS
		var denom := 2.0 * cos(ang) * cos(ang) * (dist * tan(ang) + dy)
		var sp := sqrt(Ball.GRAVITY * dist * dist / maxf(denom, 0.01)) * 1.03
		v = Vector3(d * cos(ang) * sp, sin(ang) * sp, (zt - hand.z) / maxf(1.0, dist / 3.0))
	else:
		var dist := rng.randf_range(10.0, 17.0) if not court.classic() else rng.randf_range(7.0, 11.0)
		var ang := deg_to_rad(SERVE_HIGH_ANGLE)
		var sp := sqrt(Ball.GRAVITY * dist / sin(2.0 * ang))
		v = Vector3(d * cos(ang) * sp, sin(ang) * sp, (zt - hand.z) / maxf(1.0, dist / 6.0))
	ball.launch(hand, v, serve_team, server)
	_rally_events.clear()
	serve_bounced = not (kind == "bote" or kind == "abajo")
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
	if _finished:
		return
	if attract:
		_restart_attract()
		return
	if String(config.get("mode", "")) == "test":
		set_process(false)
		return
	_finished = true
	Game.on_match_finished(result())


func _restart_attract() -> void:
	count = Rules.Count.new(rules, "3_7")
	clock = 0.0
	sudden = false
	half = 1
	_half_at = -1
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


## Bare feet on the court: heard for your player and whoever is going for the ball, quieter the further from the
## camera. Earth or stone by the court.
func _footsteps() -> void:
	var near := []
	if user_player:
		near.append(user_player)
	for t in teams:
		var tk: Player = (t.ai as TeamAI).taker
		if tk and not tk in near:
			near.append(tk)
	var cam_at: Vector3 = cam.camera.global_position if cam and cam.camera else Vector3.ZERO
	var kind := "step_stone" if court.classic() else "step_earth"
	for p in all_players():
		var pl: Player = p
		if pl.stepped and pl in near and not attract:
			var d := pl.global_position.distance_to(cam_at)
			var speed := Vector2(pl.vel.x, pl.vel.z).length()
			Sfx.play_var(kind, -16.0 - clampf((d - 8.0) * 0.6, 0.0, 14.0) + clampf(speed - 3.0, 0.0, 3.0), randf_range(0.9, 1.1))   # wsg-rng-ok: a sound's pitch
		pl.stepped = false


func _exit_tree() -> void:
	FoundationLink.in_match = false
	FoundationLink.frozen = false
	if not attract:
		Sfx.pause(false)
		Sfx.ambience("")


# ---------------------------------------------------------------- the replay

## The ball through the ring is the rarest thing in the game: it is shown again, slowed, from below the ring. The
## last seconds of play are kept (where each player and the ball were, and each body's pose) and played back on the
## bodies and the ball alone: the players' own positions are not touched.
## On Medium and High (the shared foundation draws the bodies) a few big moments are shown again too, the bodies the
## foundation's as they were drawn (WsgReplay, on the game's own clock); a tap passes any replay, the corner tag only.
const REPLAY_KEEP := 5.0       # seconds of play kept
const REPLAY_AFTER := 1.4      # seconds of the call before the replay
const REPLAY_SPEED := 0.4
## The ring is always replayed. Beyond it, at most OTHER_REPLAYS a match, only for big moments, most wanted first: the
## raya that wins the match; a raya that wipes a count out in urria; a raya won off a dive save (the dive the rally's
## last strike, by the side that won it) or after a rally of LONG_RALLY strikes. Never a plain dead ball, out or fault;
## at least REPLAY_GAP seconds of play between them; never in the last raya before the result (time up), unless it is
## the one that wins the match.
const REPLAY_PRIORITY := ["ring", "win", "urria", "dive", "rally"]
const OTHER_REPLAYS := 3
const LONG_RALLY := 8
const REPLAY_GAP := 90.0
const MOMENT_BEFORE := 1.8     # seconds shown before a moment, and after it
const MOMENT_AFTER := 1.6

var _rec: Array = []           # [time, ball position, [[body position, yaw, pose], ...]]
var _rec_t := 0.0
var _replayed := false
var _rp_t := 0.0
var _rp_cam: Camera3D
var _rp_keep: Array = []
var _rp_span := []             # [first, last] time of play the replay shows
var _rp_focus := Vector3.ZERO  # where the moment happened (not the ring's camera)
var _replay_kind := ""         # what the coming replay shows, or "" (REPLAY_PRIORITY)
var _moment := []              # [time, place] of the moment it shows
var _rally_events: Array = []  # this rally's [kind ("strike", "dive"), time, place, team]
var replays: Array = []        # [raya number, kind, clock] of each replay shown (tests)
var _others_shown := 0         # replays this match other than the ring's
var _last_replay_clock := -INF
var wsg_replay: WsgReplay      # the foundation's bodies as drawn, kept for the replays (Medium and High)


func _record(delta: float) -> void:
	if attract or not (court.classic() or wsg_replay) or not (phase in [P.LIVE, P.CALL]):
		return
	_rec_t += delta
	var bodies := []
	for p in all_players():
		var pl: Player = p
		bodies.append([pl.global_position, pl.yaw, pl.body.pose if pl.body else {}])
	_rec.append([_rec_t, ball.pos, bodies])
	while _rec.size() > 2 and _rec_t - float(_rec[0][0]) > REPLAY_KEEP:
		_rec.pop_front()
	if wsg_replay:
		wsg_replay.record(_rec_t)


func replaying() -> bool:
	return phase == P.REPLAY


## The replay a raya earns (reason, the count's what), or "": the ring at every level; the rest on Medium and High.
func replay_kind(reason: String, what: String, team := -1, fault := false) -> String:
	if reason == "ring":
		return "ring"
	if wsg_replay == null:
		return ""
	var won := what == "win" or count.winner >= 0
	if _others_shown >= OTHER_REPLAYS or (_others_shown > 0 and clock - _last_replay_clock < REPLAY_GAP):
		return ""
	# The last raya (time up, the next call ends it): only the one that wins the match.
	if not won and limit_s > 0.0 and clock >= limit_s:
		return ""
	var found := {}
	for e in _rally_events:
		if _rec_t - float(e[1]) > REPLAY_KEEP - MOMENT_BEFORE:
			continue
		match String(e[0]):
			"dive":
				found.erase("dive")
				if int(e[3]) == team:
					found["dive"] = e
			"strike":
				found.erase("dive")
	if fault:
		found.erase("dive")
	elif rally >= LONG_RALLY:
		found["rally"] = _last_strike_event()
	if won:
		found["win"] = _last_strike_event()
	if what == "urria":
		found["urria"] = _last_strike_event()
	for k in REPLAY_PRIORITY:
		if found.has(k) and not (found[k] as Array).is_empty():
			_moment = [float(found[k][1]), found[k][2]]
			return k
	return ""


func _last_strike_event() -> Array:
	for i in range(_rally_events.size() - 1, -1, -1):
		var e: Array = _rally_events[i]
		if String(e[0]) in ["strike", "dive"]:
			return e
	return [] if _rec.is_empty() else ["raya", maxf(float(_rec[0][0]), _rec_t - 1.0), ball.pos]


func _start_replay() -> void:
	_replayed = true
	if _rec.size() < 10:
		return
	var t0 := float(_rec[0][0])
	var t1 := float(_rec[-1][0])
	if _replay_kind != "ring" and not _moment.is_empty():
		t0 = maxf(t0, float(_moment[0]) - MOMENT_BEFORE)
		t1 = minf(t1, float(_moment[0]) + MOMENT_AFTER)
	if wsg_replay:
		# The foundation's bodies as they were drawn: the replay starts where its ring does.
		var sp := wsg_replay.span()
		if sp.is_empty() or float(sp[1]) - maxf(t0, float(sp[0])) < 0.5:
			return
		t0 = maxf(t0, float(sp[0]))
		wsg_replay.play(t0, t1)
		FoundationLink.frozen = true
	replays.append([log_rayas.size(), _replay_kind, clock])
	if _replay_kind != "ring":
		_others_shown += 1
		_last_replay_clock = clock
	_rp_span = [t0, t1]
	_rp_call_t = phase_t
	phase = P.REPLAY
	phase_t = 0.0
	_rp_t = 0.0
	_rp_keep = []
	for p in all_players():
		_rp_keep.append((p as Player).body.transform if (p as Player).body else Transform3D())
	_rp_cam = Camera3D.new()
	_rp_cam.fov = 48.0
	add_child(_rp_cam)
	if _replay_kind == "ring":
		# Below the ring, on the far side of the alley, looking up at it.
		var ring: Vector3 = court.rings()[0] if float(ball.pos.z) < 0.0 else court.rings()[1]
		var from: Vector3 = _rec[0][1]
		_rp_cam.global_position = Vector3(signf(from.x) * 4.5 if absf(from.x) > 0.5 else -4.5, 1.7, -ring.z * 0.35)
		_rp_cam.look_at(ring, Vector3.UP)
	else:
		# Low at the side the broadcast camera watches from, square on to the moment.
		_rp_focus = _moment[1] if _moment.size() > 1 and _moment[1] is Vector3 else ball.pos
		_rp_focus.y = 0.9
		var side := signf(cam.camera.global_position.z) if cam and cam.camera else 1.0
		var across := minf(6.5, court.half_w_at(_rp_focus.x) * 0.85) if court.classic() else 7.0
		_rp_cam.global_position = Vector3(_rp_focus.x, 1.5 if court.classic() else 1.6, _rp_focus.z * 0.3 + (side if side != 0.0 else 1.0) * across)
		_rp_cam.look_at(_rp_focus, Vector3.UP)
	_rp_cam.current = true
	if hud:
		hud.replay_tag(true)
		hud.touch.tap_skips = true


func _replay_step(delta: float) -> void:
	_rp_t += delta * REPLAY_SPEED
	var t := float(_rp_span[0]) + _rp_t
	var i := 0
	while i < _rec.size() - 2 and float(_rec[i + 1][0]) < t:
		i += 1
	var a: Array = _rec[i]
	var b: Array = _rec[i + 1]
	var w := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	var bp: Vector3 = (a[1] as Vector3).lerp(b[1], w)
	ball.show_at(bp, delta * REPLAY_SPEED)
	var ps := all_players()
	for k in mini(ps.size(), (a[2] as Array).size()):
		var pl: Player = ps[k]
		if pl.body == null:
			continue
		var ra: Array = a[2][k]
		var rb: Array = b[2][k]
		var pos: Vector3 = (ra[0] as Vector3).lerp(rb[0], w)
		var yaw := lerp_angle(float(ra[1]), float(rb[1]), w)
		pl.body.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(pl.body.scale), pos)
		pl.body.apply(rb[2] if w > 0.5 else ra[2])
	if wsg_replay and wsg_replay.playing:
		wsg_replay.seek(t)
	if _rp_cam:
		var look_at := bp.lerp(court.rings()[0] if bp.z < 0.0 else court.rings()[1], 0.3) if _replay_kind == "ring" \
			else _rp_focus.lerp(Vector3(bp.x, minf(bp.y, 2.6), bp.z), 0.6)
		var to := _rp_cam.global_transform.looking_at(look_at, Vector3.UP)
		_rp_cam.global_transform = _rp_cam.global_transform.interpolate_with(to, minf(1.0, delta * 4.0))
	if t >= float(_rp_span[1]) or t >= float(_rec[-1][0]) or _skip_replay:
		_end_replay()


var _skip_replay := false
var _rp_call_t := 0.0          # how far into the call the replay came


func _end_replay() -> void:
	_skip_replay = false
	if wsg_replay and wsg_replay.playing:
		wsg_replay.stop()
	FoundationLink.frozen = false
	var ps := all_players()
	for k in mini(ps.size(), _rp_keep.size()):
		var pl: Player = ps[k]
		if pl.body:
			pl.body.transform = _rp_keep[k]
	if _rp_cam:
		_rp_cam.queue_free()
		_rp_cam = null
	if hud:
		hud.replay_tag(false)
		hud.touch.tap_skips = false
	cam.camera.current = true
	ball.show_at(ball.pos, 0.0)
	phase = P.CALL
	# The ring's replay ends the match (as it always has); after any other the call goes on where it stopped, so the
	# players walk back to their places as they would have: the match plays exactly as without the replay.
	phase_t = CALL_T if _replay_kind == "ring" else _rp_call_t


# ---------------------------------------------------------------- you

## One player all match (the setting): yours is the team's first, the server; the others are the computer's.
func one_player() -> bool:
	return int(Game.settings.get("control", 0)) == 1 and not attract


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
	if hud == null:
		return
	if user_team < 0:
		# Watching the computer play: the copal can be passed too (the owner, 0.6.8).
		hud.set_buttons(["SKIP"] if in_ritual() else [])
		return
	var ai: TeamAI = teams[user_team].ai
	if phase == P.LIVE and ai.taker != null and ai.taker != user_player and not user_player.busy() and not one_player():
		_set_user(ai.taker)
	var j: Vector2 = hud.joystick()
	# Not in the walk-out either (players cross the analco to their places then; a man run into the far half by the
	# stick was snapped 1 m back at the serve: the sim, seed 18).
	if j.length() > 0.15 and phase != P.SERVE and phase != P.INTRO and not in_ritual():
		var w := screen_to_world(j)
		# Just after the camera changes (another view, a cut), the way he runs turns over about 0.2 s, not at once.
		var since: float = cam.since_change()
		if user_player.steer_by_dir and since < 0.25:
			w = user_player.want_dir.slerp(w, clampf(get_process_delta_time() / 0.07, 0.0, 1.0)).limit_length(1.0)
		user_player.steer_by_dir = true
		user_player.want_dir = w
	else:
		user_player.steer_by_dir = false
	var ids: Array = []
	if in_ritual():
		ids = ["SKIP"]
	elif phase == P.LIVE:
		ids = ["HIP", "DIVE"]
	elif phase == P.SERVE and serve_team == user_team and not _serve_launched:
		ids = ["SERVE"]
	hud.set_buttons(ids)


## The joystick's direction on the screen as a direction on the court, from the camera, at the place it moves (your
## player): up on the stick is up the screen there, right is right, whatever the camera (court-side, high, end) and
## wherever he is in the picture. Worked through the screen itself: the point a little way along the stick from him on
## the screen, back down onto the ground he stands on. (The camera's flat forward alone is up the screen only at its
## middle: on a wide view, or from behind an end, it was tens of degrees off, or reversed.)
func screen_to_world(j: Vector2, at := Vector3.INF) -> Vector3:
	if j.length() < 0.001:
		return Vector3.ZERO
	if at == Vector3.INF:
		at = user_player.global_position if user_player else cam.focus_point()
	return stick_to_world(j, cam.camera, at)


## The stick (x right, y down) as a direction on the court seen through camera C at the body's place AT: the way the
## stick points on the screen there (screen_to_world; the shared world check's joystick rule reads this too).
static func stick_to_world(j: Vector2, c: Camera3D, at: Vector3) -> Vector3:
	if j.length() < 0.001:
		return Vector3.ZERO
	var b := c.global_transform.basis
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var flat := (right * j.x - fwd * j.y).limit_length(1.0)
	if not c.is_inside_tree() or c.is_position_behind(at):
		return flat
	var s0 := c.unproject_position(at)
	# Off the screen (under the end camera, say), the screen has no up there: the camera's own forward.
	if not c.get_viewport().get_visible_rect().grow(200.0).has_point(s0):
		return flat
	var s1 := s0 + j.normalized() * 40.0
	var dir := c.project_ray_normal(s1)
	if dir.y > -0.01:
		return flat
	var o := c.project_ray_origin(s1)
	var hit := o + dir * ((at.y - o.y) / dir.y)
	var w := Vector3(hit.x - at.x, 0.0, hit.z - at.z)
	if w.length() < 0.0001:
		return flat
	return w.normalized() * minf(1.0, j.length())


func _on_action(id: String) -> void:
	if id == "SKIP" and in_ritual():
		ritual.finish()
		return
	if phase == P.REPLAY:
		_skip_replay = true
		return
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
				user_player.start_strike(side, aim, ring_shot(user_player, _user_stick()))
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
func _user_stick() -> Vector3:
	var j: Vector2 = hud.joystick() if hud else Vector2.ZERO
	return screen_to_world(j) if j.length() >= 0.3 else Vector3.ZERO


## The ring shot (classic court): striking within reach of the middle with the stick held toward a wall aims the ball
## at that wall's ring. Returns the ring's side, or 0 when this is no ring shot.
func ring_shot(p: Player, stick: Vector3) -> int:
	if not court.classic() or court.rings().is_empty() or absf(stick.z) < 0.7:
		return 0
	var ax := absf(p.global_position.x)
	if ax < RING_SHOT_X.x or ax > RING_SHOT_X.y:
		return 0
	var side := int(signf(stick.z))
	# The hole runs along the alley: from too far across, the ball cannot line up with it.
	var rz := side * (Court.TALUD_Z - Court.RING_OFF)
	if absf(rz - p.global_position.z) > ax * RING_SHOT_SLANT:
		return 0
	return side


## Now and then a computer player goes for the ring when he is placed for it (more often at a harder level).
## The computer goes for the ring now and then on a strike within reach of it (halved in 0.6.3, when it began meeting
## the ball with the hip several times as often: the ring stays the rare thing it is).
func ai_ring_shot(p: Player) -> int:
	if not court.classic() or court.rings().is_empty() or rng.randf() > [0.02, 0.04, 0.07][clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, 2)]:
		return 0
	return ring_shot(p, Vector3(0, 0, signf(p.global_position.z) if absf(p.global_position.z) > 0.1 else 1.0))


var serve_bounced := true    # the bounced serve has come down (its receivers wait for it to: TeamAI)
const BOTE_LAND := Vector2(1.4, 3.2)     # how far past the analco the bounced serve first comes down (m)
const BOTE_ANGLE := Vector2(50.0, 58.0)  # thrown well up and over (the owner, 0.6.8: higher), down hard enough to rise to the hip
const SERVE_HIGH_ANGLE := 52.0   # arriba, the full serve: tossed high (the owner, 0.6.8; was 40)
const ABAJO_LAND := Vector2(1.5, 4.0)     # the earth's low serve: how far past the analco it first comes down (m)
const ABAJO_ANGLE := Vector2(42.0, 50.0)  # its arc: tossed up underarm (the owner, 0.6.8: higher), to come up off the earth to the hips


const RING_SHOT_X := Vector2(4.0, 12.0)   # how far from the middle a ring shot can be struck from (m)
const RING_SHOT_SLANT := 0.4              # and how far across for each metre along
const RING_SPREAD := 1.0                  # scales the ring shot's error (tests)


## The ring shot's flight: through the ring's centre at the top of its arc (the hole is a short tube along the alley:
## a ball still climbing or falling steeply catches its stone), with the strike's error. A perfect strike goes in
## about one time in three; a good one one in ten; an ordinary one hardly ever.
func _ring_launch(p: Player, from: Vector3, quality: float) -> Vector3:
	var c: Vector3 = court.rings()[0] if p.action_ring < 0 else court.rings()[1]
	var h := Vector2(c.x - from.x, c.z - from.z)
	var hn := h.normalized()
	var sol := _ring_solve(from, c, hn)
	var ang: float = sol[0]
	var sp: float = sol[1]
	var err := (1.0 - quality) * (1.0 - p.skill * 0.5)
	ang += deg_to_rad(rng.randf_range(-1.0, 1.0) * (1.6 + 10.0 * err) * RING_SPREAD)
	hn = hn.rotated(rng.randf_range(-1.0, 1.0) * (0.018 + 0.2 * err) * RING_SPREAD)
	sp *= 1.0 + rng.randf_range(-1.0, 1.0) * (0.016 + 0.08 * err) * RING_SPREAD
	return Vector3(hn.x * cos(ang) * sp, sin(ang) * sp, hn.y * cos(ang) * sp)


class _Probe:
	var pos: Vector3
	var vel: Vector3
	var grounded := false


## The angle and speed that carry the ball (air drag and all) through the ring's centre at the top of its arc.
func _ring_solve(from: Vector3, c: Vector3, hn: Vector2) -> Array:
	var lo := deg_to_rad(20.0)
	var hi := deg_to_rad(75.0)
	var sp := 10.0
	for it in 12:
		var ang := (lo + hi) * 0.5
		var r := _ring_speed(from, c, hn, ang)
		sp = r[0]
		# Already falling at the ring: too steep (the top of the arc came before it).
		if r[1] < 0.0:
			hi = ang
		else:
			lo = ang
	var ang2 := (lo + hi) * 0.5
	return [ang2, _ring_speed(from, c, hn, ang2)[0]]


## The launch speed that carries the ball through the ring's height at that angle, and its climb there.
func _ring_speed(from: Vector3, c: Vector3, hn: Vector2, ang: float) -> Array:
	var lo := 4.0
	var hi := 30.0
	var probe := _Probe.new()
	var ev := []
	var vy := 0.0
	for it in 14:
		var sp := (lo + hi) * 0.5
		probe.pos = from
		probe.vel = Vector3(hn.x * cos(ang) * sp, sin(ang) * sp, hn.y * cos(ang) * sp)
		probe.grounded = false
		ev.clear()
		var y_at := -1.0
		for k in 400:
			var a := probe.pos
			# The flight alone (no court): what the ball would do in the open air.
			probe.vel += (Vector3(0, -Ball.GRAVITY, 0) - probe.vel * probe.vel.length() * Ball.DRAG) * STEP
			probe.pos += probe.vel * STEP
			if (a.x - c.x) * (probe.pos.x - c.x) <= 0.0:
				y_at = lerpf(a.y, probe.pos.y, (c.x - a.x) / (probe.pos.x - a.x)) if not is_equal_approx(a.x, probe.pos.x) else probe.pos.y
				vy = probe.vel.y
				break
			if probe.pos.y < 0.0:
				break
		if y_at < c.y:
			lo = sp
		else:
			hi = sp
	return [(lo + hi) * 0.5, vy]


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
	if turn_team >= 0 and ball.pos.x * Rules.dir(turn_team) > 0.0:
		turn_crossed = true
	if phase != P.LIVE:
		# After the call the ball runs on as it will; nothing it does counts.
		for e in events:
			if e.kind == "bounce" and float(e.speed) > 2.0:
				Sfx.play("thud_stone" if court.classic() else "thud", -14.0, 1.0)
			elif e.kind == "knock":
				_knock(e)
		return
	for e in events:
		match String(e.kind):
			"knock":
				_knock(e)
			"bounce":
				serve_bounced = true
				var sp := float(e.speed)
				if sp > 1.0:
					var vol := clampf(-20.0 + sp * 1.6, -20.0, -2.0)
					if String(e.surface) == "earth":
						Sfx.play_var("thud_earth", vol - 2.0, rng.randf_range(0.8, 0.95))
					else:
						Sfx.play("thud_stone", vol, rng.randf_range(0.92, 1.05))
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
var _told_low := false
const DIVE_ERR := 0.55          # the least error a dive's return has (a hip strike's runs 0 to 1 with its timing)
var ring_shots := 0


## The ball knocking into a prop round the court (a bench, a stand, the coping, a post): its knock, by what it is.
func _knock(e: Dictionary) -> void:
	var sp := float(e.speed)
	if sp < 1.0:
		return
	var vol := clampf(-20.0 + sp * 1.6, -20.0, -4.0)
	match String(e.surface):
		"fabric", "earth":
			Sfx.play_var("thud_earth", vol - 4.0, rng.randf_range(0.85, 1.0))
		"wood", "metal":
			Sfx.play("thud", vol, rng.randf_range(1.05, 1.2))
		_:
			Sfx.play("thud_stone", vol, rng.randf_range(0.92, 1.05))


func _contacts() -> void:
	for p in all_players():
		var pl: Player = p
		var w := pl.hit_window()
		if w < 0.0:
			continue
		if pl.action == Player.A.STRIKE and ball.pos.y < Player.STRIKE_MIN_Y:
			# A rolling or skimming ball goes under a standing hip: only the dive gets down to it.
			if pl.user and hud and not _told_low and ball.pos.distance_to(pl.hip_point()) < 1.2:
				_told_low = true
				hud.banner(tr("TOO_LOW_DIVE"), Game.C_GOLD)
			continue
		if not serve_bounced and pl.team != serve_team and not pl.user:
			# The computer plays the bounced serve off the bounce: its hip, swung for the ball coming up, lets the ball
			# dropping steeply onto the same spot (the high toss, 0.6.8) go by until it has come down.
			continue
		var hip := pl.hip_point()
		if pl.action == Player.A.STRIKE and ball.pos.y > hip.y + Player.STRIKE_MAX_UP:
			# Still above his waist: the hip meets the ball at the hip, not with the belly or chest; it must come down.
			continue
		var reach := Player.REACH + (0.12 if pl.user and int(Game.settings.assist) > 0 else 0.0)
		var d := ball.pos.distance_to(hip)
		if d <= reach:
			_strike(pl, w, d / reach)
			return
	for p in all_players():
		var pl: Player = p
		# A player who is striking, diving, or has just played it is not faulted for the ball near him.
		if pl.immune > 0.0 or pl.action in [Player.A.STRIKE, Player.A.DIVE] or pl.recent_attempt > 0.0:
			continue
		var feet := pl.global_position
		var a := feet + Vector3(0, 0.25, 0)
		var b := feet + Vector3(0, 1.4, 0)
		var q := Geometry3D.get_closest_point_to_segment(ball.pos, a, b)
		if q.distance_to(ball.pos) < Player.BODY_R + Ball.RADIUS:
			# Only a ball coming at him with real pace, moving toward him, counts (a slow ball grazing him does not).
			var rel := ball.vel - pl.vel
			var toward := rel.dot((pl.global_position - ball.pos).normalized())
			if rel.length() > 2.5 and toward > 1.0:
				pl.stats.faults += 1
				tstats[pl.team].faults_touch += 1
				_award(Rules.body_touch(pl.team), "touch", true, pl)
				return


var top_strike := -INF   # the highest over his hip a standing hip has met the ball this match (m; the tests read it)


func _strike(p: Player, window: float, off: float) -> void:
	if not may_strike(p.team):
		# M4: a second strike by the same side before the ball has crossed: the point to the other side.
		p.stats.faults += 1
		tstats[p.team].faults_touch += 1
		_award(Rules.second_strike(p.team), "twice", true, p)
		return
	turn_team = p.team
	turn_crossed = false
	if p.action == Player.A.STRIKE:
		top_strike = maxf(top_strike, ball.pos.y - p.hip_point().y)
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
	if p.action == Player.A.DIVE:
		# Down on the ground, the hip under a low ball: a scramble to keep it alive, never a clean shot.
		err = maxf(err, DIVE_ERR) + 0.25 * err
	var ang := deg_to_rad(aim.y + rng.randf_range(-9.0, 9.0) * err)
	var turn := rng.randf_range(-0.3, 0.3) * err
	var hn := h.normalized().rotated(turn)
	var lift := maxf(0.0, from.y - Ball.RADIUS)
	var denom := 2.0 * cos(ang) * cos(ang) * (dist * tan(ang) + lift)
	var need := sqrt(Ball.GRAVITY * dist * dist / maxf(denom, 0.01))
	var cap := (8.5 + 7.5 * p.power) * (0.5 + 0.5 * quality)
	if p.action == Player.A.DIVE:
		# A dive is a scramble. On the stone court, where the lively ball would otherwise be dived back and forth for
		# minutes, well timed it carries and badly timed it barely moves the ball, which may die short.
		cap *= 0.62 * (clampf((quality - 0.1) / 0.6, 0.45, 1.0) if court.classic() else 1.0)
		# Up off the floor: a dive scoops the ball up to come down and bounce for a standing hip.
		ang = maxf(ang, deg_to_rad(26.0 if court.classic() else 40.0))
	var sp := minf(need, cap)
	var v := Vector3(hn.x * cos(ang) * sp, sin(ang) * sp, hn.y * cos(ang) * sp)
	if p.action_ring != 0 and p.action == Player.A.STRIKE:
		v = _ring_launch(p, from, quality)
		ring_shots += 1
	ball.launch(from + Vector3(hn.x, 0.0, hn.y) * 0.05, v, p.team, p)
	if wsg_replay:
		_rally_events.append(["dive" if p.action == Player.A.DIVE else "strike", _rec_t, p.global_position, p.team])
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
		Sfx.play_var("hip_body", -8.0 + quality * 4.0, rng.randf_range(0.85, 0.95))
		if rng.randf() < 0.5:
			Sfx.voice("grunt" if p.action == Player.A.DIVE else "hup", -14.0, 0.92 + float(p.num % 4) * 0.04)
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
		res = Rules.award(count, team, Rules.points_for(count, reason))
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
		"touch", "twice":
			tstats[team].won_touch += 1
		"ring":
			tstats[team].ring += 1
	if who is Player and (who as Player).team == team and reason in ["dead", "end", "ring"]:
		(who as Player).stats.rayas += 1
	log_rayas.append([team, reason, count.holder, count.rayas, snappedf(clock, 0.1), String(res.get("what", ""))])
	last_call = {"team": team, "reason": reason, "fault": fault, "what": res.get("what", "")}
	# One replay a raya at most: the best moment it had.
	_replayed = false
	_moment = []
	_replay_kind = replay_kind(reason, String(res.get("what", "")), team, fault)
	phase = P.CALL
	phase_t = 0.0
	officials.signal_raya(team, fault)
	for p in all_players():
		(p as Player).react((p as Player).team == team)
	var big := reason == "ring" or String(res.get("what", "")) in ["urria", "win"]
	if not attract:
		Sfx.play("call", -4.0)
		Sfx.react("cheer" if big else "applause", -4.0 if big else -10.0)
		Crowd.cheer(1.0 if big else 0.55, 1.4 if big else 0.8)
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

## Auto graphics (Settings), the game's own: if the first seconds of play run under about 36 frames a second, a level
## lower (and the player is told). Then, all match long, the shared foundation's WsgAutoTier: two 1.5 s windows in a
## row slower than 36 a second or hitching take another level off (not on the battery saver's 30, which is not slow;
## not headless). Either way the step applies at once, the foundation's bodies with it (lower_graphics).
func _check_frame_rate(delta: float, real_delta: float) -> void:
	if attract or not bool(Game.settings.get("auto_gfx", true)) or phase == P.INTRO or WsgAutoTier.off:
		return
	if not _gfx_checked:
		_fps_t += delta
		_fps_frames += 1
		if _fps_t >= 6.0:
			_gfx_checked = true
			var fps := _fps_frames / _fps_t
			# (Battery saver holds it near 30 on purpose: nothing to lower then.)
			if fps < 36.0 and int(Game.settings.graphics) > Game.GFX_LOW and int(Game.settings.fps) != Game.FPS_SAVER:
				lower_graphics()
		return
	if phase == P.REPLAY or int(Game.settings.fps) == Game.FPS_SAVER:
		return
	if int(Game.settings.graphics) <= Game.GFX_LOW:
		# Low: nothing lower to step to but the motion capture on the game's own bodies (Player.toon): a phone too slow
		# for it runs on without it, the game's own run, as the beta did.
		if WsgToonDriver.off or not WsgToonDriver.available() or FoundationLink.off:
			return
		if (DisplayServer.get_name() == "headless" and not auto_headless) or OS.has_feature("movie"):
			return
		if _auto_gfx == null:
			_auto_gfx = WsgAutoTier.new(Game.frame_cap())
		if _auto_gfx.feed(real_delta):
			WsgToonDriver.off = true
			_auto_gfx.reset()
		return
	if (DisplayServer.get_name() == "headless" and not auto_headless) or OS.has_feature("movie"):
		return
	if _auto_gfx == null:
		_auto_gfx = WsgAutoTier.new(Game.frame_cap())
	if _auto_gfx.feed(real_delta):
		lower_graphics()


var _fps_t := 0.0
var _fps_frames := 0
var _gfx_checked := false
var auto_headless := false     # (tests: WsgAutoTier heard headless too, fed slow frames by hand)
## (Made when first needed: Low makes no object the beta did not - a body's model is picked by its instance id.)
var _auto_gfx: WsgAutoTier = null


## A level off the graphics now, and everything the levels change: the picture, and the shared foundation's bodies (on
## Low the game's own again, exactly as Low draws them, and no foundation replays) and their shadows.
func lower_graphics() -> void:
	var g := maxi(Game.GFX_LOW, int(Game.settings.graphics) - 1)
	Game.settings.graphics = g
	Game.save_settings()
	Game.apply_graphics(get_viewport())
	WsgFoundation.tier = g
	if hud:
		hud.note(tr("GFX_LOWERED"))
	var low := g == Game.GFX_LOW
	if low and phase == P.REPLAY:
		_end_replay()
	for b in _all_bodies():
		var body: Body = b
		if body.link == null:
			continue
		if low:
			body.unlink()
		else:
			var sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.link.body.mesh_instance.cast_shadow = sh
			if body.link.gear:
				body.link.gear.cast_shadow = sh
	if low and wsg_replay:
		ball.draw_at(Vector3.INF)
		wsg_replay.queue_free()
		wsg_replay = null
		_replay_kind = "ring" if _replay_kind == "ring" else ""
	if _auto_gfx:
		_auto_gfx.reset()


# ---------------------------------------------------------------- the shared foundation's bodies (FoundationLink)

## Every body the foundation may draw: the players and the judges.
func _all_bodies() -> Array:
	var out: Array = []
	for p in all_players():
		if (p as Player).body:
			out.append((p as Player).body)
	for j in officials.judges:
		out.append(j)
	return out


## Metres from the camera within which a player is posed every frame by graphics level; to POSE_MID every second
## frame, beyond it every third (unless he is in a move, holds the ball or is yours: every frame).
const POSE_NEAR := [10.0, 10.0, 14.0]
const POSE_MID := 22.0
var _detail_t := 0.0


## Twice a second: the foundation's bodies in full detail nearest the camera only (WsgFoundation's budget profile: its
## nearest 6 on Medium, all on High); far players posed every second or third frame, the judges every third unless
## calling.
func _rank_detail(dt: float) -> void:
	_detail_t -= dt
	if _detail_t > 0.0:
		return
	_detail_t = 0.5
	WsgFoundation.tier = int(Game.settings.graphics)
	var cam3 := get_viewport().get_camera_3d()
	var camp := cam3.global_position if cam3 else Vector3.ZERO
	# Measured from the play, not the lens: the court-side camera stands back as far as frames the play (further on
	# a wide shot), and its players are posed as often as when it stood 10 m from it (0.6.0), so a runner's planted
	# feet do not slide for being drawn every third frame.
	var back := 0.0
	if cam and cam.camera == cam3 and cam.mode == Game.CAM_TV:
		back = maxf(0.0, camp.distance_to(cam.focus_point()) - 10.0)
	var list := []
	for b in _all_bodies():
		var link: FoundationLink = (b as Body).link
		if link == null or link.body == null:
			continue
		list.append(link.body)
		if link.kind == "judge":
			link.pose_every = 1 if link.mode == "upper" else 3
		else:
			var pl := (b as Body).get_parent() as Player
			var d: float = maxf(0.0, (b as Body).global_position.distance_to(camp) - back)
			var near := d < float(POSE_NEAR[clampi(int(Game.settings.graphics), 0, 2)])
			link.pose_every = 1 if near or pl == null or pl.busy() or pl == server or pl.user else (2 if d < POSE_MID else 3)
	if not list.is_empty():
		WsgFoundation.rank_detail(list, camp)


## The ball the server holds, drawn in his drawn right hand (the game's hand, which the serve throws from, is where
## the game has it: a few centimetres off the drawn one).
func _ball_in_drawn_hand() -> void:
	var holder: FoundationLink = null
	# (Not while the arms are raised to the copal's smoke: the ball is not lifted to the sky with them; it stays where
	# the game draws it, as in the beta.)
	if ball.held and server != null and server.body and server.body.link and server.body.link.body.visible \
			and server.offering <= 0.01:
		holder = server.body.link
	for p in all_players():
		var l: FoundationLink = (p as Player).body.link if (p as Player).body else null
		if l:
			l.hand_ball = ball if l == holder else null
	if holder == null:
		ball.draw_at(Vector3.INF)
