extends Node
## Root node. Holds whichever screen or match is active; Game swaps it.

func _ready() -> void:
	Game.main = self
	# The loading screen first: it gets the sounds, clips and bodies ready, then the home screen behind it.
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
