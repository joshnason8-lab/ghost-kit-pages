# Te Reo Māori (mi) translation notes

**Confidence: low–medium. Needs review by a native speaker before release.** The grammar and everyday UI words should be sound. However, te reo has no single settled set of netball terms, and several terms and abbreviations here are my own coinages. A fluent speaker who plays netball (or a kura kaupapa coach) should review the file.

## Choices
- Netball: **poitarawhiti**, the word in Te Aka and used in Māori-medium schools. **netipōro** is a common alternative. Only MENU_EYEBROW names the sport, so it is a one-word change.
- Te reo pronouns (ia) carry no gender, so nothing needed adjusting for she/her.
- Position names (POS_NAME_*) are kept in English (Goal Shooter etc.), as NZ players use them even in te reo settings. Abbreviations stay in English.
- Terms: goal **piro**, team **kapa**, player **kaitākaro**, match **tukinga**, umpire **kaiwawao**, court **papa**, ball **pōro**, quarter **hauwhā**, half-time **haurua**, extra time **wā tāpiri**, third **hautoru** (waenga / whakaeke / ārai), goal circle **porowhita piro**, ring **mowhiti**, bib **kahu (tūranga)**.
- Calls: centre pass **tuku waenga**, free pass **tuku noa**, penalty pass **tuku whiu**, throw-in **panga mai**, offside **wāhi hē**, obstruction **whakararu**, contact **pā tinana**, footwork **mahi waewae**, held ball **pōro pupuri**, advantage **painga**, intimidation **whakawehi**.
- Knockout: semi-final **whiringa whāiti**, final **whiringa toa**.
- Buttons: Tuku (pass), Teitei (lob, "high"), Pupuhi (shoot), Haukoti (intercept), Ārai (defend), Huri (switch). All are 7 letters or fewer. The CTRL_*_TEXT strings use these labels in capitals.
- Countries use the established transliterations (Ahitereiria, Ingarangi, Hemeika, Whītī, Hāmoa…). New Zealand is **Aotearoa**.

## Check first
- `BTN_LOB` "Teitei" and `BTN_SHOOT` "Pupuhi": confirm these are what a player would expect.
- `CALL_BREAKING` "Wawe rawa", `CALL_REPLAYED_BALL` "Pōro hopu anō", `KEEP_ONSIDE` "Kia tika te wāhi": these are coined.
- `QUARTER_SHORT` "H{n}" (hauwhā) and `EXTRA_TIME_SHORT` "WT{n}" (wā tāpiri).
- `COL_P/W/D/L` → Tk/To/Ō/Hi (tākaro, toa, ōrite, hinga), `COL_PTS` "Kaute", and the `BOX_*` abbreviations (P/W, Whāng, Āwh, TWH, Riro, Hauk, Pare, Hoki, Whiu, Ngaro). These are the most likely to need changing.
- Country names that are less settled: Timuwawe (Zimbabwe), Papatohe (Barbados), Poriwana (Botswana), Tirinitā me Topako, Hiri Rānaka.
- `ON`/`OFF` "Kā"/"Weto", `SIMULATE` "Whakatairite", `PAUSED` "Kua tatari".

## Added in 0.2
- Coach **kaiako**; tips **tohutohu**; umpiring **te wawao** (from kaiwawao), levels Iti iho ngā whio / Paerewa / Auau tūturu.
- Escalate **kua piki** ("Kua piki: tuku whiu"); advance **whakamua** ("Tuku whakamua"); ordered off **kua panaia atu** (pana atu as in RULES_SANCTIONS_TEXT).
- Club season **Tau Karapu** (tau = season/year); table **tūtohi**; round **rauna**; grand final **whiringa toa nui**; premiers **Toa o te Rīki!** (rīki as in RULES_DZ).
- Tap **pāwhiria** (as in TEAM_CHANGES_NOTE), stick **rākau**, dashed ring **mowhiti motumotu**, banner **te pae i runga**. 0.9 m with a decimal point.
- Check first: `UMPIRING` "Te wawao", `UMP_REAL` "Auau tūturu", `CALL_ESCALATE`/`CALL_ADVANCE`, `MENU_LEAGUE` "Tau Karapu" (kaupeka is an alternative for season), `STAGE_GRAND_FINAL`, and `COACH_WHISTLE` (pae for the banner).

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI**. Watch **Mātakitaki**; home/away **Kāinga / Manuhiri**; speed **Tere**. Check first: `MENU_WATCH_DESC` "Noho mai, mātakitaki ai".

## Added for the home-and-away season (to translate)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`, `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: in English until translated (tools/build_i18n.py lists them as missing). A Club Season of seven rounds
  (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two: the **major
  semi-final** (1st v 2nd), the **minor semi-final** (3rd v 4th), the **preliminary final** (the major semi's loser v
  the minor semi's winner), then the grand final (`STAGE_GRAND_FINAL`, already translated). Keep "{n}" in
  `SEASON_SINGLE` and `SEASON_HOME_AWAY` (the number of rounds). `MENU_LEAGUE_DESC_2` and `LEAGUE_ABOUT_2` replace
  `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT`, which described a single round robin and the old finals (their translations
  are in git history, a start for the new ones). Use this language's word for finals (`KNOCKOUT`) and grand final.
