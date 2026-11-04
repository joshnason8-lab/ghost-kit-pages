class_name Raga
extends Node3D
## Sepak raga bulatan (the ROADMAP's idea for fans): the old game of keeping the ball up in a circle with your
## team-mates for as long as you can. Six players in a ring on the park's court, you one of them, nearest the camera;
## the ball passed round by kicks (the inside of the foot, the knee, the head), never caught. When it comes to you,
## press as the ring closes on the ball (the match's timing and its windows, by your difficulty): perfect or good and
## it goes on, a scrappy one lower, too early, too late or not at all and it falls. How many touches in a row: your
## best is kept in the record book. The game's own bodies on every graphics level, as on Low (no new assets).
##   Raga.open(buttons): from the home screen, behind the loading overlay.  config: auto (everyone played for you:
##   the tests), seed, team (whose players).

const N := 6
const RING_R := 2.4                  # m: the circle's radius
const CENTRE := Vector3(-3.4, 0, 0)  # on one half of the court, clear of the net
const APEX := [3.2, 4.4]             # how high the ball is lobbed (m)
const AI_MISS := 0.015               # a team-mate's touch going wrong: they are good, not perfect
const MOVES := [["sila", 0.7], ["thigh", 0.18], ["header", 0.12]]   # how a touch is played, how often
const OPEN := 1.1                    # s before a touch of yours that the ring opens (the match's)
## Seconds either side of the moment, by difficulty: perfect, good, scrappy (Match.timing_windows).
const TIMING := [[0.09, 0.2, 0.34], [0.07, 0.16, 0.28], [0.055, 0.13, 0.23], [0.045, 0.11, 0.19]]

var config := {}
var players: Array = []
var me := 0                # your place in the ring
var arena: Arena
var ball: Ball
var cam: Camera3D
var now := 0.0
var touches := 0
var best := 0
var new_best := false
var state := "build"       # build, play, down
var rng := RandomNumberGenerator.new()
## Every touch, for the tests: [who, move, contact (world), where he stood then, quality 0-1].
var touch_log: Array = []
var _from := -1            # who touched it last
var _to := -1              # who touches it next
var _t := 0.0              # when (now) it meets him
var _move := ""            # how
var _contact := Vector3.ZERO
var _press := -1.0         # when you pressed for this touch (now), or -1
var _result := ""          # your last touch: PERFECT, GOOD, EARLY, LATE, MISS
var _result_t := 0.0
var _down_t := -1.0
var _ui: Control
var _ring: Control
var _count: Label
var _best: Label
var _hint: Label
var _end: VBoxContainer
var _end_text: Label


## From the home screen: the circle built behind the loading overlay (the venue a part at a time), then begun.
static func open(buttons: Array = []) -> void:
	if WsgLoading.busy():
		return
	var ld := WsgLoading.cover(Game.main, buttons, Game.load_look())
	ld.parts().root.theme = Game.theme
	ld.log_label = "raga"
	var built := {}
	ld.step("Circle", func():
		var r := Raga.new()
		r.config = {"staged": true}
		r.process_mode = Node.PROCESS_MODE_DISABLED
		Sfx.music(false)
		Game._swap(r)
		ld.parts().dim.color.a = 1.0
		built.r = r)
	ld.step("Venue", func(): await built.r.build(ld), 3.0)
	ld.warm(func(): return built.r, "Drawing", 4.0)
	if not await ld.run():
		return
	await ld.done()
	if is_instance_valid(built.get("r")) and built.r == Game.current:
		built.r.process_mode = Node.PROCESS_MODE_INHERIT
		built.r.begin()


func setup(args: Dictionary) -> void:
	config = args


func _ready() -> void:
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	best = int(Game.records.get("best_raga", 0))
	if not bool(config.get("staged", false)):
		await build()
		begin()


## The park, the ball, the six in their ring, the camera over your shoulder, the screen's words.
func build(ld: WsgLoading = null) -> void:
	var team := DB.team(String(config.get("team", "THA")))
	var c1: Color = team.get("c1", Game.C_SAFFRON)
	var c2: Color = team.get("c2", Color.WHITE)
	arena = Arena.new("park", false, [c1, c2])
	arena.deferred = ld != null
	add_child(arena)
	if ld:
		await arena.build(ld)
	ball = Ball.new()
	ball.bounds = arena.bounds
	ball.solid = arena.solid
	ball.soft = arena.sand()
	ball.bounced.connect(func(at: Vector3, speed: float): Sfx.bounce(at, lerpf(-16.0, -2.0, clampf((speed - 1.2) / 6.0, 0.0, 1.0))))
	add_child(ball)
	ball.hold(Vector3(0, -5, 0))
	var squad: Array = DB.squad(String(config.get("team", "THA")))
	for i in N:
		var pd: Dictionary = squad[i % squad.size()]
		var look := {"skin": pd.get("skin", Color("c98a5a")), "jersey": c1, "shorts": c2.darkened(0.3) if c2.get_luminance() > 0.7 else c2,
			"height": float(pd.get("height", 1.76)), "women": false}
		var p := Player.new(pd, 0, int(pd.get("pos", DB.POS_STRIKER)), look)
		p.solid = arena.solid
		add_child(p)
		p.position = home(i)
		p.target = p.position
		p.face_to = CENTRE
		players.append(p)
	(players[me] as Player).set_mine(true)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = CENTRE + Vector3(0, 5.0, 7.4)
	cam.look_at(CENTRE + Vector3(0, 1.3, 0))
	cam.current = true
	_build_ui()


## A player's place in the ring: you (0) in front, nearest the camera, the others round from you.
func home(i: int) -> Vector3:
	var a := PI * 0.5 + TAU * float(i) / float(N)
	return CENTRE + Vector3(cos(a), 0, sin(a)) * RING_R


## A run begins: the player across from you drops the ball onto his own foot.
func begin() -> void:
	state = "play"
	touches = 0
	new_best = false
	touch_log.clear()
	_from = -1
	_press = -1.0
	_down_t = -1.0
	if _end:
		_end.visible = false
	var first := (me + N / 2) % N
	var p: Player = players[first]
	var drop := p.position + (CENTRE - p.position).normalized() * 0.3 + Vector3(0, 1.25, 0)
	_pass(first, drop, now, 1.7)
	_update_ui()


## The ball on its way from FROM (world, at time AT) up to APEX and down to player TO, met with a move of his: he
## goes to where that move meets it (a step off his place, as passes are), the move timed so it does.
func _pass(to: int, from: Vector3, at: float, apex: float, spread := 0.3) -> void:
	_to = to
	_press = -1.0
	_move = _pick_move()
	var p: Player = players[to]
	var c: Array = Moves.CONTACT[_move]
	var s := p.body.scale.y
	var face := (CENTRE - home(to)).normalized()
	var right := Vector3(-face.z, 0, face.x)
	var mirror := _move != "header" and rng.randf() < 0.3
	var stand := home(to) + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
	_contact = stand + face * float(c[1]) * s + right * float(c[2]) * s * (-1.0 if mirror else 1.0) + Vector3(0, float(c[0]) * s, 0)
	var sol: Array = Ball.solve_apex(from, _contact, apex)
	ball.launch(from, sol[0], at, false)
	_t = at + float(sol[1])
	p.target = stand
	p.queue_move(_move, _t - Moves.contact_time(_move), mirror)


func _pick_move() -> String:
	var r := rng.randf()
	for m in MOVES:
		r -= float(m[1])
		if r <= 0.0:
			return String(m[0])
	return "sila"


## Who it goes to next: anyone but the one who played it and the one before (so it goes round), you a little more
## often than the rest (it is your game).
func _next_of(i: int) -> int:
	var pick := []
	for j in N:
		if j != i and j != _from:
			pick.append(j)
			if j == me:
				pick.append(j)
	return int(pick[rng.randi_range(0, pick.size() - 1)])


func _process(delta: float) -> void:
	if state == "build":
		return
	var dt := minf(delta, 0.1)
	now += dt
	ball.update_to(now, dt)
	for p in players:
		(p as Player).look_at_pos = ball.global_position
		(p as Player).tick(dt, now)
	if state == "play" and now >= _t:
		_touch()
	_result_t = maxf(0.0, _result_t - dt)
	if state == "down" and _down_t >= 0.0 and now - _down_t > 1.2 and _end and not _end.visible:
		_end.visible = true
	_ring.queue_redraw()


## The touch: yours as you pressed for it, a team-mate's as he is (now and then it goes wrong). Made, the ball goes on
## to the next player (lower, and less sure where, off a scrappy touch of yours); missed, it falls.
func _touch() -> void:
	var p: Player = players[_to]
	var q := 1.0
	var made := true
	if _to == me and not bool(config.get("auto", false)):
		q = _quality()
		made = q > 0.0
	elif rng.randf() < AI_MISS:
		made = false
		q = 0.0
	touch_log.append([_to, _move, _contact, p.position, q])
	if not made:
		_drop()
		return
	touches += 1
	Sfx.play_at("knee" if _move in ["thigh", "header"] else "kick", _contact, -3.0)
	var nxt := _next_of(_to)
	_from = _to
	var apex := lerpf(float(APEX[0]), float(APEX[1]), rng.randf()) * (1.0 if q >= 0.8 else 0.82)
	_pass(nxt, _contact, _t, apex, 0.3 if q >= 0.8 else 0.55)
	_update_ui()


## How your press went: perfect or good, a clean touch; within the last window, a scrappy one; else (or none) a miss.
func _quality() -> float:
	var w: Array = TIMING[clampi(int(Game.settings.difficulty), 0, TIMING.size() - 1)]
	_result_t = 0.8
	if _press < 0.0:
		_result = "MISS"
		return 0.0
	var err := absf(_press - _t)
	_result = "LATE" if _press > _t else "EARLY"
	if err <= float(w[0]):
		_result = "PERFECT"
		return 1.0
	if err <= float(w[1]):
		_result = "GOOD"
		return 0.8
	if err <= float(w[2]):
		return 0.55
	return 0.0


## Down: it falls from where it was, and your best is kept if this run beat it.
func _drop() -> void:
	state = "down"
	_down_t = now
	ball.set_loose(now)
	if touches > best:
		best = touches
		new_best = touches > 0
		Game.records["best_raga"] = best
		Game.save_records()
	_update_ui()


## Your press (a tap anywhere but a button, or Space): counts for your touch once its ring is open.
func press() -> void:
	if state == "play" and _to == me and _press < 0.0 and _t - now <= OPEN:
		_press = now


func _unhandled_input(e: InputEvent) -> void:
	var down: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_ENTER])
	if down:
		press()
		get_viewport().set_input_as_handled()


## The phone's Back: home.
func on_back() -> void:
	Game.goto_menu()


# ---------------------------------------------------------------- the screen

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = Game.theme
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_ui.add_child(_ring)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 18
	top.add_theme_constant_override("separation", 16)
	_ui.add_child(top)
	top.add_child(UI.round_button("back", func(): Game.goto_menu()))
	var title := UI.fit(UI.label(tr("MENU_RAGA"), "HeaderLabel", 30))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var score := VBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(score)
	_count = UI.label("0", "HeaderLabel", 52, Game.C_GOLD)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_child(_count)
	_best = UI.label("", "MutedLabel", 18)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_child(_best)
	_hint = UI.wrap(tr("RAGA_HINT"), "SubLabel", 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 60
	_hint.offset_right = -60
	_hint.offset_top = -86
	_hint.offset_bottom = -24
	_ui.add_child(_hint)
	_end = VBoxContainer.new()
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end.alignment = BoxContainer.ALIGNMENT_CENTER
	_end.add_theme_constant_override("separation", 14)
	_end.visible = false
	_ui.add_child(_end)
	var card := UI.card()
	_end.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	_end_text = UI.wrap("", "HeaderLabel", 30)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.custom_minimum_size.x = 520
	cv.add_child(_end_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UI.button(tr("RAGA_AGAIN"), true, func(): begin()))
	row.add_child(UI.button(tr("RAGA_HOME"), false, func(): Game.goto_menu()))
	cv.add_child(row)
	_update_ui()


func _update_ui() -> void:
	if _count == null:
		return
	_count.text = str(touches)
	_best.text = tr("RAGA_BEST").format({"n": best})
	_hint.visible = state == "play" and touches < 3
	if state == "down":
		_end_text.text = tr("RAGA_DOWN").format({"n": touches}) + ("\n" + tr("RAGA_NEW_BEST") if new_best else "")


## The match's ring on your touches: the gold circle where the ball will be met, a ring closing on it (green once
## a press would be good), and how your press went.
func _draw_ring() -> void:
	if cam == null:
		return
	if state == "play" and _to == me:
		var left := _t - now
		if left <= OPEN and not cam.is_position_behind(_contact):
			var sp := cam.unproject_position(_contact)
			var k := clampf(left / OPEN, 0.0, 1.0)
			var w: Array = TIMING[clampi(int(Game.settings.difficulty), 0, TIMING.size() - 1)]
			var good := left <= float(w[1])
			_ring.draw_arc(sp, 26.0, 0, TAU, 40, Color(Game.C_GOLD, 0.85), 3.0, true)
			_ring.draw_arc(sp, 26.0 + 74.0 * k, 0, TAU, 48, Game.C_GOOD if good else Color(Game.C_INK, 0.8), 4.0, true)
	if _result_t > 0.0 and _result != "":
		var col: Color = {"PERFECT": Game.C_GOLD, "GOOD": Game.C_GOOD, "EARLY": Game.C_MUTED, "LATE": Game.C_MUTED, "MISS": Game.C_DANGER}.get(_result, Game.C_INK)
		var f: Font = Game.font_display
		var txt := tr("TIMING_" + _result)
		var at := cam.unproject_position((players[me] as Player).position + Vector3(0, 2.3, 0))
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 30)
		_ring.draw_string(f, at - Vector2(sz.x * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(col, minf(1.0, _result_t * 2.5)))
