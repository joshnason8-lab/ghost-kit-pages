extends SceneTree
## A clip from the library on a baked character, as a strip of stills (side view), to look at a retarget.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/clip_view.gd -- <char dir> <prefix> <albedo> <out.png> <clip,clip..> [stills]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not WsgClips.available():
		printerr("no clip library (addons/wsg_foundation/data)")
		quit(1)
		return
	var ch := WsgBody.load_character(a[0], a[1])
	var mat := StandardMaterial3D.new()
	if a[2] != "":
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(a[2]))
	var clips: Array = a[4].split(",")
	var n := int(a[5]) if a.size() > 5 else 8
	var cell := Vector2i(220, 330)
	var sheet := Image.create(cell.x * n, cell.y * clips.size(), false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = cell
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var body := WsgBody.new(ch, mat)
	vp.add_child(body)
	var ap := AnimationPlayer.new()
	body.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("mob", WsgClips.library())
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 35
	cam.look_at_from_position(Vector3(3.6, 1.0, 0.4), Vector3(0, 0.85, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 60, 0)
	vp.add_child(l)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.4, 0.25)
	floor.material_override = fm
	vp.add_child(floor)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.36, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	vp.add_child(env)
	for r in clips.size():
		var an: Animation = WsgClips.library().get_animation(clips[r])
		ap.play("mob/" + clips[r])
		ap.pause()
		for i in n:
			ap.seek(an.length * i / float(n), true)
			await process_frame
			await process_frame
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(i * cell.x, r * cell.y))
	sheet.save_png(a[3])
	print("wrote ", a[3])
	quit()
