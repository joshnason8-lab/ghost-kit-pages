class_name TacticsPanel
extends Control
## Your side's set-up, from the pause menu (TeamAI.tactics): a sweeper, two inside, the puck-outs. Each change is
## played at once and kept for your next match. Below, how the other side has set up.

var m: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 1.0)     # opaque: the pause menu is behind it
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := UI.safe_margins(self, 28.0)
	margin.add_theme_constant_override("margin_left", int(sm.x))
	margin.add_theme_constant_override("margin_right", int(sm.z))
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UI.round_button("back", func(): close(), 56))
	var title := UI.label(tr("TACTICS"), "HeaderLabel", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.shrink(title, 40, 0.6, 1)
	head.add_child(title)
	body.add_child(head)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var t: TeamAI = m.ai[m.user_team]
	v.add_child(UI.field(tr("TAC_SWEEPER"), UI.chips_row([tr("ON"), tr("OFF")], 0 if bool(t.tactics.sweeper) else 1, func(i):
		m.set_tactic("sweeper", i == 0))))
	v.add_child(UI.wrap(tr("TAC_SWEEPER_NOTE"), "MutedLabel", 17))
	v.add_child(UI.field(tr("TAC_TWO_FF"), UI.chips_row([tr("ON"), tr("OFF")], 0 if bool(t.tactics.two_ff) else 1, func(i):
		m.set_tactic("two_ff", i == 0))))
	v.add_child(UI.wrap(tr("TAC_TWO_FF_NOTE"), "MutedLabel", 17))
	v.add_child(UI.field(tr("TAC_PUCKOUT"), UI.chips_row([tr("TAC_PO_SHORT"), tr("TAC_PO_MIXED"), tr("TAC_PO_LONG")], int(t.tactics.puckout), func(i):
		m.set_tactic("puckout", i))))
	v.add_child(UI.wrap(tr("TAC_PUCKOUT_NOTE"), "MutedLabel", 17))
	var them: TeamAI = m.ai[1 - m.user_team]
	var parts := []
	if bool(them.tactics.sweeper):
		parts.append(tr("TAC_SWEEPER"))
	if bool(them.tactics.two_ff):
		parts.append(tr("TAC_TWO_FF"))
	parts.append(tr("TAC_PUCKOUT") + ": " + tr(["TAC_PO_SHORT", "TAC_PO_MIXED", "TAC_PO_LONG"][clampi(int(them.tactics.puckout), 0, 2)]))
	var opp := UI.wrap(tr("TAC_THEIRS").format({"team": DB.team_name(String(m.teams[1 - m.user_team].id)), "list": " · ".join(parts)}), "SubLabel", 19)
	opp.add_theme_color_override("font_color", Game.C_GOLD)
	v.add_child(opp)
	body.add_child(UI.scroll(v))


func close() -> void:
	queue_free()
