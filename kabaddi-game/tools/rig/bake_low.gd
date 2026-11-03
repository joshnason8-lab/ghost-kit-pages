extends SceneTree
## Low's lighter bodies: each body's triangles cut to about a quarter (Godot's own mesh simplifier, as its importer
## makes LODs), the same vertices - so the skin, the contact points and every bone read stay as they are - saved as
## assets/characters/bodies/<name>_low.res (its "indices" meta). RiggedBody draws them on Low (Low drew 21 bodies of
## 15,000 triangles and a flattened copy of each for its floor shadow: 625,000-665,000 a frame against the tier's
## 200,000; wsg_world_check's tiers rule, 2026-11-03).
##   godot --headless --path . -s res://tools/rig/bake_low.gd [-- target_triangles]

const TARGET := 4000   # triangles a player's body at most (the LOD nearest under it)
const TARGET_OFFICIAL := 2000   # an official's: on the side lines, small on screen (the beach's Low was 203,000 at 4,000)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var target := int(args[0]) if args.size() > 0 else TARGET
	var rb: Script = load("res://game/rigged_body.gd")
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/bodies/bodies.json"))
	for b: Dictionary in list:
		var file := String(b.file)
		var d: Dictionary = rb.call("_load", file)
		if d.is_empty():
			printerr("bake_low: %s did not load" % file)
			continue
		var mesh: ArrayMesh = d.mesh
		var arrays := mesh.surface_get_arrays(0)
		var full := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var want := TARGET_OFFICIAL if String(b.get("kind", "")) == "referee" else target
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, "", mesh.surface_get_format(0))
		im.generate_lods(25.0, 60.0, [])
		var best := PackedInt32Array()
		for i in im.get_surface_lod_count(0):
			var idx: PackedInt32Array = im.get_surface_lod_indices(0, i)
			if idx.size() / 3 <= want and idx.size() > best.size():
				best = idx
		if best.is_empty():
			printerr("bake_low: %s has no LOD under %d triangles" % [file, want])
			continue
		var r := Resource.new()
		r.set_meta("indices", best)
		r.set_meta("full_triangles", full)
		var out := "res://assets/characters/bodies/%s_low.res" % file.get_basename()
		var err := ResourceSaver.save(r, out, ResourceSaver.FLAG_COMPRESS)
		print("bake_low: %s %d -> %d triangles (%s, err %d)" % [file, full, best.size() / 3, out, err])
	quit()
