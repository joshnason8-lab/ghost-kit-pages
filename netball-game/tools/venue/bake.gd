extends SceneTree
## Bakes the venues' models (tools/venue/src, from the shared assets: Poly Haven and the owner's models) into what the
## game loads: for each venue one mesh resource holding every model as a named surface, and one texture atlas, so all
## of a venue's props are drawn in a single draw call (VenueProps). Run from netball-game/:
##   godot --headless --path . -s tools/venue/bake.gd
## then `godot --headless --path . --import`. Writes assets/venue/<venue>_props.res, <venue>_atlas.jpg and, for
## cut-outs (trees, grass), <venue>_cards.png.
##
## Each model's surfaces keep their geometry (deduplicated and indexed); their UVs are moved into the model's place in
## the atlas, with a margin of repeated edge pixels so mipmaps don't bleed. UV2 carries (kind, glow): kind 0 opaque, 1
## cut-out (from the cards atlas), 2 metal; glow makes the surface light up (a lamp's diffuser).

const SRC := "res://tools/venue/src/"
const OUT := "res://assets/venue/"

## venue: [atlas width, {name: [file, tile size, {surface: [kind, glow]}]}]. A name with _low is the Low graphics model.
const VENUES := {
	"hall": [1024, {
		"fluorescent_light": ["hall/fluorescent_light.glb", 256, {1: [0, 2.2]}],
		"fluorescent_light_low": ["hall/fluorescent_light_low.glb", 256, {1: [0, 2.2]}],
		"wall_clock": ["hall/wall_clock.glb", 256, {}],
		"fire_alarm": ["hall/fire_alarm.glb", 128, {}],
		"wet_floor_sign": ["hall/wet_floor_sign.glb", 128, {}],
		"gym_bench": ["seating/gym_bench.glb", 512, {}],
		"gym_bench_low": ["seating/gym_bench_low.glb", 256, {}],
		"painted_bench": ["seating/painted_bench.glb", 512, {}],
		"painted_bench_low": ["seating/painted_bench_low.glb", 256, {}],
	}],
	"outdoor": [2048, {
		"park_bench": ["seating/park_bench.glb", 512, {}],
		"park_bench_low": ["seating/park_bench_low.glb", 256, {}],
		"street_lamp_tall": ["props/street_lamp_tall.glb", 512, {0: [0, 1.6], 1: [2, 0.0]}],
		"street_lamp_tall_low": ["props/street_lamp_tall_low.glb", 256, {0: [0, 1.6], 1: [2, 0.0]}],
		"basketball_hoop": ["hall/basketball_hoop.glb", 512, {}],
		"basketball_hoop_low": ["hall/basketball_hoop_low.glb", 256, {}],
		"oak_tree": ["trees/oak_tree.glb", 1024, {}],
		"oak_tree_low": ["trees/oak_tree_low.glb", 512, {}],
		"terrace_row": ["buildings/terrace_row.glb", 1024, {}],
		"terrace_row_low": ["buildings/terrace_row_low.glb", 512, {}],
		"oak_tree_card": ["trees/oak_tree_card.glb", 1024, {0: [1, 0.0]}],
		"jacaranda_card": ["trees/jacaranda_card.glb", 1024, {0: [1, 0.0]}],
		"small_broadleaf_card": ["trees/small_broadleaf_card.glb", 1024, {0: [1, 0.0]}],
		"grass_clumps_card": ["foliage/grass_clumps_card.glb", 512, {0: [1, 0.0]}],
	}],
	"arena": [1024, {
		# Medium and High only: the _low model's decimation broke its seats, and Low keeps the painted stand.
		"bleacher_metal": ["stands/bleacher_metal.glb", 1024, {}],
	}],
}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for venue: String in VENUES:
		if not only.is_empty() and not venue in only:
			continue
		_bake(venue, VENUES[venue][0], VENUES[venue][1])
	quit()


func _bake(venue: String, width: int, items: Dictionary) -> void:
	# Gather every surface: its arrays, its image and its kind.
	var surfs := []   # [name, arrays, image, kind, glow, tile]
	for name: String in items:
		var it: Array = items[name]
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(SRC + it[0]), st) != OK:
			push_error("can't read " + it[0])
			continue
		var scene := doc.generate_scene(st)
		var found := []
		_meshes(scene, Transform3D.IDENTITY, found)
		var si := 0
		for f: Array in found:
			var mesh: Mesh = f[0]
			for s in mesh.get_surface_count():
				var flags: Array = it[2].get(si, [0, 0.0])
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				var img: Image = null
				if mat and mat.albedo_texture:
					img = mat.albedo_texture.get_image()
					img.decompress()
				else:
					img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
					img.fill(mat.albedo_color if mat else Color(0.8, 0.8, 0.8))
				surfs.append([name, _xform(mesh.surface_get_arrays(s), f[1]), img, int(flags[0]), float(flags[1]), int(it[1])])
				si += 1
		scene.free()
	# Pack the opaque and the cut-out images separately; identical images share a place.
	for cards in [false, true]:
		var list := surfs.filter(func(s: Array) -> bool: return (s[3] == 1) == cards)
		if list.is_empty():
			continue
		var places := {}   # image hash -> Rect2 (in pixels)
		var rects := []
		var imgs := []
		for s: Array in list:
			var key := hash((s[2] as Image).get_data()) + int(s[5])
			if not places.has(key):
				var im: Image = s[2]
				var w: int = s[5]
				var h := int(round(w * float(im.get_height()) / im.get_width()))
				places[key] = rects.size()
				rects.append(Vector2i(w, h))
				imgs.append(im)
			s.append(places[key])
		var pos := _pack(rects, width)
		var height := 1
		for i in rects.size():
			height = maxi(height, pos[i].y + rects[i].y)
		height = nearest_po2(height)
		var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8 if cards else Image.FORMAT_RGB8)
		var uvr := []
		for i in rects.size():
			var r: Vector2i = rects[i]
			var pad := maxi(2, r.x / 32)
			var im: Image = imgs[i].duplicate()
			im.convert(atlas.get_format())
			# The margin: the image stretched to the whole place, then the image itself inside it.
			var full: Image = im.duplicate()
			full.resize(r.x, r.y, Image.INTERPOLATE_BILINEAR)
			atlas.blit_rect(full, Rect2i(Vector2i.ZERO, r), pos[i])
			var inner := Vector2i(r.x - pad * 2, r.y - pad * 2)
			im.resize(inner.x, inner.y, Image.INTERPOLATE_LANCZOS)
			if not cards:
				for e in 4:   # repeat the edge rows outward
					var ofs := Vector2i(pad - 1 - e, pad - 1 - e)
					atlas.blit_rect(im, Rect2i(Vector2i.ZERO, inner), pos[i] + ofs)
					atlas.blit_rect(im, Rect2i(Vector2i.ZERO, inner), pos[i] + Vector2i(pad, pad) * 2 - ofs)
			atlas.blit_rect(im, Rect2i(Vector2i.ZERO, inner), pos[i] + Vector2i(pad, pad))
			uvr.append(Rect2(Vector2(pos[i] + Vector2i(pad, pad)) / Vector2(width, height), Vector2(inner) / Vector2(width, height)))
		for s: Array in list:
			s.append(uvr[s[6]])
		if cards:
			atlas.save_png(OUT + venue + "_cards.png")
		else:
			atlas.save_jpg(OUT + venue + "_atlas.jpg", 0.88)
		print("%s %s atlas %dx%d, %d images" % [venue, "cards" if cards else "opaque", width, height, rects.size()])
	# One mesh, a surface per model (a model's surfaces merged into one).
	var out := ArrayMesh.new()
	for name: String in items:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for s: Array in surfs:
			if s[0] != name:
				continue
			any = true
			var a: Array = s[1]
			var r: Rect2 = s[7]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var order := idx if not idx.is_empty() else PackedInt32Array(range(v.size()))
			for k in order:
				var u := uv[k] if k < uv.size() else Vector2.ZERO
				u = Vector2(clampf(u.x, 0.0, 1.0), clampf(u.y, 0.0, 1.0))
				st.set_uv(r.position + u * r.size)
				st.set_uv2(Vector2(s[3], s[4]))
				# Cut-outs are lit as foliage from above, whichever way their planes face.
				st.set_normal(Vector3.UP if s[3] == 1 else (n[k] if k < n.size() else Vector3.UP))
				st.add_vertex(v[k])
		if not any:
			continue
		st.index()
		var arrays := st.commit_to_arrays()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_name(out.get_surface_count() - 1, name)
		print("  %s: %d vertices, %d triangles" % [name, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	ResourceSaver.save(out, OUT + venue + "_props.res", ResourceSaver.FLAG_COMPRESS)


func _meshes(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append([(n as MeshInstance3D).mesh, t])
	for c in n.get_children():
		_meshes(c, t, out)


func _xform(a: Array, t: Transform3D) -> Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	for i in v.size():
		v[i] = t * v[i]
	for i in n.size():
		n[i] = (t.basis * n[i]).normalized()
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	return a


## Shelf packing, biggest first: the top-left corner of each rect.
func _pack(rects: Array, width: int) -> Array:
	var order := range(rects.size())
	order.sort_custom(func(a: int, b: int) -> bool: return rects[a].y * 4096 + rects[a].x > rects[b].y * 4096 + rects[b].x)
	var pos := []
	pos.resize(rects.size())
	var x := 0
	var y := 0
	var shelf := 0
	for i: int in order:
		var r: Vector2i = rects[i]
		if x + r.x > width:
			x = 0
			y += shelf
			shelf = 0
		pos[i] = Vector2i(x, y)
		x += r.x
		shelf = maxi(shelf, r.y)
	return pos
