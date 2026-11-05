extends Node3D
## Close-ups of one body (a hurler, or an official with the role given), still, from four sides at head height, and
## whole: for the officials' looks and their flags.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/head_view.tscn -- /out.png [role] [action] [t]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var role: String = a[1] if a.size() > 1 else ""
	var act: String = a[2] if a.size() > 2 else ""
	var at := float(a[3]) if a.size() > 3 else 0.5
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2f5a3a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var p: Player
	if role == "":
		var t := DB.team("KIL")
		p = Player.new({"num": 11, "line": 3, "speed": 70}, 0, {"skin": Color("e8bc9a"), "jersey": t.c1, "trim": t.c2,
			"shorts": Color("f6f6f2"), "socks": t.c1, "design": 0, "height": 1.8, "kind": "player"})
	else:
		var o := Officials.new(self)
		var looks := {}
		p = null
		add_child(o)
		for q in o.people:
			if (q as Player).role == role and p == null:
				p = q
		o.remove_child(p)
		p.position = Vector3.ZERO
		o.queue_free()
	add_child(p)
	p.yaw = 0.0
	p.visible_on_screen = true
	await get_tree().process_frame
	if act != "":
		p.play(act)
	var now := 0.0
	while now < at:
		now += 1.0 / 60.0
		p.action_t = minf(now, at) if act != "" else 0.0
		p.animate(now)
		await get_tree().process_frame
	if OS.has_environment("HV_ONLY") and p.link:
		# One surface only (0 the body, 1 the head), the other in flat red: where each ends.
		var red := StandardMaterial3D.new()
		red.albedo_color = Color.RED
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.link.body.mesh_instance.set_surface_override_material(1 - int(OS.get_environment("HV_ONLY")), red)
	# The right hand, where it is drawn (read when the skeleton has its final pose).
	var hand := [Vector3(-0.5, 1.2, 0), Basis()]
	if p.link:
		p.link.body.posed.connect(func():
			var x: Transform3D = p.link.body.bone_world("RightHand")
			hand[0] = x.origin
			hand[1] = x.basis.orthonormalized())
		now += 1.0 / 60.0
		p.animate(now)
		await get_tree().process_frame
		await get_tree().process_frame
	var hp: Vector3 = hand[0]
	var views := [[Vector3(0, 1.62, 1.1), Vector3(0, 1.62, 0)], [hp + Vector3(0.05, 0.1, 0.5), hp],
		[hp + Vector3(-0.35, 0.15, -0.3), hp], [Vector3(2.6, 1.3, 2.6), Vector3(0, 1.1, 0)],
		[Vector3(-2.6, 1.3, 2.6), Vector3(0, 1.1, 0)], [Vector3(0, 1.3, -3.4), Vector3(0, 1.1, 0)]]
	if OS.has_environment("HV_HAND"):
		# All round the right hand, close.
		views = []
		for k in 6:
			var ang := TAU * k / 6.0
			views.append([hp + Vector3(sin(ang) * 0.32, 0.12 if k % 2 == 0 else -0.12, cos(ang) * 0.32), hp])
	var img := Image.create(360 * 3, 420 * 2, false, Image.FORMAT_RGB8)
	for k in views.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(360, 420)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 38 if k < 3 else 40
		vp.add_child(cam)
		cam.look_at_from_position(views[k][0], views[k][1])
		p.animate(now)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := vp.get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		img.blit_rect(im, Rect2i(0, 0, 360, 420), Vector2i(360 * (k % 3), 420 * (k / 3)))
		vp.queue_free()
	img.save_png(out)
	get_tree().quit()
