extends WsgOwnerNote
## The owner, 2026-11-03 (every game): "make sure the crowd is sitting propery/body not standing awkwardly inside the seat, watching the game properly, facing the right direction, standing properly."

const NOTE := {"id": "2026-11-03-crowd-properly", "game": "all", "date": "2026-11-03", "version": "every game", "words": "make sure the crowd is sitting propery/body not standing awkwardly inside the seat, watching the game properly, facing the right direction, standing properly."}

const Rig := preload("res://tests/note_rig.gd")
const Venues := preload("res://tests/crowd_venue_test.gd")


## The foundation's two test grounds (every kind of seat and standing room), each crowd built in 3D and audited.
func _audits() -> Array:
	var out := []
	for v in [["arena", Venues.arena()], ["outdoor", Venues.outdoor()]]:
		var crowd := WsgCrowd3D.new()
		tree.root.add_child(crowd)
		crowd.build_venue(v[1], 2, Vector3.ZERO, 1.0, 5)
		var a := WsgCrowdVenue.audit(crowd, v[1], 0)
		out.append([v[0], a])
		crowd.free()
	return out


func _measure(audits: Array, keys: Array) -> void:
	for va in audits:
		var a: Dictionary = va[1]
		for f in a.fails:
			for k in keys:
				if String(f).begins_with(k):
					fail("%s: %s" % [va[0], f])
		for sname in a.sections:
			var s: Dictionary = a.sections[sname]
			info("%-8s %-20s %4d fans  hips %+.3f..%+.3f  feet %+.3f..%+.3f  inside %.3f  facing <= %2.0f deg  backwards %d" % [va[0], sname, s.fans,
				s.hips[0] if s.hips[0] < INF else 0.0, s.hips[1] if s.hips[1] > -INF else 0.0, s.feet[0], s.feet[1], s.inside, s.facing, s.backwards])


## Every fan passes every measure of the crowd audit: seated, standing, inside nothing, facing the play.
func check() -> void:
	if not WsgCrowd3D.available():
		skip("no licensed crowd here")
		return
	_measure(await _audits(), [""])
