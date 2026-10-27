extends Node
## The trailer's footage (tools/media_kit/make_kit.py cuts it): the home screen with its music, the League Season's
## auction, then AI raids on every ground in turn with the HUD off, on High, with the game's own sound. Recorded
## with Movie Maker at a fixed 30 fps (frames are written, not shown, so a slow software renderer does not matter):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --write-movie OUT.avi \
##       --fixed-fps 30 res://tests/trailer.tscn
## Movie Maker records at the project's window size: make_kit.py puts an override.cfg beside project.godot for
## 1920x1080 while it records. Prints "TRAILER <what> <seconds>" at each moment worth cutting to.

const FPS := 30.0
const ACTION := ["touch", "hold", "escape", "takedown"]
const GROUNDS := [["stadium", "IND", "IRN"], ["village", "HYD", "JAI"], ["dome", "MUM", "PAT"],
	["beach", "BAN", "NEP"], ["monsoon", "KOL", "CHE"]]

var _f := 0


func _process(_dt: float) -> void:
	_f += 1


func t() -> float:
	return _f / FPS


func mark(what: String) -> void:
	print("TRAILER %s %.2f" % [what, t()])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	Game.settings.sound = true
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	process_priority = -100
	# The home screen, its match behind it and its music.
	var menu: Node = Game.show_screen("res://ui/main_menu.gd")
	await frames(2)
	for l in menu.find_children("*", "Label", true, false):
		if String(l.text).begins_with("v0."):
			l.modulate.a = 0.0
	await frames(90)
	mark("menu_start")
	await frames(120)
	mark("menu_end")
	# The League Season's auction, a franchise to build.
	Game.delete_season()
	var se = Game.new_season("PAT")
	se.seed_value = 4242
	Game.save_season()
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(120)
	mark("auction_start")
	await frames(90)
	mark("auction_end")
	Game.delete_season()
	for g in GROUNDS:
		await _ground(g[0], g[1], g[2])
	mark("end")
	get_tree().quit(0)


## Raids on one ground until two moments have happened there (or 40 s), each marked: "<ground>_<event> t".
func _ground(arena: String, home: String, away: String) -> void:
	Game.start_match({"home": home, "away": away, "arena": arena, "mode": "quick", "autoplay": true, "length": 1,
		"difficulty": 3})
	var m: Node = Game.current
	m.hud.visible = false
	await frames(2)
	m.cam.cam.cull_mask = 0   # nothing to see while the teams walk out: skip drawing it
	var guard := 0
	while m.phase != "raid" and guard < 1500:
		await get_tree().process_frame
		guard += 1
	m.cam.cam.cull_mask = 0xFFFFF
	mark("%s_start" % arena)
	var got := [0]
	var seen := {}
	m.game_event.connect(func(kind, info):
		if kind in ACTION and not seen.has(kind):
			seen[kind] = true
			got[0] += 1
			mark("%s_%s" % [arena, kind])
		elif kind == "raid_end" and (int(info.raid_pts) > 0 or int(info.def_pts) > 0):
			mark("%s_point" % arena))
	var start := t()
	while (got[0] < 2 or t() - start < 6.0) and t() - start < 40.0:
		await get_tree().process_frame
		m.hud.visible = false
	await frames(60)   # what follows the last moment, to cut away on
	mark("%s_end" % arena)
