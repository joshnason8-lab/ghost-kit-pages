class_name Coach
extends Node
## Coach tips for a first-time player: the few things a first match needs, each shown once, at the moment it
## matters. The first turn chasing and the first turn defending stop the match on a card until "Got it"; the rest
## (the kho, the direction arrow, the touch and the dive, a foul) show for a few seconds without stopping play. On
## until your first match is finished (Game.settings.coach), and in Settings to turn on again.

const HOLD := 6.0

var m      # the match
var seen := {}
var _card: PanelContainer
var _text: Label
var _ok: Button
var _t := 0.0
var _chase_t := 0.0


func _init(p_match) -> void:
	m = p_match


func _ready() -> void:
	var root: Control = m.hud.root
	_card = PanelContainer.new()
	_card.theme_type_variation = "CardPanel"
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_top = 108
	_card.custom_minimum_size = Vector2(600, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_card.add_child(h)
	var ic := Icon.make("whistle", 30, Game.C_SAFFRON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	_text = UI.label("", "SubLabel", 20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size.x = 420
	UI.fit(_text, 3)
	h.add_child(_text)
	_ok = UI.button(tr("COACH_OK"), true, _dismiss)
	_ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ok.custom_minimum_size = Vector2(120, 56)
	h.add_child(_ok)
	_card.visible = false
	root.add_child(_card)


## Shows a tip once. stop: the match waits for "Got it".
func tip(key: String, stop := false) -> void:
	if seen.has(key) or not bool(Game.settings.get("coach", true)):
		return
	seen[key] = true
	_text.text = tr(key)
	UI.refit(_text)
	_card.visible = true
	_ok.visible = stop
	_t = HOLD if not stop else 0.0
	if stop:
		m.paused = true
		m.controls.enabled = false


func _dismiss() -> void:
	_card.visible = false
	if m.paused and not (m.hud._pause and is_instance_valid(m.hud._pause)):
		m.paused = false
		m.controls.enabled = true


func showing() -> bool:
	return _card.visible


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		if _t <= 0.0:
			_card.visible = false
	if m.paused or m.phase != "play":
		return
	if m._user_chasing():
		_chase_t += delta
		tip("COACH_CHASE", true)
		if _chase_t > 3.0 and not seen.has("COACH_KHO_READY"):
			tip("COACH_KHO")
		if m._kho_target(false) >= 0 and _chase_t > 1.0:
			tip("COACH_KHO_READY")
		if m.chase.dir != 0 and not m.chase.wazir and _chase_t > 9.0:
			tip("COACH_DIRECTION")
		if m.active and m._nearest_defender(m.active.position, 3.0) and _chase_t > 4.0:
			tip("COACH_TOUCH")
		if m.chase.foul != "":
			tip("COACH_FOUL")
	elif m.user == m.defending() and m.user_def:
		tip("COACH_DEFEND", true)
