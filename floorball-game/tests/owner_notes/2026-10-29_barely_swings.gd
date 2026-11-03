extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.9).

const NOTE := {"id": "2026-10-29-barely-swings", "game": "floorball", "date": "2026-10-29", "version": "0.9",
	"words": "the player barely swings in the mini game it looks bad"}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots, SHOOT held for a full wind-up then let go: the stick is drawn back and up (its blade at least 50 cm
## off the floor at the top of the wind-up) and comes through after the shot (the blade forward of the body).
func check() -> void:
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	Lib.host(tree).add_child(m)
	var top := 0.0
	var wound := false
	var through := 0.0
	var phase := 0
	for f in 60 * 12:
		var st := String(m._so.get("stage", ""))
		var sh: Player = m._so.get("shooter")
		m.touch.joystick = Vector2(0, -1) if st == "run" and phase == 0 else Vector2.ZERO
		if st == "run" and sh and phase == 0 and (sh.pos.x * float(m._so.get("dir", 1.0))) > 4.0:
			m.touch._key_held[0] = true
			m._on_action("SHOOT")
			phase = 1
		if phase == 1 and bool(m._so.get("winding", false)) and float(m._so.get("wind", 0.0)) > 0.55:
			m.touch._key_held[0] = false
			phase = 2
		await tree.process_frame
		if sh and sh.body and phase >= 1:
			var heel: Vector3 = sh.body.skeleton.global_transform * (sh.body.stick_transform() * Vector3(0, -Body.STICK_LEN, 0))
			if phase == 1 or (phase == 2 and bool(m._so.get("winding", false))):
				top = maxf(top, heel.y)
				wound = wound or sh.windup > 0.9
			elif phase == 2:
				var fwd := Vector2(cos(sh.facing), sin(sh.facing))
				through = maxf(through, (Vector2(heel.x, heel.z) - sh.pos).dot(fwd))
		if phase == 2 and bool(m._so.get("shot", false)) and through > 0.0 and f % 60 == 0 and st != "run":
			break
	info("the wind-up: the blade %.2f m off the floor at its top (wound up fully: %s); the follow-through %.2f m in front" % [top, wound, through])
	expect(top >= 0.5, "the wind-up only lifts the blade %.2f m" % top)
	expect(through >= 0.3, "no follow-through (the blade %.2f m in front)" % through)
	await Lib.done(tree, m)
