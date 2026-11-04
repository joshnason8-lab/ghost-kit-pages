extends "res://tests/test_runner.gd"
## Only the controls and league-option tests (quicker while working on them).

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	await _controls()
	await _league_options()
	await _sanctions_and_injury()
	print("controls: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
