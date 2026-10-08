extends Node3D
## Orthographic front, right and left renders of res://model.glb for joint detection
## (see tools/rig/README.md). Run in a scratch project, not the game. The image height
## covers EXTENT metres, centred 0.75 m up; autorig.py assumes the same numbers.
const EXTENT := 2.0


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var m: Node3D = load("res://model.glb").instantiate()
	add_child(m)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.6, 0.48)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.92, 0.92, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var l := DirectionalLight3D.new()
	add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = EXTENT
	add_child(cam)
	# Front: camera on -Z looking toward +Z (the model faces -Z). Side: from +X looking -X.
	var views := [["front", Vector3(0, 0.75, -5), Vector3(0, 0.75, 0)], ["side", Vector3(5, 0.75, 0), Vector3(0, 0.75, 0)], ["left", Vector3(-5, 0.75, 0), Vector3(0, 0.75, 0)]]
	for v in views:
		cam.position = v[1]
		cam.look_at(v[2])
		l.global_transform = cam.global_transform
		l.rotate_object_local(Vector3.RIGHT, -0.4)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/ortho_" + v[0] + ".png")
	get_tree().quit()
