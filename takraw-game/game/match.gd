extends Node3D
## A match, to the ISTAF laws as they stand (docs/TAKRAW.md): rally point, sets to 15 (from 14-all, win by two, up
## to 17) or the old 21 (to 25), best of three or one set; the serve alternating every point; ends changed after each
## set and at 8 in the third; three touches a side; one time-out and one video challenge a side a set.
##
## Every touch is planned. The ball flies under gravity alone (Ball), so the moment a ball is kicked the side it is
## going to knows where it can be met: who gets there, with which part of the body (a sila kick, the thigh, the chest,
## the head, a diving instep), and when; that player runs to the spot and starts his move so his foot meets the ball.
## The touch's quality, from the player's ratings (and, for yours, your timing), decides how good the pass, set or
## spike is. Blocks and digs are planned the same way against a spike.

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
var timeouts := [1, 1]
var challenges := [1, 1]
var serving_streak := 0      # the serving team's run of points (for the call-outs)
var last_point_team := -1
var run := [0, 0]            # each team's run of points in a row

# The rally.
var state := S.INTRO
var state_t := 0.0
var now := 0.0               # match time (the sim's own clock: slow motion slows it)
var time_scale := 1.0
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

# The replay: frames of the last few seconds.
var _rec: Array = []
var _replay_i := 0.0
var _replay_frames: Array = []

var officials: Array[ToonBody] = []
var _ref: ToonBody
var _judges: Array[ToonBody] = []


func _ready() -> void:
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	women = bool(config.get("women", false))
	event = String(config.get("event", "regu"))
	n_players = {"regu": 3, "quadrant": 4, "doubles": 2, "team": 3}.get(event, 3)
	user_team = int(config.get("user_team", 0))
	sets_to_win = 2 if int(config.get("sets", 3)) >= 3 else 1
	set_points = int(config.get("points", 15))
	set_cap = 17 if set_points == 15 else 25
	var venue := String(config.get("venue", "national"))
	var home_t := DB.team(String(config.home))
	arena = Arena.new(venue, women, [home_t.get("c1", Game.C_SAFFRON), home_t.get("c2", Color.WHITE)])
	add_child(arena)
	ball = Ball.new()
	add_child(ball)
	ball.hold(Vector3(0, -5, 0))
	# Your team on the left of the broadcast picture (side 1, x > 0: the camera looks across from the far side).
	if user_team == 0:
		side_team = [1, 0]
	_make_teams()
	_make_officials()
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
		hud.intro(_intro_text())
	else:
		Sfx.crowd(0.15)


func _intro_text() -> String:
	var stage := String(config.get("stage", ""))
	var ev := tr({"regu": "EVENT_REGU", "quadrant": "EVENT_QUADRANT", "doubles": "EVENT_DOUBLES", "team": "EVENT_TEAM"}[event])
	if women:
		ev = tr("WOMENS_EVENT").format({"e": ev})
	return ("%s · %s" % [stage, ev]) if stage != "" else ev


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
				"trim": c2 if c2.get_luminance() > 0.5 else Color.WHITE, "shoe": Color("f3efe6"), "hair": Color("15100c"),
				"band": c2, "hair_style": int(pd.get("hair_style", 0)), "height": float(pd.get("height", 1.76)), "women": women}
			var p := Player.new(pd, 0, roles[i] if i < roles.size() else DB.POS_STRIKER, look)
			p.slot = i
			add_child(p)
			team.players.append(p)
			stats[pd.id] = {"kills": 0, "aces": 0, "blocks": 0, "digs": 0, "errors": 0, "serves": 0, "name": pd.short, "num": pd.num, "team": k}
		teams.append(team)
	_place_sides()
	for k in 2:
		for p in teams[k].players:
			var pl: Player = p
			pl.position = pl.target
	_update_tags()


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
	var look := {"jersey": Color("f3efe6"), "shorts": Color("1a1a1a"), "skin": Color("c98a5a"), "trim": Color("1a1a1a"), "band": Color("f3efe6"), "hair_style": 1, "shoe": Color("1a1a1a")}
	_ref = ToonBody.new(look)
	add_child(_ref)
	_ref.position = Vector3(0, 0.8, post_z + 0.82)
	_ref.rotation.y = PI
	officials.append(_ref)
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var spots := [Vector3(-0.9, 0, -post_z - 1.6)]   # the assistant referee, at the near post (off the middle of the picture)
	spots.append_array([Vector3(-Court.HALF - 0.8, 0, Court.HALF_W + 0.8), Vector3(Court.HALF + 0.8, 0, -Court.HALF_W - 0.8)])
	if not low:
		spots.append_array([Vector3(-Court.HALF - 0.8, 0, -Court.HALF_W - 0.8), Vector3(Court.HALF + 0.8, 0, Court.HALF_W + 0.8)])
	for i in spots.size():
		var b := ToonBody.new(look.merged({"skin": [Color("e0b48c"), Color("b07448"), Color("8d5a36")][i % 3]}, true))
		add_child(b)
		b.position = spots[i]
		b.rotation.y = atan2(-spots[i].x, -spots[i].z)
		officials.append(b)
		if i > 0:
			_judges.append(b)
	for o in officials:
		o.apply(Moves.READY)
	_ref.apply(Moves.static_pose("sit"))
	# Line judges sit on low chairs at the corners, as they do; each with its chair.
	var g := Geo.new()
	for j in _judges:
		j.apply(Moves.static_pose("sit"))
		var back := -Vector3(sin(j.rotation.y), 0, cos(j.rotation.y)) * 0.18
		g.box(j.position + back + Vector3(0, 0.22, 0), Vector3(0.42, 0.44, 0.42), Color("2b3c55"), j.rotation.y)
	add_child(g.commit(Geo.material(true)))


# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	if paused:
		return
	if state == S.REPLAY:
		_replay_step(delta)
		return
	var ts := time_scale
	if _slowmo_until > 0.0 and now < _slowmo_until:
		ts = 0.35
	var dt := delta * ts
	now += dt
	state_t += dt
	_step(dt)
	for side in 2:
		for p in players_on(side):
			var pl: Player = p
			pl.look_at_pos = ball.global_position
			pl.tick(dt, now)
	ball.update_to(now, dt)
	cam.follow(ball.global_position, delta, self)
	hud.tick(delta)
	_record()
	if controls.visible:
		_joy = controls.joystick
		_user_steer(dt)


func _step(_dt: float) -> void:
	match state:
		S.INTRO:
			if state_t > 2.6:
				_begin_setup()
		S.SETUP:
			if state_t > SETUP_TIME:
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
			pl.hurry = 0.3
			pl.target = _serve_spot(pl, side, serving)


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
	net_t = -1.0
	land_t = -1.0
	ball.flying = false
	_setup_positions()
	var thrower := _thrower()
	ball.hold(thrower.position + thrower.net_dir() * 0.25 + Vector3(0, 1.0, 0))
	hud.set_score()
	_update_tags()
	if not _intro_done:
		_intro_done = true
	hud.call_line(_score_call())
	if not bool(config.get("attract", false)):
		Sfx.crowd(arena.atmosphere() * (0.45 + _tension() * 0.5))


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


func _begin_toss() -> void:
	state = S.TOSS
	state_t = 0.0
	Sfx.play("whistle", -8.0)
	var thrower := _thrower()
	var srv := _server()
	srv.hurry = 0.0
	srv.position = srv.target
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
	var hand := thrower.position + thrower.net_dir() * 0.0 + Vector3(0, 1.05, 0)
	if thrower == srv:
		hand = srv.target + srv.net_dir() * 0.3 + Vector3(0, 1.1, 0)
	var sol := Ball.solve_apex(hand, kp, kp.y + (0.9 if thrower != srv else 0.6))
	var t_kick := t_release + float(sol[1])
	ball.hold(hand)
	_schedule(t_release, func(): ball.launch(hand, sol[0], t_release))
	plan = {"player": srv, "kind": "serve", "move": mv, "t": t_kick, "pos": kp, "touch": 0, "mirror": mirror,
		"user": _is_user(srv), "side": srv.side, "started": false}
	srv.queue_move(mv, t_kick - Moves.contact_time(mv), mirror)
	if plan.user:
		_open_window(plan, ["SERVE", "HORSE"])
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
	# The planned touch.
	if not plan.is_empty() and now >= float(plan.t):
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
		if int(Game.settings.assist) == 0:
			# You ran him yourself: the further from the spot, the worse the touch.
			var off := Vector2(pl.position.x - Vector3(p.stand).x, pl.position.z - Vector3(p.stand).z).length()
			if off > 0.9:
				return 0.02
			base *= clampf(1.15 - off, 0.25, 1.0)
		return clampf(base, 0.0, 1.0)
	var diff: float = [0.8, 0.9, 0.97, 1.03][int(config.get("difficulty", Game.settings.difficulty))] if _is_opponent(pl) else 0.94
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


## Your timing: how close your press was to the moment the ball arrived. No press: a weak touch, kinder on Rookie.
func _timing_quality(p: Dictionary) -> float:
	if int(Game.settings.assist) == 2 and _press.is_empty():
		return 0.78
	if _press.is_empty():
		return [0.42, 0.3, 0.2, 0.12][int(Game.settings.difficulty)]
	var err := absf(float(_press.t) - float(p.t))
	var w: Array = timing_windows()
	var label := "LATE" if float(_press.t) > float(p.t) else "EARLY"
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
	return [[0.09, 0.2, 0.34], [0.07, 0.16, 0.28], [0.055, 0.13, 0.23], [0.045, 0.11, 0.19]][int(Game.settings.difficulty)]


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
	# Servers miss now and then: long, wide, or into the net (the horse kick more often).
	if not _is_user(pl) and rng.randf() < (0.05 if not horse else 0.09) + (1.0 - q) * 0.08:
		var so := Court.sgn(opp)
		match rng.randi_range(0, 2):
			0:
				target.x = so * (Court.HALF + rng.randf_range(0.2, 1.0))
			1:
				target.z = signf(target.z if target.z != 0.0 else 1.0) * (Court.HALF_W + rng.randf_range(0.2, 0.8))
			_:
				q = 0.0   # into the net, below
	target.y = Ball.RADIUS
	var v: Vector3
	if horse:
		v = _drive(from, target, lerpf(11.0, 16.5, q), 0.25)
	else:
		var sol := Ball.solve_apex(from, target, lerpf(2.4, 3.1, rng.randf()) + (0.4 if q < 0.4 else 0.0))
		v = sol[0]
	# A poor serve catches the net: it is struck too flat to clear the tape.
	if q < 0.22 and rng.randf() < 0.55:
		v = Ball.solve_apex(from, target, arena.net_top - 0.15)[0]
	Sfx.play("kick", -2.0, 1.1 if horse else 1.0)
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
	# Deep corners, or at the receiver who passes worst.
	var weakest: Player = null
	for p in players_on(opp):
		var o: Player = p
		if weakest == null or float(o.data.receive) < float(weakest.data.receive):
			weakest = o
	if rng.randf() < 0.4 and weakest:
		return Vector3(weakest.position.x, 0, weakest.position.z) + Vector3(Court.sgn(opp) * 0.6, 0, rng.randf_range(-1.0, 1.0))
	return Court.spot(opp, rng.randf_range(4.5, 6.1), rng.randf_range(-2.4, 2.4))


## A first touch: to the feeder's spot by the net (a dig: up in the air near the digger, for anyone to set).
func _pass(pl: Player, from: Vector3, q: float, kind: String) -> void:
	var side := pl.side
	if kind == "dig":
		stats[pl.data.id].digs += 1
	var setter := _role_player(side, DB.POS_FEEDER if n_players != 2 else DB.POS_TEKONG)
	if setter == pl and n_players > 2:
		setter = _role_player(side, DB.POS_TEKONG)
	var spot := Court.spot(side, 1.3, _lane(setter) * 1.1 if setter.role == DB.POS_FEEDER else 0.6)
	var apex := lerpf(2.6, 3.6, rng.randf())
	if kind == "dig":
		spot = Vector3(pl.position.x, 0, pl.position.z).lerp(spot, 0.45)
		apex = lerpf(2.6, 4.2, q)
	if q < 0.14:
		# A shank: off the body anywhere.
		Sfx.play("knee", -4.0)
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
	Sfx.play("kick" if String(_last_move(pl)) in ["sila", "kuda", "dig"] else "knee", -4.0)
	_launch(from, sol[0], side, false)
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
	Sfx.play("kick", -6.0, 1.05)
	_set_for = {"player": striker, "move": spike_move}
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
	var risk: float = {"roll": 0.13, "sunback": 0.1, "tapak": 0.08, "head_spike": 0.07}.get(mv, 0.0) + (1.0 - q) * 0.2
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
	Sfx.play("spike" if mv != "feint" else "kick", 0.0 if mv != "feint" else -6.0)
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
	var right := cam.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var up := -cam.global_transform.basis.z
	up.y = 0
	up = up.normalized()
	var d := right * j.x + up * (-j.y)
	var t := base + d * reach
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
	Sfx.play("kick", -4.0)
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
		Sfx.play("block", 0.0)
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
		Sfx.play("net", -2.0)
		var v := ball.vel
		var back := Vector3(-v.x * 0.18, maxf(0.4, absf(v.y) * 0.15), v.z * 0.4)
		ball.launch(Vector3(Court.sgn(from_side) * 0.09, p.y, p.z), back, t)
		land_t = ball.when_height(Ball.RADIUS)
		net_t = -1.0
		if String(_attack_kind) != "" and touches >= 3:
			pass
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
	plan = pick
	var pl: Player = pick.player
	if String(pick.kind) == "attack":
		_prepare_block(pick)
	pl.hurry = 1.0
	pl.target = pick.stand
	pl.queue_move(String(pick.move), float(pick.t) - Moves.contact_time(String(pick.move)), bool(pick.mirror))
	if bool(pick.user):
		_open_window(pick, _choices_for(pick))


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
						"aim": aim}
		_set_for = {}
	var best := {}
	var best_cost := 99.0
	var t := t0
	while t < t_end:
		var p := ball.at(t)
		if p.x * s > 0.05 and absf(p.z) < Court.HALF_W + 1.8 and p.x * s < Court.HALF + 2.0:
			for m in _moves_for_height(p.y, touch_no):
				var mv := String(m)
				for pp in players_on(side):
					var pl: Player = pp
					var mirror := pl.left_footed()
					var stand := Player.stand_for(p, mv, side, mirror)
					if stand.x * s < 0.02:
						continue
					var react := 0.22 - float(pl.data.get("agility", 70)) * 0.0012
					var hard := _attack_kind in ["roll", "sunback", "tapak", "head_spike", "horse"] and touch_no == 1
					if hard:
						# Against a spike: a good defender reads it off the striker's approach and is moving as it is hit.
						react = 0.12 - float(pl.data.get("receive", 60)) * 0.0022
					var dist := Vector2(stand.x - pl.position.x, stand.z - pl.position.z).length()
					var speed := 5.2 * (0.82 + float(pl.data.get("agility", 70)) * 0.0028)
					var need := react + dist / speed
					var have := t - now - Moves.contact_time(mv) * (0.6 if not hard else 0.15)
					if hard and dist < 1.1 and t - now > 0.06:
						need = minf(need, 0.04 + dist * 0.12)   # it comes at him: a reflex touch, foot, chest or thigh
					if need > have:
						continue
					var cost := _touch_cost(pl, mv, touch_no) + (t - now) * 0.05 + dist * 0.04
					if cost < best_cost:
						best_cost = cost
						var kind := "receive"
						if touch_no == 2:
							kind = "set"
						elif touch_no == 3:
							kind = "attack" if mv in ["roll", "sunback", "tapak", "head_spike", "feint"] else "over"
						elif mv == "dig":
							kind = "dig"
						var ease := 1.0
						if mv == "dig":
							ease = 0.8
						if touch_no == 1 and _attack_kind in ["roll", "sunback", "horse"]:
							ease *= 0.78 if dist > 0.5 else 0.88
						best = {"player": pl, "kind": kind, "move": mv, "t": t, "pos": p, "stand": stand, "touch": touch_no,
							"mirror": mirror, "user": _is_user(pl), "side": side, "ease": ease, "alt": "sunback"}
			if not best.is_empty() and best_cost < 0.6:
				break
		t += 0.04
	return best


## Ways to meet a ball at height h, for the touch it is (the third touch, near the net and high enough, a spike).
func _moves_for_height(h: float, touch_no: int) -> Array:
	var out := []
	if touch_no == 3 and h > 1.9:
		out.append("head_spike")
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


## Against a spike coming (planned at the set): the defending side's striker goes up to the net in front of where it
## will be hit and jumps as it is. Yours jumps when you press BLOCK.
func _prepare_block(atk: Dictionary) -> void:
	block = {}
	var def_side := 1 - int(atk.side)
	var blocker := _role_player(def_side, DB.POS_STRIKER)
	var cp: Vector3 = atk.pos
	var spot := Court.spot(def_side, 0.42, 0.0)
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
	elif int(Game.settings.assist) == 2:
		blocker.queue_move("block", float(atk.t) - Moves.contact_time("block"))
		block.jump_t = float(atk.t) + 0.04


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
	if bool(b.user) and not b.has("jump_t"):
		if not _press.is_empty() and String(_press.id) == "BLOCK":
			b.jump_t = float(_press.t) + Moves.contact_time("block")
			_press = {}
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
		var kill := rng.randf() < 0.45
		var back_v: Vector3
		if kill:
			back_v = Vector3(Court.sgn(attacker.side) * rng.randf_range(3.0, 6.0), rng.randf_range(-1.0, 1.5), rng.randf_range(-1.5, 1.5))
		else:
			back_v = Vector3(Court.sgn(blocker.side) * rng.randf_range(0.8, 2.0), rng.randf_range(3.5, 5.5), rng.randf_range(-1.0, 1.0))
		deflect = {"player": blocker, "v": back_v, "kill": kill}


# ---------------------------------------------------------------- the end of a rally

func _landed(p: Vector3) -> void:
	Sfx.play("bounce", -2.0)
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


func _fault(fault_side: int, key: String, who: Player) -> void:
	_why = key
	if OS.has_environment("TAKRAW_DEBUG"):
		print("FAULT %s after %s" % [key, _last_kind])
	Sfx.play("whistle", -6.0)
	hud.call_line(tr(key))
	if who:
		stats[who.data.id].errors += 1
		if _is_user(who):
			Game.haptic("fault")
	ball.flying = false
	_point(side_team[1 - fault_side])


func _point(team: int) -> void:
	if state == S.DEAD or state == S.OVER:
		return
	plan = {}
	block = {}
	deflect = {}
	input_window = {}
	hud.timing_done()
	_sched.clear()
	state = S.DEAD
	state_t = 0.0
	net_t = -1.0
	land_t = -1.0
	points[team] += 1
	log.append([rally_len, _why, team])
	_why = ""
	run[team] += 1
	run[1 - team] = 0
	last_point_team = team
	if not bool(config.get("attract", false)):
		Sfx.react("cheer" if rally_len > 3 or _attack_kind != "" else "applause", -4.0 if team == _home_team_index() else -9.0)
	Crowd.set_excite(0.9 if team == _home_team_index() else 0.4)
	if team == user_team:
		Game.haptic("point")
	_celebrate(team)
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


func _celebrate(team: int) -> void:
	var side := side_of_team(team)
	var k := 0
	for pp in players_on(side):
		var pl: Player = pp
		pl.play_now(["celebrate", "fist", "celebrate"][(k + rng.randi_range(0, 2)) % 3], now + rng.randf_range(0.1, 0.4))
		k += 1
	if rng.randf() < 0.5:
		var other := players_on(1 - side)
		var sad: Player = other[rng.randi_range(0, other.size() - 1)]
		sad.play_now("slump", now + 0.3)


func _judge_signal(p: Vector3, called_in: bool) -> void:
	if _judges.is_empty():
		return
	var nearest: ToonBody = _judges[0]
	for j in _judges:
		if j.global_position.distance_to(p) < nearest.global_position.distance_to(p):
			nearest = j
	var sig := Moves.static_pose("sit")
	var arm := Moves.static_pose("signal_in" if called_in else "signal_out")
	sig.upperarm_r = arm.upperarm_r
	sig.forearm_r = arm.forearm_r
	nearest.apply(sig)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(nearest):
		nearest.apply(Moves.static_pose("sit"))


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
	# The AI calls its time-out when it is behind and the other side is on a run.
	for k in 2:
		if k != user_team and timeouts[k] > 0 and run[1 - k] >= 4 and points[k] < points[1 - k]:
			timeouts[k] -= 1
			run[1 - k] = 0
			hud.banner(tr("TIMEOUT_CALLED").format({"t": DB.team_name(String(teams[k].id))}), teams[k].c1)
			state = S.BREAK
			state_t = BREAK_TIME - 3.0
			return
	Crowd.set_excite(0.0)
	_begin_setup()


func _set_won(team: int) -> void:
	sets[team] += 1
	set_scores.append([points[0], points[1]])
	hud.banner(tr("SET_TO").format({"n": set_no, "t": DB.team_name(String(teams[team].id))}), teams[team].c1)
	Sfx.play("whistle_long", -4.0)
	Sfx.react("cheer", -2.0)
	if sets[team] >= sets_to_win:
		_finish(team)
		return
	# The next set: the team that received first in this one serves first; the ends change; time-outs and
	# challenges are given back.
	set_no += 1
	first_server = 1 - first_server
	server = first_server
	points = [0, 0]
	run = [0, 0]
	timeouts = [1, 1]
	challenges = [1, 1]
	ends_changed_mid = false
	_change_ends()
	state = S.BREAK
	state_t = 0.0
	hud.set_break()


func _change_ends() -> void:
	side_team = [side_team[1], side_team[0]]
	_place_sides()
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			pl.position = pl.target
	_update_tags()


func _finish(team: int) -> void:
	state = S.OVER
	state_t = 0.0
	Sfx.crowd(0.9)
	Crowd.set_excite(1.0)
	var result := {
		"config": config, "winner": team, "sets": sets.duplicate(), "set_scores": set_scores.duplicate(true),
		"home": String(teams[0].id), "away": String(teams[1].id), "stats": stats.duplicate(true), "user_team": user_team,
		"potm": _player_of_match(team), "log": log.duplicate(true),
	}
	await get_tree().create_timer(3.0).timeout
	if not bool(config.get("attract", false)):
		Sfx.crowd(-1.0)
		Sfx.drums(-1.0)
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
	ball.global_position = f.ball
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
	state = S.DEAD
	state_t = DEAD_TIME
	_after_point()


# ---------------------------------------------------------------- your controls

func _user_side() -> int:
	return side_of_team(user_team) if user_team >= 0 else -1


func _is_user(pl: Player) -> bool:
	return user_team >= 0 and pl.side == _user_side()


func _is_opponent(pl: Player) -> bool:
	return user_team >= 0 and pl.side != _user_side()


## Opens the moment you can time a touch: the buttons for it and the ring that closes on the ball.
func _open_window(p: Dictionary, choices: Array) -> void:
	input_window = {"t": p.t, "kind": p.kind, "choices": choices, "player": p.player, "pos": p.pos}
	_press = {}
	_last_choice = ""
	controls.set_buttons(choices)
	hud.timing_open(p)
	if bool(config.get("training", false)):
		hud.call_line(tr("HINT_" + String(p.kind).to_upper()))
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			pl.set_selected(pl == p.player)


func _choices_for(p: Dictionary) -> Array:
	match String(p.kind):
		"set":
			return ["SET", "QUICK", "ATTACK2"]
		"attack":
			var alt := "SPIKE2"
			return ["SPIKE", alt, "FEINT"]
		"dig":
			return ["DIG"]
	return ["KICK"]


func _press_choice(id: String) -> bool:
	return String(_last_choice) == id


var _last_choice := ""


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
		_press = {"id": id, "t": now}
		if not block.is_empty() and bool(block.user) and not block.has("jump_t"):
			var bp: Player = block.player
			bp.play_now("block", now)
			block.jump_t = now + Moves.contact_time("block")
			_press = {}
		controls.flash(id)
		return
	if input_window.is_empty():
		return
	_last_choice = id
	_press = {"id": id, "t": now}
	controls.flash(id)


## With the assist off you run your player yourself; with it on, the joystick only aims.
func _user_steer(dt: float) -> void:
	if int(Game.settings.assist) != 0 or input_window.is_empty():
		_offer_block()
		return
	var pl: Player = input_window.player
	if _joy.length() > 0.15:
		var right := cam.global_transform.basis.x
		right.y = 0
		var up := -cam.global_transform.basis.z
		up.y = 0
		var d := (right.normalized() * _joy.x + up.normalized() * (-_joy.y))
		pl.target = pl.position + d * 2.0
		pl.hurry = clampf(_joy.length(), 0.3, 1.0)
	elif pl.position.distance_to(pl.target) < 0.05:
		pl.target = pl.position
	_offer_block()


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


## The player tags: your player's name, the server's, numbers on the rest (Settings).
func _update_tags() -> void:
	var mode := int(Game.settings.tags)
	for side in 2:
		for pp in players_on(side):
			var pl: Player = pp
			var name := "%d %s" % [int(pl.data.num), String(pl.data.short)]
			var mine := _is_user(pl)
			if mode == 2:
				pl.set_tag("")
			elif mode == 1:
				pl.set_tag(name, mine)
			else:
				pl.set_tag(name if (mine and pl.role == DB.POS_TEKONG) or pl == _server() else str(int(pl.data.num)), mine)


## How much is riding on the point: set point, match point, a close finish.
func _tension() -> float:
	var hi: int = maxi(points[0], points[1])
	var close := absi(points[0] - points[1]) <= 2
	return clampf(float(hi) / float(set_points) * (1.2 if close else 0.7), 0.0, 1.0)


func set_paused(on: bool) -> void:
	paused = on
	hud.show_pause(on)


func on_back() -> void:
	set_paused(not paused)


func quit_match() -> void:
	Sfx.crowd(-1.0)
	Sfx.drums(-1.0)
	Game.goto_menu()


## The user's time-out (the pause menu).
func call_timeout() -> void:
	if user_team < 0 or timeouts[user_team] <= 0 or (state != S.DEAD and state != S.SETUP):
		return
	timeouts[user_team] -= 1
	run = [0, 0]
	hud.banner(tr("TIMEOUT_CALLED").format({"t": DB.team_name(String(teams[user_team].id))}), teams[user_team].c1)
	state = S.BREAK
	state_t = BREAK_TIME - 3.0
	set_paused(false)


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
