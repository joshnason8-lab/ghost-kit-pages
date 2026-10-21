# Floorstorm: progress

The floorball game built overnight on 21-22 October 2026 by a Claude Code session, on branch `claude/floorball-game`.
If you are resuming (after a usage limit, a restart or a context summary): read this file and `git log`, then carry
on with "Next".

## Done

- Research: the IFF Rules of the Game, edition valid from 1 July 2026 (the full PDF could not be fetched from this
  environment; built from the 2026 text's extracts, the IFF's "What's new" and the 2022 edition, see docs/RULES.md);
  markets, languages and real local terms (docs/LANGUAGES.md); the name (Floorstorm: no floorball game on Google
  Play, "Rink Rush" clashed).
- Project: Godot 4.7.2, GL Compatibility, self-contained in floorball-game/, infrastructure taken from a snapshot
  of Takraw Smash (commit 2b800d1 of claude/kind-clarke-3g5fqs): UI helpers, DragScroll, Geo, Crowd, the
  translation build, check_scripts/check_pages.
- game/rules.gd: the rules as a pure module (rink geometry and areas, restart spots, offences and sanctions, goals,
  the clock in both modes, the penalty bench with the 2026 coincidental rule, overtime, the penalty-shot competition).
- The match: rink and hall in code (game/arena.gd), the ball's physics (game/ball.gd), bodies on a humanoid
  skeleton with the stick as a bone (game/body.gd), players with one writer of position (game/player.gd), team AI
  in a 2-1-2 with flying line changes (game/team_ai.gd), the match (game/match.gd): face-offs, hit-ins, free-hits,
  advantage and delayed penalties, penalties and the bench, goalkeepers' saves, the 3-second rule, periods,
  overtime, the penalty-shot competition, two referees who signal; HUD with a floorball scoreboard and penalty
  timers; touch controls (joystick, three buttons, held SPRINT, left-handed, sizes, drag to move, saved).
- Menus: the whiteboard home screen with an AI v AI match behind it, Quick match setup, World Finals (16 teams,
  the World Championships' format), Settings (language, difficulty, game speed, auto switch, graphics + auto,
  frame rate, camera, numbers, sound, music, vibration, left-handed, button size, move buttons, About with
  privacy, help, licences and the seven-tap dev overlay), How to Play (controls, rules with numbers, the
  referees' signs drawn), result screen with a box score, loading screen.
- tests/test_runner: a check for each rule; AI matches with a motion audit (one write a frame, no jumps).
- AI calibrated with tests/ai_bench (per 60 minutes): 10.0 goals, 120 shots, 75.7% save rate, 5 penalties,
  30 face-offs (real: ~10 goals, ~95 shots, ~73% saves).

## Next (in order)

1. Translations (14 languages, being written), then fit_audit at 16:9, 19.5:9, 20:9 with a cut-out and 4:3.
2. CI: floorball-android.yml (tests, signed APK, beta release floorstorm-beta) and floorball-play-bundle.yml;
   the standalone-repo workflow in floorball-game/.github/workflows.
3. Pages floorstorm/ (index, privacy, support), icons, store graphics and screenshots, PLAY_STORE.md.
4. input_test (drag on text scrolls each scrolling page), perf_probe numbers per graphics level.
5. README, docs/RULES.md, docs/LANGUAGES.md, docs/MESHY_BRIEF.md.

## Decisions and why

- **Name: Floorstorm** ("Floorstorm: Floorball Arena" on Play, so a search for floorball finds it). No dedicated
  floorball game was found on Google Play; Rink Rush, Holeball and 26 Holes clashed with existing titles.
  A trademark search (EUIPO, USPTO) is for the owner before launch.
- **No governing body named in the game or store**: the brief rules out real governing bodies' names (Takraw had
  to remove them), so the game says "the international Rules of the Game"; docs cite the IFF.
- **National teams only**, players with invented names drawn from each country's common names.
- **Look: a coach's whiteboard in a Nordic sports hall**: light board, marker inks (Caveat), magnets as chips and
  buttons, notes pinned for the menu. Unlike Kabaddi's dark tiles and Takraw's navy panels.
- **Broadcast camera** high on the near side (the secretariat's), benches across the picture, as floorball TV does.
- **The stick is a bone of the body's skeleton**: one draw call a player with his stick.
- **Penalised players**: the rules module tracks who sits; on the rink the player's place is taken by a team-mate
  from the bench and the team plays short by hiding the wingers' places (simplified: the penalised player does not
  walk to the penalty bench).
- **Game speed Steady (80%) by default**: 12 players at real floorball pace is hard to follow on a phone screen.
- **Overtime keeps the third period's ends** (2026 rule 203 text on ends was not retrieved).
- **armeabi-v7a**: the Play bundle keeps 32-bit too (older phones in Thailand, the Philippines and eastern Europe
  run 32-bit Android); the beta APK is 64-bit only to keep it small, as Kabaddi's and Takraw's.
- **German with ss, not ß; the sport called Unihockey in German, French and Italian prose**: most German, French
  and Italian speaking floorball players are Swiss.

## Needs the owner

- Play Console account, the upload key as repository secrets (store/PLAY_STORE.md), a trademark search on the name.
- A native speaker's check of each translation (docs/LANGUAGES.md lists the doubtful strings).
- A read of the 2026 rules PDF against docs/RULES.md's items marked "verify".
