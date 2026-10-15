extends Node
## Builds each ground's fixed parts (Arena.build_for_bake) as a scene ready for Godot's lightmapper: every mesh an
## ArrayMesh with a second UV set laid out for its lightmap (texels sized to what it is: the court finer, the ground
## around it coarser), its sky and sun, the lights only there to be baked, and a LightmapGI set up for the ground.
## Saves assets/grounds/<id>/<id>.tscn; bake.sh then bakes them in the editor.
##   godot --headless --path . res://tools/bake_lighting/make_scenes.tscn -- [dome stadium ...] [quality=low|medium|high]

const OUT := "res://assets/grounds/"
var _quality := LightmapGI.BAKE_QUALITY_MEDIUM


func _ready() -> void:
	var ids := []
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("quality="):
			_quality = {"low": LightmapGI.BAKE_QUALITY_LOW, "medium": LightmapGI.BAKE_QUALITY_MEDIUM,
				"high": LightmapGI.BAKE_QUALITY_HIGH}.get(String(a).substr(8), LightmapGI.BAKE_QUALITY_MEDIUM)
		else:
			ids.append(String(a))
	if ids.is_empty():
		ids = ["dome", "stadium", "village", "monsoon", "beach"]
	Arena.use_baked = false
	for id in ids:
		_make(String(id))
		await get_tree().process_frame
	get_tree().quit()


func _make(id: String) -> void:
	var arena := Arena.new()
	add_child(arena)
	arena.build_for_bake(id)
	var shell := arena.shell
	shell.name = id.capitalize()
	# The sky and sun it is baked under go with it (taken out again when the game loads it: Arena.build).
	for n in arena.get_children():
		if n is WorldEnvironment or n is DirectionalLight3D:
			n.reparent(shell)
	var meshes := 0
	var texels := 0.0
	for mi in shell.find_children("*", "MeshInstance3D", true, false):
		texels += _prepare(mi)
		meshes += 1
	var lm := LightmapGI.new()
	lm.name = "LightmapGI"
	lm.quality = _quality
	lm.bounces = 3
	lm.use_denoiser = true
	lm.directional = false
	lm.max_texture_size = 2048
	lm.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_DISABLED   # the players are lit live (no probes in Compatibility)
	if id == "dome":
		lm.interior = true
		lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
		lm.environment_custom_color = Color("2a3550")
		lm.environment_custom_energy = 0.35
	else:
		# The sky lights the bake as strongly as it lit the ground as ambient light before (the bake takes the ambient's
		# place on what it lights). The scene's own sky came in at full strength: on the beach, under a clear sky with
		# ambient 0.32, that was three times the fill and washed the sand out.
		lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_SKY
		lm.environment_custom_sky = arena.env.sky
		lm.environment_custom_energy = arena.env.ambient_light_energy
	shell.add_child(lm)
	for n in shell.find_children("*", "", true, false):
		n.owner = shell
	var ps := PackedScene.new()
	var err := ps.pack(shell)
	DirAccess.make_dir_recursive_absolute(OUT + id)
	err = maxi(err, ResourceSaver.save(ps, OUT + "%s/%s.tscn" % [id, id]))
	print("make_scenes %s: %d meshes, about %d lightmap texels, saved %s" % [id, meshes, int(texels), error_string(err)])
	arena.queue_free()


## The mesh as an ArrayMesh with its lightmap UVs; returns roughly how many texels it asks for.
func _prepare(mi: MeshInstance3D) -> float:
	if mi.mesh == null:
		return 0.0
	var am := ArrayMesh.new()
	if mi.mesh is PrimitiveMesh:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (mi.mesh as PrimitiveMesh).get_mesh_arrays())
	elif mi.mesh is ArrayMesh:
		am = (mi.mesh as ArrayMesh).duplicate()
	else:
		return 0.0
	var texel := _texel(mi)
	var err := am.lightmap_unwrap(mi.global_transform, texel)
	if err != OK:
		push_warning("make_scenes: no lightmap UVs for %s (%s)" % [mi.get_path(), error_string(err)])
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		return 0.0
	mi.mesh = am
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var hint := am.lightmap_size_hint
	return float(hint.x * hint.y)


## Metres a lightmap texel covers on this mesh: set by the arena (lm_texel), or by its size. Flat things by their
## area: the court about 5 cm, the run-off 8 cm, a floor 60 m across 27 cm, the fields round a ground 0.5-0.8 m.
## Solid things by their length (stands 12-25 cm, benches and posts 8 cm), coarser the further they are from the
## court: as they are within 14 m of its middle, up to four times coarser 56 m off (the trees round a village ground).
func _texel(mi: MeshInstance3D) -> float:
	if mi.has_meta("lm_texel"):
		return float(mi.get_meta("lm_texel"))
	var size := mi.get_aabb().size * mi.global_transform.basis.get_scale()
	var dims := [size.x, size.y, size.z]
	dims.sort()
	if dims[0] < 0.02:
		return clampf(sqrt(dims[1] * dims[2]) / 220.0, 0.05, 1.0)
	var off := Vector2(mi.global_position.x, mi.global_position.z).length()
	return clampf(dims[2] / 160.0, 0.08, 0.3) * clampf(off / 14.0, 1.0, 4.0)
