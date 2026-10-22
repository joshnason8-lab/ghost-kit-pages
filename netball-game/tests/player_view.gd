extends Node3D
## The players' model up close (game/hero_body.gd), saved as PNGs for checking by eye:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/player_view.tscn -- OUT_DIR [graphics 0-2]
## lineup.png: a player of each of four teams from the front, the back and the side, standing ready, holding the
## ball, catching high (close1.png, close2.png: nearer); run_<speed>.png: one stride pair of the run at walking,
## jogging and sprinting speeds in eight stills, the clips as the match lays them over her pose.

const TEAMS := ["AUS", "ENG", "NZL", "MWI"]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "user://player_view"
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	get_tree().root.size = Vector2i(1920, 1080)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("3b6f8f")
	env.environment = e
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("c9a46c")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34
	# The lineup: four teams, each seen from the front, the back and the side, then holding and catching.
	var ps := []
	var x := -8.4
	for ti in TEAMS.size():
		var sq: Array = DB.squad(TEAMS[ti])
		for v in 4:
			var pl := Player.new(0, sq[(ti * 2 + v) % 7], ToonBody.LETTERS[(ti * 2 + v) % 7])
			add_child(pl)
			pl.position = Vector3(x, 0, 0)
			pl.rotation.y = [0.0, PI, PI * 0.5, 0.3][v]
			x += 1.1
			ps.append(pl)
	await get_tree().process_frame
	for i in ps.size():
		var pl: Player = ps[i]
		var pose: Dictionary = [Poses.ready(0.9), Poses.ready(0.9), Poses.ready(0.9), Poses.hold() if i % 8 == 3 else Poses.catch_(1.0, 1.0)][i % 4]
		pl.body.apply(pose)
	cam.position = Vector3(0, 1.3, 15.5)
	cam.look_at(Vector3(0, 0.95, 0))
	await _shot(out, "lineup")
	for ti in 2:
		cam.position = Vector3(-6.75 + ti * 8.8, 1.1, 4.6)
		cam.look_at(cam.position + Vector3(0, -0.15, -4.6))
		await _shot(out, "close%d" % (ti + 1))
	for pl in ps:
		pl.queue_free()
	# The run: walking (1.4 m/s), jogging (3.5) and sprinting (6.8), one stride pair in eight stills, side on.
	ps = []
	var sq2: Array = DB.squad("ENG")
	for i in 8:
		var pl := Player.new(0, sq2[i % 7], ToonBody.LETTERS[i % 7])
		add_child(pl)
		pl.position = Vector3(-6.3 + i * 1.8, 0, 0)
		pl.rotation.y = PI * 0.5
		ps.append(pl)
	await get_tree().process_frame
	cam.position = Vector3(0, 1.2, 15.0)
	cam.look_at(Vector3(0, 0.8, 0))
	for spd: float in [1.4, 3.5, 6.8]:
		for i in 8:
			var pl: Player = ps[i]
			pl.stride_phase = i / 8.0
			pl.clip_body = 1.0
			pl.clip_arms = 1.0
			pl.body.apply(pl._with_clips(Poses.run(pl.stride_phase, spd), spd))
		await _shot(out, "run_%.1f" % spd)
	get_tree().quit()


func _shot(out: String, name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)
