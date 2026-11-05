extends SceneTree
## Makes a model small enough for a phone: its mesh simplified to about TRIS triangles (meshoptimizer's level of
## detail, the same vertices and skin weights, only fewer of them), its textures cut to SIZE pixels. Run it on each
## model as it comes (a Meshy character, the ball); the game loads what it writes.
##   godot --headless -s tools/models/prepare_model.gd -- IN.glb OUT.glb TRIS SIZE [h=METRES | l=METRES]
## A Meshy prop comes in a box about 2 units across, centred: h= (its height) or l= (its longest side on the ground) makes
## it its real size, standing on the ground (y 0) and centred there.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		push_error("usage: -- IN.glb OUT.glb TRIS SIZE")
		quit(1)
		return
	var src: String = a[0]
	var out: String = a[1]
	var want := int(a[2])
	var size := int(a[3])
	var fit := a[4] if a.size() > 4 else ""
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(src, st) != OK:
		push_error("can't read " + src)
		quit(1)
		return
	var xf := Transform3D.IDENTITY
	if fit != "":
		var box := AABB()
		var first := true
		for gm in st.get_meshes():
			var im: ImporterMesh = (gm as GLTFMesh).mesh
			for s in im.get_surface_count():
				for v in (im.get_surface_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					box = AABB(v, Vector3.ZERO) if first else box.expand(v)
					first = false
		var k := float(fit.substr(2)) / (box.size.y if fit.begins_with("h=") else maxf(box.size.x, box.size.z))
		xf = Transform3D(Basis.from_scale(Vector3.ONE * k), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k)
		print("size %s -> %s" % [box.size, box.size * k])
	for gm in st.get_meshes():
		var im: ImporterMesh = (gm as GLTFMesh).mesh
		im.generate_lods(25.0, 60.0, [])
		var made := ImporterMesh.new()
		for s in im.get_surface_count():
			var arrays: Array = im.get_surface_arrays(s)
			if fit != "":
				var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in vs.size():
					vs[i] = xf * vs[i]
				arrays[Mesh.ARRAY_VERTEX] = vs
			var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var best := full
			var sizes := ["%d" % (full.size() / 3)]
			for l in im.get_surface_lod_count(s):
				var ids: PackedInt32Array = im.get_surface_lod_indices(s, l)
				sizes.append("%d" % (ids.size() / 3))
				if absi(ids.size() / 3 - want) < absi(best.size() / 3 - want):
					best = ids
			print("surface %d: levels %s; using %d triangles" % [s, ", ".join(sizes), best.size() / 3])
			made.add_surface(im.get_surface_primitive_type(s), _compact(arrays, best), [], {}, im.get_surface_material(s),
				im.get_surface_name(s), im.get_surface_format(s))
		(gm as GLTFMesh).mesh = made
	# Cut to 256 px or less (a Low model): its colour only, no relief, roughness or metal maps (Meshy's remeshed models
	# come with them at 2048 px).
	if size <= 256:
		for m in st.get_materials():
			if m is BaseMaterial3D:
				var bm: BaseMaterial3D = m
				bm.normal_enabled = false
				bm.normal_texture = null
				bm.ao_enabled = false
				bm.ao_texture = null
				bm.metallic_texture = null
				bm.roughness_texture = null
				bm.metallic = 0.0
				bm.roughness = 0.9
	var imgs: Array = st.get_images()
	for i in imgs.size():
		var tex: Texture2D = imgs[i]
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		if img.get_width() > size:
			img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		imgs[i] = ImageTexture.create_from_image(img)
	st.set_images(imgs)
	# Written afresh from the scene it makes (the source's binary data would otherwise go out again, and its
	# animations point into it).
	var scene := doc.generate_scene(st)
	var doc2 := GLTFDocument.new()
	var st2 := GLTFState.new()
	doc2.image_format = "JPEG"
	doc2.lossy_quality = 0.85
	if doc2.append_from_scene(scene, st2) != OK or doc2.write_to_filesystem(st2, out) != OK:
		push_error("can't write " + out)
		quit(1)
		return
	print("wrote ", out)
	quit()


## Keeps only the vertices the simplified triangles use.
func _compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var order := PackedInt32Array()
	var out_idx := PackedInt32Array()
	out_idx.resize(indices.size())
	for k in indices.size():
		var v := indices[k]
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
		out_idx[k] = remap[v]
	var res := []
	res.resize(Mesh.ARRAY_MAX)
	for t in Mesh.ARRAY_MAX:
		var src = arrays[t]
		if src == null or t == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if t == Mesh.ARRAY_BONES or t == Mesh.ARRAY_WEIGHTS:
			per = (src.size() / verts.size())
		elif t == Mesh.ARRAY_TANGENT:
			per = 4
		var dst = src.duplicate()
		dst.resize(order.size() * per)
		for n in order.size():
			for c in per:
				dst[n * per + c] = src[order[n] * per + c]
		res[t] = dst
	res[Mesh.ARRAY_INDEX] = out_idx
	return res
