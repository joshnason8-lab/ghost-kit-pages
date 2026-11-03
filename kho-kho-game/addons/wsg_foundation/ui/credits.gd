class_name WsgCredits
extends Control
## The Licences and credits screen, the same in every game (owner-approved item 8): the game's own credits, the High
## pack's (res://wsg_pack.json "credits"), the foundation's (the motion capture) and the Godot Engine's notices -
## built a few paragraphs a frame (never on a thread: Kabaddi's threaded one froze for a second or more and now and
## then crashed), so it opens at once and fills in as the player reads.
##   var c := WsgCredits.new(theme, game_sections)      # [{"title": "Sounds", "body": "Crowd: kenney.nl (CC0)\n..."}]
##   c.closed.connect(c.queue_free); add_child(c)

signal closed
signal built

## Work a frame, at most (ms): the build yields once it has used this much.
const SLICE_MS := 4.0
var theme_b: WsgBroadcastTheme
var sections: Array = []
var _col: VBoxContainer
var built_paragraphs := 0
var done := false
## The longest any one frame of the build took (ms), for a test or a log.
var longest_ms := 0.0


func _init(p_theme: WsgBroadcastTheme = null, game_sections: Array = [], with_engine := true) -> void:
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	name = "WsgCredits"
	sections = game_sections.duplicate()
	sections.append_array(pack_sections())
	sections.append_array(foundation_sections())
	if with_engine:
		sections.append_array(engine_sections())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_col)
	var top := HBoxContainer.new()
	_col.add_child(top)
	top.add_child(theme_b.label(tr("Licences and credits"), theme_b.title_size, theme_b.accent))
	var b := Button.new()
	b.text = tr("Back")
	b.custom_minimum_size = Vector2(96, 48)
	b.pressed.connect(func(): closed.emit())
	top.add_child(b)


func _ready() -> void:
	_build()


func _build() -> void:
	var t0 := Time.get_ticks_usec()
	for s: Dictionary in sections:
		_col.add_child(theme_b.label(str(s.get("title", "")), theme_b.sub_size + 2, theme_b.accent))
		for para in str(s.get("body", "")).split("\n\n", false):
			var l := theme_b.label(para, maxi(14, theme_b.sub_size - 4), theme_b.text)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_col.add_child(l)
			built_paragraphs += 1
			if (Time.get_ticks_usec() - t0) / 1000.0 >= SLICE_MS:
				longest_ms = maxf(longest_ms, (Time.get_ticks_usec() - t0) / 1000.0)
				await get_tree().process_frame
				if not is_inside_tree():
					return
				t0 = Time.get_ticks_usec()
	longest_ms = maxf(longest_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	done = true
	built.emit()


## The High pack's credits (res://wsg_pack.json "credits": [{"title", "body"}]): the pack's own, Meshy and CC assets.
static func pack_sections(path := "res://wsg_pack.json") -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or not (d as Dictionary).has("credits"):
		return []
	var out := []
	for c in d.credits:
		out.append({"title": TranslationServer.translate("High graphics pack") + ": " + str(c.get("title", "")), "body": str(c.get("body", ""))})
	return out


## The foundation's own credits (what every game on it uses).
static func foundation_sections() -> Array:
	var body := "World Stage Games shared foundation.\n\nMotion capture: the Mobility pack by MoCap Online, and Reallusion ActorCore motions, licensed for use in these games."
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		body = "World Stage Games shared foundation."
	return [{"title": TranslationServer.translate("Animation"), "body": body}]


## The Godot Engine's notices (its licence and its third-party components'), as the engine gives them.
static func engine_sections() -> Array:
	var out := [{"title": "Godot Engine", "body": "This game uses the Godot Engine, available under the following licence:\n\n" + Engine.get_license_text()}]
	var parts := []
	for c in Engine.get_copyright_info():
		var lines := []
		for p in c.parts:
			lines.append("%s: %s (%s)" % [", ".join(p.files), ", ".join(p.copyright), p.license])
		parts.append("%s\n%s" % [c.name, "\n".join(lines)])
	out.append({"title": TranslationServer.translate("Third-party components"), "body": "\n\n".join(parts)})
	var lic := Engine.get_license_info()
	var texts := []
	for k in lic:
		texts.append("%s\n%s" % [k, lic[k]])
	out.append({"title": TranslationServer.translate("Licences"), "body": "\n\n".join(texts)})
	return out
