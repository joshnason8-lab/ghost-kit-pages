extends Node3D
## A match, to the ISTAF laws as they stand (docs/TAKRAW.md): rally point, sets to 15 (from 14-all, win by two, up
## to 17) or the old 21 (to 25), best of three or one set; the serve alternating every point; ends changed after each
## set and at 8 in the third; three touches a side; one video challenge a side a set.
##
## Every touch is planned. The ball flies under gravity alone (Ball), so the moment a ball is kicked the side it is
## going to knows where it can be met: who gets there, with which part of the body (a sila kick, the thigh, the chest,
## the head, a diving instep), and when; that player runs to the spot and starts his move so his foot meets the ball.
## The touch's quality, from the player's ratings, decides how good the pass, set or spike is. Blocks and digs are
## planned the same way against a spike.
##
## Your side is yours: nothing is played for you. The player who can get to the ball is lit; you run him there with the
## joystick (the gold mark on the floor is where to stand; with the assist on, the setter and the striker run to the
## set themselves), and he kicks only when you press, as the ring closes on the ball. Too early, too late, too far
## from it, or no press at all, and he misses it: the ball goes on, and falls unless someone else can still reach it.

signal finished(result: Dictionary)

enum S {INTRO, SETUP, TOSS, RALLY, DEAD, BREAK, REVIEW, REPLAY, OVER}

const SETUP_TIME := 2.2       # s for the players to take their places and the referee to call the score
const DEAD_TIME := 2.6        # s between the ball landing and the next serve
const BREAK_TIME := 5.0       # the interval between sets (two minutes, played quickly)

var config := {}
var paused := false

var arena: Arena
var ball: Ball
var cam: CameraRig
var hud: MatchHud
var controls: TouchControls
var rng := RandomNumberGenerator.new()

# The teams: [team 0, team 1], each {id, players: Array[Player], short, c1, c2}.
var teams: Array = []
var side_team := [0, 1]      # which team is on side 0 and side 1 (they change ends)
var user_team := 0           # -1: nobody's (a demo, or an AI match in a season)
var women := false
var n_players := 3
var event := "regu"

# The score.
var set_points := 15
var set_cap := 17
var sets_to_win := 2
var sets := [0, 0]
var points := [0, 0]
var set_no := 1
var set_scores: Array = []   # [[a, b], ...] for the sets played
var server := 0              # the team serving next
var first_server := 0        # the team that served first in this set
var ends_changed_mid := false
var challenges := [1, 1]
var serving_streak := 0      # the serving team's run of points (for the call-outs)
var last_point_team := -1
var run := [0, 0]            # each team's run of points in a row

# The rally.
var state := S.INTRO
var state_t := 0.0
var now := 0.0               # match time (the sim's own clock: slow motion slows it)
var time_scale := 1.0
var pace := 1.0              # a match you play runs slower than real time (Settings: Game speed)
var difficulty := 1          # 0 Rookie .. 3 Legend: the opponents' sharpness, your timing windows and reach
var touches := 0             # touches by the side the ball is on
var touch_side := -1         # the side that last touched the ball
var last_toucher: Player = null
var plan := {}               # the next touch: {player, kind, move, t, pos, touch, mirror, user, ...}
var block := {}              # a block being made: {player, t, z, q, user}
var net_t := -1.0            # when the ball crosses the net's plane next (-1: it does not)
var land_t := -1.0           # when it lands
var next_net_hit := false    # it meets the net there
var deflect := {}            # a block's deflection at the net: {v}
var rally_len := 0           # touches in the rally
var rally_ends := ""         # why the last rally ended (for the commentary)
var _attack_kind := ""       # the attack that was played (for call-outs)
var _set_for := {}           # what the setter set up: {player, move, t, pos}
var _pending_call := {}      # a line call that can be challenged: {winner, landed, margin, true_in, side, until}
var _intro_done := false
var _review := {}
var _slowmo_until := -1.0

# Your inputs.
var input_window := {}       # the touch you can time now: {t, kind, choices}
var _press := {}             # what you pressed and when: {id, t}
var _joy := Vector2.ZERO

# Stats: player id -> {kills, aces, blocks, digs, errors, serves}
var stats := {}
var log: Array = []     # each rally: [touches, how it ended, the team that won it]
var _why := ""
var _last_kind := ""
var _block_kill := false
var _came := ""              # what came over to the touch being made (the serve or attack it answers)
var _last_touch := ""        # the kind of the last touch made (a free ball comes over off a pass or a set)
var _free_ball := false      # the ball coming over is a free one: a pass or a set over the net, to be punished
var _set_cp := Vector3.ZERO  # where the set is to be spiked (the cover goes behind it)
var _marks := {}             # "side:set" -> the receiver that side's servers aim at this set
var _seq := ""               # the rally's touches, for the log: "serve receive set attack|dig ..." (| the net crossed)
var _spilled_by: Player = null   # who spilled the reception just made (he can't recover it himself)
var _server_q := 0.0         # the power serve in flight: how well it was struck (0-1) and its server's serve rating
var _server_r := 60.0
# Between points the ball is in someone's hands, or on its way to them: never left hanging (_between_points).
var _carrier: Player = null   # who has it (it goes where his hands are)
var _fetcher: Player = null   # going to pick it up where it lies
var _pick_t := -1.0           # when his hand reaches it
var _passer: Player = null    # has it, and throws it to the thrower
var _pass_t := -1.0           # when it leaves his hands
var _catcher: Player = null   # the thrower, the ball on its way to him
var _catch_t := -1.0
var _ball_keep := []          # the ball as it was when a replay began (put back after it)

# The replay: frames of the last few seconds.
var _rec: Array = []
var _replay_i := 0.0
var _replay_frames: Array = []

var officials: Array[RealBody] = []
var _ref: RealBody
var _judges: Array[RealBody] = []
var _officials := Officials.new()   # their life between the calls
var _bench := Officials.new()       # the substitutes on the benches: as alive, watching the ball
var _subs := [[], []]               # each team's substitutes (RealBody)


func _ready() -> void:
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	women = bool(config.get("women", false))
	event = String(config.get("event", "regu"))
	n_players = {"regu": 3, "quadrant": 4, "doubles": 2, "team": 3}.get(event, 3)
	user_team = int(config.get("user_team", 0))
	difficulty = clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, 3)
	if user_team >= 0 and not bool(config.get("attract", false)):
		pace = float(config.get("pace", Game.SPEEDS[clampi(int(Game.settings.get("game_speed", 0)), 0, Game.SPEEDS.size() - 1)]))
	sets_to_win = 2 if int(config.get("sets", 3)) >= 3 else 1
	set_points = int(config.get("points", 15))
	set_cap = 17 if set_points == 15 else 25
	var venue := String(config.get("venue", "national"))
	var home_t := DB.team(String(config.home))
	arena = Arena.new(venue, women, [home_t.get("c1", Game.C_SAFFRON), home_t.get("c2", Color.WHITE)])
	add_child(arena)
	if arena.crowd:
		arena.crowd.show_teams(String(config.home), String(config.away))   # the two teams' flags in the crowd
	ball = Ball.new()
	ball.bounds = arena.bounds
	ball.soft = arena.sand()
	# Every bounce off the floor or a wall heard, as loud as it was hard (the rally's landing too).
	ball.bounced.connect(func(at: Vector3, speed: float): Sfx.bounce(at, lerpf(-16.0, -2.0, clampf((speed - 1.2) / 6.0, 0.0, 1.0))))
	add_child(ball)
	ball.hold(Vector3(0, -5, 0))
	# Your team on the left of the broadcast picture (side 1, x > 0: the camera looks across from the far side).
	if user_team == 0:
		side_team = [1, 0]
	_make_teams()
	_make_officials()
	_make_bench()
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	Game.apply_graphics(get_viewport())
	hud = MatchHud.new()
	add_child(hud)
	hud.setup(self)
	controls = TouchControls.new()
	hud.add_child(controls)
	controls.action.connect(_on_action)
	controls.visible = user_team >= 0
	if bool(config.get("attract", false)):
		# Behind the home screen: no scoreboard or buttons, the crowd quiet, no replays.
		hud.visible = false
		controls.visible = false
	first_server = int(config.get("first_server", rng.randi_range(0, 1)))
	server = first_server
	state = S.INTRO
	state_t = 0.0
	if not bool(config.get("attract", false)):
		Sfx.crowd(arena.atmosphere() * 0.6)
		Sfx.drums(arena.atmosphere() * 0.3 if arena.indoor() else -1.0)
		var amb: Array = arena.ambience()
		Sfx.ambience(String(amb[0]), float(amb[1]))
		Sfx.surface("sand" if arena.sand() else "court")
		hud.intro(_intro_text())
	else:
		Sfx.crowd(0.15)
		Sfx.surface("")   # (behind the home screen: its music, the crowd low, no footsteps)


func _intro_text() -> String:
	var stage := String(config.get("stage", ""))
	var ev := tr({"regu": "EVENT_REGU", "quadrant": "EVENT_QUADRANT", "doubles": "EVENT_DOUBLES", "team": "EVENT_TEAM"}[event])
	if women:
		ev = tr("WOMENS_EVENT").format({"e": ev})
	return ("%s\u00a0· %s" % [stage, ev]) if stage != "" else ev


func _make_teams() -> void:
	teams = []
	for k in 2:
		var id := String(config.home if k == 0 else config.away)
		var t := DB.team(id)
		var lineup: Array = config.get("lineup_%d" % k, DB.regu(id, women, n_players))
		var c1: Color = t.get("c1", Color.WHITE)
		var c2: Color = t.get("c2", Color.BLACK)
		# The away side in its second colours when the two kits are alike.
		if k == 1:
			var h := DB.team(String(config.home))
			var hc: Color = h.get("c1", Color.WHITE)
			if Vector3(c1.r, c1.g, c1.b).distance_to(Vector3(hc.r, hc.g, hc.b)) < 0.35:
				var tmp := c1
				c1 = c2
				c2 = tmp
		var team := {"id": id, "short": String(t.get("short", id)), "c1": c1, "c2": c2, "players": []}
		var roles := _roles()
		for i in lineup.size():
			var pd: Dictionary = lineup[i]
			var look := {"skin": pd.get("skin", Color("c98a5a")), "jersey": c1, "shorts": c2.darkened(0.3) if c2.get_luminance() > 0.7 else c2,
				"height": float(pd.get("height", 1.76)), "women": women}
			var p := Player.new(pd, 0, roles[i] if i < roles.size() else DB.POS_STRIKER, look)
			p.slot = i
			add_child(p)
			team.players.append(p)
			stats[pd.id] = {"kills": 0, "aces": 0, "blocks": 0, "digs": 0, "errors": 0, "serves": 0, "num": pd.num, "pos": pd.pos, "team": k}
		teams.append(team)
	_place_sides()
	for k in 2:
		for p in teams[k].players:
			var pl: Player = p
			pl.position = pl.target


func _roles() -> Array:
	match n_players:
		4:
			return [DB.POS_TEKONG, DB.POS_FEEDER, DB.POS_STRIKER, DB.POS_STRIKER]
		2:
			return [DB.POS_TEKONG, DB.POS_STRIKER]
	return [DB.POS_TEKONG, DB.POS_FEEDER, DB.POS_STRIKER]


## Each team's players to their side, after a change of ends.
func _place_sides() -> void:
	for side in 2:
		var team: Dictionary = teams[side_team[side]]
		for p in team.players:
			var pl: Player = p
			pl.side = side
	_setup_positions()


func team_on(side: int) -> Dictionary:
	return teams[side_team[side]]


func side_of_team(team: int) -> int:
	return 0 if side_team[0] == team else 1


func players_on(side: int) -> Array:
	return team_on(side).players


func _role_player(side: int, role: int, nth := 0) -> Player:
	var k := 0
	for p in players_on(side):
		var pl: Player = p
		if pl.role == role:
			if k == nth:
				return pl
			k += 1
	return players_on(side)[0]


func _make_officials() -> void:
	var post_z := Court.HALF_W + Court.POST_OUT
	# In suits, as at the World Cup and the Asian championships: dark jackets and trousers, white shirts, ties.
	var look := {"suit": Color("1b2030"), "tie": Color("7a1c26"), "skin": Color("c98a5a")}
	_ref = RealBody.new(look)
	add_child(_ref)
	_ref.position = Vector3(0, 0.8, post_z + 0.82)
	_ref.rotation.y = PI
	officials.append(_ref)
	# The assistant referee standing at the other post (off the middle of the picture); a line judge standing at each
	# end, off the far corner, watching his half's back line and the side line (in the picture, never in front of it).
	var spots := [Vector3(-0.9, 0, -post_z - 1.6), Vector3(-Court.HALF - 0.35, 0, Court.HALF_W + 1.35),
		Vector3(Court.HALF + 0.35, 0, Court.HALF_W + 1.35)]
	for i in spots.size():
		var b := RealBody.new(look.merged({"skin": [Color("e0b48c"), Color("b07448"), Color("8d5a36")][i % 3]}, true))
		add_child(b)
		b.position = spots[i]
		var to: Vector3 = -spots[i] if i == 0 else Vector3(signf(spots[i].x) * Court.HALF * 0.5, 0, 0) - spots[i]
		b.rotation.y = atan2(to.x, to.z)
		officials.append(b)
		if i > 0:
			_judges.append(b)
	for o in officials:
		_officials.add(o, Moves.static_pose("sit" if o == _ref else "stand"), o != _ref, _judges.has(o))


## The substitutes: the squad's players not playing, in the team's kit, on its bench by the scorers' table (two a side
## in a regu, one in doubles; one on Low). They change benches with the ends.
func _make_bench() -> void:
	var n := 1 if n_players == 2 or int(Game.settings.graphics) == Game.GFX_LOW else 2
	for k in 2:
		var t: Dictionary = teams[k]
		var on := {}
		for p in t.players:
			on[String((p as Player).data.id)] = true
		var c2: Color = t.c2
		for pd in DB.squad(String(t.id), women):
			if (_subs[k] as Array).size() >= n:
				break
			if on.has(String(pd.id)):
				continue
			var b := RealBody.new({"skin": pd.get("skin", Color("c98a5a")), "jersey": t.c1,
				"shorts": c2.darkened(0.3) if c2.get_luminance() > 0.7 else c2, "height": float(pd.get("height", 1.76)), "women": women})
			add_child(b)
			b.rotation.y = PI   # facing the court
			_subs[k].append(b)
			_bench.add(b, Moves.static_pose("sit"))
	_seat_bench()


## Each team's substitutes on the bench at its own end.
func _seat_bench() -> void:
	var z := Court.HALF_W + Court.POST_OUT + 2.45
	for k in 2:
		var x := Court.sgn(side_of_team(k)) * 4.5
		var subs: Array = _subs[k]
		for i in subs.size():
			(subs[i] as RealBody).position = Vector3(x + (0.0 if subs.size() == 1 else (i - 0.5) * 1.15), 0, z)


## The substitutes up with their arms when their side wins a big point.
func _bench_cheer(team: int) -> void:
	for b in _subs[team]:
		if rng.randf() < 0.75:
			var up := rng.randf_range(-165.0, -135.0)
			_bench.show_signal(b, {"upperarm_l": Vector3(up, 0, 18), "upperarm_r": Vector3(up, 0, -18),
				"forearm_l": Vector3(-25, 0, 0), "forearm_r": Vector3(-25, 0, 0)}, rng.randf_range(1.0, 1.6))


# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	if paused:
		return
	if state == S.REPLAY:
		_replay_step(delta)
		return
	var ts := time_scale * pace
	if _slowmo_until > 0.0 and now < _slowmo_until:
		ts = 0.35
	var dt := delta * ts
	now += dt
	state_t += dt
	_step(dt)
	if state in [S.SETUP, S.DEAD, S.BREAK]:
		_between_points()
	for side in 2:
		for p in players_on(side):
			var pl: Player = p
			pl.look_at_pos = pl.look_to if pl.look_to.is_finite() else ball.global_position
			pl.stroll = state in [S.SETUP, S.DEAD, S.BREAK]
			pl.tick(dt, now)
	ball.update_to(now, dt)
	if _carrier:
		ball.hold(_carrier.carry_point())
	_officials.tick(dt, ball.global_position, state == S.RALLY or state == S.TOSS)
	_bench.tick(dt, ball.global_position, state == S.RALLY or state == S.TOSS)
	Crowd.set_look(ball.global_position)
	cam.follow(ball.global_position, delta, self)
	hud.tick(delta)
	_record()
	if controls.visible:
		_joy = controls.joystick
		_mark_mine()
		_user_steer(dt)
	_check_frame_rate(delta)


func _step(_dt: float) -> void:
	match state:
		S.INTRO:
			if state_t > 2.6:
				_begin_setup()
		S.SETUP:
			# The serve waits for the ball to be in the thrower's hands and him turned to the server, and for everyone
			# to reach his place (a long rally ends far from it), up to 9 s; if the ball is still on its way after 14,
			# the thrower is given it.
			if state_t > 14.0 and _carrier != _thrower():
				_give(_thrower())
			if state_t > SETUP_TIME and _carrier == _thrower() and _thrower_set() and (_all_in_place() or state_t > 9.0):
				_begin_toss()
		S.TOSS, S.RALLY:
			_rally_events()
		S.DEAD:
			if state_t > DEAD_TIME and _pending_call.is_empty():
				_after_point()
		S.BREAK:
			if state_t > BREAK_TIME:
				_begin_setup()
		S.REVIEW:
			if state_t > 3.4:
				_end_review()
	if not _pending_call.is_empty() and now > float(_pending_call.until):
		_pending_call = {}
		hud.challenge_prompt(false)


# ---------------------------------------------------------------- the serve

func _serving_side() -> int:
	return side_of_team(server)


func _setup_positions() -> void:
	var ss := _serving_side()
	for side in 2:
		var serving := side == ss
		for p in players_on(side):
			var pl: Player = p
			pl.hurry = 0.3   # a brisk walk (Player.stroll)
			pl.target = _serve_spot(pl, side, serving)


func _all_in_place() -> bool:
	for side in 2:
		for p in players_on(side):
			var pl: Player = p
			if Vector2(pl.position.x - pl.target.x, pl.position.z - pl.target.z).length() > 0.35:
				return false
	return true


## Where each player stands for the serve: the serving side's tekong with a foot in the service circle and both
## inside players in their quarter circles; the receivers spread over their court. Quadrant and doubles servers serve
## from behind the back line.
func _serve_spot(pl: Player, side: int, serving: bool) -> Vector3:
	var lr := _lane(pl)
	if serving:
		match n_players:
			3:
				if pl.role == DB.POS_TEKONG:
					return Court.spot(side, Court.SERVICE_D + 0.25, 0.0)
				return Court.spot(side, 0.55, lr * (Court.HALF_W - 0.55))
			4:
				if pl.role == DB.POS_TEKONG:
					return Court.spot(side, Court.HALF + 0.4, 0.0)
				if pl.role == DB.POS_FEEDER:
					return Court.spot(side, 1.4, 1.6)
				return Court.spot(side, 1.4 if pl.slot == 2 else 3.6, -1.6 if pl.slot == 2 else 0.0)
			2:
				if pl.role == DB.POS_TEKONG:
					return Court.spot(side, Court.HALF + 0.4, 0.0)
				return Court.spot(side, 1.6, -1.2)
	if n_players == 3:
		# A regu receives in a flat line 3-4 m off the net, nobody at it (as both matches did): the tekong in the middle
		# on his circle, the feeder (to his left) a little deeper than the striker.
		match pl.role:
			DB.POS_TEKONG:
				return Court.spot(side, 4.2, 0.0)
			DB.POS_FEEDER:
				return Court.spot(side, 3.9, 1.7)
		return Court.spot(side, 3.1, -1.6)
	match pl.role:
		DB.POS_TEKONG:
			return Court.spot(side, 4.7, 0.0)
		DB.POS_FEEDER:
			return Court.spot(side, 2.7, 1.7)
	if n_players == 4 and pl.slot == 3:
		return Court.spot(side, 4.4, -1.5)
	return Court.spot(side, 2.7 if n_players != 2 else 2.4, -1.7)


## A player's lane across the court, to his left (1) or right (-1): the feeder left, the striker right.
func _lane(pl: Player) -> float:
	if pl.role == DB.POS_FEEDER:
		return 1.0
	if pl.role == DB.POS_STRIKER:
		return -1.0
	return 0.0


func _begin_setup() -> void:
	state = S.SETUP
	state_t = 0.0
	plan = {}
	block = {}
	deflect = {}
	touches = 0
	touch_side = -1
	last_toucher = null
	rally_len = 0
	_seq = ""
	_spilled_by = null
	net_t = -1.0
	land_t = -1.0
	_setup_positions()
	_fetch_ball()
	hud.set_score()
	if not _intro_done:
		_intro_done = true
	hud.call_line(_score_call())
	if not bool(config.get("attract", false)):
		Sfx.crowd(arena.atmosphere() * (0.45 + _tension() * 0.5))
		# The home side a point from the set (or the match): the crowd claps in time.
		if set_point_for() == _home_team_index():
			Sfx.react("rhythm", -8.0)


## The score as the referee calls it: the server's score first.
func _score_call() -> String:
	var a: int = points[server]
	var b: int = points[1 - server]
	var s := "%d – %d" % [a, b]
	if a == b and a >= set_points - 1:
		s = tr("CALL_ALL").format({"n": a})
	return s


## The serving side's thrower: in a regu, the inside player nearer... the feeder; in quadrant and doubles the server
## throws to himself.
func _thrower() -> Player:
	var ss := _serving_side()
	if n_players == 3:
		return _role_player(ss, DB.POS_FEEDER)
	return _role_player(ss, DB.POS_TEKONG)


func _server() -> Player:
	return _role_player(_serving_side(), DB.POS_TEKONG)


## Between points the ball goes to the serving side's thrower, in his hands: whoever has it throws it to him; if it is
## lying loose, the nearest player (the serving side's rather) walks over and picks it up, and if he is not the thrower
## he throws it to him. Before the first serve (the ball not yet out) the thrower walks on with it.
func _fetch_ball() -> void:
	var thrower := _thrower()
	_fetcher = null
	_passer = null
	_catcher = null
	_pick_t = -1.0
	_pass_t = -1.0
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			pl.face_to = Vector3.INF
			pl.look_to = Vector3.INF
			pl.carrying = pl == _carrier
	if _carrier == thrower:
		return
	if _carrier:
		_passer = _carrier
		return
	var bp := ball.global_position
	if bp.y < -1.0:
		_give(thrower)
		return
	var best: Player = null
	var bd := INF
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			var d := Vector2(pl.position.x - bp.x, pl.position.z - bp.z).length() - (1.5 if side == _serving_side() else 0.0)
			if d < bd:
				bd = d
				best = pl
	_fetcher = best


func _give(pl: Player) -> void:
	if _carrier and _carrier != pl:
		_carrier.carrying = false
	_carrier = pl
	pl.carrying = true
	_fetcher = null if _fetcher == pl else _fetcher


## A frame between points: the fetcher to the ball and picking it up, the throw to the thrower and his catch, the
## thrower at his place turned to the server, the receivers on their toes.
func _between_points() -> void:
	var thrower := _thrower()
	var srv := _server()
	var ss := _serving_side()
	if _fetcher:
		var f := _fetcher
		var bp := ball.global_position
		var flat := Vector3(bp.x, 0, bp.z)
		var to := flat - f.position
		to.y = 0.0
		var dir := to.normalized() if to.length() > 0.05 else f.net_dir()
		f.target = flat - dir * float(Moves.CONTACT["pick"][1])
		f.hurry = 0.5
		f.face_to = flat
		f.look_to = bp
		if _pick_t < 0.0 and f.move == "" and to.length() < 0.7 and bp.y < 0.35 and ball.vel.length() < 1.5 \
				and state != S.DEAD:
			f.play_now("pick", now)
			_pick_t = now + Moves.contact_time("pick")
		if _pick_t > 0.0 and now >= _pick_t:
			_pick_t = -1.0
			_give(f)
			f.face_to = Vector3.INF
			f.look_to = Vector3.INF
			if f != thrower:
				_passer = f
			_back_to_place(f)
	if _passer and _carrier == _passer and _pass_t < 0.0 and _passer.move == "":
		var pz := _passer
		pz.face_to = thrower.position
		pz.look_to = thrower.position + Vector3(0, 1.4, 0)
		thrower.face_to = pz.position
		thrower.look_to = pz.carry_point()
		thrower.target = thrower.position   # he stops to take it
		if _turned_to(pz, thrower.position) and _turned_to(thrower, pz.position):
			pz.play_now("toss", now)
			_pass_t = now + Moves.contact_time("toss")
	if _passer and _pass_t > 0.0 and now >= _pass_t:
		_pass_t = -1.0
		var from := _passer.carry_point()
		var to_him := Vector3(_passer.position.x - thrower.position.x, 0, _passer.position.z - thrower.position.z).normalized()
		var catch := thrower.position + to_him * 0.42 + Vector3(0, 1.12, 0)
		var sol := Ball.solve_apex(from, catch, maxf(from.y, catch.y) + 0.4 + from.distance_to(catch) * 0.13)   # (a lob, higher the further)
		_carrier = null
		_passer.carrying = false
		ball.launch(from, sol[0], now)
		_catcher = thrower
		_catch_t = now + float(sol[1])
		_passer.face_to = Vector3.INF
		_passer.look_to = Vector3.INF
		_back_to_place(_passer)
		_passer = null
	if _catcher:
		_catcher.look_to = ball.global_position
		if now >= _catch_t:
			var c := _catcher
			_catcher = null
			_give(c)
			c.face_to = Vector3.INF
			c.look_to = Vector3.INF
			_back_to_place(c)
	# The thrower with the ball at his place: turned to the server, his eyes on him; the server's on the ball.
	if state == S.SETUP and _carrier == thrower and thrower != srv and _at_place(thrower):
		thrower.face_to = srv.position
		thrower.look_to = srv.position + Vector3(0, 1.5, 0)
		srv.look_to = thrower.carry_point()
	# Waiting for the serve: the receivers on their toes, the servers' inside players ready too.
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			var waiting := state == S.SETUP and _at_place(pl) and pl != thrower and pl != srv
			pl.ready_bounce = (1.0 if side != ss else 0.5) if waiting else 0.0


func _back_to_place(pl: Player) -> void:
	pl.target = _serve_spot(pl, pl.side, pl.side == _serving_side())
	pl.hurry = 0.3


func _at_place(pl: Player) -> bool:
	var spot := _serve_spot(pl, pl.side, pl.side == _serving_side())
	return Vector2(pl.position.x - spot.x, pl.position.z - spot.z).length() < 0.35


## He is turned (within 25 degrees) to face p.
func _turned_to(pl: Player, p: Vector3) -> bool:
	var to := Vector3(p.x - pl.position.x, 0, p.z - pl.position.z)
	if to.length() < 0.1:
		return true
	return absf(angle_difference(pl.body.rotation.y, atan2(to.x, to.z))) < deg_to_rad(25.0)


## The thrower ready to throw: at his place and turned to the server (or, serving himself, at his place).
func _thrower_set() -> bool:
	var thrower := _thrower()
	var srv := _server()
	if not _at_place(thrower):
		return false
	return thrower == srv or _turned_to(thrower, srv.position)


func _begin_toss() -> void:
	state = S.TOSS
	state_t = 0.0
	_whistle("long" if points[0] + points[1] == 0 else "short")   # (a set's first serve: a long blast)
	var thrower := _thrower()
	var srv := _server()
	srv.hurry = 1.0
	# The last few centimetres (he is within 35 cm, or set-up ran out of time): eased over the throw, not a jump.
	srv.vel = Vector3.ZERO
	var horse := _wants_horse(srv)
	var mv := "horse" if horse else "serve"
	var mirror := srv.left_footed()
	# The throw: underarm from the thrower's hands to the server's kicking spot, a gentle lob.
	var t_release := now + Moves.contact_time("toss")
	thrower.play_now("toss", now)
	var kick_h: float = Moves.CONTACT[mv][0] - (0.1 if women else 0.0)
	var kp := srv.target + srv.net_dir() * float(Moves.CONTACT[mv][1]) + Vector3(0, kick_h, 0)
	var right := Vector3(-srv.net_dir().z, 0, srv.net_dir().x)
	kp += right * float(Moves.CONTACT[mv][2]) * (-1.0 if mirror else 1.0)
	# From his hands (where they will be as he lets go is nearly where they are now: the flight is timed from there).
	var hand := thrower.carry_point()
	var flight := float(Ball.solve_apex(hand, kp, kp.y + (0.9 if thrower != srv else 0.6))[1])
	var t_kick := t_release + flight
	_schedule(t_release, func():
		var from := thrower.carry_point()
		_carrier = null
		thrower.carrying = false
		ball.launch(from, Ball.solve_time(from, kp, maxf(0.2, t_kick - now))[0], now))
	# Then he turns back to the net and is set to play.
	_schedule(t_release + 0.3, func():
		thrower.face_to = Vector3.INF
		thrower.look_to = Vector3.INF
		srv.look_to = Vector3.INF)
	plan = {"player": srv, "kind": "serve", "move": mv, "t": t_kick, "pos": kp, "stand": srv.target, "touch": 0,
		"mirror": mirror, "user": _is_user(srv), "side": srv.side, "started": false, "auto": true}
	if plan.user:
		_open_window(plan, ["SERVE", "HORSE"])
	else:
		srv.queue_move(mv, t_kick - Moves.contact_time(mv), mirror)
	_attack_kind = ""


func _wants_horse(srv: Player) -> bool:
	if _is_user(srv):
		return false   # you choose with the button
	return int(srv.data.get("serve_kind", 0)) == 1 and rng.randf() < 0.75


# ---------------------------------------------------------------- scheduled events

var _sched: Array = []   # [time, callable]


func _schedule(t: float, f: Callable) -> void:
	_sched.append([t, f])


func _rally_events() -> void:
	# Things timed to the match clock: the throw's release, ...
	var i := 0
	while i < _sched.size():
		if now >= float(_sched[i][0]):
			var f: Callable = _sched[i][1]
			_sched.remove_at(i)
			f.call()
		else:
			i += 1
	if state != S.TOSS and state != S.RALLY:
		return
	# The ball at the net.
	if net_t > 0.0 and now >= net_t:
		var t := net_t
		net_t = -1.0
		_at_net(t)
		if state != S.RALLY and state != S.TOSS:
			return
	# A block.
	if not block.is_empty() and not bool(block.get("done", false)) and now >= float(block.t):
		block.done = true
	# The planned touch (yours when you press).
	if not plan.is_empty() and bool(plan.get("user", false)):
		if _user_touch_due():
			return
	elif not plan.is_empty() and now >= float(plan.t):
		var p := plan
		plan = {}
		_touch(p)
		return
	# The ball on the floor.
	if land_t > 0.0 and now >= land_t:
		land_t = -1.0
		_landed(ball.at(now))


# ---------------------------------------------------------------- touches

## The touch happens: its quality, then where the ball goes.
func _touch(p: Dictionary) -> void:
	var pl: Player = p.player
	var q := _quality(p)
	if bool(p.get("user", false)):
		pl.set_selected(false)
		_clear_buttons()
	input_window = {}
	hud.timing_done()
	var kind := String(p.kind)
	var side := pl.side
	if kind != "serve" and touch_side == side:
		touches += 1
	else:
		touches = 1
	touch_side = side
	last_toucher = pl
	rally_len += 1
	var from := ball.at(now)
	_last_kind = "%s/%s q%.2f" % [kind, String(p.move), q]
	_came = _attack_kind
	_last_touch = kind
	_spilled_by = null
	_seq += ("|" if touches == 1 and rally_len > 1 else " ") + ("%s%s" % [kind, "!" if q < 0.14 else ""])
	# A first touch against an attack is a dig, whatever it is played with.
	if kind in ["receive", "dig"] and _attack_kind in ["roll", "sunback", "tapak", "head_spike", "feint"]:
		kind = "dig"
	if kind != "attack" and kind != "serve":
		_attack_kind = ""
	_block_kill = false
	if pl.side == _user_side() and _is_user(pl):
		Game.haptic("perfect" if q > 0.85 else "touch")
	Sfx.voice("hup", -14.0, 0.9 + 0.2 * float(pl.slot) / 3.0)
	match kind:
		"serve":
			stats[pl.data.id].serves += 1
			state = S.RALLY
			_serve_kick(pl, from, q, String(p.move))
		"receive", "dig":
			_pass(pl, from, q, kind)
		"set":
			_make_set(pl, from, q, p)
		"attack":
			_attack(pl, from, q, p)
		"over":
			_kick_over(pl, from, q)


## How well a touch is made (0-1): yours from your timing, the others' from their ratings and the difficulty.
func _quality(p: Dictionary) -> float:
	var pl: Player = p.player
	var rating := _rating_for(pl, String(p.kind))
	if bool(p.get("user", false)):
		var t_ok := _timing_quality(p)
		var base := t_ok * (0.82 + rating * 0.0022)
		# The further from the spot he was, the worse the touch (out of reach, he missed it: _user_touch_due).
		base *= clampf(1.1 - _off_spot(p) / _reach(p) * 0.45, 0.5, 1.0)
		return clampf(base, 0.0, 1.0)
	var diff: float = [0.8, 0.9, 0.97, 1.03][difficulty] if _is_opponent(pl) else 0.94
	if user_team < 0:
		diff = 0.94
	var mean := clampf(rating / 100.0 * diff, 0.2, 0.98)
	# Harder balls are harder: a dig against a spike, a touch far from where he wanted it.
	mean *= float(p.get("ease", 1.0))
	return clampf(mean + rng.randfn(0.0, 0.11), 0.0, 1.0)


func _rating_for(pl: Player, kind: String) -> float:
	var d := pl.data
	match kind:
		"serve":
			return float(d.get("serve", 60))
		"set":
			return float(d.get("setting", 60))
		"attack":
			return float(d.get("spike", 60))
		"block":
			return float(d.get("block", 60))
	return float(d.get("receive", 60))


## Your timing: how close your press was to the moment the ball arrived (a touch is only made on a press).
func _timing_quality(p: Dictionary) -> float:
	var pt := float(p.get("press_t", p.t))
	var err := absf(pt - float(p.t))
	var w: Array = timing_windows()
	var label := "LATE" if pt > float(p.t) else "EARLY"
	var q := 0.0
	if err <= w[0]:
		q = 1.0
		label = "PERFECT"
	elif err <= w[1]:
		q = 0.8
		label = "GOOD"
	elif err <= w[2]:
		q = 0.55
	else:
		q = 0.3
	hud.timing_result(label)
	_press = {}
	return q


## Seconds either side of the moment: perfect, good, ok.
func timing_windows() -> Array:
	return [[0.09, 0.2, 0.34], [0.07, 0.16, 0.28], [0.055, 0.13, 0.23], [0.045, 0.11, 0.19]][difficulty]


# ---------------------------------------------------------------- where the ball goes

func _serve_kick(pl: Player, from: Vector3, q: float, mv: String) -> void:
	var opp := 1 - pl.side
	var target := _serve_target(pl, opp)
	if _press_choice("HORSE") and _is_user(pl):
		mv = "horse"
	var horse := mv == "horse"
	_attack_kind = "horse" if horse else ""
	# A fault on the serve now and then: the standing foot lifted.
	if rng.randf() < 0.003:
		_fault(pl.side, "FAULT_FOOT", pl)
		return
	var err := lerpf(2.6, 0.25, q) * (1.25 if horse else 1.0)
	target += Vector3(rng.randfn(0, err * 0.5), 0, rng.randfn(0, err * 0.5))
	# Servers miss now and then: long, wide, or into the net (the horse kick more often). Hit as hard as the top
	# tekongs hit it, about one in six (a fifth of the points at the 2024 World Cup and Asian Cup were service faults).
	var into_net := false
	if not _is_user(pl) and rng.randf() < (0.16 + (1.0 - q) * 0.24 + (0.03 if horse else 0.0)) * _err_scale(pl):
		var so := Court.sgn(opp)
		match rng.randi_range(0, 2):
			0:
				target.x = so * (Court.HALF + rng.randf_range(0.2, 1.0))
			1:
				target.z = signf(target.z if target.z != 0.0 else 1.0) * (Court.HALF_W + rng.randf_range(0.2, 0.8))
			_:
				into_net = true
	target.y = Ball.RADIUS
	var v: Vector3
	_server_q = q
	_server_r = float(pl.data.get("serve", 60))
	if horse:
		v = _drive(from, target, lerpf(11.0, 16.5, q), 0.25)
	elif not _is_user(pl) or q >= 0.6:
		# The power serve: struck hard and flat over the tape, the leg high (every serve in both matches was). At you a
		# little softer on Rookie and Pro; yours when you time it well.
		var pace: float = [0.82, 0.92, 1.0, 1.04][difficulty] if _is_opponent(pl) else 1.0
		var speed := lerpf(9.5, 14.0, q) if not _is_user(pl) else lerpf(10.0, 14.0, (q - 0.6) / 0.4)
		v = _drive(from, target, speed * pace, 0.3)
		_attack_kind = "power"
	else:
		var sol := Ball.solve_apex(from, target, lerpf(2.4, 3.1, rng.randf()) + (0.4 if q < 0.4 else 0.0))
		v = sol[0]
	# A poor serve catches the net: it is struck too flat to clear the tape.
	if into_net or (q < 0.22 and rng.randf() < 0.55):
		v = Ball.solve_apex(from, target, arena.net_top - 0.15)[0]
	Sfx.play_at("kick", from, 1.0, 1.1 if horse else 1.0)   # (the kicks: a real ball's, low and soft; 3 dB up)
	_launch(from, v, pl.side, horse)
	_after_touch(pl.side)


## A ball driven hard from p0 to land at target: as fast as speed allows while still clearing the net's tape by
## clearance (m); slower if it must be, to get over.
func _drive(p0: Vector3, target: Vector3, speed: float, clearance: float) -> Vector3:
	var dist := p0.distance_to(target)
	var t := dist / speed
	var v := Vector3.ZERO
	for i in 40:
		v = Ball.solve_time(p0, target, t)[0]
		if absf(v.x) < 0.01:
			return v
		var tn := -p0.x / v.x
		if tn <= 0.0 or Ball.pos_at(p0, v, tn).y >= arena.net_top + Ball.RADIUS + clearance:
			return v
		t += 0.025
	return v


func _serve_target(pl: Player, opp: int) -> Vector3:
	if _is_user(pl):
		return _aim_target(opp, Vector3(Court.sgn(opp) * 5.0, 0, 0), 2.6)
	# As the top sides serve: at one receiver all set long (the Philippines served every serve at India's same player),
	# at him or just past him; now and then deep into a corner instead.
	var mark := _mark(opp)
	if mark and rng.randf() < 0.75:
		return Vector3(mark.position.x, 0, mark.position.z) + Vector3(Court.sgn(opp) * rng.randf_range(-0.2, 0.7), 0,
			rng.randf_range(-0.7, 0.7))
	return Court.spot(opp, rng.randf_range(4.5, 6.1), rng.randf_range(-2.4, 2.4))


## The receiver a side's servers aim at this set: a wing player (not the tekong, in a regu), the one who passes worst.
func _mark(side: int) -> Player:
	var key := "%d:%d" % [side, set_no]
	if not _marks.has(key):
		var worst: Player = null
		for p in players_on(side):
			var o: Player = p
			if n_players == 3 and o.role == DB.POS_TEKONG:
				continue
			if worst == null or float(o.data.receive) + rng.randf_range(-3, 3) < float(worst.data.receive):
				worst = o
		_marks[key] = worst
	return _marks[key]


## The computer's errors (a serve missed, a reception spilled) as the difficulty has them: more against Rookie, fewer
## against Legend; its own team's (yours, playing as one player) as they are.
func _err_scale(pl: Player) -> float:
	return [1.35, 1.15, 1.0, 0.85][difficulty] if _is_opponent(pl) else 1.0


## A first touch: to the feeder's spot by the net (a dig: up in the air near the digger, for anyone to set).
func _pass(pl: Player, from: Vector3, q: float, kind: String) -> void:
	var side := pl.side
	if kind == "dig":
		stats[pl.data.id].digs += 1
	var setter := _role_player(side, DB.POS_FEEDER if n_players != 2 else DB.POS_TEKONG)
	if setter == pl and n_players > 2:
		setter = _role_player(side, DB.POS_TEKONG)
	# Up to the setter: in a regu in the middle, 2.4 m off the net, where the top sides' setters take it.
	var spot := Court.spot(side, 1.3, _lane(setter) * 1.1 if setter.role == DB.POS_FEEDER else 0.6)
	if n_players == 3 and setter.role == DB.POS_FEEDER:
		spot = Court.spot(side, 2.4, _lane(setter) * 0.4)
	var apex := lerpf(2.6, 3.6, rng.randf())
	if kind == "dig":
		spot = Vector3(pl.position.x, 0, pl.position.z).lerp(spot, 0.45)
		apex = lerpf(2.6, 4.2, q)
	# A power serve spilled: a third of the points in those matches were decided by the reception failing (off the
	# body, out, or straight back over). The harder the serve and the better its server against the receiver, the more
	# often.
	if kind == "receive" and _came in ["power", "horse"] and not _is_user(pl):
		var rec := float(pl.data.get("receive", 60))
		var spill := clampf(0.24 + (_server_r - rec) * 0.006 + (1.0 - rec / 100.0) * 0.3, 0.06, 0.5)
		spill *= lerpf(0.6, 1.3, _server_q) * (1.2 if _came == "horse" else 1.0)
		if rng.randf() < minf(spill * _err_scale(pl), 0.55):
			_seq += "~"
			_spill(pl, from)
			return
	if q < 0.14:
		# A shank: off the body anywhere.
		Sfx.play_at("knee", from, -4.0)
		var wild := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-5, 5))
		var v := Vector3(wild.x, rng.randf_range(2.0, 5.5), wild.z)
		_launch(from, v, side, false)
		_after_touch(side)
		return
	var err := lerpf(2.2, 0.15, q)
	spot += Vector3(rng.randfn(0, err * 0.45), 0, rng.randfn(0, err * 0.45))
	# Keep it on this side unless it was hit far too hard.
	if spot.x * Court.sgn(side) < 0.25 and q > 0.3:
		spot.x = Court.sgn(side) * 0.35
	spot.y = 1.0
	var sol := Ball.solve_apex(from, spot, apex)
	var foot := String(_last_move(pl)) in ["sila", "kuda", "dig"]
	Sfx.play_at("kick" if foot else "knee", from, -1.0 if foot else -4.0)
	_launch(from, sol[0], side, false)
	_after_touch(side)


## A reception spilled (as at the World Cup and the Asian Cup, where they lost a third of the points): off the body and
## out, dead at his feet before anyone gets to it, or floated straight back over the net for the servers to put away.
func _spill(pl: Player, from: Vector3) -> void:
	var side := pl.side
	_spilled_by = pl
	var r := rng.randf()
	var v: Vector3
	if r < 0.4:
		# Out: behind him, or off to the side.
		var out := Court.spot(side, rng.randf_range(Court.HALF + 1.5, Court.HALF + 4.0), rng.randf_range(-5.0, 5.0))
		if rng.randf() < 0.5:
			var wide := rng.randf_range(Court.HALF_W + 1.2, Court.HALF_W + 3.5)
			out = Court.spot(side, rng.randf_range(0.5, 5.5), wide if rng.randf() < 0.5 else -wide)
		v = Ball.solve_apex(from, out, from.y + rng.randf_range(0.2, 0.8))[0]
	elif r < 0.7:
		v = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.3, 0.5), rng.randf_range(-1.5, 1.5))   # dead
	else:
		var over := Court.spot(1 - side, rng.randf_range(1.5, 3.5), rng.randf_range(-2.2, 2.2))
		v = Ball.solve_apex(from, over, maxf(from.y, arena.net_top) + rng.randf_range(1.0, 1.8))[0]
	Sfx.play_at("knee", from, -4.0)
	_launch(from, v, side, false)
	_after_touch(side)


func _last_move(pl: Player) -> String:
	return pl.move


## The set: the feeder lofts the ball to the spot the striker will meet it at, as high as his spike needs: a roll
## spike wants a high set, a sunback a lower one, a header or sole spike a quick one.
func _make_set(pl: Player, from: Vector3, q: float, p: Dictionary) -> void:
	var side := pl.side
	var striker := _role_player(side, DB.POS_STRIKER)
	if striker == pl:
		striker = _role_player(side, DB.POS_FEEDER)
	var spike_move := _spike_move(striker, p)
	if _is_user(pl) and _press_choice("ATTACK2"):
		# The feeder attacks over the net himself (a surprise second-touch attack).
		_attack(pl, from, q, {"move": "tapak", "player": pl})
		return
	var h: float = Moves.CONTACT[spike_move][0] - (0.12 if women else 0.0)
	var depth := lerpf(0.42, 0.75, rng.randf())
	var cp := Court.spot(side, depth, _lane(striker) * lerpf(0.9, 1.6, rng.randf()))
	var err := lerpf(1.1, 0.06, q)
	cp += Vector3(rng.randfn(0, err * 0.4), 0, rng.randfn(0, err * 0.4))
	cp.y = h
	var apex: float = {"roll": 4.1, "sunback": 3.6, "tapak": 3.3, "head_spike": 3.4, "feint": 3.3}.get(spike_move, 3.6) + rng.randf_range(-0.15, 0.2)
	if _is_user(pl) and _press_choice("QUICK"):
		apex -= 0.5
		if spike_move == "roll":
			spike_move = "sunback"
	if cp.x * Court.sgn(side) < 0.25:
		cp.x = Court.sgn(side) * 0.3
	var sol := Ball.solve_apex(from, cp, apex)
	Sfx.play_at("kick", from, -3.0, 1.05)
	_set_for = {"player": striker, "move": spike_move}
	_set_cp = cp
	_launch(from, sol[0], side, false)
	_after_touch(side)


func _spike_move(striker: Player, _p: Dictionary) -> String:
	match int(striker.data.get("spike_kind", DB.SPIKE_ROLL)):
		DB.SPIKE_ROLL:
			return "roll"
		DB.SPIKE_SUNBACK:
			return "sunback"
		DB.SPIKE_TAPAK:
			return "tapak"
	return "head_spike"


## The attack: driven down into the other court, aimed at the space the defenders leave (or where you aim).
func _attack(pl: Player, from: Vector3, q: float, p: Dictionary) -> void:
	var side := pl.side
	var opp := 1 - side
	var mv := String(p.get("move", "roll"))
	if _is_user(pl):
		if _press_choice("FEINT"):
			mv = "feint"
		elif _press_choice("SPIKE2"):
			mv = String(p.get("alt", mv))
	_attack_kind = mv
	# Touching the net in the follow-through.
	if q < 0.3 and rng.randf() < 0.25 and mv != "feint":
		_fault(side, "FAULT_NET", pl)
		return
	var aim: Vector3 = p.get("aim", Vector3.INF)
	var target := aim if aim != Vector3.INF and mv != "feint" else _attack_target(pl, opp, mv)
	var err := lerpf(2.0, 0.22, q)
	target += Vector3(rng.randfn(0, err * 0.45), 0, rng.randfn(0, err * 0.45))
	# A spike is a risk: the harder the spike, the likelier it goes long or wide (a roll spike most of all).
	var risk: float = {"roll": 0.045, "sunback": 0.035, "tapak": 0.03, "head_spike": 0.025}.get(mv, 0.0) + (1.0 - q) * 0.1
	if not _is_user(pl) and rng.randf() < risk:
		var s := Court.sgn(opp)
		if rng.randf() < 0.55:
			target.x = s * (Court.HALF + rng.randf_range(0.2, 1.2))
		else:
			target.z = signf(target.z if target.z != 0.0 else 1.0) * (Court.HALF_W + rng.randf_range(0.15, 0.9))
	target.y = Ball.RADIUS
	var v: Vector3
	if mv == "feint":
		var sol := Ball.solve_apex(from, target, from.y + 0.35)
		v = sol[0]
	else:
		var speed: float = {"roll": 30.0, "sunback": 27.0, "tapak": 22.0, "head_spike": 20.0}.get(mv, 24.0) * lerpf(0.68, 1.04, q)
		# A poor one, now and then, is driven flat into the tape.
		v = _drive(from, target, speed, 0.04 if q > 0.3 or rng.randf() < 0.6 else -0.25)
	Sfx.play_at("spike" if mv != "feint" else "kick", from, 0.0 if mv != "feint" else -3.0)
	if _is_user(pl):
		Game.haptic("spike")
	_launch(from, v, side, mv != "feint")
	_block_at_net(pl, from, v, mv)
	if mv in ["roll", "sunback"] and (user_team >= 0) and rng.randf() < 0.7:
		_slowmo_until = now + 0.35
	_after_touch(side)


func _attack_target(pl: Player, opp: int, mv: String) -> Vector3:
	if _is_user(pl):
		var base := Court.spot(opp, 3.0 if mv != "feint" else 1.2, 0.0)
		return _aim_target(opp, base, 2.6 if mv != "feint" else 1.0)
	# The open court: of a few targets, the one farthest from any defender.
	var cands: Array = []
	if mv == "feint":
		for z: float in [-2.2, -1.0, 0.0, 1.0, 2.2]:
			cands.append(Court.spot(opp, 1.2, z))
	else:
		for d: float in [1.8, 3.4, 5.4, 6.2]:
			for z: float in [-2.6, -1.3, 0.0, 1.3, 2.6]:
				cands.append(Court.spot(opp, d, z))
	var best := cands[0] as Vector3
	var best_score := -1.0
	for c in cands:
		var cv: Vector3 = c
		var near := 99.0
		for p in players_on(opp):
			var o: Player = p
			near = minf(near, Vector2(o.position.x - cv.x, o.position.z - cv.z).length())
		var score := minf(near, 2.4) + rng.randf_range(0.0, 1.8)
		if score > best_score:
			best_score = score
			best = cv
	return best


## Where you aim: the joystick moves the aim from base across the other court, as seen from the camera.
func _aim_target(opp: int, base: Vector3, reach: float) -> Vector3:
	var j := _joy
	if j.length() < 0.2:
		return base + Vector3(0, 0, rng.randf_range(-1.2, 1.2))
	var t := base + _cam_dir(j) * reach
	var s := Court.sgn(opp)
	t.x = s * clampf(t.x * s, 0.6, Court.HALF - 0.2)
	t.z = clampf(t.z, -Court.HALF_W + 0.2, Court.HALF_W - 0.2)
	return t


## A third touch with no spike on: kicked back over, high and deep.
func _kick_over(pl: Player, from: Vector3, q: float) -> void:
	var opp := 1 - pl.side
	var target := Court.spot(opp, rng.randf_range(3.5, 6.0), rng.randf_range(-2.4, 2.4))
	var err := lerpf(2.4, 0.4, q)
	target += Vector3(rng.randfn(0, err * 0.5), 0, rng.randfn(0, err * 0.5))
	target.y = Ball.RADIUS
	var sol := Ball.solve_apex(from, target, maxf(from.y + 1.0, arena.net_top + 1.8))
	Sfx.play_at("kick", from, -1.0)
	_launch(from, sol[0], pl.side, false)
	_after_touch(pl.side)


# ---------------------------------------------------------------- the flight

func _launch(from: Vector3, v: Vector3, by_side: int, hard: bool) -> void:
	ball.launch(from, v, now, hard)
	land_t = ball.when_height(Ball.RADIUS)
	net_t = ball.when_net()
	if net_t > land_t:
		net_t = -1.0
	_sched_clear_blocks()


func _sched_clear_blocks() -> void:
	pass


## The ball reaches the net's plane: over it (between the boundary tapes), into it, or round or under it.
func _at_net(t: float) -> void:
	var p := ball.at(t)
	var from_side := 0 if ball.v_launch.x > 0.0 else 1
	if not deflect.is_empty():
		# The block: back it goes, or up on the blocker's side.
		var d := deflect
		deflect = {}
		var bp: Player = d.player
		_attack_kind = ""   # the spike is spent: what happens now is the block's
		touch_side = bp.side
		touches = 1
		last_toucher = bp
		rally_len += 1
		_seq += "|block" + ("!" if bool(d.get("kill", false)) else "")
		Sfx.play_at("block", p, 0.0)
		if _is_user(bp):
			Game.haptic("block")
		# A stuff block comes off on the attackers' side of the net; a soft one on the blocker's own.
		var kill_side := 1 - bp.side if bool(d.get("kill", false)) else bp.side
		ball.launch(Vector3(Court.sgn(kill_side) * 0.12, p.y, p.z), d.v, t)
		_block_kill = bool(d.get("kill", false))
		land_t = ball.when_height(Ball.RADIUS)
		net_t = ball.when_net()
		if net_t > land_t:
			net_t = -1.0
		if bool(d.get("kill", false)):
			stats[bp.data.id].blocks += 1
			_why = "block"
			hud.banner(tr("CALL_BLOCKED"), team_on(bp.side).c1)
			Sfx.react("ooh", -4.0)
		_plan_next()
		return
	if absf(p.z) > Court.HALF_W + Ball.RADIUS:
		# Outside the boundary tape.
		_fault(from_side, "FAULT_OUTSIDE_TAPE", last_toucher)
		return
	var top := arena.net_top + Ball.RADIUS
	var bottom := arena.net_top - Court.NET_DEPTH - Ball.RADIUS
	if p.y < top and p.y > bottom:
		# Into the net: it drops back on the side it came from (still in play, if touches are left).
		Sfx.play_at("net", p, -2.0)
		var v := ball.vel
		var back := Vector3(-v.x * 0.18, maxf(0.4, absf(v.y) * 0.15), v.z * 0.4)
		ball.launch(Vector3(Court.sgn(from_side) * 0.09, p.y, p.z), back, t)
		land_t = ball.when_height(Ball.RADIUS)
		net_t = -1.0
		if rally_len == 1:
			_fault(from_side, "FAULT_SERVE_NET", last_toucher, false)   # a serve must cross: nobody may play it
			return
		_plan_next()
		return
	if p.y <= bottom:
		if OS.has_environment("TAKRAW_DEBUG"):
			print("UNDER launch %s v %s at %s touch_side %d toucher side %d" % [ball.p_launch, ball.v_launch, p, touch_side, last_toucher.side if last_toucher else -1])
		_fault(from_side, "FAULT_UNDER_NET", last_toucher)
		return
	# Over: the other side plans now (it already has, if it saw it coming).
	if touch_side == from_side:
		touches = 0


## After a touch: the next touch is planned by whichever side the ball will be on.
func _after_touch(side: int) -> void:
	_plan_next()
	_position_others()


func _plan_next() -> void:
	plan = {}
	if state != S.RALLY:
		return
	# Which side is the ball going to be played on next: if it crosses the net cleanly, the other side.
	var crossing := net_t > 0.0
	var next_side := touch_side
	var until := land_t
	if crossing:
		var pn := ball.at(net_t)
		if pn.y > arena.net_top + Ball.RADIUS and absf(pn.z) <= Court.HALF_W:
			next_side = 1 - touch_side if touch_side >= 0 else Court.side_of(ball.at(land_t).x)
		else:
			# It will meet the net (or pass under it, or round it) unless this side plays it first.
			until = net_t
	var touch_no := 1 if next_side != touch_side else touches + 1
	if touch_no > 3:
		return   # a fourth touch is a fault: nobody plays it, it falls
	# A free ball: a pass, a set or a soft kick that comes over (the top sides put it straight away: five of five in those
	# matches).
	_free_ball = touch_no == 1 and next_side != touch_side and _last_touch in ["receive", "dig", "set", "over"]
	if touch_no == 1:
		_set_cp = Vector3.ZERO
	var land := ball.at(land_t)
	# Leave a ball going out (a good player reads it; now and then one misjudges and plays it).
	if touch_no == 1 and not Court.in_court(land, next_side, Ball.RADIUS) and Court.side_of(land.x) == next_side:
		var margin := Court.line_margin(land)
		if margin > 0.12 and rng.randf() < 0.92:
			return
	var pick := _find_touch(next_side, touch_no, until)
	if OS.has_environment("TAKRAW_DEBUG") and touch_no == 1 and _attack_kind in ["roll", "sunback", "tapak", "head_spike"]:
		var nearest := 99.0
		for pp in players_on(next_side):
			nearest = minf(nearest, Vector2((pp as Player).position.x - land.x, (pp as Player).position.z - land.z).length())
		print("spike flight %.2fs land %s nearest defender %.2fm -> %s" % [land_t - now, land, nearest, "dig " + String(pick.get("move", "")) if not pick.is_empty() else "none"])
	if pick.is_empty():
		return
	pick.until = until
	plan = pick
	var pl: Player = pick.player
	if String(pick.kind) == "attack":
		_prepare_block(pick)
	if bool(pick.user):
		_take_control(pick)
		return
	pl.hurry = 1.0
	pl.target = pick.stand
	pl.queue_move(String(pick.move), float(pick.t) - Moves.contact_time(String(pick.move)), bool(pick.mirror))


## The best touch a side can make on the ball's flight: for each moment it is in reach, each player and each way of
## meeting it at that height, can he be there in time? The first good one, the easier the better.
func _find_touch(side: int, touch_no: int, until := -1.0) -> Dictionary:
	var s := Court.sgn(side)
	var t_end := (until if until > 0.0 else land_t) - 0.02
	var t0 := now + 0.12
	# A set ball is met where it was set to, by the striker, with his spike.
	if touch_no == 3 and not _set_for.is_empty():
		var striker: Player = _set_for.player
		var mv := String(_set_for.move)
		var h: float = Moves.CONTACT[mv][0] - (0.12 if women else 0.0)
		var tc := ball.when_height(h)
		if tc > now + 0.3 and tc < t_end:
			var cp := ball.at(tc)
			if cp.x * s > 0.05 and cp.x * s < 1.6:
				var mirror := striker.left_footed()
				var stand := Player.stand_for(cp, mv, side, mirror)
				var need := Vector2(stand.x - striker.position.x, stand.z - striker.position.z).length() / 5.6 + 0.15
				if need <= tc - now - Moves.contact_time(mv) * 0.5:
					_set_for = {}
					# Where he means to hit it, decided as he approaches (the defenders try to read it).
					var aim := _attack_target(striker, 1 - side, mv) if not _is_user(striker) else Vector3.INF
					return {"player": striker, "kind": "attack", "move": mv, "t": tc, "pos": cp, "stand": stand, "touch": 3,
						"mirror": mirror, "user": _is_user(striker), "side": side, "alt": "sunback" if mv == "roll" else "roll",
						"aim": aim, "from_set": true}
		_set_for = {}
	var best := {}
	var best_cost := 99.0
	var t := t0
	while t < t_end:
		var p := ball.at(t)
		if p.x * s > 0.05 and absf(p.z) < Court.HALF_W + 1.8 and p.x * s < Court.HALF + 2.0:
			var free := _free_ball and touch_no == 1 and p.x * s < 1.5
			for m in _moves_for_height(p.y, touch_no, free):
				var mv := String(m)
				for pp in players_on(side):
					var pl: Player = pp
					if mv in ["head_spike", "tapak"] and touch_no == 1 and _is_user(pl):
						continue   # (yours you play yourself)
					if pl == _spilled_by:
						continue
					var mirror := pl.left_footed()
					var stand := Player.stand_for(p, mv, side, mirror)
					if stand.x * s < 0.02:
						continue
					var react := 0.22 - float(pl.data.get("agility", 70)) * 0.0012
					var hard := _attack_kind in ["roll", "sunback", "tapak", "head_spike", "horse"] and touch_no == 1
					if hard:
						# Against a spike: a good defender reads it off the striker's approach and is moving as it is hit.
						react = 0.16 - float(pl.data.get("receive", 60)) * 0.0016
					var dist := Vector2(stand.x - pl.position.x, stand.z - pl.position.z).length()
					var speed := 5.2 * (0.82 + float(pl.data.get("agility", 70)) * 0.0028)
					var need := react + dist / speed
					var have := t - now - Moves.contact_time(mv) * (0.6 if not hard else 0.15)
					if hard and dist < 1.1 and t - now > 0.06:
						need = minf(need, 0.04 + dist * 0.12)   # it comes at him: a reflex touch, foot, chest or thigh
					if need > have:
						continue
					var cost := _touch_cost(pl, mv, touch_no) + (t - now) * 0.05 + dist * 0.04
					if free and mv in ["head_spike", "tapak"]:
						cost -= 0.45   # put it away
					if cost < best_cost:
						best_cost = cost
						var kind := _kind_for(mv, touch_no)
						var ease := 1.0
						if mv == "dig":
							ease = 0.8
						if touch_no == 1 and _attack_kind in ["roll", "sunback", "horse"]:
							ease *= 0.72 if dist > 0.5 else 0.85
						elif touch_no == 1 and _attack_kind == "power":
							ease *= 0.86 if dist > 0.5 else 0.93
						best = {"player": pl, "kind": kind, "move": mv, "t": t, "pos": p, "stand": stand, "touch": touch_no,
							"mirror": mirror, "user": _is_user(pl), "side": side, "ease": ease, "alt": "sunback"}
			if not best.is_empty() and best_cost < 0.6:
				break
		t += 0.04
	return best


func _kind_for(mv: String, touch_no: int) -> String:
	if touch_no == 1 and mv in ["head_spike", "tapak"]:
		return "attack"   # a free ball put away
	if touch_no == 2:
		return "set"
	if touch_no == 3:
		return "attack" if mv in ["roll", "sunback", "tapak", "head_spike", "feint"] else "over"
	return "dig" if mv == "dig" else "receive"


## Ways to meet a ball at height h, for the touch it is (the third touch, near the net and high enough, a spike; a free
## ball high by the net too).
func _moves_for_height(h: float, touch_no: int, free := false) -> Array:
	var out := []
	if (touch_no == 3 or free) and h > 1.9:
		out.append("head_spike")
	if free and h > 1.75 and h < 2.15:
		out.append("tapak")
	if touch_no == 3 and h > 1.45 and h < 2.3:
		out.append("feint")   # a soft tap over the net when no spike is on
	if h < 0.42:
		out.append("dig")
	elif h < 0.78:
		out.append_array(["sila", "kuda"])
	elif h < 1.02:
		out.append_array(["thigh", "sila"])
	elif h < 1.45:
		out.append("chest")
	elif h < 1.95:
		out.append("header")
	if h >= 0.3 and h < 0.62:
		out.append("dig")
	return out


func _touch_cost(pl: Player, mv: String, touch_no: int) -> float:
	var c: float = {"sila": 0.0, "thigh": 0.15, "chest": 0.25, "header": 0.3, "kuda": 0.3, "dig": 0.8, "head_spike": 0.2, "feint": 0.35}.get(mv, 0.4)
	# Roles: the feeder sets, the striker attacks; on a first touch the striker is spared if anyone else can play it.
	if touch_no == 2 and pl.role != DB.POS_FEEDER:
		c += 0.35
	if touch_no == 1 and pl.role == DB.POS_STRIKER and n_players > 2:
		c += 0.3
	if touch_no == 3 and pl.role != DB.POS_STRIKER:
		c += 0.3
	return c


## The other players move to where they should be: the side with the ball to set up the attack, the other to defend
## (the striker up at the net to block).
func _position_others() -> void:
	var p_side := touch_side
	for side in 2:
		var attacking := side == p_side if net_t < 0.0 else side != p_side
		for pp in players_on(side):
			var pl: Player = pp
			if not plan.is_empty() and plan.player == pl:
				continue
			if not block.is_empty() and block.player == pl:
				continue
			pl.hurry = 0.6
			var bz := clampf(ball.global_position.z * 0.3, -1.0, 1.0)
			if n_players == 3:
				pl.target = _regu_spot(pl, side, attacking, bz)
				continue
			match pl.role:
				DB.POS_TEKONG:
					pl.target = Court.spot(side, 4.2 if not attacking else 3.4, 0.0) + Vector3(0, 0, bz)
				DB.POS_FEEDER:
					pl.target = Court.spot(side, 1.8 if not attacking else 1.3, 1.2) + Vector3(0, 0, bz)
				_:
					if attacking:
						pl.target = Court.spot(side, 1.9, _lane(pl) * 1.6)
					else:
						pl.target = Court.spot(side, 0.9, -1.0) + Vector3(0, 0, bz)


## A regu player's place off the ball, as the top sides stand (measured on the 2024 World Cup's broadcast). With the
## ball: the setter in the middle 2.5 m off the net, the striker by it, the tekong deep; once the set is up, the two
## who are not spiking close in behind the spiker, where a blocked spike drops. Without it: the striker at the net to
## block, the setter 2.7 m back on his side, the tekong deep in the middle.
func _regu_spot(pl: Player, side: int, attacking: bool, bz: float) -> Vector3:
	var set_up := attacking and touches == 2 and touch_side == side and _set_cp != Vector3.ZERO
	if set_up and pl.role != DB.POS_STRIKER:
		# Cover: the tekong 2.5 m behind where the spike is hit, the setter short on the other side of it.
		if pl.role == DB.POS_TEKONG:
			return Court.spot(side, 2.5, _set_cp.z * 0.7)
		return Court.spot(side, 1.6, -signf(_set_cp.z if _set_cp.z != 0.0 else 1.0) * 1.3)
	match pl.role:
		DB.POS_TEKONG:
			return Court.spot(side, 3.8 if not attacking else 4.4, 0.0) + Vector3(0, 0, bz)
		DB.POS_FEEDER:
			return Court.spot(side, 2.7, 1.6) if not attacking else Court.spot(side, 2.4, 0.4) + Vector3(0, 0, bz * 0.5)
	if attacking:
		return Court.spot(side, 1.2, _lane(pl) * 1.4)
	return Court.spot(side, 0.8, -1.0) + Vector3(0, 0, bz)


## Against a spike coming (planned at the set): the defending side's striker goes up to the net in front of where it
## will be hit and jumps as it is. Yours jumps when you press BLOCK.
func _prepare_block(atk: Dictionary) -> void:
	block = {}
	var def_side := 1 - int(atk.side)
	var blocker := _role_player(def_side, DB.POS_STRIKER)
	var cp: Vector3 = atk.pos
	# One blocker, the inside player on the side the spike comes from: the striker, unless the feeder is clearly nearer
	# (yours stays yours: the computer doesn't take your block from you).
	var feeder := _role_player(def_side, DB.POS_FEEDER)
	if n_players == 3 and feeder and feeder != blocker and not _is_user(blocker) and not _is_user(feeder) \
			and absf(feeder.position.z - cp.z) + 1.5 < absf(blocker.position.z - cp.z):
		blocker = feeder
	var spot := Court.spot(def_side, float(Moves.CONTACT["block"][1]) - 0.09, 0.0)   # his raised foot reaches the net
	spot.z = clampf(cp.z, -Court.HALF_W + 0.5, Court.HALF_W - 0.5)
	blocker.hurry = 1.0
	blocker.target = spot
	block = {"player": blocker, "t": float(atk.t), "z": spot.z, "user": _is_user(blocker)}
	_read_attack(atk, def_side, blocker)
	if not block.user:
		# A good blocker reads it; a poor one guesses, and now and then stays down.
		if rng.randf() < 0.85:
			var err := rng.randfn(0.0, (100.0 - float(blocker.data.get("block", 60))) * 0.004)
			blocker.queue_move("block", float(atk.t) + err - Moves.contact_time("block"))
			block.jump_t = float(atk.t) + err


## The defenders read the coming spike off the striker's approach: a good one gets in front of where it is going.
func _read_attack(atk: Dictionary, def_side: int, blocker: Player) -> void:
	var aim: Vector3 = atk.get("aim", Vector3.INF)
	if aim == Vector3.INF:
		# Yours: they read your striker's shoulders as well as anyone's: a likely spot, deep in the middle.
		aim = Court.spot(def_side, 3.6, 0.0)
	var taken := false
	for pp in players_on(def_side):
		var d: Player = pp
		if d == blocker:
			continue
		var read := float(d.data.get("receive", 60)) / 100.0 * 0.75
		if not taken and rng.randf() < read:
			taken = true
			var f := Vector3(Court.sgn(def_side), 0, 0)
			d.target = aim + f * 0.9 + Vector3(0, 0, rng.randfn(0.0, 0.35))
			d.target.y = 0
			d.hurry = 1.0


## The spike meets the block, or not: decided as it is hit, the deflection played when the ball reaches the net.
func _block_at_net(attacker: Player, from: Vector3, v: Vector3, mv: String) -> void:
	var b := block
	block = {}
	if mv == "feint" or b.is_empty():
		return
	var blocker: Player = b.player
	if not b.has("jump_t"):
		return
	var tn := -from.x / v.x if absf(v.x) > 0.01 else -1.0
	if tn <= 0.0:
		return
	var pn := Ball.pos_at(from, v, tn)
	# Timing: the block is up for about a fifth of a second either side of its best moment.
	var tq := clampf(1.0 - absf(float(b.jump_t) - (now + tn)) / 0.3, 0.0, 1.0)
	var bz := blocker.position.z
	var at_net := absf(blocker.position.x) < 1.0
	var covers := at_net and absf(pn.z - bz) < 0.6 and pn.y < arena.net_top + 0.95
	var p_stop := tq * (0.2 + float(blocker.data.get("block", 60)) * 0.0022) - (0.08 if mv == "roll" else 0.0)
	if covers and rng.randf() < p_stop:
		var kill := rng.randf() < 0.22
		var back_v: Vector3
		if kill:
			back_v = Vector3(Court.sgn(attacker.side) * rng.randf_range(3.0, 6.0), rng.randf_range(-1.0, 1.5), rng.randf_range(-1.5, 1.5))
		else:
			back_v = Vector3(Court.sgn(blocker.side) * rng.randf_range(0.8, 2.0), rng.randf_range(3.5, 5.5), rng.randf_range(-1.0, 1.0))
		deflect = {"player": blocker, "v": back_v, "kill": kill}


# ---------------------------------------------------------------- the end of a rally

func _landed(p: Vector3) -> void:
	_whistle("long")   # the rally is over
	var side := Court.side_of(p.x)
	var inside := Court.in_court(p, side)
	var winner_side := 1 - side if inside else (1 - touch_side if touch_side >= 0 else 1 - side)
	# A serve that lands untouched in the court is an ace.
	var server_p := last_toucher
	_why = "in" if inside else "out"
	if _block_kill and inside:
		_why = "block"
	_block_kill = false
	if OS.has_environment("TAKRAW_DEBUG") and not inside and last_toucher:
		print("OUT by %s (%s, left %s) after %s, landed %s" % [String(teams[side_team[last_toucher.side]].short), ["tekong", "feeder", "striker"][last_toucher.role], last_toucher.left_footed(), _last_kind, p])
	if inside and rally_len == 1 and server_p != null and plan.is_empty():
		_why = "ace"
		stats[server_p.data.id].aces += 1
		hud.banner(tr("CALL_ACE"), team_on(server_p.side).c1)
	elif inside and last_toucher and last_toucher.side != side and _attack_kind in ["roll", "sunback", "tapak", "head_spike", "feint"]:
		_why = "kill_" + _attack_kind
		stats[last_toucher.data.id].kills += 1
		hud.banner(tr({"roll": "CALL_ROLL", "sunback": "CALL_SUNBACK", "tapak": "CALL_TAPAK", "head_spike": "CALL_HEADER_SPIKE", "feint": "CALL_FEINT"}[_attack_kind]), team_on(last_toucher.side).c1)
	elif not inside and last_toucher:
		stats[last_toucher.data.id].errors += 1
	# The line judge's call (now and then wrong on a ball within a few centimetres of the line).
	var margin := Court.line_margin(p)
	var close := absf(margin) < 0.06
	var called_in := inside
	if close and rng.randf() < 0.2:
		called_in = not inside
		winner_side = (1 - side) if called_in else (1 - touch_side if touch_side >= 0 else side)
	_judge_signal(p, called_in)
	if not called_in:
		hud.call_line(tr("CALL_OUT"))
	var winner_team: int = side_team[winner_side]
	if close and not bool(config.get("attract", false)):
		Sfx.react("ooh", -8.0)   # (a ball right on the line)
	if close:
		_pending_call = {"winner": winner_team, "p": p, "true_in": inside, "called_in": called_in, "side": side,
			"until": now + 3.5, "true_winner": side_team[(1 - side) if inside else (1 - touch_side if touch_side >= 0 else side)]}
		var loser: int = 1 - winner_team
		if challenges[loser] > 0 and (loser == user_team):
			hud.challenge_prompt(true)
		elif challenges[loser] > 0 and loser != user_team and inside != called_in and rng.randf() < 0.65:
			_schedule_ai_challenge(loser)
	_point(winner_team)


func _schedule_ai_challenge(team: int) -> void:
	await get_tree().create_timer(0.8).timeout
	if not _pending_call.is_empty():
		_challenge(team)


func _fault(fault_side: int, key: String, who: Player, stop_ball := true) -> void:
	_why = key
	if OS.has_environment("TAKRAW_DEBUG"):
		print("FAULT %s after %s" % [key, _last_kind])
	_whistle("short")
	hud.call_line(tr(key))
	if who:
		stats[who.data.id].errors += 1
		if _is_user(who):
			Game.haptic("fault")
	if stop_ball:
		ball.set_loose(now)   # play stops; the ball falls where it was going
	_point(side_team[1 - fault_side])


func _point(team: int) -> void:
	if state == S.DEAD or state == S.OVER:
		return
	plan = {}
	block = {}
	deflect = {}
	input_window = {}
	hud.timing_done()
	_clear_buttons()
	for side in 2:
		for pp in players_on(side):
			(pp as Player).set_selected(false)
	_sched.clear()
	state = S.DEAD
	state_t = 0.0
	net_t = -1.0
	land_t = -1.0
	points[team] += 1
	log.append([rally_len, _why, team, _seq.strip_edges()])
	var why := _why
	_why = ""
	run[team] += 1
	run[1 - team] = 0
	last_point_team = team
	if not bool(config.get("attract", false)):
		# The crowd is the home side's: a cheer for a long rally or a kill, applause for a short one; when their own
		# side gives a point away (out, into the net, a fault) a groan.
		var home := _home_team_index()
		if team != home and not (why.begins_with("kill") or why in ["ace", "block"]):
			Sfx.react("groan", -6.0)
		else:
			Sfx.react("cheer" if rally_len > 3 or _attack_kind != "" else "applause", -4.0 if team == home else -9.0)
	Crowd.set_excite(0.9 if team == _home_team_index() else 0.4)
	if team == user_team:
		Game.haptic("point")
	_celebrate(team, why)
	hud.set_score()
	if _attack_kind in ["roll", "sunback"] or (rally_len > 7):
		_start_replay_after = now + 1.2
		_freeze_at = now + 0.7
	_attack_kind = ""


var _start_replay_after := -1.0
var _freeze_at := -1.0
var _rec_frozen := false


func _home_team_index() -> int:
	return 0


## The point's winners react, and not the same way every time: after a big point (a kill, an ace, a block, a long
## rally, a set or match point won) the regu celebrates together, each his own way; after an ordinary one, now and then
## one player claps or pumps a fist; often nobody does. After a big one, a loser may slump.
func _celebrate(team: int, why: String) -> void:
	var side := side_of_team(team)
	# The referee's arm out to the side that won it (side 0 on his left as he faces along the net).
	if side == 0:
		_officials.show_signal(_ref, {"upperarm_l": Vector3(-10, 0, 80), "forearm_l": Vector3.ZERO}, 1.4)
	else:
		_officials.show_signal(_ref, {"upperarm_r": Vector3(-10, 0, -80), "forearm_r": Vector3.ZERO}, 1.4)
	var big := why.begins_with("kill") or why in ["ace", "block"] or rally_len >= 6 or int(points[team]) >= set_points - 1
	var ways := ["celebrate", "fist", "clap", "point"]
	var mine := players_on(side).duplicate()
	if not big:
		if rng.randf() < 0.45:
			var one: Player = mine[rng.randi_range(0, mine.size() - 1)]
			one.play_now(["fist", "clap", "fist"][rng.randi_range(0, 2)], now + rng.randf_range(0.15, 0.5), rng.randf() < 0.5)
		return
	for pp in mine:
		var pl: Player = pp
		if rng.randf() < 0.85:
			pl.play_now(ways[rng.randi_range(0, ways.size() - 1)], now + rng.randf_range(0.05, 0.45), rng.randf() < 0.5)
	_bench_cheer(team)
	if rng.randf() < 0.4:
		var other := players_on(1 - side)
		var sad: Player = other[rng.randi_range(0, other.size() - 1)]
		sad.play_now("slump", now + 0.3)


func _judge_signal(p: Vector3, called_in: bool) -> void:
	if _judges.is_empty():
		return
	var nearest: RealBody = _judges[0]
	for j in _judges:
		if j.global_position.distance_to(p) < nearest.global_position.distance_to(p):
			nearest = j
	var arm := Moves.static_pose("signal_in" if called_in else "signal_out")
	_officials.show_signal(nearest, {"upperarm_r": arm.upperarm_r, "forearm_r": arm.forearm_r}, 1.6)


## After the point: a set or the match won, the ends changed, or the next serve.
func _after_point() -> void:
	if _start_replay_after > 0.0 and not bool(config.get("attract", false)):
		_start_replay_after = -1.0
		_start_replay()
		return
	var a: int = points[0]
	var b: int = points[1]
	var won := -1
	if (a >= set_points or b >= set_points) and absi(a - b) >= 2:
		won = 0 if a > b else 1
	if a >= set_cap or b >= set_cap:
		won = 0 if a > b else 1
	if won >= 0:
		_set_won(won)
		return
	# The serve alternates every point (ISTAF, since 1 February 2024).
	server = 1 - server
	# The third set: the ends change when a side reaches 8.
	var deciding: bool = sets[0] == sets_to_win - 1 and sets[1] == sets_to_win - 1 and sets_to_win > 1
	if deciding and not ends_changed_mid and (a >= 8 or b >= 8):
		ends_changed_mid = true
		_change_ends()
		hud.banner(tr("CHANGE_ENDS"), Game.C_GOLD)
	Crowd.set_excite(0.0)
	_begin_setup()


func _set_won(team: int) -> void:
	sets[team] += 1
	set_scores.append([points[0], points[1]])
	hud.banner(tr("SET_TO").format({"n": set_no, "t": DB.team_name(String(teams[team].id))}), teams[team].c1)
	_whistle("final" if sets[team] >= sets_to_win else "long")
	Sfx.react("cheer", -2.0)
	if sets[team] >= sets_to_win:
		_finish(team)
		return
	# The next set: the team that received first in this one serves first; the ends change; the challenges are
	# given back.
	set_no += 1
	first_server = 1 - first_server
	server = first_server
	points = [0, 0]
	run = [0, 0]
	challenges = [1, 1]
	ends_changed_mid = false
	_change_ends()
	state = S.BREAK
	state_t = 0.0
	hud.set_break()


## The teams change ends: as on television, the picture cuts away (a quick fade) while they cross, rather than every
## player jumping to the other side in one frame.
func _change_ends() -> void:
	side_team = [side_team[1], side_team[0]]
	_place_sides()
	hud.cut(func():
		_seat_bench()
		for side in 2:
			for pp in players_on(side):
				var pl: Player = pp
				pl.position = pl.target
				pl.vel = Vector3.ZERO
		cam.snap())


func _finish(team: int, wait := 3.0) -> void:
	state = S.OVER
	state_t = 0.0
	Sfx.crowd(0.9)
	Crowd.set_excite(1.0)
	var result := {
		"config": config, "winner": team, "sets": sets.duplicate(), "set_scores": set_scores.duplicate(true),
		"home": String(teams[0].id), "away": String(teams[1].id), "stats": stats.duplicate(true), "user_team": user_team,
		"potm": _player_of_match(team), "log": log.duplicate(true),
	}
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	if not bool(config.get("attract", false)):
		Sfx.crowd(-1.0)
		Sfx.drums(-1.0)
		Sfx.ambience("")
	finished.emit(result)
	if bool(config.get("demo", false)):
		return
	Game.on_match_finished(result)


func _player_of_match(winner: int) -> Dictionary:
	var best := {}
	var best_v := -1.0
	for id in stats:
		var s: Dictionary = stats[id]
		var v := float(s.kills) * 1.0 + float(s.aces) * 1.2 + float(s.blocks) * 1.3 + float(s.digs) * 0.4 - float(s.errors) * 0.5 + (2.0 if int(s.team) == winner else 0.0)
		if v > best_v:
			best_v = v
			best = s.merged({"id": id}, true)
	return best


# ---------------------------------------------------------------- challenges

func challenge_by_user() -> void:
	if _pending_call.is_empty() or challenges[user_team] <= 0:
		return
	_challenge(user_team)


## The video review: the ball's touch of the floor against the line, magnified; the call stands or is reversed. A
## challenge that is upheld is kept.
func _challenge(team: int) -> void:
	var c := _pending_call
	_pending_call = {}
	hud.challenge_prompt(false)
	_review = c.merged({"team": team}, true)
	state = S.REVIEW
	state_t = 0.0
	hud.show_review(c, team)
	_whistle("double")   # play stopped for the review
	Sfx.play("buzzer", -10.0)


func _end_review() -> void:
	var c := _review
	_review = {}
	var right: bool = bool(c.true_in) != bool(c.called_in)
	var team: int = int(c.team)
	if right:
		# The call is reversed: the point goes the other way, and the challenge is kept.
		points[int(c.winner)] -= 1
		points[int(c.true_winner)] += 1
		hud.banner(tr("REVIEW_OVERTURNED"), Game.C_GOOD)
	else:
		challenges[team] -= 1
		hud.banner(tr("REVIEW_STANDS"), Game.C_DANGER)
	hud.hide_review()
	hud.set_score()
	state = S.DEAD
	state_t = DEAD_TIME - 1.0


# ---------------------------------------------------------------- the replay

func _record() -> void:
	if state != S.RALLY and state != S.DEAD and state != S.TOSS:
		return
	var f := {"ball": ball.global_position, "p": []}
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			f.p.append([pl.position, pl.body.rotation.y, pl.body.position.y, pl.body.pose])
	if _rec_frozen:
		return
	_rec.append(f)
	if _rec.size() > 300:
		_rec.pop_front()
	if _freeze_at > 0.0 and now >= _freeze_at:
		_rec_frozen = true
		_freeze_at = -1.0


func _start_replay() -> void:
	if _rec.size() < 60:
		_rec_frozen = false
		_after_point()
		return
	_replay_frames = _rec.slice(maxi(0, _rec.size() - 200), _rec.size())
	_ball_keep = [ball.global_position, ball.vel, ball.loose, ball.flying]
	_rec.clear()
	_rec_frozen = false
	_replay_i = 0.0
	state = S.REPLAY
	hud.replay(true)
	cam.replay_angle(_replay_frames[_replay_frames.size() * 2 / 3].ball)


func _replay_step(delta: float) -> void:
	_replay_i += delta * 60.0 * 0.4
	var i := int(_replay_i)
	if i >= _replay_frames.size():
		end_replay()
		return
	var f: Dictionary = _replay_frames[i]
	if (f.ball as Vector3).distance_to(ball.global_position) > 0.002:
		ball.turn(delta * 0.4)   # (the replay runs at 0.4 of real time)
	ball.global_position = f.ball
	_officials.tick(delta * 0.4, ball.global_position, true)
	_bench.tick(delta * 0.4, ball.global_position, true)
	var k := 0
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			if k < f.p.size():
				var r: Array = f.p[k]
				pl.position = r[0]
				pl.body.rotation.y = r[1]
				pl.body.position.y = r[2]
				pl.body.apply(r[3])
			k += 1
	cam.replay_follow(ball.global_position, delta)
	hud.tick(delta)


func end_replay() -> void:
	if state != S.REPLAY:
		return
	hud.replay(false)
	cam.replay_end()
	if not _ball_keep.is_empty():
		ball.global_position = _ball_keep[0]
		ball.vel = _ball_keep[1]
		ball.loose = _ball_keep[2]
		ball.flying = _ball_keep[3]
		_ball_keep = []
	state = S.DEAD
	state_t = DEAD_TIME
	_after_point()


## The referee's whistle, from his chair (a recording, one of its takes at random): "short" for a serve or a fault,
## "long" for a set's first serve and the end of a rally (indoors the take with a hall's echo), "double" when play
## stops for a review, "final" for the match won. Not in the home screen's match.
func _whistle(kind: String) -> void:
	if bool(config.get("attract", false)):
		return
	var name: String = {"short": "whistle", "long": "whistle_long", "double": "whistle_double", "final": "whistle_final"}[kind]
	if kind == "long" and arena.indoor():
		name = "whistle_gym"
	Sfx.play_at(name, _ref.global_position, -6.0 if kind == "short" else -4.0)


# ---------------------------------------------------------------- your controls

func _user_side() -> int:
	return side_of_team(user_team) if user_team >= 0 else -1


## Yours: on your side, and the one you play as if you play as one player (Settings: Play as).
func _is_user(pl: Player) -> bool:
	if user_team < 0 or pl.side != _user_side():
		return false
	var me := _mine()
	return me == null or pl == me


## The one you play as, or null when the whole side is yours. Doubles has no feeder: its striker sets as well.
func _mine() -> Player:
	var role := int(Game.settings.get("play_as", -1))
	if role < 0 or user_team < 0:
		return null
	var side := _user_side()
	for p in players_on(side):
		if (p as Player).role == role:
			return p
	return _role_player(side, DB.POS_STRIKER)


## The thin ring under the one you play as (none when the whole side is yours).
func _mark_mine() -> void:
	var me := _mine()
	for side in 2:
		for p in players_on(side):
			var pl: Player = p
			if pl.is_mine() != (pl == me):
				pl.set_mine(pl == me)


func _is_opponent(pl: Player) -> bool:
	return user_team >= 0 and pl.side != _user_side()


## Opens the moment you can time a touch: the buttons for it and the ring that closes on the ball.
func _open_window(p: Dictionary, choices: Array) -> void:
	input_window = {"t": p.t, "kind": p.kind, "choices": choices, "player": p.player, "pos": p.pos, "stand": p.get("stand", Vector3.INF)}
	_press = {}
	_last_choice = ""
	controls.set_buttons(choices)
	hud.timing_open(p)
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			pl.set_selected(pl == p.player)


func _choices_for(p: Dictionary) -> Array:
	match String(p.kind):
		"set":
			return ["SET", "QUICK", "ATTACK2"]
		"attack":
			if bool(p.get("from_set", false)):
				return ["SPIKE", "SPIKE2", "FEINT"]
			return ["SPIKE", "FEINT"] if String(p.move) == "head_spike" else ["FEINT"]
		"dig":
			return ["DIG"]
	return ["KICK"]


func _press_choice(id: String) -> bool:
	return String(_last_choice) == id


var _last_choice := ""


func _clear_buttons() -> void:
	if not _block_offered:
		controls.set_buttons([])


## A touch of yours: whoever the ball is coming to is yours to play. With the assist he runs to it himself (the set
## and the spike on Standard, every touch on Full, and a dig, which is a reflex); else you run him there.
func _take_control(p: Dictionary) -> void:
	var a := int(Game.settings.assist)
	var kind := String(p.kind)
	p.auto = a == 2 or kind == "dig" or (a == 1 and (kind == "set" or bool(p.get("from_set", false))))
	var pl: Player = p.player
	if bool(p.auto):
		pl.hurry = 1.0
		pl.target = p.stand
	_open_window(p, _choices_for(p))


func _user_plan_live() -> bool:
	return not plan.is_empty() and bool(plan.get("user", false)) and state in [S.TOSS, S.RALLY]


## How far from the spot he can be and still play it (the length of a leg, more on the easier levels).
func _reach(p: Dictionary) -> float:
	var r: float = 0.5 + [0.3, 0.18, 0.1, 0.04][difficulty]
	return r + (0.4 if bool(p.get("auto", false)) else 0.0)


func _off_spot(p: Dictionary) -> float:
	var pl: Player = p.player
	var st: Vector3 = p.get("stand", pl.position)
	return Vector2(pl.position.x - st.x, pl.position.z - st.z).length()


## The pull toward the spot when you let go of the joystick near it.
func _magnet() -> float:
	return [0.4, 0.6, 1.1][clampi(int(Game.settings.assist), 0, 2)]


## Your press: he starts the move now, so it meets the ball when it arrives (or now, if it already has). Pressed far
## too early it is a stray tap and does not count; a little too early, he kicks before the ball is there.
func _user_press(id: String) -> void:
	var w: Array = timing_windows()
	var err := now - float(plan.t)
	if err < -float(w[2]) - 0.3:
		return
	_last_choice = id
	_press = {"id": id, "t": now}
	plan.press_t = now
	plan.choice = id
	var pl: Player = plan.player
	var mv := String(plan.move)
	if String(plan.kind) == "serve" and id == "HORSE":
		mv = "horse"
	elif String(plan.kind) == "attack" and id == "FEINT":
		mv = "feint"
	elif String(plan.kind) == "attack" and id == "SPIKE2":
		mv = String(plan.get("alt", mv))
	if err < -float(w[2]):
		plan.early = true
		pl.play_now(mv, now, bool(plan.mirror))   # a kick at nothing
		return
	pl.queue_move(mv, maxf(float(plan.t), now) - Moves.contact_time(mv), bool(plan.mirror))
	if _off_spot(plan) <= _reach(plan):
		pl.target = plan.stand   # the last step in
		pl.hurry = 1.0


## Your touch, when its moment comes: made if you pressed in time and he was near enough, missed if not.
func _user_touch_due() -> bool:
	var w: Array = timing_windows()
	if plan.has("press_t"):
		if bool(plan.get("early", false)):
			if now >= float(plan.t):
				_whiff("EARLY")
				return true
			return false
		if now >= maxf(float(plan.t), float(plan.press_t)):
			if _off_spot(plan) > _reach(plan):
				_whiff("MISS")
				return true
			var p := plan
			plan = {}
			_touch(p)
			return true
		return false
	if now > float(plan.t) + float(w[1]) + 0.06:
		_whiff("MISS")
		return true
	return false


## He missed it. The ball goes on: one of yours may still reach it lower down (a second chance, if there is time); a
## missed serve is a fault.
func _whiff(label: String) -> void:
	var p := plan
	plan = {}
	input_window = {}
	hud.timing_done()
	hud.timing_result(label)
	_clear_buttons()
	var pl: Player = p.player
	pl.set_selected(false)
	if OS.has_environment("TAKRAW_DEBUG"):
		print("WHIFF %s %s touch %d move %s off %.2f reach %.2f pressed %s auto %s" % [label, p.kind, int(p.touch), p.move, _off_spot(p), _reach(p), p.has("press_t"), p.get("auto", false)])
	Sfx.voice("hup", -18.0, 0.8)
	if String(p.kind) == "serve":
		state = S.RALLY
		_fault(pl.side, "FAULT_SERVE_MISS", pl, false)   # the thrown ball drops
		return
	var until := float(p.get("until", land_t))
	var pick := _find_touch(int(p.side), int(p.touch), until)
	if pick.is_empty():
		return
	pick.until = until
	plan = pick
	if bool(pick.user):
		_take_control(pick)
		return
	var other: Player = pick.player   # a team-mate's (you play as one player)
	other.hurry = 1.0
	other.target = pick.stand
	other.queue_move(String(pick.move), float(pick.t) - Moves.contact_time(String(pick.move)), bool(pick.mirror))


## The joystick: as seen from the camera, up the screen is away from it.
func _cam_dir(j: Vector2) -> Vector3:
	var right := cam.global_transform.basis.x
	right.y = 0
	var up := -cam.global_transform.basis.z
	up.y = 0
	return right.normalized() * j.x + up.normalized() * (-j.y)


## Running your player: the joystick runs him; let go near the spot and he steps onto it. Wherever he is, the touch is
## re-planned from there (the gold mark moves along under the ball). Before their spike, it slides your blocker along
## the net.
func _user_steer(_dt: float) -> void:
	_offer_block()
	if not _user_plan_live():
		if _block_offered and _joy.length() > 0.15:
			var bp: Player = block.player
			var d := _cam_dir(_joy)
			bp.target = Vector3(bp.target.x, 0, clampf(bp.position.z + d.z * 1.4, -Court.HALF_W + 0.4, Court.HALF_W - 0.4))
			bp.hurry = 1.0
			block.z = bp.target.z
		return
	var pl: Player = plan.player
	if bool(plan.get("auto", false)) or String(plan.kind) == "serve":
		return   # he runs there himself: the joystick aims
	if pl.busy(now):
		return
	if _joy.length() > 0.15:
		pl.target = pl.position + _cam_dir(_joy) * 1.5
		pl.hurry = clampf(_joy.length(), 0.35, 1.0)
	elif _off_spot(plan) <= _magnet():
		pl.target = plan.stand
		pl.hurry = 1.0
	else:
		pl.target = pl.position
	if not plan.has("press_t") and not bool(plan.get("from_set", false)):
		_refit_user_plan()


## The touch re-planned from where your player is: the moment in the ball's flight, and the way to meet it, that he is
## nearest to (and can still get to). A few dozen points of the flight, each frame.
func _refit_user_plan() -> void:
	var pl: Player = plan.player
	var side := pl.side
	var s := Court.sgn(side)
	var touch_no := int(plan.touch)
	var t_end := float(plan.get("until", land_t)) - 0.02
	var mirror := pl.left_footed()
	var speed := 5.2 * (0.82 + float(pl.data.get("agility", 70)) * 0.0028)
	if float(plan.t) - now < 0.35:
		return   # it is nearly there: no changing his mind now
	var ct0 := Moves.contact_time(String(plan.move))
	var d0 := _off_spot(plan)
	var late0 := maxf(0.0, d0 / speed - (float(plan.t) - now - ct0 * 0.5))
	# The touch planned already, scored as the others are: another must be clearly better to take its place (the mark
	# stays put while he runs to it).
	var keep := late0 * 4.0 + d0 * 0.6 + _touch_cost(pl, String(plan.move), touch_no) * 0.3 + (float(plan.t) - now) * 0.03
	var best := {}
	var best_score := keep - 0.35
	var t := now + 0.35
	while t < t_end:
		var p := ball.at(t)
		if p.x * s > 0.05 and absf(p.z) < Court.HALF_W + 1.8:
			for m in _moves_for_height(p.y, touch_no):
				var mv := String(m)
				var stand := Player.stand_for(p, mv, side, mirror)
				if stand.x * s < 0.02:
					continue
				var d := Vector2(stand.x - pl.position.x, stand.z - pl.position.z).length()
				var late := maxf(0.0, d / speed - (t - now - Moves.contact_time(mv) * 0.5))
				var score := late * 4.0 + d * 0.6 + _touch_cost(pl, mv, touch_no) * 0.3 + (t - now) * 0.03
				if score < best_score:
					best_score = score
					best = {"t": t, "pos": p, "move": mv, "stand": stand}
		t += 0.03
	if best.is_empty():
		return
	var kind := _kind_for(String(best.move), touch_no)
	var was := String(plan.kind)
	plan.t = best.t
	plan.pos = best.pos
	plan.move = best.move
	plan.stand = best.stand
	plan.kind = kind
	plan.mirror = mirror
	input_window.t = best.t
	input_window.pos = best.pos
	input_window.stand = best.stand
	input_window.kind = kind
	if kind != was:
		input_window.choices = _choices_for(plan)
		controls.set_buttons(input_window.choices)
	hud.timing_open(plan)


func _on_action(id: String) -> void:
	if paused:
		return
	if id == "CHALLENGE":
		challenge_by_user()
		return
	if state == S.REPLAY:
		end_replay()
		return
	# The block: when the other side is attacking, your striker jumps.
	if id == "BLOCK":
		if not block.is_empty() and bool(block.user) and not block.has("jump_t"):
			var bp: Player = block.player
			bp.play_now("block", now)
			block.jump_t = now + Moves.contact_time("block")
		controls.flash(id)
		return
	if _user_plan_live() and not plan.has("press_t"):
		_user_press(id)
		controls.flash(id)


var _block_offered := false


## The BLOCK button while the other side sets up its attack.
func _offer_block() -> void:
	var want := state == S.RALLY and input_window.is_empty() and not block.is_empty() and bool(block.user) and not block.has("jump_t")
	if want != _block_offered:
		_block_offered = want
		controls.set_buttons(["BLOCK"] if want else [])
		if want:
			hud.timing_open({"t": float(block.t) - Moves.contact_time("block"), "pos": Vector3(0, arena.net_top + 0.6, float(block.z)), "kind": "block"})
		else:
			hud.timing_done()


## How much is riding on the point: set point, match point, a close finish.
func _tension() -> float:
	var hi: int = maxi(points[0], points[1])
	var close := absi(points[0] - points[1]) <= 2
	return clampf(float(hi) / float(set_points) * (1.2 if close else 0.7), 0.0, 1.0)


func set_paused(on: bool) -> void:
	paused = on
	hud.show_pause(on)
	Sfx.pause(on)


func on_back() -> void:
	if hud.settings_open():
		hud.close_settings()
		return
	set_paused(not paused)


## Whether the pause menu offers to simulate the rest: a season's or a tournament's match of yours, not yet over.
func can_sim_to_end() -> bool:
	return String(config.get("mode", "quick")) in ["season", "cup"] and user_team >= 0 and state != S.OVER


## Simulate to the end (the pause menu): the rest of the match played out point by point from the score as it
## stands, from the two sides' ratings, as the matches you don't play are (Sim); then its result, as if played.
func sim_to_end() -> void:
	if not can_sim_to_end():
		return
	set_paused(false)
	state = S.OVER
	var lineups := [teams[0].players.map(func(pl): return pl.data), teams[1].players.map(func(pl): return pl.data)]
	var p_home := Sim.rally_chance(lineups[0], lineups[1])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while true:
		points[Sim.rally(stats, lineups, p_home, rng)] += 1
		var a: int = points[0]
		var b: int = points[1]
		if ((a >= set_points or b >= set_points) and absi(a - b) >= 2) or a >= set_cap or b >= set_cap:
			var won := 0 if a > b else 1
			sets[won] += 1
			set_scores.append([a, b])
			if sets[won] >= sets_to_win:
				hud.set_score()
				_finish.call_deferred(won, 0.0)   # (after the pause menu's button has let go)
				return
			set_no += 1
			points = [0, 0]


func quit_match() -> void:
	Sfx.pause(false)
	Sfx.crowd(-1.0)
	Sfx.drums(-1.0)
	Sfx.ambience("")
	Game.goto_menu()


## Is the match one point from being won by team? (for the HUD: set point, match point)
func set_point_for() -> int:
	for k in 2:
		var a: int = points[k]
		var b: int = points[1 - k]
		if (a + 1 >= set_points and a + 1 - b >= 2) or a + 1 >= set_cap:
			return k
	return -1


func match_point_for() -> int:
	var k := set_point_for()
	if k >= 0 and sets[k] == sets_to_win - 1:
		return k
	return -1


# ---------------------------------------------------------------- frame rate

var _fps_t := 0.0
var _fps_frames := 0
var _fps_checked := false


## Auto graphics (Settings): if the first seconds of play run slowly on this phone, the graphics go down a level for
## good (and the player is told). Not for the match behind the home screen, a test, or a recording.
func _check_frame_rate(real_delta: float) -> void:
	if _fps_checked or user_team < 0 or not bool(Game.settings.get("auto_gfx", true)) or int(Game.settings.graphics) <= Game.GFX_LOW:
		return
	if DisplayServer.get_name() == "headless" or OS.has_feature("movie") or Engine.get_frames_per_second() <= 0:
		return
	if state != S.RALLY and state != S.TOSS:
		return
	_fps_t += real_delta
	_fps_frames += 1
	if _fps_t < 6.0:
		return
	_fps_checked = true
	var fps := float(_fps_frames) / _fps_t
	var cap := Game.frame_cap()
	var want := minf(36.0, 0.8 * float(cap)) if cap > 0 else 36.0
	if fps < want:
		Game.settings.graphics = int(Game.settings.graphics) - 1
		Game.settings.gfx_cap = int(Game.settings.graphics)   # and Auto keeps to it from now on
		Game.save_settings()
		Game.apply_graphics(get_viewport())
		hud.call_line(tr("GFX_LOWERED"))
