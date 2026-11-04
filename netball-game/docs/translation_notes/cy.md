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

## Added in 0.2
- Coach **hyfforddwr**; tips **cynghorion** ("Cynghorion yr hyfforddwr"); umpiring **dyfarnu**, levels Llai o chwibanu / Safonol / Cyfradd go iawn.
- Escalate **wedi'i chodi** ("Wedi'i chodi: pàs gosb", feminine after pàs); advance **ymlaen** ("Pàs ymlaen"); ordered off **wedi'i hanfon o'r cwrt** (as in RULES_SANCTIONS_TEXT).
- Club season **Tymor Clwb**; table **tabl**; round **rownd** (rowndiau terfynol = finals, as for the cup); grand final **y brif ffeinal**; premiers **Pencampwyr!** (same word as CUP_WON).
- Stick **ffon**, tap **tapiwch** (as in QUIT_SURE), dashed ring **cylch toredig**. 0.9 m with a decimal point.
- Check first: `CALL_ESCALATE` and `CALL_ADVANCE` (no settled Welsh umpire wording), `LEAGUE_WON` (could be "Pencampwyr y gynghrair!" if it fits the title), `STAGE_GRAND_FINAL`, mutations in `COACH_DEFEND` ("a'i marcio hi") and in strings where {pass}/{lob}/{defend} follow a verb, and `COACH_TIPS_NOTE` (cynghorion vs awgrymiadau).

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI** (DA, deallusrwydd artiffisial, is the formal form; AI is what people say). Watch **Gwylio**; home/away **Cartref / Oddi cartref**, as Welsh sports results; speed **Cyflymder**.

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Tymor**; single **Sengl**; home and away
  **Gartref ac oddi cartref**; major semi-final **Y brif rownd gynderfynol**; minor semi-final
  **Yr is-rownd gynderfynol**; preliminary final **Y rownd derfynol ragbrofol**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **Eilyddion** (the substitutes); swap **cyfnewid safleoedd**; pair **pâr**; play restarts **y chwarae'n ailddechrau**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
