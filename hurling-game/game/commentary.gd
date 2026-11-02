class_name Commentary
extends Node
## The match's commentary: two voices, as a broadcast has them - the commentator calling the play (A) and his co-
## commentator, a former player, reading it (B) - recorded with ElevenLabs from the lines in
## assets/commentary/lines.json (tools/commentary/: the script, the voices, how to make them). The match tells it what
## happens (event); it picks a line for that moment, never one just heard, and plays it when it can: one voice at a
## time, the bigger moment first (a goal cuts across talk about the weather), a call that is late dropped rather than
## said over the next play, the co-commentator coming in after the call when there is room, and talking over the
## replays. The crowd dips under them as a broadcast mix does. A line without its recording is skipped, so the game
## runs the same with none, some or all of them made.

const DIR := "res://assets/commentary/"
const LINES := DIR + "lines.json"

## Each kind of moment: [priority (the bigger cuts across the smaller), how long the call stays worth saying (s), the
## least time between two calls of it (s), the chance the co-commentator follows it up].
const KINDS := {
	"throw_in": [60, 3.0, 0.0, 0.3], "second_half": [60, 3.0, 0.0, 0.3], "half_time": [90, 6.0, 0.0, 0.8],
	"full_time": [100, 8.0, 0.0, 0.9], "full_time_draw": [100, 8.0, 0.0, 0.9],
	"goal": [100, 3.0, 0.0, 0.8], "point": [70, 2.5, 0.0, 0.35], "point_long": [75, 2.5, 0.0, 0.5],
	"point_free": [65, 2.5, 0.0, 0.3], "wide": [50, 2.0, 6.0, 0.35], "save": [85, 2.0, 0.0, 0.6],
	"post": [80, 2.0, 0.0, 0.5], "free": [40, 2.0, 15.0, 0.2], "penalty": [85, 3.0, 0.0, 0.5],
	"sixty_five": [40, 2.5, 20.0, 0.2], "puck_out": [25, 2.5, 45.0, 0.3], "sideline": [35, 2.5, 20.0, 0.2], "yellow": [60, 3.0, 0.0, 0.5],
	"red": [80, 3.0, 0.0, 0.7], "tackle": [35, 1.5, 12.0, 0.2], "hook": [40, 1.5, 12.0, 0.25],
	"block": [40, 1.5, 12.0, 0.25], "catch": [35, 1.5, 15.0, 0.15], "attack": [55, 2.0, 18.0, 0.0],
	"level": [50, 8.0, 0.0, 0.0], "lead_one": [50, 8.0, 0.0, 0.0], "lead_big": [50, 8.0, 30.0, 0.0],
	"comeback": [52, 8.0, 60.0, 0.0], "late": [55, 8.0, 90.0, 0.2], "replay_goal": [45, 5.0, 0.0, 0.0],
	"replay_point": [45, 5.0, 0.0, 0.0], "replay_wide": [45, 5.0, 0.0, 0.0],
	"lull": [10, 3.0, 25.0, 0.6], "extra_time": [90, 5.0, 0.0, 0.5], "shootout": [90, 5.0, 0.0, 0.5],
}
const GAP := 0.35          # a breath between two lines
const QUIET := 12.0        # live play this long without a word: one of them says something (a lull line)
## The man who wins the ball, by name ("Hogan..."), as a broadcast follows the play: the least, the cheapest talk -
## only when nothing else is being said, never the same man twice running, gone if not said at once.
const CARRIER := [20, 1.0, 3.5]   # [priority, how long it stays worth saying (s), least time between two (s)]

var m: Node
var enabled := true
var speaking := ""         # the id of the line playing ("" none)
var said: Array = []       # every line played, [time, id, seconds] (the tests read it)
var _player: AudioStreamPlayer
var _queue: Array = []     # [kind, line, due, until, priority]
var _until := 0.0          # the line playing ends
var _prio := 0
var _last := {}            # kind -> when last said
var _bags := {}            # kind|who -> the lines not yet said this round
var _quiet := 0.0
var _rng := RandomNumberGenerator.new()   # (its own dice: the match's seeded play is never changed by talk)
var _chain := false        # the line playing is a name: the next follows at once
var _last_name := ""      # the last man named on the ball
var _later: Array = []   # [when (its clock), Callable]
var _t := 0.0              # its own clock: the match's stands still through a replay, the talk goes on over it
## Lines not yet recorded are skipped - but timed as if said where silent_ok (the tests).
var silent_ok := false
## False: the recordings are not played, each line timed by its length (the tests: the same with or without them).
var use_recordings := true

static var _data := {}     # kind -> {"A": [line...], "B": [line...]}
static var _streams := {}  # id -> AudioStream (or null: not recorded)
static var _by_id := {}    # id -> its line


func _init(p_m: Node = null) -> void:
	m = p_m
	name = "Commentary"


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "WsgVoice" if AudioServer.get_bus_index("WsgVoice") >= 0 else "Master"
	_player.volume_db = -2.0
	add_child(_player)
	_rng.randomize()
	enabled = bool(Game.settings.get("commentary", true)) and bool(Game.settings.get("sound", true))
	load_lines()


## The script (assets/commentary/lines.json): {"lines": [{"id", "who": "A"|"B", "on": kind, "text"}...]}.
static func load_lines() -> void:
	if not _data.is_empty():
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(LINES)) if FileAccess.file_exists(LINES) else null
	if not j is Dictionary:
		return
	for l: Dictionary in j.get("lines", []):
		var k := String(l.on)
		if not _data.has(k):
			_data[k] = {"A": [], "B": []}
		_data[k][String(l.get("who", "A"))].append(l)
		_by_id[String(l.id)] = l


## The recording of a line, or null: assets/commentary/<id>.ogg (or .mp3).
static func stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var s: AudioStream = null
		for ext in [".ogg", ".mp3"]:
			if ResourceLoader.exists(DIR + id + ext):
				s = load(DIR + id + ext)
				break
		_streams[id] = s
	return _streams[id]


## Something happened worth a word: kind (KINDS), who first ("A" the commentator, "B" the co-commentator); lead, a
## name the commentator says first where he has it recorded ("name_<surname>": the man on the ball, "county_<ID>":
## the side), and then a line made to follow a name ("after": "name" or "county" in the script) - "Fahy... and he
## splits the posts!"; without it, a line that stands alone.
func event(kind: String, who := "A", lead := "") -> void:
	if not enabled or not KINDS.has(kind):
		return
	var k: Array = KINDS[kind]
	var now := _now()
	if now - float(_last.get(kind, -999.0)) < float(k[2]):
		return
	var lead_line := {}
	if lead != "" and who == "A" and _by_id.has(lead) and (silent_ok or stream(lead) != null):
		lead_line = _by_id[lead]
	# The man was the last thing said, a moment ago: his line follows on from that ("Flanagan..." "...is through!").
	var named_now := not lead_line.is_empty() and not said.is_empty() and String(said[-1][1]) == lead and now - float(said[-1][0]) < 4.0
	var line := _pick(kind, who, "name" if lead.begins_with("name_") and not lead_line.is_empty() else ("county" if not lead_line.is_empty() else ""))
	if named_now:
		lead_line = {}
	if line.is_empty():
		return
	_last[kind] = now
	if not silent_ok and stream(String(line.id)) == null:
		return
	var item := [kind, line, now, now + float(k[1]), int(k[0])]
	# A bigger moment cuts across what is being said (a goal over a word about the weather); else it waits its turn.
	if speaking != "" and int(k[0]) >= _prio + 30:
		_player.stop()
		speaking = ""
		_until = now - GAP    # (no breath: it cuts straight in)
	_queue = _queue.filter(func(q): return int(q[4]) >= int(k[0]) - 20)   # (smaller talk dropped for it)
	if kind.begins_with("replay_"):
		# The replay is the co-commentator's word on the score: his follow-up of the call is not said as well.
		_queue = _queue.filter(func(q): return String(q[1].get("who", "A")) != "B")
	if not lead_line.is_empty():
		# The name first, the line straight after it (the same moment: no breath between them).
		_queue.append([kind, lead_line, now, now + float(k[1]), int(k[0]) + 1, true])
	_queue.append(item)
	_queue.sort_custom(func(a, b): return int(a[4]) > int(b[4]))
	if _queue.size() > 3:
		_queue.resize(3)


## The man on the ball, by name (his "name_<n>" recording): when no one is talking and none was called just now.
func carrier(id: String) -> void:
	if not enabled or id == "" or id == _last_name or not _by_id.has(id) or (not silent_ok and stream(id) == null):
		return
	var now := _now()
	if speaking != "" or not _queue.is_empty() or now - float(_last.get("carrier", -999.0)) < float(CARRIER[2]):
		return
	for k in ["goal", "point", "point_long", "point_free", "wide"]:
		if now - float(_last.get(k, -999.0)) < 6.0:
			return     # (the ball gathered after a score or a wide: play has stopped)
	_last["carrier"] = now
	_last_name = id
	_queue.append(["carrier", _by_id[id], now, now + float(CARRIER[1]), int(CARRIER[0])])


## The co-commentator's word after a call (or the commentator's after his), if there is a line for it.
func follow(kind: String, who := "B") -> void:
	if _queue.any(func(q): return String(q[0]).begins_with("replay_")):
		return     # (the replay is coming: his word is over that)
	var line := _pick(kind, who)
	if line.is_empty() or (not silent_ok and stream(String(line.id)) == null):
		return
	var now := _now()
	_queue.append([kind, line, now, now + 6.0, int(KINDS.get(kind, [30])[0]) - 5])


func _process(delta: float) -> void:
	if not enabled or m == null:
		return
	# Paused with the match.
	if _player.stream_paused != bool(m.paused):
		_player.stream_paused = bool(m.paused)
	if m.paused:
		return
	_t += delta
	var now := _now()
	while not _later.is_empty() and float(_later[0][0]) <= now:
		(_later.pop_front()[1] as Callable).call()
	if speaking != "" and (now >= _until or (_player.stream != null and not _player.playing)):
		var was := speaking
		speaking = ""
		_until = now
		_after_line(was)
	# Live play with nothing said for a while: a word between them.
	if speaking == "" and _queue.is_empty() and m.phase in [m.P.LIVE] and not m.replay.playing:
		_quiet += delta
		if _quiet > QUIET:
			_quiet = 0.0
			event("lull", "A" if _rng.randf() < 0.5 else "B")
	else:
		_quiet = 0.0
	if speaking != "" or (now < _until + GAP and not _chain):
		return
	while not _queue.is_empty():
		var q: Array = _queue.pop_front()
		if now <= float(q[3]):
			_say(q)
			break


func _say(q: Array) -> void:
	var line: Dictionary = q[1]
	_chain = q.size() > 5     # (a name: its line follows with no breath)
	var s := stream(String(line.id)) if use_recordings else null
	_player.stream = s
	speaking = String(line.id)
	_prio = int(q[4])
	var secs := maxf(0.6, String(line.text).length() / 15.0)   # (no recording: as long as it takes to say)
	if s != null:
		_player.play()
		secs = s.get_length()
	said.append([_now(), speaking, secs])
	_until = _now() + secs
	Sfx.duck(4.0, secs)


## After a line: the other voice comes in (a point, then the co-commentator's word on it), by the kind's chance.
func _after_line(id: String) -> void:
	var l: Dictionary = _by_id.get(id, {})
	if l.is_empty() or String(l.get("who", "A")) != "A":
		return
	var kind := String(l.on)
	if _rng.randf() < float(KINDS.get(kind, [0, 0, 0, 0.0])[3]):
		follow(kind, "B")


## A line for kind by who, not one said lately: each kind's lines go round in a shuffled order before any comes again.
func _pick(kind: String, who: String, after := "") -> Dictionary:
	if not _data.has(kind):
		return {}
	var all: Array = (_data[kind][who] as Array).filter(func(l): return String(l.get("after", "")) == after)
	if all.is_empty() and after != "":
		all = (_data[kind][who] as Array).filter(func(l): return String(l.get("after", "")) == "")
	if all.is_empty():
		return {}
	var key := kind + "|" + who + "|" + after
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = all.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t = bag[i]
			bag[i] = bag[j]
			bag[j] = t
	var line: Dictionary = bag.pop_back()
	_bags[key] = bag
	return line


## f called secs from now on the commentary's clock (which runs through the replays, as the match's does not).
func later(secs: float, f: Callable) -> void:
	_later.append([_now() + secs, f])
	_later.sort_custom(func(a, b): return float(a[0]) < float(b[0]))


func stop() -> void:
	_queue.clear()
	if _player:
		_player.stop()
	speaking = ""
	_until = _now() - GAP


func _now() -> float:
	return _t
