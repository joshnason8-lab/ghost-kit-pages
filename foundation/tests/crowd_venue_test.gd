extends SceneTree
## Every kind of seat and standing room the venues have, in two test grounds (an arena and an outdoor court), placed
## by WsgCrowdVenue and drawn by WsgCrowd3D.build_venue: every fan audited (WsgCrowdVenue.audit) - the seat of the
## trousers on the seat, the soles on the floor, nothing in a seat, a seat back, a step or a barrier, every fan facing
## the play. And the old way (the same places as feet, every seat 0.44 m) must fail it: the audit checks something.
##   godot --headless --path . -s tests/crowd_venue_test.gd

static func arena() -> WsgCrowdVenue:
	var v := WsgCrowdVenue.new(Vector3.ZERO, Vector2(28, 15))
	v.add({"name": "plastic seats", "a": Vector3(-12, 0, 9), "b": Vector3(12, 0, 9), "rows": 6, "tread": 0.8, "rise": 0.4, "seat": "plastic"})
	v.add({"name": "chairs on the floor", "a": Vector3(-10, 0, -9.5), "b": Vector3(10, 0, -9.5), "rows": 3, "tread": 0.9, "seat": "chair"})
	v.add({"name": "benches", "a": Vector3(16, 0, -6), "b": Vector3(16, 0, 6), "rows": 4, "tread": 0.8, "rise": 0.45, "seat": "bench", "stand": 0.2})
	v.add({"name": "bleachers", "a": Vector3(-16, 0, 6), "b": Vector3(-16, 0, -6), "rows": 5, "tread": 0.7, "rise": 0.35, "seat": "bleacher"})
	return v


static func outdoor() -> WsgCrowdVenue:
	var v := WsgCrowdVenue.new(Vector3.ZERO, Vector2(30, 15))
	v.add({"name": "terrace", "a": Vector3(17, 0, -7), "b": Vector3(17, 0, 7), "rows": 6, "tread": 0.45, "rise": 0.18, "seat": "terrace",
		"barrier": {"height": 1.0, "gap": 0.4}})
	v.add({"name": "stone steps", "a": Vector3(-12, 0, 9), "b": Vector3(12, 0, 9), "rows": 5, "tread": 0.75, "rise": 0.38, "seat": "step"})
	v.add({"name": "wall top", "a": Vector3(-12, 0, -9), "b": Vector3(12, 0, -9), "rows": 1, "tread": 0.9, "seat": "wall"})
	v.add({"name": "stools", "a": Vector3(-12, 0, -11), "b": Vector3(12, 0, -11), "rows": 1, "tread": 0.8, "seat": "stool"})
	v.add({"name": "behind the fence", "a": Vector3(-17, 0, 7), "b": Vector3(-17, 0, -7), "rows": 1, "tread": 2.5, "seat": "floor",
		"barrier": {"height": 2.0, "gap": 0.6}})
	return v


func _initialize() -> void:
	if not WsgCrowd3D.available():
		print("CROWD VENUE TEST: SKIPPED (no crowd data)")
		quit(0)
		return
	var fails := []
	for v in [["arena", arena()], ["outdoor", outdoor()]]:
		var crowd := WsgCrowd3D.new()
		root.add_child(crowd)
		crowd.build_venue(v[1], 2, Vector3.ZERO, 1.0, 5)
		var a := WsgCrowdVenue.audit(crowd, v[1], 0 if OS.has_environment("ALL_FANS") else 40)
		print("%s: %d places, %d fans in 3D" % [v[0], crowd.placed.spots.size(), a.fans])
		for name in a.sections:
			var s: Dictionary = a.sections[name]
			print("  %-20s %4d fans  hips %+.3f..%+.3f  feet %+.3f..%+.3f  inside %.3f  facing <= %2.0f deg  backwards %d" % [name, s.fans,
				s.hips[0] if s.hips[0] < INF else 0.0, s.hips[1] if s.hips[1] > -INF else 0.0, s.feet[0], s.feet[1], s.inside, s.facing, s.backwards])
		for f in a.fails:
			fails.append("%s: %s" % [v[0], f])
		crowd.free()
	# The old way: the same places taken as feet, every seat SEAT high, no venue - the audit must catch it.
	var v := arena()
	var crowd := WsgCrowd3D.new()
	root.add_child(crowd)
	crowd.placed = v.place(5)
	var flat := []
	for i in crowd.placed.spots.size():
		flat.append(Vector3.FORWARD if i % 2 == 0 else Vector3.BACK)
	crowd.build(crowd.placed.spots, flat, 1.0, 5, true, 2)
	var old := WsgCrowdVenue.audit(crowd, v)
	print("the old way: %d fails" % old.fails.size())
	if old.fails.size() < 2:
		fails.append("the audit passes the old placement (every seat 0.44, facings anyhow): it checks nothing")
	crowd.free()
	for f in fails:
		printerr("FAIL: ", f)
	print("CROWD VENUE TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
