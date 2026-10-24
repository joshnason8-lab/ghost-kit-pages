class_name Geo
extends RefCounted
## Builds merged static geometry: everything of one material added to one SurfaceTool and drawn as one mesh (one draw
## call), with UVs from world position so a photographed surface tiles at its real size (one tile about tile metres).

var st := SurfaceTool.new()
var tile := 2.5
var tint := Color.WHITE
var _n := 0


func _init(p_tile := 2.5) -> void:
	tile = p_tile
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _uv(p: Vector3, n: Vector3) -> Vector2:
	# Project on the plane the face mostly faces.
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) / tile
	if a.x >= a.z:
		return Vector2(p.z, -p.y) / tile
	return Vector2(p.x, -p.y) / tile


## A flat four-cornered face a, b, c, d (counter-clockwise seen from its front).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col := Color(-1, 0, 0)) -> void:
	var n := (b - a).cross(c - a).normalized()
	var cc := tint if col.r < 0.0 else col
	# Godot's front faces wind clockwise as seen: the corners are given the other way round.
	for p in [a, c, b, a, d, c]:
		st.set_normal(n)
		st.set_color(cc)
		st.set_uv(_uv(p, n))
		st.add_vertex(p)
	_n += 2


## A box from its centre and size (no bottom face).
func box(c: Vector3, s: Vector3, col := Color(-1, 0, 0), bottom := false) -> void:
	var h := s * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return c + Vector3(x * h.x, y * h.y, z * h.z)
	quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), col)       # top
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col)       # +z
	quad(p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), col)   # -z
	quad(p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), col)       # +x
	quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col)   # -x
	if bottom:
		quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col)


## A box turned yaw radians about y.
func box_turned(c: Vector3, s: Vector3, yaw: float, col := Color(-1, 0, 0)) -> void:
	var h := s * 0.5
	var b := Basis(Vector3.UP, yaw)
	var p := func(x: float, y: float, z: float) -> Vector3: return c + b * Vector3(x * h.x, y * h.y, z * h.z)
	quad(p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), col)
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col)
	quad(p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), col)
	quad(p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), col)
	quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col)


## A ring like a washer: around axis x through c, holes radius ri, outer ro, half-thickness hd.
func washer(c: Vector3, ri: float, ro: float, hd: float, seg := 24, col := Color(-1, 0, 0)) -> void:
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var d0 := Vector3(0, cos(a0), sin(a0))
		var d1 := Vector3(0, cos(a1), sin(a1))
		var f := Vector3(hd, 0, 0)
		# Front and back faces.
		quad(c + f + d0 * ri, c + f + d0 * ro, c + f + d1 * ro, c + f + d1 * ri, col)
		quad(c - f + d1 * ri, c - f + d1 * ro, c - f + d0 * ro, c - f + d0 * ri, col)
		# Outside and inside.
		quad(c - f + d0 * ro, c - f + d1 * ro, c + f + d1 * ro, c + f + d0 * ro, col)
		quad(c + f + d0 * ri, c + f + d1 * ri, c - f + d1 * ri, c - f + d0 * ri, col)


func triangles() -> int:
	return _n


func commit() -> ArrayMesh:
	st.generate_tangents()
	return st.commit()


## A material for a photographed surface (assets/env/surfaces/NAME_albedo_512.jpg and its normal map): the normal map on
## Medium and High only, per-vertex light on Low.
static func surface(name: String, tint_col := Color.WHITE, rough := 0.9) -> StandardMaterial3D:
	var g := int(Game.settings.graphics)
	var m := StandardMaterial3D.new()
	var dir := "res://assets/env/surfaces/"
	# Low: the 512 maps as they always were. Medium and High: the same Poly Haven surfaces at 1K and 2K, VRAM-compressed
	# (ETC2 on phones) with mipmaps, so they are sharper up close and no heavier on video memory than they need be.
	var res := "512"
	if g == Game.GFX_MEDIUM and ResourceLoader.exists(dir + name + "_albedo_1k.jpg"):
		res = "1k"
	elif g >= Game.GFX_HIGH and ResourceLoader.exists(dir + name + "_albedo_2k.jpg"):
		res = "2k"
	m.albedo_texture = load(dir + name + "_albedo_" + res + ".jpg")
	m.albedo_color = tint_col
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if g > Game.GFX_LOW else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The normal maps at 1K on High too: at a match's distance their extra detail does not show, and compressed for
	# phones a 2K normal map is twice an albedo's size.
	var nres := "1k" if res == "2k" else res
	if g > Game.GFX_LOW and ResourceLoader.exists(dir + name + "_normal_" + nres + ".jpg"):
		m.normal_enabled = true
		m.normal_texture = load(dir + name + "_normal_" + nres + ".jpg")
		m.normal_scale = 0.8
	if g == Game.GFX_LOW:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m
