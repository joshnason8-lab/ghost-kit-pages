# Afrikaans (af) translation notes

**Confidence: high** for general UI and rules text; **medium** for a handful of netball jargon and box-score abbreviations. A quick pass by an Afrikaans speaker who plays or coaches netball is still recommended.

## Netball terms chosen
- Netball: **netbal** (standard Afrikaans).
- Positions (POS_NAME_*): **Doelskut, Doelaanval, Vleuelaanval, Senter, Vleuelverdediging, Doelverdediging, Doelwagter** — the names used in Afrikaans-medium schools. Abbreviations GS/GA/WA/C/WD/GD/GK kept in English.
- Centre pass: **senterpas**; free pass: **vrypas**; penalty pass: **strafpas**; throw-in: **ingooi**; held ball: **gehoue bal**; footwork: **voetwerk**; offside: **buitespel**; obstruction: **obstruksie**; contact: **kontak**; advantage: **voordeel**.
- Court areas: **middelderde / aanvalsderde / verdedigingsderde**, **doelsirkel**, **sentersirkel**. Bib: **borslap**.
- Buttons: Aangee, Lob, Skiet, Onderskep, Verdedig, Wissel (all ≤ 9 letters).
- Decimal comma used in measurements (30,5 m), as is standard in South Africa.

## Check first
- `CALL_BREAKING` "Te vroeg weg" — not sure there is an established Afrikaans umpire call; some players may just say "breaking".
- `KEEP_ONSIDE` "Keer buitespel" (= "prevent offside") — rephrased because "binnespel" is not idiomatic.
- `BTN_LOB` "Lob" — kept as the loanword; alternative "Hoë bal".
- `BOX_*` abbreviations invented for Afrikaans: D/P (doele/pogings), Voer, Hulp, SPO (senterpas-ontvangs), Wins, Ond, Afb, Terug, Straf, BV (balverlies). Confirm these read naturally on a stats screen, or revert to English stats abbreviations.
- `COL_P/W/D/L` → S/W/G/V (Speel, Wen, Gelykop, Verloor), `COL_PTS` "Pte".
- `QUARTER_SHORT` "K{n}" (kwart), `EXTRA_TIME_SHORT` "ET{n}" (ekstra tyd).
- `POS_NAME_C` "Senter" vs "Middel" — "Senter" is what I believe players use.
- `RULES_ADVANTAGE_TEXT`, `RULES_FOOTWORK_TEXT` — longer rule sentences, check flow.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **afrigter**; tips **wenke** ("Afrigter se wenke"); umpiring **Skeidsregters** (setting label); fewer whistles **Minder fluitjies**; penalties in the umpiring notes rendered as **oortredings** (infringements).
- Escalate **opgeskaal** ("Opgeskaal: strafpas"); advance **vorentoe geskuif** ("Pas vorentoe geskuif"); ordered off **van die baan gestuur** (matches RULES_SANCTIONS_TEXT).
- Club season **Klubseisoen**; table **Puntelys**; round **rondte** (Rondte {n}); grand final **groot eindstryd**; premiers **Ligakampioene!** (kept distinct from CUP_WON "Kampioene!"); finals stay **eindrondes**.
- Mark (a player) **merk**; dashed ring **stippelring**; lime ring **lemmetjiegroen ring** as in CTRL_MOVE_TEXT. 0,9 m with decimal comma.
- Check first: `UMP_REAL` "Ware tempo" (literally "true pace"; "Werklike koers" is the alternative), `CALL_ESCALATE` "Opgeskaal", `UMPIRING` "Skeidsregters", `COACH_DEFEND` "merk haar", `COACH_FOOTWORK` "{lob} lig die bal oor", `LEAGUE_WON` "Ligakampioene!" as a large title.

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI is **KI** (kunsmatige intelligensie), as Afrikaans media write it: "Kyk na KI", "KI-spanne". Home/away sides **Tuis / Besoekers**; Watch **Kyk**; speed **Spoed**. Check first: `MENU_WATCH` "Kyk na KI" as a menu title.

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Seisoen**; single **Enkel**; home and away
  **Tuis en weg**; major semi-final **Hoof-halfeindstryd**; minor semi-final
  **Klein halfeindstryd**; preliminary final **Voorlopige eindstryd**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **Vervangings**; swap **ruil** ("van posisie ... ruil"); pair **paar**; play restarts **die spel hervat**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
