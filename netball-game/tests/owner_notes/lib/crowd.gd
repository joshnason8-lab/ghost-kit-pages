extends RefCounted
## Who is in a venue's crowd and how each is drawn, for the owner's notes on the crowd: the people drawn as whole 3D
## people (the shared foundation's WsgCrowd3D), as flat cards (WsgCrowdCards), and the seated and standing people
## painted onto the stands by the venue's shader (the arena's bowl, VenueLook.STAND and STANDING faces: from the
## broadcast camera they read as squares of colour), estimated from the painted area; and how detailed a 3D person is.

const SEAT_AREA := 0.5 * 0.95      # m² of a sloped tier a seated person takes (a 50 cm seat, a 85 cm row up its slope)
const STANDING_AREA := 0.5 * 1.7   # m² of an upright face a painted standing person takes


## An AI match's venue at the graphics level now: {"real", "cards", "painted", "painted_m2", "share" (of everyone,
## the 3D people), "tris" (the triangles of a 3D person as drawn nearest the camera), "crowds"}.
static func count(h: Node, venue: String) -> Dictionary:
	var m: Match = h._study_match(3, {"venue": venue, "home": "ENG", "away": "WAL"})
	for i in 4:
		await h.get_tree().process_frame
	var real := 0
	var cards := 0
	var tris := 0
	var crowds := m.find_children("*", "Crowd", true, false)
	for c: Crowd in crowds:
		for e: Array in c.everyone():
			if e[2]:
				cards += 1
			else:
				real += 1
		if c.people:
			for mi: MultiMeshInstance3D in c.people.meshes:
				var mesh := mi.multimesh.mesh if mi.multimesh else null
				if mesh:
					var t := 0
					for s in mesh.get_surface_count():
						var a := mesh.surface_get_arrays(s)
						var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
						t += idx.size() / 3 if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
					tris = maxi(tris, t)
	var painted_m2 := [0.0, 0.0]
	for mi: MeshInstance3D in m.arena.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or not (mi.mesh is ArrayMesh):
			continue
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var a := am.surface_get_arrays(s)
			if a[Mesh.ARRAY_TEX_UV2] == null:
				continue
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var u2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n := idx.size() if idx.size() > 0 else v.size()
			for t in range(0, n - 2, 3):
				var i0 := idx[t] if idx.size() > 0 else t
				var i1 := idx[t + 1] if idx.size() > 0 else t + 1
				var i2 := idx[t + 2] if idx.size() > 0 else t + 2
				var k := u2[i0].x
				var which := 0 if absf(k - VenueLook.STAND) < 0.01 else (1 if absf(k - VenueLook.STANDING) < 0.01 else -1)
				if which < 0 or absf(u2[i1].x - k) > 0.01 or absf(u2[i2].x - k) > 0.01:
					continue
				var xf := mi.global_transform
				painted_m2[which] += 0.5 * ((xf * v[i1] - xf * v[i0]).cross(xf * v[i2] - xf * v[i0])).length()
	var painted := int(painted_m2[0] / SEAT_AREA * float(m.arena._look.get("density", 1.0)) + painted_m2[1] / STANDING_AREA)
	var all := real + cards + painted
	m.queue_free()
	await h.get_tree().process_frame
	await h.get_tree().process_frame
	return {"real": real, "cards": cards, "painted": painted, "painted_m2": painted_m2[0] + painted_m2[1], "standing_m2": painted_m2[1],
		"share": float(real) / maxf(1.0, all), "tris": tris, "crowds": crowds.size()}


static func line(r: Dictionary) -> String:
	return "%d people in 3D (the nearest %d triangles each), %d cards, about %d painted on the stands (%.0f m², %.0f m² of it standing rows): %.0f%% real people" % [r.real,
		r.tris, r.cards, r.painted, r.painted_m2, r.standing_m2, float(r.share) * 100.0]
