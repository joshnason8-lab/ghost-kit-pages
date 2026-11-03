extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.7): "Ball is hitting too high on body now sometimes, when it should be at the hip."

const NOTE := {"id": "2026-11-03-hip-height", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.7", "words": "Ball is hitting too high on body now sometimes, when it should be at the hip."}
const Run := preload("res://tests/note_run.gd")


## Through two minutes on each court no standing hip meets the ball higher than the cap over the hip (never the belly or chest).
func check() -> void:
	await Run.apply(self, "_ai_plays", ["village", "ulama"], ["never the belly or chest"])
	await Run.apply(self, "_ai_plays", ["stone", "classic"], ["never the belly or chest"])
