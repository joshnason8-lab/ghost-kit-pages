extends TakrawNote
## The owner, 2026-11-02: "Referee is moving backwards but showing he is running forward."

const NOTE := {"id": "2026-11-02-referee-backwards", "game": "sepak-takraw", "date": "2026-11-02", "version": "0.14.1",
	"words": "Referee is moving backwards but showing he is running forward."}


## Each standing official (the assistant referee and both line judges) backing 1.2 m away from the court, still
## facing it, on Low (the game's own body) and High (the shared foundation's, where its library is): his feet step
## back - the lower foot goes over the floor at about his own speed (a forward stride played as he goes back skates it
## at about twice).
func check() -> void:
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		var m := make_match({"seed": 3}, level)
		await frame()
		var offs: Officials = m.get("_officials")
		for o in offs.list:
			if not o.standing:
				continue
			o.back_t = 1e9
			o.off_to = -o.body.global_transform.basis.z.normalized() * 1.2
			var link: FoundationLink = o.body.link
			var foot_speed := 0.0
			var body_speed := 0.0
			var n := 0
			var was := {}
			for i in 45:
				offs.tick(DT, Vector3(0, 0.1, 30), true)
				if link:
					await frame()   # (the drawn body posed)
				var pos: Vector3 = o.body.global_position
				var fl: Vector3 = link.body.bone_world("LeftFoot").origin if link else o.body.bone_world("foot_l")
				var fr: Vector3 = link.body.bone_world("RightFoot").origin if link else o.body.bone_world("foot_r")
				var low := "l" if fl.y < fr.y else "r"
				var f: Vector3 = fl if low == "l" else fr
				if not was.is_empty() and was.low == low:
					var step := pos.distance_to(was.pos)
					if step > 0.4 * DT:
						body_speed += step
						foot_speed += Vector2(f.x - was.f.x, f.z - was.f.z).length()
						n += 1
				was = {"pos": pos, "f": f, "low": low}
			var ratio := foot_speed / maxf(body_speed, 0.001)
			var tag := "%s, %s" % [["Low", "Medium", "High"][level], "drawn by the foundation" if link else "the game's body"]
			info("%s: an official backing away, his lower foot over the floor at %.2f of his speed (%d frames)" % [tag, ratio, n])
			expect(n >= 4 and ratio < 1.4, "%s: backing away, his lower foot skates at %.2f of his speed over %d frames (he runs forward going back)" % [tag, ratio, n])
		m.queue_free()
		await frame()
	await clean()
