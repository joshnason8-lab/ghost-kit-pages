extends SceneTree
## Baked light (WsgLightBake): the second UVs it makes give every face its own patch of the map (inside it, none on
## another, the same each time), the signature follows the geometry, and the export writes what the bake reads.
##   godot --headless --path . -s tests/light_bake_test.gd

func _initialize() -> void:
	var fails := []
	# A small built place: a stand of boxes and steps, as a game builds its stadium (each quad its own vertices).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var faces := 0
	for i in 300:
		var c := Vector3(rng.randf_range(-60, 60), rng.randf_range(0, 15), rng.randf_range(-40, 40))
		var s := Vector3(rng.randf_range(0.05, 12), rng.randf_range(0.05, 4), rng.randf_range(0.05, 6))
		for n: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var u := n.cross(Vector3.FORWARD if absf(n.z) < 0.5 else Vector3.UP).normalized()
			var v := n.cross(u)
			var p := c + n * (s * n.abs()).length() * 0.5
			var hu := (s * u.abs()).length() * 0.5
			var hv := (s * v.abs()).length() * 0.5
			var q := [p - u * hu - v * hv, p + u * hu - v * hv, p + u * hu + v * hv, p - u * hu + v * hv]
			var base := faces * 4
			for k in 4:
				st.set_normal(n)
				st.add_vertex(q[k])
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_index(base + k)
			faces += 1
	var mesh := st.commit()
	var t0 := Time.get_ticks_msec()
	var un := WsgLightBake.unwrap(mesh, 1024)
	var ms := Time.get_ticks_msec() - t0
	var uv2: PackedVector2Array = (un[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	# Each face's patch, in texels: inside the map, and on no other.
	var rects := []
	var outside := 0
	for f in faces:
		var r := Rect2(uv2[f * 4] * 1024.0, Vector2.ZERO)
		for k in range(1, 4):
			r = r.expand(uv2[f * 4 + k] * 1024.0)
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > 1024.0 or r.end.y > 1024.0:
			outside += 1
		rects.append(r.grow(-0.01))
	var overlaps := 0
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			if (rects[a] as Rect2).intersects(rects[b]):
				overlaps += 1
	print("unwrap: %d faces in %d ms, texel %.3f m, %d outside the map, %d overlapping" % [faces, ms, un[1], outside, overlaps])
	if outside > 0 or overlaps > 0:
		fails.append("unwrap: %d outside, %d overlapping" % [outside, overlaps])
	# The same every time (the game makes them at run time to match the bake).
	var again: PackedVector2Array = (WsgLightBake.unwrap(mesh, 1024)[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	if again != uv2:
		fails.append("unwrap: not the same twice")
	# The signature: the same geometry the same, a face moved a centimetre not.
	var sig := WsgLightBake.signature(mesh)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	verts[0] += Vector3(0.01, 0, 0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var moved := ArrayMesh.new()
	moved.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	print("signature: %d, again %d, a face moved %d" % [sig, WsgLightBake.signature(mesh), WsgLightBake.signature(moved)])
	if sig != WsgLightBake.signature(mesh) or sig == WsgLightBake.signature(moved):
		fails.append("signature")
	# The export, and a light map found only for its own geometry.
	var dir := OS.get_user_data_dir().path_join("light_bake_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var base := dir.path_join("place")
	WsgLightBake.export(mesh, {"sun_dir": [0, 1, 0], "size": 1024}, base)
	var obj := FileAccess.get_file_as_string(base + ".obj")
	var nf := obj.count("\nf ")
	print("export: %d triangles in the OBJ (want %d)" % [nf, faces * 2])
	if nf != faces * 2 or not FileAccess.file_exists(base + ".json"):
		fails.append("export")
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 0.5))
	img.save_png(base + "_light.png")
	var found := WsgLightBake.load_for(mesh, base).size() > 0
	var not_found := WsgLightBake.load_for(moved, base).is_empty()
	print("load_for: its own geometry %s, moved geometry refused %s" % [found, not_found])
	if not found or not not_found:
		fails.append("load_for")
	for f in fails:
		printerr("FAIL: ", f)
	print("LIGHT BAKE TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
