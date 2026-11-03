extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.9).

const NOTE := {"id": "2026-10-29-menu-not-kid-like", "game": "floorball", "date": "2026-10-29", "version": "0.9",
	"words": "The menu is too kid like, make it more serious, no silly font"}

const Lib := preload("res://tests/note_lib.gd")


## The home screen and the quick match, cup and settings screens: no text in the marker-pen hand (Caveat) - every
## label and button in the game's plain sans (Noto) or the scoreboard's figures (Barlow).
func check() -> void:
	Lib.host(tree)
	var silly := []
	var seen := 0
	for path in ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/cup_screen.gd", "res://ui/settings_screen.gd"]:
		if not ResourceLoader.exists(path):
			continue
		Game.show_screen(path)
		await Lib.frames(tree, 3)
		for c in Game.current.find_children("*", "Control", true, false):
			if not (c is Label or c is Button):
				continue
			if not (c as Control).is_visible_in_tree() or String(c.get("text")).strip_edges() == "":
				continue
			seen += 1
			var f: Font = (c as Control).get_theme_font("font")
			if f == Game.font_marker or _is_caveat(f):
				silly.append("%s '%s'" % [path.get_file(), String(c.get("text")).left(24)])
	info("%d labels and buttons on 4 screens; in the marker hand: %d" % [seen, silly.size()])
	expect(seen > 20, "too few labels seen (%d)" % seen)
	expect(silly.is_empty(), "the marker-pen hand on: %s" % [silly])


func _is_caveat(f: Font) -> bool:
	if f == null:
		return false
	if f is FontVariation:
		return _is_caveat((f as FontVariation).base_font)
	return f is FontFile and String((f as FontFile).resource_path).contains("Caveat")
