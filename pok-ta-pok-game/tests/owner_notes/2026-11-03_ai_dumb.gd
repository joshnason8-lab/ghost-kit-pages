extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "The AI is dumb and barely hits the ball after the serve."

const NOTE := {"id": "2026-11-03-ai-dumb", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "The AI is dumb and barely hits the ball after the serve."}
const Run := preload("res://tests/note_run.gd")


## Two minutes of the computer against itself on each court: it meets the ball with the hip (20 strikes or more, far more than dives) and the rallies go on.
func check() -> void:
	await Run.apply(self, "_ai_plays", ["village", "ulama"], ["meets the ball with the hip", "rallies go on"])
	await Run.apply(self, "_ai_plays", ["stone", "classic"], ["meets the ball with the hip", "rallies go on"])
