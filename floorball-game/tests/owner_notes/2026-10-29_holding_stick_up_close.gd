extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.9).

const NOTE := {"id": "2026-10-29-holding-stick-up-close", "game": "floorball", "date": "2026-10-29", "version": "0.9",
	"words": "reference how hurling session did their hands holding the Hurley, the player doesn’t look like he’s holding the stick when up close"}

const Lib := preload("res://tests/note_lib.gd")


## Up close - penalty shots, High: the shooter skating in, winding up and shooting, as drawn: his top fist on the shaft
## (within 3 cm of its line) in every frame and the lower fist in 95% of those it holds it.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var keep: int = Game.settings.graphics
	Game.settings.graphics = Game.GFX_HIGH
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	Lib.host(tree).add_child(m)
	var top := [0, 0]
	var low := [0, 0]
	var hooked := []
	for f in 60 * 20:
		var st := String(m._so.get("stage", ""))
		var sh: Player = m._so.get("shooter")
		m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
		if st == "run" and sh and (sh.pos.x * float(m._so.get("dir", 1.0))) > Rules.GOAL_LINE - 6.0:
			m._on_action("SHOOT")
		if sh and sh.link and not hooked.has(sh):
			hooked.append(sh)
			sh.link.measure = true
			sh.link.body.posed.connect(func():
				if String(m._so.get("stage", "")) != "run":
					return
				var lf: Dictionary = sh.link.last_fists
				if lf.has(sh.link.top):
					top[1] += 1
					if float(lf[sh.link.top]) <= 0.03:
						top[0] += 1
				if lf.has(sh.link.low):
					low[1] += 1
					if float(lf[sh.link.low]) <= 0.03:
						low[0] += 1)
		await tree.physics_frame
	info("up close: the top fist on the shaft %d/%d, the lower %d/%d" % [top[0], top[1], low[0], low[1]])
	expect(top[1] > 100 and top[0] == top[1], "up close the top fist off the shaft in %d of %d frames" % [top[1] - top[0], top[1]])
	expect(low[1] > 100 and low[0] >= low[1] * 0.95, "up close the lower fist off the shaft in %d of %d frames" % [low[1] - low[0], low[1]])
	await Lib.done(tree, m)
	Game.settings.graphics = keep
