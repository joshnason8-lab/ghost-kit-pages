extends SceneTree
## The officials on the hurlers' own body (the owner: "can we use the player model for them?"): the HD hurler's model
## from the collar down, with an official's own head and neck (the referee's for the referee and the linesmen, the
## umpire's, cap and all, for the umpires) in place of the hurler's helmeted one - no helmet on an official. The
## result is one mesh of two surfaces on the hurler's rig (assets/foundation/<who>_body_hd_{hi,lo}.res and its
## _rig.json): 0 the body (the hurler's kit material, in the official's colours), 1 the head (the official's own
## texture). The head's points follow their bones from the official's rig to the hurler's (each point moved as its
## bones' joints are moved), so the neck meets the collar. Both are the owner's and Meshy's models: fine to commit.
##   godot --headless --path . -s res://tools/player/official_body.gd

const DIR := "res://assets/foundation/"

var _mask: Image
var _tex: Image
var _cloth := {}
## The official's head is its points weighted to the head bone past this (its face, hair and cap, not its collar);
## the hurler keeps his neck (its skin, to the jaw) and loses his head, and with it everything on his head and neck
## that is not skin or kit (the helmet, its strap and the faceguard: the kit mask's empty parts).
const HEAD_W := 0.45
const NECK_Y := 1.48
## The official's neck made the hurler's: wider and longer below the head's joint.
const NECK_WIDEN := 1.18
const NECK_LONGER := 1.25
const THROAT := 1.35


func _init() -> void:
	var hero_j := _joints("hero_hd")
	for who in ["referee", "umpire"]:
		var off_j := _joints(who + "_hd")
		for lod in ["hi", "lo"]:
			var body: ArrayMesh = load(DIR + "hero_hd_%s.res" % lod)
			var head: ArrayMesh = load(DIR + who + "_hd_%s.res" % lod)
			var out := ArrayMesh.new()
			var kept := _cut(body, false, {}, {})
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, kept[0], [], kept[1])
			_tex = (load(DIR + who + "_hd_albedo.jpg") as Texture2D).get_image()
			if _tex.is_compressed():
				_tex.decompress()
			var h := _cut(head, true, off_j, hero_j)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, h[0], [], h[1])
			var aabb := body.get_aabb()
			out.custom_aabb = body.custom_aabb if body.custom_aabb.size != Vector3.ZERO else aabb.grow(0.1)
			var path := DIR + "%s_body_hd_%s.res" % [who, lod]
			var err := ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
			print("%s: body %d + head %d triangles (%s)" % [path, (kept[0][Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3,
				(h[0][Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, error_string(err)])
		# The rig: the hurler's.
		var f := FileAccess.open(DIR + who + "_body_hd_rig.json", FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(DIR + "hero_hd_rig.json"))
	quit()


func _joints(prefix: String) -> Dictionary:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + prefix + "_rig.json"))
	var j := {}
	for k in meta.joints:
		j[k] = Vector3(meta.joints[k][0], meta.joints[k][1], meta.joints[k][2])
	return j


## The surface's triangles that are the head's (head: true) or the rest (false), with its points that are used, and
## its levels of detail cut the same way. Head points moved from the rig `from` to `to` (each by its bones' moves).
func _cut(mesh: ArrayMesh, head: bool, from: Dictionary, to: Dictionary) -> Array:
	var a := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	if _mask == null:
		_mask = (load(DIR + "hero_hd_mask.png") as Texture2D).get_image()
		if _mask.is_compressed():
			_mask.decompress()
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / vs.size()
	var headb := WsgRig.BONES.map(func(b): return b[0]).find("Head")
	var neckb := WsgRig.BONES.map(func(b): return b[0]).find("Neck")
	var is_head := PackedByteArray()
	is_head.resize(vs.size())
	for i in vs.size():
		var w := 0.0
		for k in per:
			if bones[i * per + k] == headb:
				w += ws[i * per + k]
		var on := w > HEAD_W
		if head:
			# The official's: its neck too (inside the hurler's thicker one, up to its own jaw: no gap), not its collar
			# (the shirt's colour: the referee's black, the umpire's white below the cap).
			var wn := w
			for k in per:
				if bones[i * per + k] == neckb:
					wn += ws[i * per + k]
			var c := _tex.get_pixelv(Vector2i((uv[i] * Vector2(_tex.get_size())).clamp(Vector2.ZERO, Vector2(_tex.get_size() - Vector2i.ONE))))
			var hj: Vector3 = from["Head"]
			var below := vs[i].y < hj.y
			var cloth := below and (c.get_luminance() < 0.1 or (c.s < 0.1 and c.v > 0.8))
			# (Nor a collar's flap standing out from the neck.)
			var flap := below and Vector2(vs[i].x - hj.x, vs[i].z - hj.z).length() > 0.07
			on = wn > 0.1 and not flap
			if on and cloth:
				_cloth[i] = true
		elif vs[i].y > NECK_Y:
			var m := _mask.get_pixelv(Vector2i((uv[i] * Vector2(_mask.get_size())).clamp(Vector2.ZERO, Vector2(_mask.get_size() - Vector2i.ONE))))
			on = on or m.r + m.g + m.b + m.a < 0.5
		is_head[i] = 1 if on else 0
	# The levels of detail (index lists by edge length).
	var lists := {"": a[Mesh.ARRAY_INDEX]}
	var sd := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var wide := vs.size() > 65535
	for l: Dictionary in sd.get("lods", []):
		var by: PackedByteArray = l.index_data
		var ix := PackedInt32Array()
		ix.resize(by.size() / (4 if wide else 2))
		for k in ix.size():
			ix[k] = by.decode_u32(k * 4) if wide else by.decode_u16(k * 2)
		lists[float(l.edge_length)] = ix
	# A triangle is the head's when most of its points are.
	var keep_v := {}
	var cut := {}
	for key in lists:
		var ix: PackedInt32Array = lists[key]
		var o := PackedInt32Array()
		for t in ix.size() / 3:
			var n := is_head[ix[t * 3]] + is_head[ix[t * 3 + 1]] + is_head[ix[t * 3 + 2]]
			# (The hurler's: every triangle that touches his head or the helmet's strap goes - it hung in shards.)
			if (n >= 2) if head else (n == 0):
				for k in 3:
					o.append(ix[t * 3 + k])
					keep_v[ix[t * 3 + k]] = true
		cut[key] = o
	# Only the points used, renumbered.
	var order: Array = keep_v.keys()
	order.sort()
	var remap := {}
	for n in order.size():
		remap[order[n]] = n
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for c in Mesh.ARRAY_MAX:
		var src: Variant = a[c]
		if src == null or c == Mesh.ARRAY_INDEX:
			continue
		var width: int = (int(src.size()) / vs.size()) if src.size() > 0 else 0
		var dst: Variant = src.duplicate()
		dst.resize(order.size() * width)
		for n in order.size():
			for k in width:
				dst[n * width + k] = src[int(order[n]) * width + k]
		out[c] = dst
	if head:
		var nv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
		var nb: PackedInt32Array = out[Mesh.ARRAY_BONES]
		var nw: PackedFloat32Array = out[Mesh.ARRAY_WEIGHTS]
		for n in nv.size():
			var move := Vector3.ZERO
			var tw := 0.0
			for k in per:
				var b := String(WsgRig.BONES[nb[n * per + k]][0])
				var w := nw[n * per + k]
				if w > 0.0 and from.has(b) and to.has(b):
					move += ((to[b] as Vector3) - (from[b] as Vector3)) * w
					tw += w
			nv[n] += move / maxf(tw, 1e-6) if tw > 0.0 else Vector3.ZERO
			# The neck as thick as the hurler's and down into his collar (his throat was under the helmet's strap: none).
			var hj: Vector3 = to["Head"]
			if nv[n].y < hj.y:
				var r := Vector2(nv[n].x - hj.x, nv[n].z - hj.z) * NECK_WIDEN
				# (The hurler's throat stands further forward of his neck's joint than an official's does.)
				if r.y > 0.0:
					r.y *= lerpf(1.0, THROAT, clampf((hj.y - nv[n].y) / 0.08, 0.0, 1.0))
				var y := hj.y - (hj.y - nv[n].y) * NECK_LONGER
				nv[n] = Vector3(hj.x + r.x, y, hj.z + r.y)
		out[Mesh.ARRAY_VERTEX] = nv
		# The collar on the official's neck (the referee's buttoned up to the throat) painted as the nearest skin of it.
		var nuv: PackedVector2Array = out[Mesh.ARRAY_TEX_UV]
		for n in nv.size():
			if not _cloth.has(int(order[n])):
				continue
			var best := INF
			for m in nv.size():
				if not _cloth.has(int(order[m])) and nv[m].y < float((to["Head"] as Vector3).y) + 0.04:
					var d := nv[m].distance_squared_to(nv[n])
					if d < best:
						best = d
						nuv[n] = nuv[m]
		out[Mesh.ARRAY_TEX_UV] = nuv
		_cloth.clear()
	var lods := {}
	for key in cut:
		var o := PackedInt32Array()
		for v in (cut[key] as PackedInt32Array):
			o.append(remap[v])
		if key is String:
			out[Mesh.ARRAY_INDEX] = o
		elif o.size() > 0:
			lods[key] = o
	return [out, lods]
