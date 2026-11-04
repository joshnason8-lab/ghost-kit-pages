# isiXhosa (xh) translation notes

**Confidence: low.** isiXhosa has limited published sports and software terminology, and I am less sure of idiom here than for Afrikaans or isiZulu. **A native-speaker review is needed before release**, ideally by someone who plays or coaches netball in the Eastern or Western Cape. Treat this file as a first draft.

## Netball terms chosen
- Netball: **ibhola yomnyazi** — the isiXhosa name I understand is in use ("umnyazi" = basket). Please confirm; many players just say "i-netball".
- Positions (POS_NAME_*): **kept in English**, as Xhosa-speaking players use the English names. Abbreviations kept.
- Centre pass, throw-in, offside, toss-up, bib: English loanwords with Xhosa prefixes (**i-centre pass, i-throw-in, i-offside, i-bib**).
- Goal: **inqaku** (it also means "point"; see the notes on COL_PTS/CUP_ABOUT). Shooting: **ukufaka** ("to put in"). Free pass: **ipasi yasimahla**; penalty pass: **ipasi yesohlwayo**; obstruction: **ukuthintela**; contact: **ukuchukumisana**; intercept: **ukuxhwila** ("snatch"); advantage: **inzuzo**.
- Court areas: **isahlulo esiphakathi / sokuhlasela / sokukhusela** for the thirds, **isangqa senqaku** for the goal circle. Pool: **iqoqo**, chosen so it is not confused with **iqela** (team).
- isiXhosa has no gendered pronouns, so the she/her rule has no visible effect.
- Buttons: Gqithisa, Phezulu, Faka, Xhwila, Khusela, Tshintsha (all ≤ 9 letters).
- `DOUBLE_ZONE` / `DZ_LIVE` kept in English as a feature name.

## Check first
- The netball word (`MENU_EYEBROW`) and the use of **inqaku** for goal.
- `BTN_SHOOT` "Faka" (alternative "Dubula"), `BTN_LOB` "Phezulu", `BTN_INTERCEPT` "Xhwila".
- All `CALL_*`, in particular `CALL_BREAKING` "Uqale kwangoko", `CALL_HELD_BALL` "Ubambe ixesha elide", `CALL_REPLAYED_BALL`, `CALL_GAIN`.
- `DIFF_*` chips; `DIFF_LEGEND` "Inqanaba lehlabathi" is long for a chip.
- `QUARTER_SHORT` "K{n}" and `EXTRA_TIME_SHORT` "XE{n}" (ixesha elongezelelweyo) — invented abbreviations.
- `BOX_*` and `COL_P/W/D/L` **kept in English**. `COL_PTS` "Amanq" and `COL_PCT` "Inqaku %" are guesses; because amanqaku means both goals and points, check `CUP_ABOUT` for clarity.
- UI vocabulary: `MENU_SETTINGS` "Iisetingi", `SIMULATE` "Linganisa", `DEV_ON/OFF`, `LEFT_HANDED` "Ixhoma", `PLAY_AS` "Ulawula", `KEEP_ONSIDE`.
- Country names, especially iNgilani, iSkotlani, uMntla weIreland, iOstreliya.
- Grammar and noun-class agreement throughout (ibhola is treated as class 9: "ibhola engena", "iphume").
- Length: about a dozen descriptions run 1.3–1.4x the English character count (agglutination). Check that they fit their text boxes.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **umqeqeshi**; tips **iingcebiso** ("Iingcebiso zomqeqeshi"); umpiring **ukugweba**; whistles **iimpempe**; penalties in the umpiring notes rendered as **iimpazamo** (faults).
- Escalate **inyuswe** ("Inyuswe: ipasi yesohlwayo"); advance **isiwe phambili** ("Ipasi isiwe phambili"); ordered off **ukhutshwe ebaleni** (matches RULES_SANCTIONS_TEXT).
- Club season **Isizini Yeeklabhu**; table **itheyibhile**; round **umjikelo**; grand final **owamagqibela omkhulu**; premiers **Iintshatsheli!** (same as CUP_WON, kept short for the large title); titles **iitayitile**.
- Tap **cofa** (as in TEAM_CHANGES_NOTE); post **ipali**; banner **ibhena**; mark a player **linda**. 0,9 m with decimal comma. LEAGUE_ABOUT reuses the CUP_ABOUT wording, so the amanqaku (goals/points) ambiguity carries over.
- Check first: `CALL_ESCALATE` "Inyuswe", `UMPIRING` "Ukugweba", `UMP_REAL` "Njengokwenyani", `LEAGUE_TABLE` "Itheyibhile", `ROUND_N` "Umjikelo", `REC_TITLES` "Iitayitile", `COACH_DEFEND` "umlinde", and noun-class agreement in the COACH_* tips.

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **i-AI**. Watch **Bukela**; home/away **Ekhaya / Abatyeleli** (visitors); speed **Isantya**. Check first: `MENU_WATCH` "Bukela i-AI".

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Isizini**; single **Kanye**; home and away
  **Ekhaya nakude**; major semi-final **I-semi-final enkulu**; minor semi-final
  **I-semi-final encinci**; preliminary final **Owamagqibela wokwandulela**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **Ukutshintsha abadlali**; swap **batshintshiselane izikhundla**; pair **isibini**; play restarts **umdlalo uqala kwakhona**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
