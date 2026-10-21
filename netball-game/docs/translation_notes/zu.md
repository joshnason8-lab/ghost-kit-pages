# isiZulu (zu) translation notes

**Confidence: medium-low.** isiZulu is well resourced in general, but there is little published netball terminology, so many sport terms are my best judgement. **A native-speaker review is needed before release**, ideally by someone who plays or coaches netball in KwaZulu-Natal or Gauteng.

## Netball terms chosen
- Netball: **ibhola lomnqakiswano** — the isiZulu name I understand is used in Zulu-language media. Please confirm; some players simply say "i-netball".
- Positions (POS_NAME_*): **kept in English** (Goal Shooter etc.), as Zulu-speaking players use the English names. Abbreviations kept.
- Centre pass, throw-in, offside, toss-up, bib: kept as English loanwords with Zulu prefixes (**i-centre pass, i-throw-in, i-offside, i-bib**), which is how they are said on court.
- Free pass: **iphasi yamahhala**; penalty pass: **iphasi yesijeziso**; obstruction: **ukuvimba**; contact: **ukuthintana**; advantage: **inzuzo**; intercept: **ukuhlwitha** ("snatch").
- Court areas: **ingxenye emaphakathi / yokuhlasela / yokuvikela** for the thirds, **isiyingi segoli** for the goal circle.
- isiZulu has no gendered pronouns, so the she/her rule has no visible effect.
- Buttons: Dlulisa, Phezulu (lob = "high"), Shaya, Hlwitha, Vikela, Shintsha (all ≤ 8 letters).
- `DOUBLE_ZONE` / `DZ_LIVE` kept in English as a feature name.

## Check first
- `MENU_EYEBROW` and the netball word itself.
- `BTN_LOB` "Phezulu", `BTN_SHOOT` "Shaya", `BTN_INTERCEPT` "Hlwitha" — natural on a button?
- All `CALL_*`, especially `CALL_BREAKING` "Uqale kusenesikhathi", `CALL_HELD_BALL` "Ubambe isikhathi eside", `CALL_REPLAYED_BALL` "Ukuphinda ibhola", `CALL_GAIN` "Ibhola lishintshe izandla!" — these are translations, not established calls; they may be too long for the banner.
- `DIFF_*` chips ("Usaqala, Iklabhu, Ingcweti, Izinga lomhlaba"); "Izinga lomhlaba" is longer than English.
- `QUARTER_SHORT` "K{n}" and `EXTRA_TIME_SHORT` "IE{n}" (isikhathi esengeziwe) — invented abbreviations.
- `BOX_*` and `COL_P/W/D/L` **kept in English** (isiZulu has no established stats abbreviations; South African Zulu sports tables usually use P W D L). `COL_PTS` "Amaph" is a guess.
- `SIMULATE` "Lingisa", `PLAY_AS` "Ulawula" (= "You control"), `KEEP_ONSIDE`.
- Country names (`TEAM_*`), especially iSkotilandi, iNyakatho ye-Ireland, iNgilandi.
- Length: as an agglutinative language, about a dozen descriptions run 1.3–1.45x the English character count (e.g. POS_ROLE_GA, FPS_NOTE_SAVER, RULES_COURT_TEXT, CTRL_PASS_TEXT). Check that they fit their text boxes.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **umqeqeshi**; tips **izeluleko** ("Izeluleko zomqeqeshi"); umpiring **ukwahlulela**; whistles **izimpempe**; penalties in the umpiring notes rendered as **amaphutha** (fouls).
- Escalate **kukhushulwe** ("Kukhushulwe: iphasi yesijeziso"); advance **isiwe phambili** ("Iphasi isiwe phambili"); ordered off **ukhishwe enkundleni** (matches RULES_SANCTIONS_TEXT).
- Club season **Isizini Yamaklabhu**; table **ithebula**; round **umzuliswano**; grand final **owamanqamu omkhulu**; premiers **Ompetha!** (same word as CUP_WON, kept short for the large title); titles **izicoco**.
- Tap **thepha** (as in TEAM_CHANGES_NOTE); post **ipali**; banner **isibhengezo**; mark a player **qapha**. 0,9 m with decimal comma.
- Check first: `CALL_ESCALATE` and `CALL_ADVANCE` (banner length), `UMPIRING` "Ukwahlulela", `UMP_REAL` "Njengangempela", `LEAGUE_TABLE` "Ithebula", `ROUND_N` "Umzuliswano {n}" (long for a chip), `COACH_FOOTWORK` "{lob} intantisa ibhola", `REC_TITLES` "Izicoco".
