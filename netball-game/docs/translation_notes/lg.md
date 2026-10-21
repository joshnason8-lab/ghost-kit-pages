# Luganda (lg) translation notes

**Confidence: low.** Luganda is a lower-resource language and there are no settled conventions for netball terms or game UI in it. **This file needs review by a native Luganda speaker before release**, ideally someone who follows Ugandan netball (She Cranes, the national league) or writes sport for Luganda media such as Bukedde.

## Netball terms chosen
- Netball: **netiboolo**, a loanword spelled the Luganda way (like *ggoolo* for goal). It is used only in MENU_EYEBROW. Ugandan press often just writes "netball". Check which one readers expect.
- Luganda has no grammatical gender (*ye*, *-e* cover both she and he), so the "she/her" rule needs no special forms.
- Court **ekisaawe**; ball/match **omupiira**; goal **ggoolo**; to score **okuteeba**; shooter **omuteebi**; goal post **ekikondo**; ring **empeta**; umpire **omulamuzi**; whistle **efirimbi**; defender **omuzibizi**; opponent **omuvuganya**.
- Areas: **ekitundu ekya wakati / eky'okulumba / eky'okwekuuma** (centre / attacking / defending third), **enkulungo ya ggoolo** (goal circle), **enkulungo ya wakati** (centre circle). Note that **ebitundu** also translates "quarters" (QUARTERS, RULES_TIME). Context makes the meaning clear, but check it.
- Pass **pasi** (loanword); centre pass **pasi ya wakati**; free pass **pasi ya bwereere**; penalty pass **pasi ya peneti**; throw-in **okusuula munda**; offside **ofusaayidi**; footwork **ebigere**; obstruction **okuziyiza**; contact **okukwatako**; held ball **okulwisa omupiira**; advantage **enkizo**.
- Buttons: Pasi, Waggulu (lob, "over the top"), Teeba (shoot), Nyakula (intercept, "snatch"), Kuuma (defend, "guard"), Kyusa (switch). The CTRL_* texts refer to them in capitals.
- Kept in English: POS_NAME_* (Ugandan players use the English names), Double Zone, toss-up, bib, BOX_* stat abbreviations, standings letters P/W/D/L/Pts, QUARTER_SHORT "Q{n}", EXTRA_TIME_SHORT "ET{n}".
- Informal singular address (*ggwe*, *Zannya*), as in most Luganda apps.

## Check first
- MENU_EYEBROW: "netiboolo" vs "netball".
- BTN_LOB "Waggulu", BTN_INTERCEPT "Nyakula", BTN_DEFEND "Kuuma": are these natural as button labels?
- ON/OFF "Kiriko"/"Kiggyeko". The alternative is "Yee"/"Nedda".
- CALL_BREAKING "Okusooka", CALL_REPLAYED_BALL "Okuddamu omupiira", CALL_HELD_BALL "Okulwisa omupiira", CALL_GAIN "Omupiira gukyuse!".
- DIFF_* (Omuyiga, Kiraabu, Abakugu, Ku ntikko), SIMULATE "Laga ebivaamu", MENU_RECORDS "Ebyafaayo".
- GFX_AUTO "Ebifaananyi otomatiki", FRAME_RATE "Sipiidi y'ebifaananyi".
- TIMEOUTS_NOTE "buli kitundu ekinene" (for "a half"): this may be unclear.
- Country names: Awusitureeliya, Bungereza, Sikotilandi, Welisi, Ayalandi ey'Obukiikakkono, Malayiziya, Singapoo, Samowa, Namibiya. "South Afrika" and "New Zealand" are kept close to English.
- Several rules texts (RULES_COURT_TEXT, CTRL_DEFEND_TEXT, CUP_ABOUT) come out about 1.3x the English length, which is normal for Luganda. Check that they fit on screen.

## Added in 0.2
- Coach **omutendesi**; tips **amagezi g'omutendesi**; umpiring (setting) **obulamuzi**; "fewer whistles" **efirimbi ntono**.
- Escalate **kyongezeddwa** (CALL_ESCALATE "Kyongezeddwa: pasi ya peneti"); pass advanced **pasi etwaliddwa mu maaso**; ordered off **agobeddwa** (matches *okumugoba* in RULES_SANCTIONS_TEXT).
- Club season **Sizoni ya Kiraabu**; table **olukalala** (as in the world-ranking list); round **omutendera** (ROUND_N "Omutendera {n}"); grand final **fayinolo ennene**; premiers **Bakyampiyoni!** (same word as CUP_WON); the season stage **Sizoni**.
- "Dashed ring" is **empeta ey'obutonnyeze**; "mark her" is **omukuume**.

## Check first (0.2)
- ROUND_N / MENU_LEAGUE_DESC "omutendera": Ugandan sport writing may prefer another word (or "raundi") for a league round.
- LEAGUE_TABLE "Olukalala" vs a loan such as "ttaabulo".
- CALL_ESCALATE "Kyongezeddwa" and CALL_ADVANCE "Pasi etwaliddwa mu maaso": the umpiring sense may not be clear.
- UMP_REAL "Nga ddala" and UMP_STANDARD "Ekya bulijjo" as option chips.
- COACH_PASS and COACH_DEFEND are the longest tips (about 1.1x English); check they fit the coach box.
