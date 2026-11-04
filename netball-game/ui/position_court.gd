class_name PositionCourt
extends Control
## How to Play's picture of one position, drawn as a coach draws it: the court in thirds with both goal circles, her
## team attacking to the right; the areas she may go into (Rules.AREAS) lit lime and the others dimmed; her bib where
## she typically plays, her opposite number's (Rules.OPPOSITE) beside her in the other team's coral; and under the
## court an arrow toward the goal she attacks, its post marked. No words: it reads the same in every language.

## The five areas, from the goal she defends (left) to the one she attacks (right).
const AREA_ORDER := [Court.A_DEF_CIRCLE, Court.A_DEF_THIRD, Court.A_CENTRE, Court.A_ATT_THIRD, Court.A_ATT_CIRCLE]

## Where she and her opposite number typically are, in court metres (x toward the goal she attacks, y across): the
## defender goal-side of the attacker she marks, both well inside their areas (tests/test_runner.gd checks they are
## onside), and far enough apart across the court that the bibs do not cover each other.
const SPOTS := {
	"GS": [Vector2(12.0, 3.2), Vector2(12.6, -3.4)],
	"GA": [Vector2(8.6, 3.0), Vector2(9.8, -2.6)],
	"WA": [Vector2(7.4, 4.4), Vector2(8.7, -1.0)],
	"C": [Vector2(-0.8, 2.9), Vector2(0.9, -2.6)],
	"WD": [Vector2(-7.6, 4.4), Vector2(-6.3, -1.0)],
	"GD": [Vector2(-9.8, 3.0), Vector2(-8.6, -2.6)],
	"GK": [Vector2(-12.5, 3.2), Vector2(-12.1, -3.4)],
}

var pos := "C"


static func make(p_pos: String) -> PositionCourt:
	var m := PositionCourt.new()
	m.pos = p_pos
	m.custom_minimum_size = Vector2(0, 170)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## What the picture shows for a position: the areas lit and dimmed, her spot, her opposite number and hers, and
## the end she attacks (+1: the right).
static func layout(p: String) -> Dictionary:
	var lit := []
	var dim := []
	for a in AREA_ORDER:
		(lit if Rules.may_enter(p, a) else dim).append(a)
	return {"pos": p, "lit": lit, "dim": dim, "at": SPOTS[p][0], "opp": Rules.OPPOSITE[p], "opp_at": SPOTS[p][1],
		"attacks": 1}


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var lay := layout(pos)
	var lit: Array = lay.lit
	# The court 2:1 as it is, as big as fits with the arrow's strip under it, centred.
	var h := minf(size.y / 1.18, size.x * 0.5)
	var w := h * 2.0
	var strip := h * 0.18
	var o := Vector2((size.x - w) * 0.5, (size.y - h - strip) * 0.5)
	var k := h / Court.WIDTH   # pixels a metre
	var third := w / 3.0
	var lit_col := Game.C_ACCENT
	var dim_col := Game.C_COURT.darkened(0.6)
	# The thirds, then the circles over them.
	var thirds := [Court.A_DEF_THIRD, Court.A_CENTRE, Court.A_ATT_THIRD]
	for i in 3:
		draw_rect(Rect2(o + Vector2(third * i, 0), Vector2(third, h)), lit_col if thirds[i] in lit else dim_col, true)
	var cr := Court.CIRCLE_R * k
	var lw := maxf(1.5, h * 0.016)
	var line := Color(1, 1, 1, 0.95)
	for side in [-1, 1]:
		var c := o + Vector2(0.0 if side < 0 else w, h * 0.5)
		var area: String = Court.A_DEF_CIRCLE if side < 0 else Court.A_ATT_CIRCLE
		var pts := PackedVector2Array()
		for i in 33:
			var a := -PI * 0.5 + PI * i / 32.0
			pts.append(c + Vector2(cos(a) * -side, sin(a)) * cr)
		var fill := pts.duplicate()
		fill.append(c)
		var col := lit_col.darkened(0.15) if area in lit else dim_col.darkened(0.25)
		draw_colored_polygon(fill, col)
		draw_polyline(pts, line, lw, true)
	draw_rect(Rect2(o, Vector2(w, h)), line, false, lw * 1.4)
	for i in [1, 2]:
		draw_line(o + Vector2(third * i, 0), o + Vector2(third * i, h), line, lw)
	draw_arc(o + Vector2(w, h) * 0.5, maxf(2.5, Court.CENTRE_R * k), 0, TAU, 16, line, lw, true)
	# The goal posts: hers to attack (coral, ringed), the one she defends (white).
	draw_circle(o + Vector2(lw * 1.2, h * 0.5), maxf(2.5, h * 0.03), line)
	var post := o + Vector2(w - lw * 1.2, h * 0.5)
	draw_circle(post, maxf(3.0, h * 0.045), Game.C_CORAL)
	draw_arc(post, maxf(5.0, h * 0.075), 0, TAU, 20, Game.C_CORAL, lw, true)
	# The arrow under the court: the way her team attacks.
	var ay := o.y + h + strip * 0.55
	var aw := maxf(2.0, h * 0.03)
	var head := strip * 0.42
	var x1 := o.x + w - 2.0
	draw_line(Vector2(o.x + w * 0.08, ay), Vector2(x1 - head, ay), Game.C_GOLD, aw, true)
	draw_colored_polygon(PackedVector2Array([Vector2(x1, ay), Vector2(x1 - head * 1.4, ay - head),
		Vector2(x1 - head * 1.4, ay + head)]), Game.C_GOLD)
	# Her opposite number, then her on top.
	var hb := h * 0.32
	var to_px := func(m: Vector2) -> Vector2:
		return o + Vector2((m.x + Court.HALF_L) * k, (m.y + Court.HALF_W) * k)
	_bib(to_px.call(lay.opp_at), hb * 0.76, lay.opp, Color(Game.C_CORAL, 0.95), Color(1, 1, 1, 0.9), Color.WHITE,
		Rect2(o, Vector2(w, h)))
	_bib(to_px.call(lay.at), hb, pos, Game.C_BG, Game.C_GOLD, Game.C_GOLD, Rect2(o, Vector2(w, h)))


## A bib hb tall centred at c (kept on the court r), its letters as big as fit.
func _bib(c: Vector2, hb: float, letters: String, fill: Color, edge: Color, ink: Color, r: Rect2) -> void:
	var wb := hb * 0.86
	var x0 := clampf(c.x - wb * 0.5, r.position.x + 2.0, r.end.x - wb - 2.0)
	var top := clampf(c.y - hb * 0.5, r.position.y + 2.0, r.end.y - hb - 2.0)
	var pts := BibButton.tabard(x0, top, wb, hb)
	draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, edge, maxf(1.5, hb * 0.05), true)
	var font: Font = Game.font_display
	var fs := int(hb * 0.56)
	while fs > 8 and font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > wb * 0.84:
		fs -= 1
	var tw := font.get_string_size(letters, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(x0 + (wb - tw) * 0.5, top + hb * 0.62 + font.get_ascent(fs) * 0.32), letters,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
