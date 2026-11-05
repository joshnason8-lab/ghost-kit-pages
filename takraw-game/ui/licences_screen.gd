extends Control
## What the game is made with, and under what licences: the credits, the fonts' licence, the Godot Engine's licence
## and those of the engine's own parts (Engine.get_copyright_info), which their licences ask to be shown. The legal
## texts are in English, as they are written.

const CREDITS := """[b]Sepak Takraw Unleashed[/b]
Made by Josh Nason.
The players (a man and a woman), the ball and the app's icon made for the game; the kicks, runs and walks from
motion capture (Mixamo). The jumps in the block, the header spike and the celebration: motion capture data from
mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217. The stilt houses, the
shophouses, the apartment blocks, the trees, the bleachers, benches, tables and the basketball hoop made for the
game too; the mall's shop fronts, escalators, palms and kiosks, the scoreboards, the beach bar, sun loungers,
lifeguards' tower and longtail boats, the food carts and scooters made for
the game with Meshy (meshy.ai); skies (at 4K on Medium and High), surfaces (at 2K there; the mall's granite floor too)
and the other venue pieces from Poly Haven (polyhaven.com), CC0. The review's buzzer made in code for the
game; the crowd's drums written for it (tools/audio/make_music.py). The crowd's "ooh"
and groan, the claps and the players' calls from Kabaddi Raid, by the same maker.
On Medium and High the players, the officials and the substitutes are drawn with the World Stage Games shared
foundation (the same maker): the man and the woman on its rig, every kick, header, block, toss and celebration still
the game's own, and the walks between points, the officials' standing and stepping with motion capture from the
MoCap Online Mobility pack (MoCap Online, mocaponline.com) and Reallusion ActorCore (actorcore.reallusion.com),
licensed for the game; that animation is part of the game only, not to be extracted. The replays use the
foundation's WsgReplay."""

const SOUNDS := """[b]Sounds[/b] (each with its source in docs/SOUNDS.md)
The crowd's murmur and cheer: "Free Crowd Cheering Sounds" by Gregor Quendel (opengameart.org/content/free-crowd-cheering-sounds), CC BY 4.0.
The chatter at the mall: "Free General Ambience Sounds" (crowd - mall ambience) by Gregor Quendel (www.gregorquendel.com; opengameart.org/content/free-general-ambience-sounds), CC BY-SA 4.0; the game's cut of it (assets/audio/amb_chatter.ogg) is under CC BY-SA 4.0 too.
The sea at the beach and the evening at the park: "Nature Ambient Pack Vol 1" by JC Sounds (opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1), CC BY 4.0.
Footsteps on the court: "Footsteps on different surfaces" by congusbongus, from recordings by swuing and ceberation (opengameart.org/content/footsteps-on-different-surfaces), CC BY 3.0.
Applause (one of three takes): "Applause" by the Blender Foundation (opengameart.org/content/applause), CC BY 3.0.
The referee's whistle: whistle sounds from Pixabay (Pixabay Content License): "Referee whistle" by charlesheffley009, "Referee whistle / coach whistle / sports whistle" by framptones, "Metal whistle" and "Referee whistle blow, gymnasium" by freesound_community.
The ball's kicks, touches and bounces: sound effects from Mixkit (mixkit.co), Mixkit Sound Effects Free License.
Under CC0, with thanks: impacts (the kicks' hollow knock among them), the net's rustle and the click from Kenney (kenney.nl); from opengameart.org, applause by eXpl0it3r, footsteps on sand by Fantozzi, and the menu music, "Kingdom of a Million Elephants under a White Parasol" by Spring Spring (Julie Damsgaard)."""

const FONTS := """[b]Fonts[/b]
Noto Sans, Noto Sans Thai, Lao, Myanmar, Khmer, Devanagari, JP, KR and SC: Copyright The Noto Project Authors (https://github.com/notofonts).
Teko: Copyright 2023 The Teko Project Authors (https://www.github.com/googlefonts/teko).
All under the SIL Open Font License, Version 1.1:"""


var _back := Callable()   # back to Settings (it is opened over them)
var _col: VBoxContainer
var _todo: Array = []     # the texts still to add, a piece a frame


func setup(args: Dictionary) -> void:
	_back = args.get("back", Callable())


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("LICENCES"), _back if _back.is_valid() else func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(_col))
	_col.add_child(UI.wrap(tr("LICENCES_INTRO"), "MutedLabel", 18))
	var texts := [CREDITS, SOUNDS, FONTS + "\n\n" + _plain(FileAccess.get_file_as_string("res://fonts/OFL.txt").strip_edges()),
		"[b]Godot Engine[/b]\n" + _plain(Engine.get_license_text().strip_edges())]
	# The engine's own parts, each with its copyright and licence, then the licences' texts.
	var parts := PackedStringArray()
	for c in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in c.parts:
			for who in part.copyright:
				lines.append(_plain(String(who)))
			lines.append("(" + String(part.license) + ")")
		parts.append("[b]%s[/b]\n%s" % [_plain(String(c.name)), "\n".join(lines)])
	texts.append("[b]Parts of the Godot Engine[/b]\n\n" + "\n\n".join(parts))
	var info: Dictionary = Engine.get_license_info()
	for name in info:
		texts.append("[b]%s[/b]\n%s" % [_plain(String(name)), _plain(String(info[name]).strip_edges())])
	# The texts run to some 80,000 characters. Laid out on a worker thread (RichTextLabel.threaded), Godot 4.7 can
	# crash when the page is drawn or freed mid-layout (CI did); all at once, the page would open late. So they are cut
	# at their paragraphs into pieces of about 1,500 characters, the first now and one more a frame (built() says when
	# all are in): the page opens at once, and it is complete by the time a finger has scrolled to the end.
	for t in texts:
		_todo.append_array(_pieces(t))
	_add_next()


func _process(_d: float) -> void:
	_add_next()


func _add_next() -> void:
	if not _todo.is_empty():
		_col.add_child(_text(String(_todo.pop_front())))


## Whether every piece of the licences is on the page.
func built() -> bool:
	return _todo.is_empty()


## A text cut at its paragraphs into pieces of about 1,500 characters (a longer paragraph is a piece of its own).
static func _pieces(t: String) -> Array:
	var out := []
	var cur := ""
	for para in t.split("\n\n"):
		if cur != "" and cur.length() + para.length() > 1500:
			out.append(cur)
			cur = ""
		cur = para if cur == "" else cur + "\n\n" + para
	if cur != "":
		out.append(cur)
	return out


func _text(bb: String) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
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
