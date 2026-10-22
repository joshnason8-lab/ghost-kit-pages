# Floorball Unleashed: progress

The floorball game built overnight on 21-22 October 2026 by a Claude Code session, on branch `claude/floorball-game`.
If you are resuming (after a usage limit, a restart or a context summary): read this file and `git log`, then carry
on with "Next".

## Done

- Research: the IFF Rules of the Game, edition valid from 1 July 2026 (the full PDF could not be fetched from this
  environment; built from the 2026 text's extracts, the IFF's "What's new" and the 2022 edition, see docs/RULES.md);
  markets, languages and real local terms (docs/LANGUAGES.md); the name (Floorball Unleashed: no floorball game on Google
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

- 15 languages in the game and in store listings (AI translators with each country's federation terms; doubts in
  docs/LANGUAGES.md); fit_audit clean: 15 languages x 16:9, 19.5:9, 20:9 with a cut-out, 4:3 (Thai's space-free lines
  exempt from the whole-word check, as Japanese is).
- input_test: every scrolling page scrolls when a drag starts on its text. test_runner: 436 checks green.
- CI: floorball-android.yml (tests, fit audit, input test, APK signed with the public debug key, release
  floorball-unleashed-beta), floorball-play-bundle.yml (passed, unsigned); standalone workflows in floorball-game/.github.
- Draft PR #7, subscribed. Pages in floorball-unleashed/. Icon, menu music. README, RULES, LANGUAGES, MESHY_BRIEF, PLAY_STORE.

- Penalty shot awarded in play for a foul on a clear chance (tested); time-outs granted at the next stoppage, the AI
  calling one a goal down late; store screenshots (7) and feature graphic; perf numbers in the README (Low: 89 draw
  calls, 49k triangles); CI green; beta APK 0.1.0-beta on the floorball-unleashed-beta release (31 MB).
- **Initial build complete** (21 October 2026, about 10:40 UTC).

### Round two: 0.2.0-beta (21 October 2026, evening)

- **Played through** in Chromium on the Web export with real touch events at 1280 x 720, 1600 x 720 and
  2400 x 1080 on Low: Quick match and World Finals matches, screenshots looked at. docs/PLAYTEST.md lists what was
  found, worst first, and what was fixed (with a test where one could be written). The worst: your free-hit could
  not be taken by touch; a penalty that ran out left the team short; a won tackle went straight back to the carrier;
  shots were deflected almost every time; a carrier behind the goal was stuck; the ball and your player were hard to
  see; Low graphics were 40% too dark.
- **A coach for the first match**: seven tips, each once, as its moment comes (Settings > Coach tips), 15 languages.
- **The club season**: ten invented clubs with crests, a single round robin, 3-2-1-0 points, no draws, semi-finals
  1 v 4 and 2 v 3 and a final (game/season.gd, ui/season_screen.gd).
- **The empty net**: a goal or two down late in the last period, the goalkeeper off for a sixth outfield player.
- **The penalty bench seen**: the penalised player walks there and sits out his time.
- **Delay of game (507.20)**: passive play warned with the arm up, then a free-hit; your restart kept waiting goes to
  the other team.
- **Rules re-checked** against extracts of the 2026 text (the PDF itself still blocked here): free-hit 3.5 m from the
  goalkeeper area; the personal penalty 2 + 10 sat by the offender; a goalkeeper sits his own major and personal
  penalties; rule numbers 603 and 508-510. docs/RULES.md ends with what is still to check.
- **AI retuned** after the tackle and deflection fixes: per 60 minutes 9.5 goals, 101 shots (real ~10 and ~95).
- tools/ci_local.sh runs CI's checks before each push; the Android build runs on push only (no double runs).
- **0.2.0-beta** (version code 2).

## Next (in order)

1. Phone testing on a low-end device (Galaxy A0x/A1x class): frame rate on Low, touch feel, button reach, the coach's
   notes on a real screen.
2. The 2026 rules PDF read against docs/RULES.md's "Still to check" list.
3. Native-speaker review of the translations (docs/LANGUAGES.md), the coach's tips first.
4. Club season extras: a short 3 v 3 overtime as the Nordic leagues play it, a second season, form and streaks.
5. The penalty benches and secretariat as real models; Meshy bodies if the owner wants them (docs/MESHY_BRIEF.md).
6. The World Finals' tables in bigger type on phones.

## Decisions and why

- **Name: Floorball Unleashed** ("Floorball Unleashed" on Play, so a search for floorball finds it). No dedicated
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
  from the bench and the team plays short by hiding the wingers' places; a figure of the penalised player walks to
  the penalty bench and sits there (two a team at most, as no more than two penalties run).
- **The empty net**: only a goal or two behind, in the last minutes of regulation time (8% of the period, at least
  20 s), with the ball in the opponents' half; never short-handed. Back after a goal, at the period's end, or at a
  stoppage once level.
- **Passive play**: warned after 30 s with the ball in the team's own half or behind the opponents' goal (building
  in their half holds the count); then a shot within 8 s or a free-hit to the other team.
- **Club names**: colour or material and an animal (Copper Foxes, Glacier Wolves...), the same in every language, no
  towns, so no real club can be meant.
- **Game speed Steady (80%) by default**: 12 players at real floorball pace is hard to follow on a phone screen.
- **Penalty shot in play**: awarded when the fouled player is in the attacking half, within 12 m of goal, in front of
  it, with no defender but the offender between him and the goal (our reading of "a clear chance"); the clock stands.
- **Coach tips**: notes, not a separate tutorial: a first match is a real match, and each tip comes when its
  moment does, so nothing has to be read before playing.
- **Time-outs**: granted at the next stoppage with the referee's T; the 30 seconds are signalled, not waited out.
- **Overtime keeps the third period's ends** (2026 rule 203 text on ends was not retrieved).
- **armeabi-v7a**: the Play bundle keeps 32-bit too (older phones in Thailand, the Philippines and eastern Europe
  run 32-bit Android); the beta APK is 64-bit only to keep it small, as Kabaddi's and Takraw's.
- **German with ss, not ß; the sport called Unihockey in German, French and Italian prose**: most German, French
  and Italian speaking floorball players are Swiss.

## Shared assets

The owner (Josh) has made the orchestrator session (session_016XKAyHkTQRNMGEgZbjNK28) the lead for all six mobile
games. Assets that suit more than one game come from it: they are listed in `shared-assets/README.md` on the branch
`claude/shared-assets` (large files on a "shared-assets" GitHub release), each with its source, licence and the games
it suits, and a message says what each new one is and how to fetch it.

## Needs the owner

- Play Console account, the upload key as repository secrets (store/PLAY_STORE.md), a trademark search on the name.
- A native speaker's check of each translation (docs/LANGUAGES.md lists the doubtful strings).
- A read of the 2026 rules PDF against docs/RULES.md's "Still to check" list.
