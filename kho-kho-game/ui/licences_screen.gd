class_name LicencesScreen
extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Kho Kho Rush[/b]
Made by Josh Nason. Every team's players are invented. No real player, club, league, competition or federation is
  named.

[b]The players' movement[/b]
The players and officials are the maker's own athlete model, moved by animations from Mixamo (Adobe), used under
  Mixamo's terms and fitted to the model for the game.
Their dodge and their standing at ease: the CMU Graphics Lab Motion Capture Database (clips 127_11 and 77_02).
  Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

[b]The grounds[/b]
Poly Haven (polyhaven.com), CC0: the skies; the ground, plaster, roof-tile, thatch and rubber-tile surfaces; the
  plastic chairs, painted benches and hall lights; the tropical trees.
The maker's own models, made with Meshy (meshy.ai) for these games: the rain trees, coconut palms, grass, scorers'
  table, apartment blocks and village temple.
Everything else round the grounds (barricades, tents, stages, stands, flags, banners) and the crowd, drawn from the
  players' model: made in code for the game.

[b]Sounds[/b]
Kenney (kenney.nl), CC0: footsteps, dive landings and the menus' click (Impact Sounds, UI Audio).
OpenGameArt (opengameart.org):
- The kho's slap: "Punch, slap, n' kick", by CGEffex (freesound 98341), cut by congusbongus. CC-BY 3.0.
- The crowd's murmur and cheers: "Free Crowd Cheering Sounds", by Gregor Quendel. CC-BY 4.0.
- Applause: "Applause in a large hall or church", by eXpl0it3r. CC0.
- Crickets: "Crickets Ambient Noise - loopable", by Wolfgang_. CC0.
- Birds: "Park ambiences", by Thimras. CC0.
Whistle sounds from Pixabay (pixabay.com), Pixabay Content License: the referee whistles, by charlesheffley009
  ("Referee whistle"), framptones ("Referee whistle / coach whistle / sports whistle") and freesound_community ("Metal
  whistle", "Referee whistle blow, gymnasium").
Written for the game: the menu music and the crowd's drums. From Kabaddi Raid, by the same maker: some crowd
  reactions and the players' voices.
Each sound, with its source, in docs/SOUNDS.md."""

const FONTS := """[b]Fonts[/b]
Noto Sans, Noto Sans Devanagari, Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam and Sinhala:
Copyright The Noto Project Authors (https://github.com/notofonts).
Baloo 2: Copyright 2019 The Baloo 2 Project Authors (https://github.com/EkType/Baloo2).
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
	col.add_child(text_block(reflow(CREDITS), false, 17))
	col.add_child(text_block(FONTS + "\n\n" + _plain(FileAccess.get_file_as_string("res://fonts/OFL.txt").strip_edges())))
	col.add_child(text_block("[b]Godot Engine[/b]\n" + _plain(Engine.get_license_text().strip_edges())))
	# The engine's own parts, each with its copyright and licence, then the licences' texts.
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in c.parts:
			for who in part.copyright:
				lines.append(_plain(String(who)))
			lines.append("(" + String(part.license) + ")")
		parts.append("[b]%s[/b]\n%s" % [_plain(String(c.name)), "\n".join(lines)])
	col.add_child(text_block("[b]Parts of the Godot Engine[/b]\n\n" + "\n\n".join(parts)))
	var info: Dictionary = Engine.get_license_info()
	for name in info:
		col.add_child(text_block("[b]%s[/b]\n%s" % [_plain(String(name)), _plain(String(info[name]).strip_edges())], true))


## A block of text (BBCode), as the licences and the privacy policy are shown. Licence texts are long, but are laid
## out on the main thread: the threaded layout crashed (see below).
static func text_block(bb: String, big := false, size := 15) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.threaded = false   # threaded layout crashed Godot 4.7.2 (fit_audit, 21 Oct): laid out here instead
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A drag that starts on the words must reach the scroll box: the text takes no input.
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", Game.font_body)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_font_size_override("normal_font_size", Game.ts(size))
	rt.add_theme_font_size_override("bold_font_size", Game.ts(size + 3))
	rt.add_theme_color_override("default_color", Color(Game.C_INK, 0.85))
	rt.text = bb
	return rt


## Text written wrapped in the source (CREDITS, the privacy policy), so it wraps to the screen: a line that begins
## with two spaces carries on the one before it; every other line break stays.
static func reflow(s: String) -> String:
	return s.replace("\n  ", " ")


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
