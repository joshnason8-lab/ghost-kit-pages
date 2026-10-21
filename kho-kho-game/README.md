# Khamba Dash

A kho kho game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no
royalties), the same way as Kabaddi Raid and Takraw Smash. "Khamba" is the pole, in Hindi and Marathi. It plays the
classic rules of the national championships and the fast rules of the 2025 world championship, for the sport's
players in India, Nepal, Bangladesh and Sri Lanka, in fourteen of their languages.

> **Status: playable beta.** The players are built in code (`game/body.gd`) on a humanoid skeleton, ready to be
> replaced by Meshy models (docs/MESHY_BRIEF.md). No Meshy credits have been spent. Everything else is the game as it
> will ship.

## What's in it

| Area | What works today |
|---|---|
| **The laws** | Two rule books ([docs/RULES.md](docs/RULES.md), with sources and every conflict between them). **Classic**: nine a side (eight seated, one active chaser), 1 point an out, 9-minute turns, the follow-on at a 9-point lead. **Fast**: seven a side (six seated), 2 points an out, 7-minute turns, dream runs (a point at 3 minutes, another every 30 s), the wazir and a power play each turn. Both: two innings of a chasing and a defending turn each; extra innings, then minimum chases, for a tied knockout. Every law is in a pure module (`game/rules.gd`) with a headless test for each. |
| **The field** | Classic 27 × 16 m: a 30 cm central lane, 24 m pole to pole, eight cross lanes 35 cm wide (the first 2.55 m from the pole, then 2.30 m apart), 1.5 m free zones, 1.225 m poles. Fast 22 × 16 m: six cross lanes 40 cm wide. |
| **The kho** | Run up behind a seated chaser whose back is to you; KHO is a palm on his back and the call, and you are him, rising on the far side of the lane. A late kho is a foul. |
| **The active chaser** | Takes his direction with his first run and may not turn back, may not cross the lane, turns only round a pole in the free zone. Fouls are whistled again and again until put right; a touch during a foul does not count. Lane assist (Settings) keeps your chaser legal unless you turn it off. |
| **Outs** | A touch, a sky dive, a pole dive, a step over the line, a late entry. Defenders on in batches of three; the next batch comes on when one is out. |
| **Officials** | Two umpires, one on each side line, each with his half: a short whistle and an arm up for an out, short whistles and an arm pointing the way for a foul. The referee signals the end of a turn; the timekeeper and scorer sit at the table under the shamiana. |
| **The AI** | Chasers chain khos along the lane toward the defender, dive at the lines, turn at the poles; defenders keep behind the chaser's direction, across from the seated chasers who could rise at them, slip past him as he commits and swerve from the hand. Measured against real finals: about 2 outs a minute between equal sides (real: 1.3-1.6). [docs/AI.md](docs/AI.md) has every number. |
| **Grounds** | A village ground of beaten earth at dusk, a school ground by day, an indoor arena on mats (the fast game's), a floodlit stadium of red earth. |
| **Modes** | Quick Match (either rule book, any two sides, the toss called and the choice made), Championships (16 nations at a world championship, fast rules; 16 states at a national championship, classic rules; men's and women's; groups, quarter-finals, semi-finals, the final), Watch a Match, Records. A match plays behind the home screen. |
| **Teams** | 24 nations (from the 2025 world championship) and 18 Indian states, rated from 2025-26 results, men's and women's apart. Squads of 15, every player invented (names from each region's common names, never a real player's). |
| **Languages** | English, हिन्दी, मराठी, ಕನ್ನಡ, తెలుగు, தமிழ், മലയാളം, ଓଡ଼ିଆ, বাংলা, ગુજરાતી, ਪੰਜਾਬੀ, অসমীয়া, नेपाली, සිංහල ([docs/LANGUAGES.md](docs/LANGUAGES.md)). The game starts in the phone's language; the globe on the home screen changes it. A text-fit audit checks every screen in every language at 16:9, 19.5:9, 20:9 with a camera cut-out and 4:3 (`tests/fit_audit.gd`). |
| **Phones** | GL Compatibility renderer. Each ground merged into three draw calls, the crowd one, every player's shadow one. Low graphics: lighter bodies, no outlines, no MSAA, 75% render scale, a thinner crowd; a phone with a small GPU or under 4.5 GB of memory starts on Low, and a match running under 36 frames a second drops a level. Battery saver: about 30 frames a second at 80%. The numbers are below. |

Per frame in a match (`tests/perf_probe.tscn`, Godot 4.7.2, 1280 × 720):

| Ground | Low | Medium | High |
|---|---|---|---|
| Village ground | 75 draws, 70k triangles | 98 draws, 254k triangles | 154 draws, 548k triangles |
| School ground | 75 draws, 70k triangles | 98 draws, 254k triangles | 154 draws, 547k triangles |
| Indoor arena (fast game: 24 players) | 84 draws, 89k triangles | 113 draws, 322k triangles | 179 draws, 671k triangles |
| Floodlit stadium | 75 draws, 71k triangles | 98 draws, 257k triangles | 152 draws, 541k triangles |

Budgets: Low 90 draw calls and 90,000 triangles (a Mali-G52 at 720p, 30 frames a second), Medium 130 and 340,000,
High 190 and 700,000. The game is about BUNDLE_MB MB to download (the Play bundle's arm64 split); the fonts are 2.4 MB.

## Controls

On a phone, held sideways:
- **Chasing** (your side is always the one chasing or defending, by turns): you are the active chaser, ringed in gold.
  The left thumb, anywhere on the left, is the joystick. Touch a defender and he is out. **KHO** (it pulses when a
  seated chaser is in reach, his square ringed) gives the kho; **DIVE** throws you at the nearest defender, or is a
  pole dive in the free zone. In the fast game, **POWER PLAY** shows for a few seconds as each batch comes on.
- **Defending**: you run one of the batch; **DODGE** is a burst, **SWITCH** takes another defender.
- Settings: lane assist, button size, Move buttons (drag them, saved), left-handed, vibration (only for what happens
  to you), camera (broadcast, close, behind the pole).
- The phone's back button pauses a match and resumes it; elsewhere it is Back; on the home screen it quits.

On a keyboard: WASD or arrows, Space for the first button, J and K for the others, Esc to pause.

## Get it on your phone

Every push that touches `kho-kho-game/` runs the **Khamba Dash · Android build** action: it runs the tests, then
exports the beta APK (64-bit ARM) and puts it on the release page
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/khamba-dash-beta. Open that page on the phone, tap the
APK, and allow your browser to install it. See [docs/BETA.md](docs/BETA.md).

For Google Play: [store/PLAY_STORE.md](store/PLAY_STORE.md) has every step, and the **Khamba Dash · Play Store
bundle** action builds the `.aab` (64- and 32-bit ARM, so Android Go phones get it too).

## Play it in a browser

The **Web** export preset builds a browser version: `godot --headless --path . --export-release "Web"
build/web/index.html`, then serve `build/web/` (for example `python3 -m http.server` in that folder) and open it.
Phones play by touch, computers by keyboard; sound starts after the first tap; saves stay in that browser.

## Run it on a computer

1. Install Godot 4.7 (standard build, not .NET).
2. Build the translations: `python3 tools/build_i18n.py`.
3. Open `project.godot` and press Play. Mouse clicks act as touches.

## Tests

```
python3 tools/check_scripts.py                                                          # every script parses
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn                    # the laws, screens, championships, AI matches, motion
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- out.jsonl         # text fit, every language, four shapes
godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- 2 classic 180     # AI v AI against real matches
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn        # scrolling from anywhere, taps
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/perf_probe.tscn        # draw calls and triangles
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out [lang] [WxH]   # a tour
```

## Project layout

```
autoload/   game.gd (settings, saves, theme, fonts, screens), db.gd (nations, states, squads, grounds), sfx.gd
game/       rules.gd (the laws), match.gd (turns, the chase, the AI, the officials, your controls), athlete.gd
            (the one place a player's position is written), body.gd (the drawn player on its skeleton), poses.gd,
            arena.gd + geo.gd + crowd.gd (the grounds), hud.gd, touch_controls.gd, sim.gd (matches in numbers),
            cup.gd (championships), records.gd, dev_overlay.gd (seven taps on the version)
ui/         main menu (the kho lane, kho_lane.gd), match setup and toss, settings, how to play, records, result,
            championships, licences, move buttons, the shared builders (ui.gd), flags, crests, field icons
i18n/       src/*.json (one file per language), strings.csv (generated)
fonts/      Noto Sans and its Devanagari, Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam and
            Sinhala, and Baloo 2, each cut to its script (tools/subset_fonts.py). All SIL OFL.
tools/      build_i18n.py, subset_fonts.py, check_scripts.py, check_pages.py, audio/make_music.py, store/
tests/      test_runner, fit_audit, input_test, match_sim, perf_probe, screenshots, compile_check
store/      PLAY_STORE.md, listings, the icon, feature graphic and screenshots
docs/       RULES.md, LANGUAGES.md, AI.md, MESHY_BRIEF.md, BETA.md, PROGRESS.md, translation-notes/
```

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, copy everything inside `kho-kho-game/` to the new
repo's root (including the hidden `.github/` folder) and push: `.github/workflows/android.yml` is set up for that
layout. Move the privacy and help pages (`khamba-dash/` at the top of this repository) too, or keep them here.
