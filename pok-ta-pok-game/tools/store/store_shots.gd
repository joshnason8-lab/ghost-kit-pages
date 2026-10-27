extends Node
## Screenshots rendered from the game at 1920 x 1080 on High graphics, with no debug overlays or key hints:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- OUT_DIR [SET] [only]
## SET "store" (the default): the eight store screenshots, matches on each court and four menus, in the listing's
## languages. SET "media": twelve for the media kit, in English: the courts, a dive, the copal offering, a ball sent
## through the ring with its replay and the celebration after, and the menus. tools/store/make_store_graphics.sh and
## tools/media/make_media_kit.sh run this.

var out := "/tmp"

## name, language, what (a court for a match, or a screen's script), its settings, seconds to wait, how to pick the moment
const STORE := [
	["01_village", "es", "match", {"venue": "village", "home": "ESC", "away": "LLA", "cam": Game.CAM_END}, 9.0, "action"],
	["02_stone", "en", "match", {"venue": "stone", "home": "PIS", "away": "VAL", "cam": Game.CAM_END}, 11.0, "action"],
	["03_night", "es", "match", {"venue": "night", "home": "FLO", "away": "COP"}, 13.0, "action"],
	["04_festival", "pt", "match", {"venue": "festival", "home": "SAV", "away": "QUE"}, 10.0, "action"],
	["05_home", "es", "res://ui/main_menu.gd", {}, 4.0, ""],
	["06_setup", "en", "res://ui/quick_setup.gd", {}, 2.0, ""],
	["07_howto", "es", "res://ui/howto_screen.gd", {"tab": 3}, 2.0, ""],
	["08_cup", "fr", "res://ui/cup_screen.gd", {}, 2.0, ""],
]
const MEDIA := [
	["01_village_strike", "en", "match", {"venue": "village", "home": "ESC", "away": "LLA", "cam": Game.CAM_END}, 9.0, "action"],
	["02_festival_crowd", "en", "match", {"venue": "festival", "home": "SAV", "away": "QUE"}, 10.0, "action"],
	["03_stone_court", "en", "match", {"venue": "stone", "home": "PIS", "away": "VAL", "cam": Game.CAM_END}, 11.0, "action"],
	["04_night_torchlight", "en", "match", {"venue": "night", "home": "FLO", "away": "COP"}, 13.0, "action"],
	["05_dive", "en", "match", {"venue": "village", "home": "MOR", "away": "CHL", "cam": Game.CAM_END}, 6.0, "dive"],
	["06_copal_offering", "en", "match", {"venue": "stone", "home": "PIS", "away": "VAL", "ritual": true, "cam": Game.CAM_END}, 4.5, "ritual"],
	["07_ring_shot", "en", "match", {"venue": "stone", "home": "PIS", "away": "VAL"}, 8.0, "ring"],   # also 08 and 09
	["10_home", "en", "res://ui/main_menu.gd", {}, 4.0, ""],
	["11_setup", "en", "res://ui/quick_setup.gd", {}, 2.0, ""],
	["12_cup", "en", "res://ui/cup_screen.gd", {}, 2.0, ""],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = String(args[0]) if args.size() > 0 else "/tmp"
	var which := String(args[1]) if args.size() > 1 else "store"
	var only := String(args[2]) if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.dev = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false   # the software renderer here is slow; keep High for the pictures
	TouchControls.key_hints = false
	get_tree().root.size = Vector2i(1920, 1080)
	await Crowd.bake(self)
	for s in (MEDIA if which == "media" else STORE):
		if only != "" and not String(s[0]).begins_with(only):
			continue
		Game.settings.language = s[1]
		TranslationServer.set_locale(s[1])
		Game._size_theme()
		if s[2] == "match":
			await _match_shot(s)
			continue
		if String(s[2]).ends_with("cup_screen.gd"):
			_cup_under_way()
		Game.show_screen(String(s[2]), s[3])
		await _wait(float(s[4]))
		await _save(String(s[0]))
	Game.delete_cup()
	get_tree().quit()


## Waits, playing on; with draw off, nothing is drawn meanwhile (the game runs many times faster), but the last
## second is, so the picture is of a settled frame.
func _wait(secs: float, draw := true) -> void:
	var n := int(secs * 30.0)
	for i in n:
		RenderingServer.render_loop_enabled = draw or i >= n - 30
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _match_shot(s: Array) -> void:
	var cfg: Dictionary = s[3]
	var rules := String(DB.venue(cfg.venue).rules)
	Game.settings.camera = int(cfg.get("cam", Game.CAM_TV))   # the game's own cameras: the broadcast view or the end view
	Game.start_match({"home": cfg.home, "away": cfg.away, "venue": cfg.venue, "rules": rules,
		"side": 5 if rules == "ulama" else 3, "user_team": -1, "seed": 7, "mode": "watch", "length": 10, "difficulty": 2,
		"stage": tr("FRIENDLY"), "ritual": bool(cfg.get("ritual", false))})
	var m: Node = Game.current
	await _wait(float(s[4]), String(s[5]) == "ritual")
	match String(s[5]):
		"action", "dive":
			# Roll on until someone is mid hip-strike (or mid-dive), for a lively picture.
			var want: Array = [Player.A.DIVE] if s[5] == "dive" else [Player.A.STRIKE, Player.A.DIVE]
			var guard := 0
			while guard < (1200 if s[5] == "dive" else 300):
				guard += 1
				await get_tree().process_frame
				var acting := false
				for pl in m.all_players():
					if pl.action in want and pl.action_u() > 0.3 and pl.action_u() < 0.6:
						acting = true
				if acting:
					break
			await _save(String(s[0]))
		"ritual":
			await _save(String(s[0]))
		"ring":
			await _ring_moment(m)


## A ball struck through the ring (a real flight, found with the match's own ring shot) a minute into a match: the
## replay as it reaches the ring, the replay a moment later, and the celebration after.
func _ring_moment(m: Node) -> void:
	await _wait(60.0, false)
	var guard := 0
	while m.phase != m.P.LIVE and guard < 30 * 40:
		guard += 1
		await get_tree().process_frame
	var p: Player = m.teams[0].players[0]
	var ring: Vector3 = m.court.rings()[1]
	var spot := Vector3.ZERO
	var vel := Vector3.ZERO
	var found := false
	for i in 400:
		var x := (randf_range(5.0, 9.0)) * (-1.0 if i % 2 == 0 else 1.0)
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
			spot = from
			vel = v
			found = true
			break
	p.action = Player.A.NONE
	p.action_ring = 0
	if not found:
		push_warning("no ring flight found")
		return
	p.global_position = Vector3(spot.x, 0.0, spot.z - 0.3)
	m.ball.held = false
	m.ball.launch(spot, vel, p.team, p)
	guard = 0
	while m.phase != m.P.REPLAY and guard < 30 * 15:
		guard += 1
		await get_tree().process_frame
	# In the replay: the frame where the ball is nearest the ring (kept as the replay runs), and one a moment in.
	var best := INF
	var best_img: Image = null
	guard = 0
	while m.phase == m.P.REPLAY and guard < 30 * 20:
		guard += 1
		await RenderingServer.frame_post_draw
		var d: float = m.ball.global_position.distance_to(ring)
		if d < best:
			best = d
			best_img = get_viewport().get_texture().get_image()
		if guard == 30 * 3:
			get_viewport().get_texture().get_image().save_png("%s/08_ring_replay.png" % out)
			print("shot 08_ring_replay")
	if best_img:
		best_img.save_png("%s/07_ring_shot.png" % out)
		print("shot 07_ring_shot (%.2f m from the ring)" % best)
	guard = 0
	while is_instance_valid(m) and Game.current == m and guard < 30 * 40:
		guard += 1
		await get_tree().process_frame
	await _wait(1.5)
	await _save("09_celebration")


## The tournament screen part-way through: the user's first game played and won.
func _cup_under_way() -> void:
	Game.settings.mode = "classic"
	Game.new_cup("PIS")
	var c: Cup = Game.get_cup()
	var f := c.next_fixture()
	var r := Sim.play(String(f.home), String(f.away), c.rules, 3)
	c.record_user_result({"home": f.home, "away": f.away, "winner": 0 if f.home == "PIS" else 1, "count": r.count})
	Game.save_cup()
