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
		# Low: the same places as cards, one draw call.
		if WsgCrowdCards.available():
			var cards := WsgCrowdCards.new()
			root.add_child(cards)
			cards.build(crowd.placed, PackedInt32Array(), 5)
			var c := cards.audit(v[1], crowd.placed)
			print("  %-20s %4d cards in 1 draw call  hips %+.3f..%+.3f  facing <= %2.0f deg" % ["Low (cards)", c.cards,
				c.hips[0] if c.hips[0] < INF else 0.0, c.hips[1] if c.hips[1] > -INF else 0.0, c.facing])
			if c.cards != crowd.placed.spots.size():
				fails.append("%s: %d cards for %d places" % [v[0], c.cards, crowd.placed.spots.size()])
			for f in c.fails:
				fails.append("%s: %s" % [v[0], f])
			cards.free()
		crowd.free()
	fails.append_array(_card_faces())
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


## The cards' art: every cell shows its fan's face - where the head is drawn (cards.json: from the posed skeleton),
## at least a fifth of the pixels have the fan's skin's hue (the back of a head is hair). The cards were once baked
## from the crowd's few-vertex figure: dark-haired and bearded heads read as backs (Pok Ta Pok's Low).
const FACE_DETAIL := 0.055


func _card_faces() -> Array:
	var fails := []
	if not WsgCrowdCards.available():
		return fails
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WsgCrowdCards.DIR + "cards.json"))
	var atlas := (load(WsgCrowdCards.DIR + "cards.png") as Texture2D).get_image()
	atlas.decompress()
	var cw := int(layout.cell[0])
	var chh := int(layout.cell[1])
	var worst := 1.0
	var least_detail := INF
	var w := Vector3(0.3, 0.59, 0.11)
	for n in layout.cells.size():
		var cell: Dictionary = layout.cells[n]
		if not cell.has("head"):
			fails.append("cards: %s %s has no head recorded (re-bake: tools/bake_cards.gd)" % [cell.fan, cell.pose])
			continue
		var x0: int = (n % int(layout.cols)) * cw
		var y0: int = (n / int(layout.cols)) * chh
		var ref_a: Array = layout.fans[cell.fan].looks.skin
		var ref := Vector3(ref_a[0], ref_a[1], ref_a[2])
		var lr := ref.dot(w)
		var hx: int = cell.head[0]
		var hy: int = cell.head[1]
		var r: int = cell.head[2]
		var seen := 0
		var skin := 0
		var grad := 0.0
		var pairs := 0
		for y in range(hy - r, hy + r + 1):
			for x in range(hx - r, hx + r + 1):
				if (x - hx) * (x - hx) + (y - hy) * (y - hy) > r * r or x < 0 or y < 0 or x >= cw - 1 or y >= chh:
					continue
				var c := atlas.get_pixel(x0 + x, y0 + y)
				if c.a < 0.5:
					continue
				seen += 1
				var v := Vector3(c.r, c.g, c.b)
				var lc := v.dot(w)
				if lc > 0.45 * lr and lc < 2.2 * lr and (v / maxf(lc, 0.001)).distance_to(ref / lr) < 0.35:
					skin += 1
				var c2 := atlas.get_pixel(x0 + x + 1, y0 + y)
				if c2.a >= 0.5:
					grad += absf(lc - Vector3(c2.r, c2.g, c2.b).dot(w))
					pairs += 1
		var share := float(skin) / maxf(1, seen)
		# Features: the mean step between neighbouring pixels. The few-vertex faces were smooth blobs (0.016-0.044);
		# the textured ones have eyes, brows and a hairline (0.066 and up).
		var features := grad / maxf(1, pairs)
		worst = minf(worst, share)
		least_detail = minf(least_detail, features)
		if share < 0.2:
			fails.append("cards: %s %s shows no face (%.0f%% of the head is skin)" % [cell.fan, cell.pose, share * 100.0])
		if features < FACE_DETAIL:
			fails.append("cards: %s %s has a featureless face (detail %.3f, under %.3f)" % [cell.fan, cell.pose, features, FACE_DETAIL])
	print("cards: every cell's head at least %.0f%% skin, detail at least %.3f (a face, not a blob)" % [worst * 100.0, least_detail])
	return fails
