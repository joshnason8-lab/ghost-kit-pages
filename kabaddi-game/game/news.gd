class_name News
extends RefCounted
## Headlines for the League Season and the Nations Cup, written from what happens in them: results and upsets,
## Super 10s and High 5s, runs, the table, records, injuries, the auction, the board and the awards.
##
## An item is a story and its values, not text, so that it reads in whatever language the game is in when it is
## shown: {id, k: the story ("UPSET"), v: which wording (1 to VARIANTS[k]), a: the values, p: 1 news, 2 a big
## story, 3 breaking news, w: when ({"key": "MATCHDAY", "n": 5}), t: the teams it is about}. Values under keys that
## begin "team" are team ids, shown as the team's name; "price" is lakhs, shown as money; "derby" and "goal" are
## keys of their own, translated; "name" is a player's name as it is.

const KEEP := 60   # stories kept: the oldest go

## How many wordings each story has (NEWS_<story>_<n> in i18n), so a run of results does not read the same.
const VARIANTS := {
	"THRASH": 3, "UPSET": 3, "THRILLER": 2, "TIE": 2, "DERBY": 2, "WIN": 2,
	"SUPER10": 3, "HIGH5": 2, "STREAK_W": 2, "STREAK_L": 2, "STREAK_END": 1,
	"TOP": 2, "CLINCH": 1, "OUT": 1, "RACE": 1, "PLAYOFF_SET": 1,
	"WEEK_RAIDER": 1, "WEEK_DEFENDER": 1,
	"INJURY": 2, "KNOCK": 1, "RETURN": 1,
	"RECORD_RAID": 1, "RECORD_TACKLE": 1, "RECORD_SCORE": 1, "RECORD_MARGIN": 1,
	"RECORD_RAID_SEASON": 1, "RECORD_TACKLE_SEASON": 1,
	"AUC_RECORD": 2, "AUC_STEAL": 1, "AUC_GRADE_TOP": 1, "AUC_GRADE_LOW": 1, "AUC_BIG_SPENDER": 1,
	"GOAL_SET": 1, "GOAL_MET": 1, "GOAL_MISSED": 1,
	"ELIM_WIN": 1, "SEMI_WIN": 1, "CHAMPIONS": 2, "ARJUNA": 1,
	"RETIRE": 1, "BREAKTHROUGH": 1, "NEW_SEASON": 1,
	"QUAL_THROUGH": 1, "QUAL_OUT": 1, "NEED_WIN": 1, "NEED_WIN_BY": 1, "NEED_TIE": 1, "NEED_LOSS_BY": 1,
	"NEED_HELP": 1, "NEED_TOP_BY": 1, "CUP_FINAL_SET": 1, "CUP_CHAMPIONS": 2, "CUP_FAIRYTALE": 1, "CUP_GIANT": 2,
	"CUP_CAPTAIN": 1, "GOLDEN_RAIDER": 1, "CUP_BEST_DEF": 1, "CUP_MVP": 1,
}


## Add a story to list (a season's or cup's news) and return it. n_ref is a one-element array holding the
## running story number, so that stories can be told apart once old ones are gone.
static func add(list: Array, n_ref: Array, k: String, a := {}, p := 1, when := {}, teams := []) -> Dictionary:
	n_ref[0] = int(n_ref[0]) + 1
	var item := {"id": int(n_ref[0]), "k": k, "v": 1 + absi(hash([k, a.values()])) % int(VARIANTS.get(k, 1)),
		"a": a, "p": p, "w": when, "t": teams}
	list.append(item)
	while list.size() > KEEP:
		list.pop_front()
	return item


## The headline, in the game's language now.
static func text(item: Dictionary) -> String:
	var args := {}
	var a: Dictionary = item.get("a", {})
	for key in a:
		var val = a[key]
		var ks := String(key)
		if ks.begins_with("team"):
			args[ks] = DB.team_name(String(val))
		elif ks == "price":
			args[ks] = Game.fmt_money(float(val))
		elif ks == "derby" or ks == "goal" or ks == "grade_note":
			args[ks] = TranslationServer.translate(String(val))
		elif val is float and is_equal_approx(val, round(val)):
			args[ks] = str(int(val))   # JSON hands numbers back as floats
		else:
			args[ks] = val
	return TranslationServer.translate("NEWS_%s_%d" % [String(item.get("k", "")), int(item.get("v", 1))]).format(args)


## When it happened, for the line under a headline ("Matchday 5", "Semi-final", "Auction").
static func when_text(item: Dictionary) -> String:
	var w: Dictionary = item.get("w", {})
	if w.is_empty():
		return ""
	return TranslationServer.translate(String(w.get("key", ""))).format({"n": int(w.get("n", 0)), "g": String(w.get("g", ""))})


## The newest stories first, the biggest first among equals: up to n of them.
static func latest(list: Array, n: int) -> Array:
	var out := list.duplicate()
	out.reverse()
	return out.slice(0, n)


## The front page: the biggest story of the latest round (or auction, or stage), the newest of equals.
static func top_story(list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var w: Dictionary = list[-1].get("w", {})
	var best := {}
	for i in range(list.size() - 1, -1, -1):
		var it: Dictionary = list[i]
		if it.get("w", {}) != w:
			break
		if best.is_empty() or int(it.get("p", 1)) > int(best.get("p", 1)):
			best = it
	return best


## Breaking stories the player has not seen yet (newer than seen, a story number), oldest first.
static func unseen_breaking(list: Array, seen: int) -> Array:
	var out := []
	for it in list:
		if int(it.get("id", 0)) > seen and int(it.get("p", 1)) >= 3:
			out.append(it)
	return out


static func last_id(list: Array) -> int:
	return int(list[-1].get("id", 0)) if not list.is_empty() else 0
