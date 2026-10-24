# Languages

Who would download Pok Ta Pok Rivals on Google Play, which languages the game ships, and why. Researched October
2026. A sandbox blocked direct loads of Google Play, StatCounter, Wikipedia, INEGI and Pew, so most figures come from
search results that quote those sources. Each figure gives its URL.

## Who plays and watches the game

| Market | Why it matters | Figures |
|---|---|---|
| **Mexico** | The game's home. Ulama is still played in Sinaloa; pelota maya is revived in Yucatán, Quintana Roo, Campeche and Chiapas. It is the largest Android market in the region. | About 78% of phones run Android ([StatCounter](https://gs.statcounter.com/os-market-share/mobile/mexico)). 100.2 M internet users (83.1%) in 2024; 97.2% of them go online by smartphone ([INEGI ENDUTIH 2024](https://inegi.org.mx/contenidos/programas/endutih/2024/doc/presentacion_endutih2024.pdf), [Forbes México](https://forbes.com.mx/los-usuarios-de-internet-en-mexico-ascendieron-a-100-2-millones-en-2024-el-83-1-de-la-poblacion/)). Mexico's games market was about US$2.56 B in 2023 ([Allcorrect](https://allcorrectgames.com/?p=8774)). |
| **Guatemala, Belize, Honduras, El Salvador** | Maya lands. Pitz/pelota maya revival teams play here. | Guatemala: about 69% Android ([StatCounter](https://gs.statcounter.com/os-market-share/mobile/guatemala)), 11.6 M internet users ([DataReportal](https://datareportal.com/reports/digital-2026-guatemala)). Honduras: about 69% Android ([StatCounter](https://gs.statcounter.com/os-market-share/mobile/honduras)). El Salvador: 4.9 M internet users ([DataReportal](https://datareportal.com/reports/digital-2025-el-salvador)). Belize: not verified (English is its official language). |
| **United States** | 68 M Hispanics, of whom about 60% are of Mexican origin; also history and curiosity players. | [Pew 2025](https://www.pewresearch.org/short-reads/2025/10/22/key-facts-about-us-latinos/), [Pew, Mexican origin](https://www.pewresearch.org/race-and-ethnicity/fact-sheet/us-hispanics-facts-on-mexican-origin-latinos/) |
| **Visitors to the Maya sites** | Chichén Itzá, home of the Great Ball Court, had 2.18 M visitors in 2025, 60% of them from abroad ([Posta](https://www.posta.com.mx/yucatan/con-cuantos-visitantes-cerro-chichen-itza-el-2025/vl2145464)). No breakdown by nationality was found. Mexico's air arrivals stand in for it ([Infobae](https://www.infobae.com/mexico/2025/11/21/llegaron-mas-de-15-millones-de-turistas-a-mexico-de-enero-a-septiembre/)). | Air arrivals, Jan–Sep 2025: US about 10.2 M, Canada 1.9 M, UK 0.33 M. Argentina (+20%) and Italy (+16%) grew fastest ([UnoTV](https://www.unotv.com/turismo/mexico-recibio-395-mil-turistas-de-argentina-italia-y-china-en-los-ultimos-8-meses/)). France, Germany and Spain are steady European markets ([Turespaña](https://conocimiento.tourspain.es/export/sites/conocimiento/.content/Informes/mercado-emisor/2025/2-mexico-mercado-emisor-2025.pdf)). |
| **Brazil** | Latin America's largest games market (about US$2.57 B), about 78% Android, with Portuguese its own language. | [StatCounter](https://gs.statcounter.com/os-market-share/mobile/brazil), [Allcorrect](https://allcorrectgames.com/?p=8774) |

## The languages in the game

| Code | Language | Why |
|---|---|---|
| `es` | Español (Latin American: Mexican usage, *ustedes*, no *vosotros*) | Mexico, Central America, US Hispanics, Spain. The game's first language. Sport terms are the real ones: *raya*, *taste*, *analco*, *veedor*, *ulama de cadera*, *pelota*, *fajado*. |
| `en` | English | The US, Canada, the UK, Belize, and the fallback for every other phone. |
| `pt` | Português (Brasil) | Brazil. |
| `fr` | Français | France, Canada (Quebec) and Belgium: visitors to the Maya sites. |
| `de` | Deutsch | Germany, Austria and Switzerland: visitors to the Maya sites. |
| `it` | Italiano | Italy, a fast-growing visitor market. |

The game starts in the phone's language when it has it, otherwise English. The globe on the home screen and
Settings > Language change it.

**Not shipped as a full language: Yucatec Maya (maaya t'aan).** About 775,000 people speak it (2020 census;
[IWGIA](https://iwgia.org/es/mexico/4149-mi-2021-mexico.htm)). Google Play has no listing locale for it. A full
translation needs a native translator, so the game uses it for touches only, in every language:

- The Yucatán teams' nicknames and the court names (DB).
- The judges' Maya count on the classic court: *jun, ka', óox, kan, jo', wak, uk, waxak* (1–8)
  ([Omniglot](https://www.omniglot.com/language/numbers/yucatecmaya.htm), [UADY course](https://www.mayas.uady.mx/curso_maya/lec5_6.html)).
- *Ma'alob!* ("good!") on a fine return, and *pitz* (the Classic Maya name for the ballgame,
  [Hudson Museum](https://umaine.edu/hudsonmuseum/maya/ballgame-2/)) in How to Play.

Every Maya word is marked for a native speaker to check in docs/CULTURE.md. For example, *Ba'ax ka wa'alik* is glossed
"what's up?" by Omniglot but "good evening" by INALI's prontuario, so the game does not use it.

**Nahuatl** appears only in How to Play's history: *ōllamaliztli* (the ballgame, from *ōlli*, rubber) and *tlachtli*
(the court) ([Wikipedia: Ulama](https://en.wikipedia.org/wiki/Ulama_(game))).

**RTL:** none of these languages needs it.

## Store listings (store/listing/)

Google Play locales: `es-419`, `es-US`, `es-ES`, `en-US`, `en-GB`, `en-CA`, `pt-BR`, `fr-FR`, `fr-CA`, `de-DE`,
`it-IT` ([Play's list](https://support.google.com/googleplay/android-developer/answer/9844778)). es-ES uses the same
text as es-419 with *vosotros* avoided throughout, so it reads naturally in Spain too.

## Fonts and plurals

Every language uses the Latin script. Noto Sans (text) and Oswald (headings) are subset to Latin, Latin Extended-A
and punctuation (tools/subset_fonts.py). That covers á é í ó ú ñ ü ç ã õ â ê ô à è ì ò ù ë ï œ ß, plus the Maya
apostrophe (U+0027) and ʼ (U+02BC). Plurals follow CLDR: every shipped language has *one* and *other*. French
treats 0 as *one* (game/plural.gd).

## Translations to check

The translations were written for the game, not by native speakers. These need a native speaker's check:

- All of `pt`, `fr`, `de`, `it`: the sport's terms are kept in Spanish (*raya*, *analco*, *veedor*) with a gloss on
  first use. That follows how writers in those languages describe ulama, but the glosses should be checked.
- `es`: the ulama count's words come from Sinaloa usage in the sources (docs/RULES.md). A Sinaloa player should check
  the calls the judges make in the game.
