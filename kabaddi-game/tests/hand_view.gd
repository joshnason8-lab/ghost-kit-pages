extends Node3D
## Close-ups of the realistic body's right hand in different states (relaxed, reaching for a touch, gripping
## in a hold, a fist pump), and the arms hanging, for checking the hands and fingers.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 512x512 res://tests/hand_view.tscn -- /out/dir

const CELL := 512


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(light)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	var a := Athlete.new()
	a.setup(DB.team("MUM").squad[0], 0, Color("12a4a7"), Color("f3efe6"), true)
	add_child(a)
	a.facing = Vector3(0, 0, -1)
	# state, celebration, label, camera offset from the right hand
	var shots := [["idle", 0, "relaxed", Vector3(0.35, 0.05, -0.55)], ["idle", 0, "arms", Vector3(0.0, 0.3, -2.4)],
		["holding", 0, "grip", Vector3(0.35, 0.1, -0.55)], ["celebrate", 1, "fist", Vector3(0.35, 0.1, -0.55)]]
	var sheet := Image.create(CELL * shots.size(), CELL, false, Image.FORMAT_RGB8)
	for i in shots.size():
		a.cele_kind = shots[i][1]
		a.set_state(shots[i][0], 1000.0)
		a.st_t = 500.0
		for k in 45:
			await get_tree().process_frame
		var rig: RiggedBody = a.model.rig
		var hand: Vector3 = a.global_position + Vector3(0, 1.0, 0)
		if rig and rig.skeleton and rig._bone.has("hand_r"):
			hand = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(rig._bone["hand_r"]).origin
		var target: Vector3 = hand if shots[i][2] != "arms" else a.global_position + Vector3(0, 1.0, 0)
		cam.position = target + shots[i][3]
		cam.look_at(target)
		for k in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL, CELL)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	sheet.save_png(out + "/hands.png")
	get_tree().quit()
