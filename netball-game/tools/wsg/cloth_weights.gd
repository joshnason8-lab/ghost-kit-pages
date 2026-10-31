extends SceneTree
## Loose clothes skinned as the body under them (a coat's sides, a jacket's hem): the vertices a character's arms
## should not move - anything farther from an arm's line than a sleeve - lose their arm weights and take a
## well-skinned body's instead (the proxy: another foundation character in the same T, e.g. the game's player),
## from the nearest point of its surface, without its arm bones. A raised arm then lifts its sleeve, not the coat's
## side like a wing. Rewrites <prefix>_hi.res and <prefix>_lo.res in place.
##   godot --headless --path <project> -s <this> -- <char dir> <prefix> <proxy hi.res> [sleeve_in 0.10] [sleeve_out 0.16]
## sleeve_in / sleeve_out: within the first of an arm's line (m) a vertex keeps its own weights, beyond the second it
## has the proxy's, between them a blend.

const CELL := 0.05


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var prefix: String = a[1]
	var proxy := load(a[2]) as ArrayMesh
	var r_in := float(a[3]) if a.size() > 3 else 0.10
	var r_out := float(a[4]) if a.size() > 4 else 0.16
	var joints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(prefix + "_rig.json"))).joints
	var names := []
	for b in WsgRig.BONES:
		names.append(b[0])
	var arm_bones := {}
	for i in names.size():
		for side in ["Left", "Right"]:
			for part in ["Arm", "ForeArm", "Hand", "ElbowHelper", "ShoulderHelper"]:
				if String(names[i]).begins_with(side + part):
					arm_bones[i] = side
	var pa := proxy.surface_get_arrays(0)
	var grid := _grid(pa)
	for lod in ["hi", "lo"]:
		var path := dir.path_join("%s_%s.res" % [prefix, lod])
		var mesh := load(path) as ArrayMesh
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bs.size() / vs.size()
		var changed := 0
		var moved := 0.0
		for v in vs.size():
			var p := vs[v]
			# How far outside a sleeve: the distance from the nearer arm's line (shoulder joint outwards; inside the
			# chest, the distance to the shoulder joint).
			var s := 0.0
			var on_arm := 0.0
			for j in per:
				if arm_bones.has(bs[v * per + j]):
					on_arm += ws[v * per + j]
			if on_arm <= 0.0:
				continue
			var side := "Left" if p.x > 0.0 else "Right"
			var sh := _v(joints[side + "Arm"])
			var hand := _v(joints[side + "Hand"])
			var d := _to_segment(p, sh, hand + (hand - sh).normalized() * 0.25)
			s = clampf((d - r_in) / (r_out - r_in), 0.0, 1.0)
			if s <= 0.0:
				continue
			var want := _from_proxy(p, pa, grid, arm_bones)
			var mix := {}
			for j in per:
				var b := bs[v * per + j]
				mix[b] = float(mix.get(b, 0.0)) + ws[v * per + j] * (1.0 - s)
			for b in want:
				mix[b] = float(mix.get(b, 0.0)) + float(want[b]) * s
			var order := mix.keys()
			order.sort_custom(func(x, y): return mix[x] > mix[y])
			var total := 0.0
			for j in mini(per, order.size()):
				total += mix[order[j]]
			for j in per:
				bs[v * per + j] = order[j] if j < order.size() else 0
				ws[v * per + j] = mix[order[j]] / total if j < order.size() and total > 0.0 else 0.0
			changed += 1
			moved = maxf(moved, on_arm * s)
		arr[Mesh.ARRAY_BONES] = bs
		arr[Mesh.ARRAY_WEIGHTS] = ws
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
		im.generate_lods(25.0, 60.0, [])
		var out := im.get_mesh()
		var err := ResourceSaver.save(out, path)
		print("cloth_weights: %s: %d of %d vertices off the arms (by up to %.0f%% of their weight) %s" % [
			path.get_file(), changed, vs.size(), moved * 100.0, "" if err == OK else "FAILED %d" % err])
	quit()


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _grid(pa: Array) -> Dictionary:
	var hv: PackedVector3Array = pa[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = pa[Mesh.ARRAY_INDEX]
	var grid := {}
	for t in range(0, idx.size(), 3):
		var lo := hv[idx[t]].min(hv[idx[t + 1]]).min(hv[idx[t + 2]])
		var hi := hv[idx[t]].max(hv[idx[t + 1]]).max(hv[idx[t + 2]])
		var c0 := Vector3i((lo / CELL).floor())
		var c1 := Vector3i((hi / CELL).floor())
		for x in range(c0.x, c1.x + 1):
			for y in range(c0.y, c1.y + 1):
				for z in range(c0.z, c1.z + 1):
					var c := Vector3i(x, y, z)
					if not grid.has(c):
						grid[c] = []
					(grid[c] as Array).append(t)
	return grid


## The proxy's skin at the nearest point of its surface to p, without the arm bones: {bone: weight}, summing to 1.
static func _from_proxy(p: Vector3, pa: Array, grid: Dictionary, arm_bones: Dictionary) -> Dictionary:
	var hv: PackedVector3Array = pa[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = pa[Mesh.ARRAY_INDEX]
	var hb: PackedInt32Array = pa[Mesh.ARRAY_BONES]
	var hw: PackedFloat32Array = pa[Mesh.ARRAY_WEIGHTS]
	var per := hb.size() / hv.size()
	var c := Vector3i((p / CELL).floor())
	var best := -1
	var bd := INF
	var bw := Vector3.ZERO
	for r in 12:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(absi(dx), maxi(absi(dy), absi(dz))) != r:
						continue
					for t in grid.get(c + Vector3i(dx, dy, dz), []):
						# Not the proxy's own arms (a coat's side is nearest the arm hanging by it in some bodies).
						var on_arm := false
						for k in 3:
							for j in per:
								if hw[idx[t + k] * per + j] > 0.5 and arm_bones.has(hb[idx[t + k] * per + j]):
									on_arm = true
						if on_arm:
							continue
						var bary := _closest(p, hv[idx[t]], hv[idx[t + 1]], hv[idx[t + 2]])
						var q: Vector3 = hv[idx[t]] * bary.x + hv[idx[t + 1]] * bary.y + hv[idx[t + 2]] * bary.z
						var d := p.distance_squared_to(q)
						if d < bd:
							bd = d
							best = t
							bw = bary
		if best >= 0 and sqrt(bd) < r * CELL:
			break
	var mix := {}
	var total := 0.0
	for k in 3:
		for j in per:
			var b := hb[idx[best + k] * per + j]
			if arm_bones.has(b):
				continue
			var w := hw[idx[best + k] * per + j] * bw[k]
			mix[b] = float(mix.get(b, 0.0)) + w
			total += w
	for b in mix:
		mix[b] = mix[b] / maxf(total, 1e-6)
	return mix


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
