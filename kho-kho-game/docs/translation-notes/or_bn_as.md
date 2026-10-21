# Odia / Bengali / Assamese: terms to check

Notes for a native speaker who knows kho kho. Files: `src/or.json`, `src/bn.json`, `src/as.json`.
Western digits are used everywhere (e.g. 27 ମି, 30 সেকেন্ডে). Inner quotes are typographic (“খো!”).

## Shared choices (all three)
- Chaser / defender / batch / turn / innings / dive / dream run / power play / follow-on are kept as loanwords in local script (ଚେଜର୍ / চেজার, ଡିଫେଣ୍ଡର୍ / ডিফেন্ডার, ବ୍ୟାଚ୍ / ব্যাচ, ଟର୍ନ / টার্ন, ଇନିଂସ / ইনিংস). Check that this is what players and commentators actually say.
- Wazir: ୱାଜିର୍ / ওয়াজির / ৱাজিৰ. We did not use the old Persian-derived ଉଜିର / উজির.
- Heads and tails: transliterated (ହେଡ୍/ଟେଲ୍, হেড/টেল, হেড/টেইল). A local coin-toss term may be better.
- BTN_DODGE is transliterated "dodge" (ଡଜ୍ / ডজ). Check whether a native word works better on a round button.
- TURN_SHORT is `ଟ{n}` / `ট{n}` (first letter of "turn"). It may read oddly, and Latin `T{n}` is an alternative.
- COL_P / W / D / L / PTS use whole short words: play, win, tie, loss, points. COL_D is "tie" because en.json shows "T". Check that the table column widths fit.
- "Make them follow on" is phrased as "make them chase again".
- Assamese avoids putting a case suffix on `{team}`. TOSS_LOST and RESULT_WON are worded as "{team} টছত জয়ী" / "{team} জয়ী".

## Odia (or)
- Chase (verb) is ଗୋଡ଼ାଇବା and defend is ରକ୍ଷା କରିବା. Check this against Odisha club usage, where ଚେଜ୍ / ଡିଫେନ୍ସ may be more common.
- Pole is ଖୁଣ୍ଟ, so pole dive is ଖୁଣ୍ଟ ଡାଇଭ୍. Players may just say ପୋଲ୍ ଡାଇଭ୍.
- Square (the chaser's seat) is ଘର. Central lane is ମଝି ଲେନ୍, cross lane is କ୍ରସ୍ ଲେନ୍, free zone is ଫ୍ରି ଜୋନ୍.
- Late kho is ଡେରି ଖୋ. Early rise is ଆଗୁଆ ଉଠିବା. Late entry is ଡେରିରେ ପ୍ରବେଶ.
- Move names are ଚେନ୍ (chain) and ରିଙ୍ଗ୍ (ring). Check whether Odisha players have their own names for these.
- DIFF_BEGINNER is ଶିକ୍ଷାର୍ଥୀ. TO_MENU is ମୂଳପୃଷ୍ଠା, and ହୋମ୍ may be more natural in apps.
- Assam is ଆସାମ. Check whether ଅସମ is preferred.

## Bengali (bn)
- Chase is তাড়া করা. Players may simply say চেজ করা.
- Pole is খুঁটি, so pole dive is খুঁটি ডাইভ. Square is ঘর.
- The register is informal তুমি for a 13+ audience.
- Assam is অসম, the official spelling used in West Bengal. Bangladesh usage is আসাম.
- Officials (RULES_OFFICIALS) is কর্মকর্তা. Maybe ম্যাচ অফিসিয়াল.
- The spelling mostly follows West Bengal (e.g. গুজরাত, কেরল). Check this if the target market is Bangladesh.

## Assamese (as)
- Chase is খেদা / খেদি আছে. Check whether চেজ কৰা is more usual in Assamese sports reporting.
- Pole is খুঁটা, the Assamese word rather than Bengali খুঁটি. Check that this is right for the kho kho post.
- Field is পথাৰ and group is গোট (Group {n} = গোট {n}). গ্ৰুপ may be more familiar here.
- Loanword spellings follow common Assamese practice: চেম্পিয়নশ্বিপ, ছেটিংছ, ফল'-অন, ইনিংছ, ড্ৰীম ৰান, পাৱাৰ প্লে. Please check these.
- Officials is বিষয়া. Square is ঘৰ. Beginner is শিকাৰু.
- State names: কেৰালা, তেলেংগানা, ছত্তীশগড়, গোৱা. Country names: আমেৰিকা যুক্তৰাষ্ট্ৰ, নেডাৰলেণ্ডছ, মালয়েছিয়া.
