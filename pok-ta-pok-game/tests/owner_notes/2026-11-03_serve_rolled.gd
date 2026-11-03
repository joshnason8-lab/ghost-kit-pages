extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "The AI is rolling the ball on the serve it should set up for bouncing."

const NOTE := {"id": "2026-11-03-serve-rolled", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "The AI is rolling the ball on the serve it should set up for bouncing."}
const Run := preload("res://tests/note_run.gd")


## Every serve the computer makes on both courts bounces up off the ground; none rolled.
func check() -> void:
	await Run.apply(self, "_ai_plays", ["village", "ulama"], ["serve bounces up"])
	await Run.apply(self, "_ai_plays", ["stone", "classic"], ["serve bounces up"])
