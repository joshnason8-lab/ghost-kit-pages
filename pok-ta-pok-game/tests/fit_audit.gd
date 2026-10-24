extends Node
## Every screen in every language at a phone's shape, read rather than looked at: text cut short (an ellipsis, a
## clipped edge, lines held back), a word broken in the middle, text off the screen or out of the box that clips it,
## text over other text, a translation key or a placeholder shown raw, and characters no font in the chain can draw.
## Also the match buttons' labels against their circles. Headless, so it is quick:
##   godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- OUT.jsonl [langs] [WxH,...] [parts]
## langs: es,en,pt,fr,de,it (all by default). WxH: the phone's screen in pixels (layouts depend only on its shape): 16:9
## (1280x720), 19.5:9 (a Galaxy A16's 2340x1080), 20:9 with a camera cut-out (2400x1080, its cut-out given to the
## safe-area margins as a phone's would be) and a 4:3 tablet (2048x1536). parts: menus,cup,match (all by default).
## Each problem is a line of JSON; a summary is printed at the end. Exits 1 if anything was found.

const LANGS := ["es", "en", "pt", "fr", "de", "it"]
const SKIP_CHARS := [0x20, 0x09, 0x0A, 0xA0, 0xAD, 0x200B, 0x200C, 0x200D, 0x2060, 0xFE0F]

var out_path := "user://fit_audit.jsonl"
var langs: Array = LANGS
var sizes: Array = [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(2400, 1080), Vector2i(2048, 1536)]
var parts: Array = ["menus", "cup", "match"]
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
		# The 20:9 phone has a camera cut-out on its left edge, held sideways: 110 px of it.
		UI.test_cutout = 110.0 if s == Vector2i(2400, 1080) else 0.0
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
		for set_ in [["HIP", "DIVE"], ["SERVE"]]:
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
	Game.delete_cup()
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await frames(30)
	await audit("main_menu")
	menu._open_language()
	await get_tree().create_timer(0.6).timeout
	await frames(2)
	await audit("language_picker")
	menu._picker.close()
	await frames(6)
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(10)
	await audit("settings")
	_scroll_to_end()
	await frames(4)
	await audit("settings_end")
	for tab in 4:
		Game.show_screen("res://ui/howto_screen.gd", {"tab": tab})
		await frames(10)
		await audit("howto_%d" % tab)
		_scroll_to_end()
		await frames(4)
		await audit("howto_%d_end" % tab)
	for venue in ["village", "stone"]:
		for watch in [false, true]:
			Game.settings.venue = venue
			Game.show_screen("res://ui/quick_setup.gd", {"watch": watch})
			await frames(10)
			await audit("setup_%s_%s" % [venue, watch])
			_scroll_to_end()
			await frames(4)
			await audit("setup_%s_%s_end" % [venue, watch])
	Game.show_screen("res://ui/buttons_screen.gd")
	await frames(8)
	await audit("move_buttons")
	Game.show_screen("res://ui/licences_screen.gd")
	await frames(8)
	await audit("licences")
	for rules in ["ulama", "classic"]:
		var r := _result(rules)
		Game.show_screen("res://ui/result_screen.gd", {"result": r})
		await frames(12)
		await audit("result_" + rules)
		_scroll_to_end()
		await frames(4)
		await audit("result_%s_end" % rules)


## A result with the longest names and the most to say.
func _result(rules: String) -> Dictionary:
	var ts := {"rayas": 14, "dead": 7, "end": 3, "won_out": 2, "won_touch": 2, "ring": 1 if rules == "classic" else 0, "faults_touch": 1,
		"faults_out": 2, "strikes": 140, "dives": 32, "serves": 19}
	var ps := {}
	for k in 2:
		var tid := "MOR" if k == 0 else "FCP"
		var roster := DB.roster(tid, 5)
		for i in roster.size():
			ps["%s_%d" % [tid, i + 1]] = {"name": String(roster[i].name), "team": k, "role": "medio", "strikes": 19, "dives": 4, "rayas": 3, "faults": 1, "serves": 5}
	return {"config": {"mode": "cup", "stage": tr("STAGE_QUARTER"), "venue": "village" if rules == "ulama" else "night", "rules": rules},
		"home": "MOR", "away": "FCP", "rules": rules,
		"count": {"rules": rules, "holder": 0, "rayas": 3, "points": [6, 7], "winner": 0, "ring": rules == "classic"},
		"winner": 0, "user_team": 0, "tstats": [ts, ts.duplicate()], "pstats": ps, "log": [], "longest_rally": 23, "minutes": 15.0,
		"timed": rules == "ulama", "star": "MOR_1"}


func _scroll_to_end() -> void:
	for n in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var sc: ScrollContainer = n
		if sc.is_visible_in_tree():
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _cup() -> void:
	Game.delete_cup()
	for rules in ["ulama", "classic"]:
		Game.settings.mode = rules
		Game.show_screen("res://ui/cup_screen.gd")
		await frames(10)
		await audit("cup_pick_" + rules)
	for team in ["MOR", "FCP"]:
		var c: Cup = Game.new_cup(team)
		Game.save_cup()
		Game.show_screen("res://ui/cup_screen.gd")
		await frames(8)
		await audit("cup_%s_start" % team)
		var hub := Game.show_screen("res://ui/cup_screen.gd")
		await frames(4)
		for b in hub.find_children("*", "Button", true, false):
			if (b as Button).text == tr("START_AGAIN"):
				b.set_meta("sure", true)
				(b as Button).text = tr("START_AGAIN_SURE")
		await frames(4)
		await audit("cup_%s_again" % team)
		var guard := 0
		while not c.done() and guard < 10:
			guard += 1
			var f := c.next_fixture()
			if f.is_empty():
				c.play_others()
				continue
			var s := Sim.play(String(f.home), String(f.away), c.rules)
			c.record_user_result({"home": f.home, "away": f.away, "winner": s.winner, "count": s.count})
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")
			await frames(6)
			await audit("cup_%s_round_%d" % [team, c.round])
		Game.show_screen("res://ui/main_menu.gd")
		await frames(6)
	Game.new_cup("MOR")
	Game.save_cup()
	Game.show_screen("res://ui/main_menu.gd")
	await frames(20)
	await audit("main_menu_continue")
	Game.delete_cup()


func _match() -> void:
	for rules in ["ulama", "classic"]:
		Game.start_match({"home": "MOR", "away": "FCP", "venue": "village" if rules == "ulama" else "night", "rules": rules, "difficulty": 1,
			"mode": "cup", "user_team": 0, "stage": tr("STAGE_QUARTER"), "seed": 3, "length": 10})
		await frames(40)
		await audit("match_intro_" + rules)
		var m: Node = Game.current
		await frames(200)
		await audit("match_play_" + rules)
		# The longest calls in each language.
		var who: Player = m.teams[0].players[0]
		m.hud.call_raya(1, "touch", "urria", true, who)
		m.hud.serve_tag(0, "arriba")
		await frames(4)
		await audit("match_call_urria_" + rules)
		m.hud.call_raya(0, "end", "cancel", false, who)
		await frames(4)
		await audit("match_call_cancel_" + rules)
		m.hud.call_raya(0, "ring", "ring", false, who)
		await frames(4)
		await audit("match_call_ring_" + rules)
		for k in ["TIP_SERVE", "TIP_HIP", "TIP_DIVE"]:
			m.hud.toast(tr(k), 3.0)
			await frames(3)
			await audit("match_tip_" + k)
		m.hud.note(tr("GFX_LOWERED"))
		m.set_paused(true)
		await frames(6)
		await audit("match_pause_" + rules)
		m.set_paused(false)
		m.count.winner = 0
		m.hud.full_time(0)
		await frames(4)
		await audit("match_full_time_" + rules)
		Game.goto_menu()
		await frames(4)
