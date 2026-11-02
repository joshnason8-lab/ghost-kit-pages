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
	_thin(fails, dir)
	for f in fails:
		printerr("FAIL: ", f)
	print("LIGHT BAKE TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## A thin white post (a goal's upright: 12 cm across, 8 sides of 4.6 cm) and an open wall (a 4 m box) on open ground,
## in a map whose texel (about 0.4 m) is many times the post's sides: every face's patch must hold texels of its own
## (their centres inside the face), and baked (Blender's Cycles, when on the PATH) the post's sides together must get
## about the light the box's sides do.
func _thin(fails: Array, dir: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [0]
	var quad := func(q: Array, n: Vector3) -> void:
		var b: int = faces[0] * 4
		for k in 4:
			st.set_normal(n)
			st.add_vertex(q[k])
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_index(b + k)
		faces[0] += 1
	# The post at x = -6: eight sides, 7 m tall (clockwise from outside, as Godot's fronts).
	var c := Vector3(-6, 0, 0)
	var r := 0.06
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		quad.call([c + d1 * r + Vector3(0, 7, 0), c + d0 * r + Vector3(0, 7, 0), c + d0 * r, c + d1 * r], (d0 + d1).normalized())
	# The box at x = +6: 4 m a side, 3 m tall, its four sides and its top.
	var b0 := Vector3(6, 0, 0)
	for n: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var u := n.cross(Vector3.UP)
		var p := b0 + n * 2.0
		quad.call([p + u * 2 + Vector3(0, 3, 0), p - u * 2 + Vector3(0, 3, 0), p - u * 2, p + u * 2], n)
	quad.call([b0 + Vector3(-2, 3, -2), b0 + Vector3(2, 3, -2), b0 + Vector3(2, 3, 2), b0 + Vector3(-2, 3, 2)], Vector3.UP)
	# Filler (a stand's worth of faces far off) so the texel comes out much larger than the post's sides.
	for i in 40:
		var o := Vector3(-200 + i * 10.0, 0, 60)
		quad.call([o + Vector3(0, 20, 0), o + Vector3(8, 20, 0), o + Vector3(8, 0, 0), o], Vector3.BACK)
	var mesh := st.commit()
	var size := 256
	var un := WsgLightBake.unwrap(mesh, size)
	var texel: float = un[1]
	var a := (un[0] as ArrayMesh).surface_get_arrays(0)
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	# Texel centres inside each of the post's sides (its two triangles' patch: the whole quad's rectangle).
	var fewest := 1 << 30
	for f in 8:
		var rr := Rect2(uv2[f * 4] * size, Vector2.ZERO)
		for k in range(1, 4):
			rr = rr.expand(uv2[f * 4 + k] * size)
		var n := 0
		for y in range(floori(rr.position.y), ceili(rr.end.y)):
			for x in range(floori(rr.position.x), ceili(rr.end.x)):
				if rr.has_point(Vector2(x + 0.5, y + 0.5)):
					n += 1
		fewest = mini(fewest, n)
	print("thin post: texel %.2f m, a side %.3f m across; the fewest texel centres on a side: %d (want >= %d)" % [
		texel, 2.0 * r * sin(PI / 8.0), fewest, WsgLightBake.MIN_TEXELS * WsgLightBake.MIN_TEXELS])
	if fewest < WsgLightBake.MIN_TEXELS * WsgLightBake.MIN_TEXELS:
		fails.append("thin post: a side with %d texel centres" % fewest)
	# Baked: the post's sides' light against the box's sides' (the same sun, sky and ground; both in the open).
	var blender := OS.get_environment("WSG_BLENDER") if OS.has_environment("WSG_BLENDER") else "blender"
	var probe: Array = []
	if OS.execute(blender, ["--version"], probe) != 0:
		print("thin post bake: skipped (no Blender on the PATH; WSG_BLENDER names one)")
		return
	var base := dir.path_join("thin")
	WsgLightBake.export(mesh, {"sun_dir": [0.4, 0.75, 0.53], "sun_colour": [1, 0.97, 0.92], "sun_energy": 1.0,
		"sky_colour": [0.6, 0.65, 0.75], "sky_energy": 0.6, "size": size, "scale": 2.0}, base)
	var script := ProjectSettings.globalize_path("res://tools/blender/bake_light.py")
	var out: Array = []
	var code := OS.execute(blender, ["-b", "--python", script, "--", "--base", base, "--samples", "16"], out, true)
	var img := Image.load_from_file(base + "_light.png")
	if code != 0 or img == null or img.is_empty():
		fails.append("thin post bake: Blender failed (%d)" % code)
		return
	var light := func(f: int) -> float:
		# The face's light at its middle, filtered as the game's material reads it (bilinear).
		var m := Vector2.ZERO
		for k in 4:
			m += uv2[f * 4 + k] * 0.25
		var p := m * size - Vector2(0.5, 0.5)
		var x0 := floori(p.x)
		var y0 := floori(p.y)
		var g := func(x: int, y: int) -> float: return img.get_pixel(clampi(x, 0, size - 1), clampi(y, 0, size - 1)).r
		var fx := p.x - x0
		var fy := p.y - y0
		return lerpf(lerpf(g.call(x0, y0), g.call(x0 + 1, y0), fx), lerpf(g.call(x0, y0 + 1), g.call(x0 + 1, y0 + 1), fx), fy) * 2.0
	var post := 0.0
	for f in 8:
		post += light.call(f) / 8.0
	var wall := 0.0
	for f in range(8, 12):
		wall += light.call(f) / 4.0
	var ratio := post / maxf(wall, 1e-4)
	print("thin post bake: the post's sides %.3f on average, the open box's sides %.3f (%.2f of it; want 0.75 - 1.33)" % [post, wall, ratio])
	if ratio < 0.75 or ratio > 1.33:
		fails.append("thin post bake: the post %.3f, the wall %.3f" % [post, wall])
