class_name Geo
extends RefCounted
## Static geometry made in code and merged by material: boxes, cylinders, cones and quads, each coloured by vertex,
## so a whole venue's structure is a handful of draw calls (one per material) however many parts it has. Phones
## like the Galaxy A16 are held back by draw calls far more than by triangles.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var idx := PackedInt32Array()


func _tri_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv := Rect2(0, 0, 1, 1)) -> void:
	# a b c d in order round the face, seen from the side n points to (clockwise is the front in Godot).
	var base := verts.size()
	verts.append_array([a, b, c, d])
	var lin := col.srgb_to_linear()   # colours are written in sRGB; the renderer lights in linear
	for i in 4:
		normals.append(n)
		colors.append(lin)
	uvs.append_array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)])
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## A flat rectangle at height y, from (x0, z0) to (x1, z1), facing up.
func floor_rect(x0: float, z0: float, x1: float, z1: float, y: float, col: Color, uv := Rect2(0, 0, 1, 1)) -> void:
	_tri_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, col, uv)


## A rectangle standing up, from p0 to p1 along the floor, from height y0 to y1, facing n.
func wall(p0: Vector3, p1: Vector3, y0: float, y1: float, col: Color, double := false) -> void:
	var n := (p1 - p0).cross(Vector3.UP).normalized()
	_tri_quad(Vector3(p0.x, y1, p0.z), Vector3(p1.x, y1, p1.z), Vector3(p1.x, y0, p1.z), Vector3(p0.x, y0, p0.z), n, col)
	if double:
		_tri_quad(Vector3(p1.x, y1, p1.z), Vector3(p0.x, y1, p0.z), Vector3(p0.x, y0, p0.z), Vector3(p1.x, y0, p1.z), -n, col)


## A box centred at c, of size s, turned by yaw (radians) about its centre. Its top lighter, its sides as they are.
func box(c: Vector3, s: Vector3, col: Color, yaw := 0.0, shade := true) -> void:
	var b := Basis(Vector3.UP, yaw)
	var h := s * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return c + b * Vector3(x * h.x, y * h.y, z * h.z)
	var top := col.lightened(0.06) if shade else col
	var side := col
	var dark := col.darkened(0.12) if shade else col
	_tri_quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), b * Vector3.UP, top)
	_tri_quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, -1, -1), p.call(-1, -1, -1), b * Vector3.DOWN, dark)
	_tri_quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, -1, 1), p.call(-1, -1, 1), b * Vector3.BACK, side)
	_tri_quad(p.call(1, 1, -1), p.call(-1, 1, -1), p.call(-1, -1, -1), p.call(1, -1, -1), b * Vector3.FORWARD, side)
	_tri_quad(p.call(1, 1, 1), p.call(1, 1, -1), p.call(1, -1, -1), p.call(1, -1, 1), b * Vector3.RIGHT, dark)
	_tri_quad(p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(-1, -1, 1), p.call(-1, -1, -1), b * Vector3.LEFT, dark)


## A cylinder (or a cone, r1 0) from a to b.
func cylinder(a: Vector3, b: Vector3, r0: float, r1: float, col: Color, seg := 8, caps := true) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	for i in seg:
		var t0 := TAU * i / seg
		var t1 := TAU * (i + 1) / seg
		var d0 := side * cos(t0) + fwd * sin(t0)
		var d1 := side * cos(t1) + fwd * sin(t1)
		var n := (d0 + d1).normalized()
		_tri_quad(b + d1 * r1, b + d0 * r1, a + d0 * r0, a + d1 * r0, n, col)
		if caps and r1 > 0.0:
			var base := verts.size()
			verts.append_array([b, b + d1 * r1, b + d0 * r1])
			for k in 3:
				normals.append(up)
				colors.append(col.lightened(0.05).srgb_to_linear())
				uvs.append(Vector2.ZERO)
			idx.append_array([base, base + 1, base + 2])


## A flat ring on the floor (a painted circle line): radii r0 to r1, from angle a0 to a1 (radians, from +x toward +z).
func ring(c: Vector3, r0: float, r1: float, a0: float, a1: float, col: Color, seg := 24) -> void:
	for i in seg:
		var t0 := lerpf(a0, a1, float(i) / seg)
		var t1 := lerpf(a0, a1, float(i + 1) / seg)
		var d0 := Vector3(cos(t0), 0, sin(t0))
		var d1 := Vector3(cos(t1), 0, sin(t1))
		_tri_quad(c + d0 * r1, c + d1 * r1, c + d1 * r0, c + d0 * r0, Vector3.UP, col)


## A rough ball of leaves or a bush: a squashed octahedron-ish blob.
func blob(c: Vector3, r: Vector3, col: Color) -> void:
	var pts := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	var top := c + Vector3(0, r.y, 0)
	var bot := c - Vector3(0, r.y * 0.6, 0)
	for i in 4:
		var a: Vector3 = c + pts[i] * Vector3(r.x, 0, r.z)
		var b: Vector3 = c + pts[(i + 1) % 4] * Vector3(r.x, 0, r.z)
		var n := (a + b - c * 2.0).normalized() + Vector3.UP * 0.6
		_tri_quad(top, b, a, top, n.normalized(), col.lightened(0.05))
		_tri_quad(a, b, bot, bot, (n - Vector3.UP * 1.2).normalized(), col.darkened(0.15))


static var _ico: Array = []   # [vertices, triangles] of a unit icosphere (80 faces)


static func _icosphere() -> Array:
	if not _ico.is_empty():
		return _ico
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		v[i] = (v[i] as Vector3).normalized()
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
		[7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var mid := {}
	var g := func(a: int, b: int) -> int:
		var k := Vector2i(mini(a, b), maxi(a, b))
		if mid.has(k):
			return mid[k]
		v.append(((v[a] as Vector3) + (v[b] as Vector3)).normalized())
		mid[k] = v.size() - 1
		return v.size() - 1
	var f2: Array = []
	for tri in f:
		var a: int = g.call(tri[0], tri[1])
		var b: int = g.call(tri[1], tri[2])
		var c: int = g.call(tri[2], tri[0])
		f2.append_array([[tri[0], a, c], [tri[1], b, a], [tri[2], c, b], [a, b, c]])
	_ico = [v, f2]
	return _ico


## A rounded mass of leaves (or a bush, a haystack, a hill): an 80-face sphere squashed to radii r, smooth-shaded,
## lighter on top and darker beneath, its surface a little lumpy so it does not look turned on a lathe.
func ball(c: Vector3, r: Vector3, col: Color, lumpy := 0.12, seed_ := 0) -> void:
	var ico := _icosphere()
	var v: Array = ico[0]
	var base := verts.size()
	for i in v.size():
		var d: Vector3 = v[i]
		var k := 1.0 + lumpy * sin(d.x * 7.1 + seed_ * 1.7) * sin(d.y * 6.3 + seed_) * sin(d.z * 5.7 + seed_ * 0.6)
		verts.append(c + d * r * k)
		normals.append((d / r).normalized())
		var shade := clampf(0.78 + 0.32 * (d.y * 0.5 + 0.5), 0.6, 1.12)
		colors.append(Color(col.r * shade, col.g * shade, col.b * shade).srgb_to_linear())
		uvs.append(Vector2(d.x, d.z))
	for tri in ico[1]:
		idx.append_array([base + tri[0], base + tri[2], base + tri[1]])


## A roof ridge: a triangular prism along x, centred at c, width w across z, length l, peak h above c.
func prism(c: Vector3, l: float, w: float, h: float, col: Color, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hl := l * 0.5
	var hw := w * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return c + b * Vector3(x, y, z)
	var n1 := b * Vector3(0, hw, h).normalized()
	var n2 := b * Vector3(0, hw, -h).normalized()
	_tri_quad(p.call(-hl, h, 0), p.call(hl, h, 0), p.call(hl, 0, hw), p.call(-hl, 0, hw), n1, col)
	_tri_quad(p.call(hl, h, 0), p.call(-hl, h, 0), p.call(-hl, 0, -hw), p.call(hl, 0, -hw), n2, col.darkened(0.1))
	for sx: float in [-1.0, 1.0]:
		var base := verts.size()
		verts.append_array([p.call(sx * hl, h, 0), p.call(sx * hl, 0, -hw * sx), p.call(sx * hl, 0, hw * sx)])
		for k in 3:
			normals.append(b * Vector3(sx, 0, 0))
			colors.append(col.darkened(0.2).srgb_to_linear())
			uvs.append(Vector2.ZERO)
		idx.append_array([base, base + 1, base + 2])


## The sky: a dome of radius r over the place, coloured from the horizon up, with a glow toward sun_dir.
func dome(r: float, horizon: Color, top: Color, glow: Color, sun_dir: Vector3, rings := 7, seg := 24) -> void:
	var sd := Vector3(sun_dir.x, 0, sun_dir.z).normalized()
	for i in rings:
		var e0 := PI * 0.5 * float(i) / rings
		var e1 := PI * 0.5 * float(i + 1) / rings
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var pts := [[e0, a0], [e0, a1], [e1, a1], [e1, a0]]
			var base := verts.size()
			for q in pts:
				var e: float = q[0]
				var a: float = q[1]
				var d := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e))
				verts.append(d * r - Vector3(0, r * 0.04, 0))
				normals.append(-d)
				var k := pow(sin(e), 0.6)
				var c := horizon.lerp(top, k)
				var g := maxf(0.0, d.dot(sd)) * (1.0 - k)
				colors.append(c.lerp(glow, g * g * 0.8).srgb_to_linear())
				uvs.append(Vector2.ZERO)
			idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func commit(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if verts.is_empty():
		return mi
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The material for vertex-coloured structure: lit per vertex (cheap), or unshaded for things that glow.
static func material(lit := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 0.9
	return m
