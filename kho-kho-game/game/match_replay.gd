class_name MatchReplay
extends Node
## Kho kho's moments shown again (Medium and High, with the shared foundation: WsgReplay keeps every foundation body
## exactly as it was drawn). The play is cut into windows - each ends at an out, a dive that just missed, or a run the
## crowd rose to - and at most one replay is shown for each: the window's best moment, slowed, from low beside the
## field, the match held still meanwhile (its clock too) and the HUD away. Best first:
##   a sky dive that puts him out, and a pole dive that does (OUT_DIVE, OUT_POLE);
##   a pole turn (round the post and out the far side: only as part of a window that an out or a near thing ends);
##   a dive that just missed (Match._near_miss);
##   a long survival (the fast game's dream run; the classic game's last defender of a batch, alone 45 s and still in);
##   a touch out.
## Never in a turn's last 30 seconds (the HUD's clock is red then: it is not hidden). A tap skips it.

const PRIO := {"dive_out": 9, "pole_out": 9, "pole_turn": 7, "near_miss": 6, "survival": 5, "touch_out": 4}
## Seconds of play before and after the moment that the replay shows.
const SPAN := {"dive_out": [1.6, 1.2], "pole_out": [1.8, 1.2], "pole_turn": [0.8, 1.6], "near_miss": [1.4, 1.2],
	"survival": [3.0, 0.6], "touch_out": [2.0, 0.8]}
const RATE := 0.55             # slowed
const AFTER := 1.2             # s after a window's end before its replay (the dive lands, the umpire signals)
const LAST_S := 30.0           # none in a turn's last seconds (the clock)
const LONE_S := 45.0           # the classic game's long survival: the last of a batch, alone this long

var m                          # the Match
var rec: WsgReplay
var clock := 0.0               # seconds of live play drawn (not paused, not in a replay): the replays' clock
var moments: Array = []        # this window's: {kind, prio, t, t0, t1, who}
var window := 0                # windows ended so far
var shown: Array = []          # [window, kind] of each replay shown (tests)
var cur := {}                  # the replay playing: {t, t1, cam, who, kind, hud}
var _due := -1.0               # the clock at which this window's replay is due (-1: none)
var _ui: CanvasLayer
var _lone_batch := -1          # the batch whose lone survival has been marked


func _init(p_match) -> void:
	m = p_match
	name = "Replays"


func _ready() -> void:
	rec = WsgReplay.new()
	add_child(rec)


func playing() -> bool:
	return not cur.is_empty()


## Each frame of live play: kept, and this window's replay started when it is due.
func live(dt: float) -> void:
	clock += dt
	rec.record(clock)
	_lone()
	if _due >= 0.0 and clock >= _due:
		_due = -1.0
		start()


## A moment worth seeing again, kept in this window (who: whom the camera follows).
func moment(kind: String, who: Athlete) -> void:
	if not PRIO.has(kind) or who == null:
		return
	var sp: Array = SPAN[kind]
	# The same dive seen twice (its swerve, then the miss as he lands): one moment, the longer.
	for mo in moments:
		if mo.kind == kind and mo.who == who and clock - float(mo.t) < 1.6:
			mo.t1 = maxf(float(mo.t1), clock + float(sp[1]))
			return
	moments.append({"kind": kind, "prio": PRIO[kind], "t": clock, "t0": clock - float(sp[0]), "t1": clock + float(sp[1]),
		"who": who})


## The window ends (an out, a near thing, a long run): its replay is due shortly, once its moment has played out.
func close() -> void:
	if _due < 0.0:
		_due = clock + AFTER


## The window's best moment (the highest first, then the latest), or {} for none worth it or no longer kept.
func best() -> Dictionary:
	var sp := rec.span()
	var out := {}
	for mo in moments:
		if sp.is_empty() or float(mo.t0) < float(sp[0]) - 0.3 or not is_instance_valid(mo.who):
			continue
		if out.is_empty() or int(mo.prio) > int(out.prio) or int(mo.prio) == int(out.prio) and float(mo.t) > float(out.t):
			out = mo
	return out


## This window's replay, if it has a moment and the match can stop for it. True when one has begun.
func start() -> bool:
	var mo := best()
	moments = []
	window += 1
	if mo.is_empty() or m.phase != "play" or m.clock < LAST_S or m.paused:
		return false
	var sp := rec.span()
	var t0 := maxf(float(mo.t0), float(sp[0]))
	var t1 := minf(float(mo.t1), float(sp[1]))
	if t1 <= t0 + 0.8:
		return false
	var rc := Camera3D.new()
	rc.fov = 38.0
	rc.near = 0.1
	rc.far = 160.0
	add_child(rc)
	rec.play(t0, t1)
	cur = {"t": t0, "t1": t1, "cam": rc, "who": mo.who, "kind": mo.kind, "hud": m.hud.visible if m.hud else false}
	if m.hud:
		m.hud.visible = false
		m.controls.enabled = false
	_show_ui(true)
	FoundationLink.frozen = true
	for a in m.everyone():
		a.process_mode = Node.PROCESS_MODE_DISABLED
	step(0.0)
	rc.make_current()
	shown.append([window, String(mo.kind)])
	m.game_event.emit("replay")
	return true


## The replay's subject as drawn now (where his foundation body stood then, at his middle).
func _focus() -> Vector3:
	var who: Athlete = cur.who
	if is_instance_valid(who) and who.link and who.link.body:
		return who.link.body.global_position + Vector3.UP * 0.8
	return who.global_position + Vector3.UP * 0.8 if is_instance_valid(who) else Vector3.UP


func step(delta: float) -> void:
	var t: float = float(cur.t) + minf(delta, 0.05) * RATE
	cur.t = t
	if t >= float(cur.t1):
		end()
		return
	rec.seek(t)
	var f := _focus()
	f.y = clampf(f.y, 0.4, 1.0)
	# From the near touchline, low and close, a little ahead of him, moving with him smoothly.
	var want_pos := Vector3(f.x + 1.5, 2.1, f.z + 6.5)
	var rc: Camera3D = cur.cam
	var k := 1.0 if delta <= 0.0 else minf(1.0, delta * 3.0)
	cur["pos"] = (cur.get("pos", want_pos) as Vector3).lerp(want_pos, k)
	cur["look"] = (cur.get("look", f) as Vector3).lerp(f, k)
	rc.global_position = cur.pos
	rc.look_at(cur.look)
	# The players' blob shadows under the bodies as drawn then.
	m.shadows_at_drawn()


## Back to the match: the bodies following the game again, the match's camera, the HUD.
func end() -> void:
	if cur.is_empty():
		return
	var r := cur
	cur = {}
	rec.stop()
	FoundationLink.frozen = false
	for a in m.everyone():
		a.process_mode = Node.PROCESS_MODE_INHERIT
	(r.cam as Camera3D).queue_free()
	m.cam.make_current()
	if m.hud:
		m.hud.visible = bool(r.hud)
		m.controls.enabled = not m.paused
	_show_ui(false)


## The classic game's long survival: the last of a batch still in after LONE_S alone, with the chase on him.
var _alone := 0.0


func _lone() -> void:
	if m.phase != "play" or m.active == null:
		_alone = 0.0
		return
	var live := []
	for a in m.batch:
		if m.d_state.get(a, "") == "in":
			live.append(a)
	if live.size() != 1 or m.batch_k == _lone_batch:
		_alone = 0.0
		return
	_alone += get_process_delta_time()
	var d: Athlete = live[0]
	if _alone >= LONE_S and (d.position - m.active.position).length() < 3.0:
		_lone_batch = m.batch_k
		moment("survival", d)
		close()


## "Replay" in the top corner while one plays (in the player's language and the game's type).
func _show_ui(on: bool) -> void:
	if _ui == null:
		_ui = CanvasLayer.new()
		_ui.layer = 5
		add_child(_ui)
		var frame := MarginContainer.new()
		frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.theme = Game.theme
		var mg := UI.safe_margins(frame, 28.0)
		frame.add_theme_constant_override("margin_left", int(mg.x))
		frame.add_theme_constant_override("margin_top", int(mg.y))
		_ui.add_child(frame)
		var pill := UI.pill(tr("REPLAY"), Game.C_SAFFRON, true)
		pill.name = "ReplayPill"
		(pill.get_child(0) as Label).add_theme_font_size_override("font_size", Game.ts(22))
		frame.add_child(pill)
	_ui.visible = on


## A tap (or a key) skips it.
func _input(event: InputEvent) -> void:
	if cur.is_empty():
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		end()
