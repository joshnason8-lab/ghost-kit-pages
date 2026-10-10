extends Node
## Root node. Holds whichever screen or match is active; Game swaps it.

func _ready() -> void:
	Game.main = self
	Game.goto_menu()
