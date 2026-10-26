class_name TeamCard
extends Control
## The broadcast's full-screen team card, before the match and at half-time: the screen split in the two teams'
## colours, their crests and names, the competition (and its stage) above and the venue below; at half-time the score
## between them. It fades in, holds a couple of seconds and fades out; a tap anywhere skips it.

const FADE_IN := 0.3
const HOLD := 2.0
const FADE_OUT := 0.35

var m
var half_time := false
var _tw: Tween
var _closing := false
var _cols: Array = [Color.WHITE, Color.BLACK]


static func make(p_match, p_half_time := false) -> TeamCard:
	var c := TeamCard.new()
	c.m = p_match
	c.half_time = p_half_time
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	for t in 2:
		_cols[t] = DB.team(m.team_id(t)).get("c1", Color.WHITE)
	# An opaque backdrop (it hides the match, and the fit audit sees it does), the halves painted over it.
	var bg := ColorRect.new()
	bg.color = Game.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var paint := Control.new()
	paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paint.draw.connect(_paint.bind(paint))
	paint.resized.connect(paint.queue_redraw)
	add_child(paint)
	var margin := UI.frame(self, 40.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)
	v.add_child(_centred(_text(competition(m.config), "EyebrowLabel", 18)))
	if half_time:
		v.add_child(_centred(_text(tr("HALF_TIME"), "TitleLabel", 54)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for t in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 12)
		var badge := UI.badge(m.team_id(t), Vector2(150, 100))
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(badge)
		var nm := _text(DB.team_name(m.team_id(t)), "HeaderLabel", 44)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(nm)
		row.add_child(col)
		if t == 0 and half_time:
			var mid := _text("%d – %d" % [m.score[0], m.score[1]], "ScoreLabel", 64)
			mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mid)
	v.add_child(_centred(_text(tr(String(DB.venue(String(m.config.get("venue", "arena")))[1])), "SubLabel", 22)))
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tw.tween_interval(HOLD)
	_tw.tween_callback(close)


## The competition, and its stage if it has one: "Nations Cup · Semi-final", "Quick Match".
static func competition(cfg: Dictionary) -> String:
	var mode := String(cfg.get("mode", "quick"))
	var name := TranslationServer.translate({"cup": "MENU_CUP", "league": "MENU_LEAGUE"}.get(mode, "MENU_QUICK"))
	var stage := String(cfg.get("stage", ""))
	return name if stage == "" else "%s · %s" % [name, stage]


## Fades it out and frees it (a tap, or its time is up).
func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tw.tween_callback(queue_free)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
		close()


func _paint(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var slant := h * 0.12
	var a: Color = _cols[0]
	var b: Color = _cols[1]
	c.draw_rect(Rect2(Vector2.ZERO, c.size), b.darkened(0.25))
	c.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w * 0.5 + slant, 0), Vector2(w * 0.5 - slant, h), Vector2(0, h)]), a.darkened(0.25))
	c.draw_line(Vector2(w * 0.5 + slant, 0), Vector2(w * 0.5 - slant, h), Color(1, 1, 1, 0.85), 6.0, true)
	# Darker toward the top and bottom, where the competition and the venue are written.
	for i in 8:
		var k := float(i) / 8.0
		var band := h * 0.2 / 8.0
		var dark := Color(0.02, 0.02, 0.06, 0.55 * (1.0 - k))
		c.draw_rect(Rect2(0, band * i, w, band), dark)
		c.draw_rect(Rect2(0, h - band * (i + 1), w, band), dark)


func _text(s: String, variation: String, px: int) -> Label:
	var l := UI.label(s, variation, px, Game.C_INK)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08, 0.85))
	return l


func _centred(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
