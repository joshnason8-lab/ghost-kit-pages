extends SceneTree
## Every fan model in a crowd pose, side by side (the full mesh on the rig, before the crowd's cut): to look at.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/media/fan_lineup.gd -- <char dir> <tex dir> <out.png> <clip> <t> fan fan2 ...

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var fans: Array = a.slice(5)
	var cell := Vector2i(260, 400)
	var sheet := Image.create(cell.x * fans.size(), cell.y, false, Image.FORMAT_RGBA8)
	for i in fans.size():
		var vp := SubViewport.new()
		vp.size = cell
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		WsgStage.build(vp, 6.0)
		var ch := WsgBody.load_character(a[0], fans[i])
		var body := WsgBody.new(ch, WsgStage.hero_material(a[1].path_join(fans[i] + ".jpg")))
		vp.add_child(body)
		var cam := Camera3D.new()
		vp.add_child(cam)
		await process_frame
		cam.fov = 40
		cam.look_at_from_position(Vector3(0.8, 1.2, 3.2), Vector3(0, 0.95, 0))
		var pose := WsgCrowdClips.pose(a[3], float(a[4]))
		var hs: float = (ch.joints["Hips"] as Vector3).y / 0.98
		for k in pose:
			if k == "@hips":
				var h := body.bone("Hips")
				body.skeleton.set_bone_pose_position(h, body.skeleton.get_bone_rest(h).origin + (pose[k] as Vector3) * hs)
			else:
				body.set_turn(k, pose[k])
		for f in 3:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(i * cell.x, 0))
		vp.queue_free()
	sheet.save_png(a[2])
	quit()
