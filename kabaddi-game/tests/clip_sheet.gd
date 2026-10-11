extends Node3D
## Strips of captured clips on the game's body: six moments through each clip, seen from three quarters,
## one PNG per clip. For choosing and checking clips (tools/mocap/fbx_to_clip.gd).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 256x320 res://tests/clip_sheet.tscn -- OUT_DIR CLIP.json...

const CELL := Vector2i(256, 320)
const N := 6


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(l)
	var floor_m := MeshInstance3D.new()
	floor_m.mesh = PlaneMesh.new()
	(floor_m.mesh as PlaneMesh).size = Vector2(8, 8)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2f6fd6").darkened(0.3)
	floor_m.material_override = fm
	add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3(2.6, 1.6, -3.6)
	cam.look_at(Vector3(0, 0.75, 0))
	var a := Athlete.new()
	a.setup(DB.team("MUM").squad[0], 0, Color("12a4a7"), Color("f3efe6"), true)
	add_child(a)
	a.facing = Vector3(0, 0, -1)
	a.set_state("idle", 1000.0)
	a.set_process(false)
	a.model.set_process(false)
	a.model._moves = []
	for path in args.slice(1):
		var clip := MocapClip.load_file(path)
		if clip == null or clip.version < 2:
			continue
		var sheet := Image.create(CELL.x * N, CELL.y, false, Image.FORMAT_RGB8)
		for k in N:
			var t := clip.length * k / float(N - 1)
			a.model._animate(1.0 / 30.0)
			a.model._apply_pose(clip.sample_pose(t, false), 1.0)
			if a.model.rig:
				a.model.rig.drive(a.model)
			for f in 2:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(k * CELL.x, 0))
		sheet.save_png(out.path_join(clip.name + ".png"))
	get_tree().quit()
