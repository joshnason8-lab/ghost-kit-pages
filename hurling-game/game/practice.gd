extends "res://game/match.gd"
## Free-taking practice: ten frees and 65s at the posts from all round the pitch, near and wide and far, each aimed
## by timing (PlacedAim: the target goes round in front of the goal, SHOOT stops it, then the bar, SHOOT again).
## Your county's free-taker takes them all, alone on the pitch but for the umpires at the goal (no goalkeeper: the
## owner's "The goalie can be removed"); the camera is low behind him the whole time, cutting to each new spot and
## easing in as he walks up, and stays there while the sliotar flies on over the bar, into the net or wide and lands.
## High graphics while it lasts (the HD pack's hurler if it is here) and the smooth frame rate, whatever Settings
## says: everything is close. A point over the bar is one, a goal three; the best score is kept
## (Game.settings.practice_best). Run on the shoot-out's loop (the taker walks up, the strike, the ball's end): the
## match's own rules for the ball, the posts and the nets, with the free's spot, the scoring and the end of the
## round here.
## (The owner: "Build a mini game that can be played where you can practice your free hits or whatever they are
## called, users might like it.")

const FREES := 10
## The ten spots, in order: metres from the end line, metres across from the middle (to the camera's side or away),
## and the kind (a 65 from the 65 m line). Each moves a little each round.
const SPOTS := [
	[21.0, 0.0, "free"], [30.0, -8.0, "free"], [35.0, 13.0, "free"], [45.0, 0.0, "free"], [38.0, -21.0, "free"],
	[65.0, 16.0, "65"], [50.0, 9.0, "free"], [26.0, 24.0, "free"], [56.0, -14.0, "free"], [65.0, -22.0, "65"],
]
## The post challenges: the third, sixth and ninth frees, the left post, the right post, then either (as the camera
## sees them); hit it and that free is worth two, double a point (the owner: "a hit the pole challenge every few shots
## that can give you double points"; the crossbar was one too, till the owner found the target never really moves
## across it).
const CHALLENGES := {2: "left", 5: "right", 8: ""}
const CHALLENGE_POINTS := 2
const READY_T := 0.6         # seconds in his stance at a new spot before the target comes up
const DONE_T := 2.2          # the result shown this long (the sliotar landing) before the next free
const FLIGHT_T := 5.0        # a ball still going after this long counts as missed

# {n (frees taken), points, marks (P a point, G a goal, W wide, S short, K saved), spots, kinds, state, t, best}
var practice := {}
var view: Camera3D           # the low camera behind the taker, for the whole practice
var _view_to := Transform3D()  # where it eases to as he walks up


## High graphics and the smooth frame rate from before anything is built, for as long as the practice lasts; the
## player's own settings back after it (never saved while it lasts: _save_settings).
func _enter_tree() -> void:
	if not Game.has_meta("practice_gfx"):
		Game.set_meta("practice_gfx", [int(Game.settings.graphics), int(Game.settings.get("fps", Game.FPS_SMOOTH))])
	Game.settings.graphics = Game.GFX_HIGH
	if int(Game.settings.get("fps", Game.FPS_SMOOTH)) == Game.FPS_SAVER:
		Game.settings.fps = Game.FPS_SMOOTH
	Game.apply_frame_rate()


## The look up close, as good as the phone gives: every mesh at full detail at any distance, the textures filtered
## sharp at a low angle, the sun's shadows at four times a phone's usual resolution and soft. Put back when it ends.
func _best_look() -> void:
	var vp := get_viewport()
	vp.mesh_lod_threshold = 0.0
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


func _plain_look() -> void:
	var vp := get_viewport()
	vp.mesh_lod_threshold = float(ProjectSettings.get_setting_with_override("rendering/mesh_lod/lod_change/threshold_pixels"))
	vp.anisotropic_filtering_level = int(ProjectSettings.get_setting_with_override("rendering/textures/default_filters/anisotropic_filtering_level")) as Viewport.AnisotropicFiltering
	RenderingServer.directional_shadow_atlas_set_size(int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/size")), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")) as RenderingServer.ShadowQuality)


func _exit_tree() -> void:
	super()
	_plain_look()
	# Go again: the next round is already in (it keeps High); else the player's own settings back.
	var next: Node = Game.current
	if next != null and next != self and is_instance_valid(next) and next.has_method("is_practice") and next.is_practice():
		return
	_own_settings()
	Game.remove_meta("practice_gfx")
	Game.apply_frame_rate()


func _own_settings() -> void:
	if Game.has_meta("practice_gfx"):
		var keep: Array = Game.get_meta("practice_gfx")
		Game.settings.graphics = int(keep[0])
		Game.settings.fps = int(keep[1])


## Settings saved with the player's own graphics and frame rate in them, not the practice's.
func _save_settings() -> void:
	var g := int(Game.settings.graphics)
	var f := int(Game.settings.fps)
	_own_settings()
	Game.save_settings()
	Game.settings.graphics = g
	Game.settings.fps = f


func _ready() -> void:
	super()
	coach = null
	controls.show_joystick = false
	user_team = 0
	_set_active(_best_free_taker())
	taker = active
	taker.measure_free_bas()
	# Alone on the pitch: the rest of both sides, the referee and the linesmen out of sight (the umpires stay, at the
	# goal, for their flags).
	for q in all_players():
		if q != taker:
			(q as Player).visible = false
			(q as Player).global_position = Vector3(-dir(0) * Pitch.HALF_L, 0, -Pitch.HALF_W - 30.0)
	officials.referee.visible = false
	for l in officials.linesmen:
		(l as Player).visible = false
	view = Camera3D.new()
	add_child(view)
	_best_look()
	practice = {"n": 0, "points": 0, "marks": [], "spots": [], "kinds": [], "state": "ready", "t": 0.0,
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
	# He is there already, side-on over the ball in his stance (no walk up and no putting it down between frees: the
	# owner found it looked bad), and the camera straight behind him.
	_take_stance(taker, spot)
	taker.action_t = 1.0           # in the stance from the first frame, not easing into it
	var stand := taker.global_position
	PlacedAim.low_view(view, spot, stand, dir(0))
	_view_to = view.global_transform
	view.make_current()
	practice.state = "ready"
	practice.t = now
	practice.challenge = String(CHALLENGES.get(i, "-"))
	if practice.challenge == "":
		practice.challenge = "left" if rng.randf() < 0.5 else "right"
	elif practice.challenge == "-":
		practice.challenge = ""
	practice.woodwork = ""
	shootout.state = "walk"
	hud.practice(practice)
	hud.restart_tag(restart)
	if practice.challenge != "":
		hud.banner(tr("PRACTICE_CH_TITLE"), Game.C_GOLD, 3.2)
		hud.call_line(tr("PRACTICE_CH_" + String(practice.challenge).to_upper()))
		Sfx.react("ooh", -10.0)


## Where the taker stands: beside the ball, settled to lift it (Match.free_stand). Everyone else is out of sight,
## where they were put.
func _shootout_spot(pl: Player) -> Vector3:
	if pl == taker:
		return free_stand(restart.get("spot", Vector3.ZERO), 0)
	return pl.global_position


func _aim_view() -> Camera3D:
	return view


## Every free at the one goal, the one your county attacks.
func _shootout_goal_dir() -> float:
	return dir(0)


## Close up, the sliotar nearer its own size (a little larger, to follow in flight).
func _ball_scale() -> float:
	return 1.35


func _aim_challenge() -> String:
	return String(practice.get("challenge", ""))


## The sliotar off the woodwork: which (left or right post, as the camera sees them, or the bar); on the challenge's
## own post, the free is won there and then.
func _woodwork(c: Vector3, post: bool) -> void:
	if String(practice.get("state", "")) != "struck":
		return
	var which := "bar"
	if post:
		which = "right" if c.z * dir(0) > 0.0 else "left"
	practice.woodwork = which
	if which == String(practice.get("challenge", "")):
		_shootout_result("woodwork", c)


## The aim over: the practice's camera stays (the aim used it), no cut to the match's.
func _end_aim() -> void:
	if placed_aim != null:
		placed_aim.queue_free()
		placed_aim = null
	view.make_current()


func _shootout_step(dt: float) -> void:
	match String(practice.state):
		"ready":
			# A beat in his stance at the new spot, then the target comes up.
			if placed_aim == null and now - float(practice.t) > READY_T:
				practice.state = "aim"
				shootout.state = "ready"
				_start_aim(taker)
		"struck":
			_follow_ball(dt)
			if now - float(practice.t) > FLIGHT_T:
				_shootout_result("", ball.global_position)
		"done":
			_follow_ball(dt)
			# The swing through, he settles back into his stance while the ball comes down.
			if taker.action == "":
				taker.play("free_set")
			if now - float(practice.t) > DONE_T:
				if int(practice.n) >= FREES:
					_end_round()
				else:
					_next_free()


## The camera turns to keep a sliotar going out of the picture in it (high over the bar, or wide), smoothly; the next
## free puts it back behind the taker.
func _follow_ball(dt: float) -> void:
	var b := ball.global_position
	if view.is_position_behind(b):
		return
	var vp := get_viewport().get_visible_rect().size
	var sp := view.unproject_position(b) / vp
	var out := maxf(maxf(0.1 - sp.y, sp.y - 0.92), maxf(0.06 - sp.x, sp.x - 0.94))
	if out <= 0.0:
		return
	var fwd := -view.global_transform.basis.z
	var to := (b - view.global_position).normalized()
	var want := fwd.slerp(to, clampf(out * 2.5, 0.0, 1.0))
	view.look_at(view.global_position + fwd.slerp(want, 1.0 - exp(-dt * 4.0)))


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
		"woodwork":
			_cheer(0.9)
			mark = "C"
			over_line = false
			practice.points += CHALLENGE_POINTS
			hud.banner(tr("PRACTICE_CH_HIT"), Game.C_GOLD, 3.0)
			hud.call_line(tr("PRACTICE_CH_HIT_SUB").format({"n": CHALLENGE_POINTS}))
			Sfx.react("cheer", -1.0)
			Game.haptic("score")
		"point":
			_cheer(0.75)
			mark = "P"
			practice.points += 1
			hud.banner(tr("CALL_POINT"), Game.C_GOLD)
			Sfx.react("cheer", -6.0)
			officials.umpire_signal(signf(c.x), "sig_point", c.z)
		"goal":
			_cheer(1.0)
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
	# Over the end line it flies on (over the bar and down behind the goal, or into the net, which takes the pace off
	# it); short or saved it is already down.
	if over_line and absf(c.z) <= Pitch.HALF_W:
		ball.state = Sliotar.OUT
	hud.practice(practice)


## Caught or lifted (the goalkeeper, most often, from a ball dropping under the bar): the free is over.
func _gain(p: Player, kind: String) -> void:
	if phase != P.SHOOTOUT:
		super(p, kind)
		return
	ball.vel = Vector3.ZERO
	practice.saved = p.is_keeper()
	_shootout_result("", ball.global_position)


## The crowd up for a score, and settling again.
func _cheer(k: float) -> void:
	Crowd.set_excite(k)
	_cheer_until = now + 2.4      # (the match's own murmur of anticipation leaves it be till then)


func _end_round() -> void:
	practice.state = "over"
	phase = P.OVER
	phase_t = 0.0
	var best := int(practice.best)
	var record := int(practice.points) > best
	if record:
		Game.settings.practice_best = int(practice.points)
		_save_settings()
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
