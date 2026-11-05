class_name WsgHaptics
extends RefCounted
## The phone's buzz, the same in every game (owner-approved item 8): named moments, one pattern each, so a tag feels
## like a tag in Kabaddi and Kho Kho alike. The player's setting (enabled, WsgSettings "haptics") turns it off.
##   WsgHaptics.play("bonus")          # the bonus point: a quick double pulse
##   WsgHaptics.play("tagged")         # you were tagged: a firm double buzz
## A pattern: [[ms, strength 0-1], gap ms, [ms, strength], ...]. A game adds its own: WsgHaptics.PATTERNS is copied
## into patterns, and patterns["dive"] = [[30, 0.7]].

const PATTERNS := {
	"tap": [[12, 0.3]],                                   # a menu button, a light touch
	"tag": [[25, 0.5]],                                   # your player tags someone
	"tagged": [[45, 0.9], 60, [45, 0.9]],                 # you are tagged (firm, double)
	"teammate_tagged": [[20, 0.4]],                       # a team-mate is tagged (light)
	"score": [[50, 1.0], 70, [50, 1.0]],                  # your side scores (strong, double)
	"bonus": [[25, 0.6], 50, [25, 0.6]],                  # the bonus point (quick double pulse)
	"hit": [[18, 0.7]],                                   # a strike, a block, the post
	"whistle": [[30, 0.4]],                               # the referee stops play
	"win": [[60, 1.0], 80, [60, 1.0], 80, [120, 1.0]],    # full time, you won
}

## The player's setting.
static var enabled := true
static var patterns := PATTERNS.duplicate(true)
## Where the buzzes go (default: the phone, Input.vibrate_handheld); a test sets a Callable(ms, strength) - and sets
## it back to Callable() when done (a lambda left in this static var outlives its script at exit: a heap corruption).
static var sink := Callable()
## Never two within this many ms (a burst reads as one long rattle).
const GAP_MS := 60
static var _last := -100000


## Buzzes MOMENT's pattern (nothing if off, unknown, or too soon after the last). A coroutine (the gaps are awaited);
## fire and forget.
static func play(moment: String) -> void:
	if not enabled or not patterns.has(moment):
		return
	var now := Time.get_ticks_msec()
	if now - _last < GAP_MS:
		return
	_last = now
	var tree := Engine.get_main_loop() as SceneTree
	for step in patterns[moment]:
		if step is Array:
			if sink.is_valid():
				sink.call(int(step[0]), float(step[1]))
			elif OS.has_feature("mobile"):
				Input.vibrate_handheld(int(step[0]), float(step[1]))
			if tree:
				await tree.create_timer(float(step[0]) / 1000.0).timeout
		elif tree:
			await tree.create_timer(float(step) / 1000.0).timeout
