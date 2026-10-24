# chiShona (sn) translation notes

**Confidence: low to medium.** The general UI should be understandable, but there are no established Shona netball or game-UI conventions. **This file needs review by a native Shona speaker before release**, ideally a Zimbabwean netball player, coach or Kwayedza-style sports writer (Zimbabwe's Gems are a strong netball side).

## Netball terms chosen
- Netball: **netibhora**, the loanword in Shona spelling (as *bhora* for ball). It is used only in MENU_EYEBROW. Zimbabwean media also write plain "netball". Check which one readers expect.
- Shona has no grammatical gender (*iye*, *-ake*), so the "she/her" rule needs no special forms.
- Court **nhandare**; ball **bhora**; goal **chibodzwa / zvibodzwa** (the football-commentary word); to score **kunwisa**; shoot **kupfura**; shooter **mupfuri**; post **danda**; ring **mhete**; umpire **mutongi**; whistle **pito**; defender **mudziviriri**; opponent **mupikisi**; to mark **kurinda**.
- Areas: **chikamu chepakati / chekurwisa / chekudzivirira**, **denderedzwa regora**, **denderedzwa repakati**. **Zvikamu** also means "quarters". Context makes the meaning clear, but check it.
- Pass **pasa** (loanword); centre pass **pasa yepakati**; free pass **pasa yemahara**; penalty pass **pasa yepenariti**; throw-in **kukanda mukati**; offside **ofusaidhi**; footwork **tsoka**; obstruction **kuvharira**; contact **kubatana**; held ball **kunonoka nebhora**; advantage **mukana**.
- Buttons: Pasa, Mudenga (lob, "up in the air"), Pfura (shoot), Bvuta (intercept, "snatch"), Dzivirira (defend, 9 letters), Chinja (switch). The CTRL_* texts refer to them in capitals.
- Kept in English: POS_NAME_*, Double Zone, toss-up, BOX_* stat abbreviations, standings letters P/W/D/L/Pts, "Q{n}", "ET{n}". Bib is **bhibhi**.
- Informal singular address (*Tamba*, *yako*), as in most Shona apps.

## Check first
- MENU_EYEBROW: "netibhora" vs "netball".
- ON/OFF "Hongu"/"Kwete" (yes/no). The alternative is "Yakabatidzwa"/"Yakadzimwa", which is too long for a chip.
- BTN_LOB "Mudenga", BTN_INTERCEPT "Bvuta", BTN_DEFEND "Dzivirira".
- DIFF_LEGEND "Mhare", DIFF_PRO "Nyanzvi", CUP_WON "Makunda mukombe!", SIMULATE "Ona mhedzisiro".
- CALL_BREAKING "Kukurumidza", CALL_REPLAYED_BALL "Kudzokorora bhora", CALL_GAIN "Bhora ratorwa!", CALL_CONTACT "Kubatana" (could also read as "unity", so check it).
- RESULT_WINS "{team} yakunda": the agreement assumes *timu*.
- INJURY_NOTE "Mutambi we{team}": the concord is attached directly to the team name.
- Country names: Ingirandi and Sikotirandi are localised. Wales, Northern Ireland, South Africa and New Zealand are kept in English as commonly written; confirm.
- POS_ROLE_WA, CTRL_PASS_TEXT and TIMEOUTS_NOTE run about 1.3x the English length. Check that they fit on screen.

## Added in 0.2
- Coach **murairidzi**; tips **mazano emurairidzi**; umpiring (setting) **kutonga**; "fewer whistles" **mapito mashoma**.
- Escalate **yakwidziridzwa** (CALL_ESCALATE "Yakwidziridzwa: pasa yepenariti"); pass advanced **pasa yaendeswa mberi**; ordered off **abudiswa** (matches *kumubudisa* in RULES_SANCTIONS_TEXT).
- Club season **Mwaka weKirabhu**; table **rondedzero**; round **rawundi** (loanword, plural *marawundi*); grand final **fainari huru**; premiers **Makunda ligi!** (patterned on CUP_WON); champions in LEAGUE_CHAMPIONS **shasha**.
- "Dashed ring" is **mhete yemitsetse**; "mark her" is **umurinde**.

## Check first (0.2)
- LEAGUE_TABLE "Rondedzero": Zimbabwean sport media usually say "log" (log standings); that may be the better choice.
- ROUND_N_OF "Rawundi {n} pa{of}": the concord on the number.
- LEAGUE_WON "Makunda ligi!" and LEAGUE_CHAMPIONS "{team}: shasha".
- CALL_ESCALATE "Yakwidziridzwa" (about 1.35x English) and CALL_ADVANCE.
- COACH_PASS / COACH_DEFEND length in the coach box.
