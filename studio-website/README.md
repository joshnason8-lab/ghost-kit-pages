# Studio website

The studio's WordPress site: a block theme in the approved design (`shared-assets/website-mockup/`), and every page's
content. For putting it on Bluehost, read **[INSTALL-BLUEHOST.md](INSTALL-BLUEHOST.md)**.

| Path | What it is |
|---|---|
| `dist/ghost-kit-theme.zip` | The theme, ready for Appearance > Themes > Upload. Includes the content and the pictures. |
| `dist/ghost-kit-content.xml` | The same pages as a WordPress import file (the back-up route). |
| `screenshots/` | The site at 360, 390, 768, 1024 and 1440 px, taken from a local WordPress 7.1.3. |
| `theme/ghost-kit/` | The theme's source. |
| `content-src/games.json` | Each game's facts, with the file each one came from on the game's branch. |
| `content-src/claims-check.md` | Each claim on the home page, with its evidence from the games. |
| `tools/` | The scripts that build the pages and the package. |

## How it fits together

- **The studio's name** is WordPress's Site Title. The theme and the pages never write it, so the placeholder "Ghost
  Kit Games" changes in one place.
- **The pages** are in `theme/ghost-kit/inc/content/pages.json`. `tools/build_content.py` builds them from:
  - `content-src/games.json`;
  - each game's privacy policy and help page, read straight from its branch with `git show` (read-only). The
    policies are copied word for word. Only line wraps are joined, and web addresses are made into links. One
    clause is dropped: Sepak Takraw's policy mentions "privacy.html next to this file", which means nothing on the
    web.
- **Appearance > Site setup** (`theme/ghost-kit/inc/setup.php`) turns that file into pages:
  - It adds the pictures to the Media Library, so WordPress makes the WebP sizes and `srcset`.
  - It makes the pages at fixed addresses and sets the front page and links.
  - Pressing it again is safe: it fills gaps and refreshes only the pages nobody has edited.
  - It works in rounds of about 15 seconds, so a shared host's 30-second limit doesn't stop it.
- **The look** is `theme.json` (colours, the self-hosted Oswald and Inter fonts, sizes), plus `assets/css/site.css`
  (about 15 KB) for the cards, the hero and the game page.
  - The region filter on the home page is `assets/js/filter.js` (1 KB). Without it, all the games show.
  - The mobile menu and the screenshot lightbox are WordPress's own.
- **SEO** (`inc/seo.php`):
  - The meta description is the page's excerpt.
  - The Open Graph and Twitter previews use each game's 1200 × 630 picture (`assets/images/og/`).
  - WordPress writes the titles and canonical links.
  - If an SEO plugin is active, the theme writes none of these.

## Rebuilding

From the repository root, with the game branches fetched (`git fetch origin <branch>` for each game):

```
sh studio-website/tools/package.sh      # rebuild pages.json from the game branches, then zip the theme
```

To rebuild the import file, run Site setup in a local WordPress with the theme, then:

1. Export the site with `tools/export_wxr.php`.
2. Run `tools/fix_wxr.py exported.xml dist/ghost-kit-content.xml <commit>`. This keeps only the pages and pictures,
   and points each picture at its file on GitHub at `<commit>`, so the import can download it.

When a game's media kit release (`<release>-media`) is published:

1. Add it to `content-src/media-kits.json` as `{"<release>-media": "<zip download URL>"}`.
2. Rebuild. The Press kit page then links the zip.

## What was tested

Everything below ran in WordPress 7.1.3 on PHP 8.3 with SQLite, on 27 October 2026.

- **The owner's route, on a new WordPress:**
  1. Uploaded the zip in the browser and activated it.
  2. Pressed Site setup: 28 pages and 42 pictures, the front page, links and logo, in about 9 seconds.
  3. Repeated with a 1-second round limit: it carried on by itself over 9 rounds and finished.
- **The import route, on another new WordPress:**
  1. Imported with WordPress Importer, which downloaded the pictures from GitHub.
  2. Ran Site setup afterwards: nothing was duplicated.
- **Links**: crawled every internal link and asset on both sites: 50 pages and 165 files, all `200`.
- **The block editor**: opened every page; there were no invalid blocks.
- **Widths** (360, 390, 768, 1024 and 1440 px, on 12 kinds of page):
  - no horizontal scrolling;
  - every image has alt text;
  - every button and menu link is at least 44 px tall.
- **Accessibility**: axe-core 4.10 (WCAG 2.2 AA and best practices) on 8 kinds of page at 390 and 1440 px: no
  violations.
  - The mobile menu opens and closes with Escape.
  - "Skip to content" is the first Tab stop.
  - Focus shows as a teal ring.
- **Third parties**: none on any page; fonts and pictures come from the site itself.
- **Page weight**:
  - Home: about 650 KB on a first visit at 390 px.
  - A privacy page: about 200 KB.
