extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.8.2).

const NOTE := {"id": "2026-10-29-arena-text-language", "game": "floorball", "date": "2026-10-29", "version": "0.8.2",
	"words": "Make sure any text around the arena's match the phones language."}


## In every language the game speaks, the boards' slogans and the floor's words (Signage.text) are that language's
## own: none left in English where the language has its own words, and each language's are different from English's.
func check() -> void:
	var keep := TranslationServer.get_locale()
	var keys := []
	for b: Array in Signage.BOARDS:
		var k := String(b[2])
		if k != "" and not k.begins_with("#"):
			keys.append(k)
	TranslationServer.set_locale("en")
	var en := []
	for k in keys:
		en.append(Signage.text(k))
	var same := []
	for lang in ["sv", "fi", "cs", "sk", "de", "nb", "da", "lv", "et", "pl", "fr", "it", "ja", "th"]:
		TranslationServer.set_locale(lang)
		var words := []
		for k in keys:
			words.append(Signage.text(k))
		if words == en:
			same.append(lang)
	TranslationServer.set_locale(keep)
	info("English boards: %s" % [en])
	expect(same.is_empty(), "the boards stay in English in %s" % [same])
