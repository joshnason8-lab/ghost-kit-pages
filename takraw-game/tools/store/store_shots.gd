extends Node
## The store's screenshots, 1920 x 1080, from the game itself: four moments from real matches (a roll spike as it is
## hit at the National Arena, a serve at the beach, a block in the mall, a doubles rally in the park), the score
## showing as in a match, and the menus (the last in Thai). Writes store/graphics/screenshots/ and
## store/graphics/feature_src.png (for tools/store/make_feature.py). Made by tools/media/trailer.gd in its "store" mode
## (each moment found by playing its match on within a frame, then pictured), so it takes a few minutes:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tools/store/store_shots.tscn


func _ready() -> void:
	var t: Node = (load("res://tools/media/trailer.gd") as Script).new()
	t.mode = "store"
	t.out = ProjectSettings.globalize_path("res://store/graphics/screenshots")
	add_child(t)
