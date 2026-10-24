# Floorball Unleashed

A floorball game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no
royalties), the same way as Kabaddi Raid and Takraw Smash. Floorball is the fast indoor stick game of Sweden,
Finland, Switzerland and Czechia: five and a goalkeeper a side, a plastic ball with 26 holes, a 40 x 20 m rink inside
low boards. Floorball Unleashed plays the international Rules of the Game in force from 1 July 2026, and dresses its menus as
the coach's whiteboard in a Nordic sports hall.

> **Status: beta 0.6.0.** The players, goalkeepers and referees are the owner's Meshy models (a man for the men's
> game, a woman for the women's), in each team's colours, with the owner's stick; the rink, hall and crowd were made
> to match them (docs/MESHY_BRIEF.md). Since 0.5 they walk, jog and run with real people's motion capture (CMU),
> their feet planted on the floor as they run (docs/MOCAP.md); 0.6 brought a recorded crowd and footsteps
> (docs/SOUNDS.md). 0.2 added a coach for the first match, the club season, the empty net and
> passive play, after a playtest in a browser on phone-shaped screens (docs/PLAYTEST.md). docs/BETA.md says how to
> install and what to try; docs/PROGRESS.md has what is done and what is next.

## What's in it

| Area | What works today |
|---|---|
| **The rules** | The 2026 edition, as a pure rules module with a test for each rule (docs/RULES.md lists every rule, its number, how the game does it and what is simplified). Three periods (4, 8, 12 or the laws' 20 minutes), effective time or a league's running clock (with the last 3 minutes always effective, new in 2026), intervals and changing ends, one time-out a team. |
| **Restarts** | Face-offs at the centre and the nearest dot; hit-ins 1.5 m from the boards, never behind a goal line's extension; free-hits where the offence was, never within 3.5 m of the goalkeeper area; opponents 3 m away; goals straight from either. |
| **Offences and penalties** | Hitting or hooking the stick, a stick between the legs, pushing, holding, tripping, slashing, the ball above the knee, the goalkeeper's 3 seconds; advantage played, delayed penalties with the arm up; 2-, 5- and 10-minute (2 + 10, sat by the offender) and match penalties; power plays (a minor ends on a power-play goal, a major never); never more than two penalties running; the 2026 coincidental-penalty rule; the penalised player walks to the penalty bench and sits there; passive play warned, then a free-hit; nobody through the goalkeeper area. |
| **Goals** | The whole ball over the line from the front; no kicked, headed or hand-ball goals; own goals count; a goalkeeper's throw may score (2026). |
| **Overtime** | Group matches may be drawn; a match that needs a winner gets 10 minutes of sudden victory (5 with the league clock), then penalty shots: five different players a team, then one each (after five, anyone, again: 2026). |
| **Officials** | Two referees on the diagonal along the long sides; the nearer whistles and signs the call (free-hit, hit-in, advantage, delayed penalty, goal, no goal, 2/5/10 minutes, penalty shot, face-off, time-out); a card on the screen shows the consequence, then the offence and its rule. |
| **The teams** | 22 national teams, men's and women's, rated in world-ranking order; squads of 20 (two goalkeepers, three lines of five, three reserves) with invented players from each country's common names. Kits in each country's colours; the visitors change when the jerseys clash. |
| **How they play** | A 2-1-2 defence with the nearest player pressing on the goal side, a 2-2-1 forecheck, wingers wide and the centre in the slot, flying line changes every 40-60 seconds, goalkeepers who read the shot, butterfly, catch or spill. Late in a match the team a goal or two behind pulls its goalkeeper for a sixth outfield player. Tuned to real matches (tests/ai_bench, per 60 minutes): 9.5 goals and 100 shots (real: about 10 and 95). |
| **You** | One outfield player at a time (the yellow ring at his feet and arrow over his head; no numbers over heads), switched to the one nearest the ball by itself or with Switch; shoot (aim at a corner), pass to the joystick's team-mate, sprint, tackle; you take your team's free-hits and hit-ins (without delay: kept waiting, the referee gives it to the other team), and the penalty shots. Your first match has a coach: a note at the bottom of the screen as each moment comes (moving, the ball, defending, your free-hit, the whistle, a penalty, a goal), in every language. |
| **Modes** | Quick match (any two of 22, three venues, period length, difficulty, clock, draw or decided); the World Finals (16 nations in the World Championships' format: groups A-D, play-offs, quarter-finals, semi-finals, bronze and final); a club season (ten invented clubs, a single round robin of nine rounds counted 3-2-1-0 as the Nordic leagues do, no draws, then semi-finals 1 v 4 and 2 v 3 and a final); an AI v AI match behind the home screen. |
| **After the match** | A box score: the score by period, shots on goal, saves, penalty minutes, power-play goals, face-offs won, blocked shots, every goal with scorer and assist and power play, every penalty with its offence and rule, the player of the match. |
| **Venues** | A city arena (stands all round, a hanging scoreboard), a sports hall (birch walls, one bank of seats behind the benches), a school gym (wall bars, a few parents). The benches and substitution zones on the far side, the penalty benches and secretariat on the near side. |
| **Languages** | English, Svenska, Suomi, Deutsch, Français, Italiano, Čeština, Slovenčina, Norsk bokmål, Dansk, Latviešu, Eesti, Polski, 日本語 and ไทย, with each country's real floorball terms and CLDR plurals (docs/LANGUAGES.md). The game starts in the phone's language; the globe on the home screen changes it. |
| **Phones** | GL Compatibility renderer; the rink and hall merged by material into a few draw calls, the crowd one draw call, each person one (the stick is a bone of the body). Starts on Low on a small GPU or under 4.5 GB of memory, and drops a level by itself if the first seconds of a match run under ~36 fps. Battery saver (~30 fps at 80% render scale), Smooth (60, a whole fraction of the screen's rate) or Max. A developer overlay (frame-time percentiles, hitches, draw calls) behind seven taps on the version in Settings > About. |

### Performance

`tests/perf_probe.tscn`, a match in the city arena (the biggest venue, 5,200 seats) and the sports hall, per frame:

| Graphics | Arena: draw calls / triangles | Hall: draw calls / triangles | Render scale | Shadows, MSAA |
|---|---|---|---|---|
| Low | 81 / 53,000 | 86 / 77,000 | 75% | none, off |
| Medium | 79 / 80,700 | 87 / 101,900 | 90% | none, 2x |
| High | 122 / 414,100 | 130 / 450,000 | 100% | yes, 4x |

The school gym (measured with tests/arena_look's probe mode): Low 87 / 74,800, Medium 83 / 96,300, High 126 / 429,000.

Budgets for the floor (a 2-3 GB phone with a Mali-G52/G57 at 720p, Low, 30 fps): under 100 draw calls and 100,000
triangles a frame, which Low meets. The people are the owner's Meshy models at three detail levels (Low about 2,700
triangles a person, Medium 5,400, High 10,800; docs/MESHY_BRIEF.md), each one draw call, and one more for a stick;
High's extra triangles are its shadow pass. The rink, hall and crowd are 6 to 10 draw calls and 3,000-21,000
triangles on Low (merged into one texture sheet, every repeated fitting one MultiMesh; the crowd is one draw call of
cut-outs baked from the same models; 0.4 added the halls' walls, ceilings, lamps and backboards, see
docs/PROGRESS.md). The rest of the draw calls are the HUD and buttons. The game's own data is about 9 MB: fonts
subset to 1.3 MB, the characters and stick 1.5 MB, the venue and crowd sheets and the halls' fittings and floors
about 4 MB (compressed for phones), the ball and flags
still drawn at load.

## Controls

On a phone: put your left thumb anywhere on the left of the screen and slide it: the joystick appears under it. On the
right, three buttons: **Shoot**, **Pass** and **Sprint** (held) with the ball; **Tackle**, **Switch** and **Sprint**
without it. Push the joystick up or down as you shoot to pick a corner; a pass goes to the team-mate the joystick
points at. Settings: left-handed (the sides swap), button size (Normal, Large, Extra large), Move buttons (drag each
where your thumb wants it; also in the pause menu), switch player by itself, game speed (Steady 80% or Real).
The phone's Back button pauses and resumes a match, goes back elsewhere, and quits from the home screen; leaving
the app pauses the match.

On a keyboard: WASD or arrows to move, Space, J and K for the three buttons, Esc for Back.

## Get it on your phone

Every push that touches `floorball-game/` runs the **Floorball Unleashed · Android build** action: it runs the tests and the
fit audit, exports the beta APK (64-bit ARM) and puts it on the release page
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/floorball-unleashed-beta. Open that page on the phone, tap the
APK, and allow your browser to install it. It installs over any earlier Floorball Unleashed beta and keeps your settings.

For Google Play: [store/PLAY_STORE.md](store/PLAY_STORE.md) has every step and every App content answer, and the
**Floorball Unleashed · Play Store bundle** action builds the `.aab` (unsigned until the upload key is in the repository's
secrets).

## Play it in a browser

The project has a Web export preset (single-threaded, so it runs without special server headers). In the Godot
editor: Project > Export > Web > Export Project into `build/web/`, then serve that folder (`python3 -m http.server`
in it) and open http://localhost:8000. Mouse clicks act as touches; the keyboard works too. It is not hosted
anywhere yet.

## Run it on a computer

1. Install Godot 4.7.2 (standard build, not .NET).
2. Build the translations: `python3 tools/build_i18n.py`.
3. Open `project.godot` and press Play.

## Tests

`tools/ci_local.sh` runs what the Android build action runs (every check below but the APK itself); run it before
a push. By hand:

```
python3 tools/check_scripts.py                                                   # every script parses
godot --headless --path . res://tests/compile_check.tscn                          # every script loads
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn             # each rule, every screen in every
                                                                                  # language, the World Finals, AI
                                                                                  # matches with the motion audit
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- out.jsonl  # text fit: 15 languages x 4 shapes
godot --headless --path . --fixed-fps 60 res://tests/ai_bench.tscn -- 6 4         # AI v AI against real numbers
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn # drags scroll, from text too
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/perf_probe.tscn # draw calls per graphics level
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out  # a tour of the screens
```

The motion audit (in test_runner) checks every player's position is written once a frame (only `Player.step`
writes it), and that nobody moves faster than a sprint or jumps between frames. Strides are driven by the ground actually covered
(`Player._animate`), so feet do not slide.

## Project layout

```
autoload/   game.gd (settings, saves, the whiteboard theme, plurals, screens), db.gd (teams, squads, kits, venues),
            sfx.gd (whistles, the ball's crack, boards, horn, crowd and drum, made in code)
game/       rules.gd (the rules, pure), match.gd (the match), team_ai.gd, player.gd (movement and poses),
            body.gd (the pose: a skeleton the game moves), rigged_body.gd (the owner's model following it, kit colours, the
            stick in its hands), mocap.gd (the motion capture cycles), ball.gd, arena.gd + geo.gd + crowd.gd (rink and hall),
            camera_rig.gd, hud.gd, touch_controls.gd, sim.gd (matches not shown), cup.gd (the World Finals),
            season.gd (the club season)
ui/         main menu (whiteboard + live match), quick setup, World Finals, club season, settings, move buttons,
            how to play, result (box score), licences, language picker, loading screen, ui.gd (fit helpers),
            drag_scroll.gd, backdrop.gd + rink_sketch.gd (the whiteboard), flags.gd, crest.gd (the clubs'), icon.gd
i18n/       src/*.json (one file per language), strings.csv (generated by tools/build_i18n.py)
fonts/      Noto Sans, Noto Sans Thai, Noto Sans JP (cut to the Japanese text), Caveat, Barlow Condensed: SIL OFL
assets/     characters/ (the owner's Meshy man, woman and stick, made fit for phones by tools/meshy), mocap/ (walk, jog
            and run cycles from CMU motion capture, by tools/mocap), icon/, audio/
tools/      meshy/ (prepare.gd: the models cut down for phones; views and the grip check), mocap/ (bvh_to_clip.py,
            gait_view), ci_local.sh (CI's checks,
            run before a push), build_i18n.py, subset_fonts.py, check_scripts.py,
            check_pages.py, audio/make_music.py, audio/prepare_sounds.py (the recordings),
            store/ (icons, feature graphic, screenshots)
tests/      test_runner, fit_audit, input_test, perf_probe, ai_bench, screenshots, compile_check
store/      PLAY_STORE.md, the listing in 15 languages, the icon, feature graphic and screenshots
docs/       RULES.md, LANGUAGES.md, PROGRESS.md, BETA.md (install and test), PLAYTEST.md, MESHY_BRIEF.md, MOCAP.md,
            SOUNDS.md
```

## Moving it to its own repository

This folder is self-contained. Copy everything inside `floorball-game/` (including the hidden `.github/`) to the new
repository's root and push: `.github/workflows/android.yml` and `play-bundle.yml` are set up for that layout. Move the
privacy and help pages (`floorball-unleashed/` at the top of this repository) too, or keep them here.
