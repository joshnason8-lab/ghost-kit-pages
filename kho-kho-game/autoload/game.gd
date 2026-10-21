extends Node
## Global state: settings, saves, theme, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const CUP_PATH := "user://cup.json"
const RECORDS_PATH := "user://records.json"

## The game's privacy policy and help pages (Settings > About).
const PRIVACY_URL := "https://joshnason8-lab.github.io/ghost-kit-pages/khamba-dash/privacy.html"
const SUPPORT_URL := "https://joshnason8-lab.github.io/ghost-kit-pages/khamba-dash/support.html"

## Code, name in the language itself, name in English. India's languages first, the kho kho heartland's ahead
## (Marathi, Kannada, Telugu, Tamil, Malayalam, Odia, Bengali, Gujarati, Punjabi, Assamese), then Nepali and Sinhala for
## Nepal and Sri Lanka, and English for everyone else (docs/LANGUAGES.md).
const LANGUAGES := [
	["en", "English", "English"],
	["hi", "हिन्दी", "Hindi"],
	["mr", "मराठी", "Marathi"],
	["kn", "ಕನ್ನಡ", "Kannada"],
	["te", "తెలుగు", "Telugu"],
	["ta", "தமிழ்", "Tamil"],
	["ml", "മലയാളം", "Malayalam"],
	["or", "ଓଡ଼ିଆ", "Odia"],
	["bn", "বাংলা", "Bengali"],
	["gu", "ગુજરાતી", "Gujarati"],
	["pa", "ਪੰਜਾਬੀ", "Punjabi"],
	["as", "অসমীয়া", "Assamese"],
	["ne", "नेपाली", "Nepali"],
	["si", "සිංහල", "Sinhala"],
]

const CAM_TV := 0       # the broadcast camera: high in the stand on one side line, the whole lane across the screen
const CAM_CLOSE := 1    # lower and closer, following the chase
const CAM_POLE := 2     # behind a pole, looking down the central lane

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second at 80% render scale; Smooth, 60 a second (the
## default); Max, as many as the screen shows.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## The two rule books (docs/RULES.md). Classic: the national federation's game, nine chasers (eight seated) on a 27 m
## field, 1 point an out, the follow-on. Fast: the seven-a-side game of the 2025 world championship and the franchise
## league, a 22 m field, six seated, 2 points an out, dream runs, the wazir and the power play.
const FMT_CLASSIC := 0
const FMT_FAST := 1

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds. Never in a match the AI plays on its own.
const HAPTICS := {
	"kho": [16, 0.4],                            # your kho lands on a seated chaser's back
	"tag": [[30, 0.8], 60, [50, 1.0]],           # you touch a defender out
	"tagged": [80, 0.9],                         # you are touched out
	"dive": [40, 0.7],                           # your dive hits the ground
	"foul": [90, 0.6],                           # the umpire whistles a foul on you
	"dream": [[25, 0.6], 70, [25, 0.6]],         # your batch's dream run scores
}

# Palette: red earth, chalk lime, marigold and a dusk indigo (the old names are kept for the shared UI code).
const C_BG := Color("1a1210")
const C_PANEL := Color("2e201a")
const C_PANEL_HI := Color("443026")
const C_INK := Color("f7efe2")
const C_MUTED := Color("c7b19c")
const C_SAFFRON := Color("ffb020")   # marigold: the main accent
const C_GOLD := Color("ffd97a")
const C_MAGENTA := Color("d9473a")   # vermilion
const C_TEAL := Color("4f6bd8")      # dusk indigo
const C_CLAY := Color("b5562f")      # the mud ground
const C_CHALK := Color("f2f4e6")     # the lime lines
const C_GOOD := Color("6fd38a")
const C_DANGER := Color("ff5a4a")

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
	"btn_places": {},       # buttons moved by the player: id -> [x, y] as fractions of the screen (right-handed)
	"difficulty": 1,        # 0 Beginner, 1 Club, 2 State, 3 International
	"format": FMT_CLASSIC,
	"turn_len": 0,          # 0 three minutes, 1 five, 2 the real length (9 classic, 7 fast)
	"follow_on": true,      # classic: a side 9 or more ahead may make the other follow on (scaled to shorter turns)
	"powerplay": true,      # fast: one power play a chasing turn
	"lane_assist": true,    # your active chaser keeps to his direction and his side of the lane unless you mean it
	"tags": 0,              # the shirt numbers over players' heads: 0 on, 2 off
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
var cup = null     # Cup (RefCounted), loaded lazily
var _latin: FontFile
var _fallbacks: Array[Font] = []
var records := {}  # the record book: titles won, biggest wins


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


## Back: pause or resume a match, leave a screen the way its Back button does, and quit from the main menu.
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


## The graphics level for this phone on its first run: Low on a phone with a small GPU or little memory (a Galaxy
## A16's Mali-G57 MC2 or Mali-G68 MP2, Adreno 5xx and 6xx below 640, PowerVR), Medium on the rest; High is a choice.
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


## The phone's language if the game has it, else English (Tagalog phones get Filipino).
func phone_language() -> String:
	var os_lang := OS.get_locale_language()
	if os_lang == "ory":
		os_lang = "or"
	if os_lang == "asm":
		os_lang = "as"
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
	for k in ["camera", "graphics", "fps", "btn_size", "difficulty", "format", "turn_len", "tags"]:
		settings[k] = int(settings[k])
	if not (settings.btn_places is Dictionary):
		settings.btn_places = {}


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func set_language(code: String) -> void:
	settings.language = code
	TranslationServer.set_locale(language())
	_size_theme()
	save_settings()


## How big a language's text is set against the English sizes, as Kabaddi Raid learnt on phones: Tamil's words run
## longest (14% smaller), Malayalam's nearly as long, Telugu, Kannada and Sinhala stand tall (7%), Odia's letters
## are wide; Devanagari, Bengali, Gujarati and Gurmukhi fit as English does, a little smaller.
const TEXT_K := {"ta": 0.86, "ml": 0.88, "te": 0.93, "kn": 0.93, "si": 0.93, "or": 0.94, "bn": 0.96, "as": 0.96,
	"hi": 0.97, "mr": 0.97, "ne": 0.97, "gu": 0.97, "pa": 0.97}


func text_k() -> float:
	return float(TEXT_K.get(TranslationServer.get_locale().left(2), 1.0))


## Languages whose words run long enough that a line about a player can need a third line (UI.fit).
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["ta", "te", "kn", "bn", "ml", "or", "as", "si"]


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


func new_cup(kind: String, team_id: String, women := false):
	cup = Cup.create(kind, team_id, women)
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


## config keys: home, away (team ids), venue (DB.VENUES id), format (FMT_*), turn_len (s), difficulty, mode
## ("quick"|"cup"), user_team (0, 1 or -1 for none), chase_first (0 or 1: the side that won the toss and chose to chase,
## or lost it), stage (a line naming the match: "Semi-final"), women (bool), knockout (bool: a tie is played off).
func start_match(config: Dictionary) -> void:
	var s: Script = load("res://game/match.gd")
	var m: Node = s.new()
	m.config = config
	Sfx.music(false)
	_swap(m)


func on_match_finished(result: Dictionary) -> void:
	Records.add_match(result)
	if String(result.config.get("mode", "quick")) == "cup":
		get_cup().record_user_result(result)
		save_cup()
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
	for f in ["NotoSansDevanagari", "NotoSansBengali", "NotoSansGurmukhi", "NotoSansGujarati", "NotoSansOriya",
			"NotoSansTamil", "NotoSansTelugu", "NotoSansKannada", "NotoSansMalayalam", "NotoSansSinhala"]:
		var path := "res://fonts/%s.ttf" % f
		if ResourceLoader.exists(path):
			fallbacks.append(_font(path))
	latin.fallbacks = fallbacks
	_latin = latin
	_fallbacks = fallbacks

	font_body = _variation(latin, 450, fallbacks)
	font_bold = _variation(latin, 650, fallbacks)
	# The display face: Baloo 2, round and heavy, drawn for Latin and Devanagari by an Indian foundry; the other
	# scripts fall back to Noto at its boldest.
	var baloo := _font("res://fonts/Baloo2.ttf")
	var display_fallbacks: Array[Font] = []
	display_fallbacks.append(_variation(latin, 700, fallbacks))
	baloo.fallbacks = display_fallbacks
	font_display = baloo

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

	# The home screen's lane: each choice a chalk-edged card over the ground.
	theme.set_type_variation("LaneButton", "Button")
	theme.set_stylebox("normal", "LaneButton", _sb(Color(C_BG, 0.72), 10, Color(C_CHALK, 0.35), 2, 8))
	theme.set_stylebox("hover", "LaneButton", _sb(Color(C_PANEL_HI, 0.85), 10, C_SAFFRON, 2, 8))
	theme.set_stylebox("pressed", "LaneButton", _sb(Color(C_PANEL_HI, 0.95), 10, C_GOLD, 3, 8))
	theme.set_stylebox("focus", "LaneButton", StyleBoxEmpty.new())

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


func _size_theme() -> void:
	if theme == null:
		return
	theme.default_font_size = ts(22)
	for pair in [["PrimaryButton", 30], ["ChipButton", 20], ["TitleLabel", 72], ["HeaderLabel", 40], ["SubLabel", 24],
			["MutedLabel", 19], ["EyebrowLabel", 16], ["PopupMenu", 22]]:
		theme.set_font_size("font_size", pair[0], ts(pair[1]))
	theme.set_font_size("font_size", "ScoreLabel", 60)


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
