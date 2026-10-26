extends Node
## Every screen in every language at a phone's shape, read rather than looked at: text cut short (an ellipsis, a
## clipped edge, lines held back), a word broken in the middle, text off the screen or out of the box that clips it,
## text over other text, a translation key or a placeholder shown raw, and characters no font in the chain can draw.
## Also the match buttons' labels against their circles. Headless, so it is quick:
##   godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- OUT.jsonl [langs] [WxH,...] [parts]
## langs: en,af,zu,... (all by default). WxH: the phone's screen in pixels (layouts depend only on its shape: 16:9,
## 19.5:9 (a Galaxy A16), 20:9 with a camera cut-out, and a 4:3 tablet by default). parts: menus,cup,league,match.
## Each problem is a line of JSON; a summary is printed at the end. Exits 1 if anything was found.

const LANGS := ["en", "af", "zu", "xh", "st", "tn", "ny", "lg", "sn", "sw", "ms", "zh", "si", "ta", "cy", "mi", "to", "sm", "fj"]
const SKIP_CHARS := [0x20, 0x09, 0x0A, 0xA0, 0xAD, 0x200B, 0x200C, 0x200D, 0x2060, 0xFE0F]

var out_path := "user://fit_audit.jsonl"
var langs: Array = LANGS
var sizes: Array = [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(2400, 1080), Vector2i(1600, 1200)]
var parts: Array = ["menus", "cup", "league", "match"]
var lang := "en"
var res := ""
var where := ""
var found := 0
var by_kind := {}
var _f: FileAccess
var _seen := {}
var _raw_key := RegEx.create_from_string("\\b[A-Z][A-Z0-9]*_[A-Z0-9_]{2,}\\b")
var _placeholder := RegEx.create_from_string("\\{[a-z_0-9]+\\}|%[-+ 0-9.]*[sdif]")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	if args.size() > 1 and args[1] != "" and args[1] != "all":
		langs = Array(args[1].split(","))
	if args.size() > 2 and args[2] != "":
		sizes = []
		for s in args[2].split(","):
			var wh := s.split("x")
			sizes.append(Vector2i(int(wh[0]), int(wh[1])))
	if args.size() > 3 and args[3] != "" and args[3] != "all":
		parts = Array(args[3].split(","))
	_f = FileAccess.open(out_path, FileAccess.WRITE)
	var keep: Dictionary = Game.settings.duplicate(true)
	Game.main = self
	Game.settings.sound = false
	Game.settings.dev = false
	for s in sizes:
		get_tree().root.size = s
		await frames(2)
		var vs := get_viewport().get_visible_rect().size
		res = "%dx%d" % [s.x, s.y]
		print("== %s (%d x %d on screen)" % [res, vs.x, vs.y])
		for l in langs:
			lang = l
			Game.settings.language = l
			TranslationServer.set_locale(l)
			Game._size_theme()
			await _buttons()
			for p in parts:
				await call("_" + p)
			print("   %s: %d so far" % [l, found])
	Game.goto_menu()
	await frames(2)
	Game.delete_cup()
	Game.delete_league()
	Game.settings = keep
	Game.save_settings()
	TranslationServer.set_locale(Game.language())
	_f.close()
	print("fit audit: %d problems %s -> %s" % [found, JSON.stringify(by_kind), out_path])
	get_tree().quit(1 if found > 0 else 0)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _report(kind: String, c: Object, text: String, need := 0.0, have := 0.0, extra := "") -> void:
	var path := ""
	if c is Node:
		path = _short_path(c)
	# The same problem on the same control once per screen.
	var key := "%s|%s|%s|%s|%s|%s" % [res, lang, where, kind, path, text]
	if _seen.has(key):
		return
	_seen[key] = true
	found += 1
	by_kind[kind] = int(by_kind.get(kind, 0)) + 1
	_f.store_line(JSON.stringify({"res": res, "lang": lang, "where": where, "kind": kind, "path": path,
		"text": text.left(120), "need": snappedf(need, 0.1), "have": snappedf(have, 0.1), "extra": extra}))


func _short_path(n: Node) -> String:
	var bits := PackedStringArray()
	var x := n
	var i := 0
	while x and x != get_tree().root and i < 7:
		var nm := String(x.name)
		if nm.begins_with("@"):
			nm = x.get_class()
		var sc: Script = x.get_script()
		if sc and sc.resource_path != "":
			nm += "<" + sc.resource_path.get_file().get_basename() + ">"
		bits.insert(0, nm)
		x = x.get_parent()
		i += 1
	return "/".join(bits)


# --- reading a screen -------------------------------------------------------------------------------------------

## Checks every visible piece of text on the screen as it is now.
func audit(at: String) -> void:
	where = at
	await frames(1)
	var vp := get_viewport().get_visible_rect()
	var inks := []
	var order := 0
	var covers := []
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		order += 1
		if not (n is Control) or not n.is_visible_in_tree():
			continue
		var c: Control = n
		var a := _alpha(c)
		if a < 0.05:
			continue
		var layer := _layer(c)
		if _covering(c, a):
			covers.append({"c": c, "rect": c.get_global_rect(), "layer": layer, "order": order})
		var text := _text_of(c)
		if text.strip_edges() == "":
			continue
		var ink: Rect2 = _check(c, text)
		if ink.size.x <= 0.0:
			continue
		# A news ticker runs its headlines past a window on purpose: only its text's own fit is checked.
		if _in_ticker(c):
			continue
		var seen_ink := _visible_part(c, ink)
		if seen_ink.size.x > 0.0 and seen_ink.size.y > 0.0:
			inks.append({"c": c, "ink": seen_ink, "text": text, "layer": layer, "order": order})
		var scroll := _scroll_parent(c)
		if scroll == null and not vp.grow(1.0).encloses(ink):
			_report("offscreen", c, text, ink.end.x if ink.end.x > vp.end.x else ink.end.y, vp.end.x if ink.end.x > vp.end.x else vp.end.y)
		_check_clip(c, text, ink)
		_check_box(c, text, seen_ink if seen_ink.size.x > 0.0 else ink)
	# Text over text: two pieces of text, neither inside the other, drawn over each other and not hidden under a panel.
	for i in inks.size():
		var p: Dictionary = inks[i]
		if _covered(p, covers):
			continue
		for j in range(i + 1, inks.size()):
			var q: Dictionary = inks[j]
			if p.c.is_ancestor_of(q.c) or q.c.is_ancestor_of(p.c) or _covered(q, covers):
				continue
			# Two labels laid out by the same containers are put where they are on purpose (an eyebrow tucked under
			# a title's line box); text over text comes from something placed by hand.
			if _laid_out_together(p.c, q.c):
				continue
			var cut: Rect2 = p.ink.intersection(q.ink)
			if cut.size.x < 3.0 or cut.size.y < 3.0:
				continue
			# Where they cross, one is hidden under a card drawn over it (text at an overlay's edge, under its card).
			if _hidden_at(p, cut, covers) or _hidden_at(q, cut, covers):
				continue
			var small: float = minf(p.ink.get_area(), q.ink.get_area())
			if small > 0.0 and cut.get_area() / small > 0.12:
				_report("overlap", p.c, String(p.text) + "  <>  " + String(q.text), cut.get_area(), small, _short_path(q.c))


func _in_ticker(c: Node) -> bool:
	var x := c.get_parent()
	while x:
		var sc: Script = x.get_script()
		if sc and sc.resource_path.ends_with("news_ticker.gd"):
			return true
		x = x.get_parent()
	return false


## The part of the text that shows: inside every box that clips it.
func _visible_part(c: Control, ink: Rect2) -> Rect2:
	var r := ink
	var x := c.get_parent()
	while x and not (x is CanvasLayer) and x != get_tree().root:
		if x is Control and x.clip_contents:
			r = r.intersection(x.get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		x = x.get_parent()
	return r


## Whether both are placed by containers all the way up to the node they share.
func _laid_out_together(a: Control, b: Control) -> bool:
	var common: Node = a
	while common and not common.is_ancestor_of(b):
		common = common.get_parent()
	if common == null or not (common is Container):
		return false
	for n in [a, b]:
		var x: Node = n
		while x != common:
			if not (x.get_parent() is Container) or (x is Control and x.top_level):
				return false
			x = x.get_parent()
	return true


func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var x: Node = c
	while x and x is CanvasItem:
		a *= x.modulate.a * (x.self_modulate.a if x == c else 1.0)
		x = x.get_parent()
	return a


func _layer(c: Node) -> int:
	var x := c.get_parent()
	while x:
		if x is CanvasLayer:
			return x.layer
		x = x.get_parent()
	return 0


## Panels and colour fills that hide what is under them (an overlay's dimmed backdrop, a card).
func _covering(c: Control, a: float) -> bool:
	if c is ColorRect:
		return c.color.a * a > 0.6 and c.size.x * c.size.y > 4000.0
	if c is PanelContainer or c is Panel:
		var sb := c.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			return sb.bg_color.a * a > 0.6 and c.size.x * c.size.y > 4000.0
	return false


func _covered(p: Dictionary, covers: Array) -> bool:
	for cv in covers:
		if cv.c.is_ancestor_of(p.c) or cv.c == p.c:
			continue
		var later: bool = cv.layer > p.layer or (cv.layer == p.layer and cv.order > p.order)
		# Mostly under a panel drawn after it (an overlay over the screen): what shows at the panel's edge is not
		# text over text.
		if later and cv.rect.intersection(p.ink).get_area() >= 0.5 * p.ink.get_area():
			return true
	return false


## Whether the text is hidden at r, mostly under a panel drawn after it.
func _hidden_at(p: Dictionary, r: Rect2, covers: Array) -> bool:
	for cv in covers:
		if cv.c.is_ancestor_of(p.c) or cv.c == p.c:
			continue
		var later: bool = cv.layer > p.layer or (cv.layer == p.layer and cv.order > p.order)
		if later and cv.rect.intersection(r).get_area() >= 0.5 * r.get_area():
			return true
	return false


func _text_of(c: Control) -> String:
	var t := ""
	if c is Label:
		t = c.atr(c.text)
		if c.uppercase:
			t = t.to_upper()
	elif c is Button:
		t = c.atr(c.text)
	elif c is RichTextLabel:
		t = c.get_parsed_text()
	elif c is LineEdit:
		t = c.text if c.text != "" else c.atr(c.placeholder_text)
	return t


func _scroll_parent(c: Node) -> ScrollContainer:
	var x := c.get_parent()
	while x:
		if x is ScrollContainer:
			return x
		x = x.get_parent()
	return null


## The text's own checks; returns where its ink is on the screen.
func _check(c: Control, text: String) -> Rect2:
	var font: Font = c.get_theme_font("font")
	var fs: int = c.get_theme_font_size("font_size")
	if c is RichTextLabel:
		font = c.get_theme_font("normal_font")
		fs = c.get_theme_font_size("normal_font_size")
	if font == null:
		return Rect2()
	_check_chars(c, text, font)
	if _raw_key.search(text):
		_report("raw_key", c, text)
	if _placeholder.search(text):
		_report("placeholder", c, text)
	var sb: StyleBox = null
	if c is Label:
		sb = c.get_theme_stylebox("normal")
	elif c is Button:
		sb = c.get_theme_stylebox("normal")
	var ml := sb.get_margin(SIDE_LEFT) if sb else 0.0
	var mr := sb.get_margin(SIDE_RIGHT) if sb else 0.0
	var mt := sb.get_margin(SIDE_TOP) if sb else 0.0
	var mb := sb.get_margin(SIDE_BOTTOM) if sb else 0.0
	var room := c.size.x - ml - mr
	if c is Button and c.icon and not c.expand_icon:
		room -= c.icon.get_width() + c.get_theme_constant("h_separation")
	var line_h := font.get_height(fs) + (c.get_theme_constant("line_spacing") if c is Label else 0)
	var widest := 0.0
	var shown_lines := 1
	if c is RichTextLabel:
		var rh: float = c.get_content_height()
		if not c.fit_content and not c.scroll_active and rh > c.size.y + 2.0:
			_report("cut_lines", c, text, rh, c.size.y)
		widest = minf(c.get_content_width(), c.size.x)
		return c.get_global_transform() * Rect2(Vector2.ZERO, Vector2(widest, minf(rh, c.size.y)))
	var wraps: bool = (c is Label or c is Button) and c.autowrap_mode != TextServer.AUTOWRAP_OFF
	var trims: bool = (c is Label or c is Button) and (c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or c.clip_text)
	if wraps and not (lang in ["ja", "zh"]):
		# (Chinese and Japanese break lines between any two characters: no word to keep whole.)
		# A piece that may not be broken (a word, or words held together by no-break spaces) wider than the room is
		# broken in the middle, or sticks out.
		for word in text.replace("\n", " ").split(" ", false):
			var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if ww > room + 1.5:
				_report("word_broken", c, word, ww, room, text)
	if wraps:
		widest = minf(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room, fs).x, room)
		if c is Label:
			var lc: int = c.get_line_count()
			var vis: int = c.get_visible_line_count()
			shown_lines = mini(lc, vis) if vis > 0 else lc
			if lc > vis and vis >= 0:
				_report("cut_lines", c, text, lc, vis)
	else:
		var lines := text.split("\n")
		shown_lines = lines.size()
		for ln in lines:
			var w := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			widest = maxf(widest, w)
			if w > room + 1.5:
				_report("cut_short" if trims else "too_wide", c, ln, w, room)
		widest = minf(widest, maxf(room, 0.0))
	var ink_h := minf(shown_lines * line_h, c.size.y - mt - mb) if c is Label else minf(line_h, c.size.y)
	var x0 := ml
	var align := HORIZONTAL_ALIGNMENT_LEFT
	if c is Label:
		align = c.horizontal_alignment
	elif c is Button:
		align = c.alignment
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x0 = ml + (room - widest) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x0 = ml + room - widest
	var y0 := mt
	if c is Label:
		if c.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			y0 = mt + (c.size.y - mt - mb - ink_h) * 0.5
		elif c.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
			y0 = c.size.y - mb - ink_h
	else:
		y0 = (c.size.y - ink_h) * 0.5
	return c.get_global_transform() * Rect2(Vector2(x0, y0), Vector2(widest, ink_h))


func _check_chars(c: Control, text: String, font: Font) -> void:
	var missing := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code in SKIP_CHARS or missing.contains(char(code)):
			continue
		if not font.has_char(code):
			missing += char(code)
	if missing != "":
		var codes := PackedStringArray()
		for i in missing.length():
			codes.append("U+%04X" % missing.unicode_at(i))
		_report("no_glyph", c, text, 0, 0, " ".join(codes))


## Text that runs out of the card or button it sits in (a box that does not clip shows it spilling over the next one).
func _check_box(c: Control, text: String, ink: Rect2) -> void:
	var x := c.get_parent()
	while x and not (x is CanvasLayer) and x != get_tree().root:
		if x is ScrollContainer:
			return
		if x is Button or x is PanelContainer:
			var r: Rect2 = (x as Control).get_global_rect().grow(2.0)
			if not r.encloses(ink):
				_report("outside_box", c, text, ink.end.x, r.end.x, _short_path(x))
			return
		x = x.get_parent()


## Text outside a box that clips what is in it (a scrolling list may run on down or across, as it scrolls).
func _check_clip(c: Control, text: String, ink: Rect2) -> void:
	var x := c.get_parent()
	while x:
		if x is Control and x.clip_contents and x.is_visible_in_tree():
			var r: Rect2 = x.get_global_rect().grow(1.0)
			if not r.encloses(ink):
				var across: bool = ink.position.x < r.position.x or ink.end.x > r.end.x
				var down: bool = ink.position.y < r.position.y or ink.end.y > r.end.y
				if x is ScrollContainer:
					if across and x.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
						_report("clipped", c, text, ink.end.x, r.end.x, _short_path(x))
				else:
					_report("clipped", c, text, ink.end.y if down else ink.end.x, r.end.y if down else r.end.x, _short_path(x))
				return
		if x is CanvasLayer or x == get_tree().root:
			return
		x = x.get_parent()


## The match buttons draw their own words, fitted inside the circle (game/touch_controls.gd): each must fit, in at
## most two lines, at every button size.
func _buttons() -> void:
	where = "touch_buttons"
	var tc := TouchControls.new()
	tc.size = Vector2(1280, 720)
	add_child(tc)
	var keep := int(Game.settings.btn_size)
	for k in 3:
		Game.settings.btn_size = k
		for set_ in [["PASS", "LOB"], ["SHOOT", "PASS", "LOB"], ["INTERCEPT", "DEFEND", "SWITCH"]]:
			tc.set_buttons(set_)
			tc.queue_redraw()
			await frames(2)   # the labels are fitted as they are drawn
			for f in tc.label_fits():
				_check_chars(null, tr("BTN_" + String(f.id)), Game.font_bold)
				if float(f.w) > float(f.room) + 1.0 or int(f.lines) > 2:
					_report("button_overflow", null, "%s (size %d): %d lines, %d px in %d" % [tr("BTN_" + String(f.id)), k, int(f.lines), int(f.w), int(f.room)])
	Game.settings.btn_size = keep
	tc.queue_free()


# --- the screens ------------------------------------------------------------------------------------------------

func _menus() -> void:
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await frames(30)
	await audit("main_menu")
	menu._open_language()
	await frames(12)
	await audit("language_picker")
	menu._picker.close()
	await frames(6)
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(10)
	await audit("settings")
	for tab in 4:
		Game.show_screen("res://ui/howto_screen.gd", {"tab": tab})
		await frames(10)
		await audit("howto_%d" % tab)
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(10)
	await audit("quick_setup")
	# The records as a keen player's would be (an empty book shows only a line, and hid a layout bug).
	var kept_records: Dictionary = Game.records.duplicate(true)
	Game.records = {"played": 128, "won": 71, "drawn": 6, "lost": 51, "goals": 4123, "best_margin": 38,
		"best_win": "TTO 71 – 33 NAM", "top_shooter": "Kerry-Ann Thompson (GS)", "top_shooter_goals": 64,
		"cups_played": 12, "cups_won": 3, "seasons_played": 9, "titles_won": 2}
	Game.show_screen("res://ui/records_screen.gd")
	await frames(8)
	await audit("records")
	Game.records = kept_records
	Game.show_screen("res://ui/licences_screen.gd")
	await frames(8)
	await audit("licences")
	Game.show_screen("res://ui/result_screen.gd", {"result": fake_result()})
	await frames(12)
	await audit("result")


## A finished match to show on the result screen: two full squads' box scores.
static func fake_result() -> Dictionary:
	var stats := {}
	for t in 2:
		var sq: Array = DB.squad("TTO" if t == 0 else "ZIM")
		for i in 7:
			var e: Dictionary = sq[i]
			stats[String(e.id)] = {"team": t, "name": String(e.name), "pos": Rules.POSITIONS[i], "goals": 30 if i == 0 else (14 if i == 1 else 0),
				"attempts": 35 if i == 0 else (19 if i == 1 else 0), "super": 0, "feeds": 20, "assists": 12, "cpr": 18, "gains": 4,
				"intercepts": 3, "deflections": 5, "rebounds": 2, "penalties": 9, "turnovers": 3, "passes": 60}
	return {"config": {"home": "TTO", "away": "ZIM", "mode": "quick", "stage": TranslationServer.translate("STAGE_SEMI")},
		"score": [44, 41], "q_scores": [[11, 10], [12, 9], [10, 11], [11, 11]], "stats": stats, "winner": 0,
		"potm": stats.keys()[0], "user_team": 0, "log": [], "calls": {}, "periods": 4}


func _cup() -> void:
	Game.delete_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(10)
	await audit("cup_pick")
	var cup = Game.new_cup("TTO")
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(12)
	await audit("cup_hub")
	cup.sim_next()
	cup.sim_next()
	cup.sim_next()
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(12)
	await audit("cup_semis")
	while cup.stage != "done":
		cup.sim_next()
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(12)
	await audit("cup_over")
	Game.delete_cup()


func _league() -> void:
	Game.delete_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(12)
	await audit("league_pick")
	var lg = Game.new_league("WKR")
	lg.sim_next()
	Game.save_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(12)
	await audit("league_hub")
	while lg.stage == "season":
		lg.sim_next()
	Game.save_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(12)
	await audit("league_finals")
	while lg.stage != "done":
		lg.sim_next()
	Game.save_league()
	Game.show_screen("res://ui/league_screen.gd")
	await frames(12)
	await audit("league_over")
	Game.delete_league()


func _match() -> void:
	Game.settings.coach = true
	Game.start_match({"home": "TTO", "away": "NAM", "venue": "arena", "quarter": 15, "difficulty": 1, "mode": "cup",
		"user_team": 0, "stage": tr("STAGE_SEMI"), "seed": 3})
	await frames(30)
	await audit("match_intro")
	var m: Node = Game.current
	await frames(150)
	await audit("match_play")
	m.hud.banner(tr("CALL_OBSTRUCTION"), tr("AWARD_TO").format({"award": tr("AWARD_PENALTY_SHOT"), "team": DB.team_name("NAM")}))
	await frames(4)
	await audit("match_callout")
	if m.hud.coach:
		for k in ["pass", "defend"]:   # the two longest tips
			m.hud.coach.show_tip(k)
			await frames(4)
			await audit("match_coach_" + k)
	m.set_paused(true)
	await frames(6)
	await audit("match_pause")
	m.set_paused(false)
	m.phase = "break"
	m.hud.show_break(2, 3)
	await frames(6)
	await audit("match_break")
	# The team card, before the match and at half-time (fully faded in).
	m.hud.hide_break()
	for half in [false, true]:
		m.hud.show_card(half)
		await frames(15)
		await audit("match_card_half" if half else "match_card")
	Game.goto_menu()
	await frames(4)
