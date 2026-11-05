extends Node3D
## A free's strike close up, frame by frame, on the shared foundation (and the game's own body beside it, WSG_OFF=1):
## stills of the whole free_strike from the side, the front and behind, for the end of the swing above all.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/strike_view.tscn -- /out [clip] [t0] [t1] [n] [mirror]

var cams := []
var vps := []
var low := INF


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var act: String = a[1] if a.size() > 1 else "free_strike"
	var t0 := float(a[2]) if a.size() > 2 else 0.0
	var t1 := float(a[3]) if a.size() > 3 else float(Player.ACTIONS[act][0])
	var n := int(a[4]) if a.size() > 4 else 16
	var mirror := float(a[5]) if a.size() > 5 else 1.0
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
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3d7a45")
	ground.material_override = gm
	add_child(ground)
	var t := DB.team("KIL")
	var look := {"skin": Color("e8bc9a"), "jersey": t.c1, "trim": t.c2, "shorts": Color("f6f6f2"), "socks": t.c1, "design": 0, "height": 1.8, "kind": "player"}
	var p := Player.new({"num": 11, "line": 3, "speed": 70}, 0, look)
	add_child(p)
	p.visible_on_screen = true
	# Three views: the side (the camera of a free, behind the taker's right), the front, and the back.
	for v in [Vector3(4.2, 1.2, 0.0), Vector3(0.0, 1.2, 4.2), Vector3(-3.0, 1.6, -3.0)]:
		var vp := SubViewport.new()
		vp.size = Vector2i(420, 560)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.own_world_3d = false
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 42
		vp.add_child(cam)
		cam.look_at_from_position(v, Vector3(0, 0.95, 0))
		vps.append(vp)
		cams.append([cam, v])
	await get_tree().process_frame
	if p.link:
		p.link.body.posed.connect(func():
			var sk: Skeleton3D = p.link.body.skeleton
			low = INF
			for f in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
				low = minf(low, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(f))).origin.y))
	var now := 0.0
	p.play(act, Vector3.ZERO, mirror)
	var strip := Image.create(420 * 3, 560 * n, false, Image.FORMAT_RGB8)
	for i in n:
		var at := lerpf(t0, t1, i / maxf(1.0, n - 1.0))
		# (Played up to it at 60 a second, so the planters and the blends are as in a match.)
		while p.action_t < at - 0.0001 and p.action == act:
			var dt := minf(1.0 / 60.0, at - p.action_t)
			p.action_t += dt
			now += dt
			p.animate(now)
			await get_tree().process_frame
		p.action = act
		p.action_t = at
		p.animate(now)
		await get_tree().process_frame
		# (The cameras follow his hips: the clip carries him a stride or two.)
		var hips: Vector3 = p.link.body.bone_world("Hips").origin if p.link else p.global_position + Vector3(0, 0.95, 0)
		for c in cams:
			(c[0] as Camera3D).look_at_from_position(Vector3(hips.x, 0, hips.z) + c[1], Vector3(hips.x, 1.0, hips.z))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		for k in 3:
			var img: Image = (vps[k] as SubViewport).get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			strip.blit_rect(img, Rect2i(0, 0, 420, 560), Vector2i(420 * k, 560 * i))
		print("frame %d t=%.2f lowest foot joint %.3f m" % [i, at, low])
	strip.save_png(out.path_join("%s_%s.png" % [act, "m" if mirror < 0 else "r"]))
	get_tree().quit()
