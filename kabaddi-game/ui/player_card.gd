class_name PlayerCard
extends RefCounted
## A player as a card to tap: his rating, name and a line about him, and whatever the screen needs on the right
## (form, fitness, a knock, a price, how well he fits). Picking a seven, retentions and a national squad use it.
##
## info keys, all optional: selected (bool), line (String, under the name: up to two lines, "\n" between them),
## form (-1, 0, 1), fit (0..1, a fitness bar), injured (matches out), price (String), stars (0..3), captain (bool),
## dim (bool: not available).

const ROLE_KEYS := {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}


static func role_name(p: Dictionary) -> String:
	return TranslationServer.translate(ROLE_KEYS.get(String(p.get("role", "")), "ROLE_RAIDER"))


## "Raider · 24" or "Defender (corner) · 27": the role, a defender's place, and his age.
static func line(p: Dictionary) -> String:
	var r := role_name(p)
	if String(p.role) == "defender":
		r = "%s (%s)" % [r, Scout.slot_name(p).to_lower()]
	return "%s · %s" % [r, TranslationServer.translate("AGE_N").format({"n": Scout.age(p)})]


static func make(p: Dictionary, info: Dictionary, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var sel := bool(info.get("selected", false))
	var dim := bool(info.get("dim", false))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_SAFFRON, 0.16) if sel else Color(0, 0, 0, 0.24)
	sb.set_corner_radius_all(12)
	sb.border_color = Game.C_SAFFRON if sel else Color(1, 1, 1, 0.07)
	sb.set_border_width_all(2 if sel else 1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(Game.C_SAFFRON, 0.24) if sel else Color(Game.C_PANEL_HI, 0.8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ov := UI.label(str(DB.overall(p)), "HeaderLabel", 34, Game.C_GOLD if not dim else Game.C_MUTED)
	ov.custom_minimum_size = Vector2(40, 0)
	ov.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ov)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(info.get("captain", false)):
		var cr := Icon.make("crown", 18, Game.C_GOLD)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(cr)
	var nm := UI.label(String(p.name), "SubLabel", 18, Game.C_MUTED if dim else (Game.C_SAFFRON if sel else Game.C_INK))
	UI.fit(nm)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(nm)
	col.add_child(top)
	var lines := PackedStringArray()
	for s in String(info.get("line", line(p))).split("\n"):
		lines.append(UI.bits([s]))
	var ln := UI.label("\n".join(lines), "MutedLabel", 14)
	UI.fit(ln, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ln)
	if info.has("fit"):
		# Fitness, under his name the width of the card.
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = float(info.fit) * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		var fv := float(info.fit)
		fill.bg_color = Game.C_GOOD if fv >= 0.85 else (Game.C_GOLD if fv >= 0.7 else Game.C_DANGER)
		fill.set_corner_radius_all(99)
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
	h.add_child(col)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 3)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_END
	icons.add_theme_constant_override("separation", 6)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if int(info.get("injured", 0)) > 0:
		icons.add_child(Icon.make("cross", 16, Game.C_DANGER))
		icons.add_child(UI.label(TranslationServer.translate("OUT_N").format({"n": int(info.injured)}), "EyebrowLabel", 13, Game.C_DANGER))
	if info.has("form"):
		var f := int(info.form)
		icons.add_child(Icon.make("up" if f > 0 else ("down" if f < 0 else "steady"), 16,
			Game.C_GOOD if f > 0 else (Game.C_DANGER if f < 0 else Game.C_MUTED)))
	if info.has("stars"):
		for i in 3:
			icons.add_child(Icon.make("star", 15, Game.C_GOLD if i < int(info.stars) else Color(1, 1, 1, 0.15)))
	if icons.get_child_count() > 0:
		right.add_child(icons)
	if info.has("price"):
		var pl := UI.label(String(info.price), "SubLabel", 16, Game.C_GOLD)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(pl)
	h.add_child(right)
	if sel:
		var ck := Icon.make("check", 20, Game.C_SAFFRON)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ck)
	if on_press.is_valid():
		b.pressed.connect(Sfx.click)
		b.pressed.connect(on_press)
	return b
