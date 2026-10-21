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
