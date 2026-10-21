# Chichewa (ny) translation notes

**Confidence: low to medium.** Chichewa is a lower-resource language. Malawi is a strong netball country, but in-game UI conventions are not standardised. A native-speaker review (ideally a Malawian netball player or sports journalist) is needed before release.

## Netball terms chosen
- Netball: **mpira wamanja** ("hand ball"), the term used in Malawian Chichewa media for netball (menu eyebrow). Check it isn't confused with handball; "netiboli" is the alternative.
- Goal **chigoli / zigoli**, to score **kugoletsa**; goal post **ndodo**; goal circle **chozungulira cha chigoli**; thirds **gawo lakuukira / lapakati / lodzitchinjiriza**.
- Player **wosewera**, team **timu**, umpire **woyimbira** (referee), defender **wotchinga**.
- Pass **pasi**; free pass **pasi yaulere**; penalty pass **pasi ya chilango**.
- Polite plural address (-anu, Sewerani) throughout, as in most Chichewa apps.
- Kept in English: position names (POS_NAME_*), centre pass, offside, footwork, held ball, throw-in, toss-up, bib, Double Zone, box-score abbreviations and standings letters P/W/D/L.
- Buttons: Pereka, Kweza (lob), Ponya (shoot), Landa (intercept), Teteza, Sintha.
- Short tags: "K{n}" (kota), "NW{n}" (nthawi yowonjezera).

## Check first
- MENU_EYEBROW "Mpira wamanja" vs "netiboli".
- BTN_SHOOT "Ponya" (also used for "throw" in rule texts), BTN_LOB "Kweza", BTN_INTERCEPT "Landa".
- ON/OFF "Yayatsa"/"Yazimitsa"; DIFF_* (Woyamba, Kalabu, Akatswiri, Nyenyezi). CUP_WON also uses "Akatswiri!".
- STAGE_DONE "Mmene matimu athera", CALL_GAIN "Mpira wasintha!", CALL_BREAKING, CALL_REPLAYED_BALL.
- SIZE_LARGE/SIZE_XL "Lalikulu" agreement with "batani".
- EXTRA_TIME_SHORT "NW{n}" (invented abbreviation).
- Country names: South Africa, England, Northern Ireland kept in English as is common in Malawian usage; confirm.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.
