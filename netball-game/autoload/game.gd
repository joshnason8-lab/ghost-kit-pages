extends Node
## Global state: settings, saves, theme, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const CUP_PATH := "user://cup.json"
const LEAGUE_PATH := "user://league.json"
const RECORDS_PATH := "user://records.json"

## The game's privacy policy and help pages (Settings > About).

## Code, name in the language itself, name in English. English first (most netball phones are set to it), then the
## languages of the netball nations, biggest player base first: South Africa's, Malawi's, Uganda's, Zimbabwe's, East
## Africa's, Malaysia and Singapore's, Sri Lanka's, Wales's, New Zealand's and the Pacific's. docs/LANGUAGES.md.
const LANGUAGES := [
	["en", "English", "English"],
	["af", "Afrikaans", "Afrikaans"],
	["zu", "isiZulu", "Zulu"],
	["xh", "isiXhosa", "Xhosa"],
	["st", "Sesotho", "Sesotho"],
	["tn", "Setswana", "Tswana"],
	["ny", "Chichewa", "Chichewa"],
	["lg", "Luganda", "Luganda"],
	["sn", "chiShona", "Shona"],
	["sw", "Kiswahili", "Swahili"],
	["ms", "Bahasa Melayu", "Malay"],
	["zh", "中文", "Chinese"],
	["si", "සිංහල", "Sinhala"],
	["ta", "தமிழ்", "Tamil"],
	["cy", "Cymraeg", "Welsh"],
	["mi", "Te Reo Māori", "Māori"],
	["to", "Lea Faka-Tonga", "Tongan"],
	["sm", "Gagana Sāmoa", "Samoan"],
	["fj", "Na Vosa Vakaviti", "Fijian"],
]

const CAM_TV := 0       # the broadcast camera: high in the stand on one side line, following the ball along the court
const CAM_LOW := 1      # lower and closer, at courtside
const CAM_END := 2      # behind the goal your team attacks

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second at 80% render scale; Smooth, 60 a second (the
## default); Max, as many as the screen shows. Each a whole fraction of the screen's rate.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## How you play: the whole team (you control whoever has the ball, and the defender nearest it), or one position
## all match, the way a player does (your bib; the others play themselves).
const CONTROL_TEAM := 0
const CONTROL_BIB := 1

## Quarter lengths you can pick: the real 15 minutes, or shorter for a quick game. Minutes.
const QUARTERS := [5, 8, 10, 15]

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds. Never in a match you are not playing.
const HAPTICS := {
	"catch": [16, 0.4],                          # your player catches the ball
	"intercept": [[24, 0.7], 50, [24, 0.7]],     # your player takes an intercept
	"goal": [[30, 0.7], 80, [60, 1.0]],          # your team scores
	"penalty": [80, 0.6],                        # the umpire penalises your player
}

# The palette: the indigo of an indoor arena with the lights down, the blue of a netball court, a bib lime and a
# coral for the other side.
const C_BG := Color("141029")
const C_PANEL := Color("231a45")
const C_PANEL_HI := Color("31265e")
const C_INK := Color("f6f3ff")
const C_MUTED := Color("aaa2cc")
const C_ACCENT := Color("c8f03c")       # bib lime: the main action colour
const C_GOLD := Color("ffd166")
const C_CORAL := Color("ff6b6b")
const C_COURT := Color("2f6fc4")
const C_TEAL := Color("2ec4b6")
const C_GOOD := Color("5be38f")
const C_DANGER := Color("ff5470")
const C_ON_ACCENT := Color("17200a")    # text on a lime button

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
	"btn_places": {},       # buttons moved by the player: place index -> [x, y] as fractions of the screen
	"difficulty": 1,        # 0 Rookie, 1 Club, 2 Elite, 3 World class
	"control": CONTROL_TEAM,
	"bib": "C",             # your position when you play one bib
	"quarter": 0,           # QUARTERS index: 5 minutes by default
	"onside": true,         # keep your player out of areas her position may not enter (Off: the umpire calls offside)
	"double_zone": false,   # the league variant: two points from the outer circle late in each quarter
	"rolling": false,       # rolling substitutions
	"timeouts": false,      # team time-outs
	"tags": 0,              # the bibs' letters over players' heads: 0 on, 2 off
	"whistles": 1,          # how often the AI infringes: 0 fewer whistles, 1 standard, 2 the real rate
	"seen_howto": false,
	"coach": true,          # the coach's tips in a match (on for a first match, then off; Settings)
	"coached": false,       # a first match has been played to the end with the tips
	"dev": false,
	"last_home": "ENG",
	"last_away": "JAM",
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
var league = null  # League (RefCounted), loaded lazily
var _latin: FontFile
var _fallbacks: Array[Font] = []
var records := {}
var test_quarter_s := 0.0   # a playtest's short quarters (?qs= in a browser); 0 in the game


func _ready() -> void:
	load_settings()
	_web_options()
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


## Esc on a keyboard (a computer, a browser, a phone with a keyboard) is the phone's Back button.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
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
## memory (a Galaxy A0x/A1x's Mali-G52 or G57, Adreno 5xx and 6xx below 640, PowerVR), Medium on the rest; High is a
## choice.
## In a browser, the page's address can set things for a test or a demo: ?gfx=low|medium|high, ?lang=xx, ?fresh
## (forget the saved settings: a first run).
func _web_options() -> void:
	if not OS.has_feature("web"):
		return
	var q := String(JavaScriptBridge.eval("window.location.search", true))
	if q.contains("fresh"):
		for k in ["seen_howto", "coached"]:
			settings[k] = false
		settings.coach = true
	for pair in q.trim_prefix("?").split("&", false):
		var kv := pair.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"gfx":
				settings.graphics = ["low", "medium", "high"].find(kv[1])
			"lang":
				settings.language = kv[1]
			"qs":
				test_quarter_s = float(kv[1])   # a playtest: quarters this many seconds long


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


## The phone's language if the game has it, else English.
func phone_language() -> String:
	var os_lang := OS.get_locale_language()
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
	for k in ["camera", "graphics", "fps", "btn_size", "difficulty", "control", "quarter", "tags", "whistles"]:
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


## How big a language's text is set against the English sizes. Sinhala and Tamil stand tall and run wide; the Bantu
## languages and Welsh run long words; the Chinese words are short.
const TEXT_K := {"si": 0.88, "ta": 0.86, "zu": 0.94, "xh": 0.94, "ny": 0.95, "lg": 0.95, "sn": 0.95, "st": 0.96,
	"tn": 0.96, "sw": 0.96, "af": 0.97, "cy": 0.97, "ms": 0.97, "to": 0.96, "sm": 0.96, "fj": 0.96, "mi": 0.97}


func text_k() -> float:
	return float(TEXT_K.get(TranslationServer.get_locale().left(2), 1.0))


## Languages whose words run long enough that a line about a player can need another line (UI.fit).
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["ta", "si", "zu", "xh", "ny", "lg", "sn"]


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


func new_cup(country_id: String):
	cup = Cup.create(country_id)
	save_cup()
	return cup


func save_cup() -> void:
	if cup:
		_write_json(CUP_PATH, cup.to_dict())


func delete_cup() -> void:
	cup = null
	delete_file(CUP_PATH)


func get_league():
	if league == null:
		var data = _read_json(LEAGUE_PATH)
		if data is Dictionary:
			league = League.from_dict(data)
	return league


func new_league(club_id: String):
	league = League.create(club_id)
	save_league()
	return league


func save_league() -> void:
	if league:
		_write_json(LEAGUE_PATH, league.to_dict())


func delete_league() -> void:
	league = null
	delete_file(LEAGUE_PATH)


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


## config keys: home, away (team ids), venue (DB.VENUES id), quarter (minutes), difficulty, mode ("quick"|"cup"|"league"),
## user_team (0, 1 or -1 for none), control, bib, stage (a line naming the match: "Semi-final"), need_winner (a
## knockout: extra time if drawn), double_zone, rolling, timeouts (bools).
func start_match(config: Dictionary) -> void:
	if test_quarter_s > 0.0:
		config.quarter_s = test_quarter_s
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
	elif String(result.config.get("mode", "quick")) == "league":
		get_league().record_user_result(result)
		save_league()
	show_screen("res://ui/result_screen.gd", {"result": result})


## The match config's quarter length (minutes), from the settings.
func quarter_minutes() -> int:
	return int(QUARTERS[clampi(int(settings.quarter), 0, QUARTERS.size() - 1)])


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


## Sharper copies of these textures for Medium and High: [Medium's, High's] ("" keeps the original). Low loads the
## originals, exactly as before (tests/test_runner.gd _low_unchanged). VRAM-compressed with mipmaps like the
## originals (the sky without). The floor and wall textures are 2K on High only: they repeat every 2-3 m, so even 1K
## gives more texels than the screen shows from the cameras; the sky (magnified about five times at 2K) and the
## players are sharper on both.
const HD_TEX := {
	"res://assets/venue/surfaces/white_maple_veneer_albedo_1k.jpg": ["", "res://assets/venue/surfaces/white_maple_veneer_albedo_2k.jpg"],
	"res://assets/venue/surfaces/concrete_block_wall_normal_1k.jpg": ["", "res://assets/venue/surfaces/concrete_block_wall_normal_2k.jpg"],
	"res://assets/venue/surfaces/ceiling_interior_albedo_1k.jpg": ["", "res://assets/venue/surfaces/ceiling_interior_albedo_2k.jpg"],
	"res://assets/venue/surfaces/clean_asphalt_albedo_1k.jpg": ["", "res://assets/venue/surfaces/clean_asphalt_albedo_2k.jpg"],
	"res://assets/venue/surfaces/asphalt_02_albedo_1k.jpg": ["", "res://assets/venue/surfaces/asphalt_02_albedo_2k.jpg"],
	"res://assets/venue/skies/netball_court_sky_2k.jpg": ["res://assets/venue/skies/netball_court_sky_4k.jpg", "res://assets/venue/skies/netball_court_sky_4k.jpg"],
	"res://assets/player/hero_albedo.jpg": ["res://assets/player/hero_albedo_2k.jpg", "res://assets/player/hero_albedo_2k.jpg"],
	"res://assets/player/hero_mask.png": ["res://assets/player/hero_mask_1k.png", "res://assets/player/hero_mask_1k.png"],
}


## Medium or High: the levels that load sharper textures, the crowd's 32 people and the richer sounds.
func hd() -> bool:
	return int(settings.graphics) > GFX_LOW


## Which file a texture is loaded from at graphics level g: its sharper copy (HD_TEX) where it has one, else itself.
func tex_path(path: String, g: int) -> String:
	if g <= GFX_LOW or not HD_TEX.has(path):
		return path
	var p: String = HD_TEX[path][mini(g, GFX_HIGH) - 1]
	return p if p != "" else path


## A texture at the current graphics level (tex_path).
func tex(path: String) -> Texture2D:
	return load(tex_path(path, int(settings.graphics)))


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


## Battery saver: the whole fraction of the screen's rate nearest 30 without going over about 36.
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
	return [0.35, 0.7, 1.0][clampi(int(settings.graphics), 0, 2)]


## A buzz for something that happened to the player's own side. Callers check it is the player's match.
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
	for f in ["NotoSansSinhala", "NotoSansTamil", "NotoSansSC"]:
		var path := "res://fonts/%s.ttf" % f
		if ResourceLoader.exists(path):
			fallbacks.append(_font(path))
	latin.fallbacks = fallbacks
	_latin = latin
	_fallbacks = fallbacks

	font_body = _variation(latin, 450, fallbacks)
	font_bold = _variation(latin, 650, fallbacks)
	# The display face: Barlow Condensed, the tall narrow letters of a stadium scoreboard; anything it cannot draw
	# (Sinhala, Tamil, Chinese, a macron it lacks) falls back to Noto Sans bold.
	var barlow := _font("res://fonts/BarlowCondensed-ExtraBold.ttf")
	var display_fallbacks: Array[Font] = []
	display_fallbacks.append(_variation(latin, 760, fallbacks))
	barlow.fallbacks = display_fallbacks
	font_display = barlow

	theme = Theme.new()
	theme.default_font = font_body

	theme.set_stylebox("normal", "Button", _sb(C_PANEL, 14, Color(1, 1, 1, 0.08), 1))
	theme.set_stylebox("hover", "Button", _sb(C_PANEL_HI, 14, Color(1, 1, 1, 0.16), 1))
	theme.set_stylebox("pressed", "Button", _sb(C_PANEL_HI.darkened(0.2), 14, C_ACCENT, 2))
	theme.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 14, C_ACCENT, 2))
	theme.set_stylebox("disabled", "Button", _sb(C_PANEL.darkened(0.3), 14))
	theme.set_color("font_color", "Button", C_INK)
	theme.set_color("font_hover_color", "Button", C_INK)
	theme.set_color("font_pressed_color", "Button", C_ACCENT)
	theme.set_color("font_focus_color", "Button", C_INK)
	theme.set_color("font_disabled_color", "Button", C_MUTED.darkened(0.3))

	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _sb(C_ACCENT, 14))
	theme.set_stylebox("hover", "PrimaryButton", _sb(C_ACCENT.lightened(0.1), 14))
	theme.set_stylebox("pressed", "PrimaryButton", _sb(C_ACCENT.darkened(0.15), 14))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(k, "PrimaryButton", C_ON_ACCENT)
	theme.set_font("font", "PrimaryButton", font_display)

	theme.set_type_variation("ChipButton", "Button")
	theme.set_stylebox("normal", "ChipButton", _sb(C_PANEL, 999, Color(1, 1, 1, 0.1), 1, 10))
	theme.set_stylebox("hover", "ChipButton", _sb(C_PANEL_HI, 999, Color(1, 1, 1, 0.2), 1, 10))
	theme.set_stylebox("pressed", "ChipButton", _sb(C_ACCENT, 999, C_ACCENT, 1, 10))
	theme.set_stylebox("hover_pressed", "ChipButton", _sb(C_ACCENT.lightened(0.1), 999, C_ACCENT, 1, 10))
	theme.set_color("font_pressed_color", "ChipButton", C_ON_ACCENT)
	theme.set_color("font_hover_pressed_color", "ChipButton", C_ON_ACCENT)

	theme.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 18, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _sb(C_PANEL, 18, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _sb(Color(0.06, 0.04, 0.14, 0.74), 16, Color(1, 1, 1, 0.08), 1, 12))

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
	theme.set_stylebox("focus", "LineEdit", _sb(C_BG, 10, C_ACCENT, 2))
	theme.set_color("font_color", "LineEdit", C_INK)

	theme.set_stylebox("panel", "PopupMenu", _sb(C_PANEL, 10, Color(1, 1, 1, 0.1), 1, 8))
	theme.set_stylebox("hover", "PopupMenu", _sb(C_PANEL_HI, 8))

	theme.set_stylebox("background", "ProgressBar", _sb(Color(1, 1, 1, 0.08), 999, Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _sb(C_ACCENT, 999, Color(0, 0, 0, 0), 0, 0))

	var grabber := _sb(Color(1, 1, 1, 0.18), 999, Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 999, Color(0, 0, 0, 0), 0, 0))
	_size_theme()


func _size_theme() -> void:
	if theme == null:
		return
	theme.default_font_size = ts(22)
	for pair in [["PrimaryButton", 34], ["ChipButton", 20], ["TitleLabel", 80], ["HeaderLabel", 46], ["SubLabel", 24],
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
