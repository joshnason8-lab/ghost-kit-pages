extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.0 on the A16): "base position is still like an A pose"

const NOTE := {"id": "2026-11-02-a-pose", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.0 on the A16", "words": "base position is still like an A pose"}
const Run := preload("res://tests/note_run.gd")


## The ready stance at every level: knees bent, the arms in close and bent, no A-pose.
func check() -> void:
	await Run.apply(self, "_stance", [], [])
