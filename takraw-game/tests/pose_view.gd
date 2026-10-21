extends Node3D
## Renders players in key moments of each move, to look at: xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/pose_view.tscn -- out.png

func _ready() -> void:
	var out := "user://poses.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b6cc4")
	add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 9.5)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0))
	var moves := [["", 0.0], ["sila", 0.45], ["serve", 0.55], ["horse", 0.55], ["roll", 0.48], ["roll", 0.66], ["sunback", 0.45], ["block", 0.45], ["dig", 0.38], ["header", 0.45], ["celebrate", 0.25]]
	# A second argument: the celebrations instead (and the player turned to face the camera).
	var front := OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "celebrations"
	if front:
		moves = [["", 0.0], ["celebrate", 0.25], ["fist", 0.5], ["clap", 0.15], ["clap", 0.27], ["point", 0.5], ["slump", 0.6]]
	var x := -7.5 if not front else -4.5
	for m in moves:
		var look := {"jersey": Color("ff8a1f"), "shorts": Color("2a1a0e"), "skin": Color("c98a5a"), "hair_style": randi() % 3}
		var b := ToonBody.new(look)
		add_child(b)
		b.position = Vector3(x, 0, 0)
		b.rotation.y = deg_to_rad(90 if not front else 0)
		var p: Dictionary = Moves.READY if m[0] == "" else Moves.sample(m[0], m[1])
		b.apply(p)
		b.position.y = float(p.get("y", 0.0))
		b.rotation.y += deg_to_rad(float(p.get("yaw", 0.0)))
		x += 1.5
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
