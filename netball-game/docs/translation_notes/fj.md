# Fijian (fj) translation notes

**Confidence: low to medium.** Written in standard (Bauan) Fijian. Everyday UI words are fairly safe; netball jargon, abbreviations and several coined terms are best guesses. **This file needs review by a native Fijian speaker, ideally someone involved in netball, before release.** Fijian pronouns are not gendered, so the she/her rule needs no special handling.

## Netball terms chosen
- Netball: **netiboli** (loan as used in Fijian-language media, e.g. reports on the Fiji Pearls). Only appears in `MENU_EYEBROW`.
- Positions (POS_NAME_*): kept in **English**, as players in Fiji use them. Abbreviations unchanged.
- Team: **timi**; player: **dauqito**; match: **veiqati**; game/play: **qito**; umpire: **dauveilewai**; whistle: **uvi**; ball: **polo**; court/venue: **rara**; opponent: **dauveiqati**.
- Goal: **goli**; to score: **vakarawa goli**; shoot/shot: **viri**; shooter: **dauviri**; ring: **mama**; post: **duru**.
- Third: **ikatolu** (e loma = centre, ni ravu = attacking, ni taqomaki = defending); circle: **wavoki** (wavoki ni goli).
- Centre pass: **pasi ni lomadonu**; free pass: **pasi galala**; penalty pass: **pasi ni itotogi**; throw-in: **viri i loma**.
- Offside: **sivi iyalayala** ("over the boundary"); obstruction: **tarovi**; contact: **veitarai**; advantage: **yaga**; held ball: **taura balavu**; footwork: **lakolako ni yava** / call **cala ni yava**; landing foot: **yava ni tu**; bib: **isulu ni itutu**.
- Quarter: **kota**; extra time: **gauna e vakuri**; half-time: **veimama ni gauna**; time-out / pause: **cegu**.
- Buttons: Pasi, Laveta (lob, "lift"), Viri, Kovea (intercept, "snatch"), Taqomaka, Veisau. CTRL_* texts refer to them in capitals.
- Cup: **Kapa** (loan; "Kapa ni Veimatanitu" = Nations Cup). Medals: Koula / Siliva / Varasa.

## Check first
- `MENU_CUP` "Kapa ni Veimatanitu" — is there a more usual word for a trophy/cup competition?
- `wavoki` for the circles and `ikatolu ni ravu` for the attacking third — coined; check they are clear.
- `CALL_BREAKING` "Lako taumada", `CALL_REPLAYED_BALL` "Taura tale", `CALL_GAIN` "Veisau na polo!", `CALL_INTERCEPT` "Sa kovei!" — may have established forms, or players may use English.
- `ON`/`OFF` **Waqa / Boko** (light/extinguish).
- `QUARTER_SHORT` **K{n}**, `EXTRA_TIME_SHORT` **GV{n}** (gauna e vakuri) — revert to ET{n} if clearer.
- `BOX_*`: G/V (goli/vakatovotovo), Soli, Vuke, Rawa, Kove, Taro, Lesu, Toto, Yali; CPR kept. `COL_P/W/D/L` = Q/R/T/D (qito, rawa/qaqa, tautauvata, druka), `COL_PTS` Maka.
- `DIFF_*` chips: Vou / Kalabu / Cecere / Vuravura.
- `VERSION_N` "Tabana {v}", `DEV_ON/OFF`, `CTRL_KEYS_TEXT` ("kii vakatakilakila" for arrow keys) — technical wording is uncertain.
- Country names: Ositerelia, Niusiladi, Igiladi, Aferika ki Ceva, Sikotiladi, Airelani ki Vualiku, Viti, Singapoa, Malesia; others left as international spellings.
- Fijian runs long: `BIB_TEAM_NOTE`, `GFX_NOTE`, `RULES_COURT_TEXT`, `TIMEOUTS_NOTE` are about 1.3x English; check layout.
