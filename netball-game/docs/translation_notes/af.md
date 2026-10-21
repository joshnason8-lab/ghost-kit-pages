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
