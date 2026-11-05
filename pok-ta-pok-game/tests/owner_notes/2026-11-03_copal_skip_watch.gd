extends WsgOwnerNote
## The owner, 2026-11-03 (Pok Ta Pok 0.6.7): "Should have ability to skip the copal on AI match watching too."

const NOTE := {"id": "2026-11-03-copal-skip-watch", "game": "pok-ta-pok", "date": "2026-11-03", "version": "Pok Ta Pok 0.6.7", "words": "Should have ability to skip the copal on AI match watching too."}
const Run := preload("res://tests/note_run.gd")


## Watching the computer play: a SKIP button over the copal, and it passes it.
func check() -> void:
	await Run.apply(self, "_watch_ai", [], ["copal"])
