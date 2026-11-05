extends Node
## Makes the grounds' scenery models (trees, chairs, the scorers' table, buildings) into what the game loads, from
## the models tools/scenery/fetch.sh puts in assets/scenery/src/<kind>/<name>.glb: each model's mesh
## (assets/scenery/<kind>/<name>.res, without a material: game/scenery.gd gives it one) and its textures as they came
## in the model, not re-compressed (<name>_albedo.jpg, or .png for a cut-out's alpha, and <name>_normal.jpg). Writes
## their import settings, and those of the skies and surfaces, where there are none yet: textures compressed for the
## GPU with mipmaps, normal maps as such, the surfaces' normal maps at 512 px (a ground's detail, under the camera's
## feet at most), and the sky panoramas without mipmaps (only ever magnified) in the better compression.
##   godot --headless --path . res://tools/scenery/convert.tscn [-- all]
## Models already made are left as they are (their resources keep their ids) unless "all" is given.

const SRC := "res://assets/scenery/src/"
const OUT := "res://assets/scenery/"
## Surfaces kept at 1024 px: those the broadcast camera sees close (the courts and the ground round them). The rest,
## seen from across a ground (walls, roofs, the wet sand by the sea), at 512.
const SURFACES_1K := ["brown_mud_dry", "red_dirt_mud_01", "brown_mud", "coast_sand_01", "grass_ground", "concrete_floor"]


func _ready() -> void:
	var n := 0
	var all := OS.get_cmdline_user_args().has("all")
	for kind in DirAccess.get_directories_at(SRC):
		for f in DirAccess.get_files_at(SRC + kind):
			if f.get_extension() == "glb" and (all or not FileAccess.file_exists(OUT + kind + "/" + f.get_basename() + ".res")):
				n += int(_convert(kind, f.get_basename()))
	for f in DirAccess.get_files_at(OUT + "skies"):
		if f.get_extension() == "jpg":
			_import_settings(OUT + "skies/" + f, {"compress/high_quality": true, "mipmaps/generate": false})
		elif f.get_extension() == "hdr":
			_import_settings(OUT + "skies/" + f, {"mipmaps/generate": false})
	for s in DirAccess.get_directories_at(OUT + "surfaces"):
		var dir := OUT + "surfaces/" + s + "/"
		_import_settings(dir + s + "_albedo_1k.jpg", {"process/size_limit": 0 if s in SURFACES_1K else 512})
		_import_settings(dir + s + "_normal_1k.jpg", {"compress/normal_map": 1, "process/size_limit": 512})
	_import_settings(OUT + "water/water_normal_512.png", {"compress/normal_map": 1})
	print("convert: %d models" % n)
	get_tree().quit()


func _convert(kind: String, name: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_DISCARD_TEXTURES   # taken from the file as they are, below
	var path := SRC + kind + "/" + name + ".glb"
	var err := doc.append_from_file(path, state)
	if err != OK or state.get_meshes().is_empty():
		push_error("convert: %s: %s" % [path, error_string(err)])
		return false
	var json: Dictionary = state.json
	var mat: Dictionary = json.materials[0] if json.has("materials") else {}
	var dir := OUT + kind + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var albedo := _texture(state, mat.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}), dir + name + "_albedo")
	var normal := _texture(state, mat.get("normalTexture", {}), dir + name + "_normal")
	if albedo != "":
		_import_settings(albedo, {})
	if normal != "":
		_import_settings(normal, {"compress/normal_map": 1})
	# One mesh, one surface each (the shared assets are made so); tangents where there is a normal map.
	var st := SurfaceTool.new()
	st.create_from((state.get_meshes()[0] as GLTFMesh).mesh.get_mesh(), 0)
	if normal != "":
		st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, null)
	mesh.resource_name = name
	err = ResourceSaver.save(mesh, dir + name + ".res", ResourceSaver.FLAG_COMPRESS)
	var aabb := mesh.get_aabb()
	print("convert: %s%s.res: %d triangles, %.2f x %.2f x %.2f m from y %.2f, %s%s" % [dir, name,
		mesh.surface_get_array_index_len(0) / 3, aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.y,
		albedo.get_file(), (", " + normal.get_file()) if normal != "" else ""])
	return err == OK


## The image a material's texture slot (tex: its glTF entry) points at, written as it is in the file to base plus its
## own extension; the path written, or "" when the slot is empty.
func _texture(state: GLTFState, tex: Dictionary, base: String) -> String:
	if not tex.has("index"):
		return ""
	var json: Dictionary = state.json
	var image: Dictionary = json.images[int(json.textures[int(tex.index)].source)]
	var view: GLTFBufferView = state.get_buffer_views()[int(image.bufferView)]
	var data: PackedByteArray = state.get_buffers()[view.buffer]
	var ext := "png" if String(image.get("mimeType", "")) == "image/png" else "jpg"
	var path := base + "." + ext
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data.slice(view.byte_offset, view.byte_offset + view.byte_length))
	f.close()
	return path


## A texture's import settings, where it has none yet (Godot fills in the rest when it imports it): compressed for
## the GPU with mipmaps, and whatever params changes.
func _import_settings(path: String, params: Dictionary) -> void:
	if not FileAccess.file_exists(path) or FileAccess.file_exists(path + ".import"):
		return
	var p := {"compress/mode": 2, "compress/high_quality": false, "compress/lossy_quality": 0.7,
		"compress/uastc_level": 0, "compress/rdo_quality_loss": 0.0, "compress/hdr_compression": 1,
		"compress/normal_map": 0, "compress/channel_pack": 0, "mipmaps/generate": true, "mipmaps/limit": -1,
		"roughness/mode": 0, "roughness/src_normal": "", "process/channel_remap/red": 0,
		"process/channel_remap/green": 1, "process/channel_remap/blue": 2, "process/channel_remap/alpha": 3,
		"process/fix_alpha_border": true, "process/premult_alpha": false, "process/normal_map_invert_y": false,
		"process/hdr_as_srgb": false, "process/hdr_clamp_exposure": false, "process/size_limit": 0,
		"detect_3d/compress_to": 0}
	p.merge(params, true)
	var lines := PackedStringArray(["[remap]", "", "importer=\"texture\"", "type=\"CompressedTexture2D\"", "", "[params]", ""])
	for k in p:
		lines.append("%s=%s" % [k, var_to_str(p[k])])
	var f := FileAccess.open(path + ".import", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
