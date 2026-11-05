extends SceneTree
## A light mesh made in Blender (decimate_lod.py, an OBJ) as a character's mesh again: each vertex skinned as the
## nearest point of the detailed mesh's surface is (its triangle's weights blended; both in the rig's T, and the
## decimation keeps the surface where it was), its colour too; tangents for the normal map; Godot's own smaller levels
## for far away.
##   godot --headless --path <project> -s <this> -- <hi.res> <lo.obj> <out lo.res>

const CELL := 0.05


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var hi := load(a[0]) as ArrayMesh
	var ha := hi.surface_get_arrays(0)
	var hv: PackedVector3Array = ha[Mesh.ARRAY_VERTEX]
	var hb: PackedInt32Array = ha[Mesh.ARRAY_BONES]
	var hw: PackedFloat32Array = ha[Mesh.ARRAY_WEIGHTS]
	var hc: PackedColorArray = ha[Mesh.ARRAY_COLOR] if ha[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	# A second UV set (a game's per-vertex data: Kabaddi's kit regions) taken from the nearest corner, not blended.
	var hu2: PackedVector2Array = ha[Mesh.ARRAY_TEX_UV2] if ha[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var per := hb.size() / hv.size()
	# The OBJ (Y up, V from the bottom; faces counter-clockwise), one vertex per position/UV/normal used together.
	var pos := []
	var uvs := []
	var nrm := []
	var key := {}
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var ts := PackedVector2Array()
	var idx := PackedInt32Array()
	for line in FileAccess.get_file_as_string(a[1]).split("\n"):
		var p := line.strip_edges().split(" ", false)
		if p.is_empty():
			continue
		match p[0]:
			"v":
				pos.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
			"vt":
				uvs.append(Vector2(float(p[1]), 1.0 - float(p[2])))
			"vn":
				nrm.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
			"f":
				var corner := []
				for k in range(1, p.size()):
					if not key.has(p[k]):
						var q := p[k].split("/")
						key[p[k]] = vs.size()
						vs.append(pos[int(q[0]) - 1])
						ts.append(uvs[int(q[1]) - 1] if q.size() > 1 and q[1] != "" else Vector2.ZERO)
						ns.append(nrm[int(q[2]) - 1] if q.size() > 2 and q[2] != "" else Vector3.UP)
					corner.append(key[p[k]])
				for k in range(1, corner.size() - 1):
					idx.append_array([corner[0], corner[k + 1], corner[k]])
	# Skin and colour from the nearest point of the detailed surface: its triangle's vertices' weights, blended as the
	# point lies between them (triangles found through a grid of 5 cm cells).
	var hi_idx: PackedInt32Array = ha[Mesh.ARRAY_INDEX]
	var grid := {}
	for t in range(0, hi_idx.size(), 3):
		var lo3 := hv[hi_idx[t]].min(hv[hi_idx[t + 1]]).min(hv[hi_idx[t + 2]])
		var hi3 := hv[hi_idx[t]].max(hv[hi_idx[t + 1]]).max(hv[hi_idx[t + 2]])
		var c0 := Vector3i((lo3 / CELL).floor())
		var c1 := Vector3i((hi3 / CELL).floor())
		for x in range(c0.x, c1.x + 1):
			for y in range(c0.y, c1.y + 1):
				for z in range(c0.z, c1.z + 1):
					var c := Vector3i(x, y, z)
					if not grid.has(c):
						grid[c] = []
					(grid[c] as Array).append(t)
	var bs := PackedInt32Array()
	var ws := PackedFloat32Array()
	var cs := PackedColorArray()
	var u2 := PackedVector2Array()
	var far := 0.0
	for v in vs:
		var c := Vector3i((v / CELL).floor())
		var best := -1
		var bd := INF
		var bw := Vector3.ZERO
		for r in 6:
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					for dz in range(-r, r + 1):
						if maxi(absi(dx), maxi(absi(dy), absi(dz))) != r:
							continue
						for t in grid.get(c + Vector3i(dx, dy, dz), []):
							var bary := _closest(v, hv[hi_idx[t]], hv[hi_idx[t + 1]], hv[hi_idx[t + 2]])
							var q: Vector3 = hv[hi_idx[t]] * bary.x + hv[hi_idx[t + 1]] * bary.y + hv[hi_idx[t + 2]] * bary.z
							var d := v.distance_squared_to(q)
							if d < bd:
								bd = d
								best = t
								bw = bary
			if best >= 0 and sqrt(bd) < r * CELL:
				break
		far = maxf(far, sqrt(bd))
		var mix := {}
		for k in 3:
			var hvi := hi_idx[best + k]
			for j in per:
				var b := hb[hvi * per + j]
				mix[b] = float(mix.get(b, 0.0)) + hw[hvi * per + j] * bw[k]
		var order := mix.keys()
		order.sort_custom(func(x, y): return mix[x] > mix[y])
		var total := 0.0
		for j in mini(per, order.size()):
			total += mix[order[j]]
		for j in per:
			bs.append(order[j] if j < order.size() else 0)
			ws.append(mix[order[j]] / total if j < order.size() and total > 0.0 else 0.0)
		if not hu2.is_empty():
			var kk := 0 if bw.x >= bw.y and bw.x >= bw.z else (1 if bw.y >= bw.z else 2)
			u2.append(hu2[hi_idx[best + kk]])
		if not hc.is_empty():
			cs.append(hc[hi_idx[best]] * bw.x + hc[hi_idx[best + 1]] * bw.y + hc[hi_idx[best + 2]] * bw.z)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TEX_UV] = ts
	if not cs.is_empty():
		arr[Mesh.ARRAY_COLOR] = cs
	if not u2.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = u2
	arr[Mesh.ARRAY_BONES] = bs
	arr[Mesh.ARRAY_WEIGHTS] = ws
	arr[Mesh.ARRAY_INDEX] = idx
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_tangents()
	arr = st.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", flags)
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()
	var err := ResourceSaver.save(mesh, a[2])
	print("lod_from_obj: %d triangles, %d vertices, skinned from the detailed surface's %d vertices (at most %.1f mm off it) -> %s %s" % [
		idx.size() / 3, vs.size(), hv.size(), far * 1000.0, a[2], "" if err == OK else "FAILED %d" % err])
	quit(0 if err == OK else 1)


## The barycentric weights of the point of triangle a b c nearest p (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return Vector3(1, 0, 0)
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return Vector3(0, 1, 0)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var t := d1 / (d1 - d3)
		return Vector3(1.0 - t, t, 0)
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return Vector3(0, 0, 1)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var t := d2 / (d2 - d6)
		return Vector3(1.0 - t, 0, t)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var t := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return Vector3(0, 1.0 - t, t)
	var den := 1.0 / (va + vb + vc)
	var v := vb * den
	var w := vc * den
	return Vector3(1.0 - v - w, v, w)
