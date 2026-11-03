extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.2 on the A16): "This does not seem like it has the shared foundation."

const NOTE := {"id": "2026-11-03-shared-foundation", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.2 on the A16", "words": "This does not seem like it has the shared foundation."}
const Run := preload("res://tests/note_run.gd")


## The shared foundation's bodies and motion are what is drawn, on Medium and High and on Low (the A16) too.
func check() -> void:
	await Run.apply(self, "_foundation", [], [])
