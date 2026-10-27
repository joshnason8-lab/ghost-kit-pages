# Putting the studio website on Bluehost

You need two files from `studio-website/dist/` in this repository:

- **[`ghost-kit-theme.zip`](https://github.com/joshnason8-lab/ghost-kit-pages/raw/claude/studio-website/studio-website/dist/ghost-kit-theme.zip)**:
  the theme. It holds the design, the fonts, the game pictures and all the pages' words.
- **[`ghost-kit-content.xml`](https://github.com/joshnason8-lab/ghost-kit-pages/raw/claude/studio-website/studio-website/dist/ghost-kit-content.xml)**:
  the same pages as a WordPress import file. This is only a back-up route (step 2b).

If your browser shows the `.xml` file as text instead of saving it, right-click the link and choose **Save link as**.

It takes about 15 minutes. You don't need any plugins.

## 1. Make the WordPress site and upload the theme

1. In Bluehost, add a new WordPress site for the studio's domain, the same way you did for thekabaddipulse.com and
   beyondhaunted. Log in to its WordPress dashboard (`https://{domain}/wp-admin`).
2. Bluehost starts new sites in **Coming Soon** mode. Leave it on while you set up. You turn it off in step 7.
3. Go to **Appearance > Themes > Add New Theme > Upload Theme**.
4. Choose `ghost-kit-theme.zip`, then **Install Now**, then **Activate**.

If WordPress says the file is too big ("exceeds the upload_max_filesize"), upload it another way:

1. Open Bluehost's **File Manager**.
2. Go to `public_html/wp-content/themes/` (or your site's folder) and upload the zip there.
3. Right-click the zip and choose **Extract**. This makes a `ghost-kit` folder.
4. Activate **Ghost Kit** under **Appearance > Themes**.

## 2. Make the pages

### 2a. The recommended way: Site setup

1. Go to **Appearance > Site setup**. The dashboard also shows a **Go to Site setup** button after you activate.
2. Press **Set up the site**.

It takes under a minute. If the page says *Carrying on…*, leave it open. It works in short rounds so a busy server
doesn't stop it, and it carries on by itself until it shows a green box. Then it has:

- added the 42 game pictures to the **Media Library**. WordPress makes smaller WebP copies of each one, and phones get
  the small ones;
- made all 28 pages at their fixed addresses (list below);
- made **Home** the front page;
- set the links to `/%postname%/` if the site still had plain links;
- turned comments off;
- set the logo and the browser-tab icon;
- moved WordPress's sample "Hello world!" post and "Sample Page" to the Trash, if nobody has edited them.

You can press the button again at any time:

- It never makes a second copy of a page.
- It never changes a page you have edited.
- It fills in anything that is missing, for example a page you deleted by mistake.

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
2. Choose `ghost-kit-content.xml`, then **Upload file and import**.
3. Under "Assign posts to", pick your own user.
4. Tick **Download and import file attachments**, then **Submit**.
5. Then go to **Appearance > Site setup** and press **Set up the site**. It sees the imported pages and pictures and
   doesn't copy them again. It just sets the home page, the links and the logo.

Use one way or the other, not both.

## 3. Check the settings

Site setup does these for you, but check them once:

- **Settings > Reading**: "Your homepage displays" is **A static page**, and "Homepage" is **Home**.
- **Settings > Permalinks**: **Post name** is selected. Press **Save Changes** once even if it already is; this also
  fixes any page that shows "not found".
- **Settings > Discussion**: you can untick "Allow people to submit comments". The theme already turns comments off.

## 4. The menus

The menus are already in place:

- **Header**: Games, About, Press kit, Support.
- **Footer**: Privacy, Licences, Press kit, Contact.

On a phone, the header menu folds into a ☰ button.

This theme is a block theme, so there is no Appearance > Menus. To change a menu:

1. Go to **Appearance > Editor > Patterns > Template parts**.
2. Open **Header** or **Footer**.
3. Click the menu, change it, then **Save**.

The links are written like `/games/`, so they work on any domain.

## 5. The studio name and the domain

**The studio name** ("Ghost Kit Games" is a placeholder) is one setting: **Settings > General > Site Title**. It
appears in:

- the header and the footer's © line;
- every browser-tab title;
- link previews (when someone shares a page).

The page text never names the studio, so nothing else needs changing. The **Tagline** on the same screen goes after
the name in the home page's title ("Mobile sports games").

To change the logo or the icon:

- **Logo**: in **Appearance > Editor**, click the logo in the header, then **Replace**.
- **Browser-tab icon**: **Settings > General > Site Icon**.

The ghost logo is only a starting point. If the studio gets another name, replace it.

**The domain**: Bluehost sets it when you make the site.

- If you move the site to another domain later, change **WordPress Address** and **Site Address** under
  **Settings > General**.
- Turn on Bluehost's free SSL so the addresses start with `https://`.
- The pages link to each other by path (`/games/…`), so they keep working after a move. The site must sit at the top
  of the domain (`https://{domain}/`), not in a sub-folder.

## 6. Adding the media later

Each game is building a media kit: a trailer, screenshots, menus, a 1024 px icon and text. When one is ready:

**Trailers** (each game's page shows "Trailer coming soon" until its trailer is in):

1. Download the trailers from
   [`studio-website/dist/trailers/`](https://github.com/joshnason8-lab/ghost-kit-pages/tree/claude/studio-website/studio-website/dist/trailers).
   These are web-sized versions (720p, about 5–6 MB each) of the trailers in the games' media kits. So far there is
   Netball Unleashed's.
2. Go to **Media > Add New Media File** and drop them in. Keep the file names, for example
   `netball-unleashed-trailer.mp4`.
3. Go to **Appearance > Site setup** and press **Set up the site**.

Site setup puts each trailer on its game's page as a video player, with the title art as its cover. Nothing loads
until the visitor presses play. If you have edited a game page, Site setup leaves it alone; add the video by hand
instead:

1. Click the title picture and delete it.
2. Add a **Video** block in its place and choose the trailer.
3. Delete the "Trailer coming soon" label.

A video on your own site keeps the privacy page true. If you put a game trailer on YouTube and use a **YouTube**
block instead, add a sentence about it to the **Privacy policy** page.

**Screenshots**: the four pictures under the trailer are real screenshots from the Android betas, taken from each
game's Play Store screenshots. To change one:

1. Click it, then **Replace**.
2. Upload the new picture and write its **Alternative text**, a few words on what it shows.

**Media kit links** (Press kit page): Netball Unleashed's media kit is already linked. Each other game shows
"Media kit … coming soon". When the release `<game>-media` exists on GitHub:

1. Open **Pages > Press kit**.
2. Select the words "Media kit" for that game, press the link button, and paste the zip's download address from the
   release.
3. Delete "coming soon".

**Google Play**: when a game is live on Play, open its page and change "Coming soon to Google Play" into a button
linking to `https://play.google.com/store/apps/details?id=<app id>`. The app IDs are below and on the Press kit page.
Do the same for the "Coming soon to Google Play" box at the bottom of **Home** and **Games**.

Changing pictures or words never needs the theme again.

## 7. Before you go live

- **Plugins**: Bluehost installs some plugins on new sites, for example its own Bluehost plugin, Jetpack, WPForms,
  OptinMonster or an SEO plugin. The theme needs none of them.
  - Deactivate and delete the ones you don't use.
  - The site's **Privacy policy** page says it has no analytics, no advertising, no tracking, no forms and no
    cookies for readers. That is true of the theme as delivered. If you keep a plugin that adds any of those, update
    the page.
  - If you install an SEO plugin (Yoast, Rank Math, All in One SEO, SEOPress or The SEO Framework), the theme notices
    and leaves the page descriptions and link previews to it.
- **Coming Soon**: turn it off in Bluehost (or **Settings > General** / the Bluehost menu in WordPress) when you're
  happy.
- **Search engines**: under **Settings > Reading**, make sure "Discourage search engines" is **not** ticked.

## 8. Updating the theme later

1. Go to **Appearance > Themes > Add New Theme > Upload Theme** and upload the new zip.
2. Choose **Replace active with uploaded**.
3. Press **Appearance > Site setup > Set up the site**. It updates only the pages you have not edited, and adds any
   new ones.

## The addresses

Every page has a fixed address. Replace `{domain}` with the studio's domain.

### Privacy policies, for the Google Play listings

Paste these into **Play Console > Policy and programs > App content > Privacy policy**, and into each game's store
listing:

| Game | Android app ID | Privacy policy URL |
|---|---|---|
| Kabaddi Raid | `com.kabaddiraid.game` | `https://{domain}/games/kabaddi-raid/privacy/` |
| Hurling Heroes | `com.ashandleather.game` | `https://{domain}/games/hurling-heroes/privacy/` |
| Sepak Takraw Unleashed | `com.takrawsmash.game` | `https://{domain}/games/sepak-takraw-unleashed/privacy/` |
| Netball Unleashed | `com.netballunleashed.game` | `https://{domain}/games/netball-unleashed/privacy/` |
| Kho Kho Rush | `com.khokhorush.game` | `https://{domain}/games/kho-kho-rush/privacy/` |
| Floorball Unleashed | `com.floorballunleashed.game` | `https://{domain}/games/floorball-unleashed/privacy/` |
| Pok Ta Pok Rivals | `com.poktapokrivals.game` | `https://{domain}/games/pok-ta-pok-rivals/privacy/` |

Each policy page is copied word for word from the policy inside that game (dated 26 or 27 October 2026). Kabaddi
Raid's policy currently lives at `https://thekabaddipulse.com/kabaddi-raid/privacy/`, and the game links there. If
Kabaddi Raid's Play listing should use the new site, use the address above. The words are the game's newest policy,
dated 27 October 2026.

### Support pages, for each listing's "Website" or support field

`https://{domain}/games/<game>/support/`, where `<game>` is one of:

- `kabaddi-raid`
- `hurling-heroes`
- `sepak-takraw-unleashed`
- `netball-unleashed`
- `kho-kho-rush`
- `floorball-unleashed`
- `pok-ta-pok-rivals`

### All the pages

| Address | Page |
|---|---|
| `/` | Home |
| `/games/` | Games (all seven, the betas, every policy) |
| `/games/<game>/` | One page per game |
| `/games/<game>/privacy/` | That game's privacy policy |
| `/games/<game>/support/` | That game's help and support |
| `/about/` | About |
| `/press-kit/` | Press kit |
| `/support/` | Contact and support |
| `/privacy/` | Privacy policy for the website, with links to every game's |
| `/licences/` | Licences (the games' are in each game: Settings > About > Licences) |

## If something goes wrong

- **A page says "not found"**: go to **Settings > Permalinks** and press **Save Changes**.
- **Site setup stops with a red message about a picture**: the server could not process the picture. Press the
  button again. If it keeps failing, ask Bluehost support to check that PHP's GD or Imagick extension supports WebP
  images.
- **The home page shows a list of posts**: go to **Settings > Reading** and pick **A static page**, with Home as the
  homepage.
- **Anything else**: run **Appearance > Site setup** again. It's safe.
