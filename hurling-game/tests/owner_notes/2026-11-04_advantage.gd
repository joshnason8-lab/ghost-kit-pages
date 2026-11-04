extends WsgOwnerNote
## The owner, 2026-11-04 (Hurling 0.24.13, through the lead): "Follow the GAA Official Guide: advantage for aggressive fouls only."

const NOTE := {"id": "2026-11-04-advantage", "game": "hurling", "date": "2026-11-04", "version": "Hurling 0.24.13", "words": "Follow the GAA Official Guide: advantage for aggressive fouls only."}
const Kit := preload("res://tests/note_kit.gd")


## In a match: a technical foul (over-carrying) is a free at once, never advantage (5.44: advantage "When an Aggressive
## Foul is committed"); an aggressive foul on a man with the ball and time and space can be played on.
func check() -> void:
	expect(not Rules.may_play_advantage("FOUL_STEPS", true, true), "advantage offered for a technical foul")
	expect(Rules.may_play_advantage("FOUL_PUSH", false, true), "no advantage for an aggressive foul with time and space")
	var m: Node = await Kit.match(tree, {"seed": 7}, 3)
	m.phase = m.P.LIVE
	m.advantage = {}
	m._technical_foul(m.player_by_num(0, 11), "FOUL_STEPS")
	expect(m.advantage.is_empty() and m.phase == m.P.DEAD, "a technical foul played on (advantage %s, phase %d)" % [m.advantage, m.phase])
	await Kit.done(tree, m)
