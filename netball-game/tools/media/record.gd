extends Node
## The trailer's footage: an AI v AI match on High (as broadcast: the scoreboard, no buttons, no debug overlay),
## played at a fixed 30 fps, with only the frames asked for drawn and saved as JPEGs (the rest of the match runs
## without drawing, so minutes of play cost seconds). Used by tools/media/make_media_kit.sh in two passes:
##   scan:  godot --path . --fixed-fps 30 res://tools/media/record.tscn -- OUT_DIR VENUE HOME AWAY SEED FRAMES
##          writes OUT_DIR/events.json (each event's frame: goals, shots, misses, centre passes), draws nothing.
##   shoot: ... -- OUT_DIR VENUE HOME AWAY SEED FRAMES A-B,C-D,...
##          plays the same match again (same seed, same fixed steps: the same play) and saves frames A..B, C..D as
##          OUT_DIR/f_000123.jpg, and the events again (events.json) so the script can check the play repeated.
## Godot's Movie Maker (--write-movie) would draw and write every frame of the match; this draws only the shots.

var out := ""
var venue := "arena"
var home := "AUS"
var away := "NZL"
var seed_n := 5
var total := 900
var windows: Array = []       # [[first, last], ...] frames to save
var events: Array = []
var m: Match
var start_frame := 0
var _saved := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		push_error("usage: -- OUT_DIR VENUE HOME AWAY SEED FRAMES [A-B,C-D]")
		get_tree().quit(2)
		return
	out = args[0]
	venue = args[1]
	home = args[2]
	away = args[3]
	seed_n = int(args[4])
	total = int(args[5])
	if args.size() > 6 and args[6] != "":
		for w: String in args[6].split(","):
			var ab := w.split("-")
			windows.append([int(ab[0]), int(ab[1])])
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.dev = false
	Game.settings.auto_gfx = false          # never lower the graphics because software GL is slow
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.camera = Game.CAM_TV
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	ToonBody.material(true)
	Game._size_theme()
	get_tree().root.size = Vector2i(1920, 1080)
	RenderingServer.render_loop_enabled = false
	for i in 3:
		await get_tree().process_frame
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": home, "away": away, "venue": venue, "quarter": 15, "mode": "quick", "user_team": -1,
		"demo": true, "seed": seed_n}
	m.game_event.connect(_on_event)
	start_frame = Engine.get_process_frames() + 1
	Game._swap(m)
	RenderingServer.frame_post_draw.connect(_grab)


func frame() -> int:
	return Engine.get_process_frames() - start_frame


func _wanted(f: int, ahead := 0) -> bool:
	for w: Array in windows:
		if f >= int(w[0]) - ahead and f <= int(w[1]):
			return true
	return false


func _process(_delta: float) -> void:
	if m == null:
		return
	var f := frame()
	# Drawn a few frames ahead of a window too (anything that settles over a frame or two is settled).
	RenderingServer.render_loop_enabled = _wanted(f, 3)
	if f >= total:
		set_process(false)
		RenderingServer.render_loop_enabled = false
		_finish()


func _grab() -> void:
	var f := frame()
	if m == null or not _wanted(f):
		return
	var img := get_viewport().get_texture().get_image()
	img.save_jpg(out.path_join("f_%06d.jpg" % f), 0.93)
	_saved += 1
	if _saved % 30 == 0:
		print("saved %d frames (at %d)" % [_saved, f])


func _on_event(kind: String, info: Dictionary) -> void:
	if kind in ["goal", "shot_start", "miss", "centre_setup", "gain", "deflection", "period_end"]:
		var e := {"kind": kind, "frame": frame()}
		for k in ["team", "by", "value"]:
			if info.has(k):
				e[k] = info[k]
		e["score"] = [m.score[0], m.score[1]]
		events.append(e)


func _finish() -> void:
	var fa := FileAccess.open(out.path_join("events.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"venue": venue, "home": home, "away": away, "seed": seed_n, "frames": total,
		"events": events}, "\t"))
	fa.close()
	print("events: %d, frames saved: %d" % [events.size(), _saved])
	get_tree().quit()
