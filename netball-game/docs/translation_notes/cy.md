# Welsh / Cymraeg (cy) translation notes

**Confidence: medium.** General UI and rules text follow standard Welsh software conventions (Gosodiadau, Hafan, Ailosod). Welsh netball vocabulary is not well standardised, and many Welsh-speaking players use English terms on court; mutations in some phrases should also be checked. A native-speaker review, ideally by someone who plays or coaches pêl-rwyd (e.g. via Urdd or Welsh-medium schools), is recommended.

## Netball terms chosen
- Netball: **pêl-rwyd**.
- Positions (POS_NAME_*): **Saethwr Gôl, Ymosodwr Gôl, Ymosodwr Asgell, Canol, Amddiffynnwr Asgell, Amddiffynnwr Gôl, Ceidwad Gôl**. Abbreviations GS/GA/WA/C/WD/GD/GK kept in English.
- Pass: **pàs** (feminine: y bàs, pàs rydd, pàs gosb, pàs ganol); centre pass **pàs ganol**; free pass **pàs rydd**; penalty pass **pàs gosb**; throw-in **tafliad i mewn**; held ball **dal y bêl**; footwork **gwaith traed**; offside **camsefyll**; obstruction **rhwystro**; contact **cyffwrdd**; advantage **mantais**; umpire **dyfarnwr**.
- Court thirds: **traean canol / ymosod / amddiffyn**; goal circle **cylch gôl**; post **postyn**; ring **cylchyn**.
- Buttons: Pasio, Lob, Saethu, Cipio, Amddiffyn, Newid (all <= 9 letters).
- Pronouns: hi/ei (aspirate mutation: ei dwylo, ei throed) used for players.

## Check first
- `POS_NAME_*` — "Saethwr" vs "Saethwraig" (feminine), and whether Welsh players say these at all versus the English names.
- `KEEP_ONSIDE` "Cadw fi'n onside" — kept the English "onside" since "camsefyll" has no natural positive; alternative "Osgoi camsefyll".
- `CALL_BREAKING` "Torri'n gynnar", `CALL_REPLAYED_BALL` "Ailchwarae'r bêl", `CALL_INTIMIDATION` "Bygwth", `CALL_GAIN` "Wedi'i dwyn!".
- `BTN_LOB` "Lob" (loan); `BTN_INTERCEPT` "Cipio" vs CALL "Rhyng-gipio".
- `ON`/`OFF` "Ymlaen" / "I ffwrdd" — check toggle width.
- `QUARTER_SHORT` "Ch{n}" and `EXTRA_TIME_SHORT` "AY{n}" (amser ychwanegol) — invented abbreviations.
- `BOX_*`: G/C (goliau/cynigion), Bwydo, Cynor, DPG (derbyn pàs ganol), Ennill, Cip, Gwyro, Adlam, Cosb, Coll — confirm or revert to English.
- `COL_P/W/D/L` → Ch/E/Cy/Co (Chwarae/Ennill/Cyfartal/Colli), `COL_PTS` "Pt".
- `INTERVAL_NOTE` and `RESULT_WINS` — check mutations once {next} and {team} are filled in.
- `RULES_CENTRE_TEXT`, `RULES_SANCTIONS_TEXT`, `CUP_ABOUT` — longest strings, check flow and length.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.
