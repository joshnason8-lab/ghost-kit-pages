# Putting World Stage Games on Bluehost

The website for **World Stage Games** ("Every game deserves a stage.") at **https://worldstagegames.com**.

You need two files from `studio-website/dist/` in this repository:

- **[`world-stage-games-website.zip`](https://github.com/joshnason8-lab/ghost-kit-pages/raw/claude/studio-website/studio-website/dist/world-stage-games-website.zip)**:
  the theme. It holds the design, the logo, the fonts, the pictures and all the pages' words.
- **[`world-stage-games-content.xml`](https://github.com/joshnason8-lab/ghost-kit-pages/raw/claude/studio-website/studio-website/dist/world-stage-games-content.xml)**:
  the same pages as a WordPress import file. This is only a back-up route (step 2b).

If your browser shows the `.xml` file as text instead of saving it, right-click the link and choose **Save link as**.

It takes about 15 minutes. You don't need any plugins.

**Already installed the earlier "Ghost Kit" version?** Follow "Moving from Ghost Kit" at the end instead.

## 1. Make the WordPress site and upload the theme

1. In Bluehost, add a WordPress site for **worldstagegames.com**, the same way you did for thekabaddipulse.com and
   beyondhaunted. Log in to its dashboard at `https://worldstagegames.com/wp-admin`.
2. Bluehost starts new sites in **Coming Soon** mode. Leave it on while you set up. You turn it off in step 7.
3. Go to **Appearance > Themes > Add New Theme > Upload Theme**.
4. Choose `world-stage-games-website.zip`, then **Install Now**, then **Activate**.

If WordPress says the file is too big ("exceeds the upload_max_filesize"), upload it another way:

1. Open Bluehost's **File Manager**.
2. Go to `public_html/wp-content/themes/` (or your site's folder) and upload the zip there.
3. Right-click the zip and choose **Extract**. This makes a `world-stage-games` folder.
4. Activate **World Stage Games** under **Appearance > Themes**.

## 2. Make the pages

### 2a. The recommended way: Site setup

1. Go to **Appearance > Site setup**. The dashboard also shows a **Go to Site setup** button after you activate.
2. Press **Set up the site**.

It takes under a minute. If the page says *Carrying on…*, leave it open. It works in short rounds so a busy server
doesn't stop it, and it carries on by itself until it shows a green box. Then it has:

- added the pictures (the games' art and screenshots, the sport pages' photos, the logo and the icon) to the
  **Media Library**. WordPress makes smaller WebP copies of each one, and phones get the small ones;
- made all 36 pages at their fixed addresses (list below), including the seven sport pages;
- made **Home** the front page;
- set the **Site Title** to "World Stage Games" and the **Tagline** to "Every game deserves a stage.", unless you had
  already chosen your own;
- set the **logo** (in the header) and the **site icon** (the browser tab), unless you had already chosen your own;
- set the links to `/%postname%/` if the site still had plain links, and saved them;
- turned comments off;
- moved WordPress's sample "Hello world!" post and "Sample Page" to the Trash, if nobody has edited them;
- **checked the links**: the last line of the green box says whether `/games/` opens. If it doesn't, see "If something
  goes wrong" below.

You can press the button again at any time:

- It never makes a second copy of a page.
- It never changes a page you have edited.
- It fills in anything that is missing, for example a page you deleted by mistake.

Under the button, the **Pages** table shows each page's status. A page marked **Differs from the theme's version**
has been edited, imported or made by an older version. **Reset to the theme's version** replaces it with the theme's
version, and WordPress keeps the old content under the page's **Revisions**.

**Why this way and not the import file?** It is more reliable on shared hosting such as Bluehost:

- It needs no plugin.
- It downloads nothing: the pictures come from the theme on the server itself. An import has to fetch every picture
  from GitHub, and on shared hosts these downloads sometimes time out.
- An import gives the pictures new ID numbers, so it needs extra repair work. Site setup makes them right in the
  first place.
- Running it twice is harmless. Importing the same file twice makes duplicate pages.

### 2b. The back-up way: import the content file

Use this only if Site setup can't run on the server.

1. Go to **Tools > Import > WordPress** and press **Install Now**, then **Run Importer**.
2. Choose `world-stage-games-content.xml`, then **Upload file and import**.
3. Under "Assign posts to", pick your own user.
4. Tick **Download and import file attachments**, then **Submit**.
5. Then go to **Appearance > Site setup** and press **Set up the site**. It sees the imported pages and pictures and
   doesn't copy them again. It just sets the home page, the name, the links and the logo.

Use one way or the other, not both.

## 3. Check the settings

Site setup does these for you, but check them once:

- **Settings > General**: the Site Title is **World Stage Games**, the Tagline **Every game deserves a stage.**, and
  both addresses are `https://worldstagegames.com`.
- **Settings > Reading**: "Your homepage displays" is **A static page**, and "Homepage" is **Home**.
- **Settings > Permalinks**: **Post name** is selected. Press **Save Changes** once even if it already is. This
  rewrites the server's link rules and fixes any page that shows "not found".

## 4. The menus

The menus are already in place:

- **Header**: Games, Sports, About, Press kit, Support. On a phone, they fold into a ☰ button.
- **Footer**: the language menu, then Privacy, Licences, Press kit, Contact.

Every link works whatever the permalink setting, and wherever WordPress is installed. The theme turns each link into
the page's real address as the page is shown.

This theme is a block theme, so there is no Appearance > Menus. To change a menu:

1. Go to **Appearance > Editor > Patterns > Template parts**.
2. Open **Header** or **Footer**.
3. Click the menu, change it, then **Save**.

## 5. The name, the logo and the languages

**The name** is one setting: **Settings > General > Site Title**. It appears in:

- the footer's © line;
- every browser-tab title;
- link previews (when someone shares a page);
- the logo's text for screen readers.

The **Tagline** on the same screen goes after the name in the home page's browser-tab title. The page text never
names the studio, so nothing else needs changing.

**The logo** in the header is the World Stage Games wordmark. To change it, go to **Appearance > Editor**, click the
logo in the header, then **Replace**. While a logo is set, the header shows the logo and not the Site Title as text,
because the logo already spells the name.

**The browser-tab icon** is the ticket. To change it, go to **Settings > General > Site Icon**.

**Languages**: the site is written in English, and it opens in all 54 languages the games are played in.

- The footer has a **🌐 Language** menu listing every language by its own name (हिन्दी, Gaeilge, isiZulu,
  Te Reo Māori…). Choosing one opens the same page through Google Translate.
- A visitor whose browser is set to one of those languages sees a small "🌐 हिन्दी →" button at the bottom of the
  page. One tap opens the page in that language; × hides the button for good on that device.
- Nothing is sent to Google until the visitor chooses a language, and the **Privacy policy** page says so.
  Translations are made by machine. The English text stays the official version, which matters most for the
  privacy policies.

Why not translate every page into 54 languages? A human translation of 36 pages, including the privacy policies,
into 54 languages would take months and need checking by native speakers. Unchecked machine translations stored on
the site would look official but could be wrong. If you ever want full human translations for a few languages, the
site can add them later.

## 6. Adding the media later

Each game is building a media kit: a trailer, screenshots, menus, a 1024 px icon and text. When one is ready:

**Trailers**: Site setup adds them for you. Press **Appearance > Site setup > Set up the site**, and it fetches all
seven games' trailers from GitHub straight into the Media Library, server to server, so nothing has to be uploaded
from your computer. They are web-sized versions (720p, 5–9 MB each) of the trailers in the games' media kits. Each
game's page shows its trailer as soon as it is in, on pages you have edited too. The title art is the cover, and
nothing loads until the visitor presses play.

- If the green box says it **could not fetch** a trailer, download it from
  [`studio-website/dist/trailers/`](https://github.com/joshnason8-lab/ghost-kit-pages/tree/claude/studio-website/studio-website/dist/trailers)
  and upload it under **Media > Add New Media File**, keeping its name (for example `kabaddi-raid-trailer.mp4`).
- To check that a trailer is in, go to **Media > Library** and look for the video. If it isn't there, the page shows
  "Trailer coming soon".
- To take a trailer off its page, delete the video from the Media Library.
- If a page still shows "Trailer coming soon" while its video is in the library, clear the site's cache (Bluehost's
  **Caching** settings), then reload the page.

A video on your own site keeps the privacy page true. If you put a game trailer on YouTube and use a **YouTube**
block instead, add a sentence about it to the **Privacy policy** page.

**Screenshots**: the four pictures under the trailer are real screenshots from the Android betas, taken from each
game's Play Store screenshots. To change one:

1. Click it, then **Replace**.
2. Upload the new picture and write its **Alternative text**, a few words on what it shows.

**Media kit links**: all seven games' media kits are linked, on the Press kit page and on each game's page.

**Google Play**: when a game is live on Play, open its page and change "Coming soon to Google Play" into a button
linking to `https://play.google.com/store/apps/details?id=<app id>`. The app IDs are below and on the Press kit page.
Do the same for the "Coming soon to Google Play" box at the bottom of **Home** and **Games**.

Changing pictures or words never needs the theme again.

## The sport pages

Each sport has a full page at `/sports/<sport>/`. Each page covers:

- the sport's history and how it's played, with a court or pitch diagram;
- its equipment;
- where it's played today;
- some famous moments;
- a link to its game;
- the sources used.

The game pages' "About the sport" panels link to them, and **Sports** is in the menu.

- **Photos**: they come from Wikimedia Commons, under licences that let anyone reuse them with credit (public
  domain, CC0, CC BY or CC BY-SA). Each one is credited under the photo. All of them are listed on the **Licences**
  page and in `studio-website/MEDIA_CREDITS.md`. If you swap a photo, keep a credit line under it.
- **Videos**: they are official videos (GAA, RTÉ, Pro Kabaddi, Star Sports, World Netball, the IFF, the Kho Kho
  Federation of India and others), embedded, not copied.
  - A video loads nothing from YouTube until the visitor presses play. Then it plays from YouTube's
    privacy-enhanced mode (youtube-nocookie.com).
  - The **Privacy policy** page says so.
- **Editing**: the pages are ordinary WordPress pages, so you can edit them like any other.

## 7. Before you go live

- **Plugins**: Bluehost installs some plugins on new sites, for example its own Bluehost plugin, Jetpack, WPForms,
  OptinMonster or an SEO plugin. The theme needs none of them.
  - Deactivate and delete the ones you don't use.
  - The site's **Privacy policy** page says it has no analytics, no advertising, no tracking, no forms and no
    cookies for readers. That is true of the theme as delivered. If you keep a plugin that adds any of those, update
    the page.
  - If you install an SEO plugin (Yoast, Rank Math, All in One SEO, SEOPress or The SEO Framework), the theme notices
    and leaves the page descriptions and link previews to it.
- **HTTPS**: turn on Bluehost's free SSL for worldstagegames.com, so every address starts with `https://`.
- **Coming Soon**: turn it off in Bluehost (or **Settings > General** / the Bluehost menu in WordPress) when you're
  happy.
- **Search engines**: under **Settings > Reading**, make sure "Discourage search engines" is **not** ticked.

## 8. Updating the theme later

1. Go to **Appearance > Themes > Add New Theme > Upload Theme** and upload the new zip.
2. Choose **Replace active with uploaded**.
3. Press **Appearance > Site setup > Set up the site**. It updates only the pages you have not edited, and adds any
   new ones.

## Moving from Ghost Kit

If you installed the first version (the theme called **Ghost Kit**, from `ghost-kit-theme.zip`), keep your pages and
switch theme:

1. Upload `world-stage-games-website.zip` as in step 1 and **Activate** it. It is a separate theme, so WordPress
   installs it beside Ghost Kit.
2. Press **Appearance > Site setup > Set up the site**. It:
   - keeps your pages;
   - refreshes the ones you haven't edited (for example, the home page loses its old picture background);
   - renames the site to World Stage Games, unless you had already renamed it;
   - swaps the ghost logo and icon for the new ones;
   - checks the links.
3. Look at the **Pages** table under the button. Any page marked **Differs from the theme's version** still has the
   old version's content. This happens when the pages came from the import file, or when you edited them.
   - If you didn't mean to change those pages, press **Reset every page that differs**.
   - To update one page, press **Reset to the theme's version** on its row.
   - WordPress keeps the old content under each page's **Revisions**, so a reset can be undone.
4. Delete **Ghost Kit** under **Appearance > Themes** (click it, then **Delete**).

If you edited the header or footer in the Site Editor under Ghost Kit, those edits don't carry over to the new theme.
Make them again under **Appearance > Editor**.

## The addresses

### Privacy policies, for the Google Play listings

Paste these into **Play Console > Policy and programs > App content > Privacy policy**, and into each game's store
listing:

| Game | Android app ID | Privacy policy URL |
|---|---|---|
| Kabaddi Raid | `com.kabaddiraid.game` | `https://worldstagegames.com/games/kabaddi-raid/privacy/` |
| Hurling Heroes | `com.ashandleather.game` | `https://worldstagegames.com/games/hurling-heroes/privacy/` |
| Sepak Takraw Unleashed | `com.takrawsmash.game` | `https://worldstagegames.com/games/sepak-takraw-unleashed/privacy/` |
| Netball Unleashed | `com.netballunleashed.game` | `https://worldstagegames.com/games/netball-unleashed/privacy/` |
| Kho Kho Rush | `com.khokhorush.game` | `https://worldstagegames.com/games/kho-kho-rush/privacy/` |
| Floorball Unleashed | `com.floorballunleashed.game` | `https://worldstagegames.com/games/floorball-unleashed/privacy/` |
| Pok Ta Pok Rivals | `com.poktapokrivals.game` | `https://worldstagegames.com/games/pok-ta-pok-rivals/privacy/` |

Each policy page is copied word for word from the policy inside that game (dated 26 or 27 October 2026).

Kabaddi Raid's policy currently lives at `https://thekabaddipulse.com/kabaddi-raid/privacy/`, and the game links
there. If Kabaddi Raid's Play listing should use the new site, use the address above. The words are the game's newest
policy, dated 27 October 2026.

### Support pages, for each listing's "Website" or support field

`https://worldstagegames.com/games/<game>/support/`, where `<game>` is one of:

- `kabaddi-raid`
- `hurling-heroes`
- `sepak-takraw-unleashed`
- `netball-unleashed`
- `kho-kho-rush`
- `floorball-unleashed`
- `pok-ta-pok-rivals`

### All the pages

All under `https://worldstagegames.com`:

| Address | Page |
|---|---|
| `/` | Home |
| `/games/` | Games (all seven, and every policy) |
| `/games/<game>/` | One page per game |
| `/games/<game>/privacy/` | That game's privacy policy |
| `/games/<game>/support/` | That game's help and support |
| `/sports/` | Sports: all seven sports |
| `/sports/<sport>/` | One page per sport: `kabaddi`, `hurling`, `sepak-takraw`, `netball`, `kho-kho`, `floorball`, `ulama` |
| `/about/` | About |
| `/press-kit/` | Press kit |
| `/support/` | Contact and support |
| `/privacy/` | Privacy policy for the website, with links to every game's |
| `/licences/` | Licences (the games' are in each game: Settings > About > Licences), and every photo's credit |

## If something goes wrong

- **Clicking a game or a menu item says "not found"**: go to **Settings > Permalinks** and press **Save Changes**. If
  it still happens, Site setup's link check will say so. In that case, ask Bluehost support to "make the site's
  .htaccess file writable and add the WordPress rewrite rules". As a stop-gap, choose **Plain** under **Settings >
  Permalinks**: the theme then links with `?page_id=` addresses, which always work. Only use Plain for a short time:
  the privacy policy addresses you give Google Play (`/games/<game>/privacy/`) need **Post name** to work.
- **Site setup stops with a red message about a picture**: the server could not process the picture. Press the
  button again. If it keeps failing, ask Bluehost support to check that PHP's GD or Imagick extension supports WebP
  images.
- **The home page shows a list of posts**: go to **Settings > Reading** and pick **A static page**, with Home as the
  homepage.
- **The import says "Failed to import Media"**: the server couldn't download the pictures from GitHub. The pages still
  show them, loaded from GitHub. To keep the pictures on your own site, use the Site setup route (2a) on a fresh
  install instead.
- **Big banners of the games at the top of the home page**: the home page still has the first version's content,
  which put the games' title art behind the headline. The theme hides those pictures now. To clean them out of the
  page itself, go to **Appearance > Site setup** and press **Reset to the theme's version** on the Home row.
- **A page looks out of date after updating the theme**: Site setup never changes a page that differs from the
  theme's version, in case you edited it. Its **Pages** table marks those pages, and **Reset to the theme's version**
  brings one up to date. WordPress keeps the old content under the page's **Revisions**.
- **Anything else**: run **Appearance > Site setup** again. It's safe.
