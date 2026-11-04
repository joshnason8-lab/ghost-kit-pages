extends WsgOwnerNote
const NOTE := {"id": "2026-11-04-break-free-presses", "game": "kabaddi", "date": "2026-11-04", "version": "0.14.20-beta",
	"words": "a held player's presses always do something visible (the lead's record: after one failed lion jump, Break free did nothing until he was down)"}
const U := preload("res://tests/owner_note_util.gd")


## The user's raider held at the ankle, every try failing, Break free pressed every 0.2 s: each press starts a try or is
## kept for the moment the last one is over (the button filling meanwhile), and the tries keep coming while he is held -
## not one lion jump and then nothing for 1.4 s. In a Quick Match at every difficulty (the lead).
func check() -> void:
	for d in (load("res://game/match.gd") as GDScript).get_script_constant_map()["PROFILES"].size():
		await _held(d)


func _held(difficulty: int) -> void:
	var m: Node = U.start(tree, {"first_raider": 0, "passive": true, "difficulty": difficulty})
	await U.until_raid(tree, m)
	var rd: Athlete = m.raider
	expect(rd == m.controlled, "the user is not raiding")
	var dw: Athlete = m.defenders()[0]
	dw.tackle_kind = "ankle"
	dw.position = rd.position + Vector3(1.2, 0, 0)
	m._attach(dw, false, "leg_l")
	m.lab_force["escape"] = false   # every try fails: the presses are what is checked, not the odds
	expect(m.raid.holders.has(dw), "the hold did not take")
	rd.cooldown = 0.0
	var tries := 0
	var dead := 0
	var filled := 0
	var t := 0.0
	var next_press := 0.0
	var was := String(rd.state)
	var first_t := -1.0
	var second_t := -1.0
	while t < 2.6 and is_instance_valid(m) and m.phase == "raid" and not m.raid.holders.is_empty():
		if t >= next_press:
			next_press = t + 0.2
			var before := String(rd.state)
			m._break_free()
			var tried: bool = String(rd.state) != before
			var kept: bool = bool(m.raid.get("break_queued", false))
			if not tried and not kept:
				dead += 1
		await U.frames(tree, 1)
		t += 1.0 / 30.0
		var now := String(rd.state)
		if was == "held" and now in m.ESCAPING:
			tries += 1
			if first_t < 0.0:
				first_t = t
			elif second_t < 0.0:
				second_t = t
		was = now
		var c = m.hud.get("controls") if m.hud else null
		if c != null and rd.cooldown > 0.0 and now == "held" and float(c.recharge) > 0.0:
			filled += 1
	var at := "difficulty %d: " % difficulty
	expect(dead == 0, at + "%d Break free presses while held did nothing (neither a try nor kept for the next)" % dead)
	expect(tries >= 2, at + "only %d tries in %.1f s held, pressing every 0.2 s" % [tries, t])
	if second_t > 0.0:
		expect(second_t - first_t <= 1.2, at + "the second try came %.2f s after the first" % (second_t - first_t))
	info(at + "%d tries in %.1f s held (the second %.2f s after the first); the button filled on %d frames" % [tries, t,
		second_t - first_t if second_t > 0.0 else -1.0, filled])
	m.queue_free()
	await U.frames(tree, 2)
