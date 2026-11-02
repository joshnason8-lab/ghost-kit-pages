extends Node3D
## The run, frame by frame, for checking by eye that the feet step with the ground (no gliding) and the arms swing
## bent at the elbow: every frame saved as a PNG (OUT/<mode>_NNNN.png) for a contact sheet or a clip (ffmpeg).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/gait_view.tscn -- OUT [graphics 0-2] [mode]
## Modes:
##   strip   a player on a floor marked every 0.5 m, from the side, the camera going with her: she sets off, jogs
##           (3.5 m/s), sprints (6.8), stops; then an umpire jogs her line and stops (umpire_*.png)
##   match   an AI match from the TV camera (5 s)
##   close   an AI match, the camera beside the nearest runner (6 s)

var out := "/tmp/gait_view"
var n := 0
var prefix := "strip"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else out
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_LOW
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	var mode: String = a[2] if a.size() > 2 else "strip"
	get_tree().root.size = Vector2i(1280, 720)
	match mode:
		"strip":
			await _strip()
		"match", "close":
			await _match(mode)
	get_tree().quit()


func _floor() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("3b6f8f")
	env.environment = e
	add_child(env)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 30)
	fm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c9a46c")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.material_override = mat
	fm.position = Vector3(30, 0, 0)
	add_child(fm)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("6e5532")
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(-40, 200):
		var ln := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012 if i % 2 == 0 else 0.006, 0.002, 6.0)
		ln.mesh = bm
		ln.material_override = lm
		ln.position = Vector3(i * 0.5, 0.001, 0)
		add_child(ln)


func _strip() -> void:
	_floor()
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30
	cam.make_current()
	var sq: Array = DB.squad("ENG")
	var pl := Player.new(0, sq[3], "C")
	add_child(pl)
	await get_tree().process_frame
	pl.fenced = false
	pl.place(Vector2.ZERO, PI * 0.5)
	# (The court's x is along the strip; she runs toward +x.)
	var plan := [[0, 3.5], [75, 6.8], [140, 0.0]]
	prefix = "strip"
	for f in 200:
		var spd := 0.0
		for st in plan:
			if f >= int(st[0]):
				spd = float(st[1])
		pl.set_act("run" if spd > 0.0 else "ready")
		pl.want_speed = spd
		pl.target = pl.p + Vector2(20, 0) if spd > 0.0 else pl.p + pl.vel * 0.12
		pl.advance(1.0 / 30.0)
		cam.position = Vector3(pl.position.x, 1.0, 6.5)
		cam.look_at(Vector3(pl.position.x, 0.75, 0))
		await _save()
	pl.queue_free()
	var u := Umpire.new(-1)
	add_child(u)
	await get_tree().process_frame
	u.p = Vector2.ZERO
	u.position = Vector3.ZERO
	prefix = "umpire"
	n = 0
	for f in 150:
		u.pace = Umpire.JOG
		u.target = Vector2(40, 0) if f < 100 else u.p
		u.advance(1.0 / 30.0, u.p + Vector2(0, -10))
		cam.position = Vector3(u.position.x, 1.0, 6.5)
		cam.look_at(Vector3(u.position.x, 0.75, 0))
		await _save()


func _match(mode: String) -> void:
	Game.start_match({"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1, "headless_hud": true, "seed": 5, "quarter": 15})
	var m: Node = Game.current
	RenderingServer.render_loop_enabled = false
	for i in 150:
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	prefix = mode
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 28
	var who: Node3D = null
	for f in (150 if mode == "match" else 180):
		if mode == "close":
			if who == null or who.vel.length() < 1.0 and f % 30 == 0:
				var best := 0.0
				for t in 2:
					for q in m.players[t]:
						if q.vel.length() > best:
							best = q.vel.length()
							who = q
			if who:
				cam.make_current()
				var want: Vector3 = who.global_position + Vector3(0, 1.4, 7.5)
				cam.position = want if f == 0 else cam.position.lerp(want, 0.15)
				cam.look_at(who.global_position + Vector3(0, 0.8, 0))
		await _save()


func _save() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s_%04d.png" % [prefix, n]))
	n += 1
