extends Node
## The home screen as a phone shows it, in both languages, for a look:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/menu_view.tscn -- /out
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_LOW
	for size in [Vector2i(1280, 720), Vector2i(2400, 1080)]:
		get_tree().root.size = size
		DisplayServer.window_set_size(size)
		for lang in ["en", "ga"]:
			Game.set_language(lang)
			Game.goto_menu()
			for i in 40:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "/menu_%dx%d_%s.png" % [size.x, size.y, lang])
	get_tree().quit()
