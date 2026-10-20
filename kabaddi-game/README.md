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
| **Raiding** | Cant, Hand touch (with aim assist), **Kick** (a toe touch to the front, or a back or side kick at a defender behind or beside you; a touch or kick counts only if the hand or foot gets to him), Dodge (a big gold **Break free** while you are held), **Dubki** (duck under high tackles and linked hands) and **Lion jump** (leap a dive at your ankles). When grabbed, push for the midline; the right escape breaks the hold more often. |
| **Moves and tendencies** | Every player has a rating for each raiding move. His best is his **signature**, and AI raiders use their strong moves far more than their weak ones. Every player also has ratings for the six **defensive skills** (ankle, thigh and waist hold, block, dash, chain) and a signature tackle; AI defenders pick their tackle by those ratings and by the moment (a dash only near a line, an ankle hold on a raider turning for home), and sharp ones read the raider's strengths. Ankle holds go low (beat them with a lion jump); thigh and waist holds go high (beat them with a dubki). You can read it in the wind-up. On Rookie and Pro the right escape button lights up when you raid, and Dash or Waist hold light up when you defend. Linked hands now catch a raider who runs into them. |
| **Defending** | Choose your tackle: **Ankle hold** (low), **Thigh hold**, **Waist hold** (lifts the raider so he can't push, and catches him even mid-jump) or **Dash** (shoves him over the side or end line, so use it near a line). Stand set in his path and he runs into a **block**. **Chain**: link hands with the nearest team-mate. You move slower together, but you both go in and hold on harder, and a raider who runs into linked hands gets caught. **Switch** jumps to the defender nearest the raider, and again to the next; or tap any of your defenders to take him over. Defenders keep their eyes on the raider, shuffling and backpedalling rather than turning their backs, and sharp ones pull back out of reach of a touch. Team-mates pile into a struggle one at a time; one defender can be dragged to the line, while two or three usually win. |
| **AI** | Raiders work the cover: light quick steps about 2 m from a defender, the odd feint to draw a dive, toe taps at a foot left in range, and a lunge for the touch when they go for corners and isolated or weaker tacklers, or they take an empty raid against a tight cover. Defenders stand a metre behind the baulk line, go in as the raider steps in, strikes or turns for home, and catch a raider who turns his back; team-mates run in to help a hold. The spacing and timing are measured from India v Pakistan Asian Games footage: see [docs/FOOTAGE_STYLE.md](docs/FOOTAGE_STYLE.md). |
| **Emotion** | Raiders slap their thighs before a raid and taunt the chain ("Aaja!"). Defenders call "Pakad!". Celebrations vary and don't come every time: roars, fist pumps, claps, chest thumps, pointing to the crowd, and team-mates jogging over for a high five. Out players sit on the bench in the sitting block. Winners roar, the beaten slump with hands on heads, players dispute touches ("Touch tha!" / "No touch!"), and there's the occasional shove after a tackle. Shouts are voiced and shown as speech bubbles in your language. |
| **Difficulty** | Rookie, Pro, Star and Legend change defender timing and aggression, AI raider skill, aim assist and how strict the cant rhythm is. |
| **Players** | Realistic textured bodies from a generated model (faces, knee pads, ankle guards), auto-rigged and driven by the game's animation. Each team's colours replace the model's kit, keeping its folds; skin is tinted to each player's tone; shirt numbers are added. In Quick Match each side's first two players wear the two players made in Meshy's web app. Strides match running speed; players side-shuffle, backpedal, shift their weight and look around. Switch to the classic code-built bodies in Settings. |
| **Cameras** | Third person and broadcast. The broadcast camera moves in while the raider is held and jolts at a takedown. See [docs/GRAPHICS.md](docs/GRAPHICS.md). |
| **Grounds** | Mumbai Dome, Gaon Maidan (village mud court), National Stadium (floodlit), Monsoon Ground (rain), Puri Beach (sand). Each has baked lighting, textured surfaces and its own colour grade; players cast shadows on every graphics level. See [docs/GRAPHICS.md](docs/GRAPHICS.md). |
| **Quick Match** | Any two league teams or countries, any ground. |
| **Season awards** | Every player's raid and tackle points are kept all season (simulated matches share each team's score by ability). At the end: best raider, best defender, and the **Arjuna Award** for the most valuable player, presented with a bronze statuette. |
| **League Season** | Own a franchise. **Choose up to six retentions** (stars cost more to keep), plan in the **war room** (what your squad still needs: a star raider, corners, covers; every lot with how well he fits, his age, last season's points and likely price; a shortlist with the most you will pay; the other franchises' purses and needs), then **bid at the auction**: categories A–D and New Young Players, paddles, "going once, going twice", bidding wars, record buys, **Final Bid Match cards**, an accelerated round, likely bidders on each lot, **auto-bid to your max** and a skip to your next target. Every franchise's auction is **graded**. Then the **board sets a goal** that moves next year's budget, and you play 11 rounds and the playoffs (top six, two eliminators, semis, final). Before each match: a **preview** (form guide, last meeting, key battles, their injuries) and **your seven**, picked with each player's form, fitness and knocks; tired players start with less energy. **Derbies** have louder crowds, the final opens with a **walk-out**, each round names a raider, defender and team of the week, the **record book** and **hall of fame** keep every season, and players age: the young improve, the old slow and retire. |
| **News** | A **ticker** of headlines written from what happens (upsets, thrashings, Super 10s, High 5s, runs, the table, clinched places, injuries, records, the auction, the board), several wordings for each story, the round's biggest story on the **front page**, **breaking news** that stops you until you have seen it, and the latest on the home screen. |
| **Nations Cup** | 8 countries, two groups, semis, final. **Pick your 12 from 18** (the regulars and six uncapped youngsters) and a **captain**; before your last group match you are told **what you need** ("India must beat Iran by 6 or more"); a **knockout bracket**; the **Golden Raider**, Best Defender and Player of the Tournament; the final's **walk-out**; and the **Underdog Trophy** for winning it with a side rated 70 or below (Kenya, Japan, Argentina...). Real flags and flag-accurate kits for 12 countries. |
| **Training** | Off the main menu for now; the code is kept (`ui/tutorial_menu.gd`). Each move acted out on a loop before you try it, then twelve lessons with on-screen objectives: cant, hand touch, toe touch, back and side kicks, dubki, lion jump, bonus, breaking a hold, tackling, chain tackle, waist hold, dash. |
| **Menus** | Built for wide phone screens: big mode tiles over a live AI match, each with a painted player in its colour, teams facing off in Quick Match, a full-screen player auction, How to play in short sections. Music plays in the menus (turn it off in Settings). |
| **Languages** | English, हिन्दी, मराठी, தமிழ், తెలుగు, ಕನ್ನಡ, বাংলা, ਪੰਜਾਬੀ. The game starts in the phone's language when it has it; the globe button on the main menu and Settings both change it. |
| **Audio** | A home crowd that builds as the raider goes deep, cheers, "ooh"s at a near miss, groans and applause; players grunt in a struggle, gasp when tackled and breathe hard after a raid; whistle, dhol, crowd chant, the raider's chant and players' shouts. All are placeholders (crowd and efforts synthesised by `tools/audio/make_sounds.py`; the chant and shouts from MBROLA Hindi voices by `tools/audio/make_voices.py`): drop real recordings into `assets/audio/` with the same file names. The menus' music is "Indian" by LNPLUSMUSIC (Pixabay), cut into a loop by `tools/audio/make_menu_music.py`. |

Points tables use Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1.

## Controls

On a phone:

- **Left thumb.** Touch anywhere on the left side for a floating joystick.
- **Right thumb.** Use the action buttons. Raiding: the pulsing *Cant*, *Hand touch*, *Kick*, *Dodge* (a big *Break free* while you are held, making the escape that suits the hold), *Dubki*, *Lion jump*. Defending: *Ankle hold*, *Thigh hold*, *Waist hold*, *Dash*, *Chain*, *Switch*.
- **Drag anywhere else** to look around (orbit the third-person camera).
- **Top right.** Camera and pause.
- **Left-handed layout.** Turn it on in Settings.
- **Who is who.** A tag over your player (edged in saffron) and over the raider gives his number and name, and
  everyone else on the mat has a tag with his number. The points go up with the scorer's name, and the player of
  the match is shown with his number. Settings → Display → Player tags puts names over everyone, or turns the
  tags off.

On a keyboard (the browser version on a computer, or the editor), each on-screen button shows its key:

- **Move.** WASD or arrow keys.
- **J.** Hand touch (defending: ankle hold).
- **K.** Kick: toe touch, or back/side kick (defending: thigh hold).
- **U.** Dubki (defending: dash).
- **I.** Lion jump.
- **Space.** Cant when raiding (Dodge when the cant is automatic), your usual tackle when defending, Skip on the walk-out.
- **L.** Dodge (defending: waist hold).
- **G.** Chain (link hands with the nearest team-mate).
- **Tab.** Switch defender (or click a defender).
- **C.** Change camera.
- **Esc** or **P.** Pause.

## Get it on your phone

The beta guide, [docs/BETA.md](docs/BETA.md), covers installing, updating, what to test and how to report.

Every push that touches `kabaddi-game/` runs the **Android build** GitHub Action. It runs the tests, then exports the
beta APK (64-bit ARM). To install it:

1. Open the workflow run on GitHub and download the `kabaddi-raid-VERSION-apk` artifact.
2. Unzip it and copy the `.apk` to your Android phone.
3. Open it and allow "install unknown apps" when Android asks.

The APK is signed with uber-apk-signer's public debug key, the same as the beta APKs sent by hand, so each
installs over the other. Shipping to the Play Store needs a release keystore. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, make a new repo, copy everything inside
`kabaddi-game/` to its root (including the hidden `.github/` folder), and push. `.github/workflows/android.yml`
is already set up for that layout and builds the APK on every push.

## Play it in a browser

The **Web** export preset builds a browser version: single-threaded WebGL 2, so any static host serves it with no
special headers. Export it with `godot --headless --path . --export-release "Web" build/web/index.html`, serve
`build/web/` (for example `python3 -m http.server` in that folder) and open it. About 75 MB loads the first time.
Phones and tablets play by touch, computers by keyboard. Sound starts after the first tap or key, and saves stay in
that browser.

## Run it on a computer

1. Install Godot 4.7 (standard build, not .NET).
2. Open `kabaddi-game/project.godot` and press Play.
3. Mouse clicks act as touches.

## Project layout

```
autoload/   game.gd (settings, saves, theme, screen switching), db.gd (teams, squads, grounds), sfx.gd (synth audio)
game/       match.gd (rules + AI), athlete.gd, human_model.gd (placeholder body + custom model slot),
            arena.gd (court + five grounds), camera_rig.gd, touch_controls.gd, hud.gd, cup.gd, career.gd,
            season.gd (the League Season: line-ups, fitness, the board, records, growth), news.gd (the headlines),
            scout.gd (a player's place, age, growth, strengths; a squad's needs and how well a player fits it),
            auction.gd
ui/         main menu, quick match setup, settings, how to play, Nations Cup (cup_screen, cup_squad), career hub,
            create player, League Season (season_hub, match_day, retention_screen, war_room, auction_screen,
            hall_of_fame), news_ticker (ticker, front page, breaking news), player_card, result screen
i18n/       src/*.json (one file per language), strings.csv (generated)
fonts/      Noto Sans (Latin, Devanagari, Bengali, Tamil, Telugu, Kannada, Gurmukhi) and Teko. All SIL OFL.
tests/      compile_check, test_runner (headless smoke test), screenshots (renders a visual tour),
            ai_bench (AI v AI balance, its raids beside match footage, and checks on the events), locomotion_check
            (foot skate, pops, snaps: see docs/MOTION_REALISM.md), tackle_check (holds made on contact, how
            the holds and falls move, and a held leg against its hold: docs/TACKLE_SYSTEM.md), raid_audit
            (ordinary AI raids from fixed seeds, every frame: contacts, grips, corrections, conflicting states,
            events, tackle phases, bodies inside one another, softlocks), match_record (an AI match to record,
            or to check against the audited one, frame for frame), tackle_reach (how far each dive
            reaches), defence_view (a match with the debug overlay), motion_view (gaits, celebrations,
            signals), play_video (a bot that plays), motion_audit (who moves each player in a frame, and what
            shakes: docs/REALISM_REVIEW.md), look_check (each ground at set moments, to compare a look change),
            fit_audit (every screen in every language at any phone's shape: words cut short, off the screen,
            over other words, or in letters no font has)
tools/      build_i18n.py, check_pages.py (an APK's or bundle's 16 KB pages), store_art.py (the store's pictures),
            rig/ (auto-rigging the player model), audio/ (crowd and player sounds),
            mocap/ (animation clips, and movement measured from match video), bake_lighting/ (the grounds'
            baked lighting), ground_art/ (court and stand textures)
store/      PLAY_STORE.md (every step to Google Play, and the answers to its forms), listing/ (the store text),
            graphics/ (icon, feature graphic, screenshots). The privacy policy and help pages are in ../kabaddi-raid/
docs/       ASSETS.md (how to drop in real humans), KABADDI.md (the rules), BETA.md (testing on a phone), ROADMAP.md,
            FOOTAGE_STYLE.md (how real raids play, measured from match video), MOTION_REALISM.md (movement and
            animation fixes, measured), TACKLE_SYSTEM.md (tackles and holds, measured), REALISM_REVIEW.md (the
            reviews of each video and beta, what was found and what changed), GRAPHICS.md (lighting, surfaces,
            shading, camera and picture)
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
godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn      # tackle scenarios: contact, grip, motion, events
godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- --audit   # ... and who moved whom each frame
godot --headless --path . --fixed-fps 30 res://tests/motion_audit.tscn     # movement stability: encounters and an AI match
godot --headless --path . --fixed-fps 30 res://tests/raid_audit.tscn -- 4 1 --digest /tmp/d.json   # 4 AI matches audited (run twice: the same)
godot --headless --path . --fixed-fps 30 res://tests/match_record.tscn -- 600 seed=1 trace=/tmp/r.json   # the audit's first match, unaudited
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- /tmp/fit.jsonl all 1280x720,2208x1840   # every screen, every language
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/screenshots.tscn -- /tmp/shots ta:hud   # the match's words in Tamil
```

The smoke test does five things:

- Compiles every script.
- Checks the data and all eight translations.
- Opens every screen.
- Runs a whole Nations Cup, plus a career auction and season through to the next season.
- Runs a League Season with your own retentions, a shortlist won on auto-bid, the grades, your picked seven on
  the mat (tired ones with less energy), the final's walk-out, the news, weekly awards, records, the board's
  verdict and a year's growth; and a Nations Cup with a picked squad, a captain, what you need, and its awards.
- Plays a full AI-vs-AI match under knockout rules.

## Translations

UI text lives in `i18n/src/<lang>.json`. English (`en.json`) is the source. The other seven were machine-drafted
and **need a native speaker's review before release**, especially the kabaddi terms. Run `tools/build_i18n.py` after
any change. Missing keys fall back to English.

## Names and likeness

All franchises, players, and league names are invented. Generated names are checked against a list of real star
players so no squad contains an exact match. Country teams use only country names and flag colours, not federation
marks.
