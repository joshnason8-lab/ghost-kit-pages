# Pok Ta Pok Rivals

The hip ballgame of Mexico, for Android phones: **ulama de cadera** as it is still played in the villages of southern
Sinaloa, and the **classic stone court** of the old game, reconstructed from the chroniclers. Made in Godot 4.7 with
the GL Compatibility renderer, for low, mid and high-end phones.

> **Status: beta 0.1.0.** A full match by touch against the computer, both games, four courts, a town tournament,
> six languages. See [docs/PROGRESS.md](docs/PROGRESS.md) for what is done and what comes next.

## What's in it

- **Ulama de cadera**:
  - A heavy rubber ball (3.6 kg) struck with the hip only, across the analco of a 60 m earth court, by four or five a
    side.
  - The real count: one side holds it, rayas go up and down, and **urria** can wipe a count out. Eight wins.
  - The male serves, rolled (abajo) or thrown (arriba).
  - Two judges (veedores) at the analco call each raya.
- **The classic court (reconstructed)**:
  - An I-shaped stone court with sloped taluds, walls and end courts. Points to eight.
  - A stone ring in each wall. The ball through it wins outright, and it is rare.
- **Your thumb on the hip**:
  - Move with the left thumb.
  - Tap HIP as the heavy ball reaches you, or DIVE to the ground for a low one.
  - Aim deep, low and skidding, or across.
  - The ball's shadow and a ring on the earth help you read the bounce.
- **Sixteen towns** of Sinaloa and the Maya region, each with its own nickname and faja colours. All players are
  invented.
- **Four courts**:
  - A village court at dusk.
  - A festival court by day.
  - A stone court in the Yucatán forest under a pyramid.
  - The same court by torchlight.
- **A town tournament**: eight towns, knock-out to the final.
- **The home screen is a carved stela.** The ways to play are its glyph blocks, read in paired columns. Behind it, a
  match plays on.
- **How to Play**: the rules, the controls, the judges, and the story of the game and its words.
- **Box score after every match**: how the rayas were won, strikes, dives, serves, faults and the longest rally.
- **Languages**: Spanish, English, Portuguese (Brazil), French, German and Italian. The game starts in your phone's
  language.

The rules, their sources, and what is reconstructed are in [docs/RULES.md](docs/RULES.md).

## Controls

| | |
|---|---|
| Move | Left thumb anywhere on the left of the screen (a floating joystick) |
| HIP | Strike with the hip as the ball arrives |
| DIVE | Down to the ground for a low or rolling ball |
| Aim | Hold the joystick as you strike: toward their end (long and high), toward yours (low and skidding), across |
| SERVE | When your side serves |
| Pause | The pause button, or the phone's Back |
| Keyboard | WASD or arrows, Space, J, Esc |

Settings has the language, graphics (Auto, Low, Medium, High), frame rate (Battery saver, 60, Max), button size, Move
buttons, left-handed, help, vibration, sound and music.

## Get it on your phone

Download `pok-ta-pok-rivals-<version>.apk` from the
[**pok-ta-pok-rivals-beta** release](https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/pok-ta-pok-rivals-beta)
on your phone and open it. If Android asks, allow your browser to install unknown apps. On an older or Android Go
phone that will not install it, use `-32bit.apk`. Each beta installs over the last one and keeps your settings and
your tournament.

Privacy: [pok-ta-pok-rivals/privacy.html](../pok-ta-pok-rivals/privacy.html). The game collects nothing and asks for
no permission but vibration.

## Performance

Measured with `tests/perf_probe` in a match: ten players, two judges and the crowd. Low's budget is about 100 draw
calls and 90k triangles. The table is filled in by perf_probe; see docs/PROGRESS.md.

| Court | Low | Medium | High |
|---|---|---|---|
| (see docs/PROGRESS.md) | | | |

## Project layout

```
pok-ta-pok-game/
  project.godot, export_presets.cfg, main.gd/.tscn
  autoload/   game.gd (settings, theme, screens, haptics, graphics), db.gd (towns, courts, names), sfx.gd (sounds made in code)
  game/       rules.gd (the rules, pure), court.gd (the courts' shapes), ball.gd (the heavy ball), player.gd (one writer of
              position), moves.gd (the poses), body.gd (the code-built bodies), team_ai.gd, match.gd, hud.gd, officials.gd,
              venue.gd, geo.gd, scenery.gd, crowd.gd, camera_rig.gd, touch_controls.gd, cup.gd, sim.gd, plural.gd
  ui/         main_menu.gd (the stela), quick_setup.gd, court_diagram.gd, cup_screen.gd, result_screen.gd, settings_screen.gd,
              howto_screen.gd, licences_screen.gd, buttons_screen.gd, language_picker.gd, loading_screen.gd, ui.gd (fit helpers)
  i18n/src/   en.json (the source), es, pt, fr, de, it; tools/build_i18n.py makes strings.csv
  assets/     env/ (skies, surfaces, plant cut-outs from the shared assets and Poly Haven), icon/, audio/
  tests/      test_runner, fit_audit, input_test, user_bot, match_sim, perf_probe, compile_check, shot (pictures)
  tools/      build_i18n.py, subset_fonts.py, check_pages.py, check_scripts.py, env/sky_light.py, store/ (icons, store pictures)
  docs/       RULES.md, LANGUAGES.md, CULTURE.md, MESHY_BRIEF.md, PROGRESS.md
  store/      PLAY_STORE.md, listing/, graphics/
```

Run the tests headless:

```
python3 tools/build_i18n.py
godot --headless --path . --import
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- fit.jsonl
```
