extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-referees-block-figures", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "The referees look too much like block figures, not humans."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Both umpires, on every graphics level, in every venue: drawn as a person - a skinned body of the players' own model
## (the game's HeroBody in the umpires' kit, no bib; the shared foundation's body on Medium and High with the clips),
## no box, capsule or cylinder standing in for a body or limb (WsgNoteChecks.block_figure's measure), a model of 1,000 triangles
## or more - and at ease, never in an A- or T-pose, standing or jogging her line.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var clips := Harness.have_clips()
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		FoundationLink.off = g == Game.GFX_LOW or not clips
		for venue in ["arena", "hall", "outdoor"]:
			var m: Match = h._study_match(81, {"venue": venue})
			await h._wait_live(m)
			var poses := {}
			for u: Umpire in m.umpires:
				poses[u] = [""]
				if u.link:
					u.link.body.posed.connect(func():
						var tp := WsgNoteChecks.t_or_a_pose(u.link.body)
						if tp != "":
							poses[u][0] = tp)
			for f in 150:
				await frame()
			for u: Umpire in m.umpires:
				var drawn: Node = u.link.body if u.link and u.link.body.is_visible_in_tree() else u.body
				var what := "%s, %s, the umpire %s (%s)" % [["Low", "Medium", "High"][g], venue, u.name, "the foundation's body" if drawn != u.body else "the game's body"]
				var block := _block(drawn)
				var tris := 0
				for mi: MeshInstance3D in drawn.find_children("*", "MeshInstance3D", true, false):
					if mi.is_visible_in_tree() and mi.mesh and _skinned(mi):
						for k in mi.mesh.get_surface_count():
							var a := mi.mesh.surface_get_arrays(k)
							tris += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				info("%s: %s, %d triangles" % [what, "a person" if block == "" else block, tris])
				expect(block == "", "%s: a block figure - %s" % [what, block])
				expect(tris >= 1000, "%s: %d triangles - not a human figure" % [what, tris])
				if drawn == u.body:
					expect(u.body is HeroBody, "%s: not the players' model" % what)
					var mat := u.body.mesh_instance.material_override as ShaderMaterial
					expect(mat != null and float(mat.get_shader_parameter("umpire")) > 0.5, "%s: not in the umpires' kit" % what)
				expect(String(poses[u][0]) == "", "%s: %s" % [what, poses[u][0]])
			m.queue_free()
			await frame()
			await frame()
	await Harness.done(h)


## A mesh bent by a skeleton: a Skin, or bone weights and a skeleton to follow (the game's HeroBody: Godot makes its
## skin from the skeleton's rest).
static func _skinned(mi: MeshInstance3D) -> bool:
	if mi.skin != null:
		return true
	if mi.skeleton == NodePath("") or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return false
	return mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] != null


## As WsgNoteChecks.block_figure (no skinned body, or a primitive shape over 15 cm standing in for one), with the game's
## own skinned bodies counted as bodies.
static func _block(node: Node) -> String:
	var skinned := false
	var prims := []
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		if not (n as GeometryInstance3D).is_visible_in_tree() or not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh is PrimitiveMesh and (mi.mesh as PrimitiveMesh).get_aabb().get_longest_axis_size() > 0.15:
			prims.append("%s (%s)" % [mi.name, mi.mesh.get_class()])
		elif mi.mesh != null and _skinned(mi):
			skinned = true
	if not skinned:
		return "no skinned body is drawn"
	if not prims.is_empty():
		return "drawn with primitive shapes: %s" % ", ".join(prims)
	return ""
