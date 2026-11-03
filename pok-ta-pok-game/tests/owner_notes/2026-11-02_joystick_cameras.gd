extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.1 (every game)): "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."

const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.1 (every game)", "words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}
const Run := preload("res://tests/note_run.gd")


## On the court-side, high and end cameras, earth and stone courts, the stick pushed up, right, down and left sends the player that way on the screen (within 10 degrees), the way he is told and the way he runs.
func check() -> void:
	await Run.apply(self, "_stick_camera", ["village", "ulama"], [])
	await Run.apply(self, "_stick_camera", ["stone", "classic"], [])
