extends Node3D
## Renders players in key moments of each move, to look at:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/pose_view.tscn -- out.png [what] [women]
## what: "moves" (the default), "celebrations" (facing the camera), or a move's name (that move through its length,
## side on, the moment the ball is met marked by a ball).

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://poses.png"
	var what := a[1] if a.size() > 1 else "moves"
	var women := a.size() > 2 and a[2] == "women"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b4a6e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.75, 0.82)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 11.0)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))
	var moves := [["", 0.0], ["sila", 0.45], ["serve", -1.0], ["horse", 0.55], ["roll", -1.0], ["sunback", -1.0], ["tapak", -1.0],
		["block", -1.0], ["dig", 0.38], ["header", 0.45], ["thigh", -1.0]]
	var turn := 90.0
	if what == "celebrations":
		moves = [["", 0.0], ["celebrate", 0.25], ["fist", 0.5], ["clap", 0.15], ["clap", 0.27], ["point", 0.5], ["slump", 0.6]]
		turn = 0.0
	elif what != "moves":
		moves = []
		for i in 11:
			moves.append([what, float(i) / 10.0])
	var x := -float(moves.size() - 1) * 0.75
	for m in moves:
		var look := {"jersey": Color("ff8a1f"), "shorts": Color("2a1a0e"), "skin": Color("c98a5a"), "women": women}
		var b := RealBody.new(look)
		add_child(b)
		b.position = Vector3(x, 0, 0)
		b.rotation.y = deg_to_rad(turn)
		var t: float = m[1]
		if t < 0.0:
			t = float(Moves.CONTACT[m[0]][4])
		var p: Dictionary = Moves.READY if m[0] == "" else Moves.sample(m[0], t)
		b.apply(p)
		b.position.y = float(p.get("y", 0.0))
		b.rotation.y += deg_to_rad(float(p.get("yaw", 0.0)))
		if m[0] != "" and Moves.CONTACT.has(m[0]) and absf(t - float(Moves.CONTACT[m[0]][4])) < 0.051:
			# Where the move means to meet the ball.
			var c: Array = Moves.CONTACT[m[0]]
			var ball := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = Ball.RADIUS
			s.height = Ball.RADIUS * 2
			ball.mesh = s
			add_child(ball)
			var f := Vector3(sin(deg_to_rad(turn)), 0, cos(deg_to_rad(turn)))
			var right := Vector3(-f.z, 0, f.x)
			ball.position = Vector3(x, 0, 0) + f * float(c[1]) + right * float(c[2]) + Vector3(0, float(c[0]) - (0.12 if women else 0.0), 0)
		x += 1.5
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
