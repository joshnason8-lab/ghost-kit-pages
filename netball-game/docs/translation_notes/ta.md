# Tamil (ta) translation notes

**Confidence: medium.** General UI and rules text should read naturally; netball jargon and the stats abbreviations are less certain. Written with Sri Lankan readers in mind. A review by a Sri Lankan Tamil speaker who plays or coaches netball is recommended before release.

## Choices
- Netball: **வலைப்பந்து** (MENU_EYEBROW).
- Spelling follows Sri Lankan habits where they differ from Indian Tamil: அவுஸ்திரேலியா, தென்னாபிரிக்கா, கமரா, கிண்ணம் (cup), சம்பியன்கள், ஷொட், லொப், ஸ்கொட்லாந்து, ஜொய்ஸ்டிக். Sri Lanka is **இலங்கை**.
- Players are female: **வீராங்கனை** (female player), with feminine verb endings (-ாள்) and அவள் ("she"). "Player of the match" is **போட்டியின் நாயகி**.
- Position names are transliterated English in Tamil script (கோல் ஷூட்டர், கோல் அட்டாக், விங் அட்டாக், சென்டர், விங் டிஃபென்ஸ், கோல் டிஃபென்ஸ், கோல் கீப்பர்). I believe this is what school players say; GS/GA/WA/C/WD/GD/GK stay in English.
- Common calls stay as loanwords because players use them: **சென்டர் பாஸ்**, **ஃப்ரீ பாஸ்**, **பெனால்டி பாஸ்**, **ஆஃப்சைட்**. Others are in Tamil: obstruction **தடை**, contact **தொடுகை**, footwork **கால் அசைவு**, held ball **பந்து தாமதம்**, advantage **அனுகூலம்**, throw-in **உள்ளெறிதல்**, umpire **நடுவர்**, ring **வளையம்**.
- Court areas: மையப் பகுதி / தாக்குதல் பகுதி / தடுப்புப் பகுதி (centre/attacking/defending third), கோல் வட்டம், மைய வட்டம். Quarter: **காற்பகுதி**.
- Buttons are kept as short as possible for the circular buttons: பாஸ், லொப், ஷூட், பறி (snatch = intercept), தடு (block = defend), மாற்று (switch). The CTRL_*_TEXT strings refer to the buttons by these labels.
- Decimal point in measurements (30.5 மீ), as used in Sri Lanka.

## Check first
- `BTN_INTERCEPT` "பறி" and `BTN_DEFEND` "தடு": short, but check they read as game actions.
- `QUARTER_SHORT` "கா{n}" (காற்பகுதி) and `EXTRA_TIME_SHORT` "மே{n}" (மேலதிக நேரம்). You could use "Q{n}"/"ET{n}" if Latin letters are preferred.
- `COL_P/W/D/L` → வி/வெ/ச/தோ, `COL_PTS` "புள்", and the invented `BOX_*` abbreviations (கோ/மு, வழங்கல், உதவி, பெறல், இடை, திசை, மீள், தண்ட, இழப்பு; CPR kept). Revert to English abbreviations if they look odd on the stats screen.
- `CALL_BREAKING` "முன்கூட்டி நுழைவு" and `CALL_REPLAYED_BALL` "மீள் பிடிப்பு": I am not sure there are established Tamil umpire calls.
- `ON`/`OFF` as ஆன்/ஆஃப்: common in Sri Lankan phone UIs, but இயக்கு/நிறுத்து is an alternative.
- `SIMULATE` "தானியக்கம்" (automatic): the button plays out a match without you.
- Tamil script is wider than Latin. MOVE_BUTTONS_NOTE and a few rules texts are long. Check that they wrap well on a small phone.

## Added in 0.2
- Coach **பயிற்சியாளர்**; tips **குறிப்புகள்**; umpiring (the setting) **நடுவர் கண்டிப்பு** ("umpire strictness"), levels குறைந்த விசில் / வழமை / உண்மை அளவு.
- Escalate **உயர்த்தப்பட்டது** (CALL_ESCALATE "உயர்த்தப்பட்டது: பெனால்டி பாஸ்"); advance **முன்னேறியது** ("பாஸ் முன்னேறியது"); ordered off **வெளியேற்றப்பட்டாள்** (feminine, matching RULES_SANCTIONS_TEXT வெளியேற்றலாம்).
- Club season **கழகப் பருவம்** (கழகம் as in DIFF_NORMAL); table **புள்ளிப் பட்டியல்**; round **சுற்று**; grand final **மாபெரும் இறுதி**; premiers **லீக் சம்பியன்கள்!** (லீக் as in RULES_DZ).
- "Tap" is தொடுங்கள் as in QUIT_SURE; the stick is ஸ்டிக் and the dashed ring புள்ளிக்கோட்டு வளையம். 0.9 மீ with a decimal point.
- Check first: `UMPIRING` (an alternative is நடுவர் முறை), `CALL_ADVANCE`, `MENU_LEAGUE` (பருவம் vs சீசன் in Sri Lankan sports writing), `LEAGUE_WON`, `STAGE_GRAND_FINAL`, and the length of the COACH_* tips in the 600 px box (Tamil script is wide; `COACH_PASS` and `COACH_DEFEND` are the longest).
