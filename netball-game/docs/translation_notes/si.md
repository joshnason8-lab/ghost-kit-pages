# Sinhala (si) translation notes

**Confidence: medium.** The general UI and rules text should read well. The netball jargon follows Sri Lankan usage, where many terms are spoken as English loans. A pass by a Sinhala-speaking netball player or umpire is still recommended.

## Netball terms chosen
- Netball: **දැල්පන්දු** (as specified).
- Feminine forms throughout where Sinhala marks gender: **ක්‍රීඩිකාව** (player), **ආරක්ෂිකාව** (defender), **විසි කරන්නිය / අල්ලන්නිය** (thrower/catcher), **ඇය / ඇගේ** (she/her), and the umpire is also referred to as **ඇය**.
- Positions (POS_NAME_*) are kept in English, as Sri Lankan players and media use them. "Area/zone" is **කලාප**, "position" is **ස්ථාන**, and "venue" is **තරග භූමිය** so it does not clash with position.
- Court **පිටිය**; thirds **මැද / ප්‍රහාරක / ආරක්ෂක කොටස**; goal circle **ගෝල් කවය**; centre circle **මැද කවය**; ring **වළල්ල**; post **කණුව**; umpire **විනිසුරු**.
- Goal **ගෝල්**; shoot **විදීම**; centre pass **සෙන්ටර් පාස්** (transliterated, as players say it); free pass **නිදහස් පාස්**; penalty pass **පෙනල්ටි පාස්**; offside **ඕෆ්සයිඩ්**; footwork **පාද චලනය**; obstruction **බාධා කිරීම**; contact **ස්පර්ශය**; held ball **පන්දුව රඳවීම**; throw-in **ඇතුළට විසි කිරීම**; advantage **වාසිය**; Double Zone **ද්විත්ව කලාපය**; time-out **කාල විරාම**.
- Buttons: යවන්න (Pass), උඩින් (Lob), විදින්න (Shoot), අල්ලන්න (Intercept), රකින්න (Defend), මාරු (Switch). The CTRL_* texts quote them as “…”.
- Standings P/W/D/L → **ක්‍රී / ජ / ස / ප** (ක්‍රීඩා, ජය, සම, පරාජය), as in Sinhala cricket tables; Pts → **ලකුණු**.
- Kept in English: BOX_* stat abbreviations, "Q{n}", "ET{n}", toss-up.
- ON/OFF chips: **සක්‍රිය / අක්‍රිය**.

## Check first
- BTN_LOB "උඩින්", BTN_INTERCEPT "අල්ලන්න" (could read simply as "catch"), BTN_DEFEND "රකින්න".
- CALL_BREAKING "කලින් පැනීම", CALL_REPLAYED_BALL "යළි ගත් පන්දුව", CALL_GAIN "පන්දුව දිනුවා!".
- Whether "සෙන්ටර් පාස්" or a Sinhala term ("මැද පාස්") is preferred, and the same question for "නිදහස් පාස්" vs "ෆ්‍රී පාස්".
- DIFF_NORMAL "සමාජ" (club): this may read oddly on its own. "ක්ලබ්" is the alternative.
- SIMULATE "අනුකරණය", CAM_TV "විකාශන", CTRL_MOVE_TEXT "ලා කොළ වළල්ල" (lime ring).
- Whether the box-score abbreviations and Q{n}/ET{n} should be localised.

## Added in 0.2
- Coach **පුහුණුකරු** (gender-neutral form); tips **පුහුණුකරුගේ ඉඟි**; umpiring (setting) **විනිශ්චය**; "fewer whistles" **අඩු විසිල්**; standard **සම්මත**; real rate **සැබෑ අනුපාතය**.
- Escalate **ඉහළ නැංවිණි** (CALL_ESCALATE "ඉහළ නැංවිණි: පෙනල්ටි පාස්"); pass advanced **පාස් එක ඉදිරියට**; ordered off **පිටියෙන් ඉවත් කෙරිණි** (as in RULES_SANCTIONS_TEXT).
- Club season **සමාජ වාරය**; table **ලකුණු වගුව**; round **වටය**; grand final **මහා අවසන් තරගය**; premiers **ශූරයෝ!** (same as CUP_WON).
- Feminine forms kept: ක්‍රීඩිකාව, ඇය, team-mate **සගිය**. Button names in the COACH_* tips are quoted “…” as in the CTRL_* texts.

## Check first (0.2)
- MENU_LEAGUE "සමාජ වාරය": the same doubt as DIFF_NORMAL "සමාජ"; "ක්ලබ් සීසන්" or "සමාජ තරගාවලිය" are alternatives.
- CALL_ESCALATE "ඉහළ නැංවිණි" and CALL_ADVANCE "පාස් එක ඉදිරියට".
- ROUND_N_OF "වටය {n} / {of}" (a slash rather than a sentence).
- COACH_INTERCEPT "සගිය" (feminine team-mate) and COACH_DEFEND "ඇයව රකින්න" for "mark her".
