# Languages

Kho Kho Rush starts in the phone's language when it has it. The globe button on the home screen changes it, and so
does Settings > Language. Fourteen languages are in the game.

## Who plays kho kho, and what they speak

Kho kho is played and watched most in India, and in India most in Maharashtra, where the game was born ("kho" is
Marathi). Other strongholds:

- **Maharashtra:** won its fifth straight senior women's title in January 2026, beating Odisha 23-22.
- **Odisha:** the senior women's runner-up; hosted the franchise league's second season and the 57th nationals.
- **Karnataka:** the 2026 junior champions.

Kerala, Telangana and Andhra Pradesh, West Bengal, Gujarat, Delhi and the Hindi-speaking north all field national
contenders.

Outside India:

- **Nepal:** runner-up in both finals of the 2025 world championship. It held its first national league in 2025.
- **Bangladesh and Sri Lanka:** reached the quarter-finals.
- **Bhutan:** has national teams.
- **Elsewhere:** England, South Africa, Kenya and others play through their South Asian communities.

The world championship drew a claimed 460 million views. The franchise league's first season drew 64 million
viewers, 41 million of them in India. Sources: docs/RULES.md for the competitions; for the markets, uniindia.com
and khokhofederation.in (2026 nationals), ianslive.in (juniors), thebridge.in (Odisha and the league), Wikipedia
(2025 world championship, Nepal Kho Kho Association, 2022 Ultimate Kho Kho), mediainfoline.com (Nepal's league).

## The languages, and why each is in

| Language | Code | Script | Why | Play listing |
|---|---|---|---|---|
| English | en | Latin | everywhere; the diaspora; Indian English | en-US, en-IN, en-GB |
| Hindi | hi | Devanagari | the national audience, Delhi and the north; national TV | hi-IN |
| Marathi | mr | Devanagari | the heartland (Maharashtra) | mr-IN |
| Kannada | kn | Kannada | Karnataka, junior champions | kn-IN |
| Telugu | te | Telugu | Telangana (2026 nationals' host), Andhra Pradesh | te-IN |
| Tamil | ta | Tamil | Tamil Nadu, Sri Lankan Tamils | ta-IN |
| Malayalam | ml | Malayalam | Kerala, a regular contender | ml-IN |
| Odia | or | Odia | Odisha, a stronghold (women's runner-up, league host) | none: Play has no Odia listing |
| Bengali | bn | Bengali | West Bengal and Bangladesh | bn-BD |
| Gujarati | gu | Gujarati | Gujarat | gu |
| Punjabi | pa | Gurmukhi | Punjab, the north's diaspora | pa |
| Assamese | as | Bengali-Assamese | Assam (the north-east's side) | none: Play has no Assamese listing |
| Nepali | ne | Devanagari | Nepal, the world runner-up | ne-NP |
| Sinhala | si | Sinhala | Sri Lanka | si-LK |

Odia and Assamese were not in the Play Console's listing languages as far as could be found (the support page was
blocked here; please confirm under Store listing > Manage translations). They are in the game regardless: Android
hands the game the phone's language, and the game shows Odia or Assamese. Their players see the English (en-IN)
listing, which names the sport's Odia and Assamese words in its description.

No language here is written right to left, so the game has no RTL layout.

## The words of the sport

The translators were asked to use the words players and commentators use. For "kho", that is the word itself in
each script (खो, ଖୋ, ಖೋ, ఖో, கோ, ഖോ, খো, ખો, ਖੋ, කෝ). For the rest it is often the English word in the local script:
आउट, ফাউল, డైవ్, പവർ പ്ലേ. Native words are kept where they are what people say: Marathi's आक्रमक and संरक्षक
(chaser and defender), डाव (innings), खांब (pole); Hindi's खंभा; Kannada's ಕಂಬ; Tamil's கம்பம்; Odia's ଖୁଣ୍ଟ.

## Fonts and sizes

Every script has its own Noto Sans, cut to that script (tools/subset_fonts.py). The display face, Baloo 2, covers
Latin and Devanagari; the other scripts fall back to Noto Sans at its boldest. The twelve fonts come to 2.4 MB.

Some scripts take more room than English for the same words. Kabaddi Raid learned on phones how much smaller each
needs to be set (Game.TEXT_K):

| Script | Size against English |
|---|---|
| Tamil | 14% smaller |
| Malayalam | 12% smaller |
| Telugu, Kannada, Sinhala | 7% smaller |
| Odia | 6% smaller |
| Bengali, Assamese | 4% smaller |
| Devanagari, Gujarati, Gurmukhi | 3% smaller |

Tamil, Telugu, Kannada, Bengali, Malayalam, Odia, Assamese and Sinhala get a third line before a name is cut
(Game.long_words). A single word too wide for its space is set smaller rather than broken (UI.shrink).
`tests/fit_audit.gd` checks every screen in every language at 16:9, 19.5:9, 20:9 with a camera cut-out, and a 4:3
tablet. It looks for:

- cut text;
- broken words;
- text off the screen or overlapping;
- raw keys;
- missing glyphs.

It also checks the button labels in their circles at all three button sizes. It is clean.

## For a native speaker to check

Every translation was made without a native speaker, so each needs one to read it. The terms the translators were
least sure of are listed per language in `docs/translation-notes/`. The main ones:

- table column abbreviations;
- the short form of "turn" (T1, पा1, ட1);
- heads and tails at the toss;
- the dodge button's word in Marathi, Malayalam and Sinhala;
- whether "pole dive" should use the local word for pole;
- Marathi: whether "dive" should be सूर;
- Sinhala: how its joined letters render.

The fit audit confirms only that each word fits, not that it is right.
