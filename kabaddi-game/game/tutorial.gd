class_name Tutorial
extends Node
## Training Ground lesson running inside a match: shows the objective, counts the
## events the match reports, and returns to the lesson list when done.

const LESSONS := [
	{"id": "cant", "title": "TUT_CANT_T", "raid": true, "passive": true, "steps": [
		["TUT_CANT_1", "cant", 6], ["TUT_CANT_2", "entered", 1], ["TUT_CANT_3", "baulk", 1]]},
	{"id": "touch", "title": "TUT_TOUCH_T", "raid": true, "passive": true, "steps": [
		["TUT_TOUCH_1", "touch", 1], ["TUT_TOUCH_2", "raid_point", 1]]},
	{"id": "toe", "title": "TUT_TOE_T", "raid": true, "passive": true, "steps": [
		["TUT_TOE_1", "toe_touch", 1], ["TUT_TOUCH_2", "raid_point", 1]]},
	{"id": "bonus", "title": "TUT_BONUS_T", "raid": true, "passive": true, "steps": [
		["TUT_BONUS_1", "bonus", 1], ["TUT_TOUCH_2", "raid_point", 1]]},
	{"id": "kick", "title": "TUT_KICK_T", "raid": true, "passive": true, "steps": [
		["TUT_KICK_1", "back_kick", 1], ["TUT_TOUCH_2", "raid_point", 1]]},
	{"id": "dubki", "title": "TUT_DUBKI_T", "raid": true, "passive": true, "chains": true, "steps": [
		["TUT_DUBKI_1", "dubki", 1], ["TUT_TOUCH_2", "raid_point", 1]]},
	{"id": "lion", "title": "TUT_LION_T", "raid": true, "passive": false, "style": "ankle", "steps": [
		["TUT_LION_1", "lion_jump", 1]]},
	{"id": "escape", "title": "TUT_ESCAPE_T", "raid": true, "passive": false, "steps": [
		["TUT_ESCAPE_1", "broke_free", 1]]},
	{"id": "tackle", "title": "TUT_TACKLE_T", "raid": false, "passive": false, "steps": [
		["TUT_TACKLE_1", "tackle", 1]]},
	{"id": "chain", "title": "TUT_CHAIN_T", "raid": false, "passive": false, "steps": [
		["TUT_CHAIN_1", "chain", 1], ["TUT_CHAIN_2", "tackle", 1]]},
	{"id": "waist", "title": "TUT_WAIST_T", "raid": false, "passive": false, "steps": [
		["TUT_WAIST_1", "waist_hold", 1]]},
	{"id": "dash", "title": "TUT_DASH_T", "raid": false, "passive": false, "wide": true, "steps": [
		["TUT_DASH_1", "dash_out", 1]]},
]

var m
var lesson: Dictionary
var step := 0
var count := 0
var done := false


static func lesson_by_id(id: String) -> Dictionary:
	for l in LESSONS:
		if l.id == id:
			return l
	return LESSONS[0]


## Match config for a lesson.
static func match_config(id: String) -> Dictionary:
	var l := lesson_by_id(id)
	return {
		"home": "MUM", "away": "DEL", "arena": "dome", "mode": "tutorial", "lesson": id, "control": "all",
		"difficulty": 0, "length": 0, "passive": l.passive, "first_raider": 0 if l.raid else 1,
		"raid_rule": _lesson_rule(id),
		"chains": l.get("chains", false), "style": l.get("style", ""), "wide": l.get("wide", false),
	}


## The cant lesson teaches the cant you play with (Breath if you play with the clock).
static func _lesson_rule(id: String) -> int:
	var r := int(Game.settings.get("raid_rule", 2))
	if id == "cant" and r == 0:
		return 2
	return r


## The text for a step: the cant's first step depends on how you chant.
static func step_key(key: String, rule: int) -> String:
	if key == "TUT_CANT_1":
		return ["TUT_CANT_1", "TUT_CANT_1", "TUT_CANT_1_BREATH"][clampi(rule, 0, 2)]
	return key


func setup(p_match, id: String) -> void:
	m = p_match
	lesson = lesson_by_id(id)
	m.tutorial_event.connect(_on_event)
	_show()


func next_raiding_team(_current: int) -> int:
	return 0 if lesson.raid else 1


func _show() -> void:
	if done:
		return
	var st: Array = lesson.steps[step]
	var key := step_key(String(st[0]), int(m.raid_rule))
	var text: String = tr(key)
	if int(st[2]) > 1:
		text += "  (%d/%d)" % [count, int(st[2])]
	m.hud.set_objective(tr(lesson.title), text)


func _on_event(name: String) -> void:
	if done:
		return
	var st: Array = lesson.steps[step]
	if name != st[1]:
		return
	count += 1
	if count >= int(st[2]):
		step += 1
		count = 0
		Sfx.play("bid", -4.0, 1.3)
		if step >= lesson.steps.size():
			_complete()
			return
	_show()


func _complete() -> void:
	done = true
	m.hud.set_objective(tr(lesson.title), tr("TUT_DONE"))
	m.hud.banner(tr("TUT_DONE"))
	Sfx.play("roar", -6.0)
	var finished: Array = Game.settings.get("tutorial_done", [])
	if not finished.has(lesson.id):
		finished.append(lesson.id)
	Game.settings.tutorial_done = finished
	Game.save_settings()
	await get_tree().create_timer(2.8).timeout
	if is_inside_tree():
		Sfx.stop_all()
		Game.show_screen("res://ui/tutorial_menu.gd")
