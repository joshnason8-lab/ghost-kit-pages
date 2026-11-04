class_name Coach
extends PanelContainer
## Coach tips for a first match: short notes at the bottom of the screen, each the first time it is needed (moving,
## passing, footwork, shooting, defending, intercepting, the areas, a whistle). A first-timer in the playtest scored
## nothing and did not know what the rings or buttons meant; with these, a minute of play teaches the game. They are on
## for a first match and turn themselves off after it (Settings turns them back on).

const SHOW_S := 6.0     # how long a tip stays
const GAP_S := 2.5      # the quiet between two tips

## The tips in the order they matter, each with what must be true for it to show.
const ORDER := ["move", "pass", "shoot", "footwork", "defend", "intercept", "whistle", "areas"]

var m
var seen := {}
var _label: Label
var _t := 0.0           # time left on the tip shown
var _gap := 1.5         # time before the next may show


## Should the tips show at all: on in Settings, a match you play.
static func wanted(mt) -> bool:
	return bool(Game.settings.get("coach", true)) and mt.user_team >= 0 and not mt.demo


## Which tip the state calls for, of those not yet seen ("" for none). state: me_has_ball, may_shoot, they_have_ball,
## pass_in_air (theirs), whistle (a call just made), live_s (seconds played).
static func pick(state: Dictionary, done: Dictionary) -> String:
	for k in ORDER:
		if done.has(k):
			continue
		var ok := false
		match k:
			"move":
				ok = true
			"pass":
				ok = state.get("me_has_ball", false)
			"shoot":
				ok = state.get("me_has_ball", false) and state.get("may_shoot", false)
			"footwork":
				ok = state.get("me_has_ball", false) and done.has("pass")
			"defend":
				ok = state.get("they_have_ball", false)
			"intercept":
				ok = state.get("pass_in_air", false) and done.has("defend")
			"whistle":
				ok = state.get("whistle", false)
			"areas":
				ok = float(state.get("live_s", 0.0)) > 40.0
		if ok:
			return k
	return ""


## The words for tip k, with the buttons' own names.
static func text(k: String) -> String:
	var tr_ := func(s): return TranslationServer.translate(s)
	return String(tr_.call("COACH_" + k.to_upper())).format({"pass": tr_.call("BTN_PASS"), "lob": tr_.call("BTN_LOB"),
		"shoot": tr_.call("BTN_SHOOT"), "defend": tr_.call("BTN_DEFEND"), "intercept": tr_.call("BTN_INTERCEPT"),
		"switch": tr_.call("BTN_SWITCH")})


func _init(mt = null) -> void:
	m = mt
	theme_type_variation = "GlassPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	var tag := Label.new()
	tag.text = TranslationServer.translate("COACH").to_upper()
	tag.theme_type_variation = "EyebrowLabel"
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tag)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(380, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", Game.ts(18))
	h.add_child(_label)


## Shows tip k now (the fit audit and the tests use this too).
func show_tip(k: String) -> void:
	seen[k] = true
	_label.text = text(k)
	visible = true
	_t = SHOW_S
	size = Vector2.ZERO


func step(delta: float, whistle: bool) -> void:
	if visible:
		_t -= delta
		if _t <= 0.0:
			visible = false
			_gap = GAP_S
		return
	if m.phase != "live" and m.phase != "setup" and not whistle:
		return
	_gap -= delta
	if _gap > 0.0:
		return
	var they: bool = m.possession >= 0 and m.possession != m.user_team
	var air: bool = m.ball.state == "flight" and m.pass_info.has("from") and (m.pass_info.from as Player).team != m.user_team
	var k := pick({"me_has_ball": m.me != null and m.me == m.holder, "may_shoot": m.button_set().has("SHOOT"),
		"they_have_ball": they and m.holder != null, "pass_in_air": air, "whistle": whistle, "live_s": m.live_s}, seen)
	if k != "":
		show_tip(k)
