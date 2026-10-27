# Samoan (sm) translation notes

**Confidence: low to medium.** General UI text is plain, standard Samoan; netball jargon, box-score abbreviations and several coined terms are my best guesses. **This file needs review by a native Samoan speaker, ideally someone who plays, coaches or commentates netball, before release.**

Orthography: ʻokina written as U+02BB (ʻ) and macrons used (fā, Mātū, faigatā, seāseā, mālūlū, paʻū, aū). Samoan pronouns are not gendered, so the she/her rule needs no special handling.

## Netball terms chosen
- Netball: **netipolo** (loan used in Samoan media and by Netball Samoa; "netiball" also seen). Only appears in `MENU_EYEBROW`.
- Positions (POS_NAME_*): kept in **English** (Goal Shooter, Goal Attack...), as Samoan players and commentators use the English names. Abbreviations GS/GA/WA/C/WD/GD/GK unchanged.
- Team: **ʻau**; player: **tagata taʻalo**; umpire: **laufali**; whistle: **faʻaili**; ball: **polo**; court/venue: **malae**.
- Goal / to score: **sikoa** (loan, widely used); shot / to shoot: **fana**; ring: **mama**; post: **pou**.
- Third: **vaetolu** (centre/attacking/defending: ogatotonu / osofaʻi / puipui); circle: **liʻo** (goal circle: liʻo sikoa).
- Centre pass: **pasi ogatotonu**; free pass: **pasi saʻoloto**; penalty pass: **pasi faʻasalaga**; throw-in: **togi i totonu**.
- Offside: **sopo tuaoi** ("crossing the boundary"); obstruction: **faʻalavelave**; contact: **paʻi**; advantage: **avanoa**; held ball: **taofi umi**; footwork call: **sesē vae**; landing foot: **vae tulaueleele**; bib: **ofu tulaga**.
- Quarter: **kuata**; extra time: **taimi faʻaopoopo**; half-time: **ʻafa taimi**; time-out: **taimi malolo**.
- Buttons: Pasi, Siʻi (lob, "lift"), Fana, Seu (intercept), Puipui, Sui. CTRL_* texts refer to them in capitals.
- Medals: Auro / Siliva / Apamemea. Cup: **Ipu**.

## Check first
- `BTN_SHOOT` / shot = **fana**: is this what netball commentary says, or is "togi" / "sikoa" more natural?
- `BTN_LOB` **Siʻi** and `BTN_INTERCEPT` **Seu** — confirm they read as game actions.
- `CALL_BREAKING` "Alu vave", `CALL_REPLAYED_BALL` "Toe puʻe", `CALL_HELD_BALL` "Taofi umi", `CALL_GAIN` "Faoa!" — coined; there may be established umpire calls (or players may just use the English).
- `KEEP_ONSIDE` "Taofi aʻu i totonu" ("keep me inside").
- `ON`/`OFF` **Ki / Tape** (as on a light switch).
- `QUARTER_SHORT` **K{n}**, `EXTRA_TIME_SHORT` **TF{n}** (taimi faʻaopoopo) — revert to ET{n} if that reads better.
- `BOX_*`: S/T (sikoa/taumafai), Avatu (feeds), Fesoa (assists), Maua (gains), Seu, Teʻe (deflections), Toe (rebounds), Sala (penalties), Faoa (turnovers); CPR kept. `COL_P/W/D/L` = T/M/Tu/F (taʻalo, manumalo, tutusa, faiaina), `COL_PTS` ʻAi.
- `DIFF_*` chips: Fou / Kalapu / Sili / Lalolagi.
- Country names (TEAM_*): Ausetalia, Niu Sila, Egelani, Iamaika, Aferika i Saute, Sikotilani, Uelese, Aialani i Mātū, Fiti, Sigapoa, Malaisia; others left as international spellings. Check against current Samoan usage.
- Long rule texts (`RULES_FOOTWORK_TEXT`, `RULES_PENALTIES_TEXT`, `RULES_SANCTIONS_TEXT`, `CTRL_PASS_TEXT`) — check grammar and flow.
- `CTRL_DEFEND_TEXT` is about 1.3x the English length; check it fits.

## Added in 0.2
- Coach **faiaʻoga**; tips **fautuaga**; umpiring **faiga laufali**, levels Itiiti faʻaili / Masani / Fua moni.
- Escalate **siʻitia** ("Siʻitia: pasi faʻasalaga"); advance **i luma** ("Pasi i luma"); ordered off **tuliese** (as in RULES_SANCTIONS_TEXT).
- Club season **Vaitau Kalapu**; table **laulau**; round **taamilosaga**; grand final **faʻaiʻuga sili**; premiers **Siamupini o le liki!** (liki as in RULES_DZ).
- Tap **paʻi** (as in QUIT_SURE), stick **joystick** (as in CTRL_PASS_TEXT), dashed ring **mama vaevaeina**, banner **faʻailoga i luga**. 0.9 m with a decimal point.
- Check first: `LEAGUE_ABOUT` ("feagai le tasi ma le isi i le tasi le taimi" for "play each other once"), `UMPIRING`, `UMP_REAL`, `CALL_ESCALATE`/`CALL_ADVANCE`, `LEAGUE_TABLE` "Laulau", and `ROUND_N_OF` (taamilosaga is long; check it fits the match header).
