extends Node
## The store's screenshots, rendered from the game at 1920 x 1080 on High graphics, saved as JPEG in
## store/graphics/screenshots/, and a clean frame of the rink for the feature graphic (tools/store/make_feature.py):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/store/store_shots.tscn

const OUT := "res://store/graphics/screenshots"


func _ready() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	await frames(4)
	# 1. A match in the city arena, the attack building.
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "quick", "seed": 21, "period": 8.0})
	await frames(560)
	await shot(dir, "01_arena")
	var m: Node = Game.current
	# 2. A referee's call on the screen.
	m.hud.call_card(tr("CALL_PEN2"), m._offence_line("hook"), 1)
	m.rules.add_penalty(1, String(m.squads[1][6].id), "pen2")
	m.hud.refresh()
	await frames(3)
	await shot(dir, "02_call")
	# 3. From high.
	m.cam.mode = Game.CAM_HIGH
	await frames(160)
	await shot(dir, "03_high")
	# 4. The women's game in a sports hall.
	Game.start_match({"home": "SUI", "away": "CZE", "venue": "hall", "user_team": 0, "mode": "quick", "seed": 9, "period": 8.0, "women": true})
	await frames(620)
	await shot(dir, "04_hall")
	# 5. The home screen: the whiteboard and a match behind it.
	Game.goto_menu()
	await frames(240)
	await shot(dir, "05_home")
	# 6. How to Play: the referees' signs.
	Game.show_screen("res://ui/howto_screen.gd", {"tab": 2})
	await frames(10)
	await shot(dir, "06_signs")
	# 7. The World Finals.
	var cup = Game.new_cup("FIN", false)
	cup.sim_next()
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(10)
	await shot(dir, "07_world_finals")
	Game.delete_cup()
	# 8. The rink, empty of the HUD, for the feature graphic.
	Game.start_match({"home": "SWE", "away": "CZE", "venue": "arena", "user_team": -1, "demo": true, "mode": "quick", "seed": 33, "period": 8.0})
	await frames(400)
	await shot(dir, "feature_src", false)
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(dir: String, name: String, jpg := true) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	if jpg:
		img.save_jpg(dir.path_join(name + ".jpg"), 0.9)
	else:
		img.save_png(dir.path_join("../" + name + ".png"))
	print("shot ", name)
