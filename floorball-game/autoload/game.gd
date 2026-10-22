extends Node
## Global state: settings, saves, the whiteboard theme, plurals, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const CUP_PATH := "user://cup.json"
const SEASON_PATH := "user://season.json"
const RECORDS_PATH := "user://records.json"

const SLUG := "floorball-unleashed"
## The game's privacy policy and help pages (Settings > About).
const PRIVACY_URL := "https://joshnason8-lab.github.io/ghost-kit-pages/floorball-unleashed/privacy.html"
const SUPPORT_URL := "https://joshnason8-lab.github.io/ghost-kit-pages/floorball-unleashed/support.html"

## Code, name in the language itself, name in English. The sport's heartland first (Sweden, Finland, Switzerland,
## Czechia), then the rest of its Europe, then Japan and Thailand, and English for everyone else (docs/LANGUAGES.md).
const LANGUAGES := [
	["en", "English", "English"],
	["sv", "Svenska", "Swedish"],
	["fi", "Suomi", "Finnish"],
	["de", "Deutsch", "German"],
	["fr", "Français", "French"],
	["it", "Italiano", "Italian"],
	["cs", "Čeština", "Czech"],
	["sk", "Slovenčina", "Slovak"],
	["nb", "Norsk bokmål", "Norwegian"],
	["da", "Dansk", "Danish"],
	["lv", "Latviešu", "Latvian"],
	["et", "Eesti", "Estonian"],
	["pl", "Polski", "Polish"],
	["ja", "日本語", "Japanese"],
	["th", "ไทย", "Thai"],
]

const CAM_TV := 0       # the broadcast camera: high on the side, opposite the benches, following the ball down the rink
const CAM_HIGH := 1     # higher and further back: more of the rink, smaller players
const CAM_END := 2      # behind the goal you attack, looking up the rink

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second at 80% render scale; Smooth, 60 a second (the
## default); Max, as many as the screen shows. Each a whole fraction of the screen's refresh rate.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds. Never in a match you are only watching.
const HAPTICS := {
	"shot": [24, 0.55],                          # your shot leaves the blade
	"steal": [18, 0.45],                         # you win the ball
	"goal": [[40, 0.8], 70, [70, 1.0]],          # your team scores
	"conceded": [80, 0.5],                       # your team concedes
	"foul": [70, 0.6],                           # a referee whistles you
	"save": [30, 0.7],                           # your goalkeeper saves (you play him)
}

# The whiteboard palette: white board and paper, marker inks, magnets, the hall's birch and the rink's blue floor.
const C_BG := Color("e9ecea")        # the whiteboard
const C_PANEL := Color("ffffff")     # paper pinned to it
const C_PANEL_HI := Color("f1f5fb")
const C_FRAME := Color("aab3bc")     # the board's aluminium frame
const C_INK := Color("1f2933")       # black marker
const C_MUTED := Color("5b6673")
const C_BLUE := Color("1d4ed8")      # blue marker: your team, the primary action
const C_RED := Color("d62839")       # red marker: the opponents, penalties
const C_GREEN := Color("0f8b5f")     # green marker: good
const C_MAGNET := Color("f08a24")    # an orange magnet: the thing to press
const C_YELLOW := Color("f5c518")
const C_BIRCH := Color("d9c296")
const C_FLOOR := Color("2c66ad")
const C_GOOD := Color("0f8b5f")
const C_DANGER := Color("d62839")
const C_GOLD := Color("c8961e")

## Period lengths a match can be played at (minutes); the laws' 20 is the last.
const PERIODS := [4, 8, 12, 20]

var settings := {
	"language": "",         # "" follows the phone's language
	"camera": CAM_TV,
	"graphics": -1,         # -1 until the first run picks one for the phone (detect_graphics)
	"auto_gfx": true,       # lower the graphics by itself if a match runs slowly
	"fps": FPS_SMOOTH,
	"sound": true,
	"music": true,
	"vibration": true,
	"left_handed": false,
	"btn_size": 0,          # the match buttons: 0 Normal, 1 Large, 2 Extra large
	"btn_places": [],       # where you moved the match buttons, as fractions of the screen; [] their own places
	"difficulty": 1,        # 0 Rookie, 1 Club, 2 Elite, 3 World class
	"period": 0,            # PERIODS index: the length of a period
	"rules": 0,             # 0 the IFF Rules of the Game; 1 a league's: running clock but for the last 3 minutes
	"auto_switch": true,    # the player you run changes to the one nearest the ball by itself
	"game_speed": 0,        # 0 Steady (80% of real pace, the default on a phone), 1 Real
	"seen_howto": false,
	"tips": true,           # the coach's tips in a first match (game/hud.gd coach()), each once
	"tips_seen": [],
	"dev": false,
}

signal loaded   # the loading screen is going: the home screen behind it is ready

var main: Node = null
var current: Node = null
var loading := false
var theme: Theme
var font_body: Font
var font_bold: Font
var font_marker: Font     # the whiteboard's hand
var font_score: Font      # the scoreboard's numbers and the HUD
var cup = null            # Cup (RefCounted), loaded lazily
var season = null         # Season (RefCounted), the club season, loaded lazily
var _latin: FontFile
var _fallbacks: Array[Font] = []
var records := {}


func _ready() -> void:
	load_settings()
	if int(settings.graphics) < 0:
		settings.graphics = detect_graphics()
		save_settings()
	apply_frame_rate()
	TranslationServer.set_locale(language())
	_build_theme()
	get_tree().root.theme = theme
	get_tree().root.get_viewport().gui_embed_subwindows = true
	var r = _read_json(RECORDS_PATH)
	records = r if r is Dictionary else {}


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if current and is_instance_valid(current) and current.has_method("set_paused") and not bool(current.get("paused")):
				current.set_paused(true)


## Esc on a keyboard is the phone's Back.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		go_back()


## Back: pause or resume a match, leave a screen the way its Back button does, and quit from the home screen.
func go_back() -> void:
	if current == null or not is_instance_valid(current):
		return
	if current.has_method("on_back"):
		current.on_back()
	elif current.has_meta("back"):
		(current.get_meta("back") as Callable).call()
	elif String(current.get_script().resource_path).ends_with("main_menu.gd"):
		get_tree().quit()
	else:
		goto_menu()


## The graphics level for this phone on its first run: Low on a phone with a small GPU or under about 4.5 GB of
## memory (a Galaxy A0x/A1x's Mali-G52/G57, Adreno 5xx and 6xx below 640, PowerVR), Medium on the rest; High is a
## choice.
func detect_graphics() -> int:
	if not OS.has_feature("mobile"):
		return GFX_HIGH
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var mem: Dictionary = OS.get_memory_info()
	var ram_gb := float(mem.get("physical", 0)) / 1073741824.0
	if ram_gb > 0.0 and ram_gb < 4.5:
		return GFX_LOW
	for weak in ["mali-g5", "mali-g6", "mali-t", "mali-4", "powervr", "adreno (tm) 5", "adreno (tm) 61", "adreno (tm) 50",
			"adreno (tm) 4", "img bxm", "ge8"]:
		if gpu.contains(weak):
			return GFX_LOW
	return GFX_MEDIUM


func language() -> String:
	return String(settings.language) if String(settings.language) != "" else phone_language()


## The phone's language if the game has it, else English. Android reports Norwegian Bokmål as "nb", older phones "no".
func phone_language() -> String:
	var os_lang := OS.get_locale_language()
	if os_lang == "no" or os_lang == "nn":
		os_lang = "nb"
	for pair in LANGUAGES:
		if pair[0] == os_lang:
			return os_lang
	return "en"


func language_names(code: String) -> Array:
	for pair in LANGUAGES:
		if pair[0] == code:
			return [pair[1], pair[2]]
	return [code, code]


## CLDR plural forms: the key's _ONE, _FEW, _MANY or _OTHER, in the language showing, with {n} filled in. Every
## language has _OTHER; Czech and Slovak add _FEW (2-4), Polish _FEW and _MANY, Latvian _ZERO (0, 10-20, 30 ...).
func plural(key: String, n: int) -> String:
	var form := plural_form(TranslationServer.get_locale().left(2), n)
	var k := key + "_" + form
	var s := tr(k)
	if s == k:
		s = tr(key + "_OTHER")
	return s.format({"n": n})


static func plural_form(lang: String, n: int) -> String:
	var a := absi(n)
	match lang:
		"ja", "th":
			return "OTHER"
		"fr":
			return "ONE" if a <= 1 else "OTHER"
		"cs", "sk":
			if a == 1:
				return "ONE"
			return "FEW" if a >= 2 and a <= 4 else "OTHER"
		"pl":
			if a == 1:
				return "ONE"
			if a % 10 >= 2 and a % 10 <= 4 and not (a % 100 >= 12 and a % 100 <= 14):
				return "FEW"
			return "MANY"
		"lv":
			if a % 10 == 0 or (a % 100 >= 11 and a % 100 <= 19):
				return "ZERO"
			return "ONE" if a % 10 == 1 and a % 100 != 11 else "OTHER"
	return "ONE" if a == 1 else "OTHER"


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	var data = _read_json(SETTINGS_PATH)
	if data is Dictionary:
		for k in data.keys():
			if settings.has(k):
				settings[k] = data[k]
	for k in ["camera", "graphics", "fps", "btn_size", "difficulty", "period", "rules", "game_speed"]:
		settings[k] = int(settings[k])
	if not (settings.btn_places is Array):
		settings.btn_places = []
	if not (settings.tips_seen is Array):
		settings.tips_seen = []


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func set_language(code: String) -> void:
	settings.language = code
	TranslationServer.set_locale(language())
	_size_theme()
	save_settings()


## How big a language's text is set against the English sizes: Thai stacks its marks high, so a little smaller.
const TEXT_K := {"th": 0.95}


func text_k() -> float:
	return float(TEXT_K.get(TranslationServer.get_locale().left(2), 1.0))


## Languages whose words run long enough that a line about a player can need another line (UI.fit): Finnish, German,
## Swedish, Czech, Estonian and Latvian compound or inflect into long words.
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["fi", "de", "sv", "et", "lv", "cs", "sk", "nb", "da"]


func ts(size: int) -> int:
	return maxi(1, roundi(size * text_k()))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- cup, records

func get_cup():
	if cup == null:
		var data = _read_json(CUP_PATH)
		if data is Dictionary:
			cup = Cup.from_dict(data)
	return cup


func new_cup(country_id: String, women := false):
	cup = Cup.create(country_id, women)
	save_cup()
	return cup


func save_cup() -> void:
	if cup:
		_write_json(CUP_PATH, cup.to_dict())


func delete_cup() -> void:
	cup = null
	delete_file(CUP_PATH)


## The club season: one at a time, saved after every round as the World Finals are.
func get_season():
	if season == null:
		var data = _read_json(SEASON_PATH)
		if data is Dictionary:
			season = Season.from_dict(data)
	return season


func new_season(club_id: String, women := false):
	season = Season.create(club_id, women)
	save_season()
	return season


func save_season() -> void:
	if season:
		_write_json(SEASON_PATH, season.to_dict())


func delete_season() -> void:
	season = null
	delete_file(SEASON_PATH)


func save_records() -> void:
	_write_json(RECORDS_PATH, records)


func record_result(result: Dictionary) -> void:
	if int(result.get("user_team", -1)) < 0:
		return
	var me := int(result.user_team)
	var g: Array = result.goals
	records.played = int(records.get("played", 0)) + 1
	if int(result.winner) == me:
		records.won = int(records.get("won", 0)) + 1
	records.goals_for = int(records.get("goals_for", 0)) + int(g[me])
	var margin := int(g[me]) - int(g[1 - me])
	if margin > int(records.get("best_margin", -99)):
		records.best_margin = margin
		records.best_line = "%s %d–%d %s" % [DB.team_name(result.config.home), int(g[0]), int(g[1]), DB.team_name(result.config.away)]
	save_records()


# ---------------------------------------------------------------- navigation

func _swap(node: Node) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = node
	main.add_child(node)


func show_screen(script_path: String, args := {}) -> Node:
	var s: Script = load(script_path)
	var node: Node = s.new()
	if node.has_method("setup"):
		node.setup(args)
	_swap(node)
	Sfx.music(true)
	return node


func goto_menu() -> void:
	show_screen("res://ui/main_menu.gd")


## config keys: home, away (team ids), venue (DB.VENUES id), period (minutes), difficulty, mode ("quick"|"cup"|"season"),
## user_team (0, 1 or -1 for none), stage (a line naming the match: "Semi-final"), women (bool), knockout (bool: a
## draw goes to overtime and penalty shots), rules (0 IFF, 1 league clock), seed.
func start_match(config: Dictionary) -> void:
	var s: Script = load("res://game/match.gd")
	var m: Node = s.new()
	m.config = config
	Sfx.music(false)
	_swap(m)


func on_match_finished(result: Dictionary) -> void:
	record_result(result)
	if String(result.config.get("mode", "quick")) == "cup":
		get_cup().record_user_result(result)
		save_cup()
	elif String(result.config.get("mode", "quick")) == "season" and get_season() != null:
		get_season().record_user_result(result)
		save_season()
	show_screen("res://ui/result_screen.gd", {"result": result})


# ---------------------------------------------------------------- graphics

func apply_graphics(viewport: Viewport) -> void:
	match int(settings.graphics):
		GFX_LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
		GFX_MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 0.9
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
	if int(settings.get("fps", FPS_SMOOTH)) == FPS_SAVER:
		viewport.scaling_3d_scale = minf(viewport.scaling_3d_scale, 0.8)


func screen_hz() -> int:
	var hz := roundi(DisplayServer.screen_get_refresh_rate())
	return hz if hz > 0 else 60


## Smooth's frame rate on a screen of HZ: 60 where 60 divides the screen's rate evenly, else half the rate at 144 Hz
## and up, else no cap.
func smooth_cap(hz: int) -> int:
	if hz % 60 == 0:
		return 60
	if hz >= 130:
		return hz / 2
	return 0


## Battery saver: the whole fraction of the screen's rate nearest 30 without going over about 36 (30 at 60 or 120 Hz,
## 45 at 90, 36 at 144).
func saver_cap(hz: int) -> int:
	return hz / ceili(hz / 36.0)


func frame_cap() -> int:
	match int(settings.get("fps", FPS_SMOOTH)):
		FPS_SAVER:
			return saver_cap(screen_hz())
		FPS_SMOOTH:
			var cap := smooth_cap(screen_hz())
			return cap if cap < screen_hz() else 0
	return 0


func apply_frame_rate() -> void:
	Engine.max_fps = frame_cap()


func shadows_enabled() -> bool:
	return int(settings.graphics) >= GFX_HIGH


func crowd_density() -> float:
	return [0.45, 0.75, 1.0][clampi(int(settings.graphics), 0, 2)]


## A buzz for something that happened to you. Matches you only watch never call it (match.gd checks user_team).
func haptic(kind: String) -> void:
	if not settings.vibration or not OS.has_feature("mobile") or not HAPTICS.has(kind):
		return
	var h: Array = HAPTICS[kind]
	if not (h[0] is Array):
		Input.vibrate_handheld(int(h[0]), float(h[1]))
		return
	for step in h:
		if step is Array:
			Input.vibrate_handheld(int(step[0]), float(step[1]))
			await get_tree().create_timer(float(step[0]) / 1000.0).timeout
		else:
			await get_tree().create_timer(float(step) / 1000.0).timeout


# ---------------------------------------------------------------- theme

func _font(path: String) -> FontFile:
	return load(path)


func _build_theme() -> void:
	var latin := _font("res://fonts/NotoSans.ttf")
	var fallbacks: Array[Font] = []
	for f in ["NotoSansThai", "NotoSansJP"]:
		var path := "res://fonts/%s.ttf" % f
		if ResourceLoader.exists(path):
			fallbacks.append(_font(path))
	latin.fallbacks = fallbacks
	_latin = latin
	_fallbacks = fallbacks

	font_body = _variation(latin, 450, fallbacks)
	font_bold = _variation(latin, 680, fallbacks)
	# The marker hand: Caveat, falling back to bold Noto (Thai, Japanese) so every script keeps a heavy title.
	var caveat := _font("res://fonts/Caveat.ttf")
	var marker_fb: Array[Font] = []
	marker_fb.append(font_bold)
	caveat.fallbacks = marker_fb
	font_marker = _variation(caveat, 700, marker_fb)
	var barlow := _font("res://fonts/BarlowCondensed-Bold.ttf")
	barlow.fallbacks = marker_fb
	font_score = barlow

	theme = Theme.new()
	theme.default_font = font_body

	# Buttons: white cards pinned to the board, a marker line under them.
	theme.set_stylebox("normal", "Button", _sb(C_PANEL, 10, Color(C_INK, 0.22), 2))
	theme.set_stylebox("hover", "Button", _sb(C_PANEL_HI, 10, Color(C_BLUE, 0.6), 2))
	theme.set_stylebox("pressed", "Button", _sb(Color("dfe8f7"), 10, C_BLUE, 3))
	theme.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 10, C_BLUE, 2))
	theme.set_stylebox("disabled", "Button", _sb(Color("e3e6e8"), 10))
	theme.set_color("font_color", "Button", C_INK)
	theme.set_color("font_hover_color", "Button", C_INK)
	theme.set_color("font_pressed_color", "Button", C_BLUE)
	theme.set_color("font_focus_color", "Button", C_INK)
	theme.set_color("font_disabled_color", "Button", Color(C_MUTED, 0.6))
	theme.set_font("font", "Button", font_bold)

	# The primary action: a blue marker block, white words.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _sb(C_BLUE, 12))
	theme.set_stylebox("hover", "PrimaryButton", _sb(C_BLUE.lightened(0.1), 12))
	theme.set_stylebox("pressed", "PrimaryButton", _sb(C_BLUE.darkened(0.2), 12))
	theme.set_stylebox("focus", "PrimaryButton", _sb(Color(0, 0, 0, 0), 12, C_INK, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(k, "PrimaryButton", Color.WHITE)
	theme.set_font("font", "PrimaryButton", font_bold)

	# Chips: magnets on the board; the chosen one is a filled orange magnet.
	theme.set_type_variation("ChipButton", "Button")
	theme.set_stylebox("normal", "ChipButton", _sb(C_PANEL, 999, Color(C_INK, 0.25), 2, 10))
	theme.set_stylebox("hover", "ChipButton", _sb(C_PANEL_HI, 999, Color(C_MAGNET, 0.8), 2, 10))
	theme.set_stylebox("pressed", "ChipButton", _sb(C_MAGNET, 999, C_MAGNET.darkened(0.25), 2, 10))
	theme.set_stylebox("hover_pressed", "ChipButton", _sb(C_MAGNET.lightened(0.08), 999, C_MAGNET.darkened(0.25), 2, 10))
	theme.set_color("font_pressed_color", "ChipButton", Color("1d1307"))
	theme.set_color("font_hover_pressed_color", "ChipButton", Color("1d1307"))
	theme.set_font("font", "ChipButton", font_bold)

	theme.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 6, Color(C_INK, 0.12), 1, 20))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _sb(C_PANEL, 6, Color(C_INK, 0.12), 1, 20))
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _sb(Color(1, 1, 1, 0.93), 10, Color(C_INK, 0.18), 1, 12))
	theme.set_type_variation("DarkPanel", "PanelContainer")
	theme.set_stylebox("panel", "DarkPanel", _sb(Color(0.07, 0.09, 0.12, 0.86), 8, Color(1, 1, 1, 0.12), 1, 10))

	theme.set_color("font_color", "Label", C_INK)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", font_marker)
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", font_marker)
	theme.set_type_variation("SubLabel", "Label")
	theme.set_font("font", "SubLabel", font_bold)
	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", C_MUTED)
	theme.set_type_variation("EyebrowLabel", "Label")
	theme.set_color("font_color", "EyebrowLabel", C_MUTED)
	theme.set_font("font", "EyebrowLabel", font_bold)
	theme.set_type_variation("ScoreLabel", "Label")
	theme.set_font("font", "ScoreLabel", font_score)
	# The HUD's words sit on dark panels over the rink.
	theme.set_type_variation("HudLabel", "Label")
	theme.set_font("font", "HudLabel", font_bold)
	theme.set_color("font_color", "HudLabel", Color("f4f6f8"))

	theme.set_stylebox("normal", "LineEdit", _sb(C_PANEL, 8, Color(C_INK, 0.25), 2))
	theme.set_stylebox("focus", "LineEdit", _sb(C_PANEL, 8, C_BLUE, 2))
	theme.set_color("font_color", "LineEdit", C_INK)

	theme.set_stylebox("panel", "PopupMenu", _sb(C_PANEL, 8, Color(C_INK, 0.2), 1, 8))
	theme.set_stylebox("hover", "PopupMenu", _sb(C_PANEL_HI, 6))
	theme.set_color("font_color", "PopupMenu", C_INK)
	theme.set_color("font_hover_color", "PopupMenu", C_BLUE)

	theme.set_stylebox("background", "ProgressBar", _sb(Color(C_INK, 0.1), 999, Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _sb(C_BLUE, 999, Color(0, 0, 0, 0), 0, 0))

	var grabber := _sb(Color(C_INK, 0.25), 999, Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 999, Color(0, 0, 0, 0), 0, 0))
	_size_theme()


func _size_theme() -> void:
	if theme == null:
		return
	theme.default_font_size = ts(22)
	for pair in [["Button", 22], ["PrimaryButton", 28], ["ChipButton", 20], ["TitleLabel", 84], ["HeaderLabel", 54],
			["SubLabel", 24], ["MutedLabel", 19], ["EyebrowLabel", 16], ["PopupMenu", 22], ["HudLabel", 20]]:
		theme.set_font_size("font_size", pair[0], ts(pair[1]))
	theme.set_font_size("font_size", "ScoreLabel", 56)


func _sb(bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad - 4
	sb.content_margin_bottom = pad - 4
	sb.anti_aliasing = true
	return sb


func _variation(base: Font, weight: int, fallbacks: Array[Font]) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	v.fallbacks = fallbacks
	return v
