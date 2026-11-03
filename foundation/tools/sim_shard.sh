#!/bin/sh
# Runs a WsgSim batch so that a freeze or a crash cannot stop it: Godot is watched; if it dies, or prints nothing new
# for HANG seconds (a frozen match: an endless loop the in-game checks cannot interrupt), the match it was on (its
# progress.txt) is recorded as a "freeze" or "crash" failure and the batch goes on from the next seed. Results go on
# accumulating in OUT (results.jsonl: a rerun skips what is done).
#   sh <game>/tools/wsg/sim_shard.sh <game dir> <out dir> [batch options...]
#   e.g. sh tools/wsg/sim_shard.sh . "$RUNNER_TEMP/sim/3" --from 1 --count 2000 --shard 3/8
GAME=$1
OUT=$2
shift 2
HANG=${HANG:-120}
GODOT=${GODOT:-godot}
# (A game's copy is in tools/wsg/; the foundation's own in tools/.)
SIM=res://tools/wsg/sim.gd
[ -f "$GAME/tools/wsg/sim.gd" ] || SIM=res://tools/sim.gd
mkdir -p "$OUT/failures"
LOG="$OUT/godot.log"
tries=0
while :; do
	: > "$OUT/progress.txt"
	"$GODOT" --headless --fixed-fps 30 --path "$GAME" -s "$SIM" -- batch --out "$OUT" "$@" > "$LOG.part" 2>&1 &
	pid=$!
	last=$(wc -c < "$LOG.part")
	quiet=0
	hung=0
	while kill -0 $pid 2>/dev/null; do
		sleep 5
		now=$(wc -c < "$LOG.part")
		if [ "$now" = "$last" ]; then
			quiet=$((quiet + 5))
			if [ $quiet -ge "$HANG" ]; then
				kill -9 $pid 2>/dev/null
				hung=1
				break
			fi
		else
			quiet=0
			last=$now
		fi
	done
	wait $pid 2>/dev/null
	code=$?
	cat "$LOG.part" >> "$LOG"
	grep -E "^(SIM BATCH|[a-z:_]+ +seed )" "$LOG.part" | tail -3
	cur=$(cat "$OUT/progress.txt" 2>/dev/null)
	case "$cur" in
		running*)
			kind=$(printf '%s' "$cur" | cut -f2)
			seed=$(printf '%s' "$cur" | cut -f3)
			what=crash
			[ $hung = 1 ] && what=freeze
			echo "sim_shard: $kind seed $seed: $what (Godot $( [ $hung = 1 ] && echo "printed nothing for ${HANG}s" || echo "exited $code"))"
			sig=$( [ $hung = 1 ] && echo "freeze: the match stopped advancing" || echo "crash: Godot exited mid-match")
			printf '{"ok": false, "seed": %s, "kind": "%s", "config": {}, "failures": [{"check": "%s", "message": "%s", "signature": "%s", "severity": 5, "t": 0, "frame": 0}], "result": {}, "balance": {}, "sim_s": 0, "wall_s": 0, "speed": 0}\n' \
				"$seed" "$kind" "$what" "$sig (see godot.log)" "$sig" >> "$OUT/results.jsonl"
			mkdir -p "$OUT/failures/$what"
			tail -60 "$LOG.part" > "$OUT/failures/$what/$seed.log"
			tries=$((tries + 1))
			if [ $tries -gt 50 ]; then
				echo "sim_shard: 50 freezes or crashes in one batch: stopping"
				exit 1
			fi
			continue
			;;
	esac
	rm -f "$LOG.part"
	exit $code
done
