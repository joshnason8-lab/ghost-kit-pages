extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "Their pre play stance is too rigid."

const NOTE := {"id": "2026-11-03-rigid-stance", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "Their pre play stance is too rigid."}
const Run := preload("res://tests/note_run.gd")


## The stance moves: breathing, weight from foot to foot, the arms and head, never frozen.
func check() -> void:
	await Run.apply(self, "_stance", [], [])
