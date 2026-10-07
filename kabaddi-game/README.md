# Kabaddi Raid

A 3D kabaddi game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no royalties).
It's aimed at Indian players: Pro-style rules, a fictional franchise league, international matches, and eight UI languages.

> **Status: playable prototype.** The athletes are code-built placeholder humans. The game is designed so real
> character models and motion capture can replace them without code changes. See [docs/ASSETS.md](docs/ASSETS.md).

## What's in it

| Area | What works today |
|---|---|
| **Match** | 7 v 7, two halves, alternating 30-second raids. You raid, then you defend. |
| **Rules** | Touch points, bonus line (6+ defenders on the mat), baulk line, raid clock, out of bounds, lobbies (live only after a struggle), tackles, super tackles (≤3 defenders), chain holds, empty raids and do-or-die, revival in order of dismissal, all outs (+2), golden raid for tied knockouts. |
| **Raiding** | Hand touch (with aim assist), toe touch, dodge. When grabbed, push for the midline and dodge to break holds. The raider chants automatically (no chant button). |
| **Defending** | Control one defender and **Tackle** when the raider is close. Teammates hold the chain, cut off the midline, and pile on for a chain tackle. **Switch** jumps to the defender nearest the raider. |
| **Cameras** | Third person (behind your player), first person (from your player's eyes, drag to look), and broadcast (side-on TV view). Change any time from the HUD. |
| **Grounds** | Mumbai Dome (indoor pro arena), Gaon Maidan (village mud court at golden hour), National Stadium (floodlit, international), Monsoon Ground (rain, wet mat), Puri Beach (sand court by the sea). |
| **Quick Match** | Any two league teams or any two countries, on any ground, at three lengths and difficulties. |
| **Nations Cup** | 8 countries, two groups of four, semi-finals and a final. Play or simulate each match. |
| **Career** | Create a player (name, home state, role, build, skin tone, hair), go into the **player auction** (franchises bid live, in lakhs and crores), play an 11-match league season and top-four playoffs, earn skill points, train, then do it again next season. |
| **League** | The Premier Raid League (PRL): 12 invented franchises with generated squads. |
| **Languages** | English, हिन्दी, मराठी, தமிழ், తెలుగు, ಕನ್ನಡ, বাংলা, ਪੰਜਾਬੀ. Picks the phone's language on first launch. |
| **Audio** | Whistle, dhol loop, crowd bed and roars, impacts. All synthesised in code. Replace any of them by dropping a file into `assets/audio/`. |

Points tables use Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1.

## Controls

On a phone:

- **Left thumb.** Touch anywhere on the left side for a floating joystick.
- **Right thumb.** Use the action buttons. Raiding: *Hand touch*, *Toe touch*, *Dodge*. Defending: *Tackle*, *Switch*.
- **Drag anywhere else** to look around. Use it to aim in first person or to orbit the third-person camera.
- **Top right.** Camera and pause.
- **Left-handed layout.** Turn it on in Settings.

On a keyboard (for testing in the editor):

- **Move.** WASD or arrow keys.
- **J.** Hand touch.
- **K.** Toe touch.
- **Space.** Dodge when raiding, Tackle when defending.
- **Tab.** Switch defender.
- **C.** Change camera.
- **Esc.** Pause.

## Get it on your phone

Every push that touches `kabaddi-game/` runs the **Android build** GitHub Action. It runs the tests, then exports a
debug APK. To install it:

1. Open the workflow run on GitHub and download the `kabaddi-raid-debug-apk` artifact.
2. Unzip it and copy the `.apk` to your Android phone.
3. Open it and allow "install unknown apps" when Android asks.

The debug build is signed with a throwaway debug key. Shipping to the Play Store needs a release keystore. See
[docs/ROADMAP.md](docs/ROADMAP.md).

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, make a new repo, copy everything inside
`kabaddi-game/` to its root (including the hidden `.github/` folder), and push. `.github/workflows/android.yml`
is already set up for that layout and builds the APK on every push.

## Run it on a computer

1. Install Godot 4.7 (standard build, not .NET).
2. Open `kabaddi-game/project.godot` and press Play.
3. Mouse clicks act as touches.

## Project layout

```
autoload/   game.gd (settings, saves, theme, screen switching), db.gd (teams, squads, grounds), sfx.gd (synth audio)
game/       match.gd (rules + AI), athlete.gd, human_model.gd (placeholder body + custom model slot),
            arena.gd (court + five grounds), camera_rig.gd, touch_controls.gd, hud.gd, cup.gd, career.gd
ui/         main menu, quick match setup, settings, how to play, Nations Cup, career hub,
            create player, auction, result screen
i18n/       src/*.json (one file per language), strings.csv (generated)
fonts/      Noto Sans (Latin, Devanagari, Bengali, Tamil, Telugu, Kannada, Gurmukhi) and Teko. All SIL OFL.
tests/      compile_check, test_runner (headless smoke test), screenshots (renders a visual tour)
tools/      build_i18n.py
docs/       ASSETS.md (how to drop in real humans), ROADMAP.md
```

## Tests

```sh
cd kabaddi-game
python3 tools/build_i18n.py                       # after editing i18n/src/*.json
godot --headless --path . --import
godot --headless --path . res://tests/compile_check.tscn
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /tmp/shots
```

The smoke test does five things:

- Compiles every script.
- Checks the data and all eight translations.
- Opens every screen.
- Runs a whole Nations Cup, plus a career auction and season through to the next season.
- Plays a full AI-vs-AI match under knockout rules.

## Translations

UI text lives in `i18n/src/<lang>.json`. English (`en.json`) is the source. The other seven were machine-drafted
and **need a native speaker's review before release**, especially the kabaddi terms. Run `tools/build_i18n.py` after
any change. Missing keys fall back to English.

## Names and likeness

All franchises, players, and league names are invented. Generated names are checked against a list of real star
players so no squad contains an exact match. Country teams use only country names and flag colours, not federation
marks.
