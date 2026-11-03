extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.x): "crowd moves poorly and is facing away from the game often"

const NOTE := {"id": "2026-11-02-crowd-facing-away", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.x", "words": "crowd moves poorly and is facing away from the game often"}

const Rig := preload("res://tests/note_rig.gd")
const Venues := preload("res://tests/crowd_venue_test.gd")


## The foundation's two test grounds (every kind of seat and standing room), each crowd built in 3D and audited.
func _audits() -> Array:
	var out := []
	# (High's crowd, as the owner saw it: the player's tier lets it be built - WsgFoundation.crowd_quality.)
	WsgFoundation.tier = WsgFoundation.HIGH
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


## Every fan within 35 degrees of the play, none backwards, in every kind of stand.
func check() -> void:
	if not WsgCrowd3D.available():
		skip("no licensed crowd here")
		return
	_measure(await _audits(), ["facing", "backwards"])
