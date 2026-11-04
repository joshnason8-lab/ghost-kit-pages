# Setswana (tn) translation notes

**Confidence: low.** Setswana is a lower-resource language and netball terminology in Setswana is not well documented in writing. A native-speaker review (ideally a netball player or coach in Botswana or North West, South Africa) is needed before release.

## Netball terms chosen
- Netball: **netbolo** (loanword; menu eyebrow only).
- Goal: **kolo / dikolo**; goal post **pala**; goal circle **sediko sa kolo**; thirds **karolo ya tlhaselo / ya bogare / ya tshireletso**.
- Player **motshameki**, match **motshameko**, team **setlhopha**, umpire **motsereganyi** (referee).
- Pass **pase**; free pass **pase ya mahala**; penalty pass **pase ya kotlhao**.
- Kept in English: position names (POS_NAME_*), centre pass, offside, footwork, held ball, throw-in, toss-up, bib, Double Zone, box-score abbreviations and standings letters P/W/D/L.
- Obstruction **kganelo (obstruction)**; contact **go thulana (contact)**.
- Buttons: Fetisa, Tsholetsa (lob), Thuntsha, Thopa (intercept), Sireletsa, Fetola.
- Short tags: "K{n}" (kotara), "NO{n}" (nako e okeditsweng).

## Check first
- BTN_SHOOT "Thuntsha" (vs "Thunya"), BTN_LOB "Tsholetsa", BTN_INTERCEPT "Thopa".
- ON/OFF "Bulegile"/"Tswetswe"; DIFF_* (Mosimolodi, Tlelabo, Setswerere, Naledi).
- CUP_WON "Bafenyi!" (champions), CALL_GAIN "Bolo e fetogile!", CALL_BREAKING, CALL_REPLAYED_BALL.
- KNOCKOUT/STAGE_FINALS "Difinale" vs STAGE_FINAL "Final".
- GFX_AUTO "Ditshwantsho ka boitiriso", GFX_NOTE (long), FPS_NOTE_SAVER.
- EXTRA_TIME_SHORT "NO{n}" (invented abbreviation).
- Country names: Aforika Borwa, Engelane, Jamaika, Ireland Bokone; Scotland and Wales kept in English.
- Setswana and Sesotho strings were written in parallel; check that no Sesotho forms leaked in.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **mokatisi**; tips **dikgakololo** ("Dikgakololo tsa mokatisi"); umpiring **botsereganyi**; whistle **phala / diphala**; penalties in the umpiring notes rendered as **diphoso** (faults).
- Escalate **e godisitswe** ("E godisitswe: pase ya kotlhao"); advance **e isitswe pele** ("Pase e isitswe pele"); ordered off **o ntshitswe lebaleng**.
- Club season **Paka ya Ditlelabo** (paka = period/season); table **tafole**; round **potologo / dipotologo**; grand final **final e kgolo**; finals stay **difinale**; premiers **Bafenyi!** (same as CUP_WON); titles **ditlotla**. Elite match: **motshameko wa baitseanape**.
- Tap **tobetsa**; stick kept as **joystick**; mark a player **disa**. 0.9 m with a decimal point, as elsewhere in this file.
- Check first: `MENU_LEAGUE` / `STAGE_SEASON` "Paka" (alternative "Sešene"), `ROUND_N` "Potologo", `UMP_FEWER` "Diphala di le dinnye", `CALL_ESCALATE` "E godisitswe", `COACH_DEFEND` "o mo disa", `COACH_TIPS_NOTE` (long), and again that no Sesotho forms leaked in.

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI**. Watch **Lebelela**; home/away **Ba gae / Baeng** (guests); speed **Lebelo**. Check first: `MENU_WATCH_DESC` "Nna o lebelele".

## Added for the home-and-away season (to translate)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`, `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: in English until translated (tools/build_i18n.py lists them as missing). A Club Season of seven rounds
  (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two: the **major
  semi-final** (1st v 2nd), the **minor semi-final** (3rd v 4th), the **preliminary final** (the major semi's loser v
  the minor semi's winner), then the grand final (`STAGE_GRAND_FINAL`, already translated). Keep "{n}" in
  `SEASON_SINGLE` and `SEASON_HOME_AWAY` (the number of rounds). `MENU_LEAGUE_DESC_2` and `LEAGUE_ABOUT_2` replace
  `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT`, which described a single round robin and the old finals (their translations
  are in git history, a start for the new ones). Use this language's word for finals (`KNOCKOUT`) and grand final.
