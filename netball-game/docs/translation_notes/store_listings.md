# Google Play store listings: translation notes

Files: `store/listing/{af,zu,sw,ms-MY,zh-CN,si-LK,ta-IN}.txt`, translated from `en-GB.txt`. In every file the App name stays "Netball Unleashed", the position abbreviations GS, GA, WA, C, WD, GD and GK stay in English, the nineteen language names are copied exactly, and "Double Zone" is kept as a feature name. Lengths were checked with Python on the stripped text between markers (limits: short 80, full 4000).

| File | Short | Full |
|---|---|---|
| af.txt | 77 | 2424 |
| zu.txt | 77 | 2816 |
| sw.txt | 75 | 2662 |
| ms-MY.txt | 77 | 2695 |
| zh-CN.txt | 33 | 1012 |
| si-LK.txt | 77 | 2674 |
| ta-IN.txt | 75 | 3009 |

Wherever possible, the terms match the in-game strings in `i18n/src/<lang>.json`, for example the names of the game modes and venues.

## Afrikaans (af)
**Confidence: medium-high.** Uses the game's own terms: senterpas, buitespel, Vinnige wedstryd, Nasiesbeker, Doelskut/Doelaanval, borslap.
Check: "maak lope" (leads) in the short description; "voer" for feeds and "balwinste"/"terugkaatsballe" in the stats line; "obstruksie" compared with the more everyday "hindernis"; whether "speletjie" sounds too light for the disclaimer (the in-game ABOUT_DISCLAIMER uses it too).

## isiZulu (zu)
**Confidence: medium-low.** Netball is **ibhola lomnqakiswano**, as in `i18n/src/zu.json` (MENU_EYEBROW). As in the app, positions and on-court jargon are English loanwords with Zulu prefixes (i-centre pass, i-bib, ama-feed, ama-rebound, i-offside).
Check: that the netball term itself is still current; the "I-" prefix on the app name in running text ("I-Netball Unleashed"); the stats line, which is mostly loanwords; and the release-note phrase "ukukhishwa kokuqala". In the language list, the final "and" was left out on purpose so that "Na Vosa Vakaviti" does not pick up a prefix.

## Kiswahili (sw)
**Confidence: medium.** **Netiboli**, pasi ya katikati, kuotea, bibu, Mechi ya haraka and Kombe la Mataifa, all as in `sw.json`. Positions use the English names, as in the app. The decimal is "m 0.9", following the app.
Check: "England" is rendered as "Uingereza", the common sports usage, but the word can also mean the UK. Also check "mirusho kutoka nje" (throw-ins), "mipira iliyopatikana" (gains), whether the copy reads naturally in both Kenya and Tanzania, and "chombo chochote kinachosimamia netiboli" (governing body).

## Bahasa Melayu, Malaysia (ms-MY)
**Confidence: medium.** **Bola jaring**; Penjaring Gol and Penyerang Gol written out, as in `ms.json`; hantaran tengah, ofsaid, Perlawanan Pantas and Piala Negara.
Check: the disclaimer says "permainan indie yang bebas" rather than the app's "permainan bebas", because "bebas" alone can read as "free (no cost)". Confirm which wording a Malaysian reader prefers. Also check that "dikira dua gol" (Double Zone) and "suapan"/"lantunan" in the stats line are natural.

## Simplified Chinese for Singapore/Malaysia (zh-CN)
**Confidence: medium-low.** **Inconsistency to resolve:** as instructed, this listing uses **篮网球**, but the in-game `zh.json` uses **投球**, and `docs/translation_notes/zh.md` says 投球 is the term in Lianhe Zaobao and Malaysian Chinese press, with 篮网球 described as the mainland/HK-leaning variant. A Singapore or Malaysian Chinese reviewer should choose one term and use it in both the app and the listing. Position names 射手/攻击射手 and 中场传球, 越区, 国家杯 and 快速比赛 follow `zh.json`.
Check: 位置背心 for bibs; 投篮命中/出手 and 篮板 in the stats line (basketball words); and "远距离投篮一球算两球" for Double Zone. The full description is much shorter in characters, which is normal for Chinese.

## Sinhala (si-LK)
**Confidence: low-medium.** There is no in-app Sinhala file to match. Netball is **දැල්පන්දු**. Positions use the English names. On-court terms are written the way Sri Lankan players say them, as Sinhala-script loanwords (සෙන්ටර් පාස්, ෂූට්, ඕෆ්සයිඩ්, ත්‍රෝ-ඉන්, ෆීඩ්, රිබවුන්ඩ්), and some have the English added in brackets (obstruction, contact, advantage, intercept).
Check: the mix of loanwords and pure Sinhala; "ගෝල් කවය" for the goal circle; "ක්‍රීඩිකාවන්" (female players) in the disclaimer; and that the ZWJ conjuncts (ක්‍රී, ශ්‍රී) display correctly in the Play Console. Note that Play counts characters as code points, so the short description is close to the limit at 77.

## Tamil (ta-IN, aimed at Sri Lankan and Singaporean readers)
**Confidence: medium-low.** There is no in-app Tamil file to match. Netball is **வலைப்பந்து**. Word choices lean towards Sri Lankan/Singapore usage: கைபேசி (mobile), கிண்ணம் (cup; Indian Tamil would use கோப்பை), கழகம் (club). On-court jargon is transliterated English (சென்டர் பாஸ், ஷூட், ஆஃப்சைட், ஃபீட், ரீபவுண்ட்).
Check: the short description was shortened to fit 80 characters, so it no longer mentions 0.9 m. Also check "காற்பகுதி" for quarter, "வீராங்கனை" (female player) in the disclaimer, and whether "நாடுகளின் கிண்ணம்" works for Nations Cup.

- zh-CN: aligned to 投球, the word the game uses (Singapore/Malaysia press term per zh.md); a native reviewer may still prefer 篮网球.
