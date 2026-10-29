extends Node3D
## One spectator who faces the rink (+x, the red arrow), seen from eight places round him: he must face along the
## arrow in every picture (the crowd shader's views and mirroring, Crowd.view()).
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/crowd/facing_view.tscn -- out.png graphics
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.settings.graphics = int(a[1])
	get_window().size = Vector2i(600, 600)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.45, 0.5)
	add_child(env)
	# A floor arrow: the rink is toward +x.
	var arrow := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3, 0.02, 0.15)
	arrow.mesh = bm
	arrow.position = Vector3(1.5, 0, 0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color.RED
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = am
	add_child(arrow)
	var c := Crowd.new()
	add_child(c)
	# One person at x = -15 (an end stand); build() faces him toward the rink's middle: +x.
	c.position = Vector3(15, 0, 0)
	c.build([Vector3(-15, 0, 0)], 1.0, [Color.YELLOW], 3, 1.0)
	print("facing turns ", c.facings[0])
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var shots := []
	for ang in [0, 45, 90, 135, 180, 225, 270, 315]:
		var r := deg_to_rad(float(ang))
		cam.position = Vector3(cos(r) * 2.6, 1.3, sin(r) * 2.6)
		cam.look_at(Vector3(0, 0.8, 0))
		for k in 4:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.resize(300, 300)
		shots.append(img)
	var out := Image.create_empty(1200, 600, false, shots[0].get_format())
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(0, 0, 300, 300), Vector2i((i % 4) * 300, (i / 4) * 300))
	out.save_png(a[0])
	get_tree().quit()
