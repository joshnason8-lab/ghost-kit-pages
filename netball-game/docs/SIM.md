# Simulated matches

The owner's project (November 2026): thousands of simulated matches, headless, faster than real time, on the real
game code, each from a seed that plays it again exactly, so bugs are found and fixed without anyone playing every
build. The shared foundation's WsgSim (synced at 7239d54, ADOPTING.md §5.17) is the harness: runner, seeds, fixed
step, failure records and replay, reports, shards, CI, the generic checks, the human-input and menu fuzzers. This page
is the game's part: its adapter, where its randomness is and how it is seeded, how fast a match runs headless, the
netball checks, and the scenarios.

## WsgSim: the adapter and how to run it

`game/wsg_sim.gd` (extends WsgSimGame; not `game/sim.gd`, which is the game's numbers-only results simulator for the
cup and the season, `Sim.play`). Pass `--game res://game/wsg_sim.gd` to every tool command:

```
OUT=$TMPDIR/sim   # never inside the project
HANG=1500 sh tools/wsg/sim_shard.sh . "$OUT" --smoke --input --game res://game/wsg_sim.gd
HANG=1500 sh tools/wsg/sim_shard.sh . "$OUT/3" --from 1 --count 2400 --shard 3/16 --input --game res://game/wsg_sim.gd
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- merge --game res://game/wsg_sim.gd --out "$OUT" "$OUT"/*/
godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- replay --game res://game/wsg_sim.gd --failure "$OUT/failures/<sig>/<seed>.json"
NETBALL_SIM_SHORT=1 godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- fps-probe --game res://game/wsg_sim.gd --seeds 6
```

- **Kinds**: `random`, `extreme` (the strongest against the weakest, the two weakest, the two strongest; 5- or
  15-minute quarters; the fewest or the real-rate whistles), `human` (a user team, whole-team or one bib, played by
  WsgSimInput with `--input`; idle without it), `targeted:scoring` (Double Zone, its window's edges),
  `targeted:timer` (quarters of 4-30 s: period ends, shots in the air, knockouts), `targeted:completion` (near-equal
  knockouts: extra time and on to a two-goal lead), `targeted:fouls` (the real whistle rate, 4-minute quarters:
  warnings, suspensions, ordering off, injuries), `targeted:variants` (Double Zone, time-outs, rolling changes, a
  knockout together). Every config also draws venue, level (Low, Medium, High: the foundation on Medium and High
  when the licensed data is there), quarters (5, 8, 10, 15), camera, control, onside, difficulty.
- **The length mix**: with `config.short` the quarters are a fifth as long (a 5-minute quarter plays 60 s; extra time
  scales with them, as it does for any quarter length); every rule the same.
- **rules()** is `tests/sim/netball_checks.gd`, every frame; its errors fail the match, its warnings (the umpire's
  discretion, things seen but not rules) go in the events and in the result as `n_<check>` counts.
- **Kept as the game plays**: a replay is skipped at once, as a tap skips it; and every player's foundation body is
  posed in full, undoing WsgSim's sampled pose: the ball a player holds is where the foundation's pose layer puts her
  hands (`FoundationLink.ball_at`), so a pass's or shot's start, and so the play, would change without it
  (`NETBALL_SIM_SAMPLED_POSE=1` allows it, to measure that).
- **The human**: the stick is the touch joystick's value (`TouchControls.joystick`); the three buttons are the keys
  the controls read (Space, J, K), Back is Esc (pauses and resumes); after the app comes back from the background the
  person taps Resume a moment later (the game pauses a match then, as on a phone).
- **Bodies** are named for the stretch of play (`GS0.3`): a new quarter places everyone at once, a replay or a change
  cuts, and the feet are measured afresh there (a jump at a cut is not a slide). A body not yet posed (not drawn) is
  not given to the pose check.
- The adapter prints a line a period, so `sim_shard.sh` can tell a long match from a frozen one; still set `HANG`
  above its 120 s default (a 15-minute quarter is minutes of a runner's time).
- **CI**: `.github/workflows/netball-sim.yml`, nightly (16 shards of the 2,400-match batch, merged into one report)
  and on request (nightly or smoke); artifacts only, in the runner's temp folder.
- `sh tools/wsg/rng_lint.sh` lists what is left: the six cosmetic rolls on the global generator in game/match.gd
  (480, 723, 744, 747, 749: sounds' pitch, a squeak's chance) and game/ball.gd:171 (the ball's drawn spin), all in
  files other work had open: mark them `# wsg-rng-ok: <why>` (or move them to `Sfx._rng`) when those files are free.
  It does not see match.gd:558, a sound's pitch drawn from the match's own generator (below).

## run_batch: the game's own batch runner

```
XDG_DATA_HOME=$TMPDIR/x godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- n=60 quarter_s=45 wsg=on out=$TMPDIR/sim
godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- only=17 seed=1 quarter_s=45 wsg=on ...
```

Written before WsgSim landed and kept for what WsgSim does not do: several match steps a frame (`steps`), the speed
split (`profile=1`, `checks=off`, CPU seconds), and `repro=1`. It builds each match as the game does (AI v AI),
steps it itself (`Match._process`, 1/fixed-fps cut at 0.05 s), runs the same netball checks after every step and
event, skips replays as a tap does, and writes a JSON for every match with a finding, plus `summary.json`, to `out`
(refused inside the project). Match i's config follows from the batch's seed and i alone (`only=i` replays it).

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

Measured November 2026 on the build machine: 4 cores shared with other work (load average about 25), so the wall
clock understates what a free core does; each run also reads its own CPU time (`/proc/self/stat`), and "x a CPU
second" is the speed one free core gives. AI v AI, 20 s quarters, three venues each, `tests/sim/run_batch.tscn`:

| Level | Foundation | Steps a frame | x real time (wall, loaded) | x a CPU second |
|---|---|---|---|---|
| Low | off or on (Low never uses it) | 1 | 5.8 | 11.5-11.9 |
| Low | off | 4 / 16 | 5.5 / 6.3 | 11.7 / 11.7 |
| Low | off, checks off | 4 | 6.9 | 12.1 |
| Medium | off | 1 / 4 | 5.7 / 5.3 | 11.4 / 11.7 |
| High | off | 1 / 4 | 6.1 / 6.5 | 11.3 / 12.0 |
| Medium | on | 1 / 4 | 2.0 / 2.8 | 3.8 / 5.5 |
| High | on | 1 / 4 | 2.4 / 3.1 | 3.8 / 5.3 |
| Medium, the HUD built | on | 4 | 2.4 | 5.6 |

- **Nothing in the match waits for the wall clock.** With `--fixed-fps 30` every frame is 1/30 s of play however long
  it takes, and frames run back to back (`--fixed-fps` skips the engine's frame delay; the harness also sets
  `Engine.max_fps = 0`: the game's Smooth cap is 0 on a 60 Hz or headless screen, but Battery saver or a 144 Hz screen
  would set one, and a run without `--fixed-fps` would step by the wall clock). The game uses no physics bodies, no
  AnimationPlayer or AnimationTree, and tweens only in the menus. Things on engine time rather than the match's:
  the goal whistle's 0.45 s `SceneTreeTimer` (heard matches only: sound), haptics' timers (phones only), the AI's
  time-out after a goal (`call_deferred`: the frame's end), and the foundation's skeleton update (its pose layers
  ease by the frame's delta and its hands set `ball_at` once a frame).
- **The cost is the step itself**: about 2.8 ms of CPU a step with the foundation off (the AI and fourteen players'
  moves, bodies, hands: `profile=1` splits it), so more steps a frame buys nothing there (11.5x at 1, 11.7x at 16).
  The checks cost 4%.
- **With the foundation** (Medium and High with the licensed data) a step costs about 6 ms and each frame's skeleton
  update as much again at one step a frame: 3.8x; at 4 steps a frame 5.5x, but then the foundation is posed once a
  frame for four steps, which changes where the ball leaves the hands and so the play (the same seed gives different
  scores at 1 and 4 steps). WsgSim steps once a frame, so its foundation matches run at about 3.8x a CPU second.
- **Best honest speeds**: about 12x a free core with the foundation off (Low: a production level), 3.8x with it; on
  the 4 cores, 4 processes, about 45x and 15x in all.
- **What more needs**: (1) the coarser step only if WsgSim's `fps-probe` finds one whose outcomes match 30 fps
  exactly (the AI's per-step chances, `randf() < rate * dt`, and the 0.05 s step cap make that unlikely: see
  "WsgSim" below for what it found); (2) the foundation's frame cost: its skeleton modifiers run at the frame, so a
  build where the match's step drives them (or where the hands' ball point comes from the game's clock, not the
  skeleton update) would let it step several times a frame without changing the play; (3) the step's own cost
  (players' bodies and hands posed every step even headless, because the ball's position comes from the hands): a
  cheaper hand point when nothing is drawn would change the play, so it is not an option under "production code
  only"; (4) more processes: sharding is linear.

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

**run_batch, 20 matches** (9 with 30 s quarters, foundation off, Low/Medium/High, three venues; 11 with 45 s quarters,
foundation on; knockouts, Double Zone, time-outs, rolling changes and whistle rates mixed; 1,231 + 2,170 s of play).
Every match finished; no scoring, clock, period, centre-pass, throw-in, substitution, time-out or end-of-match rule
was broken; no NaN, no body or ball out of the world or under the floor; seeded matches repeat (`repro=1`, and the
same scores across processes). What it found, ranked by how often x how much it matters:

| # | Finding | Matches | Times | Kind | Where (who may change it) |
|---|---|---|---|---|---|
| 1 | **A rebound taken at full stretch pops into the hands**: a GS or GA picking up her own side's rebound (the ball about 2.5 m up, `_run_loose` lets a player take it up to her leaping reach) has it at her chest the next frame, 1.3-1.6 m lower; a defender's rebound (the GK's, a "gain") the same, 1.0-1.6 m | 12 + 17 of 20 | 18 + 32 | seen (a ball jumping 1.5 m in 1/30 s), no rules effect | game/match.gd `_run_loose` (no leap for a high pick-up), game/player.gd hand point |
| 2 | **Defenders defending inside 0.9 m for a second and more, uncalled**: 0.03-0.85 m from the landing foot; also the opposing C at a centre pass taker. The AI aims 0.94-1.15 m off, then `Rules.onside_point` pulls the spot back inside when goal-side is in an area she may not enter, and the umpire's 15% miss is on purpose | 14 of 20 | 20 | rules (obstruction R16) | game/ai.gd `_defend` (a spot 0.9 m off in another direction) |
| 3 | **Obstruction called from 1.0-1.35 m**: the AI's "slip" calls contact or obstruction on the marker up to 1.35 m from the landing foot (`_slips`: 1.35); obstruction needs closer than 0.9 m | 9 of 20 | 10 | rules | game/ai.gd:836; the slip rates are balance: the owner's call |
| 4 | **Offside called on a player in her own area**: the offside slip names a random player where she stands (`_slips` 851-855) | 3 of 20 | 3 | rules (the call shows nothing wrong) | game/ai.gd |
| 5 | **The ball jumps to the centre circle or into a restart taker's hands** (up to 15 m in a frame) at every centre pass and many restarts | 20 of 20 | 186 | seen, as most games do | game/match.gd `_setup_centre`, `_run_setup` |
| 6 | (Found and fixed in the checks, not the game: a player "teleport" after a skipped replay; the ball "in two places" for the frame after a tap ends a replay; a same-team box score when a team played itself, which the game never allows.) | | | | |

**WsgSim's first matches** (the smoke batch, 4 shards; the machine's other work left each about a tenth of a core):
The smoke batch (`--smoke --input`, 71 matches planned, 4 shards) was stopped after 12 matches (3,287 s of play in 7,411
s of wall clock: the machine's other work left each shard about a tenth of a core): 4 random, 4 extreme, 4 human; 3
passed, 9 failed. One "freeze" (random#4) was not one: a full-length 15-minute-quarter match printing nothing for 30
minutes of a starved core, before the adapter printed a line every two minutes of play. Results in
`$TMPDIR/.../smoke/merged/SIM_REPORT.md` on the build machine (outside the project). The netball rules found nothing
in the AI's own play; what failed:

| # | Finding (WsgSim's own check, or the netball rules') | Seen | Kind | Where |
|---|---|---|---|---|
| 1 | **Your player can run off the floor into the stands** with Keep me onside off: the bib-controlled C ran past the run-off within seconds: behind a goal line (x 22-23 m; the run-off ends at 18.3) and over a side line (z 15.6 m; it ends at 10.7) | human#6, human#15 | a body out of the venue (WsgSim "out of bounds"; netball `player_lost`) | game/match.gd `_drive_me` / game/player.gd `advance`: nothing holds an unfenced player inside the run-off |
| 2 | **A centre pass nobody reached is taken outside the centre third with no call, and by its own thrower**: the human's C lobbed the centre pass, the GA was not there (`_arrive`: the ball runs on, no event), and the C picked it up at x 6.3 (a goal third): a centre pass fault and a replayed ball, neither called. docs/RULES.md says replayed ball "cannot happen in play": it can, this way | human#3 | rules (R8, R11) | game/match.gd `_arrive`, `_run_loose` |
| 3 | **Advantage signalled three times for one challenge, then the same contact called**: the human's GK holding INTERCEPT on the shooter infringes every frame (`TeamAI` 927-933: contact from 1.2 m), the umpire plays advantage, again, again, then calls it; the user's player never gives way (`give_way` skips her) | human#3 | rules, presentation | game/ai.gd |
| 4 | **A wing defence stands still 6 s and more with her target 8-12 m away** (WsgSim "stuck"): likely fenced at the defending circle's edge with her target across it (a straight path through an area she may not enter; nothing routes her round) | extreme#5, #11, human#6; random#2, #4 in the first try | movement | game/player.gd `advance` (fenced), game/ai.gd targets |
| 5 | **Feet sliding while planted** (the foundation's check at 7239d54, the followed quarter of the bodies): 8-20 cm in most foundation matches, and 1-1.6 m once in the first stretch of play of several. The check guessed "planted" from a low, slow foot; the foundation's d4e3107 measures feet only while its planter drives them (poses the game sets do not count): rerun on d4e3107 before fixing anything | every Medium/High match so far | seen | the foundation link (game/foundation_link.gd) or the check |
| 6 | The user's C in a T-pose on the first frame of a match (the frame before her first pose; the loading screen may hide it) | human#15 | seen, unconfirmed | game/foundation_link.gd (visible before posed) |

**Fixed (rules round two, test_runner `-- rules2`)**: WsgSim's 1-4 above and run_batch's 1, 3 and 4: your player
kept in the run-off (`Player.bounds`), a pass nobody reached not played first by its thrower (replayed ball) and a
centre pass so still to be touched in the centre third, advantage played once, the AI's obstruction and offside
slips made before they are called, fenced players routed round a goal circle, a loose ball met in the hands' reach
and brought in. Each test fails on a1b84be and passes after (docs/PROGRESS.md).

**Determinism**: `sim.gd -- determinism --seeds 2` (short matches): PASS, both seeds the same frame for frame (1,479
checks each). **The step**: `sim.gd -- fps-probe --seeds 4` (short): 20 fps gave 0 of 4 outcomes the same as 30, so
WsgSim stays at 30 frames a second. **Speed, WsgSim** (one step a frame): a 5-minute-quarter short match (257 s of
play) took 27 CPU s at Low (9.5x a CPU second with the start-up) and 79 CPU s at Medium with the foundation (3.3x).

**The nightly batch, what it would cost**: the adapter's mix averages about 940 s of play a match (three in four
short, a quarter of the quarters 5, 8, 10 or 15 minutes long; a third of the matches Low, two thirds with the
foundation), about 220 CPU seconds a match on this machine's cores: 2,400 matches are about 540,000 CPU seconds. One
Godot per job on 16 jobs: about 9 hours each (over a job's 6-hour limit). The workflow therefore runs four shards
side by side in each job (a runner has 4 cores): 64 shards, about 2.3 hours each if a runner's core is as quick as
this machine's, each stopped at 4.5 hours so what ran is uploaded and merged. To bring it under 2 hours: fewer
foundation matches (each costs three Low ones), 15-minute quarters only in the extreme kind, or 2,000 matches. The
owner's call: the mix decides what the nightly covers.

**Balance, for the owner (nothing changed):** goals come at about 3.5 a minute of play in the 45-second quarters (115
goals in 33 minutes of play over 11 matches; 3.7 in the 30-second ones), about twice the real game's 1.8-1.9 (110-120
in 60 minutes). Short quarters inflate it a little (each starts on a centre pass), so measure it on 15-minute
quarters before deciding anything.

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
| A fuzzed human player | WsgSim `human` kind with `--input` (WsgSimInput: stick sweeps, holds, circles, jitter; taps, mashes, double taps of the three buttons; Back; background and back; screen turns; camera switches; whole team or one bib, onside on or off, every difficulty); soak `monkey` (needs a window); `tests/user_bot.tscn` refers to a script never committed (dangling) | the user's own infringements checked as such (offside with onside off, DEFEND inside 0.9 m, over a third, short pass): today they show as calls, which the checks accept |
| Pause, resume, backgrounding | soak `back`, `lifecycle`, `matches` (pokes) | in run_batch: pause and resume at random steps (the clock and phase must not move while paused) |
| Menu paths: Nations Cup and Club Season end to end | test_runner `_cup`, `_league` (simulated rounds; seeded repeat and save/load part way); soak `back` | the adapter's `menu_start`, `in_match`, `menu_check` for WsgSim's menu fuzzer (not written yet), and the user's cup and season matches played by the bot through the result screens, every round to the medals |
| Every settings combination | test_runner `_screens` (every screen in every language) | the settings product (graphics x fps x camera x control x onside x quarters x language) at the match start, a few seconds each |
| Mid-match quit, rematch | soak `back` (quit from the pause menu); result screen REMATCH drops the seed (now re-seeded by Game.start_match) | a run_batch mode that quits at a random step and starts the next match: no leak (node count), no error |
| Corrupted and old saves | none in WsgSim yet (the adapter has no `save_paths`/`old_saves`); Game reads JSON with defaults; cups and seasons saved before `rng_state` load randomized (from_dict) | `save_paths()` (settings, records, cup, season) and old versions' samples for `sim.gd -- menu --saves` |

Other test-side gaps: matches with a user team are never simulated in bulk (difficulty, control modes, the user's
own infringements); real-length quarters (15 minutes) are not in any batch; the foundation's path (Medium, High)
costs about the same per step as Low headless, so it should be in every batch.
