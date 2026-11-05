extends TakrawNote
## The lead, 2026-11-04, for the owner: sepak raga bulatan, the circle game (game/raga.gd) - "add an owner note that a
## full ring run plays on Low and High with props, feet and pose rules passing, no new assets".

const NOTE := {"id": "2026-11-04-sepak-raga", "game": "sepak-takraw", "date": "2026-11-04", "version": "0.15.22",
	"words": "Sepak raga bulatan: a full ring run plays on Low and High with props, feet and pose rules passing, no new assets (the lead's request for the owner)."}

const CAP := 60   # touches: a run this long is full (it is kept up for good past it)


## On Low and on High, a ring run played by itself (everyone's touches, yours too) from the first drop to the ball
## falling, or CAP touches: it keeps going (20 touches at least), each touch played where the move reaches the ball;
## no body ever in a prop, the ball through none (WsgPropAudit, as at every venue); every player's feet by the feet
## rule (WsgNoteChecks.foot_slip: a planted foot 2 cm a step, a flat foot 2 cm a frame, a low foot's jump 25 cm); none
## in a T- or A-pose (the rule's arms, read off the game's bodies); and no new assets: the circle loads only scripts -
## the park, the bodies and the ball are a match's.
func check() -> void:
	var src := FileAccess.get_file_as_string("res://game/raga.gd")
	var loads := []
	var at := src.find("res://")
	while at >= 0:
		var end := src.find("\"", at)
		var path := src.substr(at, end - at)
		if not path.ends_with(".gd"):
			loads.append(path)
		at = src.find("res://", at + 6)
	expect(src != "" and loads.is_empty(), "the circle loads an asset of its own: %s" % [loads])
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		var lvl: String = ["Low", "Medium", "High"][g]
		Game.reset_settings_for_tests()
		Game.settings.sound = false
		Game.settings.graphics = g
		WsgFoundation.tier = g
		FoundationLink.off = g == Game.GFX_LOW
		var r := Raga.new()
		r.config = {"auto": true, "seed": 11}
		r.process_mode = Node.PROCESS_MODE_DISABLED   # (played here, frame by frame)
		tree.root.add_child(r)
		_made.append(r)
		await frame()
		await frame()
		var audit := WsgPropAudit.new(r.arena.solid)
		var feet := {}
		var poses := {}
		var free_was := false
		var frames := 0
		while r.state == "play" and r.touches < CAP and frames < 30 * 240:
			frames += 1
			r._process(DT)
			for i in r.players.size():
				var pl: Player = r.players[i]
				audit.body("ring %d" % i, pl.global_position, Player.BODY_R, Player.BODY_H)
				var f: Array = pl.body.feet()
				if f.size() == 4:
					if not feet.has(i):
						feet[i] = []
					feet[i].append(f)
				var why := _a_or_t(pl.body)
				if why != "":
					poses[i] = why
			var free: bool = r.ball.flying or r.ball.loose
			if free and free_was:
				audit.ball(r.ball.global_position, Ball.RADIUS)
			else:
				audit.ball_reset()
				if free:
					audit.ball(r.ball.global_position, Ball.RADIUS)
			free_was = free
			audit.tick(DT)
			if frames % 300 == 299:
				await frame()
		var rep := audit.report()
		var far := 0
		for e in r.touch_log:
			var c: Vector3 = e[2]
			var stood: Vector3 = e[3]
			far += int(Vector2(c.x - stood.x, c.z - stood.z).length() > 0.65)
		info("%s: %d touches (%s), %.0f s; %d body frames, %d inside a prop; %d ball steps, %d through one" % [lvl, r.touches,
			"down" if r.state == "down" else "kept up", frames * DT, rep.body_checks, rep.body_cases, rep.ball_steps, rep.ball_tunnels])
		expect(r.touches >= 20, "%s: the ring kept it up for only %d touches" % [lvl, r.touches])
		expect(far == 0, "%s: %d touches played out of the move's reach" % [lvl, far])
		expect(int(rep.body_cases) == 0, "%s: a body was inside a prop %d times (worst %s)" % [lvl, rep.body_cases, str(rep.worst).left(160)])
		expect(int(rep.ball_tunnels) == 0, "%s: the ball went through a prop %d times" % [lvl, rep.ball_tunnels])
		var worst := [0.0, 0.0, 0.0]
		for i in feet:
			var s := WsgNoteChecks.foot_slip(feet[i])
			worst = [maxf(worst[0], float(s.max_cm)), maxf(worst[1], float(s.skid_cm)), maxf(worst[2], float(s.jump_cm))]
			expect(float(s.max_cm) <= WsgWorldRules.FEET_MAX_CM, "%s: ring player %d's planted foot slid %.1f cm in a step (%.1f at most)" % [lvl, i, s.max_cm, WsgWorldRules.FEET_MAX_CM])
			expect(float(s.skid_cm) <= WsgWorldRules.FEET_MAX_CM, "%s: ring player %d's flat foot slid %.1f cm in a frame (%.1f at most)" % [lvl, i, s.skid_cm, WsgWorldRules.FEET_MAX_CM])
			expect(float(s.jump_cm) <= WsgWorldRules.JUMP_MAX_CM, "%s: ring player %d's low foot jumped %.1f cm in a frame (%.0f at most)" % [lvl, i, s.jump_cm, WsgWorldRules.JUMP_MAX_CM])
		info("%s: feet, worst of %d players: slip %.1f cm a step, skid %.1f cm a frame, jump %.1f cm" % [lvl, feet.size(), worst[0], worst[1], worst[2]])
		expect(feet.size() == r.players.size(), "%s: feet read for %d of %d players" % [lvl, feet.size(), r.players.size()])
		expect(poses.is_empty(), "%s: in a T- or A-pose: %s" % [lvl, poses])
		r.queue_free()
		await frame()
	await clean()


## The rule's T- or A-pose (WsgNoteChecks.t_or_a_pose), read off the game's own body: both arms straight and out to
## the sides, level (T) or part way (A).
func _a_or_t(rb: RealBody) -> String:
	var sk := rb.skeleton
	var w := func(n: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_" + n)).origin
	var down := -rb.global_transform.basis.y.normalized()
	var a := {}
	for side in ["Left", "Right"]:
		var sh: Vector3 = w.call(side + "Arm")
		var el: Vector3 = w.call(side + "ForeArm")
		var wr: Vector3 = w.call(side + "Hand")
		var up := (el - sh).normalized()
		a[side] = [rad_to_deg(up.angle_to(down)), rad_to_deg(up.angle_to((wr - el).normalized())), up]
	if float(a.Left[1]) >= 25.0 or float(a.Right[1]) >= 25.0:
		return ""
	var across: Vector3 = w.call("RightArm") - w.call("LeftArm")
	across.y = 0.0
	for side in ["Left", "Right"]:
		var lv: Vector3 = a[side][2]
		lv.y = 0.0
		if lv.length() < 1e-4 or absf(lv.normalized().dot(across.normalized())) < 0.7:
			return ""
	var l: float = a.Left[0]
	var r: float = a.Right[0]
	if l > 70.0 and r > 70.0 and l <= 110.0 and r <= 110.0:
		return "T-pose (%.0f, %.0f)" % [l, r]
	if l > 35.0 and r > 35.0 and l <= 70.0 and r <= 70.0:
		return "A-pose (%.0f, %.0f)" % [l, r]
	return ""
