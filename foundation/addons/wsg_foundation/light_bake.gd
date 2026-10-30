class_name WsgLightBake
extends RefCounted
## Baked light for a game's own built geometry (stands, walls, roofs: flat-shaded faces, each quad its own four
## vertices), for the phones that light per vertex without shadows (GL Compatibility, Low and Medium): the sun's and
## sky's light, the roof's shadow on the seats, the corners' occlusion, the stands' shadow on the pitch, baked in
## Blender's Cycles (tools/blender/bake_light.py) and drawn for the cost of one texture read.
##   at bake time (tools/blender/README.md):  WsgLightBake.export(mesh, light, "res://.../arena")  -> OBJ + JSON
##   at run time:  var lm := WsgLightBake.load_for(mesh, "res://.../arena_day")   # null: none, or not this geometry
##                 if lm: mi.mesh = lm.mesh; mi.material_override = lm.material(...)
## The second UVs are made here, the same at bake and at run time (each face its own patch, packed in rows), so a
## game ships only the light map and a signature of the geometry it was baked for.

## Texels between patches (the bake bleeds into them; filtering never reaches the next face).
const PAD := 2
## A face's patch is never smaller than this, in texels.
const MIN_TEXELS := 2


## mesh with a second UV set: each quad (four vertices, two triangles) or lone triangle its own patch, laid flat in
## its own plane and packed into a size x size map. Returns [mesh, texel size (m)].
static func unwrap(mesh: ArrayMesh, size := 2048, surface := 0) -> Array:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var charts := _charts(verts, idx)
	# The texel size that fills about 70% of the map (padding and rows waste the rest), then smaller until it fits.
	var area := 0.0
	for c in charts:
		area += (c[2] as Vector2).x * (c[2] as Vector2).y
	var texel := sqrt(area / (0.7 * size * size)) if area > 0.0 else 1.0
	var placed := []
	for attempt in 12:
		placed = _pack(charts, texel, size)
		if not placed.is_empty():
			break
		texel *= 1.1
	var uv2 := PackedVector2Array()
	uv2.resize(verts.size())
	for i in charts.size():
		var c: Array = charts[i]
		var at: Vector2 = placed[i]
		var ids: Array = c[0]
		var flat: Array = c[1]
		for k in ids.size():
			uv2[ids[k]] = (at + (flat[k] as Vector2) / texel) / float(size)
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [out, texel]


## The faces: [vertex ids, their places flat in the face's plane (from its corner), the patch's size (m)].
static func _charts(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var out := []
	var i := 0
	while i < idx.size():
		var ids: Array = [idx[i], idx[i + 1], idx[i + 2]]
		# Geo's quads: a b c, a c d (four vertices of their own).
		if i + 5 < idx.size() and idx[i + 3] == idx[i] and idx[i + 4] == idx[i + 2]:
			ids.append(idx[i + 5])
			i += 6
		else:
			i += 3
		var a: Vector3 = verts[ids[0]]
		var u := Vector3.ZERO
		for k in range(1, ids.size()):
			if (verts[ids[k]] - a).length() > 1e-5:
				u = (verts[ids[k]] - a).normalized()
				break
		var n := Vector3.ZERO
		for k in range(1, ids.size() - 1):
			n += (verts[ids[k]] - a).cross(verts[ids[k + 1]] - a)
		if u == Vector3.ZERO or n.length() < 1e-8:
			u = Vector3.RIGHT
			n = Vector3.UP
		n = n.normalized()
		var v := n.cross(u).normalized()
		var flat := []
		var lo := Vector2(INF, INF)
		var hi := -lo
		for k in ids.size():
			var d: Vector3 = verts[ids[k]] - a
			var p := Vector2(d.dot(u), d.dot(v))
			flat.append(p)
			lo = lo.min(p)
			hi = hi.max(p)
		for k in flat.size():
			flat[k] = (flat[k] as Vector2) - lo
		out.append([ids, flat, hi - lo])
	return out


## Each chart's corner in the map (texels), in rows tallest first; empty if they do not fit.
static func _pack(charts: Array, texel: float, size: int) -> Array:
	var order := range(charts.size())
	var dims := []
	for c in charts:
		var s: Vector2 = c[2]
		dims.append(Vector2i(maxi(MIN_TEXELS, ceili(s.x / texel)), maxi(MIN_TEXELS, ceili(s.y / texel))))
	order.sort_custom(func(a, b): return dims[a].y > dims[b].y or dims[a].y == dims[b].y and a < b)
	var at := []
	at.resize(charts.size())
	var x := PAD
	var y := PAD
	var row := 0
	for i in order:
		var d: Vector2i = dims[i]
		if x + d.x + PAD > size:
			x = PAD
			y += row + PAD
			row = 0
		if y + d.y + PAD > size or d.x + 2 * PAD > size:
			return []
		at[i] = Vector2(x, y)
		x += d.x + PAD
		row = maxi(row, d.y)
	return at


## A number that changes when the geometry does (its vertices, to the millimetre): a light map is used only on the
## geometry it was baked for.
static func signature(mesh: ArrayMesh, surface := 0) -> int:
	var verts: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	var h := verts.size()
	for i in range(0, verts.size(), maxi(1, verts.size() / 4096)):
		var p: Vector3 = verts[i]
		h = hash([h, roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)])
	return h


## For the bake: the unwrapped mesh as OBJ (the second UVs as its UVs, Y up as Godot's) and the light as JSON.
## light: {"sun_dir": to the sun, "sun_colour": [r,g,b], "sun_energy", "sky_colour": [r,g,b], "sky_energy",
## "spots": [[position, aimed at, colour, energy, angle deg, range]], "ground": [x0, z0, x1, z1, y] (a ground the
## built geometry shades: the pitch), "size": map size}. Writes <base>.obj and <base>.json; returns the signature.
static func export(mesh: ArrayMesh, light: Dictionary, base: String) -> int:
	var size := int(light.get("size", 2048))
	var un := unwrap(mesh, size)
	var m: ArrayMesh = un[0]
	var a := m.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var f := FileAccess.open(base + ".obj", FileAccess.WRITE)
	f.store_line("o built")
	for p in verts:
		f.store_line("v %f %f %f" % [p.x, p.y, p.z])
	for t in uv2:
		f.store_line("vt %f %f" % [t.x, 1.0 - t.y])
	for n in norms:
		f.store_line("vn %f %f %f" % [n.x, n.y, n.z])
	# (Godot's triangles are clockwise from the front; OBJ's counter-clockwise.)
	for i in range(0, idx.size(), 3):
		var t := [idx[i] + 1, idx[i + 2] + 1, idx[i + 1] + 1]
		f.store_line("f %d/%d/%d %d/%d/%d %d/%d/%d" % [t[0], t[0], t[0], t[1], t[1], t[1], t[2], t[2], t[2]])
	f.close()
	var sig := signature(mesh)
	var info := light.duplicate()
	info["signature"] = sig
	info["texel"] = un[1]
	info["size"] = size
	var j := FileAccess.open(base + ".json", FileAccess.WRITE)
	j.store_string(JSON.stringify(info, "\t"))
	j.close()
	return sig


## The baked light for mesh, if there is one and it was baked for this geometry: {"mesh": the mesh with its second
## UVs, "light": the built geometry's light map, "ground": the ground's (or null), "ground_rect": [x0, z0, x1, z1],
## "scale": what the maps' values are multiplied by}. base: "res://.../<arena>_<time>" (base.json beside
## base_light.png and base_ground.png).
static func load_for(mesh: ArrayMesh, base: String) -> Dictionary:
	if mesh == null or not FileAccess.file_exists(base + ".json") or _texture(base + "_light.png") == null:
		return {}
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if not info is Dictionary or int((info as Dictionary).get("signature", 0)) != signature(mesh):
		return {}
	var un := unwrap(mesh, int(info.size))
	var g: Array = info.get("ground", [])
	return {"mesh": un[0], "light": _texture(base + "_light.png"), "ground": _texture(base + "_ground.png"),
		"ground_rect": g, "scale": float(info.get("scale", 2.0))}


## An imported texture, or a PNG as it is (user://: a map downloaded or baked on the device); null if neither.
static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


## A material for the built geometry under its light map: its vertex colours times the baked light, nothing lit at
## run time (the cheapest there is). srgb: the vertex colours are sRGB (the Vulkan renderer's convention).
static func material(lm: Dictionary, srgb := false) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D light : filter_linear, repeat_disable;
uniform float scale = 2.0;
uniform bool srgb = false;
void fragment() {
	vec3 c = srgb ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb;
	ALBEDO = c * texture(light, UV2).rgb * scale;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("light", lm.light)
	m.set_shader_parameter("scale", lm.scale)
	m.set_shader_parameter("srgb", srgb)
	return m
