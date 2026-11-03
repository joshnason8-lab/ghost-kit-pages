extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "For some reason while a player is running his arm is stuck sticking straight out."

const NOTE := {"id": "2026-11-03-arm-stuck-out-running", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "For some reason while a player is running his arm is stuck sticking straight out."}
const KK := preload("res://tests/note_kk.gd")


## A reach ends (TAG, and the reach the chaser makes for a touch): his arm comes back, whether he runs or stands - over
## TAG pressed running, standing, with a runner in reach and with none.
func check() -> void:
	var m: Node = await KK.play(tree)
	for case in [["running, a runner near", Vector2(1, 0), true], ["running, nobody near", Vector2(1, 0), false],
			["standing, a runner near", Vector2.ZERO, true], ["standing, nobody near", Vector2.ZERO, false]]:
		var a: Athlete = m.active
		a.position = Vector3(float(m.f.square_x[4]), 0, float(m.chase.half) * 3.0)
		a.vel = Vector3.ZERO
		a.act = ""
		for d in m.batch:
			d.position = a.position + Vector3(1.2, 0, 0) if case[2] and d == m.batch[0] else Vector3(0, 0, -float(m.chase.half) * 6.5)
		m._reach_ready = 0.0
		m.controls.joystick = case[1]
		await frame()
		m._on_action("TAG")
		for i in 45:
			m.controls.joystick = case[1]
			await frame()
		var a2: Athlete = m.active
		expect(a2.act != "reach" and a2.body.grip == Vector3.INF and a2.body.clip != "reach",
			"%s: 1.5 s after TAG he still reaches (act '%s', clip '%s')" % [case[0], a2.act, a2.body.clip])
	m.controls.joystick = Vector2.ZERO
	await KK.done(tree, m)
