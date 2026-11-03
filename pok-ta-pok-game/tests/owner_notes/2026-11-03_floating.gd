extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "Players are floating around when they goto get the ball."

const NOTE := {"id": "2026-11-03-floating", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "Players are floating around when they goto get the ball."}
const Run := preload("res://tests/note_run.gd")


## Through whole matches on both courts: one writer per player, nothing jumps in a frame, the stride matches the speed (no gliding).
func check() -> void:
	await Run.apply(self, "_match_and_motion", ["village", "ulama"], [])
	await Run.apply(self, "_match_and_motion", ["stone", "classic"], [])
