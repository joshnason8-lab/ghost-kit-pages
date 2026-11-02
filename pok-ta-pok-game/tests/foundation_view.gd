extends Node
## Stills of the same seeded moments, in this build or the beta's (it uses only what both have), for comparing the
## shared foundation's bodies with the game's own:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/foundation_view.tscn -- OUT_DIR [graphics] [which]
## which: all (default), or a comma list of: strike, dive, serve, run, gear, judge, offering, crowd, ring, courts,
## spanish. Each AI match is seeded: the game plays it the same in either build, so each still is the same moment.
## The match is held (paused) for each still; a still camera looks at the moment from close by.

var out := ""
var gfx := 1
var which: Array = []
var m: Node
var _shots := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp/fv"
	gfx = int(a[1]) if a.size() > 1 else 1
	which = (a[2] if a.size() > 2 else "all").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = gfx
	Game.settings.coach = false
	# (Not lowered by itself under a software renderer's slow frames: Low samples the recorded serve differently, and
	# the matches would part ways.)
	Game.settings.auto_gfx = false
	Game.set_language("en")
	if _want("strike") or _want("dive") or _want("run") or _want("gear") or _want("judge"):
		await _match_moments("village", "ulama", 9)
	if _want("serve") or _want("gear"):
		await _serve("stone", "classic", 5)
	if _want("offering"):
		await _offering()
	if _want("ring"):
		await _ring()
	if _want("crowd"):
		await _crowd()
	if _want("courts"):
		for v in ["village", "festival", "stone", "night"]:
			await _court(v)
	if _want("spanish"):
		await _spanish()
	if "pixels" in which:
		for v in (["festival"] if "festival_only" in which else ["village", "festival", "stone", "night"]):
			await _court(v, true)
	print("foundation_view: %d stills in %s" % [_shots, out])
	get_tree().quit()


func _want(k: String) -> bool:
	return "all" in which or k in which


func _start(venue: String, rules: String, seed_: int, extra := {}) -> void:
	m = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue,
		"rules": rules, "user_team": -1, "seed": seed_, "length": 4.0, "mode": "test", "difficulty": 2}
	m.config.merge(extra, true)
	add_child(m)
	await get_tree().process_frame


func _end() -> void:
	if is_instance_valid(m):
		m.queue_free()
	m = null
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(name: String, at: Vector3, from: Vector3, fov := 40.0) -> void:
	m.paused = true
	var c := Camera3D.new()
	c.fov = fov
	add_child(c)
	c.global_position = from
	c.look_at(at, Vector3.UP)
	c.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(name)
	c.queue_free()
	if m.cam and m.cam.camera:
		m.cam.camera.current = true
	m.paused = false


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	_shots += 1


## A spot beside a player, his hips at the centre: side metres to his left (negative: right), a little in front.
func _beside(p: Node3D, dist: float, up := 1.0) -> Vector3:
	var yaw: float = p.yaw
	var left := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	return p.global_position + (fwd * 0.8 + left * 0.6).normalized() * dist + Vector3(0, up, 0)


## A rally's moments in a seeded village match: a hip strike and a dive at the moment they meet the ball, a player
## running hard, the gear close up, a judge calling the raya.
func _match_moments(venue: String, rules: String, seed_: int) -> void:
	await _start(venue, rules, seed_)
	var got := {}
	var frames := 0
	while frames < 30 * 240 and got.size() < 6:
		await get_tree().process_frame
		frames += 1
		if m.phase == m.P.OVER:
			break
		for p in m.all_players():
			var pl: Player = p
			if _want("strike") and not got.has("strike") and pl.action == Player.A.STRIKE and pl.hit_done and absf(pl.action_u() - Moves.STRIKE_HIT) < 0.06:
				got["strike"] = true
				await _shot("strike_contact", pl.global_position + Vector3(0, 0.8, 0), _beside(pl, 3.2, 0.9))
				break
			if _want("dive") and not got.has("dive") and pl.action == Player.A.DIVE and pl.hit_done and absf(pl.action_u() - Moves.DIVE_HIT) < 0.08:
				got["dive"] = true
				await _shot("dive_save", pl.global_position + Vector3(0, 0.4, 0), _beside(pl, 3.4, 0.5))
				break
			var sp := Vector2(pl.vel.x, pl.vel.z).length()
			if _want("run") and not got.has("run") and pl.action == Player.A.NONE and sp > 4.6 and frames > 60:
				got["run"] = true
				await _shot("run_fast", pl.global_position + Vector3(0, 0.9, 0), pl.global_position + Vector3(pl.vel.x, 0, pl.vel.z).normalized().rotated(Vector3.UP, 1.2) * 4.0 + Vector3(0, 1.2, 0))
				break
		if _want("gear") and not got.has("gear") and m.phase == m.P.SERVE and m.phase_t > 1.2 and m.server:
			got["gear"] = true
			var sv: Player = m.server
			await _shot("gear_ulama", sv.global_position + Vector3(0, 0.95, 0), _beside(sv, 1.5, 1.05), 38.0)
		if _want("judge") and not got.has("judge") and m.phase == m.P.CALL and m.phase_t > 0.9:
			got["judge"] = true
			var j: Node3D = m.officials.judges[1]
			await _shot("judge_call", j.global_position + Vector3(0, 1.1, 0), j.global_position + j.global_transform.basis.z.normalized() * 4.0 + Vector3(0.8, 1.4, 0), 40.0)
		if not _want("strike"):
			got["strike"] = true
		if not _want("dive"):
			got["dive"] = true
		if not _want("run"):
			got["run"] = true
		if not _want("gear"):
			got["gear"] = true
		if not _want("judge"):
			got["judge"] = true
		if got.size() >= 5 and not got.has("x"):
			got["x"] = true
	await _end()


## The serve's toss on the stone court (the classic kit: the yoke and the knee pad close up too).
func _serve(venue: String, rules: String, seed_: int) -> void:
	await _start(venue, rules, seed_)
	var frames := 0
	var gear_done := false
	while frames < 30 * 30:
		await get_tree().process_frame
		frames += 1
		var sv: Player = m.server
		if sv == null:
			continue
		if _want("gear") and not gear_done and m.phase == m.P.SERVE and m.phase_t > 1.0 and sv.action == Player.A.NONE:
			gear_done = true
			await _shot("gear_classic", sv.global_position + Vector3(0, 0.8, 0), _beside(sv, 1.7, 0.95), 40.0)
		if _want("serve") and sv.action == Player.A.SERVE and sv.action_u() > 0.5:
			await _shot("serve_toss", sv.global_position + Vector3(0, 0.9, 0), _beside(sv, 3.0, 1.0))
			break
	await _end()


## The copal offering before a match on the stone court: arms raised to the smoke.
func _offering() -> void:
	await _start("stone", "classic", 7, {"ritual": true})
	var frames := 0
	while frames < 30 * 60 and m.in_ritual():
		await get_tree().process_frame
		frames += 1
		var best: Player = null
		for p in m.all_players():
			if (p as Player).offering > 0.9:
				best = p
		if best and frames > 30 * 3:
			var e: Node3D = m.ritual.elder
			var mid: Vector3 = (best.global_position + e.global_position) * 0.5
			await _shot("offering", mid + Vector3(0, 1.0, 0), mid + (best.global_position - e.global_position).normalized().rotated(Vector3.UP, PI * 0.5) * 4.5 + Vector3(0, 1.4, 0), 44.0)
			break
	await _end()


## The ring replay (classic court): some play, a ball through the ring given, its replay from under the ring.
func _ring() -> void:
	await _start("stone", "classic", 5)
	var frames := 0
	while frames < 30 * 40 and not (m.phase == m.P.LIVE and m.phase_t > 4.0):
		await get_tree().process_frame
		frames += 1
	m._award(0, "ring", false, null)
	frames = 0
	while frames < 30 * 20 and not (m.phase == m.P.REPLAY and m.phase_t > 2.0):
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("ring_replay")
	await _end()


## The stands at the village court, from the court.
func _crowd() -> void:
	await _start("village", "ulama", 3)
	for i in 40:
		await get_tree().process_frame
	var spots: Array = m.venue.spectator_spots()
	var at: Vector3 = spots[spots.size() / 2] if not spots.is_empty() else Vector3(0, 1, 10)
	await _shot("crowd", at + Vector3(0, 1.0, 0), Vector3(at.x * 0.6, 1.6, at.z * 0.35), 50.0)
	await _end()


## Each court from the broadcast camera, once play is under way. det: the same picture in any run of any build - the
## clocks the crowd's sway and the torches' flicker read held still, and each body dressed in the model its player's
## name picks (the game picks by the body's instance id, which changes run to run): for comparing pixels.
func _court(v: String, det := false) -> void:
	var rules: String = DB.venue(v).rules
	await _start(v, rules, 13)
	var frames := 0
	while frames < 30 * 30 and not (m.phase == m.P.LIVE and m.phase_t > 1.5):
		await get_tree().process_frame
		frames += 1
	m.paused = true
	var c: Camera3D = null
	if det:
		_hold_still()
		for p in m.all_players():
			print("det %s %s: at %s action %d t %.4f phase %.4f frames %d" % [v, p.name, str(p.global_position), p.action, p.action_t, p.phase, frames])
		# (A camera of its own: the broadcast camera's shake reads the wall clock.)
		c = Camera3D.new()
		c.fov = 50.0
		add_child(c)
		c.global_position = Vector3(-3.0, 7.5, 15.0)
		c.look_at(Vector3(0, 0.6, 0), Vector3.UP)
		c.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("court_%s%s" % [v, "_det" if det else ""])
	if c:
		c.queue_free()
	m.paused = false
	await _end()


func _hold_still() -> void:
	var crowd = m.venue.get("crowd")
	if crowd:
		crowd.set_process(false)
		if crowd.material_override:
			(crowd.material_override as ShaderMaterial).set_shader_parameter("time_s", 10.0)
	m.venue.set_process(false)
	m.officials.set_process(false)
	for j in m.officials.judges:
		(j as Body).apply(Moves.judge_idle(0.0))
	for n in m.venue.find_children("*", "OmniLight3D", true, false):
		(n as OmniLight3D).light_energy = 3.0
	for n in m.venue.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.material_override is ShaderMaterial and (gi.material_override as ShaderMaterial).shader.code.contains("time_s"):
			(gi.material_override as ShaderMaterial).set_shader_parameter("time_s", 10.0)
	var people: Array = m.all_players() + []
	for j in m.officials.judges:
		people.append(j)
	for p in people:
		var b: Body = (p as Player).body if p is Player else p
		if b.rigged == null:
			continue
		var kind := String(b.look.get("kind", "ulama"))
		var files: Array = RiggedBody.files_for(kind)
		var f := String(files[absi(hash(String(p.name))) % files.size()][0])
		if f != b.rigged.file:
			b.rigged.free()
			b.rigged = RiggedBody.new()
			b.add_child(b.rigged)
			b.rigged.setup(b, f, b.look)
			b.rigged.follow(b)


## A screen in Spanish (the game's first language): Settings.
func _spanish() -> void:
	Game.set_language("es")
	var s: Node = Game.show_screen("res://ui/settings_screen.gd")
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("spanish_settings")
	if is_instance_valid(s):
		s.queue_free()
	Game.set_language("en")
	await get_tree().process_frame
