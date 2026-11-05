extends Node3D
## A strip of pictures of a player running at a speed, side on, to look at a gait (motion capture or the code's):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/mocap/gait_view.tscn -- out.png speed [role] [angle]
## angle (degrees) is the way he runs against the way he faces (0 ahead, 90 to his left, 180 backward).
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.settings.graphics = 2
	get_window().size = Vector2i(400, 560)
	var speed := float(a[1]) if a.size() > 1 else 4.0
	var role := a[2] if a.size() > 2 else "F"
	var ang := deg_to_rad(float(a[3])) if a.size() > 3 else 0.0
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.78, 0.8)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.45, 0.6)
	floor_m.material_override = fm
	add_child(floor_m)
	# Marks on the floor every metre, to see the feet against.
	for i in 400:
		var mk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.002, 0.6)
		mk.mesh = bm
		mk.position = Vector3(i - 50, 0.001, 0)
		add_child(mk)
	var p := Player.new({"id": "SWE01", "height": 1.8, "num": 4, "kit": [Color("1d4ed8"), Color("1d4ed8"), Color.WHITE]}, 0, role, 1)
	add_child(p)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.current = true
	var frames: Array[Image] = []
	var dt := 1.0 / 30.0
	var t := 0.0
	var shots := 0
	while shots < 10:
		p.want_vel = Vector2(speed, 0)
		p.want_face = -ang
		p.step(dt)
		t += dt
		cam.global_position = Vector3(p.pos.x, 1.0, p.pos.y + 5.0)
		cam.look_at(Vector3(p.pos.x, 0.85, p.pos.y))
		await get_tree().process_frame
		if t > 3.0:
			await get_tree().process_frame
			frames.append(get_viewport().get_texture().get_image())
			shots += 1
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var strip := Image.create(w * 5, h * 2, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % 5) * w, (i / 5) * h))
	strip.save_png(a[0] if a.size() > 0 else "gait.png")
	get_tree().quit()
