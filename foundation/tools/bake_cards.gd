extends SceneTree
## Bakes the Low crowd's cards (WsgCrowdCards): each shared fan drawn flat from the front - seated, standing and
## cheering - into one atlas, and a second atlas of what each pixel is (the shirt, skin, hair, the legs' clothes) so
## the cards take the team colours and set_looks as the 3D fans do. From the authored crowd motions only (the cards
## are committed: addons/wsg_foundation/crowd/), lit as the 3D crowd lights its fans (from the front, above).
## The colours are each fan's whole textured model (tools/crowd_src: <fan>_hi.res and <fan>.jpg) posed on the rig
## as the crowd's motions pose it, grounded as the crowd's frames are: the crowd's own few-hundred-triangle figure
## carries a face in three or four vertex colours, and on a card a dark-haired or bearded head read as the back of
## one (Pok Ta Pok's Low, 2026-11-03). The parts (the mask) come from the crowd's figure in the same pose.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/bake_cards.gd
## Writes crowd/cards.png (RGBA: the fan, alpha its outline), crowd/cards_mask.png (R the shirt, G skin, B hair, A the
## legs' clothes: each pixel's share; drawn in two passes, the legs' on their own) and
## crowd/cards.json ({"cell": [w, h] px, "size": [w, h] m, "cols", "cells": [{"fan", "pose"}], "poses"}).

const CELL := Vector2i(128, 256)
const SIZE := Vector2(1.15, 2.3)          # each cell, in the fan's own metres: x across their middle, y up from the floor
const POSES := {"sit": ["sit_idle", 0.0], "stand": ["stand_idle", 0.0], "cheer": ["cheer", 0.5]}
const OUT := "res://addons/wsg_foundation/crowd/"
const SRC := "res://tools/crowd_src/"


func _initialize() -> void:
	WsgCrowd3D.DIR = OUT
	WsgCrowd3D._meta = {}
	var md := WsgCrowd3D.meta()
	var fans: Array = md.fans.keys()
	var vp := SubViewport.new()
	vp.size = CELL
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE.y
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(0, SIZE.y * 0.5, 5.0)
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/bake_cards.gdshader")
	mi.material_override = mat
	var cells := []
	for fan in fans:
		for pose in POSES:
			cells.append({"fan": fan, "pose": pose})
	var cols := POSES.size() * 2
	var rows := int(ceil(float(cells.size()) / cols))
	var atlas := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	var mask := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for n in cells.size():
		var c: Dictionary = cells[n]
		var mesh := _pose_mesh(c.fan, POSES[c.pose][0], POSES[c.pose][1], md)
		mi.mesh = mesh
		var at := Vector2i((n % cols) * CELL.x, (n / cols) * CELL.y)
		var shots := []
		# The colours: the whole textured fan in this pose.
		var body := await _pose_body(vp, c.fan, POSES[c.pose][0], POSES[c.pose][1], md)
		# Where the head is drawn (px in the cell: its middle, 9 cm over the head joint, and its radius): the test
		# looks there for the face.
		var hw := body.bone_world("Head").origin + Vector3(0, 0.09, 0)
		c["head"] = [roundi((hw.x / SIZE.x + 0.5) * CELL.x), roundi((1.0 - hw.y / SIZE.y) * CELL.y), roundi(0.09 / SIZE.y * CELL.y)]
		mi.visible = false
		for k in 3:
			await process_frame
		var col := vp.get_texture().get_image()
		col.convert(Image.FORMAT_RGBA8)
		shots.append(col)
		body.queue_free()
		mi.visible = true
		for mode in [1, 2]:
			mat.set_shader_parameter("mode", mode)
			for k in 3:
				await process_frame
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			shots.append(img)
		atlas.blit_rect(shots[0], Rect2i(Vector2i.ZERO, CELL), at)
		# The mask: the shirt, skin and hair from the second pass, the legs' clothes (the third's red) as its alpha.
		var m := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
		for y in CELL.y:
			for x in CELL.x:
				var a: Color = shots[1].get_pixel(x, y)
				var b: Color = shots[2].get_pixel(x, y)
				m.set_pixel(x, y, Color(a.r, a.g, a.b, b.r if shots[0].get_pixel(x, y).a > 0.0 else 0.0))
		mask.blit_rect(m, Rect2i(Vector2i.ZERO, CELL), at)
	atlas.save_png(ProjectSettings.globalize_path(OUT + "cards.png"))
	mask.save_png(ProjectSettings.globalize_path(OUT + "cards_mask.png"))
	var f := FileAccess.open(OUT + "cards.json", FileAccess.WRITE)
	# Each fan's seat height (as drawn: their own units) and own colours of their parts (set_looks shades from them).
	var fan_info := {}
	for fan in fans:
		fan_info[fan] = {"seat": WsgCrowd3D.seat_of(fan).x, "looks": md.fans[fan].get("looks", {})}
	f.store_string(JSON.stringify({"cell": [CELL.x, CELL.y], "size": [SIZE.x, SIZE.y], "cols": cols, "rows": rows,
		"cells": cells, "poses": POSES.keys(), "fans": fan_info, "source": "authored (WsgCrowdClips)"}, "\t"))
	f.close()
	print("cards: %d cells (%d fans x %d poses), atlas %dx%d" % [cells.size(), fans.size(), POSES.size(), atlas.get_width(), atlas.get_height()])
	quit()


## The fan's whole model (textured) in one frame of a crowd motion, on the rig, its lowest point on the floor (as
## bake_crowd grounds the crowd's frames), in vp.
func _pose_body(vp: Node, fan: String, clip: String, at: float, md: Dictionary) -> WsgBody:
	var ch := WsgBody.load_character(SRC, fan)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/bake_cards.gdshader")
	mat.set_shader_parameter("mode", 0)
	mat.set_shader_parameter("textured", true)
	mat.set_shader_parameter("albedo", ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(SRC + fan + ".jpg"))))
	var body := WsgBody.new(ch, mat)
	vp.add_child(body)
	await process_frame
	var ci: Dictionary = md.clips[clip]
	var f := int(floor(at * (int(ci.frames) - 1)))
	var t: float = float(f) / float(md.fps)
	var pose: Dictionary = WsgCrowdClips.pose(clip, t)
	var hs: float = (ch.joints["Hips"] as Vector3).y / 0.98
	for k in pose:
		if k == "@hips":
			var h := body.bone("Hips")
			body.skeleton.set_bone_pose_position(h, body.skeleton.get_bone_rest(h).origin + (pose[k] as Vector3) * hs)
		else:
			body.set_turn(k, pose[k])
	for k in 3:
		await process_frame
	# Grounded: the skinned model's lowest point at 0.
	var sk := body.skeleton
	var mats := []
	for i in sk.get_bone_count():
		mats.append(sk.get_bone_global_pose(i) * Transform3D(Basis.IDENTITY, -sk.get_bone_global_rest(i).origin))
	var arr := (ch.meshes[0] as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := bs.size() / vs.size()
	var low := INF
	for v in vs.size():
		var p := Vector3.ZERO
		for j in nb:
			var w := ws[v * nb + j]
			if w > 0.0:
				p += ((mats[bs[v * nb + j]] as Transform3D) * vs[v]) * w
		low = minf(low, p.y)
	body.position.y = -low
	for k in 2:
		await process_frame
	return body


## The fan's crowd mesh in one frame of a motion (its own units; facing +z, the camera's way).
func _pose_mesh(fan: String, clip: String, at: float, md: Dictionary) -> ArrayMesh:
	var src: ArrayMesh = load(WsgCrowd3D.DIR + fan + "_crowd.res")
	var arr := src.surface_get_arrays(0)
	var ci: Dictionary = md.clips[clip]
	var row := int(ci.row) + int(floor(at * (int(ci.frames) - 1)))
	var img := (load(WsgCrowd3D.DIR + fan + "_pos.res") as Texture2D).get_image()
	var nimg := (load(WsgCrowd3D.DIR + fan + "_nrm.res") as Texture2D).get_image()
	var nv := int(md.fans[fan].vertices)
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for v in nv:
		var p := img.get_pixel(v, row)
		var q := nimg.get_pixel(v, row)
		pos.append(Vector3(p.r, p.g, p.b))
		nrm.append(Vector3(q.r * 2.0 - 1.0, q.g * 2.0 - 1.0, q.b * 2.0 - 1.0).normalized())
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
