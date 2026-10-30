extends Node
## Root node. Holds whichever screen or match is active; Game swaps it.

func _ready() -> void:
	# The Firebase Test Lab build (export preset "Android TestLab"): a match plays itself at each tier, measured.
	if OS.has_feature("testlab"):
		get_tree().change_scene_to_file.call_deferred("res://testlab/testlab_run.tscn")
		return
	Game.main = self
	Ultra.arm()
	# The loading screen first: it gets the sounds, clips and bodies ready, then the home screen behind it.
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
