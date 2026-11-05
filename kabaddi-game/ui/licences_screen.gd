extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Kabaddi Raid[/b]
Made by Josh Nason.
Players, referees and the crowd modelled with Meshy; movement from Mixamo (Adobe), the CMU Graphics Lab Motion Capture Database and match footage.
Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.
On Medium and High the players and officials are drawn with the World Stage Games shared foundation (the same maker): each player's own Meshy model on its rig, walking, jogging, turning, standing and celebrating with motion capture from the MoCap Online Mobility pack (MoCap Online, mocaponline.com) and Reallusion ActorCore (actorcore.reallusion.com), licensed for the game; that animation is part of the game only, not to be extracted. The replays use the foundation's WsgReplay.
Rain trees, coconut palms, dry grass, the scorers' table, the apartment blocks, the village temple and the Jagannath temple's tower modelled with Meshy for the game. The sea's ripples were made for the game.
From Poly Haven (polyhaven.com), all CC0:
Skies: Kloppenheim 07, Qwantani Dusk 2 and Qwantani Sunset (Pure Sky) by Greg Zaal and Jarod Guest; Overcast Soil (Pure Sky) by Jarod Guest and Sergej Majboroda.
Ground and walls: Brown Mud, Brown Mud Dry, Coast Sand 01, Red Dirt Mud 01 and Thatch Roof Angled by Rob Tuytel (the thatch with Dimitrios Savva); Damp Beach Sand by Dimitrios Savva; Clay Plaster and Clay Roof Tiles by Amal Kumar; Concrete Floor by eye-candy.xyz; Grass Ground by Charlotte Baglioni.
Models: Plastic Monobloc Chair 01 by Kuutti Siitonen; Folding Wooden Stool by Ulan Cabanilla; Island Tree 01 and 02 by Rob Tuytel and Rico Cilliers.
Music, from freesound.org, all CC0: "Tanpura 10" by sankalp and "Tabla Rhythm Bayan Tala Kherwa" by afleetingspeck (the menus), "tabla 5to4 85bpm -loop" by MieliTietty (the drums under a match). Slowed and mixed for the game."""

# Every recorded sound, with where it is from and its licence (docs/SOUNDS.md has each file).
const SOUNDS := """[b]Sounds[/b]
The crowd (its murmur, cheers and roar): "Free Crowd Cheering Sounds" by Gregor Quendel (opengameart.org/content/free-crowd-cheering-sounds), licensed CC BY 4.0 (creativecommons.org/licenses/by/4.0/). Cut, made mono and looped for the game.
Footsteps on the mats and the earth, bodies hitting the mat, touches and the menus' click: "Impact Sounds" and "Interface Sounds" by Kenney (kenney.nl), CC0.
Footsteps on the sand: "Fantozzi's Footsteps (Grass/Sand & Stone)" by Fantozzi (opengameart.org), CC0.
Applause: "Applause in a large hall or church" by eXpl0it3r (opengameart.org), CC0.
The grounds: "AMB Rain Loop 1" by Kresiek The Furry, "Beach Ocean Waves" by jasinski, "Park ambiences" by Thimras and "Crickets Ambient Noise - loopable" by Wolfgang_ (all opengameart.org), CC0.
Whistle sounds from Pixabay (Pixabay Content License): "Referee whistle" by charlesheffley009, "Referee whistle / coach whistle / sports whistle" by framptones, "Metal whistle" and "Referee whistle blow, gymnasium" by freesound_community. Trimmed and loudness-matched for the game.
From freesound.org, all CC0: the crowd's gasp and disappointed sigh ("CRWDReac" by ShangusBurger), and the players' grunts, pain sounds and breaths ("Male Grunts" by Kodack, "Grunting" by randbsoundbites, "Voice_AdultMale_PainGrunts_09" by MrFossy, "male_hurt9" by micahlg, "Short Exertion" by SuddenDice, "Exhale_10115a" by otherthings). Cut and made mono for the game.
The raider's "kabaddi" and the crowd's chant: spoken by the Piper text-to-speech voice "venkatesh" (Telugu; rhasspy/piper-voices, trained by PravalX on AI4Bharat's IndicVoices-R, CC BY 4.0 creativecommons.org/licenses/by/4.0/). Cut and mixed for the game.
The dhol and the players' shouts were made for the game."""

const FONTS := """[b]Fonts[/b]
Noto Sans: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/latin-greek-cyrillic).
Noto Sans Devanagari, Tamil, Telugu, Kannada and Gurmukhi: Copyright 2022 The Noto Project Authors (https://github.com/notofonts/devanagari, /tamil, /telugu, /kannada, /gurmukhi).
Noto Sans Bengali: Copyright 2025 The Noto Project Authors (https://github.com/notofonts/bengali).
Teko: Copyright 2023 The Teko Project Authors (https://www.github.com/googlefonts/teko).
All under the SIL Open Font License, Version 1.1:"""


func setup(_args: Dictionary) -> void:
	pass


## The texts still to add: one a frame once the page is up, so it opens at once instead of freezing while
## every licence is laid out.
const CHUNK := 1500
var _todo: Array[String] = []
var _col: VBoxContainer


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("LICENCES"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(_col))
	_col.add_child(UI.wrap(tr("LICENCES_INTRO"), "MutedLabel", 18))
	_col.add_child(_text(CREDITS))
	_col.add_child(_text(SOUNDS))
	_queue(FONTS + "\n\n" + _plain(FileAccess.get_file_as_string("res://fonts/OFL.txt").strip_edges()))
	_queue("[b]Godot Engine[/b]\n" + _plain(Engine.get_license_text().strip_edges()))
	# The engine's own parts, each with its copyright and licence, then the licences' texts.
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in c.parts:
			for who in part.copyright:
				lines.append(_plain(String(who)))
			lines.append("(" + String(part.license) + ")")
		parts.append("[b]%s[/b]\n%s" % [_plain(String(c.name)), "\n".join(lines)])
	_queue("[b]Parts of the Godot Engine[/b]\n\n" + "\n\n".join(parts))
	var info: Dictionary = Engine.get_license_info()
	for name in info:
		_queue("[b]%s[/b]\n%s" % [_plain(String(name)), _plain(String(info[name]).strip_edges())])


## A long text goes on as several labels of a few paragraphs each, so no one frame lays out a whole licence.
func _queue(text: String) -> void:
	var chunk := ""
	for para in text.split("\n\n"):
		if chunk != "" and chunk.length() + para.length() > CHUNK:
			_todo.append(chunk)
			chunk = ""
		chunk = para if chunk == "" else chunk + "\n\n" + para
	if chunk != "":
		_todo.append(chunk)


func _process(_delta: float) -> void:
	if _todo.is_empty():
		set_process(false)
		return
	_col.add_child(_text(_todo.pop_front()))


## Every text is on the page.
func built() -> bool:
	return _todo.is_empty()


func _text(bb: String) -> RichTextLabel:
	return UI.rich_text(bb)


## Text shown as it is: square brackets in a licence are not formatting.
static func _plain(s: String) -> String:
	return s.replace("[", "[lb]")
