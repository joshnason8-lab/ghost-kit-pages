class_name Plural
extends RefCounted
## Plural forms by the Unicode CLDR rules: English has one and other; Irish one (1), two (2), few (3-6), many (7-10)
## and other (the rest). A string with a count has a key for each form its language uses (KEY_one, KEY_two ...);
## word(key, n) picks the right one, falling back to KEY_other.


static func category(lang: String, n: int) -> String:
	match lang.left(2):
		"ga":
			if n == 1:
				return "one"
			if n == 2:
				return "two"
			if n >= 3 and n <= 6:
				return "few"
			if n >= 7 and n <= 10:
				return "many"
			return "other"
	return "one" if n == 1 else "other"


static func word(key: String, n: int) -> String:
	var cat := category(TranslationServer.get_locale(), n)
	var k := "%s_%s" % [key, cat]
	var t := TranslationServer.translate(k)
	if t == k or t == "":
		t = TranslationServer.translate(key + "_other")
	return t.format({"n": n})
