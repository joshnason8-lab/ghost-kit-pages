class_name WsgSimInput
extends RefCounted
## WsgSim's human player: a seeded stream of what a person does to the game, through the game's own input path
## (InputEventAction and the gamepad's left stick through Input.parse_input_event, or the game's own touch stick:
## WsgSimGame.stick). Every so many frames a new stick plan - swept round all 8 ways, held one way, circled, jittered
## frame to frame, let go - and now and then: a tap of any of the game's actions, a mash (five taps in ten frames), a
## double tap, a pause and resume, the app sent to the background and back, the screen turned, the camera switched
## (the joystick on every camera). summary() counts what it did.

var game: WsgSimGame
var tree: SceneTree
var rng := RandomNumberGenerator.new()
var actions: Array = []
var counts := {}

var _plan := ""
var _plan_end := 0
var _dir := Vector2.ZERO
var _release := {}        # action -> frame to let go
var _resume_at := -1
var _fore_at := -1


func _init(p_game: WsgSimGame, seed: int, p_tree: SceneTree) -> void:
	game = p_game
	tree = p_tree
	rng.seed = seed
	actions = game.input_actions()


func tick(frame: int) -> void:
	# The stick.
	if frame >= _plan_end:
		_plan = ["sweep", "hold", "circle", "jitter", "release"][rng.randi() % 5]
		_plan_end = frame + rng.randi_range(15, 90)
		_dir = Vector2.from_angle(rng.randf() * TAU)
		_count("stick " + _plan)
	var v := Vector2.ZERO
	match _plan:
		"sweep":
			v = Vector2.from_angle(floorf(frame / 8.0) * PI / 4.0)
		"hold":
			v = _dir
		"circle":
			v = Vector2.from_angle(frame * 0.2)
		"jitter":
			v = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.0)
	_stick(v)
	# Taps and their releases.
	for a in _release.keys():
		if frame >= int(_release[a]):
			_action(String(a), false)
			_release.erase(a)
	if not actions.is_empty():
		if rng.randf() < 0.04:
			_tap(actions[rng.randi() % actions.size()], frame, rng.randi_range(1, 12))
			_count("tap")
		if rng.randf() < 0.005:
			var a: String = actions[rng.randi() % actions.size()]
			for k in 5:
				_action(a, true)
				_action(a, false)
			_count("mash")
		if rng.randf() < 0.005:
			var a: String = actions[rng.randi() % actions.size()]
			_action(a, true)
			_action(a, false)
			_action(a, true)
			_release[a] = frame + 2
			_count("double tap")
	# Pause and resume.
	if _resume_at < 0 and rng.randf() < 0.001:
		_pause_key()
		_resume_at = frame + rng.randi_range(15, 120)
		_count("pause")
	elif _resume_at >= 0 and frame >= _resume_at:
		_pause_key()
		_resume_at = -1
	# The app to the background and back.
	if _fore_at < 0 and rng.randf() < 0.001:
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		_fore_at = frame + rng.randi_range(5, 60)
		_count("background")
	elif _fore_at >= 0 and frame >= _fore_at:
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_fore_at = -1
	# The screen turned (portrait and landscape swapped: the layout's size changes).
	if rng.randf() < 0.0005:
		var sz := tree.root.content_scale_size
		tree.root.content_scale_size = Vector2i(sz.y, sz.x) if sz != Vector2i.ZERO else Vector2i(720, 1280)
		tree.root.size_changed.emit()
		_count("rotate")
	# Another camera.
	var cams := game.cameras()
	if cams.size() > 1 and rng.randf() < 0.003:
		game.set_camera(rng.randi() % cams.size())
		_count("camera")


func summary() -> Dictionary:
	return counts


func _stick(v: Vector2) -> void:
	if game.stick(v):
		return
	for ax in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var e := InputEventJoypadMotion.new()
		e.axis = ax[0]
		e.axis_value = ax[1]
		Input.parse_input_event(e)


func _tap(a: String, frame: int, hold: int) -> void:
	_action(a, true)
	_release[a] = frame + hold


func _action(a: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = down
	e.strength = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _pause_key() -> void:
	var a := "pause" if InputMap.has_action("pause") else "ui_cancel"
	_action(a, true)
	_action(a, false)


func _count(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1
