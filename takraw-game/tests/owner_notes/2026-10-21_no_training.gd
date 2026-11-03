extends TakrawNote
## The owner, 2026-10-21: "No training section necessary."

const NOTE := {"id": "2026-10-21-no-training", "game": "sepak-takraw", "date": "2026-10-21", "version": "0.1.0",
	"words": "No training section necessary."}


## The home screen, in every language, has no training: no button or entry for it.
func check() -> void:
	Game.reset_settings_for_tests()
	var holder := Node.new()
	tree.root.add_child(holder)
	_made.append(holder)
	Game.main = holder
	for pair in Game.LANGUAGES:
		TranslationServer.set_locale(pair[0])
		var menu := Game.show_screen("res://ui/main_menu.gd")
		await frame()
		var words := []
		for n in menu.find_children("*", "", true, false):
			if n is Button:
				words.append((n as Button).text)
			elif n is Label:
				words.append((n as Label).text)
		var all := " ".join(words).to_lower()
		var training := TranslationServer.translate("TRAINING").to_lower()
		expect(not all.contains("training") and not all.contains("practice") and (training == "training" or not all.contains(training)),
			"%s: the home screen has a training entry" % pair[0])
	TranslationServer.set_locale("en")
	info("the home screen in %d languages: no training" % Game.LANGUAGES.size())
	await clean()
