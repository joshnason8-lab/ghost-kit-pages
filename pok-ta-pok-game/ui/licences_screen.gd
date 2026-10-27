extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Pok Ta Pok Rivals[/b]
Made by Josh Nason. The game's code, its bodies' gear (the faja, the chimali, the yoke), the courts, the ball, the agave, the stands, the hip's slap, the judges' drum, the conch and the menus' music (cane flute, drum, slit drum and rattles) are made for the game, in code.
The rules follow the published research on ulama and the Mesoamerican ballgame (docs/RULES.md in the game's source), above all Manuel Aguilar-Moreno's work on ulama de cadera; the stone court's serve and copal offering follow pelota maya as played in Yucatán today. The classic court is a reconstruction.
The game is not connected with, or endorsed by, any sporting body, federation, tournament or club. Towns appear by their place names only, with nicknames and colours of the game's own design; every player is invented."""

## Every outside work in the game: what it is, who made it, its licence, where it is from. (docs/SOUNDS.md and
## docs/MESHY_BRIEF.md in the game's source list each file.)
const SOURCES := [
	["Motion capture: the run (take 09_02) and the serve's underhand toss (take 124_12)",
		"Carnegie Mellon University Graphics Lab; BVH conversion by Bruce Hahne",
		"Free for research and commercial use. Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.",
		"mocap.cs.cmu.edu"],
	["The players' bodies, the judge, the sixteen townspeople in the stands, the carved ring",
		"Made with Meshy for this game by its maker", "Owned by the game's maker (Meshy's terms for paid plans)", "meshy.ai"],
	["The rain tree, coconut palm, dry grass and grass clump cut-outs", "Made with Meshy by the game's maker, for the maker's games",
		"Owned by the game's maker", "meshy.ai"],
	["Surfaces: dry ground, brown mud, plastered wall, white sandstone blocks, broken wall, sparse grass (512, 1K and 2K)",
		"Poly Haven", "CC0 1.0 (public domain)", "polyhaven.com"],
	["Skies: Qwantani Dusk 2, Qwantani Noon, Kloofendal 48d Partly Cloudy, Kloppenheim 02 (pure sky)",
		"Poly Haven", "CC0 1.0 (public domain)", "polyhaven.com"],
	["The island trees (cut-outs) and the boulder", "Poly Haven", "CC0 1.0 (public domain)", "polyhaven.com"],
	["Impact Sounds, Interface Sounds and RPG Audio packs (the hip's thump, the ball on earth, bare feet, clicks)",
		"Kenney (kenney.nl)", "CC0 1.0 (public domain)", "kenney.nl/assets"],
	["\"Free Crowd Cheering Sounds\" (the crowd's murmur, cheers, applause)", "Gregor Quendel",
		"CC BY 4.0 (creativecommons.org/licenses/by/4.0); softened and cut for the game", "opengameart.org/content/free-crowd-cheering-sounds"],
	["\"Nature Ambient Pack Vol 1\" (summer evening, rainforest canopy, forest night, torch flame)", "JC Sounds",
		"CC BY 4.0 (creativecommons.org/licenses/by/4.0); cut into loops for the game", "opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1"],
	["\"Crickets Ambient Noise - loopable\"", "Wolfgang_ (Ted Kerr)", "CC0 1.0", "opengameart.org/content/crickets-ambient-noise-loopable"],
	["\"Fireplace Sound loop\"", "PagDev", "CC0 1.0", "opengameart.org/content/fireplace-sound-loop"],
	["\"Forest bird sounds\"", "pauliuw", "CC0 1.0", "opengameart.org/content/forest-bird-sounds"],
	["\"Dog barking mono\"", "Brandon Morris (submitted by HaelDB)", "CC0 1.0", "opengameart.org/content/dog-barking-mono"],
	["The crowd's ooh and groan, a clap, the players' efforts", "Synthesised by the maker for Kabaddi Raid",
		"The maker's own", "-"],
]
## Asked about and not used in this game: listed so nobody looks for them.
const NOT_USED := "Not used in this game: Mixamo animations, Pixabay sounds (the whistles), freesound.org sounds. There are no ads or analytics libraries."


const FONTS := """[b]Fonts[/b]
Noto Sans: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic).
Oswald: Copyright 2016 The Oswald Project Authors (https://github.com/googlefonts/OswaldFont), as the font file gives it;
the project's sources are now at https://github.com/vernnobile/OswaldFont.
Both under the SIL Open Font License, Version 1.1:"""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("LICENCES"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	col.add_child(UI.wrap(tr("LICENCES_INTRO"), "MutedLabel", 18))
	_add(col, _text(CREDITS))
	var src_lines := PackedStringArray()
	for src in SOURCES:
		src_lines.append("[b]%s[/b]\n%s. %s. %s" % [src[0], src[1], String(src[2]).trim_suffix("."), src[3]])
	_add(col, _text("[b]Sources[/b]\n\n" + "\n\n".join(src_lines) + "\n\n" + NOT_USED))
	_add(col, _text(FONTS + "\n\n" + _plain(FileAccess.get_file_as_string("res://fonts/OFL.txt").strip_edges())))
	_add(col, _text("[b]Godot Engine[/b]\n" + _plain(Engine.get_license_text().strip_edges())))
	# The engine's own parts, each with its copyright and licence, then the licences' texts.
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in c.parts:
			for who in part.copyright:
				lines.append(_plain(String(who)))
			lines.append("(" + String(part.license) + ")")
		parts.append("[b]%s[/b]\n%s" % [_plain(String(c.name)), "\n".join(lines)])
	_add(col, _text("[b]Parts of the Godot Engine[/b]\n\n" + "\n\n".join(parts)))
	var info: Dictionary = Engine.get_license_info()
	for name in info:
		_add(col, _text("[b]%s[/b]\n%s" % [_plain(String(name)), _plain(String(info[name]).strip_edges())], true))


## A block of text on a dark card, readable over any sky at any graphics level; a drag on it reaches the scroll box.
func _add(col: VBoxContainer, rt: RichTextLabel) -> void:
	var c := UI.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(rt)
	col.add_child(c)


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
