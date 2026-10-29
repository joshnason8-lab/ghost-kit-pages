extends Node3D
## One chaser running, diving, lying and getting up, filmed from the side frame by frame, with the numbers that say
## whether it is right (tests/dive_view.tscn):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/dive_view.tscn -- OUT [every]
## OUT/dive_NNN.png every few frames, and per frame: hips height, lowest point, pitch, speed, act.

var a: Athlete
var cam: Camera3D
var out := ""
var every := 3
var f := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://dive_view"
	every = int(args[1]) if args.size() > 1 else 3
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(960, 540)
	Game.settings.graphics = Game.GFX_LOW if OS.get_environment("KK_LOW") != "" else Game.GFX_HIGH
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.7, 0.78)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 10)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.42, 0.28)
	ground.material_override = gm
	add_child(ground)
	for i in 30:
		# A chalk line every metre, to read the distance covered.
		var l := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.002, 2.0)
		l.mesh = bm
		l.position = Vector3(i - 10, 0.001, 0)
		add_child(l)
	ModelBody.warm()
	a = Athlete.new({"id": "t", "speed": 80}, 0)
	add_child(a)
	a.yaw = PI * 0.5   # facing +x
	a.position = Vector3(-8, 0, 0)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true


func _process(_d: float) -> void:
	var dt := 1.0 / 30.0
	if f < 36:
		a.want = Vector3(6.8, 0, 0)
	if f == 36:
		a.do("dive", 0.5)
	if f > 36 and a.act == "":
		a.want = Vector3(3.0, 0, 0)
	a.integrate(dt)
	cam.position = Vector3(a.position.x, 0.9, 5.2)
	cam.look_at(Vector3(a.position.x, 0.6, 0))
	var sk := a.body.skeleton
	var hips := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin
	print("f %3d %-8s t %.2f x %.2f v %.2f hips %.2f low %.2f drawn %s clip %s" % [f, a.act, a.act_t, a.position.x,
		a.vel.length(), hips.y, a.body.lowest_point() + a.body.position.y, a.body.dive_drawn, a.body.clip])
	if f >= 30 and f % every == 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/dive_%03d.png" % [out, f])
	f += 1
	if f > 120:
		get_tree().quit()
