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
