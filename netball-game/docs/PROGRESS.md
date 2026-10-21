# Progress

The working log for Centre Pass Netball: what is done, what is next, and the decisions made along the way with the
reasons. Anyone picking the work up (after a usage limit, a restart, a context summary) starts here, then reads
`git log`.

## State

- Branch `claude/netball-game`, folder `netball-game/` (self-contained Godot 4.7.2 project), pages folder
  `centre-pass-netball/`, workflows `.github/workflows/netball-android.yml` and `netball-play-bundle.yml`.
- Version 0.2.0-beta. Draft PR #4 (https://github.com/joshnason8-lab/ghost-kit-pages/pull/4); beta release
  https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/centre-pass-netball-beta.

## Done

- Research: the Rules of Netball (World Netball, 2024 edition, current in October 2026) and the leagues' variants;
  the markets and their languages. Notes behind docs/RULES.md and docs/LANGUAGES.md.
- Project scaffold from Takraw Smash's infrastructure (UI helpers, drag scrolling, fit audit, input test, perf probe,
  loading screen, licences, sound synthesis, the auto-graphics and frame-rate logic, the dev overlay from Kabaddi).
- The rules module `game/rules.gd` (pure functions) and `game/court.gd` (the court's geometry).
- The match: 14 code-built players (women's bodies, dresses, bibs with letters from one atlas), two umpires who move
  along their side lines and signal, the ball, three venues, the broadcast camera, the HUD with a netball
  scoreboard, touch controls with movable buttons, the AI for both teams, the umpires' calls, box score.
- Screens: home (court-shaped menu, bib rail), quick setup (team sheet), settings, how to play (four tabs, the
  positions with area maps), result with box score, Nations Cup, records, licences.
- Tests: test_runner with a check for each rule, the rules in play, the cup, controls and motion.
- League options: the Double Zone, time-outs (90 s, two a half, after a goal) and rolling changes.
- CI: the Android build (tests, fit audit, input test, APK, beta release) and the Play bundle (unsigned; target API
  36, min 24, only VIBRATE, isGame, 16 KB pages: all checked) pass.
- Store: PLAY_STORE.md, English listings (6 regional), icon, feature graphic, 7 screenshots; pages; README; BETA.md;
  MESHY_BRIEF.md; synthesized menu music.
- All 19 languages in, 301 strings each, fit audit clean at four screen shapes; store listings in af, zu, sw,
  ms-MY, zh-CN, si-LK, ta-IN besides the six English ones. (The usage limit stopped work at about 07:45 UTC; it
  resumed at 09:48.)
- Umpires warn and suspend (R6); injury stoppages hold time (R10).
- Round two (0.2.0-beta): the Web build played by touch in Chromium at three phone shapes (docs/PLAYTEST.md) and
  its findings fixed with tests (pause button, Back/Esc, language list, pass target, key hints, interval screen,
  name tags, home art); the coach's tips for a first match; the umpires advance, escalate and order off; the
  Umpiring setting (AI penalty rate); the Club Season (eight invented clubs); the rules re-checked (rule numbers,
  on-the-line offside, simultaneous infringement, ET interval) with what is still blocked recorded in RULES.md;
  339 strings in all 19 languages, fit audit clean.

## Next

1. Native speakers' review of every translation (docs/translation_notes/), the lower-resource languages first; the
   0.2 strings are listed under "Added in 0.2" in each.
2. The non-English store listings: add the Club Season and the coach (the English ones have them).
3. A home-and-away Club Season (14 rounds) as an option, and a finals series with a second chance for the top two.
4. The after-goal tactical change (2024) on request; the without-ball obstruction signal drawn.
5. A phone test on a Mali-G52-class phone; trim crowd/render scale if Low drops under 30 fps.
6. Meshy models (docs/MESHY_BRIEF.md) if the owner chooses; the upload key and the closed test (store/PLAY_STORE.md).
7. Open the rules PDF when the network allows and settle the items in RULES.md "Still unconfirmed".

## Decisions

- **Name: Centre Pass Netball** (slug `centre-pass-netball`, package `com.centrepassnetball.game`). The centre pass
  starts every passage of netball and is the sport's own term; searches of Google Play and the web (October 2026)
  found no game of that name (only scoring apps that mention centre passes).
- **Rules edition: World Netball Rules of Netball 2024**, in force since 1 January 2024; no 2025 or 2026 edition (a
  minor review is under way for 2027). So: no toss-up (simultaneous infringements go to the team last in
  possession), cautions replaced by warnings and suspensions, a goal counts if released before the whistle.
- **Toss-up not implemented**: it no longer exists in the 2024 rules.
- **Intervals 4, 12, 4 minutes; extra time 2 × 7 minutes with a minute between, then on to a two-goal lead**: the
  2024 rules (the "3/5 minutes" often quoted is old). The game shows the interval's real length and lets you skip.
- **Quarters default to 5 minutes** for a phone session, with 8, 10 and the real 15 on offer. The clock runs on
  through goals and restarts, as in the real game.
- **Infringement rate**: real elite teams concede 50-58 penalties a match. The AI concedes about a third of that
  rate so the game is not all whistles; the rate is in game/ai.gd `_slips`.
- **Women's netball only**: men's and mixed netball use the same rules (only line-up limits differ in mixed), but the
  owner's brief and the market are women's netball; mixed can come later.
- **League variants under invented names**: the Double Zone (a two-point zone 3.0-4.9 m from the post in the last
  five minutes of each quarter, as Australia's and England's top leagues play it).
- **Languages**: English plus 18: Afrikaans, isiZulu, isiXhosa, Sesotho, Setswana (South Africa, the biggest player
  base), Chichewa (Malawi), Luganda (Uganda), chiShona (Zimbabwe), Kiswahili (Kenya, Tanzania, Uganda), Malay and
  Chinese (Malaysia, Singapore), Sinhala and Tamil (Sri Lanka), Welsh, Te Reo Māori, Tongan, Samoan, Fijian. Most
  netball phones are set to English, so the globe button matters; Android 13+ also lets players pick the app's
  language. See docs/LANGUAGES.md, and docs/translation_notes/ for what native speakers should check.
- **Northern Ireland's flag**: no official flag exists, so the game draws a neutral green field (game uses flags
  only where they are official).
- **armeabi-v7a**: the Play bundle includes 32-bit ARM as well as 64-bit, for the older phones common in Malawi,
  Uganda, Zambia and Zimbabwe; the sideload beta APK is 64-bit only, as Kabaddi's and Takraw's are.
- **Workflow use**: round one's 18 translations were run as one multi-agent workflow, a choice made on my own for
  speed overnight. The owner has not opted in to workflows, so round two used three translator subagents instead.
- **Club names** (round two): invented city + nickname, checked by web search against the top leagues of the four
  countries; "Sunbirds" clashed with a South African league team and became the Strelitzias; Kestrels and Kāhu,
  each close to a team in the same country, became Brolgas and Kārearea.
- **Coach**: tips rather than a scripted tutorial match, so a first-timer plays a real match from the first tap; each
  tip shows once, when its moment comes, and the tips stop after the first full match.
- **Before every push** (the owner's request, round two): run locally what CI runs (check_scripts, test_runner,
  the full fit audit, the input test, the perf probe and a Web export), so a push fails CI only for what cannot be
  caught here (the Android export and signing). The Android build runs on `push` only (no `pull_request` run of the
  same commit), so one failure sends one email.

