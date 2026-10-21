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
