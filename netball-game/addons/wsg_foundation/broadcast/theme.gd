class_name WsgBroadcastTheme
extends Resource
## How a game's broadcast graphics look (the lower thirds, the score bug, the intro card): its colours, type and
## timing. Each game makes its own (Hurling: its gold and ink), or takes default().

@export var font: Font               # null: the game's theme's
@export var title_size := 30
@export var sub_size := 20
@export var panel := Color(0.06, 0.08, 0.1, 0.9)
@export var accent := Color(0.95, 0.75, 0.2)
@export var text := Color(1, 1, 1)
@export var sub_text := Color(0.85, 0.88, 0.9)
@export var radius := 6
@export var slide := 0.35            # s a card takes to come on or go off
@export var hold := 3.5              # s a lower third stays
## No sliding: cards fade (the player's accessibility setting).
@export var reduce_motion := false


static func default() -> WsgBroadcastTheme:
	return WsgBroadcastTheme.new()


func style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 18
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l
