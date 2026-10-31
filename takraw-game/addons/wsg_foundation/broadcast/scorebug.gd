class_name WsgScorebug
extends Control
## The score in the top corner, as television shows it: two rows (each side's colour, short name, score - in the
## game's own form: hurling's "1-07", kabaddi's "23"), the clock and the period beside them; a score that changes
## flashes. Themed (WsgBroadcastTheme); short names through tr().
##   var bug := WsgScorebug.new(theme); layer.add_child(bug)
##   bug.setup(["KIL", Color.BLACK, Color.GOLD], ["TIP", Color.BLUE, Color.GOLD])
##   bug.set_score("1-07", "0-09"); bug.set_clock("23:41", "1st half")

var theme_b: WsgBroadcastTheme
var _rows: Array = []      # [chip, name, score] per side
var _clock: Label
var _period: Label


func _init(p_theme: WsgBroadcastTheme = null) -> void:
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	box.position = Vector2(18, 18)
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	row.add_child(grid)
	for side in 2:
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(10, 26)
		var name := theme_b.label("", theme_b.sub_size, theme_b.text)
		var score := theme_b.label("", theme_b.sub_size, theme_b.text)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.custom_minimum_size.x = 64
		grid.add_child(chip)
		grid.add_child(name)
		grid.add_child(score)
		_rows.append([chip, name, score])
	var right := VBoxContainer.new()
	row.add_child(right)
	_clock = theme_b.label("0:00", theme_b.sub_size + 4, theme_b.accent)
	_period = theme_b.label("", theme_b.sub_size - 6, theme_b.sub_text)
	right.add_child(_clock)
	right.add_child(_period)


## Each side: [short name, main colour, second colour].
func setup(a: Array, b: Array) -> void:
	for side in 2:
		var s: Array = [a, b][side]
		(_rows[side][0] as ColorRect).color = s[1]
		(_rows[side][1] as Label).text = tr(String(s[0]))


func set_score(a: String, b: String) -> void:
	for side in 2:
		var l: Label = _rows[side][2]
		var t: String = [a, b][side]
		if l.text != t and l.text != "":
			var tw := create_tween()
			l.modulate = theme_b.accent
			tw.tween_property(l, "modulate", Color.WHITE, 0.8)
		l.text = t


func set_clock(clock: String, period := "") -> void:
	_clock.text = clock
	_period.text = tr(period)
	_period.visible = period != ""
