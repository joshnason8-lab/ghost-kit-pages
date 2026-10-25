extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Sepak Takraw Unleashed[/b]
Made by Josh Nason.
The players (a man and a woman), the ball and the app's icon made for the game; the kicks, runs and walks from
motion capture (Mixamo). The jumps in the block, the header spike and the celebration: motion capture data from
mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217. The temple, the stilt houses, the
shophouses, the apartment blocks, the trees, the bleachers, benches, tables and the basketball hoop made for the
game too; the mall's shop fronts, escalators, palms and kiosks, the scoreboards, the beach bar, sun loungers,
lifeguards' tower and longtail boats, the temple's sala, chedis and spirit house, the food carts and scooters made for
the game with Meshy (meshy.ai); skies (at 4K on Medium and High), surfaces (at 2K there; the mall's granite floor too)
and the other venue pieces from Poly Haven (polyhaven.com), CC0. The review's buzzer made in code for the
game; the crowd's drums written for it (tools/audio/make_music.py). The crowd's "ooh"
and groan, the claps and the players' calls from Kabaddi Raid, by the same maker."""

const SOUNDS := """[b]Sounds[/b] (each with its source in docs/SOUNDS.md)
The crowd's murmur and cheer: "Free Crowd Cheering Sounds" by Gregor Quendel (opengameart.org/content/free-crowd-cheering-sounds), CC BY 4.0.
The chatter at the mall and the night market: "Free General Ambience Sounds" (crowd - mall ambience) by Gregor Quendel (www.gregorquendel.com; opengameart.org/content/free-general-ambience-sounds), CC BY-SA 4.0; the game's cut of it (assets/audio/amb_chatter.ogg) is under CC BY-SA 4.0 too.
The sea at the beach, the birds at the temple and the evening at the park: "Nature Ambient Pack Vol 1" by JC Sounds (opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1), CC BY 4.0.
Footsteps on the court: "Footsteps on different surfaces" by congusbongus, from recordings by swuing and ceberation (opengameart.org/content/footsteps-on-different-surfaces), CC BY 3.0.
The slap in a spike: "Punch, slap, n' kick" by CGEffex (opengameart.org/content/punch-slap-n-kick), CC BY 3.0.
Applause (one of three takes): "Applause" by the Blender Foundation (opengameart.org/content/applause), CC BY 3.0.
The referee's whistle: whistle sounds from Pixabay (Pixabay Content License): "Referee whistle" by charlesheffley009, "Referee whistle / coach whistle / sports whistle" by framptones, "Metal whistle" and "Referee whistle blow, gymnasium" by freesound_community.
Under CC0, with thanks: the ball's knocks from "Wood and Metal Sound Effects: Volume 2" by Ogrebane; impacts, the net's rustle and the click from Kenney (kenney.nl); applause by eXpl0it3r; footsteps on sand by Fantozzi; the menu music, "Kingdom of a Million Elephants under a White Parasol" by Spring Spring (Julie Damsgaard)."""

const FONTS := """[b]Fonts[/b]
Noto Sans, Noto Sans Thai, Lao, Myanmar, Khmer, Devanagari, JP, KR and SC: Copyright The Noto Project Authors (https://github.com/notofonts).
Teko: Copyright 2023 The Teko Project Authors (https://www.github.com/googlefonts/teko).
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
	rt.add_theme_color_override("default_color", Color(Game.C_INK, 0.85))
	rt.text = bb
	return rt


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
