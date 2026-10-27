extends Node
## One clip of the trailer, played by the game itself and recorded with Godot's Movie Maker (pictures and the game's
## own sound, frame by frame):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     --write-movie OUT/frame.png res://tools/media/trailer_clip.tscn -- CLIP
## It prints "MARK <name> <frame>" at the moments the cut is made from, and quits when the clip is done.
## tools/media/make_media_kit.sh runs every clip and cuts them together.

func _ready() -> void:
	var clip := String(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else "village"
	Game.main = self
	Game.settings.sound = true
	Game.settings.music = true
	Game.settings.coach = false
	Game.settings.dev = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	TouchControls.key_hints = false
	await Crowd.bake(self)
	match clip:
		"menu":
			Game.goto_menu()
			_mark("start")
			await _frames(30 * 12)
		"ritual":
			var m := _start("stone", "PIS", "VAL", true, Game.CAM_END)
			_mark("start")
			while is_instance_valid(m) and m.in_ritual():
				await _frames(1)
			_mark("end")
		"village", "night", "festival", "stone":
			var homes := {"village": ["ESC", "LLA"], "night": ["FLO", "COP"], "festival": ["SAV", "QUE"], "stone": ["PIS", "VAL"]}
			var m := _start(clip, homes[clip][0], homes[clip][1], false, Game.CAM_END if clip in ["village", "stone"] else Game.CAM_TV)
			await _until(func(): return m.phase == m.P.LIVE, 30 * 30)
			_mark("live")
			# A strike or a dive, then a little after.
			await _until(func(): return _acting(m, [Player.A.STRIKE, Player.A.DIVE]), 30 * 30)
			_mark("action")
			await _frames(30 * 3)
			await _until(func(): return _acting(m, [Player.A.STRIKE, Player.A.DIVE]), 30 * 20)
			_mark("action2")
			await _frames(30 * 3)
		"dive":
			var m := _start("village", "MOR", "CHL", false, Game.CAM_END)
			await _until(func(): return m.phase == m.P.LIVE, 30 * 30)
			await _until(func(): return _acting(m, [Player.A.DIVE]), 30 * 60)
			_mark("dive")
			await _frames(30 * 3)
		"ring":
			var m := _start("stone", "PIS", "VAL", false, Game.CAM_TV)
			await _until(func(): return m.phase == m.P.LIVE, 30 * 30)
			await _frames(30 * 2)
			_mark("strike")
			_ring_shot(m)
			await _until(func(): return m.phase == m.P.REPLAY, 30 * 15)
			_mark("replay")
			# The replay's frame where the ball is nearest the ring.
			var ring: Vector3 = m.court.rings()[1]
			var best := INF
			var at := 0
			while m.phase == m.P.REPLAY:
				await _frames(1)
				var d: float = m.ball.global_position.distance_to(ring)
				if d < best:
					best = d
					at = Engine.get_frames_drawn()
			print("MARK ringpass %d" % at)
			_mark("end")
	get_tree().quit()


func _mark(name: String) -> void:
	# The movie has a picture for every frame drawn since the start.
	print("MARK %s %d" % [name, Engine.get_frames_drawn()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, limit: int) -> void:
	var n := 0
	while not cond.call() and n < limit:
		n += 1
		await get_tree().process_frame


func _start(venue: String, home: String, away: String, ritual: bool, cam: int) -> Node:
	var rules := String(DB.venue(venue).rules)
	Game.settings.camera = cam   # the game's own cameras: the broadcast view or the end view
	Game.start_match({"home": home, "away": away, "venue": venue, "rules": rules, "side": 5 if rules == "ulama" else 3,
		"user_team": -1, "seed": 7, "mode": "watch", "length": 10, "difficulty": 2, "stage": tr("FRIENDLY"), "ritual": ritual})
	return Game.current


func _acting(m: Node, want: Array) -> bool:
	for pl in m.all_players():
		if pl.action in want and pl.action_u() > 0.25 and pl.action_u() < 0.5:
			return true
	return false


## A real flight through the ring, found with the match's own ring shot, struck from where a player stands.
func _ring_shot(m: Node) -> void:
	var p: Player = m.teams[0].players[0]
	var ring: Vector3 = m.court.rings()[1]
	for i in 400:
		var x := randf_range(5.0, 9.0) * (-1.0 if i % 2 == 0 else 1.0)
		var from := Vector3(x, 0.7, ring.z - randf_range(2.5, 4.0))
		p.action = Player.A.STRIKE
		p.action_ring = 1
		var v: Vector3 = m._ring_launch(p, from, 1.0)
		var pr = m._Probe.new()
		pr.pos = from
		pr.vel = v
		var ev := []
		for k in 500:
			pr.pos = Ball.simulate(pr, m.STEP, m.court, "stone", ev)
			if pr.grounded:
				break
		if ev.any(func(e): return e.kind == "ring"):
			p.action = Player.A.NONE
			p.action_ring = 0
			p.global_position = Vector3(from.x, 0.0, from.z - 0.3)
			m.ball.held = false
			m.ball.launch(from, v, p.team, p)
			return
	p.action = Player.A.NONE
	p.action_ring = 0
	push_warning("no ring flight found")
