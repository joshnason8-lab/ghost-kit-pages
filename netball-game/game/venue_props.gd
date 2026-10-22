class_name VenueProps
extends RefCounted
## A venue's models (benches, lamps, trees, houses: the shared assets baked by tools/venue/bake.gd) placed many times
## and merged into one mesh with one texture atlas, so however many there are they cost one draw call. On Low each
## model is its _low version where it has one, and trees are cut-outs.

var _src: ArrayMesh
var _names := {}          # model name -> surface index in _src
var _low := false
var _arrays := {}         # model name -> [vertices, normals, uvs, uv2s, indices] of the source, read once
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var idx := PackedInt32Array()
var venue := ""


func _init(p_venue: String, low: bool) -> void:
	venue = p_venue
	_low = low
	var path := "res://assets/venue/%s_props.res" % venue
	if ResourceLoader.exists(path):
		_src = load(path)
		for i in _src.get_surface_count():
			_names[_src.surface_get_name(i)] = i


func has(name: String) -> bool:
	return _names.has(name)


## The model name to draw at this graphics level: its _low version on Low, if it has one.
func pick(name: String) -> String:
	if _low and _names.has(name + "_low"):
		return name + "_low"
	return name


## Places a model (by name; its _low version on Low) at xf, its colour multiplied by tint.
func add(name: String, xf: Transform3D, tint := Color.WHITE) -> void:
	var n := pick(name)
	if not _names.has(n):
		return
	if not _arrays.has(n):
		_arrays[n] = _src.surface_get_arrays(_names[n])
	var a: Array = _arrays[n]
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var base := verts.size()
	var lin := tint.srgb_to_linear()
	for i in v.size():
		verts.append(xf * v[i])
		normals.append((xf.basis * nm[i]).normalized())
		colors.append(lin)
	uvs.append_array(a[Mesh.ARRAY_TEX_UV])
	uv2s.append_array(a[Mesh.ARRAY_TEX_UV2])
	var src_idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for i in src_idx:
		idx.append(base + i)


## Places a model standing at p (on the floor), turned yaw radians, scaled by s.
func put(name: String, p: Vector3, yaw := 0.0, s := 1.0, tint := Color.WHITE) -> void:
	add(name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p), tint)


func triangles() -> int:
	return idx.size() / 3


func commit(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Props"
	if verts.is_empty():
		return mi
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The material for a venue's props: the atlas (and the cut-outs' atlas), lit, rough, with the venue's fade.
func material() -> ShaderMaterial:
	var m := VenueLook.props(_low)
	m.set_shader_parameter("atlas", load("res://assets/venue/%s_atlas.jpg" % venue))
	var cards := "res://assets/venue/%s_cards.png" % venue
	if ResourceLoader.exists(cards):
		m.set_shader_parameter("cards", load(cards))
	return m
