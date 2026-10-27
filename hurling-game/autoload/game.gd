extends Node
## Global state: settings, saves, theme, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const CHAMP_PATH := "user://championship.json"
const RECORDS_PATH := "user://records.json"
const SUSPENDED_PATH := "user://suspended.json"   # a championship match left part-way (Match.snapshot)

## Code, name in the language itself, name in English. Hurling is played and watched in Ireland and by the Irish
## abroad (Britain, North America, Australia): English for everyone, and Irish, the game's own language
## (docs/LANGUAGES.md).
const LANGUAGES := [
	["en", "English", "English"],
	["ga", "Gaeilge", "Irish"],
]

const CAM_TV := 0       # the broadcast camera: high in the stand at the halfway line, panning and zooming with the ball
const CAM_HIGH := 1     # higher and wider: more of the pitch, the players smaller
const CAM_END := 2      # behind the goal you are attacking

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second at 80% render scale; Smooth, 60 a second (the
## default); Max, as many as the screen shows. Each is a whole fraction of the screen's refresh rate.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds. Never in a match only the AI plays.
const HAPTICS := {
	"strike": [22, 0.55],                        # your strike: ash meets leather
	"catch": [16, 0.4],                          # you catch it
	"tackled": [45, 0.8],                        # you are shouldered or hooked
	"score": [[30, 0.7], 80, [60, 1.0]],         # your side scores
	"free": [80, 0.6],                           # the referee gives a free against you
	"card": [[60, 0.9], 90, [60, 0.9]],          # you are shown a card
}

# The palette: a parish pitch at dusk and the printed match programme (cream paper, black ink, a red and a green).
const C_BG := Color("10201a")
const C_PANEL := Color("1b3228")
const C_PANEL_HI := Color("27463a")
const C_INK := Color("f4ecd8")
const C_MUTED := Color("a8b9a9")
const C_SAFFRON := Color("e0a43a")   # the evening light, the sliotar's leather: the accent
const C_GOLD := Color("f2d389")
const C_MAGENTA := Color("c8452c")   # the programme's red
const C_TEAL := Color("3fae7a")      # the grass
const C_GOOD := Color("62d38f")
const C_DANGER := Color("ff6a5a")
const C_PAPER := Color("efe5cc")
const C_PAPER_DK := Color("ddcfae")
const C_PRINT := Color("1f1b15")

## Match length, in minutes of real time for a match you play: the clock runs faster so a full match fits. The last
## is the real thing, a minute a minute.
const LENGTHS := [8, 14, 20, 35]

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
	"btn_pos": {},          # buttons you have moved: id -> [x, y] as a fraction of the screen
	"difficulty": 0,        # 0 Junior, 1 Intermediate, 2 Senior, 3 All-Star (Junior to start: docs/PLAYTEST.md)
	"assist": 1,            # 0 none; 1 your player solos by himself before his fourth step; 2 that and the switch
	"length": 1,            # LENGTHS: how long a match you play takes
	"grade": 0,             # 0 senior county (2 x 35), 1 club and minor (2 x 30)
	"draw_rule": 0,         # a drawn knock-out game: 0 extra time then penalties, 1 extra time then a replay (old)
	"tags": 0,              # the numbers over players' heads: 0 on, 2 off
	"seen_howto": false,
	"venue": "county",      # the ground last picked in match setup
	"tactics": {"sweeper": false, "two_ff": false, "puckout": 1},   # your side's set-up (TeamAI.tactics)
	"auto_subs": true,      # the manager makes your substitutions (else you do, from the pause menu)
	"coach": true,          # coach's tips in a match (game/coach.gd); off by itself after your first match
	"dev": false,
}

signal loaded   # the loading screen is going: the home screen behind it is ready

var main: Node = null
var current: Node = null
var loading := false
var theme: Theme
## A touch screen: no hover look on buttons (Android moves an emulated mouse to where a finger lifts, so a chip or
## button dragged over would stay lit as if hovered).
var touch_ui := DisplayServer.is_touchscreen_available()
var font_body: Font
var font_bold: Font
var font_display: Font
var font_title: Font
var champ = null   # Championship (RefCounted), loaded lazily
var _latin: FontFile
var _fallbacks: Array[Font] = []
var records := {}  # the record book: titles won, biggest wins, top scorers


func _ready() -> void:
	load_settings()
	if int(settings.graphics) < 0:
		settings.graphics = detect_graphics()
		save_settings()
	elif int(settings.graphics) > GFX_HIGH:
		settings.graphics = GFX_HIGH       # the 0.10 betas' Ultra is High now
		save_settings()
	Ultra.boot()
	loaded.connect(Ultra.started)
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


## Back: pause or resume a match, leave a screen the way its Back button does, and quit from the home screen.
func go_back() -> void:
	if current == null or not is_instance_valid(current):
		return
	if current.has_method("on_back"):
		current.on_back()
	elif current.has_meta("back"):
		(current.get_meta("back") as Callable).call()
	elif String(current.get_script().resource_path).ends_with("main_menu.gd"):
		if current.has_method("close_overlay") and current.close_overlay():
			return
		get_tree().quit()
	else:
		goto_menu()


## The graphics level for this phone on its first run: Low on a phone with a small GPU or under 4.5 GB of memory (a
## Galaxy A0x/A1x's Mali-G52 or G57, Adreno 5xx and 61x, PowerVR), High on a recent high-end phone (Ultra.capable:
## Adreno 640 and later, Mali-G710 and later, Immortalis, Xclipse, with 6 GB), Medium on the rest.
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
	return GFX_HIGH if Ultra.capable() else GFX_MEDIUM


## The sharper version of a texture, for Medium and High (Low always loads the file named): "x_1k.jpg" becomes
## "x_2k.jpg", anything else "x_hd.<ext>", when that file is in the game.
func hd(path: String) -> String:
	if int(settings.graphics) == GFX_LOW:
		return path
	var p := path.replace("_1k.", "_2k.") if path.contains("_1k.") else path.get_basename() + "_hd." + path.get_extension()
	return p if ResourceLoader.exists(p) else path


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
	for k in ["camera", "graphics", "fps", "btn_size", "difficulty", "assist", "length", "grade", "draw_rule", "tags"]:
		settings[k] = int(settings[k])
	if not (settings.btn_pos is Dictionary):
		settings.btn_pos = {}
	if not (settings.tactics is Dictionary):
		settings.tactics = {"sweeper": false, "two_ff": false, "puckout": 1}
	settings.length = clampi(int(settings.length), 0, LENGTHS.size() - 1)


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func set_language(code: String) -> void:
	settings.language = code
	TranslationServer.set_locale(language())
	_size_theme()
	save_settings()


## How big a language's text is set against the English sizes: Irish runs about a fifth longer, so its text is set a
## little smaller and every label is fitted besides (UI.fit, UI.shrink).
const TEXT_K := {"ga": 0.96}


func text_k() -> float:
	return float(TEXT_K.get(TranslationServer.get_locale().left(2), 1.0))


## Languages whose words run long enough that a line about a player can need another line (UI.fit).
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["ga"]


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


# ---------------------------------------------------------------- the championship, records

func get_champ():
	if champ == null:
		var data = _read_json(CHAMP_PATH)
		if data is Dictionary:
			champ = Championship.from_dict(data)
	return champ


func new_champ(team_id: String):
	champ = Championship.create(team_id)
	save_champ()
	return champ


func save_champ() -> void:
	if champ:
		_write_json(CHAMP_PATH, champ.to_dict())


func delete_champ() -> void:
	champ = null
	delete_file(CHAMP_PATH)
	clear_suspended()


## A championship match left part-way: kept to carry on with (Match.snapshot()), {} if none.
func save_suspended(snap: Dictionary) -> void:
	_write_json(SUSPENDED_PATH, snap)


func suspended() -> Dictionary:
	if not FileAccess.file_exists(SUSPENDED_PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUSPENDED_PATH))
	return d if d is Dictionary and d.has("config") else {}


func clear_suspended() -> void:
	delete_file(SUSPENDED_PATH)


## The suspended match, if it is the championship's next one for the player's county; else none (and it goes).
func suspended_for(f: Dictionary) -> Dictionary:
	var s := suspended()
	if s.is_empty() or f.is_empty():
		return {}
	if String(s.config.get("home", "")) == String(f.home) and String(s.config.get("away", "")) == String(f.away):
		return s
	clear_suspended()
	return {}


func resume_match(snap: Dictionary) -> void:
	var cfg: Dictionary = (snap.config as Dictionary).duplicate(true)
	cfg.user_team = int(cfg.get("user_team", 0))
	cfg.resume = snap
	start_match(cfg)


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


## config keys: home, away (team ids), venue (DB.VENUES id), user_team (0, 1 or -1 for none), mode ("quick"|"champ"
## |"watch"), stage (a line naming the game: "Semi-final"), knockout (bool: a draw goes to extra time), half (minutes
## of the clock in a half), length (real minutes the match takes), seed, difficulty.
func start_match(config: Dictionary) -> void:
	var s: Script = load("res://game/match.gd")
	var m: Node = s.new()
	m.config = config
	Sfx.music(false)
	_swap(m)


func on_match_finished(result: Dictionary) -> void:
	Records.add_match(result)
	# The coach's tips are for a first match: once one is played through, they go off (Settings turns them on).
	if int(result.get("user_team", -1)) >= 0 and bool(settings.get("coach", true)):
		settings.coach = false
		save_settings()
	if String(result.config.get("mode", "quick")) == "champ" and get_champ() != null:
		get_champ().record_user_result(result)
		save_champ()
	show_screen("res://ui/result_screen.gd", {"result": result})


# ---------------------------------------------------------------- graphics

func apply_graphics(viewport: Viewport) -> void:
	match int(settings.graphics):
		GFX_LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
		GFX_MEDIUM:
			# 4x, not 2x: on Vulkan 2x left the far lines in dashes; a phone's tiled GPU smooths 4x almost for free.
			viewport.msaa_3d = Viewport.MSAA_4X
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
	return [0.22, 0.7, 1.0][clampi(int(settings.graphics), 0, 2)]


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
	_latin = latin
	_fallbacks = fallbacks
	font_body = _variation(latin, 450, fallbacks)
	font_bold = _variation(latin, 650, fallbacks)
	# Headings in a condensed face, like a match programme's; the game's name in it too, at its heaviest.
	var oswald := _font("res://fonts/Oswald.ttf")
	var display_fallbacks: Array[Font] = []
	display_fallbacks.append(_variation(latin, 700, fallbacks))
	oswald.fallbacks = display_fallbacks
	font_display = _variation(oswald, 600, display_fallbacks)
	font_title = _variation(oswald, 700, display_fallbacks)

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

	if touch_ui:
		flatten_hover(theme)

	theme.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 16, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _sb(C_PANEL, 16, Color(1, 1, 1, 0.06), 1, 20))
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _sb(Color(0.03, 0.07, 0.12, 0.72), 14, Color(1, 1, 1, 0.08), 1, 12))

	theme.set_color("font_color", "Label", C_INK)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", font_display)
	theme.set_type_variation("LogoLabel", "Label")
	theme.set_font("font", "LogoLabel", font_title)
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


## On a touch screen the hover look is the normal one (and pressed for a chosen chip).
static func flatten_hover(t: Theme) -> void:
	for type in ["Button", "PrimaryButton", "ChipButton"]:
		if t.has_stylebox("normal", type):
			t.set_stylebox("hover", type, t.get_stylebox("normal", type))
		if t.has_stylebox("pressed", type):
			t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
		if t.has_color("font_color", type):
			t.set_color("font_hover_color", type, t.get_color("font_color", type))
		if t.has_color("font_pressed_color", type):
			t.set_color("font_hover_pressed_color", type, t.get_color("font_pressed_color", type))


func _size_theme() -> void:
	if theme == null:
		return
	theme.default_font_size = ts(22)
	for pair in [["PrimaryButton", 34], ["ChipButton", 20], ["TitleLabel", 64], ["LogoLabel", 72], ["HeaderLabel", 44], ["SubLabel", 24],
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
