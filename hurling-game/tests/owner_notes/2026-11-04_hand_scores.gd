extends WsgOwnerNote
## The owner, 2026-11-04 (Hurling 0.24.13, through the lead): "Follow the GAA Official Guide: a player in possession can't score with the hand, hand-passed points included. Restart is a free out."

const NOTE := {"id": "2026-11-04-hand-scores", "game": "hurling", "date": "2026-11-04", "version": "Hurling 0.24.13", "words": "Follow the GAA Official Guide: a player in possession can't score with the hand, hand-passed points included. Restart is a free out."}
const Kit := preload("res://tests/note_kit.gd")


## In a match: a ball hand-passed over the bar by the attacking side is waved off and the defenders have a free from
## where the hand-pass was made; a struck point still counts.
func check() -> void:
	var m: Node = await Kit.match(tree, {"seed": 7}, 3)
	var s := float(m.dir(0))
	var from := Vector3((Pitch.HALF_L - 15.0) * s, 1.2, -3.0)
	m.phase = m.P.LIVE
	m.ball.last_team = 0
	m.ball.last_kind = "hand_pass"
	m.ball.set_meta("hand_from", from)
	var pts: int = m.score[0][1]
	m._over_end_line(Vector3(Pitch.HALF_L * s, Pitch.BAR_H + 1.0, -1.0), s)
	expect(m.score[0][1] == pts, "a hand-passed point counted")
	var r: Dictionary = m.restart
	expect(String(r.get("kind", "")) == "free" and int(r.get("team", -1)) == 1, "after a hand-passed point: %s, not the defenders' free" % r)
	if r.has("spot"):
		expect(Vector3(r.spot).distance_to(Vector3(from.x, 0, from.z)) < 0.6, "the free out is %.1f m from where the hand-pass was made" % Vector3(r.spot).distance_to(Vector3(from.x, 0, from.z)))
	m.phase = m.P.LIVE
	m.ball.last_kind = "strike"
	m._over_end_line(Vector3(Pitch.HALF_L * s, Pitch.BAR_H + 1.0, -1.0), s)
	expect(m.score[0][1] == pts + 1, "a struck point did not count")
	await Kit.done(tree, m)
