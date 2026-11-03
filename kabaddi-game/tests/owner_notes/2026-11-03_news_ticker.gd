extends WsgOwnerNote
const NOTE := {"id": "2026-11-03-news-ticker", "game": "kabaddi", "date": "2026-11-03", "version": "0.14.1-beta",
	"words": "Get rid of the scrolling news section on bottom."}
const U := preload("res://tests/owner_note_util.gd")


func check() -> void:
	U.host(tree)
	var had = Game.season
	if Game.get_season() == null:
		Game.season = Season.create("MUM")   # a season going (in memory: not saved), as the hub shows it
	var found := 0
	for screen in ["res://ui/main_menu.gd", "res://ui/season_hub.gd"]:
		if not ResourceLoader.exists(screen):
			continue
		Game.show_screen(screen)
		await U.frames(tree, 3)
		var n: int = Game.current.find_children("*", "NewsTicker", true, false).size()
		info("%s: %d news tickers" % [screen.get_file(), n])
		found += n
	expect(found == 0, "a scrolling news ticker is back (%d)" % found)
	Game.season = had
	Game.goto_menu()
