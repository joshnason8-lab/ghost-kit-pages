# Simplified Chinese, Singapore/Malaysia (zh) translation notes

**Confidence: medium** for general UI; **medium-low** for netball terminology. Netball has no single standardised Chinese vocabulary; Singapore and Malaysian Chinese press use 投球 for the sport but players usually say positions and calls in English. Review by a Singapore or Malaysian Chinese-speaking netball player is recommended.

## Netball terms chosen
- Netball: **投球** — the term used in Lianhe Zaobao (Singapore) and Malaysian Chinese press (篮网球 is the mainland/HK-leaning variant).
- Positions (POS_NAME_*): **射手 (GS), 攻击射手 (GA), 边锋进攻 (WA), 中锋 (C), 边锋防守 (WD), 防守后卫 (GD), 守门员 (GK)** — descriptive translations; abbreviations kept in English, which is what local players actually use.
- Court thirds: **进攻区 / 中区 / 防守区**; goal circle: **射球区**; centre circle: **中圈**; post: **篮柱**; ring: **篮圈**.
- Centre pass **中场传球**; free pass **任意传球**; penalty pass **罚球传球**; throw-in **界外球**; held ball **持球过久**; footwork **步法(违例)**; offside **越区**; obstruction **阻挡**; contact **身体接触**; advantage **有利**.
- Buttons: 传球, 高吊, 投篮, 拦截, 防守, 切换 (2 characters each).
- Pronouns: 她 used for players throughout.
- Country names in Singapore standard forms (澳大利亚, 新西兰). Malaysian readers often say 澳洲 / 纽西兰; consider if targeting Malaysia specifically.

## Check first
- `POS_NAME_*` — especially 攻击射手 (GA), 防守后卫 (GD) and 守门员 (GK; 守门员 is "goalkeeper" in football sense, may want 守篮员 or keep English).
- `AWARD_FREE_PASS` 任意传球 / `AWARD_PENALTY_PASS` 罚球传球 — plausible but not confirmed against local umpiring usage.
- `CALL_BREAKING` 抢跑, `CALL_REPLAYED_BALL` 重复触球, `CALL_INTIMIDATION` 恐吓, `CALL_HELD_BALL` 持球过久.
- `DOUBLE_ZONE` 双分区 — invented name for the league rule.
- `BOX_*`: 中/投, 喂球, 助攻, 中传接 (centre pass receives), 抢断, 拦截, 碰球 (deflections), 篮板, 犯规, 失误 — confirm.
- `COL_P/W/D/L` → 赛/胜/平/负; `COL_PTS` 积分; `COL_PCT` 得分率.
- `QUARTER_SHORT` "第{n}节" and `EXTRA_TIME_SHORT` "加时{n}" are 3 characters (wider than "Q1"); check they fit the HUD.
- `PLAYER_TAGS` 显示球员位置 — rephrased ("show player positions") rather than literal "bibs".
- `INTERVAL_NOTE` — word order assumes {next} is a noun like "第2节"; check with real values.
- `TIMEOUTS`, `TIMEOUTS_NOTE`, `ROLLING`, `ROLLING_NOTE`, `TIME_OUT_N`, `TIME_OUT_CALLED`, `TIME_OUT_NOTE`, `INJURY_HELD`, `INJURY_NOTE`, `CALL_WARNING`, `CALL_SUSPENSION`, `SANCTION_LINE`: added later, check.

## Added in 0.2
- Coach **教练**; tips **教练提示**; umpiring (setting) **判罚尺度**; "fewer whistles" **少吹哨**; standard **标准**; real rate **真实频率**.
- Escalate **升级** (CALL_ESCALATE "升级：罚球传球"); pass advanced **传球位置前移**; ordered off **罚下场** (as in RULES_SANCTIONS_TEXT).
- Club season **俱乐部赛季**; table **积分榜**; round **第{n}轮**; grand final **总决赛**; premiers **联赛冠军！**; the season stage **常规赛**.
- Button names in the COACH_* tips are quoted “{pass}” as in the CTRL_* texts; "mark her" is **盯防她**; "dashed ring" is **虚线圆环**.
- 29 new characters entered the font subset (共升去吹哪因太子字季定尺己带常幅教某榜横母简练走遇需顶频); fonts/NotoSansSC.ttf was regenerated with tools/subset_fonts.py.

## Check first (0.2)
- CALL_ESCALATE "升级" and CALL_ADVANCE "传球位置前移": local umpiring usage is unconfirmed.
- STAGE_SEASON "常规赛" (regular season) for "The season".
- LEAGUE_WON "联赛冠军！" ("league champions"): Australian "Premiers" has no direct equivalent.
- UMPIRING "判罚尺度" as a settings label.

## Added for Watch AI
- Keys `MENU_WATCH`, `MENU_WATCH_DESC`, `WATCH_HOME`, `WATCH_AWAY`, `WATCH_GO`, `WATCH_NOTE`, `SPEED` (an AI v AI match to watch; the home and away sides on its team sheet; the 1x/2x speed). "观看 AI 对战" (watch the AI play each other); home/away **主队 / 客队**; Watch **观看**; speed **速度**.

## Added for the home-and-away season (needs native review)
- Keys `MENU_LEAGUE_DESC_2`, `LEAGUE_ABOUT_2`, `SEASON_FORMAT`, `SEASON_SINGLE`, `SEASON_HOME_AWAY`,
  `STAGE_MAJOR_SEMI`, `STAGE_MINOR_SEMI`, `STAGE_PRELIM_FINAL`, `LEAGUE_THROUGH`, `LEAGUE_KNOCKED_OUT`: a Club Season of
  seven rounds (Single) or fourteen (Home and away), and the top-four finals with a second chance for the top two.
  Translated without a native speaker, from this language's own terms already in the game (semi-final, grand final,
  finals, round, the home and away sides).
- The two descriptions are the old `MENU_LEAGUE_DESC` and `LEAGUE_ABOUT` translations (now removed) brought up to
  date. Terms chosen: season **赛季**; single **单循环：{n}轮**; home and away
  **主客场双循环：{n}轮**; major semi-final **大半决赛**; minor semi-final
  **小半决赛**; preliminary final **预决赛**.
- Check first: `STAGE_PRELIM_FINAL` (no established word was found; it means the final before the grand final),
  `STAGE_MAJOR_SEMI` / `STAGE_MINOR_SEMI`, `SEASON_HOME_AWAY`, and `LEAGUE_ABOUT_2` as a whole. Keep "{n}" (the
  number of rounds) in `SEASON_SINGLE` and `SEASON_HOME_AWAY`.

## Added for positional changes (needs native review)
- Keys `CHANGES_SUBS` (a chip beside Team changes: the list of substitutions) and `CHANGES_SWAPS_NOTE` (the note over
  the list of positional changes: two players on court swap positions, each must be able to play her new one, and the
  swap is made as play restarts). The other chip is `HOWTO_POSITIONS`, already translated. Translated without a
  native speaker, from this language's own words for Team changes and its substitution note.
- Terms chosen: substitutions **替补**; swap **交换位置** (no new characters, so the font was not cut again); pair **一对位置**; play restarts **比赛重新开始**.
- Check first: that `CHANGES_SUBS` reads as "substitutions" (players coming on from the bench) and not as team changes
  in general; that the note's "swap" means two players exchanging positions, not leaving the court; and that it fits
  as a short chip.
