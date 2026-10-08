class_name Awards
extends RefCounted
## Season player stats and the end-of-season awards: best raider, best defender, and the
## Arjuna Award for the most valuable player (most raid plus tackle points).
##
## Matches you play add every player's real points. Matches the game simulates share each
## team's score among its starting seven: raid points mostly to its raiders, tackle points
## mostly to its defenders, the better players taking a bigger share.

const RAID_SHARE := 0.62     # of a team's points that come from raids
const TACKLE_SHARE := 0.28   # ... and from tackles (the rest is all-out and extra points)


static func add(table: Dictionary, pid: String, pname: String, team: String, raid: int, tackle: int) -> void:
	if not table.has(pid):
		table[pid] = {"name": pname, "team": team, "raid": 0, "tackle": 0, "matches": 0}
	var row: Dictionary = table[pid]
	row.raid = int(row.raid) + raid
	row.tackle = int(row.tackle) + tackle
	row.matches = int(row.matches) + 1
	row.team = team


## Add a played match: the "player_stats" from a match result.
static func add_match(table: Dictionary, player_stats: Dictionary, skip_pid := "") -> void:
	for pid in player_stats:
		if String(pid) == skip_pid:
			continue
		var r: Dictionary = player_stats[pid]
		add(table, String(pid), String(r.name), String(r.team), int(r.raid), int(r.tackle))


## Share a simulated team score among the starting seven.
static func sim_team(table: Dictionary, squad: Array, team: String, points: int, rng: RandomNumberGenerator) -> void:
	var seven := DB.starting_seven(squad.duplicate())
	if seven.is_empty():
		return
	var raid_w := []
	var tackle_w := []
	for p in seven:
		var a: Dictionary = p.attrs
		var raid_v: float = (a.agility + a.reach + a.speed) / 3.0
		var role := String(p.role)
		raid_w.append(pow(raid_v / 100.0, 4.0) * (1.0 if role == "raider" else (0.55 if role == "allrounder" else 0.06)))
		tackle_w.append(pow(float(a.tackle) / 100.0, 4.0) * (1.0 if role == "defender" else (0.6 if role == "allrounder" else 0.15)))
	var raid_pts := _split(int(round(points * RAID_SHARE * rng.randf_range(0.85, 1.15))), raid_w, rng)
	var tackle_pts := _split(int(round(points * TACKLE_SHARE * rng.randf_range(0.8, 1.2))), tackle_w, rng)
	for i in seven.size():
		var p: Dictionary = seven[i]
		add(table, String(p.id), String(p.name), team, raid_pts[i], tackle_pts[i])


static func _split(total: int, weights: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	out.resize(weights.size())
	out.fill(0)
	var sum := 0.0
	for w in weights:
		sum += float(w)
	if sum <= 0.0:
		return out
	for k in total:
		var roll := rng.randf() * sum
		for i in weights.size():
			roll -= float(weights[i])
			if roll <= 0.0:
				out[i] += 1
				break
	return out


## Best raider, best defender and the most valuable player (the Arjuna Award).
static func leaders(table: Dictionary) -> Dictionary:
	var best := {"raider": {}, "defender": {}, "mvp": {}}
	var top := {"raider": -1, "defender": -1, "mvp": -1}
	for pid in table:
		var r: Dictionary = table[pid]
		var row := {"pid": String(pid), "name": String(r.name), "team": String(r.team), "raid": int(r.raid), "tackle": int(r.tackle), "matches": int(r.matches)}
		for k in ["raider", "defender", "mvp"]:
			var v: int = row.raid if k == "raider" else (row.tackle if k == "defender" else row.raid + row.tackle)
			if v > int(top[k]):
				top[k] = v
				best[k] = row
	return best
