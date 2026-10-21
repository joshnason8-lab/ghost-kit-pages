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
