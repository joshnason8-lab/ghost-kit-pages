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
| **Raid rule** (Settings) | The traditional **cant**, two ways: **Breath** (the default, hands free: the raider chants on one breath, longer for fitter, fresher raiders; sprinting, moves and struggling in a hold use it up faster) or **Tap** (tap Cant on the beat; every move counts as a beat). Or the **30-second clock**, the Pro rule with no chant. |
| **Rules** | Touch points; bonus line with 6+ defenders on the mat, including the airborne bonus (a leg stretched over the line); baulk line; out of bounds, with the lobbies live only after contact; defenders crossing the midline, or diving or dashing out, are out; tackles and super tackles (3 or fewer defenders); chain holds; empty raids and do-or-die; revival in order of dismissal; all outs (+2, everyone back); the 5-second rule to start a raid; green and yellow cards for rough play (a yellow is two minutes off and a technical point). Super 10 and High 5 are called out. Drawn knockouts use the Pro tie-breaker: five raids each by different raiders, then a coin toss and golden raids with the baulk line as the bonus line. |
| **Energy and time outs** | Raids, dives and holds tire players; they recover between raids, faster on the bench and at half time. Two 30-second time outs per team per half: call yours from the pause menu, and the AI calls one when tired or after a run of points. Team energy and time outs left show on the scoreboard. |
| **Officials** | Referee and scorers' table at the midline, an umpire on each side line, a line judge at each end line. They follow the raid and make the hand signals: points (with the number), bonus, out, all out, time out, half time, match end and cards. See [docs/KABADDI.md](docs/KABADDI.md). |
| **Raiding** | Cant, Hand touch (with aim assist), **Kick** (a toe touch to the front, or a back or side kick at a defender behind or beside you), Dodge, **Dubki** (duck under high tackles and linked hands) and **Lion jump** (leap a dive at your ankles). When grabbed, push for the midline; the right escape breaks the hold more often. |
| **Moves and tendencies** | Every player has a rating for each raiding move. His best is his **signature**, and AI raiders use their strong moves far more than their weak ones. Every player also has ratings for the six **defensive skills** (ankle, thigh and waist hold, block, dash, chain) and a signature tackle; AI defenders pick their tackle by those ratings and by the moment (a dash only near a line, an ankle hold on a raider turning for home), and sharp ones read the raider's strengths. Ankle holds go low (beat them with a lion jump); thigh and waist holds go high (beat them with a dubki). You can read it in the wind-up. On Rookie and Pro the right escape button lights up when you raid, and Dash or Waist hold light up when you defend. Linked hands now catch a raider who runs into them. |
| **Defending** | Choose your tackle: **Ankle hold** (low), **Thigh hold**, **Waist hold** (lifts the raider so he can't push, and catches him even mid-jump) or **Dash** (shoves him over the side or end line, so use it near a line). Stand set in his path and he runs into a **block**. **Chain**: link hands with the nearest team-mate. You move slower together, but you both go in and hold on harder, and a raider who runs into linked hands gets caught. **Switch** jumps to the defender nearest the raider, and again to the next; or tap any of your defenders to take him over. Defenders keep their eyes on the raider, shuffling and backpedalling rather than turning their backs, and sharp ones pull back out of reach of a touch. Team-mates pile into a struggle one at a time; one defender can be dragged to the line, while two or three usually win. |
| **AI** | Raiders work the cover: light quick steps just outside a defender's reach, the odd feint to draw a dive, toe taps at a foot left in range, and they go for corners and isolated or weaker tacklers when there is an opening, or take an empty raid against a tight cover. Defenders hold their shape, go in as the raider strikes or turns for home, and catch a raider who turns his back. |
| **Emotion** | Raiders slap their thighs before a raid and taunt the chain ("Aaja!"). Defenders call "Pakad!". Celebrations vary and don't come every time: roars, fist pumps, claps, chest thumps, pointing to the crowd, and team-mates jogging over for a high five. Out players sit on the bench in the sitting block. Winners roar, the beaten slump with hands on heads, players dispute touches ("Touch tha!" / "No touch!"), and there's the occasional shove after a tackle. Shouts are voiced and shown as speech bubbles in your language. |
| **Difficulty** | Rookie, Pro, Star and Legend change defender timing and aggression, AI raider skill, aim assist and how strict the cant rhythm is. |
| **Players** | Realistic bodies from a generated model, auto-rigged and driven by the game's animation, with team kit colours, skin tones and shirt numbers. Strides match running speed; players side-shuffle, backpedal, shift their weight and look around. Switch to the classic code-built bodies in Settings. |
| **Cameras** | Third person and broadcast. |
| **Grounds** | Mumbai Dome, Gaon Maidan (village mud court), National Stadium (floodlit), Monsoon Ground (rain), Puri Beach (sand). |
| **Quick Match** | Any two league teams or countries, any ground. |
| **Season awards** | Every player's raid and tackle points are kept all season (simulated matches share each team's score by ability). At the end: best raider, best defender, and the **Arjuna Award** for the most valuable player, presented with a bronze statuette. |
| **League Season** | Own a franchise. Retain your best six, then **bid at the auction**: categories A–D and New Young Players, paddles, "going once, going twice", bidding wars, record buys, **Final Bid Match cards**, and an accelerated round. Then play 11 rounds and the playoffs (top six, two eliminators, semis, final) and **lift the trophy**. |
| **Nations Cup** | 8 countries, two groups, semis, final. Real flags and flag-accurate kits for 12 countries. |
| **Training** | Each move acted out on a loop before you try it, then twelve lessons with on-screen objectives: cant, hand touch, toe touch, back and side kicks, dubki, lion jump, bonus, breaking a hold, tackling, chain tackle, waist hold, dash. |
| **Menus** | Built for wide phone screens: big mode tiles over a live AI match, teams facing off in Quick Match, a full-screen player auction, How to play in short sections. |
| **Languages** | English, हिन्दी, मराठी, தமிழ், తెలుగు, ಕನ್ನಡ, বাংলা, ਪੰਜਾਬੀ. |
| **Audio** | A home crowd that builds as the raider goes deep, cheers, "ooh"s at a near miss, groans and applause; players grunt in a struggle, gasp when tackled and breathe hard after a raid; whistle, dhol, crowd chant, the raider's chant and players' shouts. All are placeholders (crowd and efforts synthesised by `tools/audio/make_sounds.py`; the chant and shouts from MBROLA Hindi voices by `tools/audio/make_voices.py`): drop real recordings into `assets/audio/` with the same file names. |

Points tables use Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1.

## Controls

On a phone:

- **Left thumb.** Touch anywhere on the left side for a floating joystick.
- **Right thumb.** Use the action buttons. Raiding: the pulsing *Cant*, *Hand touch*, *Kick*, *Dodge*, *Dubki*, *Lion jump*. Defending: *Ankle hold*, *Thigh hold*, *Waist hold*, *Dash*, *Chain*, *Switch*.
- **Drag anywhere else** to look around (orbit the third-person camera).
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
- **Tab.** Switch defender (or click a defender).
- **C.** Change camera.
- **Esc.** Pause.

## Get it on your phone

The beta guide, [docs/BETA.md](docs/BETA.md), covers installing, updating, what to test and how to report.

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
tests/      compile_check, test_runner (headless smoke test), screenshots (renders a visual tour),
            ai_bench (AI v AI balance), motion_view (gaits, celebrations, signals), play_video (a bot that plays)
tools/      build_i18n.py, rig/ (auto-rigging the player model), audio/ (crowd and player sounds)
docs/       ASSETS.md (how to drop in real humans), KABADDI.md (the rules), BETA.md (testing on a phone), ROADMAP.md
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
