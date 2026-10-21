extends "res://tests/test_runner.gd"
## Only the controls test (quicker while working on them).

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	await _controls()
	print("controls: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
