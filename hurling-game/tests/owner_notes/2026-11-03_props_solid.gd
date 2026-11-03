extends WsgOwnerNote
## The owner, 2026-11-03 (every game (Hurling 0.23)): "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."

const NOTE := {"id": "2026-11-03-props-solid", "game": "hurling", "date": "2026-11-03", "version": "every game (Hurling 0.23)", "words": "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."}
const Kit := preload("res://tests/note_kit.gd")

## At every ground, 30 s of an AI match at sim speed fed to the props' audit (game/prop_runs.gd): no player, official or
## substitute ever more than 2 cm into a prop, no ball step through one; and the props a player meets are there (the
## goal frames, the flags, the dugouts and their benches).
func check() -> void:
	var reg: Object = load("res://game/prop_runs.gd").new()
	for v in reg.call("venues"):
		var audit := WsgPropAudit.new()
		var host: Node = await reg.call("run", String(v), 77, 30.0, audit, tree)
		var r := audit.report()
		var names := {}
		for p in audit.solid.props:
			names[String(p.name)] = true
		info("%s: %d body frames, %d inside a prop; %d ball steps, %d through one; %d props" % [v, r.body_checks, r.body_cases, r.ball_steps, r.ball_tunnels, audit.solid.props.size()])
		expect(bool(r.pass), "%s: %s" % [v, (r.worst as Array).slice(0, 3)])
		for need in ["goal frame", "flag", "dugout", "painted_bench_low"]:
			expect(names.has(need), "%s: no solid %s" % [v, need])
		if is_instance_valid(host):
			host.queue_free()
		await Kit.frames(tree, 3)
