extends Node
## The trailer's footage, from real matches on High (the HD pack's look), 1920 x 1080 at 30 frames a second: each
## shot plays its match with nothing drawn until its moment comes (a shot at the posts, a catch, a tackle, a goal's
## celebration), then saves every frame for a few seconds as seg_<n>/NNNN.jpg. tools/media/assemble.py cuts them into
## the trailer with its title and end cards and the game's own sounds.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --fixed-fps 30 res://tools/media/trailer.tscn -- <out dir> [0,1,2]
## (Run by tools/media/make_media_kit.sh.) Each shot writes seg_<n>/ and seg_<n>/info.json (its name and frames); the
## numbers, if given, are the only shots made (the CI workflow makes them in parallel jobs).

const SHOTS := [
	# name, the match, the moves that start it, seconds kept, a shot at the posts only (near the goal)
	["final_point", {"home": "COR", "away": "LIM", "venue": "stadium", "seed": 12}, ["strike", "strike_stick"], 4.5, true],
	["floodlit_catch", {"home": "DUB", "away": "WAT", "venue": "night", "seed": 9}, ["catch"], 3.0, false],
	["parish_dusk", {"home": "WEX", "away": "KIL", "venue": "parish", "seed": 3}, ["strike", "strike_stick", "hand_pass"], 3.5, false],
	["tackle", {"home": "TIP", "away": "KIL", "venue": "county", "seed": 21}, ["tackle", "hook", "block"], 3.0, false],
	["county_point", {"home": "GAL", "away": "CLA", "venue": "county", "seed": 7}, ["strike", "strike_stick"], 4.5, true],
	["celebration", {"home": "KIL", "away": "GAL", "venue": "stadium", "seed": 41}, ["celebrate"], 3.0, false],
]

var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.dev = false
	Game.settings.coach = false
	TouchControls.key_hints = false
	var which := range(SHOTS.size())
	if OS.get_cmdline_user_args().size() > 1:
		which = Array(OS.get_cmdline_user_args()[1].split(",")).map(func(x): return int(x))
	for i in which:
		var s: Array = SHOTS[i]
		var n := await _shot(i, s)
		var f := FileAccess.open(out.path_join("seg_%d/info.json" % i), FileAccess.WRITE)
		f.store_string(JSON.stringify({"name": s[0], "frames": n}))
		f.close()
		print("trailer: ", s[0], " ", n, " frames")
	get_tree().quit()


func _shot(i: int, s: Array) -> int:
	var cfg := {"difficulty": 2, "mode": "quick", "user_team": -1, "length": 30}
	cfg.merge(s[1], true)
	Game.start_match(cfg)
	var m: Node = Game.current
	m.controls.visible = false
	var dir := out.path_join("seg_%d" % i)
	DirAccess.make_dir_recursive_absolute(dir)
	RenderingServer.render_loop_enabled = false
	var guard := 0
	var found := false
	while guard < 30 * 240 and not found:
		await get_tree().process_frame
		guard += 1
		if guard < 30 * 6:
			continue
		for p in m.all_players():
			var pl: Player = p
			if pl.action in s[2] and pl.action_t < 0.1 and m.cam.camera.is_position_in_frustum(pl.global_position):
				if s[4] and _to_goal(m, pl) > 45.0:
					continue
				found = true
				break
	RenderingServer.render_loop_enabled = true
	var n := int(float(s[3]) * 30.0)
	for k in n:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(dir.path_join("%04d.jpg" % k), 0.92)
		await get_tree().process_frame
	return n


## How far a man is from the goal line he is shooting at (the one his side attacks this half).
func _to_goal(m: Node, pl: Player) -> float:
	return Pitch.from_goal_line(pl.global_position, m.dir(pl.team))
