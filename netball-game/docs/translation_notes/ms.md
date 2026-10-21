# Bahasa Melayu, Malaysia (ms) translation notes

**Confidence: medium.** General UI and rules text should read naturally; netball position names and some umpire calls in Malay vary between schools/MSSM material and what club players actually say (many use the English terms). A review by a Malaysian netball player or coach is recommended before release.

## Netball terms chosen
- Netball: **bola jaring** (standard Malaysian term).
- Positions (POS_NAME_*): **Penjaring Gol, Penyerang Gol, Penyerang Sayap, Pemain Tengah, Pertahanan Sayap, Pertahanan Gol, Penjaga Gol** — the descriptive Malay names used in school material. Abbreviations GS/GA/WA/C/WD/GD/GK kept in English.
- Court: **gelanggang**; thirds: **pertiga tengah / serangan / pertahanan**; goal circle: **bulatan gol**; centre circle: **bulatan tengah**; post: **tiang**; ring: **gelung**.
- Centre pass **hantaran tengah**; free pass **hantaran bebas**; penalty pass **hantaran penalti**; throw-in **balingan masuk**; held ball **bola dipegang**; footwork **langkah kaki**; offside **ofsaid** (common loanword); obstruction **halangan**; contact **sentuhan**; advantage **kelebihan**; umpire **pengadil**.
- Buttons: Hantar, Lambung, Jaring, Pintas, Halang, Tukar (all <= 7 letters).
- Player pronoun: Malay "dia" is gender-neutral, so no gender marking needed.

## Check first
- `POS_NAME_*` — confirm these are the names Malaysian players/teachers use; "Penjaring" vs "Penembak" for GS, "Pemain Tengah" vs "Tengah" for C.
- `CALL_BREAKING` "Mula awal", `CALL_REPLAYED_BALL` "Main semula bola", `CALL_INTIMIDATION` "Ugutan" — no confirmed official Malay umpire call; players may say the English.
- `CALL_GAIN` "Rampas bola!", `BTN_DEFEND` "Halang" (also the root of "halangan" = obstruction; may want "Bertahan" if it fits the button).
- `KEEP_ONSIDE` "Elak ofsaid" (= avoid offside), rephrased.
- `QUARTER_SHORT` "S{n}" (suku) and `EXTRA_TIME_SHORT` "MT{n}" (masa tambahan) — invented abbreviations.
- `BOX_*`: G/C (gol/cubaan), Suapan, Bantu, CPR kept, Rampas, Pint, Pesong, Lant, Pen, Hilang — confirm or revert to English stats abbreviations.
- `COL_P/W/D/L` → P/M/S/K (Perlawanan/Menang/Seri/Kalah), as in Malaysian league tables; `COL_PTS` "Mata".
- `VS` "lwn" (lawan) — standard in Malaysian press.
- `RULES_FOOTWORK_TEXT`, `RULES_PENALTIES_TEXT` — long rule sentences; check flow and length.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.
