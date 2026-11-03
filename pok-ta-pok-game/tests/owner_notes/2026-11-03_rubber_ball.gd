extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "The ball is rubber and should have more bounce."

const NOTE := {"id": "2026-11-03-rubber-ball", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "The ball is rubber and should have more bounce."}
const Run := preload("res://tests/note_run.gd")


## Dropped from the hip the rubber ball comes back up off the earth and higher off the stone.
func check() -> void:
	await Run.apply(self, "_ball", [], ["comes back to", "bounces higher"])
