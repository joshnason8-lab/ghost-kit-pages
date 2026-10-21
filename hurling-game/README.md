# Ash & Leather

Hurling for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no royalties) in
the same way as Kabaddi Raid and Takraw Smash. It plays the GAA's playing rules as they stand in 2026, fifteen a side,
for the people who play and follow hurling: Ireland, and the Irish abroad. In English and in Irish.

> **Status: playable beta (0.2.0).** The players are built in code (`game/body.gd`) on a humanoid skeleton, ready to
> be replaced by Meshy models (docs/MESHY_BRIEF.md). Everything else is the game as it will ship.

## What's in it

| Area | What works today |
|---|---|
| **The rules** | The Official Guide Part 2 in force from 27 March 2026, in one module (`game/rules.gd`) with a test for each rule: goals (3) and points, written 2-18; halves of 35 minutes (senior county) or 30 (club), added time; the throw-in; four steps and two catches, the solo, no lifting by hand, the hand-pass (no hand-passed goals); puck-outs (everyone outside the 20 m line, 13 m before the taker's side plays it), frees, 65s, sideline cuts, penalties (one defender on the line); the tackle and its fouls; advantage for five seconds; yellow and red cards, and in senior county hurling the black card and sin bin for denying a goal chance; the 2026 dissent rule; extra time and the penalty shoot-out in knock-out games. See [docs/RULES.md](docs/RULES.md), with its sources. |
| **The pitch** | 140 × 85 m, the 13, 20, 45 and 65 m lines, the halfway line, the small (14 × 4.5 m) and large (19 × 13 m) rectangles, the 13 m arc, the goals (6.5 m apart, the bar at 2.5 m, posts 10 m high) with their nets, the corner and line flags. |
| **The sliotar** | 113 g, 71 mm, flying with air drag (a 40 m/s puck-out carries 80-100 m), bouncing and rolling on grass; marked on screen (a dot, an arrow at the edge) so it reads on a phone. |
| **The players** | Thirty hurlers in helmets with face guards, hurleys in hand, county colours in the game's own kit designs; running, striking from the hand and off the hurley, soloing, catching, lifting, hand-passing, hooking, blocking, shouldering, falling, celebrating. One movement writer each, audited: nothing snaps, strides match speed. |
| **The officials** | The referee (the whistle, the arm out for a free, one arm up for advantage, the cards, ten fingers for the sin bin, both arms for a penalty, the throw-in), two linesmen with their flags, four umpires in white coats (white flag for a point, green for a goal, arms crossed for a wide, an arm up for a 65). |
| **The AI** | Each side keeps its lines and marks man to man by the numbers, presses the man on the ball, supports him for the hand-pass, shoots for points from range and goes for goal only when through, pucks out short or long as county sides do. Tuned to the GAA's 2026 match statistics and checked at every length in CI (`tests/score_check.tscn`): the 35-minute length is a full 70-minute match with the ball live as long as in a real one, and it ends like one (about 3 goals and 43 points between the sides; real: 2.75 and 42); shorter lengths score in proportion. [docs/AI.md](docs/AI.md). |
| **Tired players, substitutions, tactics** | Players tire by the match clock (more in a sprint, less with stamina), slower and less accurate as they do; five substitutions (three more in extra time) made at a break, by the manager or by you from the pause menu, the man going off walking to the line. Tactics from the pause menu: a sweeper, two inside (the corner-forward out), short, mixed or long puck-outs; the computer's side has its county's habits and drops a sweeper back to hold a late lead. |
| **Your first match** | The coach on the sideline: the game in three lines before the throw-in, then a short tip the first time each thing comes up (the ball near you, the four steps, the solo, in range, close in, a tackle, your puck-out, your free, too many steps), in English and Irish. A ring on the grass shows where a high ball near you comes down. |
| **Modes** | Throw-in (any two counties, any ground); the Summer Championship (two groups of five, group finals, quarter-finals, semi-finals, the final) and the Tier Two Cup; Watch a match (AI v AI); a match behind the home screen. A result in the newspaper's style with the scorers and the box score. |
| **The counties** | Twenty, by their place names in English and Irish, rated from the 2025 and 2026 seasons, in their traditional colours in kit designs of the game's own (no crests, county-board jerseys, nicknames or real competitions). Every player is invented. |
| **Grounds** | The parish field at dusk (a small stand, a grass bank, ball-stop nets, floodlights, the trees and hills), the county ground by day and under lights, the national stadium. |
| **Languages** | English and Irish (Gaeilge), with the GAA's Irish terms and Irish plural forms. The game starts in the phone's language; the globe on the home screen changes it. A text-fit audit checks every screen in both languages at 16:9, 19.5:9, 20:9 with a camera cut-out and 4:3 (`tests/fit_audit.gd`). [docs/LANGUAGES.md](docs/LANGUAGES.md). |
| **Phones** | GL Compatibility renderer. Each ground's structure in a few draw calls, the crowd in one, a player in one (two with his outline on Medium and High). At the national stadium, the heaviest ground, the busiest frame of two seconds' play: **Low 68 draw calls and 138,000 triangles, Medium 91 and 284,000, High 161 and 674,000**; at the parish field 69 / 135,000, 92 / 259,000, 150 / 570,000 (`tests/perf_probe.tscn`, 0.2.0; round one's code measured the same way the same day: Low 63 / 127,000 at the stadium, and the same frame time). On a phone under 4.5 GB of memory or with a small GPU (Mali-G52/G57, Adreno 5xx/61x) the game starts on Low: simpler players (a third of the polygons), far ones posed less often, no outlines, no MSAA, 75% render scale, a thinner crowd, no 3D behind the menus; and it drops a level by itself if a match runs under about 36 frames a second. Frame rate: Battery saver (about 30, at 80% scale), 60, or Max. The beta APK is 27.5 MB (64-bit; 29.0 MB 32-bit), nearly all of it the engine: the game's own files (fonts subset to 312 KB, sounds mostly made in code, no textures) are about 1 MB; Play's bundle serves each phone only its own ABI. |

## Controls

On a phone: your left thumb anywhere on the left of the screen is a joystick that runs your player (the gold ring).
The buttons on the right are what he can do now: with the sliotar, STRIKE (for a point with the joystick toward the
posts or let go; a long ball to the teammate you point at), GOAL (close in), PASS (a hand-pass), SOLO (onto the
hurley before your four steps are up; the dots count them) and HAND (back into the hand, your second catch); without
it, CATCH, LIFT and PULL as it comes, TACKLE and BLOCK near the man on the ball; SWITCH changes your player. At your
restarts: LONG or SHORT puck-outs, STRIKE or PASS frees, 65s and sideline cuts, GOAL for a penalty. Settings: help
with the ball (Off, Solo, Full), match length, grade, coach's tips, button size, move buttons, left-handed. In the pause menu: substitutions and tactics.

On a keyboard: WASD or arrows, Space, J, K and L for the buttons, Q to switch, Esc to pause.

## Get it on your phone

Every push that touches `hurling-game/` runs the **Ash & Leather · Android build** action: it runs the tests, then
exports the beta APKs (64-bit ARM, and 32-bit ARM for older and Android Go phones) and puts them on the release page
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/ash-and-leather-beta. Open that page on the phone, tap
the APK, and allow your browser to install it. See [docs/BETA.md](docs/BETA.md).

For Google Play: [store/PLAY_STORE.md](store/PLAY_STORE.md) has every step, and the **Ash & Leather · Play Store
bundle** action builds the `.aab` (unsigned until the upload key is added as secrets; target API 36, 16 KB pages
checked, vibration the only permission).

## Play it in a browser

The **Web** export preset builds a browser version: single-threaded WebGL 2, so any static host serves it with no
special headers. Export it with `godot --headless --path . --export-release "Web" build/web/index.html`, serve
`build/web/` (for example `python3 -m http.server` in that folder) and open it. Phones and tablets play by touch,
computers by keyboard. Sound starts after the first tap or key, and saves stay in that browser.

## Run it on a computer

1. Install Godot 4.7 (standard build, not .NET).
2. Build the translations: `python3 tools/build_i18n.py`.
3. Open `project.godot` and press Play. Mouse clicks act as touches.

## Tests

```
godot --headless --path . res://tests/compile_check.tscn                              # every script compiles
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn                 # the rules, screens, scrolling, the championship, a match, the movement audit
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- out.jsonl      # text fit, both languages, four screen shapes
godot --headless --path . --fixed-fps 30 res://tests/user_bot.tscn -- play 4          # a thumb on the buttons plays a match
godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- 4 14 v         # AI matches, their numbers and events
godot --headless --path . --fixed-fps 30 res://tests/score_check.tscn -- 2            # scores at every length against real hurling's
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn      # touch: scrolling from anywhere, taps
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn   # draw calls, triangles
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/screenshots.tscn -- /out   # a tour of the screens
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/kit_view.tscn -- /out                     # kits and officials close up
```

## Project layout

```
autoload/   game.gd (settings, saves, theme, screens), db.gd (counties, players, grounds), sfx.gd (sounds)
game/       rules.gd (the playing rules, pure), match.gd (the match: play, restarts, fouls, cards, time, your player),
            team_ai.gd (shape, marking, decisions), officials.gd, player.gd (movement and poses), body.gd (the drawn
            player on its skeleton), sliotar.gd, pitch.gd, stadium.gd + geo.gd + crowd.gd (the grounds),
            camera_rig.gd, hud.gd, touch_controls.gd, championship.gd, sim.gd, records.gd, plural.gd, coach.gd,
            playtest_hook.gd (the Web build's state for browser playtests)
ui/         home screen (the programme), match setup (the team sheets), the championship, result, settings, how to
            play, move buttons, licences, language picker, loading screen, backdrop, drawn art, substitutions,
            tactics
i18n/       src/en.json, src/ga.json, strings.csv (generated)
fonts/      Noto Sans and Oswald (cut to the letters used), Uncial Antiqua; all SIL OFL
tools/      build_i18n.py, subset_fonts.py, check_scripts.py, check_pages.py, audio/make_music.py (the jig),
            store/ (icons, feature graphic, screenshots)
tests/      test_runner, fit_audit, user_bot, match_sim, score_check, input_test, perf_probe, screenshots, kit_view, compile_check
store/      PLAY_STORE.md, the listings, the icon, feature graphic and screenshots
docs/       RULES.md, LANGUAGES.md, AI.md, MESHY_BRIEF.md, BETA.md, PLAYTEST.md, PROGRESS.md
```

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, copy everything inside `hurling-game/` to the new
repo's root (including the hidden `.github/` folder) and push: `.github/workflows/android.yml` is set up for that
layout. Move the privacy and help pages (`ash-and-leather/` at the top of this repository) too, or keep them here.
