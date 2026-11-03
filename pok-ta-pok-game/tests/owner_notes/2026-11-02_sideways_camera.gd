extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.0 on the A16): "Sideways camera... you can't see all of the game"

const NOTE := {"id": "2026-11-02-sideways-camera", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.0 on the A16", "words": "Sideways camera... you can't see all of the game"}
const Run := preload("res://tests/note_run.gd")


## Through AI matches on the earth and stone courts, on 20:9, 16:9 and 4:3 screens: the ball always in the court-side camera's picture, the players near it in it, and on the stone court the alley's near edge over the near wall.
func check() -> void:
	await Run.apply(self, "_tv_camera", ["village", "ulama"], [])
	await Run.apply(self, "_tv_camera", ["stone", "classic"], [])
