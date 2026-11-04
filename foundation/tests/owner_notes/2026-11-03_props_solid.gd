extends WsgOwnerNote
## The owner, 2026-11-03 (every game): "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."

const NOTE := {"id": "2026-11-03-props-solid", "game": "all", "date": "2026-11-03", "version": "every game", "words": "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."}

## A body sent straight at a goal behind a bench, a table and a pole goes round each and is never inside one; a ball
## shot at them at 40 m/s bounces back off each.
func check() -> void:
	var s := WsgSolidProps.new()
	s.add({"name": "bench", "kind": "box", "position": Vector3(0, 0, 0), "size": Vector3(4.0, 0.45, 0.4)})
	s.add({"name": "table", "kind": "box", "position": Vector3(8, 0, 0), "yaw": 0.4, "size": Vector3(1.8, 0.76, 0.8)})
	s.add({"name": "pole", "kind": "cylinder", "position": Vector3(-8, 0, 0), "radius": 0.05, "height": 1.2, "material": "metal"})
	s.add({"name": "floor", "kind": "floor", "y": 0.0})
	var audit := WsgPropAudit.new(s)
	for x in [0.0, 8.0, -8.0]:
		var pos := Vector3(x + 0.1, 0, 3)
		var goal := s.free_spot(Vector3(x, 0, -3), 0.3)
		var memo := {}
		for f in 150:
			var w := goal - pos
			if w.length() < 0.2:
				break
			pos = s.move(pos, w.normalized() * 5.0, 1.0 / 30.0, 0.3, 1.8, goal, memo)[0]
			audit.body("walker", pos, 0.3)
		expect(pos.distance_to(goal) < 0.5, "a body did not get round the prop at x %.0f" % x)
		var r := s.bounce(Vector3(x, 0.4, 2), Vector3(0, 0, -40), 0.11, 0.1)
		expect((r.vel as Vector3).z > 0.0, "a ball at 40 m/s went on through the prop at x %.0f" % x)
	info("%d body frames, %d inside a prop" % [audit.body_checks, audit.body_cases])
	expect(audit.body_cases == 0, "a body went into a prop: %s" % [audit.report().worst])
