class_name CourtDiagram
extends Control
## A court seen from above, drawn to scale: the ulama taste (a long strip of earth, the analco across its middle, a
## chivo at each end) or the classic stone court (the I: the alley, the sloped benches, the end courts, the rings at
## the centre line). The two sides' halves are tinted in their colours; labels name the lines.

var rules := Rules.ULAMA
var home := Color("b8352b")
var away := Color("2f5d8a")
var labels := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_court(p_rules: String, h: Color, a: Color) -> void:
	rules = p_rules
	home = h
	away = a
	queue_redraw()


func _draw() -> void:
	var s := size
	var hl := Court.END_HALF_L if rules == Rules.CLASSIC else Court.ULAMA_HALF_L
	var hw := Court.END_HALF_W if rules == Rules.CLASSIC else Court.ULAMA_HALF_W * 3.0
	var k := minf((s.x - 24.0) / (hl * 2.0), (s.y - 44.0) / (hw * 2.0))
	var c := Vector2(s.x * 0.5, s.y * 0.5 - 8.0)
	var P := func(x: float, z: float) -> Vector2: return c + Vector2(x, z) * k
	var ink := Color(Game.C_INK, 0.85)
	var earth := Color("8a5a3a")
	var stone := Color("cdbd9c")
	var font: Font = Game.font_bold
	var fs := Game.ts(14)
	if rules == Rules.ULAMA:
		var w := Court.ULAMA_HALF_W
		draw_rect(Rect2(P.call(-hl, -w), Vector2(hl * 2.0, w * 2.0) * k), earth)
		draw_rect(Rect2(P.call(-hl, -w), Vector2(hl, w * 2.0) * k), Color(home, 0.28))
		draw_rect(Rect2(P.call(0, -w), Vector2(hl, w * 2.0) * k), Color(away, 0.28))
		draw_rect(Rect2(P.call(-hl, -w), Vector2(hl * 2.0, w * 2.0) * k), ink, false, 2.0)
		draw_line(P.call(0, -w - 0.6), P.call(0, w + 0.6), Game.C_GOLD, 3.0)
		if labels:
			_label(tr("ANALCO"), P.call(0, -w - 1.0), font, fs, Game.C_GOLD)
			_label(tr("CHIVO"), P.call(-hl + 2.0, w + 2.6), font, fs, ink)
			_label(tr("CHIVO"), P.call(hl - 2.0, w + 2.6), font, fs, ink)
			_label(tr("TASTE_SIZE"), P.call(0, w + 2.6), font, fs, Color(Game.C_INK, 0.6))
		return
	var al := Court.ALLEY_HALF_L
	var aw := Court.ALLEY_HALF_W
	var tz := Court.TALUD_Z
	var ew := Court.END_HALF_W
	# The structures either side, then the floor of the I.
	for sz in [-1.0, 1.0]:
		draw_rect(Rect2(P.call(-al, minf(sz * aw, sz * (tz + 3.0))), Vector2(al * 2.0, 3.0 + tz - aw) * k), Color(stone, 0.55))
		draw_rect(Rect2(P.call(-al, minf(sz * aw, sz * tz)), Vector2(al * 2.0, tz - aw) * k), Color(stone, 0.85))
	draw_rect(Rect2(P.call(-al, -aw), Vector2(al * 2.0, aw * 2.0) * k), Color("e6dcc6"))
	draw_rect(Rect2(P.call(-al, -aw), Vector2(al, aw * 2.0) * k), Color(home, 0.25))
	draw_rect(Rect2(P.call(0, -aw), Vector2(al, aw * 2.0) * k), Color(away, 0.25))
	for sx in [-1.0, 1.0]:
		var x0: float = minf(sx * al, sx * hl)
		draw_rect(Rect2(P.call(x0, -ew), Vector2(hl - al, ew * 2.0) * k), Color("e6dcc6"))
		draw_rect(Rect2(P.call(x0, -ew), Vector2(hl - al, ew * 2.0) * k), Color(home if sx < 0 else away, 0.18))
		draw_rect(Rect2(P.call(x0, -ew), Vector2(hl - al, ew * 2.0) * k), ink, false, 2.0)
	draw_line(P.call(0, -aw), P.call(0, aw), Game.C_GOLD, 2.0)
	for rc in [-1.0, 1.0]:
		draw_circle(P.call(0, rc * (tz - 0.4)), maxf(4.0, Court.RING_OUT * k * 1.6), Color("6a5a44"))
		draw_circle(P.call(0, rc * (tz - 0.4)), maxf(2.0, Court.RING_IN * k * 1.6), Color("e6dcc6"))
	if labels:
		_label(tr("RING"), P.call(0, -tz - 3.6), font, fs, Game.C_GOLD)
		_label(tr("END_COURT"), P.call(-(al + hl) * 0.5, ew + 2.4), font, fs, ink)
		_label(tr("END_COURT"), P.call((al + hl) * 0.5, ew + 2.4), font, fs, ink)
		_label(tr("TALUD"), P.call(-al * 0.55, tz + 2.2), font, fs, Color(Game.C_INK, 0.7))


func _label(text: String, at: Vector2, font: Font, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, at - Vector2(w * 0.5, -fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(font, at - Vector2(w * 0.5, -fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
