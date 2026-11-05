extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.7): "Get rid of the festival court Day flags they are in the way."

const NOTE := {"id": "2026-11-03-festival-flags", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.7", "words": "Get rid of the festival court Day flags they are in the way."}


## The festival court by day: nothing hangs over the court or the near side, anywhere along the court, between head
## height and 6 m (where the papel picado was strung): every vertex of the venue's own meshes is checked.
func check() -> void:
	var v := Venue.new()
	tree.root.add_child(v)
	v.build("festival", Court.new(Rules.ULAMA))
	await frame()
	var hits := {}
	var meshes := 0
	for n in v.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.name in ["ground", "taste", "lines"]:
			continue
		meshes += 1
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			for p: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				var w := xf * p
				if absf(w.x) < 31.0 and w.z > -2.5 and w.z < 9.0 and w.y > 2.0 and w.y < 6.0:
					hits[String(mi.name)] = int(hits.get(String(mi.name), 0)) + 1
	info("%d meshes of the festival court looked through" % meshes)
	expect(meshes >= 3, "the festival court's meshes were not found")
	for k in hits:
		fail("%s: %d points hang over the court or the near side (2-6 m up)" % [k, hits[k]])
	v.free()
