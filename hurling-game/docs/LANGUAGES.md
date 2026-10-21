# Languages

## Who plays and watches hurling, and what they speak

- **Ireland and Northern Ireland** are the game's heartland and its market: the 2025 All-Ireland senior hurling
  final averaged 980,000 viewers on RTÉ2 (peak 1.12 million) with about 400,000 streams
  (https://about.rte.ie/2025/07/22/tipperarys-epic-second-half-all-ireland-hurling-final-comeback-draws-over-one-million-viewers-to-rte2).
  The strongest counties are in Munster and south Leinster; Antrim, Down and Derry carry it in Ulster.
- **The Irish abroad**: more than 500 GAA clubs outside Ireland: 171 in the USA, over 100 in GAA Europe across 20+
  countries (about 4,900 players), clubs across Britain, Canada, Australia, New Zealand, Asia and the Middle East
  (https://en.wikipedia.org/wiki/Geography_of_the_GAA, https://gaelicgameseurope.com/about-us/,
  https://www.gaa.ie/my-gaa/world-gaa/our-clubs/usgaa). Nearly all play and follow the game in English.
- **Irish (Gaeilge)**: 1,873,997 people in Ireland (40%) said they could speak it in the 2022 census; 71,968 speak it
  daily outside education
  (https://www.cso.ie/en/releasesandpublications/ep/p-cpp8/censusofpopulation2022profile8-theirishlanguageandeducation/irishlanguageandthegaeltacht/).
  In Northern Ireland 12.4% have some Irish (2021 census). Irish is the GAA's own language (its name is Irish, its
  terms are Irish, county programmes print the team sheet in Irish, TG4 broadcasts the games in Irish).
- Other languages spoken at home in Ireland (Polish 124,000, Romanian, French, Portuguese, Spanish) come with
  fluent English and no hurling tradition; shinty's Scottish Gaelic speakers are not a hurling audience.

## In the game

| Code | Language | Why |
|---|---|---|
| `en` | English | Everyone who plays or watches hurling. Written in Irish and British spelling (colours, centre, licences). |
| `ga` | Gaeilge (Irish) | The sport's own language: its terms (camán, sliotar, cúl, cúilín, poc amach), its team sheets, its broadcasts on TG4. A sizeable minority of players speak it, and every Irish schoolchild learns it. |

No other language has a meaningful share of hurling's players. French or Spanish listings could come later for GAA
Europe, at low priority.

The game starts in the phone's language when it is Irish (Android locale `ga`), else English; the globe on the home
screen (and Settings > Language) changes it.

**Fonts**: Noto Sans for the text, Oswald for headings and Uncial Antiqua for the title, all with every Irish letter
(á é í ó ú Á É Í Ó Ú). `tests/fit_audit.gd` checks every character on every screen has a glyph.

**Fitting**: Irish runs about a fifth longer than English. Irish text is set 4% smaller, and every label that can
run long is fitted (UI.fit: a second line, then an ellipsis; UI.shrink: a smaller size, by real line heights;
UI.keep_on_screen: a whole page drawn smaller, to 70% at most). fit_audit checks every screen in both languages at
16:9, 19.5:9, 20:9 with a camera cut-out and a 4:3 tablet: no text cut, broken mid-word, off the screen, over other
text, a raw key or a missing glyph.

**Plurals**: Irish has five plural forms (CLDR: one 1, two 2, few 3-6, many 7-10, other). Counted words take a key
for each form (`MARGIN_one`, `MARGIN_two`, `MARGIN_few`, `MARGIN_many`, `MARGIN_other`) and `game/plural.gd`
chooses (tested in test_runner). The mutations follow the numeral: 1 chúilín, 2 chúilín, 3-6 chúilín (lenition),
7-10 gcúilín (eclipsis), 20 cúilín. Elsewhere the game avoids number-plus-noun phrases (scores are "2-15", minutes
are "14 nóim.").

**Names**: players' names show in their Irish form in Irish (Seán Ó Briain) and their English form in English (Seán
O'Brien), the way county programmes print the team sheet in Irish. Counties likewise: Cill Chainnigh, Tiobraid
Árann, Port Láirge.

## The store listing

Google Play does **not** offer Irish as a store-listing language (the Console's list runs from Afrikaans to Zulu
without `ga`; Welsh, Breton and Scottish Gaelic are absent too). English listings: **en-GB** (the default: Ireland
sees it, as there is no en-IE), **en-US**, **en-AU**, **en-CA** (store/listing/). Each says "Ar fáil as Gaeilge /
Available in Irish", and two of the screenshots show the game in Irish.
To confirm: Play Console > Store presence > Store listings > Manage translations (the research could not open
Google's own page).

## The GAA's terms in Irish, as used

| English | Irish in the game | Confidence |
|---|---|---|
| hurling | iománaíocht | sure |
| hurley | camán | sure |
| sliotar | sliotar | sure |
| goal / point | cúl / cúilín | sure |
| goalkeeper | cúl báire | sure |
| full-back, half-back (lines) | lánchúlaí, leathchúlaí | sure |
| midfield | lár na páirce | sure |
| half-forward, full-forward | leath-thosaí, lántosaí | sure |
| referee | réiteoir | sure |
| linesman | maor líne | sure |
| umpire | maor cúil | likely |
| free | saorphoc (pl. saorphocanna) | likely (Tuairisc writes "pocanna saora"; both are used) |
| puck-out | poc amach | sure |
| penalty | poc éirice | likely ("poc pionóis" is also used, after football's "cic pionóis") |
| sideline cut | poc sleasa | likely |
| 65 | poc 65 | likely |
| throw-in | caitheamh isteach | sure |
| small / large rectangle | cearnóg bheag / cearnóg mhór | likely |
| yellow / red / black card | cárta buí / dearg / dubh | sure |
| sin bin | bosca smachta | **check** (a coinage; there may be a settled term on TG4) |
| half time / full time | leath ama / deireadh an chluiche | sure ("lánaimseartha" is also seen) |
| extra time | am breise | sure |
| hand-pass | pas láimhe | likely |
| solo | solo | likely (borrowed, as players say it) |
| wide | amú | likely ("iarracht amú") |
| knock-out game | cluiche cnaguirlis | **check** |
| tackle (button) | tacláil | likely |
| semi-final, final | cluiche leathcheannais, cluiche ceannais | sure |
| coach | traenálaí | sure |
| substitute(s), the bench | ionadaí (ionadaithe), an binse | sure |
| tactics, sweeper | beartaíocht, scuabaire | **check** (scuabaire for the sweeper is a calque) |
| two inside (the two-man full-forward line) | beirt istigh | **check** |
| a bye (in a round) | sos | **check** |

## For a native speaker to check

Every Irish string in `i18n/src/ga.json` was written for this build and should be read by a native speaker before
release. In particular:
- the button words, which must be short: BUAIL (strike), CÚL (goal), PAS, SOLO, LÁMH (hand), BEIR (catch), ARDAIGH
  (lift), TARRAING (pull), TACLÁIL, BAC (block), ATHRAIGH (switch), GEARR / FADA (short / long);
- "bosca smachta" for the sin bin, "cluiche cnaguirlis" for a knock-out game, "Corn an Dara Sraith" for the Tier Two
  Cup;
- the plural forms of cúilín after 11-19 ("11 chúilín" is read "aon chúilín déag");
- the How to Play texts (RULES_*_TEXT, CTRL_*_TEXT), the longest Irish in the game;
- 0.2.0's new texts: the coach's tips (COACH_*), substitutions and tactics (SUBS_*, TAC_*), the bye (CHAMP_BYE) and
  the match-length note (LENGTH_NOTE). "fágtha" (left) is the same in every plural form, so SUBS_LEFT has one text.
Reports from the beta go to joshnason8@gmail.com (support page).
