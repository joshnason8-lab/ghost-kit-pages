# Languages

Who would download a netball game on Google Play, what language their phones are set to, and what the game ships.
Research of 21 October 2026; sources at the end of each section.

## Where netball is played and watched

- World Netball has more than 80 members in five regions. The world ranking after the 2026 Commonwealth Games:
  1 Australia, 2 New Zealand, 3 England, 4 Jamaica, 5 South Africa, 6 Uganda, 7 Tonga, 8 Malawi; then Scotland, Wales,
  Northern Ireland, Trinidad and Tobago, Barbados, Zimbabwe, Zambia, Fiji, Samoa, Singapore, Malaysia, Sri Lanka and
  others (48 ranked). https://netball.sport/?p=39213 ; https://netball.sport/wp-content/uploads/2026/03/World-Netball-Annual-Update-March-2026-Press-Release.pdf
- **Players**: South Africa about 2 million (its second-biggest participation sport, 8,500 schools); Africa as a
  whole about 6.6 million, half the world's; Australia 466,000 adults and 225,000 children (2024); New Zealand about
  150,000 registered and 300,000 playing; Singapore about 80,000. https://pmg.org.za/committee-meeting/14841/ ;
  https://netball.sport/the-rise-of-netball-in-africa/ ; https://www.ausport.gov.au/clearinghouse/research/archive/netball ;
  https://en.wikipedia.org/wiki/Netball_in_New_Zealand ; https://www.activesgcircle.gov.sg/learn/netball/netball-singapores-up-and-coming-sport
- **Viewers**: the 2023 world championship in Cape Town had 14.9 million live TV viewers (42.3 million on every
  platform), 78% of them in sub-Saharan Africa; its biggest markets were the UK, South Africa, New Zealand, Malaysia and
  Brunei. https://netball.sport/?p=30921
- Uganda, Malawi, Zambia and Zimbabwe each grew more than 400% from 2018. Netball is the leading women's sport in
  Jamaica, New Zealand and Malawi.

## What their phones are set to

Most netball players' phones are set to **English**, in every market: the UK, Australia, New Zealand, the Caribbean,
the Pacific, and most of Africa and Singapore. The meaningful exceptions are Afrikaans in South Africa, Malay and
Chinese in Malaysia and Singapore, and Sinhala (and Tamil) in Sri Lanka. Android itself offers af, zu, sw, si, ta, ms
and zh as phone languages; Welsh only on some phones; isiXhosa, Sesotho, Setswana, Chichewa, Luganda, chiShona, Māori,
Tongan, Samoan and Fijian not at all. But since Android 13 a player can choose a language for one app in the phone's
settings, and the game has its own language button (the globe on the home screen), so a language the phone lacks is
still one tap away. https://developer.android.com/guide/topics/resources/app-languages

## What the game ships, and why

The owner asked for every local language of the people who would download the game. Netball's players are, more than
any other team sport's, in places whose own languages are rarely offered by games: southern and eastern Africa and the
Pacific. A game that greets a Malawian player in Chichewa or a Tongan in Tongan is unusual and welcome, and costs
little: the text is small. So the game ships **English and eighteen more**, the languages of the nations in the world's
top twenty and of the biggest player base (South Africa's):

| Code | Language | For | Phone language on Android | Netball's word |
|---|---|---|---|---|
| en | English (British spelling) | everyone; the default | yes | netball |
| af | Afrikaans | South Africa, Namibia | yes | netbal |
| zu | isiZulu | South Africa | yes | ibhola lomnqakiswano (translator's choice; check) |
| xh | isiXhosa | South Africa | no | ibhola yomnyazi (check against the Western Cape isiXhosa rulebook) |
| st | Sesotho | South Africa, Lesotho | no | netbolo (loan; check) |
| tn | Setswana | Botswana, South Africa | no | netbolo (loan; check) |
| ny | Chichewa | Malawi | no | netiboli / mpira wa manja |
| lg | Luganda | Uganda | no | netiboolo (loan; check) |
| sn | chiShona | Zimbabwe | no | netibhora (loan; check) |
| sw | Kiswahili | Kenya, Tanzania, Uganda | yes | netiboli |
| ms | Bahasa Melayu | Malaysia, Singapore, Brunei | yes | bola jaring |
| zh | Chinese (Simplified) | Singapore, Malaysia | yes | 投球 (Singapore and Malaysia press; 篮网球 elsewhere) |
| si | Sinhala | Sri Lanka | yes | දැල්පන්දු |
| ta | Tamil | Sri Lanka, Singapore, Malaysia | yes | வலைப்பந்து |
| cy | Welsh | Wales | some phones | pêl-rwyd |
| mi | Te Reo Māori | New Zealand | no | poitarawhiti (netipōro also used) |
| to | Tongan | Tonga | no | netipolo (check) |
| sm | Samoan | Samoa | no | netipolo (check) |
| fj | Fijian | Fiji | no | netiboli (check) |

Sources for the words: https://conceptnet.io/c/en/netball ; https://en.wikipedia.org/wiki/Wales_Netball ;
https://maoridictionary.co.nz/word/5742 ; https://en.wikipedia.org/wiki/Malaysian_Netball_Association ;
https://www.thepapare.com/tag/netball-sri-lanka/ ; https://en.wikipedia.org/wiki/Netball_in_Africa ;
https://thechanzo.com/2024/12/23/kukuza-netiboli-tanzania-juhudi-zinahitaji-kurejesha-mapenzi-unazi-kwa-mchezo-huo-mkakati-kwa-taifa/ ;
https://westerncape.gov.za/gc-news/99/56114

**The positions stay GS, GA, WA, C, WD, GD, GK in every language**: they are on the bibs, and every netball market
uses them. Netball terms (footwork, obstruction, held ball) are often said in English by players everywhere; the
translators used the local term where one is established.

**RTL**: none of these languages is written right to left, so the layout needs no mirroring.

## Fonts

Noto Sans covers every Latin-script language here, with the Welsh ŵ and ŷ, the Māori, Tongan and Samoan macrons and the
Polynesian ʻokina (U+02BB, kept by `tools/subset_fonts.py`). Noto Sans Sinhala and Noto Sans Tamil are cut to their
scripts; Noto Sans SC to the characters the Chinese text uses. Barlow Condensed, the display face, falls back to Noto
for anything it lacks. The fit audit reports any character no font can draw (`no_glyph`).

Sinhala and Tamil are set at 88% and 86% of the English size (they stand tall and run wide), the Bantu languages at
94-96% (long words): `Game.TEXT_K`.

## Store listings

Google Play's listing languages include **en-GB** (the default), **en-AU**, **en-ZA**, **en-US**, **en-IN**, **en-SG**,
**af**, **zu**, **sw**, **ms** (and ms-MY), **zh-CN**, **si-LK** and **ta-IN**. The game has a listing for each in
`store/listing/` (en-GB doubling as the base for the other English ones, tailored a little). Play has no listing
language for Welsh, isiXhosa, Sesotho, Setswana, Chichewa, Luganda, chiShona, Māori, Tongan, Samoan or Fijian (and no
en-NZ): those players see the English listing, then find their language in the game.
https://support.google.com/googleplay/android-developer/answer/9844778

## Checking the translations

The translations were made for this build and **need native speakers' review before release**, the lower-resource
languages above all (isiXhosa, Sesotho, Setswana, Chichewa, Luganda, chiShona, Tongan, Samoan, Fijian, and Te Reo
Māori). Each language's translator notes, with the terms chosen and the strings to check first, are in
`docs/translation_notes/<code>.md`.
