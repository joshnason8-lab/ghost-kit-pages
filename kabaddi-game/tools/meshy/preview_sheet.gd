extends Node3D
## A check sheet for a Meshy download: front, back, and both hands close up (from the front and from
## below, to see the fingers and which way the palms face). Loads the GLB at run time, so it needs no import.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 512x512 \
##       res://tools/meshy/preview_sheet.tscn -- /abs/model.glb /abs/out.png

const CELL := 512


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(args[0], state) != OK:
		push_error("can't read " + args[0])
		get_tree().quit(1)
		return
	var m: Node3D = doc.generate_scene(state)
	add_child(m)
	var pts := PackedVector3Array()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		for s in mesh.get_surface_count():
			for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				pts.append(xf * v)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	m.position.y -= lo.y   # feet on the floor
	var h := hi.y - lo.y
	# The hands: the points furthest out to each side.
	var hands := []
	for sgn in [-1.0, 1.0]:
		var edge: float = hi.x if sgn > 0 else lo.x
		var sum := Vector3.ZERO
		var n := 0
		for p in pts:
			if absf(p.x - edge) < 0.12:
				sum += p
				n += 1
		hands.append(sum / maxf(1, n) - Vector3(0, lo.y, 0))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.66)
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	add_child(light)
	var cam := Camera3D.new()
	add_child(cam)
	var mid := Vector3((lo.x + hi.x) / 2.0, h / 2.0, (lo.z + hi.z) / 2.0)
	var views := [
		[mid + Vector3(0, 0, h * 1.9), mid, 34.0],
		[mid + Vector3(0, 0, -h * 1.9), mid, 34.0],
		[hands[0] + Vector3(0, 0.05, 0.42), hands[0], 30.0],
		[hands[0] + Vector3(0, -0.4, 0.16), hands[0], 30.0],
		[hands[1] + Vector3(0, 0.05, 0.42), hands[1], 30.0],
		[hands[1] + Vector3(0, -0.4, 0.16), hands[1], 30.0],
	]
	var sheet := Image.create(CELL * views.size(), CELL, false, Image.FORMAT_RGB8)
	for i in views.size():
		cam.fov = views[i][2]
		cam.position = views[i][0]
		cam.look_at(views[i][1], Vector3.UP if absf((views[i][0] - views[i][1]).normalized().y) < 0.95 else Vector3.FORWARD)
		for k in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL, CELL)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	sheet.save_png(args[1])
	get_tree().quit()
