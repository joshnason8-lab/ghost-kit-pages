# Te Reo Māori (mi) translation notes

**Confidence: low–medium. Needs review by a native speaker before release.** The grammar and everyday UI words should be sound. However, te reo has no single settled set of netball terms, and several terms and abbreviations here are my own coinages. A fluent speaker who plays netball (or a kura kaupapa coach) should review the file.

## Choices
- Netball: **poitarawhiti**, the word in Te Aka and used in Māori-medium schools. **netipōro** is a common alternative. Only MENU_EYEBROW names the sport, so it is a one-word change.
- Te reo pronouns (ia) carry no gender, so nothing needed adjusting for she/her.
- Position names (POS_NAME_*) are kept in English (Goal Shooter etc.), as NZ players use them even in te reo settings. Abbreviations stay in English.
- Terms: goal **piro**, team **kapa**, player **kaitākaro**, match **tukinga**, umpire **kaiwawao**, court **papa**, ball **pōro**, quarter **hauwhā**, half-time **haurua**, extra time **wā tāpiri**, third **hautoru** (waenga / whakaeke / ārai), goal circle **porowhita piro**, ring **mowhiti**, bib **kahu (tūranga)**.
- Calls: centre pass **tuku waenga**, free pass **tuku noa**, penalty pass **tuku whiu**, throw-in **panga mai**, offside **wāhi hē**, obstruction **whakararu**, contact **pā tinana**, footwork **mahi waewae**, held ball **pōro pupuri**, advantage **painga**, intimidation **whakawehi**.
- Knockout: semi-final **whiringa whāiti**, final **whiringa toa**.
- Buttons: Tuku (pass), Teitei (lob, "high"), Pupuhi (shoot), Haukoti (intercept), Ārai (defend), Huri (switch). All are 7 letters or fewer. The CTRL_*_TEXT strings use these labels in capitals.
- Countries use the established transliterations (Ahitereiria, Ingarangi, Hemeika, Whītī, Hāmoa…). New Zealand is **Aotearoa**.

## Check first
- `BTN_LOB` "Teitei" and `BTN_SHOOT` "Pupuhi": confirm these are what a player would expect.
- `CALL_BREAKING` "Wawe rawa", `CALL_REPLAYED_BALL` "Pōro hopu anō", `KEEP_ONSIDE` "Kia tika te wāhi": these are coined.
- `QUARTER_SHORT` "H{n}" (hauwhā) and `EXTRA_TIME_SHORT` "WT{n}" (wā tāpiri).
- `COL_P/W/D/L` → Tk/To/Ō/Hi (tākaro, toa, ōrite, hinga), `COL_PTS` "Kaute", and the `BOX_*` abbreviations (P/W, Whāng, Āwh, TWH, Riro, Hauk, Pare, Hoki, Whiu, Ngaro). These are the most likely to need changing.
- Country names that are less settled: Timuwawe (Zimbabwe), Papatohe (Barbados), Poriwana (Botswana), Tirinitā me Topako, Hiri Rānaka.
- `ON`/`OFF` "Kā"/"Weto", `SIMULATE` "Whakatairite", `PAUSED` "Kua tatari".
