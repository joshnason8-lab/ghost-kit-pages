# Netball Unleashed

A netball game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no
royalties) the same way as Kabaddi Raid and Takraw Smash. It plays the Rules of Netball as they stand (World Netball,
2024 edition), for the sport's players from Johannesburg to Lilongwe, Kingston, Auckland and Nuku'alofa, in their
languages.

> **Status: playable beta.** The players are the owner's own model (`game/hero_body.gd`, `tools/player/`), in each
> team's colours with the position's letters on the bib, running with the owner's Mixamo Fast_Run (shared with
> Hurling); the umpires are built in code (`game/body.gd`). Everything else is the game as it will ship.

## What's in it

| Area | What works today |
|---|---|
| **The rules** | World Netball's Rules of Netball, 2024 edition (current in October 2026), in a pure rules module with a test for each rule: seven positions and their areas, offside (on the line is fine, 2024), the centre pass alternating whoever scored and caught in the centre third, footwork and the landing foot, three seconds, short pass, over a third, obstruction at 0.9 m from the landing foot, contact, free pass, penalty pass, penalty pass or shot in the circle, the penalised player out of play beside the thrower, throw-ins, advantage, no toss-up (2024), a goal released before the whistle counts, only GS and GA score from the circle; warnings, two-minute suspensions and ordering off (replaced after four minutes), the umpires' advance and escalate; injury stoppages; four quarters with 4-12-4 minute intervals; extra time of 2 × 7 minutes and on to a two-goal lead. See [docs/RULES.md](docs/RULES.md), with its sources. |
| **The court** | 30.5 × 15.25 m in thirds, the 0.9 m centre circle, 4.9 m goal circles, posts 3.05 m with a 380 mm ring on its 150 mm arm and a net, padded post protectors, 3.05 m run-off, all to measure. |
| **Playing** | A full match against the AI, by touch. Play the whole team (you have whoever has the ball, and the defender nearest it) or pick a bib and play one position all match. With the ball she cannot run: turn with the stick, pick a team-mate, Pass or Lob within your three seconds; Shoot from the circle. In defence, Defend from 0.9 m (the ring round the landing foot turns red when you are closer) and Intercept passes you can reach. Nothing is played for you: hold on too long and it is held ball. A **coach** gives a short tip the first time each thing is needed in your first match (moving, passing, shooting, footwork, defending, intercepting, a whistle, the areas). |
| **The AI** | Plays the positions as they are played: leads into space and holds, the GS round the post, the GA at the circle's edge, the WA in the pocket, defenders goal-side of their player and on the ball at 0.9 m, the centre pass forward to the GA or WA. Tuned to real numbers: about 55 goals a team in 60 minutes, GS about 86% and GA about 77% shooting, few gains a match (docs/RULES.md "How the AI plays"). |
| **Officials** | Two umpires, each controlling her half (one goal third, half the centre third, a side line and a goal line), walking her side line with play; she blows, calls and signals each decision as World Netball's signals show it, then points the award. |
| **Broadcast touches** | A netball scoreboard (flags, scores, quarter, the clock counting down, the arrow to the next centre pass, DOUBLE ZONE when live), the call and award on screen, bibs over players' heads, crowd reactions, the swish of the net and the ring's clang. |
| **Modes** | Quick Match (any two of 23 nations, three venues, quarters of 5, 8, 10 or the real 15 minutes, four difficulty levels, the Double Zone league rule); the Nations Cup (two pools, semi-finals, bronze and final, tables by goal percentage, extra time in knockouts); the **Club Season** (eight invented clubs from Australia, New Zealand, England and South Africa, seven rounds, top four to the semi-finals, a grand final); league options (the Double Zone, time-outs, rolling changes); an Umpiring setting (fewer whistles, standard, or the real elite rate); records; an AI v AI match behind the home screen. |
| **After the match** | The score by quarter, the player of the match, and a box score for each side: goals from attempts and shooting %, feeds, assists, centre pass receives, gains, intercepts, deflections, rebounds, penalties, turnovers. |
| **Teams** | 23 national teams rated from the 2026 world ranking, by their plain names and flags (drawn in code; Northern Ireland, which has no official flag, gets a neutral one); squads of twelve with invented names from each country's common names. No national team's nickname, governing body, league or competition is named. |
| **Venues** | Realistic, from photo-scanned Poly Haven surfaces and skies (CC0) and the owner's own models. An arena at night under rigs of floodlights: a painted sprung-timber court in deep blue, brightest where the lights fall, the lamps reflected in it, a teal run-off framed by a glowing line, boards of plain colour, a bowl of two tiers of seated people with aisle lights and phones twinkling, and on Medium and High sections of the owner's metal courtside stand with people in their seats, beams of light and bloom. A community sports hall by day: a sprung maple floor with the netball court among the faint lines of other sports, painted block walls, blue pads, high windows, steel trusses with rows of fluorescent lights, clean regulation basketball boards, doors, clock, benches and a stepped stand of blue tip-up seats (a league crowd in its front rows on Medium and High). A park court at the end of the day under a photographed sky: green acrylic on asphalt, a chain-link fence, park benches, street lamps, jacarandas, oaks and broadleaves, terraced houses beyond, a street hoop on the next court, the floodlights coming on. The goals: a silver post, a glossy orange ring and a white corded net. |
| **Languages** | English, Afrikaans, isiZulu, isiXhosa, Sesotho, Setswana, Chichewa, Luganda, chiShona, Kiswahili, Bahasa Melayu, 中文, සිංහල, தமிழ், Cymraeg, Te Reo Māori, Lea Faka-Tonga, Gagana Sāmoa, Na Vosa Vakaviti. The game starts in the phone's language when it has it; the globe on the home screen changes it. A text-fit audit checks every screen in every language at four screen shapes (`tests/fit_audit.gd`). See [docs/LANGUAGES.md](docs/LANGUAGES.md); the translations await native speakers' checks (docs/translation_notes/). |
| **Phones** | GL Compatibility renderer; each venue a few draw calls (its structure, what glows, its lights, painted by its shaders; its models merged into one mesh with one texture atlas), the crowd one draw call, each player one (two with the outline). The players' model is 5,840 triangles (with its own levels for far away), 1,460 on Low. A match on the broadcast camera, before and after the realistic venues (draw calls / triangles, `tests/perf_probe.tscn`): **arena** Low 94 / 31,800 → 94 / 31,800, Medium 111 / 191,000 → 112 / 280,000, High 148 / 399,000 → 149 / 487,000; **hall** Low 94 / 31,300 → 96 / 74,600, Medium 110 / 190,000 → 113 / 273,000, High 147 / 397,000 → 152 / 492,000; **outdoor** Low 94 / 32,300 → 95 / 59,000, Medium 111 / 192,000 → 112 / 293,000, High 166 / 504,000 → 176 / 654,000 (the courtside and behind-the-goal cameras: at most 96 draw calls on Low and 180 on High). Budgets: 100 draw calls and 100,000 triangles on Low, for a Mali-G52 at 720p. The venues' copied assets (skies, surfaces, baked models and atlases in assets/venue) come to 9.4 MB (the arena's stand 0.5 MB of it). Phones with a small GPU or under about 4.5 GB of memory start on Low (no outlines, no MSAA, 75% render scale, a thinner crowd, fewer sides to each body part); auto graphics drops a level if the first 20 seconds of a match run under 36 fps. Frame rate: Battery saver (about 30 a second at 80% scale), 60, or the screen's maximum, each a whole fraction of the refresh rate. A developer overlay (frame-time percentiles, hitches, Copy summary) behind seven taps on the version. |
| **Play** | Target API 36, 64-bit with 16 KB pages (checked in CI), category Game, landscape, the only permission vibration; no internet, ads, purchases, analytics or data collected. The Play bundle carries 32-bit ARM too, for the older phones common in southern and eastern Africa. |

## Controls

On a phone: the left thumb anywhere on the left of the screen is a joystick: it runs your player (the lime ring),
or, when she has the ball, turns her and picks whom to pass to (a ring shows who). The right thumb has the buttons
for what she can do now: **Pass** and **Lob** with the ball, **Shoot** when your GS or GA has it in the circle;
**Intercept**, **Defend** and **Switch** in defence. Settings: Play as (Team or One position), Keep me onside,
button size, Move buttons (drag them where your thumb finds them; also in the pause menu), left-handed. The phone's
Back button pauses and resumes a match, goes back elsewhere, and quits from the home screen; the game pauses itself
when it loses focus.

On a keyboard: WASD or arrows, Space for the first button, J and K for the others, Esc to pause.

## Get it on your phone

Every push that touches `netball-game/` runs the **Netball Unleashed · Android build** action: it runs the tests,
then exports the beta APK (64-bit ARM) and puts it on the release page
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/netball-unleashed-beta. Open that page on the phone,
tap the APK, and allow your browser to install it. See [docs/BETA.md](docs/BETA.md).

For Google Play: [store/PLAY_STORE.md](store/PLAY_STORE.md) has every step and every App content answer, and the
**Netball Unleashed · Play Store bundle** action builds the `.aab` (unsigned until the upload key is added as
repository secrets).

## Play it in a browser

The **Web** export preset builds a browser version (single-threaded WebGL 2, so any static host serves it with no
special headers): `godot --headless --path . --export-release "Web" build/web/index.html`, then serve `build/web/`
(for example `python3 -m http.server` in that folder) and open it. Mouse clicks act as touches.

To run it in the editor instead:

1. Install Godot 4.7 (standard build, not .NET).
2. Build the translations: `python3 tools/build_i18n.py`.
3. Open `project.godot` and press Play.

## Tests

```
python3 tools/check_scripts.py                                                        # every script parses
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn                  # rules, screens, matches, motion, cup, controls
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- out.jsonl       # text fit, every language, four shapes
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn      # drag from anywhere (text too) scrolls
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/perf_probe.tscn   # draw calls per level
godot --headless --path . --fixed-fps 30 res://tests/match_trace.tscn -- 120           # a match's events, as they happen
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out en menus,match,store
node tools/playtest/play.js "http://localhost:8765/index.html?gfx=low&qs=25&fresh" /out 1280 720 quick   # play the Web build by touch in Chromium
```

`docs/PLAYTEST.md` is the record of playing the Web build as a first-time player would, and what was fixed.

## Project layout

```
autoload/   game.gd (settings, saves, theme, screens, graphics), db.gd (nations, squads, venues), sfx.gd (sounds: the
            recordings in assets/audio/, a few synthesised; venue beds, crowd reactions, 3D sounds on court)
game/       rules.gd (the Rules of Netball, pure), court.gd (the court's measurements), match.gd (the match: phases,
            calls, scoring, the box score), ai.gd (both teams' play), player.gd (movement, one writer a frame),
            hero_body.gd (the players: the owner's model, the team's colours, the bib, the clips), body.gd (the
            skeleton, and the umpires drawn in code), poses.gd (every pose and umpire signal),
            ball.gd, umpire.gd, arena.gd + geo.gd + crowd.gd (the venues), camera_rig.gd, hud.gd,
            touch_controls.gd, dev_overlay.gd, sim.gd (matches in numbers), cup.gd, records.gd
ui/         home (main_menu, court_third, bib_button), quick setup, settings, how to play, result, cup, records,
            licences, language picker, button layout, ui.gd (the helpers: fit, shrink, bits, keep_on_screen),
            drag_scroll.gd, flags.gd, icon.gd
i18n/       src/*.json (one file per language), strings.csv (generated)
fonts/      Noto Sans (Latin, cut), Noto Sans Sinhala and Tamil (cut to their scripts), Noto Sans SC (cut to the
            characters used), Barlow Condensed. All SIL OFL.
tools/      build_i18n.py, subset_fonts.py, check_scripts.py, check_pages.py, art/make_bib_letters.py,
            audio/ (make_music.py: the menu music; make_sounds.py: the sounds, from the downloads in docs/SOUNDS.md),
            store/ (icons, feature graphic), player/ (bakes the owner's model into assets/player/: README.md)
tests/      test_runner, fit_audit, input_test, perf_probe, match_trace, screenshots, compile_check, controls_only,
            player_view (the players' model up close)
store/      PLAY_STORE.md, the listings (store/listing/), the icon, feature graphic and screenshots
docs/       RULES.md, LANGUAGES.md, PROGRESS.md, BETA.md, MESHY_BRIEF.md, SOUNDS.md (every sound: source, author,
            licence), translation_notes/
```

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, copy everything inside `netball-game/` to the new
repo's root (including the hidden `.github/` folder) and push: `.github/workflows/android.yml` is set up for that
layout. Move the privacy and help pages (`netball-unleashed/` at the top of this repository) too, or keep them
here, and change `PRIVACY_URL` and `SUPPORT_URL` in `autoload/game.gd` if their address changes.
