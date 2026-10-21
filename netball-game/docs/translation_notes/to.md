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
