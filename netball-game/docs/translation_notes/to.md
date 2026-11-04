# Tongan (to) translation notes

**Confidence: low. Needs review by a native speaker before release.** The Tongan is understandable, but I have far less material to draw on than for the other languages. Netball vocabulary, loanword spellings and some phrasing should all be checked by a fluent Tongan speaker, ideally someone who follows netball. Treat this file as a first draft.

## Choices
- Netball: **netipolo**, the loanword used in Tongan-language media and by Netball Tonga. Only MENU_EYEBROW names the sport.
- Tongan pronouns (ia) carry no gender, so nothing needed adjusting for she/her.
- The fakauʻa is U+02BB (ʻ) throughout, never an apostrophe. The toloi (macron) is used on ā ē ī ō ū where I am confident of it.
- Position names (POS_NAME_*) are kept in English. Abbreviations stay in English.
- Terms: team **timi**, player **tokotaha vaʻinga**, match/game **vaʻinga**, ball **pulu**, goal **kōlo**, score a goal **maʻu kōlo**, court **malaʻe**, umpire **fakamaau**, quarter **kuata**, half-time **haafe taimi**, extra time **taimi fakalahi**, third **konga** (lotomālie / ʻohofi / taukapo), circle **siakale**, ring **lingi**, bib **pipi**.
- Calls: centre pass **paasi senitā**, free pass **paasi tauʻatāina**, penalty pass **paasi tautea**, throw-in **lī ki loto**, offside **ʻofisaiti**, obstruction **fakafeʻātungia**, contact **ala**, footwork **ngāue vaʻe**, held ball **pulu puke**, advantage **faingamālie**.
- Buttons: Paasi, Lopu, Fana (shoot), Puke (catch = intercept), Taukapo (defend), Fetongi (switch). All are 7 letters or fewer. The CTRL_*_TEXT strings use these labels in capitals.
- `ON`/`OFF` are "ʻIo"/"ʻIkai" (yes/no), because I know of no established Tongan toggle labels.

## Check first
- `GOAL`/`REC_GOALS` and others: **kōlo** for a netball goal. The spelling and long vowel need checking, and so does whether Tongan players use a different word.
- `BTN_INTERCEPT` "Puke" (also BOX_INT, CALL_INTERCEPT) and `BTN_LOB` "Lopu".
- `CALL_BREAKING` "Vave fau", `CALL_REPLAYED_BALL` "Toe puke pulu", `KEEP_ONSIDE` "Taʻofi ʻofisaiti", `SIMULATE` "Fakataipe": these are coined.
- `QUARTER_SHORT` "K{n}" (kuata), `EXTRA_TIME_SHORT` "TF{n}" (taimi fakalahi), `COL_P/W/D/L` → V/I/T/M (vaʻinga, ikuna, tatau, mole), and the `BOX_*` abbreviations (K/F, Fafa, Tokon, Maʻu, Puke, Teke, Foki, Taut, Mole; CPR kept).
- Country names: Simipapuei, Pāpeitosi, Potisiuana, Tilinitati mo Topako, ʻIukanitā, Sīlangikā. Most of these are guessed transliterations.
- Several rules texts (RULES_PENALTIES_TEXT, RULES_SANCTIONS_TEXT, RULES_TEAMS_TEXT) and INTERVAL_NOTE are about 1.3–1.4x the English length. Tongan runs longer. Check the layout.

## Added in 0.2
- Coach **faiako**; tips **fakahinohino**; umpiring **founga fakamaau**, levels Siʻi ange e ifi / Angamaheni / Tuʻunga moʻoni.
- Escalate **hiki hake** ("Hiki hake: paasi tautea"); advance **ki muʻa** ("Paasi ki muʻa"); ordered off **tuli ki tuʻa** (as in RULES_SANCTIONS_TEXT).
- Club season **Sīsini Kalapu** (loan); table **tēpile**; round **takai**; grand final **fainolo lahi**; premiers **Ikuna ʻo e liki!** (liki as in RULES_DZ; champions stays "ikuna lahi" as in CUP_WON).
- Tap **tā** (as in QUIT_SURE), stick **sitiki**, dashed ring **takai laine motumotu**, whistle **ifi**. 0.9 m with a decimal point.
- Check first: `ROUND_N`/`ROUND_N_OF` "Takai" (the same word is used for the ring in the CTRL/COACH texts; a different word for a round may be better), `MENU_LEAGUE` "Sīsini", `LEAGUE_WON`, `CALL_ESCALATE`/`CALL_ADVANCE`, `COACH_INTERCEPT` ("ʻi he ʻatā" for "in the air"), and `COACH_WHISTLE` ("tohi ʻi ʻolunga" for the banner).

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). AI kept as **AI**. Watch **Mamata**; home/away **ʻApi / ʻAʻahi** (visiting); speed **Vave**. Check first: `WATCH_AWAY` "ʻAʻahi" over a team.

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **Sīsini**; single **Tuʻo taha**; home and away
  **ʻApi mo ʻaʻahi**; major semi-final **Semi-fainolo lahi**; minor semi-final
  **Semi-fainolo siʻi**; preliminary final **Fainolo fakakamata**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **Kau fetongi**; swap **fetongiʻaki honau tuʻunga**; pair **ongo tuʻunga**; play restarts **toe kamata ʻa e vaʻinga**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
