extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Netball Unleashed[/b]
Made by Josh Nason.
The players are Josh Nason's own 3D model, made with Meshy (meshy.ai) and rigged and animated with Mixamo (Adobe,
mixamo.com): its Walking and Running clips and the Fast_Run sprint, used under Mixamo's terms. Umpires, venues, crowd, ball and flags made in code for the game (the
crowd's 32 people on Medium and High drawn for it by tools/art/make_crowd.py); the
menu music and the shoe squeaks written for it (tools/audio). The crowd's ooh and groan from Kabaddi
Raid, by the same maker.
Venue models by Josh Nason, made with Meshy (meshy.ai): the arena's courtside stands, gym and park benches, oak trees, grass, terraced houses
and the street hoop. From Poly Haven (polyhaven.com), CC0: the skies, floor and wall textures, jacaranda and
broadleaf trees, painted benches, hall lights, clock, fire alarm, wet floor sign and street lamps.
Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.
(The side-step and the landing: clips 102_27 and 16_08, in Bruce Hahne's BVH conversion.)
On Medium and High the players, umpires and reserves are drawn with the World Stage Games shared foundation (the
same maker): the owner's player model on its rig, walking, running, sprinting, turning, starting and stopping with
motion capture from the MoCap Online Mobility pack (MoCap Online, mocaponline.com) and Reallusion ActorCore
(actorcore.reallusion.com), licensed for the game; that animation is part of the game only, not to be extracted.
The replays use the foundation's WsgReplay."""

const SOUNDS := """[b]Sounds[/b] (the full list: docs/SOUNDS.md)
Whistle sounds from Pixabay (pixabay.com, Pixabay Content License): charlesheffley009, "Referee whistle";
framptones, "Referee whistle / coach whistle / sports whistle"; freesound_community, "Metal whistle" and "Referee
whistle blow, gymnasium".
Kenney (kenney.nl), CC0: Impact Sounds, UI Audio and RPG Audio: the catches, the bounces, the ring, the net, the
clicks and the footsteps on asphalt.
Gregor Quendel, "Free Crowd Cheering Sounds" (opengameart.org/content/free-crowd-cheering-sounds), CC-BY 4.0: the
cheers and the arena's crowd.
Gregor Quendel, "Free General Ambience Sounds" (opengameart.org/content/free-general-ambience-sounds), CC-BY-SA 4.0:
the arena's applause, the hall's crowd and the park's birds, traffic and people; adapted (cut, filtered, mixed,
looped), the adapted sounds also CC-BY-SA 4.0 (creativecommons.org/licenses/by-sa/4.0).
congusbongus, "Footsteps on different surfaces" (opengameart.org/content/footsteps-on-different-surfaces), from
recordings by swuing and ceberation (freesound.org), CC-BY 3.0: the footsteps on a hall floor.
eXpl0it3r, "Applause in a large hall or church" (opengameart.org), CC0: the hall's applause.
qubodup, "Well Done" (opengameart.org), CC0: the park's applause.
leezh, "Applause" (opengameart.org/content/applause), cut from Yo Frankie! by the Blender Foundation, CC-BY 3.0
(creativecommons.org/licenses/by/3.0): one of the arena's applause takes on Medium and High."""

const FONTS := """[b]Fonts[/b]
Noto Sans, Noto Sans Sinhala, Noto Sans Tamil and Noto Sans SC: Copyright The Noto Project Authors (https://github.com/notofonts).
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
	col.add_child(_text(CREDITS))
	col.add_child(_text(SOUNDS))
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


func _text(bb: String, big := false) -> RichTextLabel:
	return text_block(bb, big)


## A block of formatted text for the About pages (Licences, Help, Privacy), its height its own, inside a page's
## scroll box. Licence texts are long: a big one is laid out off the main thread.
static func text_block(bb: String, big := false) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	# (Not in headless runs: freeing a threaded label mid-layout, as the screen tests do, can crash the engine.)
	rt.threaded = big and DisplayServer.get_name() != "headless"
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


## Text written wrapped in the code, as paragraphs: a paragraph (blank lines between) is one flowing line, its bold
## heading line kept on its own.
static func flow(s: String) -> String:
	var out := PackedStringArray()
	for para in s.split("\n\n"):
		var lines := para.split("\n")
		var head := ""
		if lines.size() > 1 and lines[0].begins_with("[b]") and lines[0].ends_with("[/b]"):
			head = lines[0] + "\n"
			lines.remove_at(0)
		out.append(head + " ".join(lines))
	return "\n\n".join(out)


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
