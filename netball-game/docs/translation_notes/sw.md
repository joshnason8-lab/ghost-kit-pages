# Kiswahili (sw) translation notes

**Confidence: medium-high** for general UI and rules text; **medium** for netball jargon and box-score abbreviations. Reviewed briefly, not by a native speaker; a pass by a Swahili speaker who follows netball is recommended. Swahili pronouns are not gendered.

## Netball terms used
- Netball: **netiboli** (Kenyan usage). Tanzanian media often say **mpira wa pete**; pick one per target market.
- Positions (POS_NAME_*) kept in English; abbreviations unchanged.
- Centre pass: **pasi ya katikati**; free pass: **pasi huru**; penalty pass: **pasi ya penalti**; throw-in: **mpira wa kurusha**; offside: **kuotea**; obstruction: **uzuiaji**; contact: **kugusana**; advantage: **faida**; footwork: **kazi ya miguu** / call **kosa la miguu**.
- Thirds: **theluthi** (ya kati / ya mashambulizi / ya ulinzi); circle: **duara la goli**; umpire: **mwamuzi**; bib: **bibu**.
- Buttons: Pasi, Inua, Piga, Nasa, Linda, Badili — consistent with the capitalised words in CTRL_* texts.

## Changes made in this review
- `KEEP_ONSIDE_NOTE`, `RULES_OFFSIDE_TEXT`: added the missing verb "kuingia" ("allowed to enter"); the sentences were incomplete.
- Added the 12 keys that en.json gained (time-outs, rolling changes, injury, warning/suspension, `SANCTION_LINE`) so sw.json matches en.json key-for-key.

## Check first
- `TEAM_ENG` "Uingereza" usually means the UK/Britain; for England some write "Uingereza" anyway, others "England". Also check `TEAM_WAL` "Welisi", `TEAM_BAR` "Babados".
- `SIMULATE` "Matokeo ya haraka" (3 words) — check it fits as a button.
- `BOX_TO` "Pot" (potezo?) is unclear; `COL_P/W/D/L` Mc/Sh/Sr/Fu; `EXTRA_TIME_SHORT` "MN{n}".
- `CALL_BREAKING` "Kutoka mapema", `CALL_REPLAYED_BALL` "Kuudaka tena".
- New keys: "Muda wa kusimama" for time-out; `TIMEOUTS_NOTE` is about 1.35x English.

## Added in 0.2
- Coach **kocha**; tips **vidokezo vya kocha**; umpiring (setting) **uamuzi**; "fewer whistles" **filimbi chache**.
- Escalate **imepandishwa** (CALL_ESCALATE "Imepandishwa: pasi ya penalti"); pass advanced **pasi imesogezwa mbele**; ordered off **ametolewa nje** (as in RULES_SANCTIONS_TEXT).
- Club season **Msimu wa Klabu**; table **msimamo** (league standings, as in football); round **raundi**; grand final **fainali kuu**; premiers **Mabingwa!** (same as CUP_WON).
- "Mark her" is **umkabe**; "dashed ring" is **pete ya vistari**.

## Check first (0.2)
- UMPIRING "Uamuzi" (could read as "decision"); "Waamuzi" or "Upulizaji filimbi" are alternatives.
- CALL_ESCALATE "Imepandishwa" in the umpiring sense.
- LEAGUE_ABOUT uses "Uingereza" for England, as TEAM_ENG does (see the earlier note).
- REC_TITLES "Mataji ya Msimu wa Klabu".

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI** (common in Swahili tech writing; "akili bandia" is the long form). Watch **Tazama**; home/away **Nyumbani / Ugenini**, as Swahili football results say; speed **Kasi**.

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Msimu**; single **Mara moja**; home and away
  **Nyumbani na ugenini**; major semi-final **Nusu fainali kuu**; minor semi-final
  **Nusu fainali ndogo**; preliminary final **Fainali ya awali**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.
