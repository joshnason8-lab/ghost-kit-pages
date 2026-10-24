# Progress

Pok Ta Pok Rivals is the seventh game in the family. Branch `claude/pok-ta-pok-game`; release tag
`pok-ta-pok-rivals-beta`; folders `pok-ta-pok-game/` (the Godot project, self-contained, with its own
`.github/workflows/android.yml` for a standalone repo) and `pok-ta-pok-rivals/` (the pages). The root workflows are
`.github/workflows/pok-ta-pok-android.yml` and `pok-ta-pok-play-bundle.yml`, path-filtered to these folders.

**If you are resuming:** read this file and `git log` first.

## Done

- **Research** (October 2026): rules, court, ball, officials and clothing from Aguilar-Moreno, CONADE, the
  Secretaría de Cultura inventory, the UNAM thesis, NPR, Penn Museum and the Met (docs/RULES.md). Markets and languages
  from StatCounter, INEGI, DataReportal, Pew and Mexican tourism figures (docs/LANGUAGES.md). Name check: nothing
  called "Pok Ta Pok Rivals" was found. The closest is "POK" on Steam (2027) and "Ulama" on Play, so the title is
  kept.
- **The rules module** (`game/rules.gd`):
  - The ulama count: one side holds it; a raya to the holder adds one; a raya to the other side takes one off.
  - Urria on 3 and 7, or 3, 5 and 7, or off. Eight wins.
  - Who wins a raya: the ball dies in a half, goes past an end, goes out at a side, or touches a player anywhere but
    the hip.
  - The serve: male abajo or male arriba.
  - The classic court's points and the ring.
  - The time limit.

  Every rule is tested in `tests/test_runner.gd`.
- **The match**:
  - A heavy ball (3.6 kg, bounces 0.42 on earth and 0.58 on stone, rolling resistance) with the classic court's talud,
    walls, end courts and rings.
  - Players with one writer of position, acceleration limits and strides matched to speed.
  - Hip strikes and dives timed to the ball.
  - Team AI that reads the ball's path, turns side-on and sends deep lobs or low skidding drives.
  - Two judges (veedores) at the analco who signal each raya.
  - A raya tally board.
  - Pause, auto graphics, haptics only for your own side.
- **Bodies**: code-built and lit (not cel-shaded), on 17 bones, wearing the documented ulama gear (gamuza, chimali,
  faja). The classic court's yoke and knee pad are reconstructed. Judges wear everyday clothes.
- **The crowd**: one draw call, rendered at load time from the same 3D bodies (front and back), everyone facing the
  court. This is tested at every venue and graphics level.
- **Four venues**:
  - A Sinaloa village court at dusk.
  - A festival court by day, with stands, awnings and papel picado.
  - A Yucatán stone court in the forest, with a pyramid on the skyline.
  - The stone court by torchlight.

  They use the shared skies and surfaces, Poly Haven limestone (CC0) and shared tree cards; the agave is built in
  code.
- **Screens**:
  - The home screen is a carved stela whose glyph blocks are the menu, read in paired columns.
  - Match setup: the court, two towns with their players by position, a court diagram, side size, urria, time,
    level.
  - The town tournament: eight towns, knock-out.
  - The result screen with a box score.
  - Settings, How to Play (four tabs, including the story), the licences, and Move buttons.
- **Six languages** (es, en, pt, fr, de, it): fit_audit is clean on every screen at four screen shapes.
- **CI**: the root and standalone workflows, both green on the PR. The beta APK (64- and 32-bit) is on the
  `pok-ta-pok-rivals-beta` release, and the Play bundle workflow passes (unsigned).
- **Store**: `store/PLAY_STORE.md`, listings in 11 Play locales (`store/listing/`), the 512 icon and the feature
  graphic rendered from the stone ring, and six 1920x1080 screenshots (`store/graphics/`).
- **Performance** (perf_probe, after the body reduction): village Low 59 draws / 53k triangles, stone Low 60 / 64k,
  both well inside the Low budget (100 draws, 90k triangles). High: village 75 / 138k, stone 74 / 131k. The crowd is
  one draw call at every level.
- **Pages**: `pok-ta-pok-rivals/` (index, privacy, support).

## Next

1. **The pok-ta-pok / pelota maya revival** as a third rule set on the festival court. The tournament rules are
   documented: one strike per side, end line +4 or +5, foul points, a ring that wins outright, halves of 13 minutes.
2. Yucatec Maya touches: the judges' count on the stone court (*jun, ka', óox…*). It is listed for a native speaker
   in docs/CULTURE.md.
3. Menu music from the region, properly credited.
4. Meshy models (docs/MESHY_BRIEF.md) when the owner allows credits.
5. A Classic-period court variant with floor markers and no rings.

## Decisions and why

- **Ulama de cadera is the main mode.** It is the living game with the most documentation (Aguilar-Moreno played
  and filmed it). The stone court is labelled "Classic court (reconstructed)" everywhere it is offered.
- **60 × 4 m taste:** Aguilar-Moreno's figure, in the middle of the 50–69 m range the sources give.
- **The count:** a raya against the holder takes one off (Wikipedia's reading), not NPR's one-line "the lead passes
  over". Urria defaults to 3 and 7, where Aguilar-Moreno (2–3, 6–7) and CONADE (3, 5, 7) overlap.
- **Serve kind:** rolled from level, thrown once a side holds the count. The side that won the last raya serves.
  Both are reconstructed, because the sources say the serve changes with the score but not how.
- **4 or 5 a side in ulama:** the documented numbers. 2–4 on the stone court is the game's own choice.
- **Time limit:** a 2022 national meet used 30 minutes. The game offers 6, 10, 15 or none; at time, the holder wins,
  and if level the next raya wins.
- **Each side stays in its own half.** It is implied by the sources (the analco divides the sides) though not stated.
- **Code-built realistic bodies, no Meshy.** Ulama players are mostly skin and leather, which suits a smooth lit
  body. The other games' owner models are hurling and floorball players in kit, so they are not reused.
- **Crowd from the bodies:** the painted cut-outs looked cartoonish, so the sheet is rendered from the 3D bodies at
  loading. Headless, a painted sheet stands in.
- **No real place copied.** The stone court is generic and modelled on the smaller ringed courts. No site or tourist
  park is named.
- **Languages:** Spanish first. English, Brazilian Portuguese, French, German and Italian cover the diaspora,
  Brazil's market and the visitors to the Maya sites. Yucatec Maya appears as touches only, because Play has no
  listing locale for it and the translation needs a native speaker.
- **armeabi-v7a kept** (a 32-bit APK beside the 64-bit one, and both in the bundle): older and Android Go phones in
  Mexico and Central America still run 32-bit Android, as Hurling found for the Galaxy A0x.
- **Assist on by default:** your player is moved to meet the ball and the timing is yours. Timing a hip strike is the
  skill, and steering a player along a 60 m court with one thumb as well was too much on a phone.
- **Android SDK in this container:** dl.google.com is blocked here, so local exports use stub SDK tools; CI uses the
  runner's real SDK.

## Needs the owner

- **Play Console:** the upload-key secrets (`ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEY_ALIAS`,
  `ANDROID_UPLOAD_KEY_PASSWORD`) for a signed bundle, and the store listing upload.
- **Meshy credits:** docs/MESHY_BRIEF.md.
- **A knowledgeable reviewer:** docs/CULTURE.md.
