class_name Plural
extends RefCounted
## Plural forms by the Unicode CLDR rules: every language the game ships has one and other; French and Brazilian
## Portuguese count 0 as one too. A string with a count has a key for each form its language uses (KEY_one, KEY_two ...);
## word(key, n) picks the right one, falling back to KEY_other.


static func category(lang: String, n: int) -> String:
	match lang.left(2):
		"fr", "pt":
			# French and Brazilian Portuguese count 0 and 1 as one (CLDR).
			return "one" if n == 0 or n == 1 else "other"
	return "one" if n == 1 else "other"


static func word(key: String, n: int) -> String:
	var cat := category(TranslationServer.get_locale(), n)
	var k := "%s_%s" % [key, cat]
	var t := TranslationServer.translate(k)
	if t == k or t == "":
		t = TranslationServer.translate(key + "_other")
	return t.format({"n": n})
