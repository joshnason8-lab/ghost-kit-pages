extends SceneTree
## Prepares the Meshy models for phones (docs/MESHY_BRIEF.md; from the floorball game's tool): cuts the mesh down to a triangle budget with
## Godot's own simplifier (ImporterMesh LODs: skin weights and UVs are kept, as the cut only drops triangles), shrinks
## the texture, and saves what the game loads:
##   character (a rigged GLB, a player or a judge): assets/people/<name>.scn (the skeleton and the mesh, for High
##     graphics), <name>_mid.scn (Medium) and <name>_low.scn (Low), with the texture as <name>.jpg
##   prop (a static GLB, a spectator): assets/people/<name>.res (an ArrayMesh) and <name>.jpg
## Usage:
##   godot --headless --script tools/meshy/prepare.gd -- character in.glb name tris_high tris_mid tris_low [tex_px]
##   godot --headless --script tools/meshy/prepare.gd -- prop in.glb name tris [tex_px]

const OUT := "res://assets/people/"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if a[0] == "character":
		_character(a[1], a[2], [int(a[3]), int(a[4]), int(a[5])], int(a[6]) if a.size() > 6 else 1024)
	else:
		_prop(a[1], a[2], int(a[3]), int(a[4]) if a.size() > 4 else 512)
	quit()


func _load(path: String) -> Array:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	assert(err == OK, "cannot read %s" % path)
	return [doc, st]


## The surface's arrays with only the triangles of the LOD nearest the budget, unused vertices dropped.
func _cut(im: ImporterMesh, surface: int, tris: int, bones := []) -> Array:
	var arrays: Array = im.get_surface_arrays(surface)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var best := idx
	if idx.size() / 3 > tris:
		im.generate_lods(25.0, 60.0, bones)
		for l in im.get_surface_lod_count(surface):
			var li: PackedInt32Array = im.get_surface_lod_indices(surface, l)
			if absi(li.size() / 3 - tris) < absi(best.size() / 3 - tris):
				best = li
	# Compact: keep only the vertices the triangles use, in the order first used.
	var remap := {}
	var order := PackedInt32Array()
	var out_idx := PackedInt32Array()
	out_idx.resize(best.size())
	for i in best.size():
		var v: int = best[i]
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		out_idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for k in Mesh.ARRAY_MAX:
		var src = arrays[k]
		if src == null or k == Mesh.ARRAY_INDEX:
			continue
		var per := 1
		if k == Mesh.ARRAY_BONES or k == Mesh.ARRAY_WEIGHTS:
			per = src.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		elif k == Mesh.ARRAY_TANGENT:
			per = 4
		var dst = src.duplicate()
		dst.resize(order.size() * per)
		for n in order.size():
			for j in per:
				dst[n * per + j] = src[order[n] * per + j]
		out[k] = dst
	out[Mesh.ARRAY_INDEX] = out_idx
	print("  %d -> %d triangles, %d vertices" % [idx.size() / 3, out_idx.size() / 3, order.size()])
	return out


func _texture(st: GLTFState, name: String, px: int) -> String:
	var imgs := st.get_images()
	if imgs.is_empty():
		return ""
	var img: Image = (imgs[0] as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var path := OUT + name + ".jpg"
	img.save_jpg(ProjectSettings.globalize_path(path), 0.9)
	print("  texture %s (%d px)" % [path, px])
	return path


func _character(src: String, name: String, tris: Array, px: int) -> void:
	print(name, ":")
	var tex := _texture(_load(src)[1], name, px)
	for pass_i in 3:
		var l := _load(src)
		var doc: GLTFDocument = l[0]
		var st: GLTFState = l[1]
		var root: Node = doc.generate_scene(st)
		var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		var im: ImporterMesh = (st.get_meshes()[0] as GLTFMesh).mesh
		var mesh := ArrayMesh.new()
		for s in im.get_surface_count():
			var arr := _cut(im, s, int(tris[pass_i]))
			# Each vertex's height standing (0 the soles, 1 the top of the head) in its colour's red: the kit's shader
			# tells shirt, shorts and socks apart by it, whatever pose the body is in.
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var lo := INF
			var hi := -INF
			for v in vs:
				lo = minf(lo, v.y)
				hi = maxf(hi, v.y)
			var cols := PackedColorArray()
			cols.resize(vs.size())
			for i in vs.size():
				cols[i] = Color((vs[i].y - lo) / (hi - lo), 0, 0)
			arr[Mesh.ARRAY_COLOR] = cols
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		# No material saved with it: the game draws it with its own (game/rigged_body.gd: the kit's colours over the
		# texture), so the texture is not packed in twice.
		mi.mesh = mesh
		# The game poses it (game/rigged_body.gd): Meshy's clips are dropped; the scene is saved whole, owners set.
		for ap in root.find_children("*", "AnimationPlayer", true, false):
			ap.get_parent().remove_child(ap)
			ap.free()
		root.name = "Character"
		_own(root, root)
		var ps := PackedScene.new()
		ps.pack(root)
		var out: String = OUT + name + ["", "_mid", "_low"][pass_i] + ".scn"
		ResourceSaver.save(ps, out, ResourceSaver.FLAG_COMPRESS)
		print("  saved ", out)
		root.free()


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)


func _prop(src: String, name: String, tris: int, px: int) -> void:
	print(name, ":")
	var l := _load(src)
	var st: GLTFState = l[1]
	var tex := _texture(st, name, px)
	var im: ImporterMesh = (st.get_meshes()[0] as GLTFMesh).mesh
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _cut(im, 0, tris))
	print("  aabb ", mesh.get_aabb())
	ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	print("  saved ", OUT + name + ".res")
