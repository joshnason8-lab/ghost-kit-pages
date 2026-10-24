# Sepak Takraw Unleashed

A sepak takraw game for Android phones, built with [Godot 4.7](https://godotengine.org) (free and open source, no
royalties), the same way as Kabaddi Raid. It is aimed at the sport's heartland, Southeast Asia, and plays the ISTAF
laws as they stand, with real-looking players, ball and crowds.

> **Status: playable beta.** The players are a man's and a woman's model (`assets/models/`), dressed in each team's
> colours, moving to motion capture (the spikes, the serve, the knee, the run and walk from Mixamo; the jumps in the
> block, the header spike and the celebration from the CMU library) and to the game's own key poses
> (`game/real_body.gd`, `game/moves.gd`, [docs/MOCAP.md](docs/MOCAP.md)).

## What's in it

| Area | What works today |
|---|---|
| **The laws** | ISTAF, since 1 February 2024: rally point, sets to 15 (from 14-all, win by two, up to 17), best of three (or one set), the serve alternating every point; the 21-point sets of the old rule as an option. Ends change after each set and at 8 in the third. Three touches a side, one player may make all three; a block counts as one. One video challenge a side a set. See [docs/TAKRAW.md](docs/TAKRAW.md), with its sources. |
| **The court** | 13.40 × 6.10 m, lines inside the court, the quarter circles and service circles where the laws put them, the net 1.52 m for men and 1.42 m for women, posts 30 cm outside the side lines, boundary tapes over the side lines. |
| **Events** | Regu (3), the team event (three regus, no player twice, first to two), quadrant (4) and doubles (2); men and women. |
| **The serve** | The score is called; the feeder throws to the tekong, who kicks with a foot in the circle while both inside players stand in their quarter circles. Quadrant and doubles servers serve from behind the back line. Instep serve or the horse-kick (sunback) serve. |
| **Touches** | Every touch is planned on the ball's exact flight: who can get there, and with what (sila, instep, thigh, chest, header, a diving dig), and when. On your side nothing is played for you: you run the lit player to the gold mark on the floor (with the assist, the setter and striker run to the set themselves), and he kicks only when you press; too early, too late or too far from the ball and he misses it. A match runs at 70% of real speed by default (Settings: Game speed). |
| **Attacks** | The roll spike (a full somersault), the sunback (the Malaysian *kalih*), the sole spike (*tapak*), the header spike and the feint; high or quick sets; the feeder's surprise second-touch attack. Spikes run up to about 30 m/s. |
| **Defence** | Blockers read the set and jump at the net, side on, a foot raised over it; defenders read the striker's approach and dig what they can reach, with the foot, chest or thigh. |
| **Faults** | Net touches, the ball under the net or outside the boundary tape, a fourth touch, out balls, the server's standing foot. |
| **Officials** | The referee in his high chair, the assistant at the other post, line judges who signal in and out, and now and then call a close one wrong. They follow the ball with their heads, breathe and shift their weight; the referee points to the side that won the point (`game/officials.gd`). Challenge it: a video review shows the ball's mark against the line, in millimetres. |
| **Broadcast touches** | Slow motion on a roll spike, replays of the great points, the crowd that rises with a long rally, drums in the arenas, call-outs (ROLL SPIKE!, BLOCKED!, ACE!), set point and match point. |
| **Venues** | Four indoor (the National Arena, the Grand Dome, a shopping-mall atrium where the world championship is played, a provincial gym) and four outdoor (a temple court, a floodlit park court, a beach at sunset, a night-market street), built from real-world pieces: photographed skies and surfaces, a Thai wat, stilt houses, shophouses and apartment blocks with lit windows, palms and rain trees, plastic chairs, park benches, a chain-link fence, market stalls and lanterns, metal bleachers, a maple gym floor with its clock and basketball boards, the sea moving at the beach ([docs/PROGRESS.md](docs/PROGRESS.md)). |
| **Modes** | Quick Match; League Season in club leagues run the way the real ones are, under plain names of the game's own: the Malaysia League (seven Grand Prix of groups of three, quarter-finals, semi-finals, the final and third place, worth the STL's points; the last two relegated; Division 1's finalists promoted into the same season), the Thailand League (home and away, every fixture a tie of two regus, 2 points for both, 1 for one each) and the Indonesia League (five regions, then the national finals in Jakarta; men and women); awards and the record book. International: the World Championship, the Royal Cup, the Asian and the Southeast Asian championships (groups, semi-finals, both losing semi-finalists take bronze, the final). |
| **Teams** | 22 national teams rated from 2025–26 results (men's and women's apart: Vietnam's women are near the top), 54 clubs: the real line-ups' states, provinces and services (Malaysia's 2026 Premier League and Division 1, Thailand's provincial clubs, Indonesia's five regions) under invented nicknames. Squads of nine with tekongs, feeders and strikers, each with ratings and a signature spike, known by shirt number: no player has a name, and none is a real person. |
| **Languages** | English, ไทย, Bahasa Melayu, Bahasa Indonesia, Tiếng Việt, ລາວ, မြန်မာ, ខ្មែរ, Filipino, 日本語, 한국어, 中文, हिन्दी. The game starts in the phone's language when it has it. A text-fit audit checks every screen in every language at 16:9 and at a Galaxy A16's shape (`tests/fit_audit.gd`), the way Kabaddi Raid's does. |
| **Phones** | GL Compatibility renderer; each venue's structure merged into a few draw calls, the crowd one draw call (people rendered from the players' models onto one small sheet), players one each (about 11,000 triangles, fewer at a distance). A match draws 72 to 86 draw calls and 100,000 to 140,000 triangles a frame on Low, depending on the venue, and 88 to 122 draw calls on High (`tests/perf_probe.tscn -- all`; every venue in docs/PROGRESS.md). Graphics on Auto (the default) pick the level for the phone each time the game starts: Low on a phone with a small GPU or under 4.5 GB of memory (a Galaxy A16's Mali-G57 MC2 or Mali-G68 MP2: no cast shadows or glow, no MSAA, a 75% render scale, a thinner crowd), High on a flagship GPU with 8 GB, Medium between; never above what a slow match lowered it to. Settings are in the pause menu too. A battery-saver frame rate. |

## Real life, without anyone's trademarks

The rules, the countries and their flags, the cities and the leagues' formats are real; the names are the game's own.
The leagues are the Malaysia, Thailand and Indonesia Leagues (not the Sepak Takraw League, the Takraw Thailand League or
Liga Sepak Takraw Indonesia), Malaysia's top flight the Premier Division, the world event a World Championship; no
federation, league, club, sponsor, venue company or phone maker is named in the game or its store listing; clubs are
the real line-ups' states, provinces and services under invented nicknames; players are shirt numbers. Settings >
About and the store listing say the game is independent and not endorsed by any of them.

## Controls

On a phone: the left thumb anywhere on the left of the screen is a joystick: it runs your lit player to the gold mark
on the floor (green when he is close enough), slides your blocker along the net, and aims serves and spikes. The right
thumb has the buttons for the touch that is coming; he kicks only when you press, as the ring closes on the ball.
Settings: play as (the whole team, or one player: the tekong, the feeder or the striker, the others played for you),
assist (Off: you run for every touch; Standard: for the first touch; Full: they run for you; you always time the
touch), game speed (Slow, Medium, Real), button size, left-handed. Pause a match for the same settings.

On a keyboard: WASD or arrows, Space for the first button, J and K for the others, Esc to pause.

## Get it on your phone

Every push that touches `takraw-game/` runs the **Sepak Takraw Unleashed · Android build** action: it runs the tests, then
exports the beta APK (64-bit ARM) and puts it on the release page
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/sepak-takraw-unleashed-beta. Open that page on the phone, tap the
APK, and allow your browser to install it. See [docs/BETA.md](docs/BETA.md).

For Google Play: [store/PLAY_STORE.md](store/PLAY_STORE.md) has every step, and the **Sepak Takraw Unleashed · Play Store
bundle** action builds the `.aab`.

## Run it on a computer

1. Install Godot 4.7 (standard build, not .NET).
2. Build the translations: `python3 tools/build_i18n.py`.
3. Open `project.godot` and press Play. Mouse clicks act as touches.

## Tests

```
python3 tools/check_scripts.py                                                       # every script parses
godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn                 # the smoke test CI runs
godot --headless --path . --fixed-fps 60 res://tests/match_sim.tscn -- 4              # AI matches, how rallies end
godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- out.jsonl      # text fit, every language
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- /out   # a tour of the screens
xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/venue_view.tscn -- /out   # every venue
```

## Project layout

```
autoload/   game.gd (settings, saves, theme, screens), db.gd (teams, squads, venues), sfx.gd (sounds)
game/       match.gd (the laws, the rally, the AI, challenges, replays), ball.gd, court.gd, player.gd,
            real_body.gd (the player's model, posed), moves.gd (every move's poses and contact),
            arena.gd + geo.gd + scenery.gd + crowd.gd (the venues), officials.gd, camera_rig.gd, hud.gd, touch_controls.gd,
            sim.gd (matches played out), season.gd, cup.gd, records.gd
ui/         main menu, quick setup, season, international, result, settings, how to play, records, licences
i18n/       src/*.json (one file per language), strings.csv (generated)
fonts/      Noto Sans for Latin and Vietnamese, Thai, Lao, Myanmar, Khmer, Devanagari, and Japanese, Korean and
            Chinese cut to the characters used (tools/subset_fonts.py); Teko. All SIL OFL.
tools/      build_i18n.py, subset_fonts.py, check_scripts.py, check_pages.py, audio/make_music.py,
            ui_art/render_art.tscn (the menu figures), store/ (icons, screenshots), meshy/ (the character order),
            models/ (shrinking the models, the kit masks, the crowd sheet, the moves from motion capture, bvh.gd)
tests/      test_runner, fit_audit, match_sim, screenshots, venue_view, crowd_view, officials_view, pose_view, rally_frames,
            compile_check
store/      PLAY_STORE.md, the listing in five languages, the icon, feature graphic and screenshots
docs/       TAKRAW.md (the sport, with sources), MOCAP.md (the motion capture, clip by clip), MESHY_BRIEF.md, BETA.md,
            ROADMAP.md, PROGRESS.md
```

## Moving it to its own repository

This folder is self-contained. To give the game its own repo, copy everything inside `takraw-game/` to the new
repo's root (including the hidden `.github/` folder) and push: `.github/workflows/android.yml` is set up for that
layout. Move the privacy and help pages (`takraw-smash/` at the top of this repository) too, or keep them here.
