extends SceneTree
## Renders a baked character in each test pose (front and side) into one contact sheet.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/pose_view.gd -- <char dir> <prefix> <albedo> <out.png> [poses,..] [zoom bone]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var ch := WsgBody.load_character(a[0], a[1])
	var mat := StandardMaterial3D.new()
	if a[2] != "":
		var img := Image.load_from_file(a[2])
		mat.albedo_texture = ImageTexture.create_from_image(img)
	var poses := WsgTestPoses.all()
	var names: Array = a[4].split(",") if a.size() > 4 and a[4] != "" else poses.keys()
	var zoom: String = a[5] if a.size() > 5 else ""
	var vp_size := Vector2i(360, 480)
	var sheet := Image.create(vp_size.x * 2, vp_size.y * names.size(), false, Image.FORMAT_RGBA8)
	for r in names.size():
		for c in 2:
			var vp := SubViewport.new()
			vp.size = vp_size
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.own_world_3d = true
			root.add_child(vp)
			var body := WsgBody.new(ch, mat)
			vp.add_child(body)
			WsgTestPoses.apply(body, poses[names[r]])
			var cam := Camera3D.new()
			vp.add_child(cam)
			var l := DirectionalLight3D.new()
			l.rotation_degrees = Vector3(-35, 25 + c * 90, 0)
			vp.add_child(l)
			var env := WorldEnvironment.new()
			env.environment = Environment.new()
			env.environment.background_mode = Environment.BG_COLOR
			env.environment.background_color = Color(0.32, 0.36, 0.42)
			env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
			vp.add_child(env)
			await process_frame
			await process_frame
			var tgt := Vector3(0, 0.95, 0)
			var dist := 3.0
			if zoom != "":
				tgt = body.bone_world(zoom).origin
				dist = 0.6
			var yaw := deg_to_rad([0.0, 70.0][c]) if zoom == "" else deg_to_rad([0.0, 90.0][c])
			cam.fov = 40
			cam.near = 0.02
			cam.position = tgt + Vector3(sin(yaw), 0.2 if zoom == "" else 0.9, cos(yaw)).normalized() * dist
			cam.look_at(tgt)
			await process_frame
			await process_frame
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, vp_size), Vector2i(c * vp_size.x, r * vp_size.y))
			vp.queue_free()
	sheet.save_png(a[3])
	print("wrote ", a[3], " ", names)
	quit()
