extends Node
## Global state: settings, saves, theme, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const SEASON_PATH := "user://season.json"
const CUP_PATH := "user://cup.json"
const RECORDS_PATH := "user://records.json"

## The game's privacy policy and help pages (Settings > About).

## Code, name in the language itself, name in English. The sport's heartland first: Thailand, Malaysia, Indonesia,
## Vietnam, Laos, Myanmar, Cambodia and the Philippines, then Japan, Korea, China and India, which field national
## teams, and English for everyone else.
const LANGUAGES := [
	["en", "English", "English"],
	["th", "ไทย", "Thai"],
	["ms", "Bahasa Melayu", "Malay"],
	["id", "Bahasa Indonesia", "Indonesian"],
	["vi", "Tiếng Việt", "Vietnamese"],
	["lo", "ລາວ", "Lao"],
	["my", "မြန်မာ", "Burmese"],
	["km", "ខ្មែរ", "Khmer"],
	["fil", "Filipino", "Filipino"],
	["ja", "日本語", "Japanese"],
	["ko", "한국어", "Korean"],
	["zh", "中文", "Chinese"],
	["hi", "हिन्दी", "Hindi"],
]

const CAM_TV := 0       # the broadcast camera: high in the stand, off to your end of the side line, so the net is seen at
                        # an angle rather than edge on
const CAM_END := 1      # behind your own end line, looking over the net
const CAM_SIDE := 2     # high in the stand level with the net, the whole court side on

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second; Smooth, 60 a second (the default); Max, as many as
## the screen shows.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds.
const HAPTICS := {
	"touch": [18, 0.45],                         # your foot, knee or head on the ball
	"perfect": [[22, 0.7], 50, [22, 0.7]],       # a touch timed just right
	"spike": [60, 1.0],                          # your spike
	"block": [45, 0.85],                         # your block meets the ball
	"point": [[30, 0.7], 80, [60, 1.0]],         # your side wins the rally
	"fault": [90, 0.6],                          # the referee calls a fault on you
}

# Brand palette, shared with the HUD and menus (the same family as Kabaddi Raid's, with a takraw teal).
const C_BG := Color("0c1a29")
const C_PANEL := Color("172f47")
const C_PANEL_HI := Color("21405f")
const C_INK := Color("f3efe6")
const C_MUTED := Color("9db0c7")
const C_SAFFRON := Color("ff9a1f")
const C_GOLD := Color("ffd27a")
const C_MAGENTA := Color("e8336d")
const C_TEAL := Color("19b3a3")
const C_GOOD := Color("4cd38a")
const C_DANGER := Color("ff5a5a")

## How fast a match you play runs, against real time: Slow (the default: time to see the ball and get to it), Medium,
## Real. The ball, the players and the clock all slow together, so a rally plays as it would, only slower.
const SPEEDS := [0.7, 0.85, 1.0]

var settings := {
	"language": "",         # "" follows the phone's language
	"camera": CAM_TV,
	"graphics": -1,         # -1 until the first run picks one for the phone (detect_graphics)
	"gfx_auto": true,       # Auto: the graphics picked for this phone each time the game starts (detect_graphics)
	"gfx_cap": GFX_HIGH,    # and no higher than a slow match left them (auto_gfx)
	"auto_gfx": true,       # lower the graphics by itself if a match runs slowly
	"fps": FPS_SMOOTH,
	"sound": true,
	"music": true,
	"vibration": true,
	"left_handed": false,
	"btn_size": 0,          # the match buttons: 0 Normal, 1 Large, 2 Extra large
	"difficulty": 1,        # 0 Rookie, 1 Pro, 2 Star, 3 Legend
	"assist": 1,            # who runs your player to the ball: 0 you, every touch; 1 you for the first touch (the set and
	                        # the spike he runs to himself); 2 he runs to every one. You time every touch yourself.
	"game_speed": 0,        # the pace of a match you play: SPEEDS
	"play_as": -1,          # -1 the whole side (every touch is yours); a DB.POS_ role: that one player, the others the
	                        # computer's
	"sets": 1,              # 0 one set, 1 best of three: the real match
	"points": 0,            # 0 sets to 15 (the ISTAF rule), 1 to 21 (the long sets of the old rule)
	"event": 0,             # the event in Quick Match: 0 Regu (3), 1 Team (three regus), 2 Quadrant (4), 3 Doubles (2)
	"seen_howto": false,
	"dev": false,
}

signal loaded   # the loading screen is going: the home screen behind it is ready

var main: Node = null
var current: Node = null
var loading := false
var theme: Theme
var font_body: Font
var font_bold: Font
var font_display: Font
var season = null  # Season (RefCounted), loaded lazily
var cup = null     # Cup (RefCounted), loaded lazily
var _latin: FontFile
var _fallbacks: Array[Font] = []
var records := {}  # the record book: titles won, biggest wins, best spikers (Records)


var _defaults := {}


func _ready() -> void:
	_defaults = settings.duplicate(true)
	load_settings()
	if int(settings.graphics) < 0 or bool(settings.gfx_auto):
		settings.graphics = auto_graphics()
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


## Back: close what is open over the screen (a list being picked from, a question), pause or resume a match, leave a
## screen the way its Back button does, and quit from the main menu.
func go_back() -> void:
	if current == null or not is_instance_valid(current):
		return
	if _close_popup():
		return
	if current.has_method("on_back"):
		current.on_back()
	elif current.has_meta("back"):
		(current.get_meta("back") as Callable).call()
	elif String(current.get_script().resource_path).ends_with("main_menu.gd"):
		get_tree().quit()
	else:
		goto_menu()


## A team picker's list or a question (League Season's "Abandon?") open over the screen: Back closes it, as on any
## Android screen, rather than leaving the screen under it.
func _close_popup() -> bool:
	for w in current.find_children("*", "Window", true, false):
		if (w as Window).visible:
			(w as Window).hide()
			return true
	for o in current.find_children("*", "OptionButton", true, false):
		if (o as OptionButton).get_popup().visible:
			(o as OptionButton).get_popup().hide()
			return true
	return false


## The graphics level for this phone: Low on a phone with a small GPU or little memory (a Galaxy A16's Mali-G57 MC2 or
## Mali-G68 MP2, Adreno 5xx and 6xx below 640, PowerVR), High on a flagship's GPU with 8 GB or more (Adreno 650, 660,
## 690, 730 and later, Mali-G710 and later, Immortalis, Xclipse), Medium on the rest.
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
	if ram_gb >= 7.5:
		for strong in ["adreno (tm) 650", "adreno (tm) 660", "adreno (tm) 690", "adreno (tm) 73", "adreno (tm) 74",
				"adreno (tm) 75", "adreno (tm) 8", "mali-g710", "mali-g715", "mali-g720", "mali-g725", "mali-g925",
				"immortalis", "xclipse"]:
			if gpu.contains(strong):
				return GFX_HIGH
	return GFX_MEDIUM


## Auto's level: the phone's (detect_graphics), but no higher than a slow match has left it (gfx_cap).
func auto_graphics() -> int:
	return mini(detect_graphics(), int(settings.get("gfx_cap", GFX_HIGH)))


func language() -> String:
	return String(settings.language) if String(settings.language) != "" else phone_language()


## The phone's language if the game has it, else English (Tagalog phones get Filipino).
func phone_language() -> String:
	var os_lang := OS.get_locale_language()
	if os_lang == "tl":
		os_lang = "fil"
	if os_lang == "in":
		os_lang = "id"   # Android's old code for Indonesian
	for pair in LANGUAGES:
		if pair[0] == os_lang:
			return os_lang
	return "en"


func language_names(code: String) -> Array:
	for pair in LANGUAGES:
		if pair[0] == code:
			return [pair[1], pair[2]]
	return [code, code]


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	var data = _read_json(SETTINGS_PATH)
	if data is Dictionary:
		for k in data.keys():
			if settings.has(k):
				settings[k] = data[k]
		# Saved before Auto: still Auto if the level is the one the game would pick, else the level chosen.
		if not data.has("gfx_auto") and data.has("graphics") and int(data.graphics) >= 0:
			settings.gfx_auto = int(data.graphics) == detect_graphics()
	for k in ["camera", "graphics", "gfx_cap", "fps", "btn_size", "difficulty", "assist", "game_speed", "play_as", "sets", "points", "event"]:
		settings[k] = int(settings[k])


## The settings a new player has (for the tests: not this machine's saved ones), sound off, graphics fixed.
func reset_settings_for_tests() -> void:
	settings = _defaults.duplicate(true)
	settings.sound = false
	settings.graphics = GFX_MEDIUM
	settings.language = "en"
	TranslationServer.set_locale("en")
	_size_theme()


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func set_language(code: String) -> void:
	settings.language = code
	TranslationServer.set_locale(language())
	_size_theme()
	save_settings()


## How big a language's text is set against the English sizes. Burmese and Khmer stack their letters high and run
## wide; Lao and Thai a little; the rest fit as English does (the Chinese, Japanese and Korean words are short).
const TEXT_K := {"my": 0.84, "km": 0.88, "lo": 0.94, "th": 0.96, "hi": 0.95, "vi": 0.96, "fil": 0.95, "id": 0.97, "ms": 0.97}


func text_k() -> float:
	var loc := TranslationServer.get_locale()
	return float(TEXT_K.get(loc.left(3) if loc.begins_with("fil") else loc.left(2), 1.0))


## Languages whose words run long enough that a line about a player can need another line (UI.fit).
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["my", "km", "lo", "fi", "vi"]


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


# ---------------------------------------------------------------- season, cup, records

func get_season():
	if season == null:
		var data = _read_json(SEASON_PATH)
		if data is Dictionary:
			season = Season.from_dict(data)
	return season


func new_season(league_id: String, team_id: String, women := false):
	season = Season.create(league_id, team_id, women)
	save_season()
	return season


func save_season() -> void:
	if season:
		_write_json(SEASON_PATH, season.to_dict())


func delete_season() -> void:
	season = null
	delete_file(SEASON_PATH)


func get_cup():
	if cup == null:
		var data = _read_json(CUP_PATH)
		if data is Dictionary:
			cup = Cup.from_dict(data)
	return cup


func new_cup(kind: String, country_id: String, women := false, event := "regu"):
	cup = Cup.create(kind, country_id, women, event)
	save_cup()
	return cup


func save_cup() -> void:
	if cup:
		_write_json(CUP_PATH, cup.to_dict())


func delete_cup() -> void:
	cup = null
	delete_file(CUP_PATH)


func save_records() -> void:
	_write_json(RECORDS_PATH, records)


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


## config keys: home, away (team ids), venue (DB.VENUES id), event ("regu"|"quadrant"|"doubles"|"team"), sets (1 or 3),
## points (15 or 21), difficulty, mode ("quick"|"season"|"cup"), user_team (0, 1 or -1 for none), stage (a line naming
## the match: "Semi-final"), women (bool). A team event is three regu matches, one after another (tie).
func start_match(config: Dictionary) -> void:
	if String(config.get("event", "")) == "team" and not config.has("tie"):
		config.tie = {"results": [], "used": [[], []]}
	if config.has("tie"):
		var tie: Dictionary = config.tie
		var n: int = (tie.results as Array).size()
		var women: bool = bool(config.get("women", false))
		config.lineup_0 = DB.regu(String(config.home), women, 3, tie.used[0])
		config.lineup_1 = DB.regu(String(config.away), women, 3, tie.used[1])
		if not config.has("stage_base"):
			config.stage_base = String(config.get("stage", ""))
		var base := String(config.stage_base)
		config.stage = (base + "\u00a0· " if base != "" else "") + tr("REGU_N").format({"n": n + 1})
	var s: Script = load("res://game/match.gd")
	var m: Node = s.new()
	m.config = config
	Sfx.music(false)
	_swap(m)


func on_match_finished(result: Dictionary) -> void:
	var cfg: Dictionary = result.config
	Records.add_match(result)
	if cfg.has("tie"):
		# One regu of a tie: a team event goes on until a side has won two of three; a Thai league tie plays both its
		# regus (play_all), and may be drawn.
		var tie: Dictionary = cfg.tie.duplicate(true)
		tie.results.append([int(result.sets[0]), int(result.sets[1])])
		var scores: Array = tie.get("set_scores", [])
		scores.append_array(result.get("set_scores", []))
		tie.set_scores = scores
		for k in 2:
			for pd in cfg.get("lineup_%d" % k, []):
				tie.used[k].append(pd.id)
		var wins := [0, 0]
		for r in tie.results:
			wins[0 if int(r[0]) > int(r[1]) else 1] += 1
		var regus := int(tie.get("regus", 3))
		var decided: bool = (tie.results as Array).size() >= regus or (not bool(tie.get("play_all", false)) and (wins[0] >= 2 or wins[1] >= 2))
		if not decided:
			show_screen("res://ui/result_screen.gd", {"result": result, "tie": tie})
			return
		# The tie is decided: it counts as one result, in regus won.
		var tie_result := result.duplicate()
		tie_result.sets = wins
		tie_result.set_scores = []
		tie_result.winner = 0 if wins[0] > wins[1] else (1 if wins[1] > wins[0] else -1)
		tie_result.tie = tie
		_record(tie_result)
		show_screen("res://ui/result_screen.gd", {"result": result, "tie": tie, "tie_done": true})
		return
	_record(result)
	show_screen("res://ui/result_screen.gd", {"result": result})


func _record(result: Dictionary) -> void:
	match String(result.config.get("mode", "quick")):
		"cup":
			get_cup().record_user_result(result)
			save_cup()
		"season":
			get_season().record_user_result(result)
			save_season()


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
		viewport.scaling_3d_scale *= 0.85


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
	return [0.4, 0.7, 1.0][clampi(int(settings.graphics), 0, 2)]


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
	for f in ["NotoSansThai", "NotoSansLao", "NotoSansMyanmar", "NotoSansKhmer", "NotoSansDevanagari", "NotoSansJP",
			"NotoSansKR", "NotoSansSC"]:
		var path := "res://fonts/%s.ttf" % f
		if ResourceLoader.exists(path):
			fallbacks.append(_font(path))
	latin.fallbacks = fallbacks
	_latin = latin
	_fallbacks = fallbacks

	# Each weight's fallbacks at that weight too: the Chinese, Japanese and Korean fonts would otherwise draw at their
	# own default, the thinnest (100).
	font_body = _variation(latin, 450, _weighted(fallbacks, 450))
	font_bold = _variation(latin, 650, _weighted(fallbacks, 650))
	var teko := _font("res://fonts/Teko.ttf")
	var display_fallbacks: Array[Font] = []
	display_fallbacks.append(_variation(latin, 700, _weighted(fallbacks, 700)))
	teko.fallbacks = display_fallbacks
	font_display = _variation(teko, 600, display_fallbacks)

	theme = Theme.new()
	theme.default_font = font_body

	theme.set_stylebox("normal", "Button", _sb(C_PANEL, 12, Color(1, 1, 1, 0.08), 1))
	theme.set_stylebox("hover", "Button", _sb(C_PANEL_HI, 12, Color(1, 1, 1, 0.16), 1))
	theme.set_stylebox("pressed", "Button", _sb(C_PANEL_HI.darkened(0.2), 12, C_SAFFRON, 2))
	theme.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 12, C_SAFFRON, 2))
	theme.set_stylebox("disabled", "Button", _sb(C_PANEL.darkened(0.3), 12))
	theme.set_color("font_color", "Button", C_INK)
	theme.set_color("font_hover_color", "Button", C_INK)
	theme.set_color("font_pressed_color", "Button", C_GOLD)
	theme.set_color("font_focus_color", "Button", C_INK)
	theme.set_color("font_disabled_color", "Button", C_MUTED.darkened(0.3))

	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _sb(C_SAFFRON, 12))
	theme.set_stylebox("hover", "PrimaryButton", _sb(C_SAFFRON.lightened(0.1), 12))
	theme.set_stylebox("pressed", "PrimaryButton", _sb(C_SAFFRON.darkened(0.15), 12))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(k, "PrimaryButton", Color("1d1307"))
	theme.set_font("font", "PrimaryButton", font_display)

	theme.set_type_variation("ChipButton", "Button")
	theme.set_stylebox("normal", "ChipButton", _sb(C_PANEL, 999, Color(1, 1, 1, 0.1), 1, 10))
	theme.set_stylebox("hover", "ChipButton", _sb(C_PANEL_HI, 999, Color(1, 1, 1, 0.2), 1, 10))
	theme.set_stylebox("pressed", "ChipButton", _sb(C_SAFFRON, 999, C_SAFFRON, 1, 10))
	theme.set_stylebox("hover_pressed", "ChipButton", _sb(C_SAFFRON.lightened(0.1), 999, C_SAFFRON, 1, 10))
	theme.set_color("font_pressed_color", "ChipButton", Color("1d1307"))
	theme.set_color("font_hover_pressed_color", "ChipButton", Color("1d1307"))

	theme.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 16, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _sb(C_PANEL, 16, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _sb(Color(0.03, 0.07, 0.12, 0.72), 14, Color(1, 1, 1, 0.08), 1, 12))

	theme.set_color("font_color", "Label", C_INK)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", font_display)
	theme.set_type_variation("HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", font_display)
	theme.set_type_variation("SubLabel", "Label")
	theme.set_font("font", "SubLabel", font_bold)
	theme.set_type_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", C_MUTED)
	theme.set_type_variation("EyebrowLabel", "Label")
	theme.set_color("font_color", "EyebrowLabel", C_MUTED)
	theme.set_font("font", "EyebrowLabel", font_bold)
	theme.set_type_variation("ScoreLabel", "Label")
	theme.set_font("font", "ScoreLabel", font_display)

	theme.set_stylebox("normal", "LineEdit", _sb(C_BG, 10, Color(1, 1, 1, 0.15), 1))
	theme.set_stylebox("focus", "LineEdit", _sb(C_BG, 10, C_SAFFRON, 2))
	theme.set_color("font_color", "LineEdit", C_INK)

	theme.set_stylebox("panel", "PopupMenu", _sb(C_PANEL, 10, Color(1, 1, 1, 0.1), 1, 8))
	theme.set_stylebox("hover", "PopupMenu", _sb(C_PANEL_HI, 8))

	theme.set_stylebox("background", "ProgressBar", _sb(Color(1, 1, 1, 0.08), 999, Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _sb(C_SAFFRON, 999, Color(0, 0, 0, 0), 0, 0))

	var grabber := _sb(Color(1, 1, 1, 0.18), 999, Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 999, Color(0, 0, 0, 0), 0, 0))
	_size_theme()


## Chinese, Japanese and Korean share many characters but draw them differently: the language being shown puts its
## own font first in the chain.
func _order_fallbacks() -> void:
	if _fallbacks.is_empty():
		return
	var first: String = {"ja": "NotoSansJP", "ko": "NotoSansKR", "zh": "NotoSansSC"}.get(TranslationServer.get_locale().left(2), "")
	_latin.fallbacks = _first(_fallbacks, first)
	for v in [font_body, font_bold, (font_display as FontVariation).fallbacks[0]]:
		(v as FontVariation).fallbacks = _first((v as FontVariation).fallbacks, first)


## The fonts with the one whose file is named first put first.
static func _first(fonts: Array[Font], first: String) -> Array[Font]:
	var ordered: Array[Font] = []
	for f in fonts:
		var path := String((f as FontVariation).base_font.resource_path if f is FontVariation else f.resource_path)
		if first != "" and path.contains(first):
			ordered.insert(0, f)
		else:
			ordered.append(f)
	return ordered


## Each of the fonts at this weight (those without a weight axis are as they are).
func _weighted(fonts: Array[Font], weight: int) -> Array[Font]:
	var out: Array[Font] = []
	for f in fonts:
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		out.append(v)
	return out


func _size_theme() -> void:
	if theme == null:
		return
	_order_fallbacks()
	theme.default_font_size = ts(22)
	for pair in [["PrimaryButton", 34], ["ChipButton", 20], ["TitleLabel", 76], ["HeaderLabel", 44], ["SubLabel", 24],
			["MutedLabel", 19], ["EyebrowLabel", 16], ["PopupMenu", 22]]:
		theme.set_font_size("font_size", pair[0], ts(pair[1]))
	theme.set_font_size("font_size", "ScoreLabel", 64)


func _sb(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0, pad := 14) -> StyleBoxFlat:
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
