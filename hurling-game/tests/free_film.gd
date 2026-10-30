extends Node
## Free-taking filmed for the foundation pilot's before and after (WSG_OFF=1: the game as it is today): through the
## game's own cameras, aimed as a player would (the target low in the middle, then the bar in the green).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie out.avi res://tests/free_film.tscn -- <part>
## part: "free" (two frees in practice: from 21 m in front, then 30 m out to the left) or "shootout" (extra time's
## shoot-out: the first two penalties, yours then theirs).

var part := "free"
var m: Node
var label: Label
var taken := 0
var t := 0.0
var _last := -1


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	part = a[0] if a.size() > 0 else "free"
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	if part == "free":
		m = load("res://game/practice.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 7, "mode": "practice"}
	else:
		m = load("res://game/match.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 5, "length": 8.0,
			"mode": "champ", "knockout": true}
	add_child(m)
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	label = Label.new()
	label.position = Vector2(24, 64)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	cl.add_child(label)
	if part == "shootout":
		await get_tree().process_frame
		await get_tree().process_frame
		m._begin_shootout()


func _process(delta: float) -> void:
	t += delta
	var tag := "AFTER: the shared foundation" if FoundationLink.enabled() else "BEFORE: the game today"
	if OS.has_environment("FILM_TAG"):
		tag = OS.get_environment("FILM_TAG")
	label.text = "%s     %s" % [tag, "a free in practice" if part == "free" else "the extra-time shoot-out"]
	if m.placed_aim != null and not m.placed_aim.stopped and m.user_buttons() == ["SHOOT"] and t > 0.5:
		# A beat to see the stance, then aimed: low in the middle (a goal) or over the bar.
		if m.placed_aim.get_meta("film_t", -1.0) < 0.0:
			m.placed_aim.set_meta("film_t", t)
		if t - float(m.placed_aim.get_meta("film_t")) > 1.0:
			m.placed_aim.angle = PI * 0.5 if part == "free" else PI * 1.5
			m.placed_aim._place()
			m._on_action("SHOOT")
			m.placed_aim.bar_x = 0.0
			m._on_action("SHOOT")
	if part == "free":
		var n := int(m.practice.get("n", 0))
		if n != _last:
			_last = n
			taken = n
		if taken >= 2 and String(m.practice.state) != "done" or t > 26.0:
			print("free film: %d taken %s in %.1f s" % [taken, m.practice.get("marks", []), t])
			get_tree().quit()
	else:
		var n: int = int(m.shootout.taken[0]) + int(m.shootout.taken[1])
		if n >= 2 and String(m.shootout.state) == "ready" or t > 30.0 or m.phase == m.P.OVER:
			print("shoot-out film: %d taken, goals %s in %.1f s" % [n, m.shootout.goals, t])
			get_tree().quit()
