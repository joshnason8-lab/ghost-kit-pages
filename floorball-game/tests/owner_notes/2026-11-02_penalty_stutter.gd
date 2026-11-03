extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta), with a video of a penalty shot.

const NOTE := {"id": "2026-11-02-penalty-stutter", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Attached is a video of the penalty kick. The running is a weird stutter."}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots, three shots skated in with the joystick held up: once he is up to speed the shooter's run is smooth -
## the game's own speed over the ground never under 60% of its fastest, and (with the shared foundation's body) its
## hips' travel each frame never under half their usual - no stop-start.
func check() -> void:
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	Lib.host(tree).add_child(m)
	var shots := 0
	var game_speeds := []
	var hips_speeds := []
	var prev_hips := [Vector3.INF]
	var run_t := 0.0
	while shots < 3:
		var st := String(m._so.get("stage", ""))
		m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
		var sh: Player = m._so.get("shooter")
		var p0: Vector2 = sh.pos if sh else Vector2.ZERO
		await tree.physics_frame
		if st == "run" and not bool(m._so.get("shot", false)) and sh:
			run_t += 1.0 / 60.0
			if run_t > 0.8 and (sh.pos.x * float(m._so.get("dir", 1.0))) < Rules.GOAL_LINE - 4.0:
				game_speeds.append(sh.pos.distance_to(p0) * 60.0)
				if sh.link and sh.link.body:
					var h := sh.link.body.bone_world("Hips").origin
					if prev_hips[0] != Vector3.INF:
						hips_speeds.append(Vector2(h.x - prev_hips[0].x, h.z - prev_hips[0].z).length())
					prev_hips[0] = h
			if (sh.pos.x * float(m._so.get("dir", 1.0))) > Rules.GOAL_LINE - 4.0:
				m._on_action("SHOOT")
		else:
			if run_t > 0.0:
				shots += 1
			run_t = 0.0
			prev_hips[0] = Vector3.INF
		if int(m._practice.get("shot", 0)) >= 3:
			break
	var hi := Lib.pct(game_speeds, 1.0)
	var lo := Lib.pct(game_speeds, 0.0)
	info("%d frames up to speed: %.2f to %.2f m/s" % [game_speeds.size(), lo, hi])
	expect(game_speeds.size() > 60, "too little of the run seen (%d frames)" % game_speeds.size())
	expect(lo >= hi * 0.6, "the run stutters: %.2f to %.2f m/s" % [lo, hi])
	if not hips_speeds.is_empty():
		var hh := Lib.pct(hips_speeds, 0.95)
		var hl := Lib.pct(hips_speeds, 0.05)
		info("the body's hips as drawn: %.3f to %.3f m a frame (5%% to 95%%)" % [hl, hh])
		expect(hl >= hh * 0.5, "the body as drawn stutters: its hips %.3f to %.3f m a frame" % [hl, hh])
	await Lib.done(tree, m)
