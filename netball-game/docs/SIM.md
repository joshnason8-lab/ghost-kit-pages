# Simulated matches

The owner's project (November 2026): thousands of simulated matches, headless, faster than real time, on the real
game code, each from a seed that plays it again exactly, so bugs are found and fixed without anyone playing every
build. The shared foundation will ship the general harness (WsgSim: runner, seeds, fixed-step headless, timeouts,
failure recorder and replay, batch reports, sharding, nightly CI, generic checks). This page is the game's part: where
its randomness is and how it is seeded, how fast a match runs headless, the netball checks, the batch runner, and the
scenarios to generate.

```
XDG_DATA_HOME=$TMPDIR/x godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- n=60 quarter_s=45 wsg=on out=$TMPDIR/sim
# one failing match again, exactly (the JSON written for it has the line):
godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- only=17 seed=1 quarter_s=45 wsg=on ...
# shards: first=0 n=30 on one machine (or core), first=30 n=30 on another
```

`tests/sim/run_batch.gd` builds each match as the game does (`game/match.gd` with a config, AI v AI), steps it itself
(`steps` match steps a frame, each exactly the step a frame takes: `Match._process`, 1/fixed-fps cut at 0.05 s), runs
`tests/sim/netball_checks.gd` after every step and at every `game_event`, skips each replay as a tap does, and writes a
JSON for every match with a violation, plus `summary.json`, to `out` (refused inside the project). Match i's config
(teams, venue, seed, knockout, Double Zone, time-outs, rolling changes, whistle rate) follows from the batch's seed and
i alone, so `only=i` replays it. `repro=1` plays each match twice and fails it if the two differ. Engine errors logged
during a match count as violations. Exit code 1 on any error-level violation or unfinished match.

## Randomness: every roll, and how it is seeded

Rule: **gameplay draws come from the match's own generator, `Match.rng`, seeded from `config.seed`; cosmetic draws
never touch it** (the global generator, `Sfx._rng`, or a fixed per-object seed). The AI reaches it through
`TeamAI.rng()` (it returns `m.rng`). `Game.start_match` now puts a seed in every config that has none (`randi()`), so
every match the game plays, including a rematch (the result screen drops the old seed), has its seed in its result's
config and can be played again. Cups and seasons have their own generators (`Cup.rng`, `League.rng`), now seedable
(`Cup.create(country, seed)`, `League.create(club, seed)`, `Game.new_cup/new_league(..., seed)`) and saved with the
cup or season (`rng_state`), so a loaded cup goes on as it would have.

| Where | What it decides | Kind | Seeded by |
|---|---|---|---|
| game/match.gd:95 | the match's generator | gameplay | `config.seed`; `Time.get_ticks_usec()` only when a match is made without `Game.start_match` and without a seed (the tests' own matches all pass one) |
| game/match.gd:108-109 | the toss: first centre pass, first ends | gameplay | Match.rng |
| game/match.gd:471 | the landing foot at a catch on the move | gameplay | Match.rng |
| game/match.gd:558 | the pass sound's pitch | **cosmetic on the gameplay generator** | Match.rng (drawn whether or not sound is on, so seeded runs repeat; but changing the sound would change every later roll: move to `Sfx._rng` when match.gd is free, as one accepted reshuffle of seeded results) |
| game/match.gd:577 | a deflected pass's new direction | gameplay | Match.rng |
| game/match.gd:604-605 | a fumbled catch and where the ball goes | gameplay | Match.rng |
| game/match.gd:769 | whether a shot goes in | gameplay | Match.rng |
| game/match.gd:791 | where a miss hits the rim | gameplay | Match.rng |
| game/match.gd:803-804 | the rebound's direction and speed | gameplay | Match.rng |
| game/match.gd:861 | the AI's time-out after a goal | gameplay | Match.rng |
| game/match.gd:883 | advantage played or not | gameplay | Match.rng |
| game/match.gd:995 | an injury from a contact | gameplay | Match.rng |
| game/match.gd:1138 | the injured player replaced | gameplay | Match.rng |
| game/match.gd:480, 723, 744, 747, 749 | catch, bounce, step and squeak sounds (pitch, a squeak's chance) | cosmetic | global generator (right) |
| game/ai.gd:472-481 | the attackers' leads (where they cut to) | gameplay | Match.rng via TeamAI.rng() |
| game/ai.gd:494 | how long a lead or hold lasts | gameplay | Match.rng |
| game/ai.gd:616 | the holder's decision time | gameplay | Match.rng |
| game/ai.gd:625 | the GA trying a Double Zone long shot | gameplay | Match.rng |
| game/ai.gd:685 | noise in a pass's value (the choice of pass) | gameplay | Match.rng |
| game/ai.gd:781, 786 | going for an intercept; take, tip or miss | gameplay | Match.rng |
| game/ai.gd:839-853 | the AI's infringements: contact, obstruction, footwork, offside (and who) | gameplay | Match.rng |
| game/ai.gd:922 | a defender's challenge on a pass: take, tip, miss | gameplay | Match.rng |
| game/ai.gd:945 | the umpire seeing your DEFEND inside 0.9 m | gameplay | Match.rng |
| game/ball.gd:171 | the ball's spin as drawn | cosmetic | global generator (right) |
| game/cup.gd:26, 182 | the cup's other matches (Sim) | gameplay (competition) | Cup.rng: `seed` argument, else `hash(country) + ticks`; on load its saved state (older saves: randomized) |
| game/league.gd:25-32, 176 | the season's draw (the clubs' order: was `Array.shuffle()` on the **global** generator), its other matches | gameplay (competition) | League.rng, as the cup's; the draw now from it |
| game/sim.gd:10-11 | a numbers-only match | gameplay (competition) | the caller's generator (cup and season pass theirs); randomized only when none is passed |
| autoload/db.gd:169-203 | squads: names, ratings, heights, skin, hair | data | `hash("squad:" + id)`: the same every run |
| autoload/game.gd:387 | a match's seed when its config has none | meta | global generator (randomized at start) |
| autoload/sfx.gd:182, 216, 238, 240, 407-493 | sound takes, pitches, synthesized noise | cosmetic | global generator |
| autoload/sfx.gd:236, 253, 255 | the whistle's and the extra takes' picks | cosmetic | `Sfx._rng` (kept off the match's draws on purpose) |
| ui/main_menu.gd:27 | which home-screen match plays | cosmetic | global generator |
| game/crowd.gd:143-151, game/crowd_venues.gd:55-59 | the crowd's shirts and seats | cosmetic | per-seat hashes of a fixed seed |
| game/arena.gd:666, 1137, 1249, 1306 | venue dressing: lights, props, grass, trees | cosmetic | fixed seeds (11, 21, 7) |
| addons/wsg_foundation/crowd3d.gd, crowd_cards.gd, flags.gd | the 3D crowd, cards, flags | cosmetic | fixed seeds |
| addons/wsg_foundation/locomotor.gd:366-368 | the foundation bodies' idle fidgets | cosmetic | was the global generator; now each body's own (game/foundation_link.gd:88-89, hashed from its kind, position and team) |
| addons/wsg_foundation/audio/audio.gd:102, 110 | the foundation's sound takes and pitch | cosmetic | global generator |

Not random, but not repeatable either (what else a seed needs to repeat a match):

- **The graphics level and the foundation.** On Medium and High with the licensed data, a held ball is where the
  foundation's hands draw it (`Player.hand_point` reads `FoundationLink.ball_at`), so where a pass or shot leaves the
  hands, and so its flight's length and time, depend on the foundation's pose. Its pose is made at the engine's
  skeleton update (once a frame, eased by the frame's delta), far bodies every second or third frame by their distance
  from the camera. So the same seed plays the same match only at the same level, foundation on or off, the same
  `--fixed-fps` and, with the foundation, the same steps a frame. Low (and the foundation off) is the same whatever the
  steps a frame: measured, the same scores at 1 and 4 steps. Every failure JSON records level, foundation, steps and
  the command that replays it.
- **Deferred calls**: the AI's time-out after a goal is `call_deferred` (runs at the frame's end): at more than one
  step a frame it lands up to steps-1 steps later. Only with time-outs on.
- `Game.settings` the match reads: `whistles` (the batch passes it in the config), `difficulty` (only for a match with
  a user team), `onside`, `control`, `camera` (user matches only). A replay must use the same.
- Repeatable in one process and across processes: `repro=1` passes (the same seed twice in one run gives the same
  goals, calls and periods at the same times), and separate runs of the same arguments give the same scores.

How a site should reach the seed (for the agents editing game/match.gd, ai.gd, ball.gd, player.gd, arena.gd,
crowd.gd now; nothing here changes their call sites):

- Gameplay in Match: `rng`. In TeamAI: `rng()`. In Player, Ball, Umpire (none today): `match_ref.rng` / the match's
  `rng` passed in; never the global `randf()`.
- Cosmetic anywhere: the global generator or a generator of the object's own with a fixed or hashed seed. Never
  `Match.rng`: each cosmetic draw on it shifts every later gameplay draw when the cosmetics change (match.gd:558 is
  the one that does today).
- New competitions or menu draws: a generator of their own, seeded from an argument, its state saved with them.

## Headless speed

<<SPEED>>

## The netball checks

`tests/sim/netball_checks.gd`, a plain class: `begin(m)`, `check_frame(m, dt)` after every step, `check_event(m, kind,
info)` on every `game_event`, `finish(m, result, finished)`. It redoes the court's geometry itself (areas, circles,
thirds, the ring) rather than asking `Rules`, except `Rules.double_zone_live` (the window's scaling is the game's own
choice). Each violation is `{t, q, phase, check, severity, msg}`: **error**, a state the rules or physics forbid that
the game produced; **warn**, an infringement left uncalled or one called without it (umpire's discretion, or a
simplification docs/RULES.md admits), counted and ranked.

| Area | Checks (name: what) |
|---|---|
| Scoring (R9) | `score_down`, `score_without_goal` (a score changes only by a goal, by its value), `score_periods` (the periods' scores add up), `shot_position` (GS/GA only), `shot_outside` (from inside her circle, line included), `shot_free_pass` (a free pass in the circle is not shot), `shot_value` (1, or 2 from 3.0 m with the Double Zone live), `goal_position`, `goal_value`, `goal_team`, `goal_without_shot`, `goal_late` (a shot from one period scoring in the next), `goal_not_through` (the whole ball through the ring: its middle within the ring less its radius, at the ring's height), `box_score`, `box_scorer` |
| Clock (R2, R10) | `clock_up`, `clock_fast`, `clock_bad`, `clock_held` (no time off in an interval, time-out, injury, at full time or in a replay), `clock_stopped` (it runs in live play), `clock_before_cp` (it waits for the period's first centre pass), `clock_period_length` (quarters and extra time's halves as set), `period_end_early` |
| Periods and the end | `period_order`, `extra_time` (only in a knockout), `ends` (change every period, not playing on), `et_lead` (playing on ends at a two-goal lead), `end_early`, `end_level`, `end_periods`, `result_periods`, `no_end` (did not finish in 12 quarters' time plus 10 minutes), `stall` (60 s of play without an event) |
| Centre pass (R8) | `cp_alternate` (whoever scored), `cp_lineup` (at the whistle: the taking C in the circle, the other C in the centre third, the rest out of it: breaking uncalled), `cp_taken_outside` (the first of her team to take it after the C does so in the centre third, not GS or GK, or it is called: a caught pass and one picked up loose) |
| Possession, footwork (R11, R13) | `held_ball_uncalled` (more than 3 s in play), `held_ball_late` (a shot still in her hands after 3 s), `held_ball_early`, `footwork_travel` (more than 1.6 m from where she got it), `footwork_after_landing` (more than 0.45 m once landed), `holder_off_court` |
| Areas (R14) | `offside_uncalled` (half a second in an area her position may not enter, in play), `offside_at_whistle` (at any restart's whistle), `offside_phantom` (called standing in her own area) |
| Out of court (R15) | `throw_in_on_court` (out called with the ball on the court), `throw_in_inside` / `throw_in_far` (the thrower outside, within 0.5 m of the line), `throw_in_spot` |
| Free and penalty passes, obstruction, advantage (R6, R7, R16) | `restart_spot` (taken within 1.6 m of where given), `restart_taker` (by a player allowed there), `penalty_out_of_play` (the penalised player beside the thrower), `penalty_defender_close`, `obstruction_uncalled` (defending inside 0.9 m of the landing foot a second and more), `obstruction_phantom` (called from 0.9 m or more), `advantage_wrong` (only with the fouled side's shooter set in her circle), `call_unknown` |
| Changes and time-outs (R3, variants) | `sub_when` (only at an interval, an injury, a time-out, a replacement after ordering off, or with rolling changes), `timeout_off`, `timeout_when` (after a goal, before the centre pass), `timeout_count` (two a team a half), `too_few` (five at least) |
| Impossible states | `ball_holder` (one holder; the ball and the match agree), `away_holds` (out of play or suspended), `ball_off_hands`, `ball_two_places` (drawn where the match has it), `ball_teleport` (in play), `ball_jump_restart` and `ball_snap_catch` (counted: the ball put on the spot or into the catcher's hands), `ball_nan`, `ball_below_floor`, `ball_lost`, `player_nan`, `player_teleport`, `player_speed`, `player_lost`, `player_height`, `body_below_floor` (each drawn body's ankles, every 15 steps), `team_size`, `player_twice`, `position_twice`, `position_bad`, `player_team`, `phase_unknown`, `engine_error` |

## The first batch

<<BATCH>>

## Scenarios to generate

| Scenario | Exists | To build |
|---|---|---|
| Normal play: AI v AI, every venue | tests/sim/run_batch (any number, seeded, checked every step); test_runner `_matches` (3 matches, 75 s quarters); soak `matches` part (with Back and the home button); match_trace (one match's events) | nightly shards of run_batch on the foundation's WsgSim |
| Every graphics level, the foundation on and off | run_batch `levels=`, `wsg=` (each match the next level); test_runner `_foundation_match`, `_venue_study`, `_low_unchanged` | |
| Team strength extremes (the best v the weakest, equals) | run_batch's random pairs and near-rated pairs (mix) | a generator of fixed pairings (top v bottom, the two weakest), and score-rate bounds per rating gap (balance: flag only, the owner decides) |
| Attribute extremes (shooting 20 or 99, speed 30, all-tall, all-short) | none | squads edited in a config (`lineup_0/1` is there: Match reads it) with clamped extremes; checks: goals happen, nobody runs past TOP |
| Every AI strategy and difficulty | AI v AI is sharp 1.0 both sides; difficulty only applies against a user team | a bot user team (below) at each difficulty; the AI has no named strategies yet, its knobs are the whistle rate and sharpness |
| Match settings: quarter lengths (5, 8, 10, 15 and the tests' seconds) | run_batch `quarter_s=`; the real quarters only via `quarter` with no `quarter_s` | a quarter-minutes axis (`quarter=5..15`, no quarter_s): checks the Double Zone window scaling and period lengths |
| Double Zone, time-outs, rolling changes, whistle rate | run_batch `mix=1` (40%, 40%, 30%, each rate); test_runner `_league_options` | rolling changes are made from the pause menu: a bot that makes them |
| Onside on/off, camera, control mode team/bib | test_runner `_controls`, `_stick_camera` (scripted) | need a user team: the bot below, each camera, team and bib |
| Venues | all three, every match cycles them | |
| Last-second goals, ties, extra time, two-goal lead | run_batch knockouts (30%) and near-rated pairs; test_runner `_two_goal_lead`, `_matches` (knockout) | a generator that starts a match at q4 with seconds left and the score level (config hook, or set `time_left`/`score` after `_ready` as `_two_goal_lead` does) |
| Penalties, advantage, suspensions, ordering off, injuries | run_batch at the real whistle rate (`whistles=2`); test_runner `_sanctions_and_injury`, `_advantage_clear` | a "foul-heavy" generator (whistle rate 3x and a long quarter) checking the ladder: warning at the 4th, suspension at the 3rd after, ordered off at the second suspension, replacement after 240 s |
| A fuzzed human player | soak `monkey` (random taps, drags, Back, home button through the menus and into matches; needs a window); `tests/user_bot.tscn` refers to a script that was never committed (dangling) | a headless in-match bot for the user team: joystick sweeps on every camera, button mashing (PASS, LOB, SHOOT, INTERCEPT, DEFEND, SWITCH), pause and resume, `NOTIFICATION_APPLICATION_PAUSED` / focus out, with the netball checks on: the user's own offside (onside off), obstruction (DEFEND inside 0.9 m), over a third, short pass |
| Pause, resume, backgrounding | soak `back`, `lifecycle`, `matches` (pokes) | in run_batch: pause and resume at random steps (the clock and phase must not move while paused) |
| Menu paths: Nations Cup and Club Season end to end | test_runner `_cup`, `_league` (simulated rounds; now with seeded repeat and save/load part way); soak `back` | the user's own matches played by the bot through Game.start_match and the result screen, every round to the medals, with seeds |
| Every settings combination | test_runner `_screens` (every screen in every language) | the settings product (graphics x fps x camera x control x onside x quarters x language) at the match start, a few seconds each |
| Mid-match quit, rematch | soak `back` (quit from the pause menu); result screen REMATCH drops the seed (now re-seeded by Game.start_match) | a run_batch mode that quits at a random step and starts the next match: no leak (node count), no error |
| Corrupted and old saves | none for the match; Game reads JSON with defaults | a generator of truncated, wrong-typed and old-version settings, records, cup and season files (old ones without `rng_state` load randomized: covered by from_dict's fallback) |

Other test-side gaps: matches with a user team are never simulated in bulk (difficulty, control modes, the user's
own infringements); real-length quarters (15 minutes) are not in any batch; the foundation's path (Medium, High)
costs about the same per step as Low headless, so it should be in every batch.
