extends Node
## Stills of an AI match for comparing the shared foundation's bodies (FoundationLink, Medium and High) with the game's
## own, the same seeded moments on a build without it (the beta) too:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/foundation_view.tscn -- \
##       OUT_DIR [graphics 0-2] [venue] [seed] [only: tv|moves|replay] [language] [event]
## tv: the broadcast picture of the venue (and the crowd's stand, the benches, the officials); moves: the toss and the
## serve's kick, a roll spike, a sunback, a block and a head spike at contact, a player walking between points (picked
## by his speed), a line judge's signal; replay: the next replay (in the language given). Each still is taken with the
## match held at the moment.

var m: Node
var cam: Camera3D
var out := "/tmp"
var got := {}


func _ready() -> void:
	seed(12345)   # (the crowd's and the ball's spin's own randomness: the same picture each run, in both builds)
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_MEDIUM
	var venue: String = a[2] if a.size() > 2 else "national"
	var only: String = a[4] if a.size() > 4 else ""
	var lang: String = a[5] if a.size() > 5 else "en"
	Game.settings.language = lang
	TranslationServer.set_locale(lang)
	Game._size_theme()
	RealBody.warm()
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": venue, "event": a[6] if a.size() > 6 else "regu", "sets": 3,
		"points": 15, "user_team": -1, "demo": true, "seed": int(a[3]) if a.size() > 3 else 77, "mode": "quick"}
	add_child(m)
	cam = Camera3D.new()
	add_child(cam)
	if only in ["", "tv"]:
		await _frames(150)
		_hold(true)
		await _still("tv_%s_%d" % [venue, Game.settings.graphics])
		# (The same without the crowd's cut-outs, which differ from run to run in any build: for comparing builds
		# pixel for pixel.)
		if m.arena.crowd:
			m.arena.crowd.visible = false
			await _still("tvnc_%s_%d" % [venue, Game.settings.graphics])
			m.arena.crowd.visible = true
		if only == "tv":
			await _side_shots(venue)
			get_tree().quit()
			return
	if only in ["", "replay"]:
		await _replay_still(lang)
		if only == "replay":
			get_tree().quit()
			return
	await _moves(only)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hold(on: bool) -> void:
	m.paused = on


func _players() -> Array:
	return m.players_on(0) + m.players_on(1)


## A move's contact passing this frame (or past fraction k of it).
func _at(pl: Player, mv: String, k := -1.0) -> bool:
	if pl.move != mv:
		return false
	var c: Array = Moves.CONTACT.get(mv, [0, 0, 0, Moves.length(mv), 0.5])
	var t: float = (m.now - pl.move_start) / Moves.length(mv)
	return t >= (float(c[4]) if k < 0.0 else k) and t < (float(c[4]) if k < 0.0 else k) + 0.08


## Plays on (nothing drawn: software rendering is slow) until cond(player) holds for someone, then holds the match.
func _wait(cond: Callable, limit: int) -> Player:
	_hold(false)
	RenderingServer.render_loop_enabled = false
	for i in limit:
		await get_tree().process_frame
		if m.state == m.S.REPLAY:
			m.end_replay()
			continue
		if m.state == m.S.OVER:
			break
		for p in _players():
			if cond.call(p):
				_hold(true)
				RenderingServer.render_loop_enabled = true
				return p
	RenderingServer.render_loop_enabled = true
	_hold(true)
	return null


func _moves(only := "") -> void:
	var want := {"toss": "toss", "serve": "serve", "horse": "horse", "roll": "roll", "sunback": "sunback",
		"block": "block", "head_spike": "head_spike"}
	var picked := only.begins_with("moves:") or only == "toss"
	if picked:
		var keep := {}
		for k in (["toss"] if only == "toss" else Array(only.substr(6).split(","))):
			keep[k] = k
		want = keep
	var walked := picked
	var signal_shot := only.begins_with("moves:")
	var guard := 0
	while guard < 40 and (want.size() > 0 or not walked or not signal_shot):
		guard += 1
		var p := await _wait(func(q):
			for k in want:
				if _at(q, want[k]):
					return true
			# Walking between points, at a walk (picked by his speed), on his own.
			if not walked and q.stroll and q.move == "" and q.vel.length() > 1.3 and q.vel.length() < 2.0 and not q.carrying:
				return true
			# A line judge's signal, well under way.
			if not signal_shot and q == _players()[0]:
				for o in m._officials.list:
					if o.judge and o.sig_w > 0.95:
						return true
			return false, 20000)
		if p == null:
			break
		var judge = null
		if not signal_shot:
			for o in m._officials.list:
				if o.judge and o.sig_w > 0.95:
					judge = o
		if judge != null:
			signal_shot = true
			await _shoot_body(judge.body, "judge_signal", 1.2, 30.0)
			print("judge_signal: mode %s" % _mode(judge.body))
		elif p.move != "" and want.values().has(p.move):
			var k: String = p.move
			want.erase(k)
			var fov := 34.0
			var y := 1.3 if k in ["roll", "sunback", "block", "head_spike"] else 1.0
			await _shoot(p, k, y, fov)
			if k == "toss":
				# The server waiting for it (the ball on its way from both hands).
				await _shoot(m._server(), "toss_server", 1.0, 40.0)
		elif not walked:
			walked = true
			await _shoot(p, "walk", 0.95, 30.0, true)
			print("walk: %.2f m/s, mode %s" % [p.vel.length(), _mode(p.body)])
	print("not seen: %s" % [want.keys()])


func _mode(b: RealBody) -> String:
	var l = b.get("link")
	return String(l.mode) if l != null else "(the game's body)"


## From the side of the court (the broadcast's far side), level with him, a little ahead of him.
func _shoot(p: Player, name: String, y: float, fov: float, moving := false) -> void:
	var f := p.net_dir()
	if moving and p.vel.length() > 0.3:
		f = p.vel.normalized()
	var side := Vector3(-f.z, 0, f.x)
	var at := p.global_position
	var from := at + side * 3.6 * signf(side.z if absf(side.z) > 0.1 else 1.0) + f * 1.2 + Vector3.UP * (y + 0.2)
	if name in ["toss", "sunback"]:
		# (From the court's middle: the referee's chair stands behind the thrower at the post.)
		from = at + Vector3(0, y + 0.3, -3.4 * signf(at.z + 0.001)) + f * 1.6
	if moving:
		from = at + side * 3.4 + f * 0.6 + Vector3.UP * (y + 0.15)
	await _shot(from, at + Vector3.UP * y, fov, name)
	print("%s: %s %s, mode %s" % [name, p.data.get("id", "?"), p.move, _mode(p.body)])


func _shoot_body(b: RealBody, name: String, y: float, fov: float) -> void:
	var at := b.global_position
	var f := Vector3(sin(b.rotation.y), 0, cos(b.rotation.y))
	await _shot(at + f * 3.4 + Vector3(-f.z, 0, f.x) * 1.2 + Vector3.UP * (y + 0.2), at + Vector3.UP * y, fov, name)


func _shot(from: Vector3, look: Vector3, fov: float, name: String) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(look)
	cam.make_current()
	m.hud.visible = false
	await _still(name)
	m.hud.visible = true
	m.cam.make_current()


## The officials (the referee in his chair, the assistant, the line judges), the substitutes on their bench, the
## crowd's stand.
func _side_shots(venue: String) -> void:
	var post := Court.HALF_W + Court.POST_OUT
	# From inside the court: the referee in his chair at the near post and a line judge beyond him; the assistant at
	# the far post and the other judge from the other way.
	await _shot(Vector3(3.0, 1.9, -1.2), Vector3(-1.0, 1.2, post + 0.8), 66.0, "officials_" + venue)
	await _shot(Vector3(-2.5, 1.9, 1.2), Vector3(1.5, 1.0, -post - 1.2), 66.0, "officials2_" + venue)
	var bx := Court.sgn(m.side_of_team(0)) * 4.5
	await _shot(Vector3(bx + 1.8, 1.3, post - 0.6), Vector3(bx, 0.75, post + 2.45), 48.0, "subs_" + venue)
	await _shot(Vector3(0, 1.6, 0), Vector3(0, 4.0, -12.0), 70.0, "crowd_" + venue)


func _replay_still(lang: String) -> void:
	_hold(false)
	RenderingServer.render_loop_enabled = false
	var n := 0
	for k in [0.3, 0.45, 0.62]:
		while n < 60000 and not (m.state == m.S.REPLAY and m._replay_i > float(m._replay_frames.size()) * k):
			await get_tree().process_frame
			n += 1
		if m.state != m.S.REPLAY:
			break
		RenderingServer.render_loop_enabled = true
		_hold(true)
		await _still("replay_%s_%d" % [lang, int(k * 100)])
		_hold(false)
		RenderingServer.render_loop_enabled = false
	RenderingServer.render_loop_enabled = true
	print("replay: %s" % [m.replays.back() if m.get("replays") != null and m.replays.size() > 0 else "the game's"])


func _still(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
