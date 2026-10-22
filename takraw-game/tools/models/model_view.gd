extends SceneTree
## Renders models side by side, front and side on, to look at (a model before and after prepare_model, say):
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/models/model_view.gd -- OUT.png A.glb [B.glb ...]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b4a6e")
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.environment.ambient_light_energy = 0.7
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var files := a.slice(1)
	var x := -float(files.size() - 1) * 1.1
	for f in files:
		for turn in [0.0, 90.0]:
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(f, st) != OK:
				push_error("can't read " + f)
				continue
			var n: Node3D = doc.generate_scene(st)
			root.add_child(n)
			n.position = Vector3(x, 0, 0)
			n.rotation_degrees.y = turn
			x += 1.1
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.0, 4.2 + files.size() * 0.9)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
