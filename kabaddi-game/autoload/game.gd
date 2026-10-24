extends Node
## Global state: settings, saves, theme, and moving between screens.

const SETTINGS_PATH := "user://settings.json"
const CAREER_PATH := "user://career.json"
const CUP_PATH := "user://cup.json"
const SEASON_PATH := "user://season.json"

## The game's privacy policy and help pages (Settings > About), on thekabaddipulse.com. Earlier builds open the web
## version's privacy.html and support.html, which forward here (tools/web/netlify.toml).
const PRIVACY_URL := "https://thekabaddipulse.com/kabaddi-raid/privacy/"
const SUPPORT_URL := "https://thekabaddipulse.com/kabaddi-raid/support/"

## Code, name in the language itself, name in English.
const LANGUAGES := [
	["en", "English", "English"],
	["hi", "हिन्दी", "Hindi"],
	["mr", "मराठी", "Marathi"],
	["ta", "தமிழ்", "Tamil"],
	["te", "తెలుగు", "Telugu"],
	["kn", "ಕನ್ನಡ", "Kannada"],
	["bn", "বাংলা", "Bengali"],
	["pa", "ਪੰਜਾਬੀ", "Punjabi"],
]

const CAM_THIRD := 0
const CAM_FIRST := 1
const CAM_TV := 2

const GFX_LOW := 0
const GFX_MEDIUM := 1
const GFX_HIGH := 2

## Frame rate (Settings): Battery saver, about 30 frames a second and the court drawn softer; Smooth, 60 a second (the
## default); Max, as many as the screen shows.
const FPS_SAVER := 0
const FPS_SMOOTH := 1
const FPS_MAX := 2

## The buzz for what happens to you in a match (Settings, Vibration): milliseconds and strength (0-1), or, for a
## pattern, buzzes and the gaps between them in milliseconds.
const HAPTICS := {
	"touch": [24, 0.55],                         # your hand or foot on a defender
	"touched": [16, 0.35],                       # the raider's on you
	"hold": [45, 0.8],                           # your hold on the raider
	"team_hold": [20, 0.35],                     # a team-mate's, as you defend
	"held": [70, 1.0],                           # the first hold on you
	"held_more": [35, 0.7],                      # another hold on you
	"takedown": [120, 1.0],                      # you are brought down
	"tackle_won": [[40, 0.8], 90, [60, 1.0]],    # your side brings the raider down
	"dash": [50, 0.85],                          # your dash lands, or one lands on you
	"free": [[20, 0.6], 70, [20, 0.6]],          # you break free
}

# Brand palette, shared with the HUD and menus.
const C_BG := Color("0c1a29")
const C_PANEL := Color("172f47")
const C_PANEL_HI := Color("21405f")
const C_INK := Color("f3efe6")
const C_MUTED := Color("9db0c7")
const C_SAFFRON := Color("ff9a1f")
const C_GOLD := Color("ffd27a")
const C_MAGENTA := Color("e8336d")
const C_GOOD := Color("4cd38a")
const C_DANGER := Color("ff5a5a")

var settings := {
	"language": "",         # "" follows the phone's language
	"lang_v": 2,            # settings version: 2 stopped pinning the phone's language on first run
	"camera": CAM_TV,       # the broadcast camera; third person behind the raider is the other choice
	"cam_v": 2,             # settings version: 2 made the broadcast camera the default
	"graphics": GFX_MEDIUM,
	"sound": true,
	"music": true,          # the menus' music (needs sound on too)
	"vol_fx": 100,          # the volume sliders, 0..100 (Sfx.apply_volumes): the players' and officials' sounds,
	"vol_crowd": 100,       # the crowd and the ground's own sound,
	"vol_music": 100,       # the menus' music
	"vibration": true,
	"left_handed": false,
	"btn_size": 0,          # the match buttons' size: 0 Normal, 1 Large, 2 Extra large (TouchControls.SIZE_K)
	"btn_places": [],       # where the player put the six match buttons (Move buttons), or [] for the size's own
	"difficulty": 1,
	"length": 0,
	"seen_howto": false,
	"raid_rule": 2,         # 0 Pro 30-second clock, 1 cant by tapping, 2 Breath (cant runs by itself)
	"rules_v": 2,           # settings version: 2 made Breath the default
	"models": 1,            # 0 classic code-built players, 1 realistic rigged players
	"tutorial_done": [],
	"auto_gfx": true,       # lower the graphics by itself if a match runs slowly
	"fps": FPS_SMOOTH,      # frame rate: FPS_SAVER, FPS_SMOOTH or FPS_MAX (frame_cap)
	"tags": 0,              # tags over players' heads: 0 names over you and the raider (numbers over the rest),
	                        # 1 names over everyone, 2 none (MatchHud.PlayerTags)
	"dev": false,           # the developer's overlay in matches (DevOverlay): seven taps on the home screen's version
}

signal loaded   # the loading screen is going: the home screen behind it is ready

var main: Node = null
var current: Node = null
var loading := false   # the loading screen is up (ui/loading_screen.gd)
var theme: Theme
var font_body: Font
var font_bold: Font
var font_display: Font
var career = null  # Career (RefCounted), loaded lazily
var cup = null     # Cup (RefCounted), loaded lazily
var season = null  # Season (RefCounted), loaded lazily


func _ready() -> void:
	load_settings()
	apply_frame_rate()
	TranslationServer.set_locale(language())
	_build_theme()
	get_tree().root.theme = theme
	get_tree().root.get_viewport().gui_embed_subwindows = true


## The phone's back button and the app going into the background.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Leaving the app mid-raid pauses the match.
			if current and is_instance_valid(current) and current.has_method("set_paused") and not bool(current.get("paused")):
				current.set_paused(true)


## Back: pause or resume a match, leave a screen the way its Back button does, and quit
## from the main menu.
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


## The language in use: the player's pick, or else the phone's.
func language() -> String:
	return String(settings.language) if String(settings.language) != "" else phone_language()


## The phone's language if the game has it, else English.
func phone_language() -> String:
	var os_lang := OS.get_locale_language()
	for pair in LANGUAGES:
		if pair[0] == os_lang:
			return os_lang
	return "en"


## A language's own name ("हिन्दी"), and its English name.
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
		if data.has("cant") and not data.has("raid_rule"):
			# Older saves had a cant switch (tap or automatic); keep what the player chose.
			settings.raid_rule = 1 if int(data.cant) == 0 else 2
	# JSON gives floats; keep ints as ints.
	for k in ["camera", "graphics", "difficulty", "length", "raid_rule", "models", "tags", "fps", "btn_size", "vol_fx",
			"vol_crowd", "vol_music"]:
		settings[k] = int(settings[k])
	if not TouchControls.is_layout(settings.btn_places):
		settings.btn_places = []
	if data is Dictionary and int(data.get("rules_v", 1)) < 2:
		# Tapping the cant was the old default and it tied up the thumb: move to Breath.
		if settings.raid_rule == 1:
			settings.raid_rule = 2
		settings.rules_v = 2
	if data is Dictionary and int(data.get("lang_v", 1)) < 2:
		# The first run used to save the phone's language as if picked; follow the phone instead.
		if String(settings.language) == phone_language():
			settings.language = ""
		settings.lang_v = 2
	if data is Dictionary and int(data.get("cam_v", 1)) < 2:
		# The broadcast camera is the default now: saves from before it (third person, whether picked or not)
		# move to it once.
		settings.camera = CAM_TV
		settings.cam_v = 2
	if settings.raid_rule > 2:
		settings.raid_rule = 2   # the spoken cant (3) is gone
	if settings.camera == CAM_FIRST:
		settings.camera = CAM_TV


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


## Pick a language; "" goes back to following the phone.
func set_language(code: String) -> void:
	settings.language = code
	TranslationServer.set_locale(language())
	_size_theme()
	save_settings()


## How big a language's text is set against the English sizes. Words made for English in a space made for English:
## Tamil's labels run 1.4 times as wide as English at the median (2.2 times for the longest tenth), Kannada's and
## Telugu's up to 1.3-1.4 times, so their text is set a little smaller; the rest are as narrow as English or narrower.
const TEXT_K := {"ta": 0.86, "kn": 0.93, "te": 0.93}


func text_k() -> float:
	return float(TEXT_K.get(TranslationServer.get_locale().left(2), 1.0))


## Languages whose words run long enough that a line about a player can need a third line (UI.fit).
func long_words() -> bool:
	return TranslationServer.get_locale().left(2) in ["ta", "te", "kn", "bn"]


## A font size for the language being shown (text_k).
func ts(size: int) -> int:
	return maxi(1, roundi(size * text_k()))


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed


func _write_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- career and cup

func get_career():
	if career == null:
		var data = _read_json(CAREER_PATH)
		if data is Dictionary:
			career = Career.from_dict(data)
	return career


func new_career(profile: Dictionary):
	career = Career.create(profile)
	save_career()
	return career


func save_career() -> void:
	if career:
		_write_json(CAREER_PATH, career.to_dict())


func delete_career() -> void:
	career = null
	delete_file(CAREER_PATH)


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


func get_season():
	if season == null:
		var data = _read_json(SEASON_PATH)
		if data is Dictionary:
			season = Season.from_dict(data)
	return season


func new_season(team_id: String):
	season = Season.create(team_id)
	save_season()
	return season


func save_season() -> void:
	if season:
		_write_json(SEASON_PATH, season.to_dict())


func delete_season() -> void:
	season = null
	delete_file(SEASON_PATH)


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
	Sfx.music(true)   # the menus' music, carrying on from screen to screen
	return node


func goto_menu() -> void:
	show_screen("res://ui/main_menu.gd")


## config keys: home (team id), away (team id), arena, length, difficulty,
## mode ("quick"|"cup"|"career"), knockout (bool), control ("all"|"career"),
## career_player (Dictionary, optional), user_team (0 or 1)
func start_match(config: Dictionary) -> void:
	var s: Script = load("res://game/match.gd")
	var m: Node = s.new()
	m.config = config
	Sfx.music(false)
	_swap(m)


func on_match_finished(result: Dictionary) -> void:
	match String(result.config.get("mode", "quick")):
		"cup":
			get_cup().record_user_result(result)
			save_cup()
		"career":
			get_career().record_user_result(result)
			save_career()
		"season":
			get_season().record_user_result(result)
			save_season()
	show_screen("res://ui/result_screen.gd", {"result": result})


# ---------------------------------------------------------------- graphics

func apply_graphics(viewport: Viewport) -> void:
	var g := int(settings.graphics)
	match g:
		GFX_LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.7
		GFX_MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 0.85
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
	if int(settings.get("fps", FPS_SMOOTH)) == FPS_SAVER:
		viewport.scaling_3d_scale *= 0.8   # the battery saver draws the court a little softer


## The screen's refresh rate, a whole number (60 when the phone does not say).
func screen_hz() -> int:
	var hz := roundi(DisplayServer.screen_get_refresh_rate())
	return hz if hz > 0 else 60


## Smooth's frame rate on a screen of HZ: 60 on a 60, 120 or 240 Hz screen, which shows each frame for the same number
## of refreshes; half the screen's rate at 144 Hz and up (72). 0, no cap, on a screen 60 does not divide evenly, such
## as 90 Hz, where 60 frames a second would be shown unevenly.
func smooth_cap(hz: int) -> int:
	if hz % 60 == 0:
		return 60
	if hz >= 130:
		return hz / 2
	return 0


## The battery saver's frame rate on a screen of HZ: about 30, a whole number of refreshes each (30 at 60, 90 or
## 120 Hz; 36 at 144 Hz, where 30 would be shown unevenly).
func saver_cap(hz: int) -> int:
	return hz / ceili(hz / 36.0)


## The most frames a second the game draws: 0 for as many as the screen shows.
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
	return int(settings.graphics) >= GFX_MEDIUM


func crowd_density() -> float:
	return [0.35, 0.65, 1.0][int(settings.graphics)]


## Buzz the phone for something that happens to you in a match (HAPTICS), if vibration is on.
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


# ---------------------------------------------------------------- text helpers

## Money is stored in lakhs (1 crore = 100 lakhs).
func fmt_money(lakhs: float) -> String:
	if lakhs >= 100.0:
		var cr := snappedf(lakhs / 100.0, 0.01)
		return tr("CRORE").format({"n": String.num(cr, 2)})
	return tr("LAKH").format({"n": str(int(round(lakhs)))})


# ---------------------------------------------------------------- theme

func _font(path: String) -> FontFile:
	var f: FontFile = load(path)
	return f


func _build_theme() -> void:
	var latin := _font("res://fonts/NotoSans.ttf")
	var fallbacks: Array[Font] = [
		_font("res://fonts/NotoSansDevanagari.ttf"),
		_font("res://fonts/NotoSansBengali.ttf"),
		_font("res://fonts/NotoSansTamil.ttf"),
		_font("res://fonts/NotoSansTelugu.ttf"),
		_font("res://fonts/NotoSansKannada.ttf"),
		_font("res://fonts/NotoSansGurmukhi.ttf"),
	]
	latin.fallbacks = fallbacks

	font_body = _variation(latin, 450, fallbacks)
	font_bold = _variation(latin, 650, fallbacks)
	var teko := _font("res://fonts/Teko.ttf")
	var display_fallbacks: Array[Font] = []
	display_fallbacks.append(_variation(latin, 700, fallbacks))
	teko.fallbacks = display_fallbacks
	font_display = _variation(teko, 600, display_fallbacks)

	theme = Theme.new()
	theme.default_font = font_body

	# Buttons: dark panel with a hairline, saffron on focus.
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

	# Primary call to action.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _sb(C_SAFFRON, 12))
	theme.set_stylebox("hover", "PrimaryButton", _sb(C_SAFFRON.lightened(0.1), 12))
	theme.set_stylebox("pressed", "PrimaryButton", _sb(C_SAFFRON.darkened(0.15), 12))
	theme.set_color("font_color", "PrimaryButton", Color("1d1307"))
	theme.set_color("font_hover_color", "PrimaryButton", Color("1d1307"))
	theme.set_color("font_pressed_color", "PrimaryButton", Color("1d1307"))
	theme.set_color("font_focus_color", "PrimaryButton", Color("1d1307"))
	theme.set_font("font", "PrimaryButton", font_display)

	# Toggle chips for option rows.
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
	theme.set_font_size("font_size", "ScoreLabel", 64)

	theme.set_stylebox("normal", "LineEdit", _sb(C_BG, 10, Color(1, 1, 1, 0.15), 1))
	theme.set_stylebox("focus", "LineEdit", _sb(C_BG, 10, C_SAFFRON, 2))
	theme.set_color("font_color", "LineEdit", C_INK)

	theme.set_stylebox("panel", "PopupMenu", _sb(C_PANEL, 10, Color(1, 1, 1, 0.1), 1, 8))
	theme.set_stylebox("hover", "PopupMenu", _sb(C_PANEL_HI, 8))
	theme.set_stylebox("normal", "OptionButton", _sb(C_PANEL, 12, Color(1, 1, 1, 0.1), 1))
	theme.set_stylebox("hover", "OptionButton", _sb(C_PANEL_HI, 12, Color(1, 1, 1, 0.18), 1))
	theme.set_stylebox("pressed", "OptionButton", _sb(C_PANEL_HI, 12, C_SAFFRON, 2))
	theme.set_stylebox("focus", "OptionButton", _sb(Color(0, 0, 0, 0), 12, C_SAFFRON, 2))

	var bar_bg := _sb(Color(1, 1, 1, 0.08), 999, Color(0, 0, 0, 0), 0, 0)
	var bar_fg := _sb(C_SAFFRON, 999, Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fg)

	var grabber := _sb(Color(1, 1, 1, 0.18), 999, Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 999, Color(0, 0, 0, 0), 0, 0))
	_size_theme()


## The theme's text sizes, for the language being shown (text_k); again whenever the language changes.
func _size_theme() -> void:
	if theme == null:
		return
	theme.default_font_size = ts(22)
	for pair in [["PrimaryButton", 34], ["ChipButton", 20], ["TitleLabel", 76], ["HeaderLabel", 44], ["SubLabel", 24],
			["MutedLabel", 19], ["EyebrowLabel", 16], ["PopupMenu", 22]]:
		theme.set_font_size("font_size", pair[0], ts(pair[1]))
	theme.set_font_size("font_size", "ScoreLabel", 64)   # numbers only


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
