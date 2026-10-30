extends SceneTree
## A Godot mesh (an ArrayMesh .res, every surface) written as an OBJ for Blender: positions, normals and UVs (the V
## turned for OBJ's bottom-left origin), Y up, metres, in the pose it was saved in (the rig's T for the foundation's
## characters).
##   godot --headless --path <project> -s <this> -- <mesh.res> <out.obj>

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mesh := load(a[0]) as Mesh
	if mesh == null:
		printerr("export_obj: not a mesh: ", a[0])
		quit(1)
		return
	var f := FileAccess.open(a[1], FileAccess.WRITE)
	f.store_line("# %s (%d surfaces)" % [a[0], mesh.get_surface_count()])
	var base := 1
	var tris := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in v.size():
				idx.append(i)
		f.store_line("o surface%d" % s)
		for p in v:
			f.store_line("v %.6f %.6f %.6f" % [p.x, p.y, p.z])
		for t in uv:
			f.store_line("vt %.6f %.6f" % [t.x, 1.0 - t.y])
		for q in n:
			f.store_line("vn %.6f %.6f %.6f" % [q.x, q.y, q.z])
		# Godot's front faces wind clockwise; OBJ's counter-clockwise.
		for i in range(0, idx.size(), 3):
			var c := [idx[i] + base, idx[i + 2] + base, idx[i + 1] + base]
			var parts := []
			for k in c:
				parts.append("%d/%s/%s" % [k, str(k) if not uv.is_empty() else "", str(k) if not n.is_empty() else ""])
			f.store_line("f " + " ".join(parts))
			tris += 1
		base += v.size()
	f.close()
	print("export_obj: %s: %d triangles -> %s" % [a[0], tris, a[1]])
	quit()
