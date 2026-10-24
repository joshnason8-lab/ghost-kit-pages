extends Node3D
## A look at the prepared models (tools/meshy): the man and woman, high and low, posed by their Running clip, and
## the stick, lit like the hall. xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/meshy/view.tscn -- out.png
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/view.png"
	get_window().size = Vector2i(1600, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.86)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	add_child(sun)
	var x := -2.4
	for f in ["man", "man_low", "woman", "woman_low"]:
		var ch: Node3D = (load("res://assets/characters/%s.scn" % f) as PackedScene).instantiate()
		add_child(ch)
		ch.position = Vector3(x, 0, 0)
		var mi: MeshInstance3D = ch.find_children("*", "MeshInstance3D", true, false)[0]
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/characters/%s.jpg" % f.replace("_low", ""))
		mi.material_override = m
		var ap: AnimationPlayer = ch.find_children("*", "AnimationPlayer", true, false)[0] if not ch.find_children("*", "AnimationPlayer", true, false).is_empty() else null
		if ap and f.ends_with("_low"):
			ap.play("Running")
			ap.seek(0.2, true)
			ap.pause()
		x += 1.2
	for k in 2:
		var st := MeshInstance3D.new()
		st.mesh = load("res://assets/characters/%s.res" % ["stick", "stick_plain"][k])
		var sm := StandardMaterial3D.new()
		if k == 0:
			sm.albedo_texture = load("res://assets/characters/stick.jpg")
		st.material_override = sm
		st.position = Vector3(2.6 + k * 1.0, 0.95, 0)
		st.scale = Vector3.ONE * 0.6
		add_child(st)
	var cam := Camera3D.new()
	cam.position = Vector3(0.6, 1.1, 5.2)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0.6, 0.85, 0))
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
