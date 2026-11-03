extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0 (and 0.20 before it)): "I still do not hear the sound of a clang when the ball is hitting the goal posts, that was built this is a regression."

const NOTE := {"id": "2026-11-03-post-clang", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0 (and 0.20 before it)", "words": "I still do not hear the sound of a clang when the ball is hitting the goal posts, that was built this is a regression."}
const Kit := preload("res://tests/note_kit.gd")

## In free-taking, under its own low camera 40-65 m from the posts: the sliotar off a post plays the clang where it hit,
## as one of the foundation's bright kinds (no distance filter, from no farther than bright_distance), loud.
func check() -> void:
	var keep = Game.settings.sound
	Game.settings.sound = true
	var m: Node = await Kit.match(tree, {"mode": "practice", "user_team": 0, "seed": 1}, 30, true)
	if Sfx.wsg == null:
		fail("no foundation mixer (WsgAudio): the clang has nowhere to be crisp")
	else:
		for f in WsgNoteChecks.bright(Sfx.wsg, ["post", "strike"]):
			fail(f)
		for side: float in [-1.0, 1.0]:
			var gx: float = Pitch.HALF_L * m.dir(0)
			var z := (Pitch.POST_GAP * 0.5 + Pitch.POST_W * 0.5) * side
			m.ball.state = Sliotar.FREE
			m.ball.vel = Vector3(20.0 * m.dir(0), 0, 0)
			m._check_ball(Vector3(gx - 0.5 * m.dir(0), 3.0, z), Vector3(gx + 0.5 * m.dir(0), 3.0, z))
			var ear: Vector3 = m.get_viewport().get_camera_3d().global_position
			var heard := false
			for p: AudioStreamPlayer3D in Sfx.wsg._pool:
				if p.playing and p.stream and String(p.stream.resource_path).get_file().begins_with("post"):
					info("off the %s post: %.0f m from the camera, played at %.1f dB, filter %.0f dB, %.1f m from the ear" % [
						"left" if side < 0 else "right", Vector3(gx, 3, z).distance_to(ear), p.volume_db, p.attenuation_filter_db,
						p.global_position.distance_to(ear)])
					heard = heard or (p.volume_db > -6.0 and p.attenuation_filter_db == 0.0 and p.global_position.distance_to(ear) <= Sfx.wsg.bright_distance + 0.5)
			expect(heard, "the sliotar off the %s post: no crisp, loud clang" % ["left" if side < 0 else "right"])
			await Kit.frames(tree, 20)
	Game.settings.sound = keep
	await Kit.done(tree, m)
