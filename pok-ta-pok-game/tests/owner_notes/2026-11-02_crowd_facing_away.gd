extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.0 on the A16): "crowd moves poorly and is facing away from the game often"

const NOTE := {"id": "2026-11-02-crowd-facing-away", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.0 on the A16", "words": "crowd moves poorly and is facing away from the game often"}
const Run := preload("res://tests/note_run.gd")


## Every venue at every graphics level: the fans turned to the play (each within its limit of the nearest play), none backwards, the seated cards too; and they react.
func check() -> void:
	await Run.apply(self, "_crowd_faces", [], [])
