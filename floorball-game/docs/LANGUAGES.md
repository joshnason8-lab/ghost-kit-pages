# Languages

Floorstorm ships fifteen languages in the game and a Google Play listing in each (store/listing/). It starts in the
phone's language when it has it (Norwegian phones report "nb" or "no"), else English; the globe on the home screen
and Settings change it.

## Who would download it

Floorball's players are concentrated: Sweden (~118,000 licensed), Finland (~65,800), Czechia (~41,400) and
Switzerland (~34,000) hold three-quarters to four-fifths of the world's ~350,000 licensed players (IFF, 2020); then
Germany (8-13k), Denmark (10-12k), Norway (5-8k), Slovakia (~7k), Latvia (~3.5k, fourth at the 2024 men's World
Championship), Singapore (~3.7k), Japan (~3k), Estonia (~1.4k), Australia (~1.3k). Thailand hosts the Asia-Oceania
confederation and qualifies for world championships; Poland has a federation and a large population. Sources: the
IFF's licensed-player posts (https://floorball.sport/2016/03/09/number-of-licensed-players-2015 and the 2018-2021
posts), its member pages (https://archive.floorball.sport/czech-republic/, /germany, /denmark, /latvia, /estonia,
/australia), Svensk Innebandy (https://via.tt.se/pressrum/3236077/svensk-innebandy), swiss unihockey via
https://floorball.sport/2020/05/12/new-record-of-licensed-players-in-switzerland/. The men's World Championship
in Tampere, 5-13 December 2026, is a natural launch window.

| Language | Code | Play listing | Why | Local name of the sport |
|---|---|---|---|---|
| English | en | en-US | Everyone else: Singapore, Australia, the Philippines, Canada, the USA, the Netherlands | floorball |
| Swedish | sv | sv-SE | Sweden, a third of the world's players, and Swedish-speaking Finns | innebandy |
| Finnish | fi | fi-FI | Finland, men's world champions, hosts of 2026 | salibandy |
| German | de | de-DE | Switzerland's German speakers, Germany, Austria | Unihockey (CH), Floorball (DE, AT) |
| French | fr | fr-FR | Romandy (Switzerland), France, Belgium | unihockey |
| Italian | it | it-IT | Ticino, Italy | unihockey / floorball |
| Czech | cs | cs-CZ | Czechia, third market, women's silver 2025 | florbal |
| Slovak | sk | sk | Slovakia, ranked sixth | florbal |
| Norwegian Bokmål | nb | no-NO | Norway, ranked eighth | innebandy |
| Danish | da | da-DK | Denmark, ranked tenth | floorball |
| Latvian | lv | lv | Latvia, ranked fourth | florbols |
| Estonian | et | et | Estonia, ranked ninth | saalihoki |
| Polish | pl | pl-PL | Poland | unihokej |
| Japanese | ja | ja-JP | Japan, Asia's largest market by spending | フロアボール |
| Thai | th | th | Thailand, Asia-Oceania's hub | ฟลอร์บอล |

No right-to-left language is needed: none of these markets uses one.

## Decisions

- **German with "ss", never "ß", and the sport called Unihockey**: most German-speaking players are Swiss; "ss" reads
  correctly in Germany and Austria too. Swiss forms (Viertelfinal, Halbfinal) are kept. Play has no de-CH listing, so
  the de-DE listing is written the same way.
- **French and Italian Swiss-flavoured** (unihockey, canne, bully, coup franc): Romandy and Ticino are their markets.
- **Plurals by CLDR rules** (Game.plural): one/other for most; Czech and Slovak add few (2-4); Polish few and many;
  Latvian zero (0, 10-20, 30 ...); French counts 0 as one; Japanese and Thai one form. Where a number sits by a noun
  elsewhere, the translations are phrased so the grammar does not depend on it ("Saves: 12").
- **Fonts**: Noto Sans (Latin incl. every Czech, Slovak, Polish, Latvian, Estonian, Nordic letter), Caveat for the
  marker titles, Barlow Condensed for the scoreboard, Noto Sans Thai, and Noto Sans JP cut to the Japanese text's
  characters (tools/subset_fonts.py). tests/fit_audit checks every character has a glyph.
- **Text fit**: tests/fit_audit reads every screen in every language at 16:9, 19.5:9, 20:9 with a camera cut-out and
  4:3. Finnish, Estonian, German, Latvian and Czech words get one more line before an ellipsis (Game.long_words).

- **Goals straight from a hit-in**: several translators' notes below flag that the glossary's summary said a goal
  could not be scored from a hit-in. The 2026 rules' 504 says it can ("a goal may be scored directly from a hit-in");
  the game and every translation follow 504.

## For a native speaker to check

The translations were written by AI translators from the English with a glossary of each country's floorball terms
taken from its federation's rulebooks where those could be found. Everything below is what they marked as unsure.
Corrections are welcome: email joshnason8@gmail.com with the screen and the words.

### Swedish (sv)

#### Terms chosen
innebandy · mål · målvakt · utespelare · tekning / tekningspunkt (face-off) · frislag · inslag (hit-in) · utvisning · litet/stort lagstraff, personligt straff, matchstraff · straffslag · fördel · fördröjd utvisning · förlängning · powerplay · byteszon · femma (line) · sarg · plan · klubba · målområde (goal crease) · målvaktsområde (goalkeeper area) · mittpunkt · utkast (GK throw) · räddning · assist · självmål

#### Please check
- BTN_TACKLE "Bryt" (CTRL_TACKLE same): I avoided "Tackla" because it sounds like body contact. Is "Bryt" clear on a button?
- SH_SHORT "BP" (boxplay): I took this from hockey usage. Would "SH" or "NU" (numerärt underläge) be better?
- OT_SHORT "förl." / SO_SHORT "str.": OK as score suffixes (e.g. "3–2 förl.")?
- COL_P/W/D/L/PTS = M/V/O/F/P: standard table headers?
- MENU_CUP "Världsfinaler": a made-up name to avoid saying "VM". Would "VM-turnering" read more naturally?
- RULE_PENALTIES_BODY: I used the official-sounding "litet/stort lagstraff" and "personligt straff". Check them against the Swedish rulebook wording.
- OFF_CHARGE "Otillåten tackling", OFF_VIOLENT_STICK "Våldsamt klubbslag", OFF_FIGHT "Våldsamt uppträdande": check against the rulebook offence names.
- OFF_LYING "Liggande spel", OFF_BLOCK_LYING "Liggande blockering": natural?
- VENUE_SCHOOL "Gympasal" is informal; "Gymnastiksal" is the alternative.
- RULE_HITIN_BODY says a goal may be scored directly from a hit-in, following en.json. The glossary's rule facts say a goal can NOT be scored from a hit-in. The English source needs checking.
- FULL_TIME "Slutsignal" vs "Slut": which reads better on the end screen?

### Finnish (fi)

Files: i18n/src/fi.json, store/listing/fi-FI.txt

#### Floorball terms chosen
- floorball: salibandy · goal: maali · goalkeeper: maalivahti · field player: kenttäpelaaja
- face-off: aloitus (face-off dot: aloituspiste, centre spot: keskipiste)
- free-hit: vapaalyönti · hit-in: rajalyönti (glossary said "verify")
- penalty: jäähy (UI/stats); formal "rangaistus" in rule text: joukkuerangaistus, henkilökohtainen 10 minuutin rangaistus, ottelurangaistus
- penalty shot: rangaistuslaukaus; shootout: voittolaukaukset (SO_SHORT "vl", AFTER_SHOOTOUT "voittolaukauksin")
- period: erä · interval: erätauko · overtime: jatkoaika (OT_SHORT "ja")
- power play / short-handed: ylivoima / alivoima (PP_SHORT "YV", SH_SHORT "AV")
- goal crease: maalialue · goalkeeper area: maalivahdin alue · substitution zone: vaihtoalue
- time-out: aikalisä · referee: erotuomari · stick: maila · slap shot: lämäri
- advantage: etu · delayed penalty: viivästetty jäähy
- effective time / running clock: tehokas peliaika / juokseva aika
- Buttons: Laukaus, Syöttö, Kiri, Riisto, Vaihto (all nouns)
- Table columns: O V T H (ottelut, voitot, tasapelit, häviöt), P (pisteet)

#### Strings to check
- SO_SHORT / SHOOTOUT / AFTER_SHOOTOUT / DRAW_DECIDED / RULE_OT: I used the everyday "voittolaukaukset" for the shootout and "rangaistuslaukaus" for a single penalty shot. The rulebook may say "rangaistuslaukauskilpailu"; is "vl" the right short form for salibandy results?
- OT_SHORT "ja": copied from ice hockey result style ("ja" = jatkoajalla). Could also be "JA".
- STAGE_PLAYOFFS "Karsinta" / CUP_INTRO "karsinnat": the round before the quarter-finals. Media may use "pudotuspelikarsinta" or "playoff".
- MENU_CUP "MM-turnaus" for "World Finals": it suggests a world championship without naming any organiser. OK?
- CTRL_TACKLE / BTN_TACKLE "Riisto": "riisto" usually means the result (a steal), not the stick action. Alternatives: "Taklaus" (wrong for floorball), "Mailaus".
- BTN_SPRINT "Kiri": "Spurtti" is another option.
- OFF_CHARGE "Päällekarkaus": not sure this is the salibandy rulebook term for charging.
- OFF_HIGH_BALL "Korkea pelaaminen": the rule term for playing the ball above the knee; please confirm.
- OFF_HEAD "Pelaaminen päällä" and OFF_LYING "Pelaaminen lattiatasossa": check against the rulebook names.
- OFF_PROTEST "Valittaminen": or "Protestointi".
- ASSIST_SHORT "syöt.": Finnish box scores often just put the assist in brackets; may be better as "s".
- SIGN_ADVANTAGE_BODY: the call written as "etu!"; Finnish referees may shout something else.
- SIGN_PEN10 "10 min henkilökohtainen": shortened from "10 minuutin henkilökohtainen rangaistus" to fit; check that it reads OK as a title.
- AUTO_SWITCH "Automaattinen pelaajanvaihto" (28 letters, one compound): might be long for a settings row; "Vaihda pelaaja itse" is an option.
- RULE_HITIN_BODY / CTRL_RESTART_BODY say a goal can be scored straight from a hit-in, as the English source says. The glossary says a hit-in cannot score directly. Please check this against the 2026 rules (applies to all languages).

### German (de)

Audience: Switzerland first, then Germany/Austria. "ss" everywhere, no "ß" (checked: none in de.json or de-DE.txt). Informal "du".

#### Terms chosen
- Sport in prose: Unihockey (store text: "Unihockey (Floorball)" once, so people in Germany recognise it)
- Face-off: Bully (pl. Bullys), face-off dot: Bullypunkt, centre spot: Mittelpunkt
- Free-hit: Freischlag; hit-in: Einschlag; "Frei- und Einschläge" in a title
- Penalties: 2-Minuten-Strafe, 5-Minuten-Strafe, persönliche 10-Minuten-Strafe, Matchstrafe, Bankstrafe (klein/gross)
- Penalty shot: Penalty (pl. Penaltys); shootout: Penaltyschiessen
- Period: Drittel; overtime: Verlängerung; power play: Überzahl; short-handed: Unterzahl
- Goal crease: Torraum; goalkeeper area: Torhüterraum; goalkeeper: Torhüter (Goalie in the tagline and store text)
- Stick: Stock; boards: Bande; substitution zone: Wechselzone
- Buttons: Schuss, Pass, Sprint, Tackling, Wechseln (the CAPS button names in CTRL_* bodies match these)
- Abbreviations: OT_SHORT "Verl.", SO_SHORT "n.P.", PP_SHORT "ÜZ", SH_SHORT "UZ", ASSIST_SHORT "Ass."
- Table: Sp / S / U / N / Tore / Pkt
- Swiss forms on purpose: Viertelfinal, Halbfinal (DE would be Viertelfinale/Halbfinale), Damen/Herren, «» quotes

#### Unsure (please check)
- OT_SHORT "Verl.": the code uses it both as a period label in the HUD and as a suffix after a cup score ("3–2 Verl."). "n.V." only works as the suffix, so I picked "Verl.". SO_SHORT "n.P." is used only as a suffix.
- PP_SHORT/SH_SHORT "ÜZ"/"UZ": are these common in Swiss match reports, or do they use "PP"/"SH" (or "BP")?
- BTN_TACKLE / CTRL_TACKLE "Tackling": sounds like a football word. Is there a better short Unihockey verb for a stick check at the ball?
- STAGE_QF/STAGE_SF "Viertelfinal"/"Halbfinal": Swiss singular. In Germany this reads as a typo. Switch to "Viertelfinale" if Germany matters more.
- OFF_STICK_HIT "Schlag auf den Stock" vs OFF_SLASH "Stockschlag" vs OFF_VIOLENT_STICK "Gewaltsamer Stockschlag": please check against the official German rulebook terms.
- OFF_CHARGE "Rempeln", OFF_OBSTRUCT "Sperren", OFF_LYING "Spiel am Boden": unverified rulebook wording.
- MENU_CUP "WM-Endrunde": suggests a World Championship without naming any organiser. Alternative: "Weltfinale".
- FRIENDLY "Freundschaftsspiel" is long (19 chars). Alternative: "Testspiel".
- BOX_SCORE "Statistik": Swiss "Matchblatt" is another option.
- OVERTIME_NOTE keeps "Sudden Victory" (the rulebook term in German-speaking countries). Is this right?
- Source content, not translation: RULE_HITIN_BODY and CTRL_RESTART_BODY say a goal may be scored directly from a hit-in, but the glossary says it cannot. I translated the English as written; the game designer should check this.
- Code issue: ui/result_screen.gd hardcodes "2 min"/"5 min"/"10 min" (not translatable, but fine in German).

### French (fr)

Audience: Romandie first, then France. Informal "tu". Typography: no-break space (U+00A0) before : ; ! ? and inside « ». Swiss French often uses no space before ; ! ?, so remove those if you prefer that style.

#### Terms chosen
- Sport: unihockey; stick: canne; ball: balle; boards: bande(s)
- Face-off: bully (pl. bullys); face-off dot: point d'engagement; centre spot: point central
- Free-hit: coup franc; hit-in: remise en jeu
- Penalties: pénalité de 2/5 minutes, pénalité personnelle de 10 minutes, pénalité de match, petite/grande pénalité de banc; "purger" a penalty
- Penalty shot: penalty (pl. penaltys); shootout "penaltys", "aux penaltys"
- Period: tiers-temps (in short UI labels: "tiers", e.g. "Tiers {n}", "Fin du tiers {n}")
- Overtime: prolongation; sudden death: mort subite; power play: supériorité numérique
- Goal crease: zone de but; goalkeeper area: zone du gardien
- Own goal: autogoal (Swiss); time-out: temps mort
- Buttons: Tir, Passe, Sprint, Tacle, Changer (the CAPS names in CTRL_* bodies match these)
- Abbreviations: OT "Prol.", SO "pen.", PP "sup.", SH "inf.", assist "ass."
- Table: J / V / N / D / Buts / Pts

#### Unsure (please check)
- RULE_RINK_BODY etc. "zone de but" (4x5 m crease) vs "zone du gardien" (1x2.5 m): the glossary only confirms "zone du gardien". Please check the Swiss French rulebook name for the crease.
- OWN_GOAL / RULE_GOALS_BODY "autogoal": Swiss word. In France it would be "but contre son camp" (too long for the score line).
- PP_SHORT/SH_SHORT "sup."/"inf.": made up; Romandie may use "PP"/"BP" (box play).
- SO_SHORT "pen." vs "t.a.b." (ice hockey style).
- MENU_CUP "Finales mondiales": maybe "Phase finale mondiale" or "Mondial".
- CTRL_SHOOT_BODY "tir frappé" for slap shot: correct in unihockey? Alternative: "slap shot".
- OFF_* infraction names (Crochetage, Retenue, Charge irrégulière, Blocage couché, Brutalité, Retard de jeu): unverified against the official French wording.
- ON/OFF rendered "Oui"/"Non" for toggles. Use "Activé"/"Désactivé" if the space allows.
- FPS_N "{n} ips" (images par seconde): change to "fps" if players expect it.
- Source content: RULE_HITIN_BODY and CTRL_RESTART_BODY say you can score directly from a hit-in, but the glossary says the opposite. I translated the English as written.

### Italian (it)

Audience: Ticino first, then Italy. Informal "tu". All Italian glossary terms were marked unverified, so the whole term set needs a check by a native speaker who plays.

#### Terms chosen
- Sport: unihockey; stick: bastone; ball: palla (the glossary says "pallina", see below); boards: balaustra
- Face-off: ingaggio; face-off dot: punto d'ingaggio; centre spot: punto centrale
- Free-hit: punizione; hit-in: rimessa
- Penalties: penalità di 2/5 minuti, penalità personale di 10 minuti, penalità di partita, penalità minore/maggiore di squadra
- Penalty shot: tiro di rigore; shootout: rigori ("ai rigori")
- Period: tempo ("{n}° tempo"); overtime: supplementare; power play: superiorità numerica
- Goal crease: area di porta; goalkeeper area: area del portiere; field player: giocatore di movimento
- Buttons: Tira, Passa, Scatta, Contrasta, Cambia (imperatives; the CAPS names in CTRL_* bodies match these)
- Abbreviations: OT "Suppl.", SO "rig.", PP "sup.", SH "inf.", assist "ass."
- Table: G / V / N / P / Gol / Pt

#### Unsure (please check)
- Ball: I used "palla" throughout; the glossary says "pallina". Which does Ticino use?
- Period: "tempo" vs "terzo" vs "periodo". "{n}° tempo" may suggest football halves.
- Penalty shot: "rigore"/"tiro di rigore" vs simply "penalty" (Ticino may say "penalty" like Swiss German speakers).
- Boards "balaustra": or "balaustre"/"bordi"?
- Hit-in "rimessa": or "rimessa laterale"/"rimessa in gioco"?
- PP_SHORT/SH_SHORT "sup."/"inf.": made up.
- CTRL_SHOOT_BODY "tiro schiaffato" for slap shot: hockey usage, check.
- OFF_* names (Aggancio, Bastonata, Carica irregolare, Blocco a terra, Trattenuta): unverified.
- OVERTIME_NOTE: I dropped "sudden victory" and wrote "il primo gol vince".
- SIGN_NO_GOAL/CALL_NO_GOAL/OFF_NO_GOAL "Gol non valido"; NO_GOALS (an empty list) "Nessun gol.".
- Source content: RULE_HITIN_BODY and CTRL_RESTART_BODY say you can score directly from a hit-in, but the glossary says the opposite. I translated the English as written.

### Czech (cs)

#### Terms chosen
- floorball: florbal; stick: hokejka; ball: míček; rink: hřiště; boards: mantinel
- face-off: vhazování (the spoken "buly" is not used); hit-in: rozehrání; free-hit: volný úder
- penalty shot: trestné střílení (plural trestná střílení); goal crease: brankoviště; goalkeeper area: malé brankoviště
- period: třetina; overtime: prodloužení; power play: přesilovka / přesilová hra; time-out: oddechový čas
- penalties: menší/větší trest (2/5 min), osobní trest na 10 minut, trest do konce utkání (match penalty)
- delayed penalty: oddálený trest; advantage: výhoda; slap shot: golfák
- effective / running clock: čistý / hrubý čas
- buttons: Střela, Přihrávka, Sprint, Odebrat, Přepnout. The help texts quote these labels in capitals ("stiskni STŘELA").
- tone: informal "ty"

#### Unsure (key: why)
- OT_SHORT "pp" / SO_SHORT "sn": these are the usual Czech result suffixes (po prodloužení / samostatné nájezdy). "sn" is borrowed from ice hockey, and the official florbal term is trestné střílení. "TS" is an alternative.
- PP_SHORT "PH" / SH_SHORT "OS": hockey-style stat abbreviations (přesilová hra / oslabení).
- RULE_ADVANTAGE, SIGN_DELAYED, CALL_DELAYED "oddálený trest": please check this against the ČFbU Pravidla florbalu. "signalizovaný trest" might be the official term.
- RULE_PENALTIES_BODY "menší/větší trest týmu": the rulebook may say "trest na 2 minuty"/"trest na 5 minut" instead.
- STAGE_PLAYOFFS "Předkolo" and CUP_INTRO "předkolo play-off": the world-championship round before the quarter-finals. Czech media sometimes call it "osmifinále".
- OFF_CHARGE "Nedovolené napadení", OFF_FIGHT "Hrubé chování", OFF_VIOLENT_STICK "Surová hra hokejkou": descriptive wording, not checked against the rulebook's list of offences.
- COL_*: Z/V/R/P/B (zápasy, výhry, remízy, prohry, body). COL_GOALS "Skóre" is 5 letters, like the English "Goals".
- TEAM_USA "USA" instead of "Spojené státy", to save space.
- VS "–" (the Czech score-line dash), e.g. "Česko – Švédsko".
- POTM_GK has been reworded to "Zákroky: {s} · Střely na branku: {a}" so the grammar does not depend on the number.
- FPS_NOTE_SAVER uses "{n} fps" rather than "snímků za sekundu" to avoid needing a plural form.
- Source issue (affects all languages): en.json (RULE_HITIN_BODY, CTRL_RESTART_BODY) says a goal may be scored straight from a hit-in, but the glossary's rule facts say it cannot. I followed en.json. Please check the 2026 rules.

### Slovak (sk)

#### Terms chosen
- florbal; hokejka; loptička; ihrisko; mantinel
- face-off: vhadzovanie (S); hit-in: rozohranie (S); free-hit: voľný úder (S); penalty shot: trestné strieľanie (S), plural trestné strieľania
- goal crease: bránkovisko; goalkeeper area: malé bránkovisko; goal: bránka; goalkeeper: brankár
- period: tretina; overtime: predĺženie; power play: presilovka; time-out: oddychový čas
- penalties: menší/väčší trest, osobný trest na 10 minút, trest do konca zápasu
- delayed penalty: oneskorený trest; advantage: výhoda; slap shot: golfová strela
- effective / running clock: čistý / hrubý čas
- buttons: Strela, Prihrávka, Šprint, Odobrať, Prepnúť. Tone: informal "ty".

#### Unsure (key: why)
- OT_SHORT "pp" / SO_SHORT "sn": hockey-style result suffixes. "sn" (samostatné nájazdy) is not the florbal rule term.
- PP_SHORT "PH" / SH_SHORT "OS": hockey-style abbreviations.
- RULE_ADVANTAGE, SIGN_DELAYED, CALL_DELAYED "oneskorený trest": please check this against the Pravidlá florbalu. "signalizovaný trest" might be the official term.
- RULE_GKAREA, OFF_GK_AREA "malé bránkovisko": the glossary gives only "bránkovisko", so this term is modelled on the Czech one.
- FRIENDLY "Prípravný zápas": the usual Slovak term. "Priateľský zápas" is a possible alternative.
- STAGE_PLAYOFFS "Predkolo": same question as for Czech.
- OFF_CHARGE, OFF_FIGHT, OFF_VIOLENT_STICK, OFF_ROUGH_BOARD: descriptive wording, not checked against the rulebook.
- COL_*: Z/V/R/P/B; COL_GOALS "Skóre". TEAM_USA "USA". VS "–".
- POTM_GK has been reworded to "Zákroky: {s} · Strely na bránku: {a}" so the grammar does not depend on the number.
- The hit-in source issue described in the Czech notes applies here too.

### Norwegian Bokmål (nb)

#### Terms chosen
innebandy · mål · keeper (rather than målvakt) · utespiller · avslag / avslagspunkt (face-off) · frislag · innslag (hit-in) · utvisning · liten/stor lagstraff, personlig straff, matchstraff · straffeslag · fordel · utsatt utvisning · forlengning · overtall (power play; "PP" kept as abbreviation) · bytteson · rekke (line) · vant (boards) · bane · kølle · målområde (goal crease) · keeperområde (goalkeeper area) · midtpunkt · utkast · redning · assist · selvmål

#### Please check
- Face-off "avslag": the glossary sourced it from school rules and said "tekning" might be the official term. Check against the national federation's rules.
- Goalkeeper area "keeperområde": not verified. The rulebook may use "målvaktområde".
- BTN_PASS "Pass": is this clear as an imperative? "Pasning" is the alternative (7 letters). BTN_TACKLE "Takle": is it natural?
- SH_SHORT "UT" (undertall): made up. Is there an established abbreviation?
- OT_SHORT "forl." / SO_SHORT "str.": OK?
- COL_P/W/D/L = K/V/U/T: standard?
- POWER_PLAY / RULE_PP "overtall": would "powerplay" be preferred?
- OFF_HAND "Hands", OFF_HEAD "Heading": football loanwords. Are they fine for innebandy?
- OFF_VIOLENT_STICK "Voldsom køllebruk", OFF_CHARGE "Ulovlig takling": check against the rulebook.
- MENU_CUP "Verdensfinaler": a made-up name.
- RULE_HITIN_BODY: a goal may be scored directly from a hit-in, following en.json. This contradicts the glossary's rule facts, so verify the source.

### Danish (da)

#### Terms chosen
floorball · mål · målmand · markspiller · face-off / face-off-punkt · frislag · indslag (hit-in) · udvisning · lille/stor holdstraf, personlig straf, matchstraf · straffeslag · fordel · udsat udvisning · forlængelse · powerplay · udskiftningszone · kæde (line) · bande (boards) · bane · stav · målfelt (goal crease) · målmandsfelt (goalkeeper area) · midtpunkt · udkast · redning · assist · selvmål

All Danish glossary terms were unverified, so a check against the Danish federation's rules is especially useful.

#### Please check
- Face-off: I kept the English "face-off". "Tekning" was the other option in the glossary.
- Goal crease "målfelt" / goalkeeper area "målmandsfelt": check against the rulebook.
- Stick "stav" vs "stav/kølle": confirm.
- BTN_PASS "Aflever" (7 letters), BTN_TACKLE "Tackl": are these natural as imperatives? "Tackl" may look odd.
- SH_SHORT "UT" (undertal): made up.
- COL_P/W/D/L = K/V/U/T: standard?
- OFF_HAND "Hånd på bolden", OFF_HEAD "Hovedstød": natural for floorball?
- OFF_VIOLENT_STICK "Voldsomt stavslag", OFF_CHARGE "Ulovlig tackling": check.
- DIVISION "Række": I picked it for the men's/women's selector. "Klasse" is the alternative.
- TEAM_NED "Nederlandene" vs the everyday "Holland".
- MENU_CUP "Verdensfinaler": a made-up name.
- Store short description is exactly 80 characters (the limit).
- RULE_HITIN_BODY: a goal may be scored directly from a hit-in, following en.json. This contradicts the glossary's rule facts, so verify the source.

### Latvian (lv)

Files: i18n/src/lv.json, store/listing/lv.txt

#### Floorball terms chosen
- floorball: florbols · goal: vārti · goalkeeper: vārtsargs · field player: laukuma spēlētājs
- face-off: iemešana (face-off dot: iemešanas punkts, centre spot: centra punkts)
- free-hit: brīvsitiens (the glossary also lists "soda sitiens") · hit-in: iesitiens
- penalty: sods (mazais / lielais komandas sods, personīgais 10 minūšu sods, spēles sods)
- penalty shot: soda metiens (S) · shootout: soda metieni
- period: periods · interval: pārtraukums · overtime: papildlaiks
- power play / short-handed: vairākums / mazākums
- goal crease: vārtu laukums (S) · goalkeeper area: vārtsarga laukums · substitution zone: maiņu zona
- time-out: pārtraukums · referee: tiesnesis · stick: nūja · ball: bumbiņa (S) · boards: apmale
- shot: metiens · pass: piespēle · save: atvairīts metiens
- advantage: priekšrocība · delayed penalty: atliktais sods
- effective time / running clock: tīrais laiks / netīrais laiks
- Buttons: Mest, Piespēlēt, Sprintēt, Atņemt, Mainīt (all verbs; "Piespēlēt" is 10 letters)
- Table columns: S U N Z (spēles, uzvaras, neizšķirti, zaudējumi), P (punkti)
- Plurals: MINUTES_ZERO and MINUTES_OTHER are both "{n} minūtes", MINUTES_ONE is "{n} minūte" (e.g. "21 minūte").

#### Strings to check
- Free-hit "brīvsitiens" or "soda sitiens": the glossary sources use "soda sitiens". I chose "brīvsitiens" because "soda sitiens" is easy to confuse with "soda metiens" (penalty shot). Please confirm.
- Time-out "pārtraukums" (SIGN_TIMEOUT, TIMEOUT_*): this is also the word for the interval between periods. "Taimauts" might be clearer.
- OT_SHORT "PL", SO_SHORT "SM": abbreviations I made up from papildlaiks / soda metieni. Please replace with whatever Latvian results tables really use.
- PP_SHORT "vair.", SH_SHORT "maz.", ASSIST_SHORT "piesp.": check.
- CLOCK_LEAGUE "Netīrais laiks": the usual sports term, I believe; check that it reads fine in the UI.
- MENU_CUP "PČ turnīrs" (PČ = pasaules čempionāts): OK as a short label?
- STAGE_PLAYOFFS "Izslēgšanas spēle": also covers the quarter-finals; the round before the quarter-finals might be called "astotdaļfināls" or "play-off".
- CTRL_TACKLE "Bumbiņas atņemšana" / BTN_TACKLE "Atņemt": check that it sounds natural.
- OFF_CHARGE "Uzbrukšana ar ķermeni", OFF_TRIP "Paklupināšana", OFF_HOOK "Nūjas aizķeršana", OFF_ROUGH_BOARD "Iegrūšana apmalē": check against the rulebook offence names.
- SIGN_ADVANTAGE_BODY: the call written as "priekšrocība!"; referees may shout something else (e.g. "turpināt!").
- GROUP_X "{x} grupa": uses Latvian word order ("A grupa").
- TEAM_USA "ASV".
- RULE_HITIN_BODY / CTRL_RESTART_BODY: a goal straight from a hit-in follows the English source, but the glossary says it is not allowed. Please check.

### Estonian (et)

Files: i18n/src/et.json, store/listing/et.txt

All Estonian game terms in the glossary were marked unverified, so please check this whole list against the saalihoki rulebook.

#### Floorball terms chosen
- floorball: saalihoki · goal: värav · goalkeeper: väravavaht · field player: väljakumängija
- face-off: vahevise (face-off dot: vaheviske punkt, centre spot: keskpunkt)
- free-hit: vabalöök · hit-in: sisselöök
- penalty: karistus (10-minutiline isiklik karistus, mängukaristus) · penalty shot: karistusvise
- period: periood · interval: vaheaeg · overtime: lisaaeg
- power play: arvuline ülekaal · short-handed: (arvuline) vähemus
- goal crease: väravaala · goalkeeper area: väravavahi ala · substitution zone: vahetustsoon
- time-out: aeg maha · referee: kohtunik · stick: kepp · boards: piire
- shot: vise · pass: sööt · save: tõrje
- advantage: eelis · delayed penalty: edasilükatud karistus
- effective time / running clock: puhas mänguaeg / jooksev aeg
- Buttons: Vise, Sööt, Spurt, Äravõtt, Vahetus (all nouns)
- Table columns: M V VI K (mängud, võidud, viigid, kaotused), P (punktid)

#### Strings to check
- Face-off "vahevise" (FACE_OFF_GO, RULE_FACEOFF*, SIGN_FACE_OFF*, CALL_FACE_OFF, ST_FO): borrowed from ice hockey. In floorball the ball is not thrown, so saalihoki may use another word (e.g. "vahelöök"). This is the most important thing to check.
- "vise" for shot and "karistusvise" for penalty shot: hockey terms. If saalihoki says "löök" / "karistuslöök", the shot strings and buttons need changing (BTN_SHOOT, CTRL_SHOOT, SHOTS_LINE, ST_SOG, ST_SHOTS, ST_BLOCKED, POTM_*).
- OT_SHORT "la", SO_SHORT "kv", PP_SHORT "ÜK", SH_SHORT "VK": abbreviations I made up from lisaaeg / karistusvisked / ülekaal / vähemus. Please replace with whatever Estonian result tables really use.
- ASSIST_SHORT "sööt": not an abbreviation; "resultatiivne sööt" is too long.
- BTN_TACKLE / CTRL_TACKLE "Äravõtt": not sure this is used in sport. Alternatives: "Löö palli", "Võta pall".
- CTRL_SHOOT_BODY: I gave "slap shot" a description ("täie hooga") because I don't know an Estonian term for it.
- SIGN_DELAYED / CALL_DELAYED / RULE_ADVANTAGE "edasilükatud karistus": taken from ice hockey; check.
- SIGN_ADVANTAGE_BODY: the call written as "eelis!".
- OFF_CHARGE "Kehaga ründamine", OFF_SLASH "Kepiga löömine", OFF_TRIP "Jala ette panemine", OFF_HOOK "Haakimine": check against the rulebook offence names.
- MENU_CUP "MM-turniir", STAGE_PLAYOFFS "Play-off": OK?
- TEAM_USA "USA" (instead of "Ameerika Ühendriigid", to save space) and TEAM_NED "Holland" (common usage; the official name is "Madalmaad").
- DIVISION "Klass" (men/women): maybe "Sarja" or "Võistlusklass".
- RULE_HITIN_BODY / CTRL_RESTART_BODY: a goal straight from a hit-in follows the English source, but the glossary says it is not allowed. Please check.

### Polish (pl)

#### Terms chosen
- floorball: unihokej; stick: kij; ball: piłka; rink: boisko; boards: banda
- face-off: wznowienie (gry); hit-in: wybicie; free-hit: uderzenie wolne; penalty shot: rzut karny
- goal crease: pole bramkowe; goalkeeper area: pole bramkarza; period: tercja; overtime: dogrywka
- power play: gra w przewadze; short-handed: w osłabieniu; time-out: czas / przerwa na żądanie
- penalties: kara mniejsza/większa, kara osobista 10 minut, kara meczu; delayed penalty: kara odroczona; advantage: korzyść
- slap shot: strzał z zamachu; save: obrona; assist: asysta
- effective / running clock: czas efektywny / czas ciągły
- buttons: Strzał, Podanie, Sprint, Odbiór, Zmiana. Tone: informal "ty", with "Twój/Ciebie" capitalised as is usual in Polish UI.
- Plurals: ONE minuta, FEW minuty, MANY minut, OTHER (fractions) minuty. "1,5 minuty" is correct Polish, so OTHER is not the same as MANY.

#### Unsure (key: why)
- The glossary marks all Polish terms as unverified. Please check the whole file against the Polish translation of the rules.
- Hit-in "wybicie" (RULE_HITIN, CALL_HIT_IN, SIGN_HIT_IN, CTRL_RESTART): the Polish rules might use "wprowadzenie piłki" or "wbicie".
- Face-off "wznowienie": Polish players often just say "buly". Also, "wznowienie" can mean any restart in general use.
- Time-out "czas" (SIGN_TIMEOUT, TIMEOUT_*): this is short sports usage. CTRL_PAUSE_BODY uses "przerwa na żądanie".
- OT_SHORT "dogr." / SO_SHORT "k." / PP_SHORT "przew." / SH_SHORT "osł.": newspaper-style abbreviations. Polish hockey also uses "pd"/"pk"/"PP"/"SH".
- STAGE_PLAYOFFS "Baraż" and CUP_DESC "baraże": the world-championship playoff round before the quarter-finals.
- OFF_CHARGE "Atak ciałem", OFF_SLASH "Cios kijem", OFF_FIGHT "Brutalne zachowanie": descriptive wording.
- RULE_PENALTIES_BODY "mniejsza/większa kara drużynowa": the official wording may differ.
- COL_*: M/Z/R/P (mecze, zwycięstwa, remisy, porażki), Pkt; COL_TEAM "Drużyna", COL_GOALS "Bramki".
- TEAM_USA "USA" instead of "Stany Zjednoczone".
- ON/OFF "Wł."/"Wył.": abbreviated to save space.
- POTM_GK has been reworded to "Obrony: {s} · Strzały na bramkę: {a}" so the grammar does not depend on the number.
- Store pl-PL: the Play Console menu path in the comment line is translated freely and may not match the console's real Polish labels.
- The hit-in source issue described in the Czech notes applies here too.

### Japanese (ja)

#### Terms chosen
- floorball フロアボール; rink リンク; boards ボード; goal crease ゴールエリア; goalkeeper area ゴールキーパーエリア
- face-off フェイスオフ (dot: フェイスオフドット); free-hit フリーヒット; hit-in ヒットイン; centre spot センタースポット
- penalty shot(s) ペナルティショット (SO_SHORT "PS"); overtime 延長戦 (OT_SHORT "延長"); period ピリオド (第{n}ピリオド)
- 2/5-minute penalty 2分間退場 / 5分間退場; 10-min personal penalty 10分間のパーソナルペナルティ; match penalty マッチペナルティ; bench penalty ベンチペナルティ; delayed penalty ディレイドペナルティ; advantage アドバンテージ
- power play パワープレー (PP), short-handed SH, assist abbreviation "A"
- Buttons: シュート / パス / ダッシュ / タックル / 切替
- Table headers: 試 勝 分 敗 得点 勝点 (Japanese standings style)
- Effective time 実時間制; running clock ランニングタイム; Steady ゆったり; Real リアル
- Offences: hockey-style katakana where Japanese sports use them (フッキング, ホールディング, トリッピング, スラッシング, チャージング, プッシング); descriptive Japanese otherwise.
- Japanese full-width punctuation (：！（）) used throughout; app name keeps ASCII colon "Floorstorm: フロアボール".
- Goalkeeper "he" rendered gender-neutrally.

#### Unsure / please review
- No Japanese federation rulebook was available; all terms are unverified katakana. "ゴールエリア" vs "ゴールクリース" for goal crease; "ヒットイン" may be called "ヒットイン"/"サイドヒット" locally.
- CLOCK_IFF "実時間制" (stopped clock) — alternatives: "プレーイングタイム", "ストップウォッチ方式".
- SO_SHORT "PS" and ASSIST_SHORT "A" are guesses at readable abbreviations.
- OFF_STICK_HIT "スティックを叩く", OFF_GK_OUTSIDE "エリア外で手を使用", CALL_OUT_LINE "ボード外（504）" — check length on screen.
- CAM_HIGH translated as 俯瞰 (overhead view) rather than literal 高.
- Source-content flags (translated faithfully, not changed): en.json RULE_HITIN_BODY and CTRL_RESTART_BODY say a goal may be scored straight from a hit-in, but the glossary's rule facts say a hit-in cannot be scored directly. Also the 2026 goalkeeper-throw goal and "coincidental penalties no longer take players off" claims were not verified.

### Thai (th)

#### Terms chosen
- floorball ฟลอร์บอล; rink สนาม; boards บอร์ด; goal crease เขตประตู; goalkeeper area เขตผู้รักษาประตู
- face-off เฟซออฟ (dot จุดเฟซออฟ); free-hit ฟรีฮิต; hit-in ฮิตอิน; centre spot จุดกึ่งกลางสนาม
- penalty shot(s) ยิงลูกโทษ (SO_SHORT "ลูกโทษ"); overtime ต่อเวลาพิเศษ (OT_SHORT "ต่อเวลา"); period ช่วง (ช่วงที่ {n})
- penalties โทษ 2 นาที / โทษ 5 นาที; personal penalty โทษส่วนบุคคล; match penalty แมตช์เพนัลตี้; delayed penalty โทษรอลงโทษ; advantage ได้เปรียบ
- power play เพาเวอร์เพลย์ (PP/SH kept Latin), assist แอสซิสต์ (short แอส), saves เซฟ, shots on goal ยิงตรงกรอบ
- VS "พบ" (Thai sports convention); quarter-final รอบ 8 ทีม; semi-final รอบรองชนะเลิศ
- Buttons: ยิง / ส่ง / เร่ง / แย่ง / สลับ
- Table headers: แข่ง ชนะ เสมอ แพ้ ประตู แต้ม (Thai football table style)
- Country names follow Royal Society spellings (เช็กเกีย, สโลวาเกีย, ลัตเวีย, เยอรมนี).
- Spaces only between phrases/clauses; no full stops (Thai convention), number+unit spaced.

#### Unsure / please review
- All floorball terms are transliterations; no Thai rulebook was available.
- "โทษรอลงโทษ" for delayed penalty is awkward-ish; alternative "โทษล่าช้า" or "รอเป่าลงโทษ".
- CLOCK_IFF "เวลาจริง" (stopped clock) may be confused with real-world time; alternative "เวลาหยุดนาฬิกา".
- SPEED_STEADY "พอดี" is a loose rendering of "Steady".
- OT_SHORT "ต่อเวลา" and SO_SHORT "ลูกโทษ" may be wide for tight score labels; "OT" could be used instead.
- PP_SHORT/SH_SHORT kept as PP/SH, which casual Thai players may not recognise.
- Source-content flags (translated faithfully): en.json says a goal may be scored straight from a hit-in, contradicting the glossary's rule facts; 2026 goalkeeper-throw goal and coincidental-penalty claims unverified.
