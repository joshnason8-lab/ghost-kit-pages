# Sesotho (st) translation notes

**Confidence: low.** Sesotho is a lower-resource language for machine-assisted localisation and netball vocabulary in Sesotho is thin in written sources. A native-speaker review (ideally someone who plays or coaches netball in South Africa or Lesotho) is needed before release.

## Orthography
South African orthography (wa, ya, tshwaya, jwang). Lesotho orthography differs (oa, ea, tšoaea, joang). If the main market is Lesotho, the whole file needs an orthography pass.

## Netball terms chosen
- Netball: **netbolo** (loanword; only used in the menu eyebrow).
- Goal: **kolo / dikolo** (loanword used in football commentary), not "sepheo".
- Goal post: **palo**; goal circle: **sedikadikwe sa kolo**; thirds: **karolo ya tlhaselo / e bohareng / ya tshireletso**.
- Pass: **pase**; free pass **pase ya mahala**; penalty pass **pase ya kotlo**.
- Umpire: **moahlodi** (referee/judge).
- Kept in English because players use them: position names (POS_NAME_*), centre pass, offside, footwork, held ball, throw-in, toss-up, bib, Double Zone, box-score abbreviations (Feeds, Ast, Gains, Int, Defl, Reb, Pen, TO, CPR) and standings letters P/W/D/L.
- Obstruction: **thibelo (obstruction)**; contact: **ho thulana (contact)**.
- Buttons: Fetisa, Phahamisa (lob), Thunya, Hapa (intercept), Sireletsa, Fetola.
- Short tags: QUARTER_SHORT "K{n}" (kotara), EXTRA_TIME_SHORT "NE{n}" (nako e ekeditsweng).

## Check first
- BTN_LOB "Phahamisa" and BTN_INTERCEPT "Hapa": are these what a player would say?
- ON/OFF "Bulehile"/"Timilwe" and DIFF_* (Moqadi, Tlelabo, Setsebi, Naledi).
- CALL_BREAKING, CALL_REPLAYED_BALL, CALL_GAIN "Bolo e fetohile!", CALL_INTIMIDATION.
- KEEP_ONSIDE "Nthibele offside", GFX_AUTO "Ditshwantsho ka bowona".
- EXTRA_TIME_SHORT "NE{n}" (invented abbreviation; "ET{n}" may be clearer).
- STAGE_FINAL "Final" vs KNOCKOUT/STAGE_FINALS "Makgaolakgang"; MEDAL_SILVER "Silefera".
- Country names: Engelane, Jamaika, Ireland Leboya; Scotland and Wales kept in English.
- Long rule texts (RULES_FOOTWORK_TEXT, RULES_CENTRE_TEXT, RULES_SANCTIONS_TEXT) for grammar and length.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **mokwetlisi**; tips **malebela** ("Malebela a mokwetlisi"); umpiring **boahlodi**; whistle **mololi / melodi**; penalties in the umpiring notes rendered as **diphoso** (faults).
- Escalate **e nyollotswe** ("E nyollotswe: pase ya kotlo"); advance **e isitswe pele** ("Pase e isitswe pele"); ordered off **o ntshitswe lebaleng**.
- Club season **Sehla sa Ditlelabo**; table **tafole**; round **potoloho / dipotoloho**; grand final **final e kgolo** (follows STAGE_FINAL "Final"); finals stay **makgaolakgang**; premiers **Ditshampione!** (same as CUP_WON); titles **ditlotla**.
- Tap **tobetsa**; stick kept as **joystick** (as in CTRL_* texts); mark a player **lebela**. 0.9 m with a decimal point, as elsewhere in this file.
- Check first: `ROUND_N` "Potoloho" (I am unsure of the usual word for a league round), `MENU_LEAGUE` "Sehla", `CALL_ESCALATE` "E nyollotswe", `UMP_FEWER` "Melodi e fokolang", `UMP_STANDARD` "Ka tlwaelo", `LEAGUE_TABLE` "Tafole", `COACH_FOOTWORK` "e phaphamatsa", `REC_TITLES`.
