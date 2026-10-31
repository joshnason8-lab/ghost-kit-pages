class_name WsgLowerThird
extends Control
## A name on the screen, low on the left as television puts it: a colour stripe (the player's county), the title (a
## name) and a line under it (what they did: "0-3 today"), sliding on and off (or fading, theme.reduce_motion).
## Text goes through tr(): give it keys or words already in the player's language.
##   var lt := WsgLowerThird.new(theme); hud_layer.add_child(lt)
##   lt.show_card("Tomás Ó Briain", "1-02 today", county_colour)

var theme_b: WsgBroadcastTheme
var _box: PanelContainer
var _title: Label
var _sub: Label
var _stripe: ColorRect
var _tw: Tween
var _seq := 0


func _init(p_theme: WsgBroadcastTheme = null) -> void:
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(8, 0)
	row.add_child(_stripe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_title = theme_b.label("", theme_b.title_size, theme_b.text)
	_sub = theme_b.label("", theme_b.sub_size, theme_b.sub_text)
	col.add_child(_title)
	col.add_child(_sub)
	_box.modulate.a = 0.0


## On for seconds (the theme's hold if 0), then off.
func show_card(title: String, sub := "", colour := Color(), seconds := 0.0) -> void:
	_seq += 1
	var seq := _seq
	_title.text = tr(title)
	_sub.text = tr(sub)
	_sub.visible = sub != ""
	_stripe.color = colour if colour.a > 0.0 else theme_b.accent
	await get_tree().process_frame     # (the box's size for its text)
	var safe := _safe_rect()
	var at := Vector2(safe.position.x + safe.size.x * 0.04, safe.end.y - _box.size.y - safe.size.y * 0.08)
	if _tw:
		_tw.kill()
	_tw = create_tween()
	if theme_b.reduce_motion:
		_box.position = at
		_tw.tween_property(_box, "modulate:a", 1.0, theme_b.slide)
	else:
		_box.position = at - Vector2(_box.size.x + 40.0, 0)
		_box.modulate.a = 1.0
		_tw.tween_property(_box, "position", at, theme_b.slide).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds if seconds > 0.0 else theme_b.hold).timeout
	if seq == _seq:
		hide_card()


func hide_card() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	if theme_b.reduce_motion:
		_tw.tween_property(_box, "modulate:a", 0.0, theme_b.slide)
	else:
		_tw.tween_property(_box, "position:x", -_box.size.x - 40.0, theme_b.slide).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _safe_rect() -> Rect2:
	var vp := get_viewport_rect()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or not OS.has_feature("mobile"):
		return vp
	var win := Vector2(DisplayServer.window_get_size())
	var k := vp.size / win if win.x > 0.0 else Vector2.ONE
	return Rect2(safe.position * k, safe.size * k)
