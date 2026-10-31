extends Node3D
## A Mixamo clip on the game's skeleton (tools/player), as a strip of eight stills from t0 to t1 seconds:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/clip_view.tscn -- /out clip t0 t1 [turn] [top]
## (turn: the men's turn in radians; top: seen from higher up)
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var clip: String = a[1]
	var t0 := float(a[2])
	var t1 := float(a[3])
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2f5a3a")
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 6.0, 9.0) if a.size() > 5 else Vector3(0, 1.1, 9.0)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 40
	var ps := []
	for i in 8:
		var t := DB.team("COR")
		var look := {"skin": Color("e8bc9a"), "jersey": t.c1, "trim": t.c2, "shorts": Color("f6f6f2"), "socks": t.c1, "design": 0, "height": 1.8, "kind": "player"}
		var p := Player.new({"num": 1, "line": 3, "speed": 70}, 0, look)
		p.position = Vector3(-5.6 + i * 1.6, 0, 0)
		add_child(p)
		ps.append(p)
	await get_tree().process_frame
	for i in 8:
		var p: Player = ps[i]
		p.body.rotation.y = float(a[4]) if a.size() > 4 else 0.0
		var cp := HeroBody.clip_pose(clip, lerpf(t0, t1, i / 7.0))
		var c: Dictionary = HeroBody.data().clips[clip]
		var pose := {"hips_y": cp[1]}
		for j in ToonBody.BONES.size():
			pose[ToonBody.BONES[j][0]] = cp[0][j]
		if c.has("yaw"):
			pose.hips = Quaternion(Vector3.UP, deg_to_rad(float(c.yaw))) * cp[0][0]
		p.body.apply(pose)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % clip))
	get_tree().quit()
