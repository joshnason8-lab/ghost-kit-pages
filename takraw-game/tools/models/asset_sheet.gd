extends Node3D
## Renders imported models from four sides (front: looking at +Z's face from the front, then right, back, left), each
## framed to its size, to see which way a model faces before placing it:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/models/asset_sheet.tscn -- OUT.png res://a.glb [...]

const CELL := Vector2i(320, 320)


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var files := a.slice(1)
	var sheet := Image.create_empty(CELL.x * 4, CELL.y * files.size(), false, Image.FORMAT_RGBA8)
	for row in files.size():
		for side in 4:
			var img: Image = await _shot(files[row], side)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(side * CELL.x, row * CELL.y))
	sheet.save_png(out)
	get_tree().quit()


func _shot(path: String, side: int) -> Image:
	var sv := SubViewport.new()
	sv.size = CELL
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b4a6e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sv.add_child(sun)
	var m: Node3D = (load(path) as PackedScene).instantiate()
	sv.add_child(m)
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.1)
	var dir := Vector3(0, 0, 1).rotated(Vector3.UP, side * PI * 0.5)
	var cam := Camera3D.new()
	cam.fov = 40
	sv.add_child(cam)
	cam.position = c + dir * r * 3.0 + Vector3(0, r * 0.6, 0)
	cam.look_at(c)
	cam.current = true
	var lbl := Label3D.new()
	sv.add_child(lbl)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	sv.queue_free()
	return img
