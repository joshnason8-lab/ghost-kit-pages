extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.7): "Toss the ball up higher on serve."

const NOTE := {"id": "2026-11-03-serve-toss", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.7", "words": "Toss the ball up higher on serve."}
const Run := preload("res://tests/note_run.gd")


## Every serve on both courts goes up at least 1.6 m.
func check() -> void:
	await Run.apply(self, "_ai_plays", ["village", "ulama"], ["tossed up high"])
	await Run.apply(self, "_ai_plays", ["stone", "classic"], ["tossed up high"])
