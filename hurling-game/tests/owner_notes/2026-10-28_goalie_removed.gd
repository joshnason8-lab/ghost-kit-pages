extends WsgOwnerNote
## The owner, 2026-10-28 (Hurling 0.13.0): "The goalie can be removed"

const NOTE := {"id": "2026-10-28-goalie-removed", "game": "hurling", "date": "2026-10-28", "version": "Hurling 0.13.0", "words": "The goalie can be removed"}
const Kit := preload("res://tests/note_kit.gd")

## Free-taking practice: no goalkeeper in the goal, the taker alone on the pitch but for the umpires.
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "practice", "user_team": 0, "seed": 3}, 10, true)
	var shown := 0
	for p in m.all_players():
		if (p as Player).visible:
			shown += 1
	expect(not m.keeper_of(1).visible, "the goalkeeper is in the goal")
	expect(shown == 1, "%d players on the pitch (the taker alone)" % shown)
	await Kit.done(tree, m)
