# The computer's play: what it copies from real matches

In 0.11.0 the AI was set against two broadcasts the owner sent:
- the 2024 World Cup, Thailand v the Philippines, the first set (15-4);
- the Asian Cup, India v the Philippines, fifteen points of a set.

Every point with a visible end was counted, 32 in all. The court was measured off the World Cup broadcast: a
homography from the court's lines gives each player's place in metres.

## How the points were decided

| | The real matches (32 points) | The game before (0.10.0) | The game now (0.11.0) |
|---|---|---|---|
| An attack's kill | 40% | 59% | 46% |
| The serve: the reception failing | 34% | 1% | 25% |
| A service fault | 19% | 4% | 17% |
| A block | 6% | 19% | 5% |
| Another error (a spike out, a net touch) | 3% | 17% | 7% |

The game's figures: eight AI-v-AI regu matches at the National Arena, the same eight each time
(`tests/match_sim.tscn -- 8 regu national`), 540 points before and 586 now. Counted as the real ones were: a point is
the serve's when the reception fails on the first or second touch after it, or comes straight over and is put away.
The touches a rally: 5.8 on average before, 4.5 now (the median 4 both times: the serve, the reception, the set, the
spike).

**About half the points were decided by the serve.** Three of the Philippines' four points against Thailand were Thai
service faults. Five of their nine against India came from serves at the same Indian receiver. Before 0.11.0 the
serve decided almost nothing (one point in twenty), blocks four times too many, and one spike in six went out.

## What the top sides do, and what the computer does now

| What the matches showed | In the game (`game/match.gd`) |
|---|---|
| Every serve a flat power serve, the leg high; no looped serves | The computer's tekongs serve hard and flat (`_serve_kick`: 9.5-14 m/s, just over the tape). Yours too when you time it well (a weak one still loops over). |
| Served at one receiver all set: the Philippines served all seven at India's #13 | Each side picks a wing player to serve at for the set: the one who receives worst (`_mark`). At him or just past him three serves in four, deep into a corner otherwise (`_serve_target`). |
| About one serve in six missed: into the net, wide, long | A service fault about one in six, more for a weaker tekong, more for the horse kick (`_serve_kick`). A serve into the net is a fault at once: nobody may play it. |
| A third of the points lost on the reception: off the body, out, back over the net | A power serve can spill off a receiver (`_pass`, `_spill`), the likelier the harder it was hit and the better its server against him. It flies out, dies at his feet, or floats back over for the servers to put away. He can't recover his own spill. |
| The receiving line flat, 3-4 m off the net, nobody at the net: the tekong on his circle 4.2 m back, the left inside player 3.9 m, the right 3.1 m | The regu's receiving places (`_serve_spot`) |
| The pass goes to the setter in the middle, about 2.5 m off the net | The pass goes there (`_pass`) |
| Three touches off a clean reception, a roll spike from the middle | As before (it already did) |
| One blocker: the inside player on the side the spike comes from; the other inside player 2.7 m back, the tekong 3.5-4.5 m deep | The feeder blocks when he is clearly nearer than the striker (`_prepare_block`). The others' places off the ball (`_regu_spot`). |
| A blocked spike drops short behind the spiker | Once the set is up, the tekong covers 2.5 m behind the spike, the setter short on the other side (`_regu_spot`) |
| A loose first touch that comes over is put away at once: five of five | A free ball high by the net is headed or soled straight back (`_find_touch`: `_free_ball`) |
| Rallies 1.5-5.5 s, at most three crossings; one spike error in 32 points | Spikes are harder to dig (the diggers read them a little later, and touch them less cleanly) and go out less often. A block stuffs a spike back less often (22% of the blocks that reach it, from 45%). |

**Difficulty** works on what decided the real points. On Rookie the computer misses more serves and spills more
receptions (x1.35); on Legend fewer (x0.85) (`_err_scale`). Its serve at you is a little softer on Rookie (x0.82) and
Pro (x0.92). This is on top of the touch quality it already scaled.

## Checking it

`tests/match_sim.tscn` prints each match and then how the points were decided, as in the table above. Options:
- `SEQ=1`: each rally's touches, e.g. `serve|receive~|attack`: `|` is the net crossed, `~` a spill, `!` a shank or a
  stuff block.
- `SEED=n`: start the matches' seeds from n, to run several at once.
- `PAIR=THA,KOR`: only that match.

The officials wear suits as at those two events (0.11.1, docs/PROGRESS.md).

## Not copied

- **Feints and where the spikes land:** the broadcasts' frame rate doesn't show them.
