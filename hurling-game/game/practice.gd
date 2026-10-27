extends "res://game/match.gd"
## Free-taking practice: ten frees and 65s at the posts from all round the pitch, near and wide and far, each aimed
## by timing (PlacedAim: the target goes round in front of the goal, SHOOT stops it). Your county's free-taker
## takes them all, their goalkeeper stands in the other goal, the rest of both panels watch from the far end. A point
## over the bar is one, a goal three; the best score is kept (Game.settings.practice_best). Run on the shoot-out's
## loop (the taker walks up, the strike, the ball's end): the match's own rules for the ball, the keeper and the
## posts, with the free's spot, the scoring and the end of the round here.
## (The owner: "Build a mini game that can be played where you can practice your free hits or whatever they are
## called, users might like it.")

const FREES := 10
## The ten spots, in order: metres from the end line, metres across from the middle (to the camera's side or away),
## and the kind (a 65 from the 65 m line). Each moves a little each round.
const SPOTS := [
	[21.0, 0.0, "free"], [30.0, -8.0, "free"], [35.0, 13.0, "free"], [45.0, 0.0, "free"], [38.0, -21.0, "free"],
	[65.0, 16.0, "65"], [50.0, 9.0, "free"], [26.0, 24.0, "free"], [56.0, -14.0, "free"], [65.0, -22.0, "65"],
]
const WALK_T := 2.2          # seconds for the taker to settle over the ball before the target comes up
const DONE_T := 2.6          # the result shown this long before the next free
const FLIGHT_T := 7.0        # a ball still going after this long counts as missed

# {n (frees taken), points, marks (P a point, G a goal, W wide, S short, K saved), spots, kinds, state, t, best}
var practice := {}


func _ready() -> void:
	super()
	coach = null
	controls.show_joystick = false
	user_team = 0
	_set_active(_best_free_taker())
	taker = active
	practice = {"n": 0, "points": 0, "marks": [], "spots": [], "kinds": [], "state": "walk", "t": 0.0,
		"best": int(Game.settings.get("practice_best", -1))}
	for s in SPOTS:
		var d: float = float(s[0]) + (rng.randf_range(-3.0, 3.0) if String(s[2]) == "free" else 0.0)
		var z: float = float(s[1]) + rng.randf_range(-3.0, 3.0)
		practice.spots.append(Vector3((Pitch.HALF_L - d) * dir(0), 0, clampf(z, -Pitch.HALF_W + 4.0, Pitch.HALF_W - 4.0)))
		practice.kinds.append(String(s[2]))
	phase = P.SHOOTOUT
	phase_t = 0.0
	shootout = {"state": "walk"}
	Sfx.crowd(0.1)
	_next_free()
	for pl in all_players():
		(pl as Player).global_position = _shootout_spot(pl)
	hud.practice(practice, true)


func is_practice() -> bool:
	return true


## Your county's free-taker (DB.free_taker: the best at frees).
func _best_free_taker() -> Player:
	var id := String(DB.free_taker(String(config.home)).id)
	for q in teams[0].players:
		if String((q as Player).data.id) == id:
			return q
	return teams[0].players[13]


func _next_free() -> void:
	var i := int(practice.n)
	var spot: Vector3 = practice.spots[i]
	var kind: String = practice.kinds[i]
	ball.place(spot)
	ball.vel = Vector3.ZERO
	ball.state = Sliotar.DEAD
	carrier = null
	restart = {"kind": kind, "team": 0, "spot": spot}
	# He comes in from a few strides back, not from the last spot (forty metres off, a long wait).
	var stand := _shootout_spot(taker)
	var to_goal := Vector3(Pitch.HALF_L * dir(0) - spot.x, 0, -spot.z).normalized()
	taker.global_position = stand - to_goal * 4.0
	taker.vel = Vector3.ZERO
	practice.state = "walk"
	practice.t = now
	shootout.state = "walk"
	hud.practice(practice)
	hud.restart_tag(restart)


## Where everyone stands: the taker a stride behind the ball, looking at the posts; the other side's goalkeeper on
## his line; the rest in two groups at the far 45, watching.
func _shootout_spot(pl: Player) -> Vector3:
	var gx := Pitch.HALF_L * dir(0)
	if pl == taker:
		var spot: Vector3 = restart.get("spot", Vector3.ZERO)
		var to_goal := Vector3(gx - spot.x, 0, -spot.z).normalized()
		return spot - to_goal * 1.1
	if pl == keeper_of(1):
		return Vector3(gx - dir(0) * 0.6, 0, 0)
	var i: int = teams[pl.team].players.find(pl)
	return Vector3(-dir(0) * (Pitch.HALF_L - 45.0 + float(i % 4) * 1.6), 0, (-16.0 if pl.team == 0 else 16.0) + float(i / 4) * 1.8)


func _shootout_step(_dt: float) -> void:
	match String(practice.state):
		"walk":
			var at: bool = taker.global_position.distance_to(_shootout_spot(taker)) < 0.6
			if placed_aim == null and ((at and now - float(practice.t) > WALK_T) or now - float(practice.t) > WALK_T + 4.0):
				taker.global_position = _shootout_spot(taker)
				taker.face_to = Vector3(Pitch.HALF_L * dir(0), 0, 0)
				practice.state = "aim"
				shootout.state = "ready"
				_start_aim(taker)
		"struck":
			if now - float(practice.t) > FLIGHT_T:
				_shootout_result("", ball.global_position)
		"done":
			if now - float(practice.t) > DONE_T:
				if int(practice.n) >= FREES:
					_end_round()
				else:
					_next_free()


func _shootout_strike(_choice: String) -> void:
	practice.state = "struck"
	practice.t = now
	shootout.state = "struck"
	carrier = taker
	ball.state = Sliotar.HELD
	taker.ball_hand = false
	taker.ball_stick = false
	_shoot_at(taker, _aim_point, String(restart.kind))


## The ball's end: over the end line (kind "point", "goal" or "" wide), or caught, stopped or still going ("").
func _shootout_result(kind: String, c: Vector3) -> void:
	if String(practice.get("state", "")) != "struck":
		return
	var over_line := absf(c.x) >= Pitch.HALF_L - 0.5 or absf(c.z) > Pitch.HALF_W
	var saved := bool(practice.get("saved", false))
	practice.saved = false
	var mark := "W" if over_line else ("K" if saved else "S")
	match kind:
		"point":
			mark = "P"
			practice.points += 1
			hud.banner(tr("CALL_POINT"), Game.C_GOLD)
			Sfx.react("cheer", -6.0)
			officials.umpire_signal(signf(c.x), "sig_point", c.z)
		"goal":
			mark = "G"
			practice.points += 3
			hud.banner(tr("CALL_GOAL"), Game.C_GOLD)
			Sfx.react("cheer", -2.0)
			officials.umpire_signal(signf(c.x), "sig_goal", c.z)
		_:
			if over_line:
				hud.banner(tr("CALL_WIDE"), Game.C_INK)
				if absf(c.z) <= Pitch.HALF_W:
					officials.umpire_signal(signf(c.x), "sig_wide", c.z)
			elif saved:
				hud.banner(tr("CALL_SAVED"), Game.C_INK)
			else:
				hud.banner(tr("PRACTICE_SHORT"), Game.C_INK)
			Sfx.react("groan", -8.0)
	(practice.marks as Array).append(mark)
	practice.n += 1
	practice.state = "done"
	practice.t = now
	shootout.state = "done"
	ball.state = Sliotar.DEAD
	ball.vel = Vector3.ZERO
	hud.practice(practice)


## Caught or lifted (the goalkeeper, most often, from a ball dropping under the bar): the free is over.
func _gain(p: Player, kind: String) -> void:
	if phase != P.SHOOTOUT:
		super(p, kind)
		return
	ball.vel = Vector3.ZERO
	practice.saved = p.is_keeper()
	_shootout_result("", ball.global_position)


func _end_round() -> void:
	practice.state = "over"
	phase = P.OVER
	phase_t = 0.0
	var best := int(practice.best)
	var record := int(practice.points) > best
	if record:
		Game.settings.practice_best = int(practice.points)
		Game.save_settings()
	if int(practice.points) > 0:
		taker.play("celebrate")
	hud.practice_done(practice, maxi(best, int(practice.points)), record and best >= 0)


## Back: the pause menu during the round; home from the card at the end of it.
func on_back() -> void:
	if phase == P.OVER:
		quit_match()
		return
	super()


## Go again: a new round at the same ground, the spots moved a little.
func again() -> void:
	var cfg: Dictionary = config.duplicate()
	cfg.seed = rng.randi()
	Game.start_match(cfg)


## Never kept for later: a round is two minutes.
func snapshot() -> Dictionary:
	return {}
