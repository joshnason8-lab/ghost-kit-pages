extends WsgOwnerNote
## The owner, 2026-10-22, on 0.2.x (the home screen's left goal third, halved into the two competitions).

const NOTE := {"id": "2026-10-22-menu-line-white", "game": "netball", "date": "2026-10-22", "version": "0.2.x",
	"words": "On Menu make the black line white between nations cup and club season"}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const SHAPES := [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(2400, 1080), Vector2i(1024, 768)]


## The home screen at four screen shapes (16:9, 20:9 and a large 20:9 phone, 4:3), in English and the language with
## the longest titles: the Nations Cup and Club Season halves (and How to Play and Watch AI, halved the same way) meet
## with no gap between them - no dark background shows through as a line - and each draws the court's white line along
## the edge they share (CourtThird's own line, white). In a window (not headless) the pixels themselves are read: down
## the seam, the brightest row is white (each channel 0.75 or more, no bluer than 0.2) and no row there is darker than the court's blue.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var win := DisplayServer.get_name() != "headless"
	var keep := tree.root.size
	for lang in ["en", "zu"]:
		Game.settings.language = lang
		TranslationServer.set_locale(lang)
		for shape: Vector2i in SHAPES:
			if win:
				DisplayServer.window_set_size(shape)
			tree.root.size = shape
			Game._size_theme()
			Game.goto_menu()
			for i in 6:
				await frame()
			var menu: Node = Game.current
			var halves := {}
			for ct in menu.find_children("*", "CourtThird", true, false):
				halves[(ct as CourtThird).kind] = ct
			for pair in [["goal_left_top", "goal_left_bottom", "Nations Cup / Club Season"], ["goal_right_top", "goal_right_bottom", "How to Play / Watch AI"]]:
				var top: CourtThird = halves.get(pair[0])
				var bot: CourtThird = halves.get(pair[1])
				var what := "%s, %dx%d, %s" % [lang, shape.x, shape.y, pair[2]]
				if not expect(top != null and bot != null, "%s: the halves are not on the home screen" % what):
					continue
				var a := top.get_global_rect()
				var b := bot.get_global_rect()
				var gap := b.position.y - a.end.y
				info("%s: the halves meet with %.1f px between them (negative: overlapping)" % [what, gap])
				expect(gap <= 0.0, "%s: a %.1f px gap between the halves shows the dark background as a line" % [what, gap])
				expect(absf(a.position.x - b.position.x) < 1.0 and absf(a.size.x - b.size.x) < 1.0, "%s: the halves are not one above the other" % what)
				if win and pair[0] == "goal_left_top":
					for i in 90:
						await frame()    # (the loading screen's fade over the home screen gone)
					var img := tree.root.get_texture().get_image()
					# (The screen's pixels: the home screen is laid out at 720 lines and stretched to the window.)
					var k := Vector2(img.get_size()) / tree.root.get_visible_rect().size
					var at := (a.position + Vector2(a.size.x * 0.75, a.size.y)) * k
					var x := int(at.x)
					var y0 := int(at.y) - 8
					var brightest := Color.BLACK
					var darkest := 3.0
					for y in range(y0, y0 + 16):
						var c := img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))
						if c.r + c.g + c.b > brightest.r + brightest.g + brightest.b:
							brightest = c
						darkest = minf(darkest, c.r + c.g + c.b)
					var court := Color(Game.C_COURT, 1.0)
					info("%s: down the seam the brightest pixel %s, the darkest %.2f (the court %.2f)" % [what, brightest, darkest, court.r + court.g + court.b])
					expect(brightest.r >= 0.75 and brightest.g >= 0.75 and brightest.b - brightest.r <= 0.2, "%s: the line between them is not white (%s)" % [what, brightest])
					expect(darkest >= (court.r + court.g + court.b) * 0.7, "%s: a dark line between them (%.2f)" % [what, darkest])
	# The line itself: drawn white (CourtThird draws the court's lines in white at 85%).
	var src := FileAccess.get_file_as_string("res://ui/court_third.gd")
	expect(src.contains("var line := Color(1, 1, 1"), "CourtThird no longer draws its lines white")
	tree.root.size = keep
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	if not win:
		info("(headless: the seam measured by layout; run in a window to read its pixels)")
	await Harness.done(h)
