class_name WsgSettings
extends RefCounted
## The player's settings, the same keys in every game (owner-approved item 8), kept in user://wsg_settings.cfg, and the
## common Settings screen (screen()): graphics (Low, Medium, High - WsgFoundation.tier), sound (one slider a bus:
## Effects, Crowd, Music...), the joystick (its side and size), haptics (WsgHaptics.enabled). Themed by the game's
## WsgBroadcastTheme. The game reads them at start (load_all()) and gets applied(key, value) on each change.
##   WsgSettings.load_all()                       # at boot, before anything is built
##   var s := WsgSettings.screen(theme, {"buses": ["Effects", "Crowd", "Music"]})
##   s.applied.connect(func(k, v): if k == "graphics": rebuild_venue())
##   add_child(s)

const PATH := "user://wsg_settings.cfg"
const DEFAULTS := {"graphics": -1, "haptics": true, "joystick_side": "left", "joystick_size": 1.0}

static var values := {}


static func load_all() -> Dictionary:
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in cf.get_section_keys("settings"):
			values[k] = cf.get_value("settings", k)
	if int(values.graphics) < 0:
		values.graphics = WsgFoundation.starting_tier()
	WsgFoundation.tier = WsgFoundation.allowed(int(values.graphics))
	WsgHaptics.enabled = bool(values.haptics)
	for k in values:
		if String(k).begins_with("volume_"):
			_volume(String(k).substr(7), float(values[k]))
	return values


static func get_value(key: String, def: Variant = null) -> Variant:
	if values.is_empty():
		load_all()
	return values.get(key, DEFAULTS.get(key, def))


## Sets KEY, applies what the foundation owns (the tier, haptics, a bus's volume), saves.
static func set_value(key: String, v: Variant) -> void:
	if values.is_empty():
		load_all()
	values[key] = v
	match key:
		"graphics":
			WsgFoundation.tier = WsgFoundation.allowed(int(v))
		"haptics":
			WsgHaptics.enabled = bool(v)
	if key.begins_with("volume_"):
		_volume(key.substr(7), float(v))
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


static func _volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


## The Settings screen (a Control, full rect, scrolling): opts {"buses": [bus names for sliders], "joystick": true,
## "title": "Settings", "back": Callable()}.
static func screen(theme: WsgBroadcastTheme = null, opts := {}) -> WsgSettingsScreen:
	return WsgSettingsScreen.new(theme if theme else WsgBroadcastTheme.default(), opts)
