extends WsgOwnerNote
## The owner (relayed by the lead to every game), 2026-11-03.
## PENDING: not in tests/owner_notes/INDEX.json until the game registers its props as solid (the shared foundation's
## WsgSolidProps, Arena.solid: in progress). WsgOwnerNote has no expected-fail, so this note waits here, outside the
## strict run; run it with
##   godot --headless --path . --fixed-fps 30 -s res://tools/wsg/owner_notes.gd -- res://tests/owner_notes/pending
## and move it (and its INDEX entry) up into tests/owner_notes/ the day it passes.

const NOTE := {"id": "2026-11-03-props-solid", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta (every game)",
	"words": "These games live in a world of reality. There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## In every venue, on Low and High: the venue's props are solid (Arena.solid, a WsgSolidProps holding its benches,
## tables, posts and the rest); through AI play and a quarter-time break (when the players walk to their benches and
## the umpires to the middle), no player, reserve or umpire is ever inside one (WsgPropAudit: none more than 2 cm in);
## the ball never passes through one (WsgPropAudit's tunnels); and a loose ball sent at each bench and table at 10 m/s
## comes back off it.
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
			var m: Match = h._study_match(111, {"venue": venue, "quarter_s": 40.0})
			await h._wait_live(m)
			var solid = m.arena.get("solid")
			if not expect(solid is WsgSolidProps, "%s: the venue's props are not solid (no Arena.solid)" % what):
				m.queue_free()
				await frame()
				continue
			var props: Array = (solid as WsgSolidProps).props.filter(func(p): return String(p.get("kind", "")) != "floor")
			expect(props.size() > 0, "%s: no solid props registered" % what)
			var audit := WsgPropAudit.new(solid)
			for f in 2400:
				await frame()
				audit.tick(1.0 / 30.0)
				for q in m.players[0] + m.players[1] + m.umpires:
					audit.body(String(q.name), q.global_position, 0.25)
				var res: Node = m.get_node_or_null("Reserves")
				if res:
					for r in res.get_children():
						if r is ToonBody:
							# (Seated on the bench: her body over the seat, her lower legs in front of it.)
							for part: Array in Match.reserve_parts(r):
								audit.body(String(r.name), part[0], part[1], part[2])
				if m.ball.state in ["loose", "flight", "dead"]:
					audit.ball(m.ball.global_position, Ball.R)
				else:
					audit.ball_reset()
			var rep := audit.report()
			info("%s: %d props; %d body frames, %d inside a prop; %d ball steps, %d through a prop" % [what, props.size(), audit.body_checks,
				audit.body_cases, audit.ball_steps, audit.ball_tunnels])
			expect(audit.body_cases == 0, "%s: a player or umpire inside a prop: %s" % [what, rep.get("worst", [])])
			expect(audit.ball_tunnels == 0, "%s: the ball went through a prop: %s" % [what, rep.get("worst", [])])
			# A loose ball at each bench and table.
			var hit := 0
			var through := 0
			for p: Dictionary in props:
				var nm := String(p.get("name", ""))
				if not (nm.contains("bench") or nm.contains("table")):
					continue
				hit += 1
				var c: Vector3 = p.get("position", Vector3.ZERO)
				var from := c + Vector3(0, 0.35, 3.0)
				m.ball.loose(from, (c + Vector3(0, 0.35, 0) - from).normalized() * 10.0)
				var start_d := Vector2(from.x - c.x, from.z - c.z).length()
				var closest := INF
				for f in 30:
					await frame()
					closest = minf(closest, Vector2(m.ball.position.x - c.x, m.ball.position.z - c.z).length())
				var end_d := Vector2(m.ball.position.x - c.x, m.ball.position.z - c.z).length()
				if end_d < start_d * 0.5 and closest < 0.1:
					through += 1
					fail("%s: a ball at 10 m/s went through the %s" % [what, nm])
			info("%s: %d benches and tables shot at, %d gone through" % [what, hit, through])
			m.queue_free()
			await frame()
			await frame()
	await Harness.done(h)
