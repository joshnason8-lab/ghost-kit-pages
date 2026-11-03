extends WsgOwnerNote
## The owner, 2026-11-03 (every game): "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."

const NOTE := {"id": "2026-11-03-props-solid", "game": "pok-ta-pok", "date": "2026-11-03", "version": "every game", "words": "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."}
const Run := preload("res://tests/note_run.gd")


## At every venue: the props are solid, nobody stands in one, the ball struck at a bench, the stands or the coping comes back off it, and in play a knock is out.
func check() -> void:
	await Run.apply(self, "_props_solid", ["village", "ulama"], [])
	await Run.apply(self, "_props_solid", ["festival", "ulama"], [])
	await Run.apply(self, "_props_solid", ["stone", "classic"], [])
	await Run.apply(self, "_props_solid", ["night", "classic"], [])
