extends WsgOwnerNote
## The owner (relayed by the lead), 2026-10-27, on 0.8.0-beta: Settings' Licences, Help and Privacy links went to web
## pages that returned 404.

const NOTE := {"id": "2026-10-27-about-pages-404", "game": "netball", "date": "2026-10-27", "version": "0.8.0-beta",
	"words": "Licenses/Help/Privacy links returned 404"}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Each of the three from Settings' own button, in four of the game's languages: it opens in the game (no web page,
## so nothing to 404, offline or on a branch GitHub Pages does not serve), its own screen, with its words in it (over
## 600 characters; the credits, the controls, the privacy facts and a contact), and it scrolls (test_runner
## _about_pages, once a language); and no script in the game opens a web page at all (OS.shell_open).
func check() -> void:
	var h: Node = await Harness.make(tree)
	# (Four languages spread across the list, the first English: every language costs two minutes over all 19.)
	var langs := []
	for i in [0, 6, 12, Game.LANGUAGES.size() - 1]:
		langs.append(Game.LANGUAGES[i])
	for pair in langs:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		var before: int = h.failed.size()
		await h._about_pages()
		for i in range(before, h.failed.size()):
			h.failed[i] = "%s: %s" % [pair[0], h.failed[i]]
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	info("%d checks in %s" % [h.checks, ", ".join(langs.map(func(p): return p[0]))])
	for f in h.failed:
		fail(String(f))
	await Harness.done(h)
	var links := []
	for d in ["res://ui", "res://game", "res://autoload"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and FileAccess.get_file_as_string(d.path_join(f)).contains("shell_open("):
				links.append(d.path_join(f))
	info("scripts that open a web page: %s" % [links])
	expect(links.is_empty(), "a screen still opens a web page (%s): it 404s wherever the page is not served" % [links])
