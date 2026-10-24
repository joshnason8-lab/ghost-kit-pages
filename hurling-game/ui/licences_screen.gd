extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Hurling Heroes[/b]
Made by Josh Nason.
The hurlers: the maker's own player model, moving with motion capture from Adobe Mixamo (mixamo.com) and the
CMU Graphics Lab Motion Capture Database (clips 35_01 and 35_17). Motion capture data from mocap.cs.cmu.edu. The
database was created with funding from NSF EIA-0196217.
The skies, the grass and field textures, the small broadleaf and fern cut-outs, the painted bench, the street lamps
and the mossy rocks: Poly Haven (polyhaven.com), CC0. The oak and broadleaf trees, the hedgerow grasses, the
thatched cottages, the terraced houses and the park bench: the maker's own models.
The referee, the umpires, the people in the crowd and the floodlights: the maker's own models, made with Meshy
(meshy.ai). Stands and sliotar made in code for the game; the menu music written for it
(tools/audio/make_music.py). Crowd reactions from Kabaddi Raid, by the same maker.
Sounds: the stadium crowd's murmur, cheer and roar from "Free Crowd Cheering Sounds" by Gregor Quendel
(opengameart.org), CC-BY 4.0; birdsong from "Park ambiences" by Thimras (opengameart.org), CC0; footsteps, knocks and
the menu click from Kenney's Impact Sounds and Interface Sounds (kenney.nl), CC0; the whistle and the strike made in
code. Every sound's source: docs/SOUNDS.md.
The game is not connected with, or endorsed by, any sporting body, county board or club. Counties appear by their
place names, in colours of the game's own design; every player is invented."""

const FONTS := """[b]Fonts[/b]
Noto Sans: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic).
Oswald: Copyright 2016 The Oswald Project Authors (https://github.com/googlefonts/OswaldFont).
Uncial Antiqua: Copyright (c) 2011 by Brian J. Bonislawsky DBA Astigmatic (AOETI), with Reserved Font Name "Uncial Antiqua".
All under the SIL Open Font License, Version 1.1:"""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("LICENCES"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	col.add_child(UI.wrap(tr("LICENCES_INTRO"), "MutedLabel", 18))
	col.add_child(_text(CREDITS))
	col.add_child(_text(FONTS + "\n\n" + _plain(FileAccess.get_file_as_string("res://fonts/OFL.txt").strip_edges())))
	col.add_child(_text("[b]Godot Engine[/b]\n" + _plain(Engine.get_license_text().strip_edges())))
	# The engine's own parts, each with its copyright and licence, then the licences' texts.
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in c.parts:
			for who in part.copyright:
				lines.append(_plain(String(who)))
			lines.append("(" + String(part.license) + ")")
		parts.append("[b]%s[/b]\n%s" % [_plain(String(c.name)), "\n".join(lines)])
	col.add_child(_text("[b]Parts of the Godot Engine[/b]\n\n" + "\n\n".join(parts)))
	var info: Dictionary = Engine.get_license_info()
	for name in info:
		col.add_child(_text("[b]%s[/b]\n%s" % [_plain(String(name)), _plain(String(info[name]).strip_edges())], true))


## Licence texts are long, but are laid out on the main thread: laid out on its own thread (RichTextLabel.threaded),
## a text freed while still being laid out (leaving the screen at once) crashed the engine in a CI run.
func _text(bb: String, big := false) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.threaded = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A drag that starts on the words must reach the scroll box: the text takes no input.
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", Game.font_body)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_font_size_override("normal_font_size", Game.ts(15))
	rt.add_theme_font_size_override("bold_font_size", Game.ts(18))
	rt.add_theme_color_override("default_color", Color(Game.C_INK, 0.85))
	rt.text = bb
	return rt


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
