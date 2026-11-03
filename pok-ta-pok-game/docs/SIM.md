# Simulation testing

The owner wants thousands of simulated matches per game, run headless and faster than real time on the real game
code. This is Pok Ta Pok Rivals' part, ready for the shared WsgSim harness when it lands.

## 1. Seeds

Every random roll in play goes through the match's one `RandomNumberGenerator` (`Match.rng`), seeded from the match
config's `seed`:
- the AI's choices (`TeamAI`);
- the serve's landing, angle and kind;
- the ring chance and the lapses;
- the replays' picks.

A match given no seed draws one (`randi()`) and keeps it in `rng.seed`, so it can be replayed. A run with the same seed
plays the same, which `test_runner`'s "the match plays exactly as without the foundation" checks.

The tournament (since 0.6.15): `Cup.create(team, rules, seed)` draws from the seed, and each of the other games'
simulated results (`ResultSim`) is played from the seed, its round and its place in the draw. The seed is saved with
the cup. A new cup from the menu is still a fresh draw each time (its seed taken from the clock, then kept), and a cup
saved before 0.6.15 has no seed, so its other games are played as before.

The foundation's locomotor fidgets were the one unseeded roll in what is drawn. Since 0.6.11 they are seeded from each
body's look.

Left unseeded on purpose, because none of them touch play:
- the sounds' pitch and variant (`Sfx`);
- the main menu's choice of attract match;
- a new cup's seed from the menu (kept with the cup from then on).

## 2. Speed

`tests/match_sim.gd` runs at about **8.5× real time**, headless at `--fixed-fps 30` on one desktop core: 2 AI matches
of about 4 simulated minutes each (480 s) take 58 s, at about 4 ms per 1/30 s step.

Nothing is tied to the wall clock. The match clock, the ball and the players all step on the frame's delta. Most of a
step's cost is posing ten players and two judges, each through Body/FoundationLink. There is no render in headless.

At this speed, 2,000 matches of 4 minutes (480,000 simulated seconds) come to about 15.7 h on one core, or about 2 h
sharded 8 ways. Watch AI's 2× (`Match.speed`) runs two steps per frame, so it adds no speed headless.

## 3. The sport's rules, after every step (`game/rule_checks.gd`)

`RuleChecks.step(match)` returns every violation in a step. `match_sim` runs it on every step and fails the run on
any violation. It checks:

- **The count:**
  - ulama: a holder of -1, 0 or 1, holding 1–8 rayas (none when level);
  - classic: 0–8 points each;
  - a winner only on 8, through the ring, or at time (R14);
  - each change is exactly the history's next raya, replayed by the rules, and never two rayas in one step.
- **The clock:** only forward, only in play, and never far past its limit.
- **The serve:** always the side that won the last raya (R11).
- **The end:** no play after a side has won, and never over with no winner and no time limit.
- **The players:**
  - each in his own half (R1: not over the analco, outside the intro and the end);
  - inside the court's bounds;
  - never more than 1 m in a step.
- **The ball:**
  - never inside the court's stone (talud, walls, rings) or a prop;
  - never under the ground;
  - never faster than 45 m/s;
  - never lost (non-finite).
- **The hip:** never meets the ball more than `Player.STRIKE_MAX_UP` over the hip.
- **Touches:** counted only in play.
- **Stuck:** no phase (a rally, a call, a replay, the copal) lasts over 150 s.

I tried injected faults to make sure the checks fire. With the analco clamp removed, `match_sim` reports 65
violations. The run also caught one wrong check of my own, a timed-out win while holding 1 raya, which R14 allows.

## 4. Scenario generators

Each comes from the real menus' configs (`Game.start_match`) and a seed:

- **Normal play:** Watch AI at every venue (village, festival, stone, night) and both rule sets, with a side size from
  each rule set's range.
- **Team strength:**
  - the strongest team against the weakest, from `DB` attributes;
  - each attribute at its minimum and maximum;
  - a mirror match.
- **Difficulty:** the AI at levels 0, 1 and 2 against each other and against themselves; ring chance and lapses at
  their extremes.
- **Match settings:**
  - length 0 (to 8 rayas), 6, 10 and 15 minutes;
  - urria sets 3_7, 3_5_7 and none;
  - the copal on and off;
  - graphics Low, Medium and High, where the posing differs;
  - one-player control, assist on and off.
- **Boundary cases:**
  - a raya at the last second of time;
  - level at time, then sudden death;
  - 7–7 in urria;
  - a ring shot at 7;
  - the serve short;
  - a ball dying exactly on the analco;
  - a ball knocked into a prop in play.
- **A fuzzed human player** (`tests/user_bot.gd` grown):
  - the stick swept through every angle on every camera (TV, high, end);
  - HIP and DIVE mashed and at random;
  - pause and resume mid-rally;
  - app backgrounding (`NOTIFICATION_APPLICATION_PAUSED`);
  - the camera cycled mid-rally;
  - SKIP spammed through the copal and the replays.
- **The tournament** (`targeted:cup`, in the WsgSim adapter): a cup drawn from the seed for the home town, its first
  game played as the menu plays it (mode cup, the town's side the person's), the result recorded as the game records
  it, then checked (`RuleChecks.cup`): the game's winner in the draw, every later round drawn from the winners, the
  town in or out as it played, and played through to a champion once it is out.
- **Menu paths:**
  - the tournament from the draw to the final, saved and resumed;
  - quick match and play again;
  - Watch AI at 1× and 2×;
  - mid-match quit;
  - every settings combination (language × graphics × controls × button size);
  - old and corrupted saves (`settings.cfg`, `cup.json`).

## 5. What already runs in CI

- `test_runner` (820 checks).
- `match_sim` with the rules checks.
- `user_bot` (play and idle).
- `input_test`.
- `fit_audit`.
- `prop_audit`.
- The owner's notes (18).

## 6. Balance

WsgSim's report splits its balance by `home_played_by`: in a third of the generated configs the home side is the
person's (the harness's random or idle input), and that side lost all 23 such matches in the first smoke batch: the
harness's play, not the game's balance. Computer against computer, one cell of levels at a time, with a 95% interval:

    godot --headless --path . --fixed-fps 30 res://tests/balance_sim.tscn -- <home level> <away level> <first seed> <count> [minutes]

