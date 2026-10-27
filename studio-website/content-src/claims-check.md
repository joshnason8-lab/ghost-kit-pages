# Claims check: seven games

Read-only from the game branches on 27 October 2026. Paths are `<branch>:<folder>/<file>`. "Listing" means
`<folder>/store/listing/en-US.txt`. A claim not found in the sources is marked **NOT SUPPORTED**.

## 1. Motion capture

All seven use clips from motion capture libraries (mostly the CMU Graphics Lab database, sometimes Mixamo) for
**some** moves. None says the studio recorded its own motion capture. Say "real motion capture for (some) moves",
not "fully motion-captured" or "captured in our studio".

| Game | Quote |
|---|---|
| Kabaddi Raid | README.md: "recorded movement from the CMU motion capture library, since 0.10.0"; assets/mocap/README.txt: "Motion capture data from mocap.cs.cmu.edu" (other clips from Mixamo and Meshy) |
| Sepak Takraw Unleashed | README.md: "moving to motion capture (the spikes, the serve, the knee, the run and walk from Mixamo; ...)"; docs/MOCAP.md: "Real jumps from the CMU library" |
| Netball Unleashed | Listing (release notes 0.5.0): "Real motion capture for defenders' side-steps and for landing a catch on the run." |
| Kho Kho Rush | docs/BETA.md: "Real recorded movement for two moves, from a motion capture library" |
| Hurling Heroes | Listing (release notes 0.6.0): "Players now walk and jog with real motion capture" |
| Floorball Unleashed | README.md: "Since 0.5 they walk, jog and run with real people's motion capture (CMU)" |
| Pok Ta Pok Rivals | Listing: "Lifelike players and townspeople, with a run and a serve taken from motion capture." |

## 2. Real rules, on-field officials and whistles

| Game | Real rules | Officials / whistles |
|---|---|---|
| Kabaddi Raid | Listing: "The rules as they are played: bonus points, revivals, all outs, do-or-die raids, super tackles, the golden raid, time outs and cards" (docs/KABADDI.md: Pro Kabaddi League rules, with the traditional cant as an option) | Listing: "with the referees signalling every call"; docs/RELEASE_NOTES.md 0.11.1: "The referee now blows a real whistle" |
| Sepak Takraw Unleashed | Listing: "The laws of the game as they stand today: sets to 15 (win by two, up to 17), best of three..." | Listing: "Faults called by the referee, line judges' calls, and a video challenge to overturn them."; docs/BETA.md 0.9.1: "a real referee's whistle" |
| Netball Unleashed | Listing: "played to the Rules of Netball as they stand today" | Listing: "all called by two umpires who signal every decision"; listing release notes 0.7.0: "Real referee whistles." |
| Kho Kho Rush | Listing: "Two rule books. Classic, as the national championships play it ... Fast, as the 2025 world championship played it" | Listing: "Umpires on both side lines who whistle a foul until it is put right, a referee and a timekeeper." |
| Hurling Heroes | Listing: "The playing rules as they stand in 2026" | Listing: "The referee whistles, points the free and holds up the card; the linesmen flag the sideline cuts; the umpires in their white coats wave the white flag..." |
| Floorball Unleashed | Listing: "Floorball's international Rules of the Game, the edition in force from 1 July 2026" | Listing: "Two referees who whistle and signal every call as real ones do" |
| Pok Ta Pok Rivals | Listing: "played as it is still played today" (ulama de cadera); the stone court is "rebuilt from the old chronicles" (a reconstruction, not current rules) | Listing: "Two judges, the veedores, at the analco call every raya." **Whistles: NOT SUPPORTED** |

## 3. Low / Medium / High graphics

| Game | Quote |
|---|---|
| Kabaddi Raid | Listing: "Low, Medium or High graphics, to suit your phone." |
| Sepak Takraw Unleashed | Not in the listing. README.md: "Graphics on Auto (the default) pick the level for the phone ... Low ... High ... Medium between" |
| Netball Unleashed | Not in the listing's description. Listing release notes 0.4.1 ("on Low graphics too") and 0.7.0 ("on Medium and High"); autoload/game.gd has GFX_LOW, GFX_MEDIUM, GFX_HIGH |
| Kho Kho Rush | Not in the listing. README.md table "Ground \| Low \| Medium \| High" |
| Hurling Heroes | Listing: "Low, Medium and High graphics, picked for your phone and changed any time: High adds real lighting and shadows, and an optional HD download" |
| Floorball Unleashed | Not in the listing. README.md table "Low / Medium / High" |
| Pok Ta Pok Rivals | Listing: "graphics that set themselves"; README.md: "graphics (Auto, Low, Medium, High)" |

## 4. Fully offline

| Game | Quote |
|---|---|
| Kabaddi Raid | Listing: "Plays offline." store/PLAY_STORE.md: "no internet access (CI fails the bundle if INTERNET appears)" |
| Sepak Takraw Unleashed | Listing: "Plays offline." store/PLAY_STORE.md: "one permission (vibration) and no internet access" |
| Netball Unleashed | Listing: "Plays offline." store/PLAY_CONSOLE_ANSWERS.md: "no internet permission" |
| Kho Kho Rush | Listing: "Plays offline." store/PLAY_STORE.md: "no internet access" |
| Hurling Heroes | **Partly.** Listing: "Plays offline (only the optional HD download uses the internet)." It has the INTERNET permission for that download. |
| Floorball Unleashed | Listing: "Plays offline." store/PLAY_STORE.md: "no internet access" |
| Pok Ta Pok Rivals | The listing does not say "offline". store/PLAY_STORE.md: "one permission (vibration) and no internet access". So it cannot go online, but "plays offline" is not stated in the listing itself. |

## 5. No ads, no tracking

All seven listings say no ads and no data collected. "No tracking" is not used word for word anywhere; the closest
are "no data collected" and the Play Console answers below. "No ads, no data collected" is safe to say for all seven.

| Game | Quote |
|---|---|
| Kabaddi Raid | Listing: "No ads, no purchases, no account, and no data collected." PLAY_CONSOLE_ANSWERS.md: "No accounts, ads, analytics or crash reporting." |
| Sepak Takraw Unleashed | Listing: "No ads, no purchases, no account, and no data collected." PLAY_STORE.md: Advertising ID "No" |
| Netball Unleashed | Listing: same sentence. PLAY_CONSOLE_ANSWERS.md: "no SDKs for ads, analytics, crash reporting or sign-in" |
| Kho Kho Rush | Listing: same sentence. PLAY_STORE.md: Advertising ID "No" |
| Hurling Heroes | Listing: same sentence. PLAY_CONSOLE_ANSWERS.md: "no analytics, no crash reporting, no advertising and no advertising ID" |
| Floorball Unleashed | Listing: same sentence. PLAY_STORE.md: Advertising ID "No" |
| Pok Ta Pok Rivals | Listing: "No ads, no in-app purchases, no account, no data collected." PLAY_CONSOLE_ANSWERS.md: "no analytics, crash-reporting, ads or other SDKs" |

## 6. Beta: how testers join

**A GitHub release APK** for every game: each Android workflow replaces the APK on a fixed tag in
`joshnason8-lab/ghost-kit-pages` on every push that passes the tests. **No sign-up form** is mentioned anywhere.
**Play closed test**: each `store/PLAY_STORE.md` describes it as a future step (at least 12 testers, 14 days, an
opt-in link sent by email list); nothing says it is running yet. **Obtainium**: shared-assets/obtainium/README.md
(branch `claude/shared-assets`) gives one JSON that adds all seven betas and keeps them updated.

| Game | Release tag | How the docs tell testers to install |
|---|---|---|
| Kabaddi Raid | `kabaddi-raid-beta` (workflow `.github/workflows/kabaddi-android.yml`; linked from `kabaddi-raid/index.html` "Android beta (APK)") | docs/BETA.md does **not** mention the release page: "Download `kabaddi-raid-0.12.3-beta.apk` from the chat, or open the latest Android build run on GitHub (Actions tab) and download the ... artifact", then open the .apk, allow installs, "More details, then Install anyway" if Play Protect warns. The release notes say: tap the APK under Assets, allow unknown apps. **Web version** for iPhone, iPad or computer: https://kabaddi-raid-beta.netlify.app (kabaddi-raid/support.html; workflow names it only "while its site really serves the game") |
| Sepak Takraw Unleashed | `sepak-takraw-unleashed-beta` (old tag `takraw-smash-beta` is deleted by the workflow) | docs/BETA.md: "On the phone, open https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/sepak-takraw-unleashed-beta. Tap `sepak-takraw-unleashed-<version>.apk` under Assets. ... allow your browser (or Files) to install unknown apps." |
| Netball Unleashed | `netball-unleashed-beta` | docs/BETA.md: same three steps, `netball-unleashed-<version>.apk` |
| Kho Kho Rush | `khamba-dash-beta` (kept from the game's old name, docs/PROGRESS.md) | docs/BETA.md: same three steps, `kho-kho-rush-<version>.apk` |
| Hurling Heroes | `ash-and-leather-beta` (the HD pack has its own release, `hurling-heroes-hd`) | docs/BETA.md: same steps, `hurling-heroes-<version>.apk`, or `-32bit.apk` for older or Android Go phones |
| Floorball Unleashed | `floorball-unleashed-beta` (old `floorstorm-beta` "is no longer updated") | docs/BETA.md: open the release page, tap the `.apk` under Assets, allow installs, "Install anyway" if Play Protect warns |
| Pok Ta Pok Rivals | `pok-ta-pok-rivals-beta` | README.md (no docs/BETA.md): "Download `pok-ta-pok-rivals-<version>.apk` from the pok-ta-pok-rivals-beta release on your phone and open it. ... On an older or Android Go phone that will not install it, use `-32bit.apk`." |

Beta APKs are signed with a beta key, not Play's. PLAY_STORE.md (Kabaddi): a phone with the beta "has to uninstall it
(and lose its saves) before installing the game from Play". Several BETA.md files also say a one-time uninstall was
needed when the beta key changed.

## 7. Languages across all games

**54 distinct in-game languages** (union of every game's `i18n/src/*.json`, 54 distinct codes, each matching the
languages the listings name):

Afrikaans, Assamese, Bengali, Burmese, Chichewa, Chinese, Czech, Danish, English, Estonian, Fijian, Filipino,
Finnish, French, German, Gujarati, Hindi, Indonesian, Irish, Italian, Japanese, Kannada, Khmer, Korean, Lao, Latvian,
Luganda, Malay, Malayalam, Marathi, Māori, Nepali, Norwegian, Odia, Polish, Portuguese, Punjabi, Samoan, Sesotho,
Setswana, Shona, Sinhala, Slovak, Spanish, Swahili, Swedish, Tamil, Telugu, Thai, Tongan, Vietnamese, Welsh, Xhosa,
Zulu.

Per game: Kabaddi 8, Takraw 13, Netball 19, Kho Kho 14, Hurling 2, Floorball 15, Pok Ta Pok 6 (total 77 with
repeats). Some translations are flagged as unreviewed: the Kabaddi README says the seven non-English ones "were
machine-drafted and need a native speaker's review before release", and the Irish store listing is marked a DRAFT
for a native speaker to read. Other games were not checked on this point. So "54 languages" is accurate for what
ships, but it does not mean the translations were reviewed.

## Other things to watch

- **Takraw venues**: the listing says "FIVE VENUES"; README.md lists eight (four indoor, four outdoor). Use the
  listing or check the game.
- **Min Android**: stated for Kabaddi, Netball, Hurling and Floorball (Android 7.0 / API 24). For Takraw, Kho Kho
  and Pok Ta Pok it is derived: `min_sdk` is empty (Godot's default) on Godot 4.7.2, whose minimum is API 24 per
  hurling-game/store/PLAY_STORE.md.
- **Download size** is stated only for Kabaddi (about 78 MB from Play) and Pok Ta Pok (about 117 MB from Play).
- **App ids** keep old names: Hurling is `com.ashandleather.game`, Takraw `com.takrawsmash.game`.
- **Kabaddi has no "independent game / not endorsed" sentence** in its listing.
