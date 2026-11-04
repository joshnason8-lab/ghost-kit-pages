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

## Added in 0.2
- Coach **mphunzitsi**; tips **malangizo** ("Malangizo a mphunzitsi"); umpiring **kuyimbira**; whistle **muluzu / miluzu** (as in RULES_GOAL_TEXT); penalties in the umpiring notes rendered as **zolakwa** (faults).
- Escalate **yasanduka** ("Yasanduka: pasi ya chilango", = "it became"); advance **yapita patsogolo** ("Pasi yapita patsogolo"); ordered off **watulutsidwa m'bwalo** (matches RULES_SANCTIONS_TEXT "kumutulutsa").
- Club season **Nyengo ya Makalabu**; table **tebulo**; round **rawundi / marawundi** (loanword, like fainolo, kalabu); grand final **fainolo yaikulu**; finals stay **mafainolo**; premiers **Akatswiri!** (same as CUP_WON); titles **zikho** (trophies). Elite match: **masewera apamwamba**.
- Tap **dinani**; stick kept as **joystick**; mark a player **kulondera**. Polite plural address kept. 0.9 m with a decimal point, as elsewhere in this file.
- Check first: `ROUND_N` "Rawundi" (alternatives: "Gawo", or keep "Round"), `CALL_ESCALATE` "Yasanduka", `UMP_STANDARD` "Wamba", `UMP_REAL` "Ngati zenizeni", `LEAGUE_TABLE` "Tebulo", `COACH_FOOTWORK` "imayandamitsa", `REC_TITLES` "Zikho".

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI**. Watch **Onerani**; home/away **Akunyumba / Alendo** (visitors); speed **Liwiro**; records **mbiri** as in MENU_RECORDS. Check first: `WATCH_HOME` "Akunyumba".

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Nyengo**; single **Kamodzi**; home and away
  **Kunyumba ndi kwina**; major semi-final **Semi-final yaikulu**; minor semi-final
  **Semi-final yaing'ono**; preliminary final **Fainolo yoyambirira**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **Kulowetsa osewera**; swap **asinthane maudindo**; pair **awiri**; play restarts **masewera akayambiranso**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
