extends Node
## The trailer's footage (tools/media_kit/make_kit.py cuts it): the home screen with its music, the League Season's
## auction, then AI raids on every ground in turn with the HUD off, on High, with the game's own sound. Recorded
## with Movie Maker at a fixed 30 fps (frames are written, not shown, so a slow software renderer does not matter):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --write-movie OUT.avi \
##       --fixed-fps 30 res://tests/trailer.tscn
## Movie Maker records at the project's window size: make_kit.py puts an override.cfg beside project.godot for
## 1920x1080 while it records. Prints "TRAILER <what> <seconds>" at each moment worth cutting to.
## Drawn without a GPU, High takes seconds a frame, so the matches are seeded and found first, headless and fast:
##   godot --headless --path . --fixed-fps 30 res://tests/trailer.tscn -- scan PLAN.json
## writes the frame of each ground's moments; the recording (-- record PLAN.json) then draws each match only for the
## few seconds round its best moment (a seeded match plays the same each time), the rest not drawn.

const FPS := 30.0
const ACTION := ["touch", "hold", "escape", "takedown"]
const GROUNDS := [["stadium", "IND", "IRN", 11], ["village", "HYD", "JAI", 12], ["dome", "MUM", "PAT", 13],
	["beach", "BAN", "NEP", 14], ["monsoon", "KOL", "CHE", 15]]
const PREFER := ["takedown", "escape", "hold", "touch"]
const BEFORE := 60   # frames drawn before the moment
const AFTER := 75    # and after it

var _mode := "record"
var _plan := {}
var _plan_path := ""

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
	var args := OS.get_cmdline_user_args()
	_mode = args[0] if args.size() > 0 else "record"
	_plan_path = args[1] if args.size() > 1 else "user://trailer_plan.json"
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	Game.settings.sound = _mode == "record"
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	process_priority = -100
	if _mode == "scan":
		for g in GROUNDS:
			_plan[g[0]] = await _scan(g[0], g[1], g[2], int(g[3]))
		var f := FileAccess.open(_plan_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_plan, "  "))
		f.close()
		print("TRAILER plan ", JSON.stringify(_plan))
		get_tree().quit(0)
		return
	_plan = JSON.parse_string(FileAccess.get_file_as_string(_plan_path))
	# The home screen, its match behind it and its music.
	var menu: Node = Game.show_screen("res://ui/main_menu.gd")
	await frames(2)
	for l in menu.find_children("*", "Label", true, false):
		if String(l.text).begins_with("v0."):
			l.modulate.a = 0.0
	await frames(90)
	mark("menu_start")
	await frames(100)
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
		await _record(g[0], g[1], g[2], int(g[3]))
	mark("end")
	get_tree().quit(0)


func _config(arena: String, home: String, away: String, seed: int) -> Dictionary:
	return {"home": home, "away": away, "arena": arena, "mode": "quick", "autoplay": true, "length": 1,
		"difficulty": 3, "seed": seed}


## Headless: the frame (from the match's start) of each kind of moment the first time it happens, and of the first
## point, over the first 45 s of raiding.
func _scan(arena: String, home: String, away: String, seed: int) -> Dictionary:
	Game.start_match(_config(arena, home, away, seed))
	var m: Node = Game.current
	var out := {}
	var fr := [0]
	m.game_event.connect(func(kind, info):
		if kind in PREFER and not out.has(kind):
			out[kind] = fr[0]
		elif kind == "raid_end" and not out.has("point") and (int(info.raid_pts) > 0 or int(info.def_pts) > 0):
			out["point"] = fr[0])
	var raid_at := -1
	while fr[0] < 30 * 120:
		await get_tree().process_frame
		fr[0] += 1
		if raid_at < 0 and m.phase == "raid":
			raid_at = fr[0]
		if raid_at >= 0 and (fr[0] - raid_at > 30 * 45 or out.has("takedown") and out.has("point")):
			break
	print("TRAILER scan %s %s" % [arena, JSON.stringify(out)])
	return out


## The same seeded match, drawn only round its best moment: marks "<ground>_start", "<ground>_<moment>" (as it
## happens in this run) and "<ground>_end".
func _record(arena: String, home: String, away: String, seed: int) -> void:
	var p: Dictionary = _plan.get(arena, {})
	var at := -1
	var what := ""
	for k in PREFER:
		if p.has(k):
			at = int(p[k])
			what = k
			break
	if at < 0:
		return
	Game.start_match(_config(arena, home, away, seed))
	var m: Node = Game.current
	m.hud.visible = false
	var fr := [0]
	m.game_event.connect(func(kind, _info):
		if kind == what:
			mark("%s_%s" % [arena, kind]))
	while fr[0] < at + AFTER:
		await get_tree().process_frame
		fr[0] += 1
		m.hud.visible = false
		var drawn: bool = fr[0] >= at - BEFORE - 3
		if m.cam and m.cam.cam:
			m.cam.cam.cull_mask = 0xFFFFF if drawn else 0
		if fr[0] == at - BEFORE:
			mark("%s_start" % arena)
	mark("%s_end" % arena)
