extends Node3D
## Close-ups of the rigged body in a few poses, for checking the rig.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/rig_view.tscn -- /out/dir

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(l)
	var states := [["raid", 0.0], ["ready", 0.0], ["touch", 0.5], ["kick", 0.5], ["backkick", 0.5], ["dubki", 0.5], ["jump", 0.5], ["dive", 0.9], ["held", 0.5], ["celebrate", 0.5]]
	var athletes := []
	for i in states.size():
		var a := Athlete.new()
		a.setup(DB.team("MUM").squad[i], 0, Color("12a4a7"), Color("f3efe6"), true)
		add_child(a)
		a.position = Vector3((i % 5) * 1.6 - 3.2, 0, (i / 5) * 2.4)
		a.facing = Vector3(0, 0, -1)
		a.kick_back = 1.0
		a.set_state(states[i][0], 1000.0)
		a.st_t = 1000.0 * float(states[i][1])
		athletes.append(a)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	for k in 40:
		await get_tree().process_frame
	for v in [["front", Vector3(0, 2.2, -7.5), Vector3(0, 0.6, 1.2)], ["side", Vector3(7.5, 2.0, 1.2), Vector3(0, 0.6, 1.2)], ["face", Vector3(-3.2, 1.45, -1.3), Vector3(-3.2, 1.35, 0)], ["back", Vector3(-1.6, 1.5, 5.2), Vector3(-1.6, 1.0, 2.4)]]:
		cam.position = v[1]
		cam.look_at(v[2])
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/rig_" + v[0] + ".png")
	get_tree().quit()
