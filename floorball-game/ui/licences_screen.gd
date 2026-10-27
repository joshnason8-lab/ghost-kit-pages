extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Floorball Unleashed[/b]
Made by Josh Nason. The rink, the boards, the goals, the halls' walls, ceilings and basketball boards, the ball, its
floor decals and the menu music were made for the game. Floorball's rules are the international Rules of the Game,
as the game understands them; the game is not made or endorsed by any federation, league or team. The teams' and
players' names are invented.

[b]3D models[/b]
- Players, goalkeepers, referees and the stick; the sports hall's aluminium stand, the gym benches and the Nordic fire
alarm points: the maker's own models, made with Meshy (meshy.ai). The players are rigged with Mixamo's bone names;
no Mixamo model or animation is used.
- The halls' fluorescent lights ("Mounted Fluorescent Lights", Ulan Cabanilla), hanging lamps ("Hanging Industrial
Lamp", Kuutti Siitonen), wall clock ("Wall Clock", PierreB3D) and wet floor sign ("Wet Floor Sign 01", Fran
Calvente): Poly Haven (polyhaven.com), CC0.

[b]Surfaces[/b]
- Rubber floor ("Rubber Tiles", Amal Kumar), wood floor ("Wood Floor", Dimitrios Savva), block wall ("Concrete Block
Wall", Charlotte Baglioni), birch slats ("White Maple Veneer", Jenelle van Heerden): Poly Haven (polyhaven.com), CC0.

[b]Motion capture[/b]
- How the players and referees walk and run: motion capture data from mocap.cs.cmu.edu. The database was created
with funding from NSF EIA-0196217. (Clips 35_01, 35_17 and 16_55.)

[b]Sounds[/b]
- The referees' whistles: from Pixabay, under the Pixabay Content License: "Referee whistle" by charlesheffley009,
"Referee whistle / coach whistle / sports whistle" by framptones, "Metal whistle" and "Referee whistle blow,
gymnasium" by freesound_community; trimmed and levelled.
- The crowd, its cheers and its chant: "Free Crowd Cheering Sounds" by Gregor Quendel (opengameart.org,
gregorquendel.com), CC BY 4.0; cut and levelled.
- The applause: "Applause in a large hall or church" by eXpl0it3r (opengameart.org), CC0.
- Footsteps and the menus' click: Kenney (kenney.nl), "Impact Sounds" and "Interface Sounds", CC0.
- The crowd's "ooh" and groan, and the players' calls: from Kabaddi Raid, by the same maker.
- The ball, the boards, the posts, the net, stick on stick, the horn and the drum: made for the game.
"""

const FONTS := """[b]Fonts[/b]
Noto Sans, Noto Sans Thai and Noto Sans JP: Copyright The Noto Project Authors (https://github.com/notofonts).
Caveat: Copyright 2014 The Caveat Project Authors (https://github.com/googlefonts/caveat).
Barlow Condensed: Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow).
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
	col.add_child(UI.rich(UI.flow(CREDITS)))
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


## Licence texts are long: a big one is laid out off the main thread.
func _text(bb: String, big := false) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.threaded = big
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A drag that starts on the words must reach the scroll box: the text takes no input.
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", Game.font_body)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_font_size_override("normal_font_size", Game.ts(15))
	rt.add_theme_font_size_override("bold_font_size", Game.ts(18))
	rt.add_theme_color_override("default_color", Color(Game.C_INK, 0.9))
	rt.text = bb
	return rt


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
