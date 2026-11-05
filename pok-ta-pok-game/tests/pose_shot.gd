extends Node
## Pictures of the bodies in a pose for looking at (not a test): the ready stance (or another of Moves' poses), from
## the front and the side, the realistic body and the code-built one, and the copal elder.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/pose_shot.tscn -- OUT_PREFIX [GFX] [pose]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp/pose"
	Game.settings.graphics = int(args[1]) if args.size() > 1 else 0
	var pose := String(args[2]) if args.size() > 2 else "stance"
	get_tree().root.size = Vector2i(1600, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fa3b0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 6)
	floor_.mesh = pm
	add_child(floor_)
	var looks := [
		{"kind": "ulama", "skin": Color("a8754f"), "hair": Color("1b1410"), "team": Color("b0302a"), "height": 1.72, "build": 0.5, "seed": 3},
		{"kind": "ulama", "skin": Color("8a5a3a"), "hair": Color("1b1410"), "team": Color("2a5fb0"), "height": 1.68, "build": 0.5, "seed": 3, "rigged": false},
		{"kind": "elder", "skin": Color("7c5236"), "hair": Color("d9d4cc"), "shirt": Color("efe9dc"), "height": 1.62, "build": 0.4},
	]
	var bodies := []
	for i in looks.size():
		var b := Body.new(looks[i])
		add_child(b)
		b.position = Vector3((i - 1) * 1.6, 0, 0)
		bodies.append(b)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	for view in ["front", "side"]:
		for i in bodies.size():
			(bodies[i] as Body).position = Vector3((i - 1) * 1.6, 0, 0) if view == "front" else Vector3(0, 0, (1 - i) * 1.4)
		if view == "front":
			cam.position = Vector3(0, 1.0, 7.5)
			cam.look_at(Vector3(0, 0.85, 0))
		else:
			cam.position = Vector3(7.5, 1.0, 0.0)
			cam.look_at(Vector3(0, 0.85, 0))
		for f in 4:
			for i in bodies.size():
				var p: Dictionary = Callable(Moves, pose).call(1.0) if i < 2 else Moves.blend(Moves.judge_idle(1.0), Moves.run(0.3, 1.2, 0.0), 0.7)
				(bodies[i] as Body).apply(p)
				if (bodies[i] as Body).rigged:
					(bodies[i] as Body).rigged.follow(bodies[i])
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("%s_%s_g%d_%s.jpg" % [out, pose, int(Game.settings.graphics), view], 0.88)
	get_tree().quit()
