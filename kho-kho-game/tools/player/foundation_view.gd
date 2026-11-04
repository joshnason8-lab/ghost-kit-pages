extends Node
## Stills of an AI match for comparing the shared foundation's bodies (FoundationLink, Medium and High) with the game's
## own, each taken with the match held still at the moment:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/player/foundation_view.tscn -- \
##       OUT_DIR [graphics 0-2] [what: moments|grounds|replay] [venue] [seed] [language]
##   moments: a chaser running (picked by his speed), a defender dodging, a kho (the palm slap), a pole turn, a dive
##            on the ground, a pole dive, the seated chasers, an umpire walking, an umpire's signal, the crowd;
##   grounds: every ground from the broadcast camera and from behind the pole (Low: what the beta draws, to the pixel);
##   replay:  the first replay, late in it (with the foundation), in the language given;
##   signal:  an umpire's signal only.
## Runs on a build without the foundation too (the beta's bodies), so the same moments can be put side by side: the
## match is the same (the foundation draws, it never plays), so the same moment comes at the same point of play.

var m: Node
var cam: Camera3D
var out := "/tmp"
var gfx := 1


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1280, 720)
	gfx = int(a[1]) if a.size() > 1 else Game.GFX_MEDIUM
	var what: String = a[2] if a.size() > 2 else "moments"
	var venue: String = a[3] if a.size() > 3 else "school"
	var seed := int(a[4]) if a.size() > 4 else 12
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.coach = false
	Game.settings.camera = Game.CAM_TV
	Game.settings.graphics = gfx
	Game.set_language(a[5] if a.size() > 5 else "en")
	if what == "grounds":
		for v in DB.venue_ids():
			await _ground(v)
		get_tree().quit()
		return
	_start(venue, seed)
	await _frames(20)
	if what == "replay":
		await _replay_still()
		get_tree().quit()
		return
	if what == "signal":
		var r: Athlete = await _wait(func(q): return q.side < 0 and q.act in ["out", "foul"] and q.act_t > 0.5, 30000)
		if r:
			await _shoot(r, "official_signal", Vector3(3.0, 1.3, 1.6), 1.1, 30.0)
		get_tree().quit()
		return
	await _moments()
	get_tree().quit()


func _start(venue: String, seed: int) -> void:
	Game.start_match({"home": "MAH", "away": "ODI", "venue": venue, "format": KhoRules.CLASSIC, "turn_len": 420.0,
		"user_team": -1, "seed": seed, "mode": "quick", "chase_first": 0})
	m = Game.current
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	add_child(cam)
	for q in m.everyone():
		if q.get("link") != null:
			q.link.measure = true


func _moments() -> void:
	await _wait(func(q): return m.phase == "play" and m.phase_t > 1.0, 3000)
	await _broadcast("crowd")
	var r: Athlete = await _wait(func(q): return m.phase == "play" and q == m.active and q.act == "" and q.vel.length() > 6.2, 6000)
	if r:
		await _shoot(r, "chaser_running", Vector3(0.0, 1.0, 4.2), 0.9, 30.0, true)
		print("chaser_running: %.1f m/s" % r.vel.length())
	await _wait(func(q): return m.phase == "play" and q.act == "sit" and q in m.squares and q != m.active, 600)
	await _seated()
	r = await _wait(func(q): return q.act == "dodge" and q.act_t > q.act_len * 0.4, 20000)
	if r:
		await _shoot(r, "defender_dodging", Vector3(0.0, 1.0, 4.0), 0.9, 30.0, true)
	r = await _wait(func(q): return q.act == "kho" and q.act_t > q.act_len * 0.55, 20000)
	if r:
		await _shoot(r, "kho", Vector3(2.4, 1.1, 2.6), 0.8, 32.0)
		print("kho: on the run %s" % (r.vel.length() > 1.2))
	r = await _wait(func(q): return q.act == "pole_turn" and q.act_t > q.act_len * 0.45, 20000)
	if r:
		await _shoot(r, "pole_turn", Vector3(0.0, 1.2, 4.0), 0.9, 32.0, true)
	r = await _wait(func(q): return q.act == "lie" or q.act == "dive" and q.act_t > q.act_len * 0.9 and not q.mirror, 30000)
	if r:
		await _shoot(r, "dive_ground", Vector3(0.0, 0.9, 3.6), 0.35, 32.0, true)
	r = await _wait(func(q): return q.act == "pole_dive" and q.act_t > q.act_len * 0.75, 30000)
	if r:
		await _shoot(r, "pole_dive", Vector3(0.0, 1.0, 4.0), 0.5, 32.0, true)

	r = await _wait(func(q): return q.side < 0 and q.act == "" and q.vel.length() > 0.8, 9000)
	if r:
		await _shoot(r, "official_walking", Vector3(3.0, 1.2, 1.4), 1.0, 30.0)
	r = await _wait(func(q): return q.side < 0 and q.act in ["out", "foul"] and q.act_t > 0.5, 30000)
	if r:
		await _shoot(r, "official_signal", Vector3(3.0, 1.3, 1.6), 1.1, 30.0)


## The seated chasers down the lane, from the side and a little above.
func _seated() -> void:
	_hold(true)
	var a: Athlete = m.squares[2]
	cam.global_position = a.global_position + Vector3(-2.5, 2.2, 5.0)
	cam.look_at(a.global_position + Vector3(2.5, 0.5, 0.0))
	cam.make_current()
	await _still("seated_chasers")
	m.cam.make_current()
	_hold(false)


## Whom the shot is of, where he is drawn.
func _at(a: Node3D) -> Vector3:
	var l = a.get("link")
	if l != null and l.body != null:
		return l.body.global_position
	return a.global_position


## A still of a, from offset in his own frame (x his left, z ahead) - or from the side (side: the offset in the
## field's frame, on his side of the central lane) - looking at his middle (h).
func _shoot(a: Node3D, still_name: String, offset: Vector3, h: float, fov: float, side := false) -> void:
	_hold(true)
	await _frames(1)
	var p := _at(a)
	var yaw: float = a.get("yaw") if a.get("yaw") != null else 0.0
	var o := Basis(Vector3.UP, yaw) * offset
	if side:
		# (From his side of the lane, so the seated chasers on it are behind him, not in front.)
		o = Vector3(offset.x, offset.y, offset.z * (signf(p.z) if absf(p.z) > 0.4 else 1.0))
	cam.fov = fov
	cam.global_position = p + o
	cam.look_at(p + Vector3(0, h, 0))
	cam.make_current()
	await _still(still_name)
	m.cam.make_current()
	_hold(false)


## The match's own camera (the broadcast camera).
func _broadcast(still_name: String) -> void:
	_hold(true)
	m.cam.make_current()
	await _still(still_name)
	_hold(false)


## Each ground from the broadcast camera and from behind the pole, at the same point of play.
func _ground(v: String) -> void:
	for c in [Game.CAM_TV, Game.CAM_POLE]:
		Game.settings.camera = c
		_start(v, 4)
		await _frames(150)
		_hold(true)
		# (Every clip put at the same point: a man standing at ease starts his idle at a point taken from his object's
		# id, which differs from run to run - two runs of the same build differed there and only there.)
		for q in m.everyone():
			q.body.anim.seek(0.25, true)
		# (And the crowd's bobbing, which runs on the wall clock.)
		for cr in m.find_children("*", "Crowd", true, false):
			cr.process_mode = Node.PROCESS_MODE_DISABLED
			if cr.material_override:
				(cr.material_override as ShaderMaterial).set_shader_parameter("time_s", 10.0)
		m.cam.make_current()
		await _still("ground_%s_%s_g%d" % [v, "tv" if c == Game.CAM_TV else "pole", gfx])
		m.queue_free()
		Game.current = null
		cam.queue_free()
		await _frames(3)
	Game.settings.camera = Game.CAM_TV


## The first replay (with the foundation), late in it.
func _replay_still() -> void:
	if m.get("replay") == null:
		print("replay: none (no foundation here)")
		return
	var n := 0
	while n < 60000 and not (m.replay.playing() and float(m.replay.cur.t) > float(m.replay.cur.t1) - 0.9):
		await get_tree().process_frame
		n += 1
	if m.replay.playing():
		m.paused = true
		await _still("replay_" + TranslationServer.get_locale())
		print("replay: %s" % m.replay.cur.kind)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The match held still: its clock, every player's and official's clips (the foundation's bodies with them).
func _hold(on: bool) -> void:
	m.paused = on
	for a in m.everyone():
		a.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## The first athlete for whom pred holds, within n frames (null if none).
func _wait(pred: Callable, n: int) -> Athlete:
	for i in n:
		for q in m.everyone():
			if pred.call(q):
				return q
		await get_tree().process_frame
	return null


func _still(still_name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, still_name])
	print("still: ", still_name)
