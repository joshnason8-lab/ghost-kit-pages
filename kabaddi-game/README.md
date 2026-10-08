# Kabaddi Raid

A 3D kabaddi game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no royalties).
It's aimed at Indian players: Pro-style rules, a fictional franchise league, international matches, and eight UI languages.

> **Status: playable prototype.** Players use a realistic body made from a generated 3D model, rigged by
> `tools/rig` and driven by the game's own animation code. Kit colours are painted per team. The classic code-built
> bodies are still available in Settings → Players. See [docs/ASSETS.md](docs/ASSETS.md) and
> [tools/rig/README.md](tools/rig/README.md).

## What's in it

| Area | What works today |
|---|---|
| **Match** | 7 v 7, two 20-minute halves of alternating 30-second raids. You raid, then you defend. The clock can run at 6× (about 7 minutes), 3× (about 14 minutes) or real time. |
| **The cant** | Raiders must chant "kabaddi" all raid. Tap the pulsing **Cant** button as its ring closes to keep your breath up. Run out of breath in their half and you're out. You can switch to an automatic cant in Settings. Each tap is voiced. |
| **Rules** | Touch points, bonus line (6+ defenders on the mat), baulk line, raid clock, out of bounds, lobbies (live only after a struggle), tackles, super tackles (3 or fewer defenders), chain holds, empty raids and do-or-die, revival in order of dismissal, all outs (+2), golden raid for tied knockouts. |
| **Raiding** | Cant, Hand touch (with aim assist), **Kick** (a toe touch to the front, or a back or side kick at a defender behind or beside you), Dodge, **Dubki** (duck under high tackles and linked hands) and **Lion jump** (leap a dive at your ankles). When grabbed, push for the midline; the right escape breaks the hold more often. |
| **Moves and tendencies** | Every player has a rating for each raiding move. His best is his **signature**, and AI raiders use their strong moves far more than their weak ones. Every player also has ratings for the six **defensive skills** (ankle, thigh and waist hold, block, dash, chain) and a signature tackle; AI defenders pick their tackle by those ratings and by the moment (a dash only near a line, an ankle hold on a raider turning for home), and sharp ones read the raider's strengths. Ankle holds go low (beat them with a lion jump); thigh and waist holds go high (beat them with a dubki). You can read it in the wind-up. On Rookie and Pro the right escape button lights up when you raid, and Dash or Waist hold light up when you defend. Linked hands now catch a raider who runs into them. |
| **Defending** | Choose your tackle: **Ankle hold** (low), **Thigh hold**, **Waist hold** (lifts the raider so he can't push, and catches him even mid-jump) or **Dash** (shoves him over the side or end line, so use it near a line). Stand set in his path and he runs into a **block**. **Chain**: link hands with the nearest team-mate. You move slower together, but you both go in and hold on harder, and a raider who runs into linked hands gets caught. **Switch** jumps to the defender nearest the raider. Team-mates pile into a struggle one at a time; one defender can be dragged to the line, while two or three usually win. |
| **Emotion** | Raiders slap their thighs before a raid and taunt the chain ("Aaja!"). Defenders call "Pakad!". Winners roar, the beaten slump with hands on heads, players dispute touches ("Touch tha!" / "No touch!"), and there's the occasional shove after a tackle. Shouts are voiced and shown as speech bubbles in your language. |
| **Difficulty** | Rookie, Pro, Star and Legend change defender timing and aggression, AI raider skill, aim assist and how strict the cant rhythm is. |
| **Players** | Realistic bodies from a generated model, auto-rigged and driven by the game's animation, with team kit colours, skin tones and shirt numbers. Switch to the classic code-built bodies in Settings. |
| **Cameras** | Third person, first person (drag to look), broadcast. |
| **Grounds** | Mumbai Dome, Gaon Maidan (village mud court), National Stadium (floodlit), Monsoon Ground (rain), Puri Beach (sand). |
| **Quick Match** | Any two league teams or countries, any ground. |
| **League Season** | Own a franchise. Retain your best six, then **bid at the auction**: categories A–D and New Young Players, paddles, "going once, going twice", bidding wars, record buys, **Final Bid Match cards**, and an accelerated round. Then play 11 rounds and the playoffs (top six, two eliminators, semis, final) and **lift the trophy**. |
| **Nations Cup** | 8 countries, two groups, semis, final. Real flags and flag-accurate kits for 12 countries. |
| **Career** | Create a player and pick his signature raiding move and signature tackle, get auctioned (with the same live auction), play seasons, train ratings and moves. |
| **Training** | Twelve lessons with on-screen objectives: cant, hand touch, toe touch, back and side kicks, dubki, lion jump, bonus, breaking a hold, tackling, chain tackle, waist hold, dash. |
| **Start menu** | A live AI match plays behind the menu on a rotating ground. |
| **Languages** | English, हिन्दी, मराठी, தமிழ், తెలుగు, ಕನ್ನಡ, বাংলা, ਪੰਜਾਬੀ. |
| **Audio** | Whistle, dhol, crowd, crowd chant, the raider's chant, and players' shouts. Voices are placeholder text-to-speech: drop real recordings into `assets/audio/` with the same file names. |

Points tables use Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1.

## Controls

On a phone:

- **Left thumb.** Touch anywhere on the left side for a floating joystick.
- **Right thumb.** Use the action buttons. Raiding: the pulsing *Cant*, *Hand touch*, *Kick*, *Dodge*, *Dubki*, *Lion jump*. Defending: *Ankle hold*, *Thigh hold*, *Waist hold*, *Dash*, *Chain*, *Switch*.
- **Drag anywhere else** to look around. Use it to aim in first person or to orbit the third-person camera.
- **Top right.** Camera and pause.
- **Left-handed layout.** Turn it on in Settings.

On a keyboard (for testing in the editor):

- **Move.** WASD or arrow keys.
- **J.** Hand touch (defending: ankle hold).
- **K.** Kick: toe touch, or back/side kick (defending: thigh hold).
- **U.** Dubki (defending: dash).
- **I.** Lion jump.
- **Space.** Cant when raiding, your usual tackle when defending.
- **L.** Dodge (defending: waist hold).
- **G.** Chain (link hands with the nearest team-mate).
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
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /tmp/shots moves   # raid moves
godot --headless --path . --fixed-fps 30 res://tests/ai_bench.tscn -- 4 1   # AI v AI balance: 4 matches on Pro
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
