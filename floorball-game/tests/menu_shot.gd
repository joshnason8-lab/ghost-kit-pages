extends Node
## One picture of the home screen after its live match has settled (for checking the framing):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/menu_shot.tscn -- OUT.png
func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.goto_menu()
	for i in 240:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
