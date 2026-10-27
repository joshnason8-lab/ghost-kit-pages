#!/usr/bin/env python3
"""Builds the site's pages from the games' own words.

Reads studio-website/content-src/games.json (facts gathered from each game branch, with their sources) and each game's
privacy policy and help page straight from its branch (read-only, git show). Writes the theme's content file,
theme/ghost-kit/inc/content/pages.json, which the theme's "Set up the site" button turns into pages.

Run from anywhere:  python3 studio-website/tools/build_content.py
"""

import json
import os
import re

import sources
from blocks import (buttons, columns, esc, esc_attr, gallery, grid, group, heading, image, lst, paragraph, raw_html,
                    row, separator, stack, table)

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.dirname(HERE)
OUT = os.path.join(SITE, "theme", "ghost-kit", "inc", "content")

REPO_URL = "https://github.com/joshnason8-lab/ghost-kit-pages"
EMAIL = "joshnason8@gmail.com"
POLICY_DATE = "27 October 2026"

# Each game's beta release tag (GitHub releases in joshnason8-lab/ghost-kit-pages). The media kit is <slug>-media.
RELEASE_SLUG = {
    "kabaddi-raid": "kabaddi-raid",
    "sepak-takraw-unleashed": "sepak-takraw-unleashed",
    "netball-unleashed": "netball-unleashed",
    "kho-kho-rush": "khamba-dash",
    "hurling-heroes": "ash-and-leather",
    "floorball-unleashed": "floorball-unleashed",
    "pok-ta-pok-rivals": "pok-ta-pok-rivals",
}

# Where the site differs from games.json: the home card's region tags and labels (the filter has an Africa chip, as
# netball's biggest following and most of its languages are there), the card's three tags, and the beta notes.
OVERRIDES = {
    "netball-unleashed": {"regions": ["Oceania", "Europe", "Africa", "Americas"], "region_label": "Oceania · UK · Africa"},
    "sepak-takraw-unleashed": {"card_players": "3 v 3"},
    "kho-kho-rush": {"card_players": "9 v 9 · 7 v 7"},
    "pok-ta-pok-rivals": {"card_players": "Hip ball"},
    "floorball-unleashed": {"card_players": "5 v 5", "region_label": "Nordics · Europe"},
}

# The order of the design's home page.
ORDER = ["kabaddi-raid", "hurling-heroes", "sepak-takraw-unleashed", "netball-unleashed", "kho-kho-rush",
         "floorball-unleashed", "pok-ta-pok-rivals"]

REGIONS = ["South Asia", "Southeast Asia", "Europe", "Africa", "Americas", "Oceania"]

# Screenshot alt text, written from the screenshots themselves (store/graphics/screenshots on each branch).
SHOTS = {
    "kabaddi-raid": ["A raider among the defenders on a blue kabaddi court, in a packed arena",
                     "A Nations Cup raid, the raider crossing towards the defenders",
                     "The final, Kenya v India, at the national stadium",
                     "The League Season screen: the news, the next match and the league table"],
    "sepak-takraw-unleashed": ["A roll spike at the net on an indoor court",
                               "A serve from the circle, with the Horse kick and Serve buttons",
                               "A match on a court in a shopping mall",
                               "A match on the beach, with the Block button"],
    "netball-unleashed": ["Netball in a floodlit arena, every player in her bib",
                          "Netball on an outdoor court",
                          "Netball in a sports hall",
                          "Players in their positions in the arena"],
    "kho-kho-rush": ["Chasers sitting in the lane on a village ground",
                     "The Fast rules in an indoor arena",
                     "A chase in a stadium",
                     "The World Championship screen, with the group tables"],
    "hurling-heroes": ["A player about to strike the sliotar on a county ground",
                       "Players under a dropping ball in the stadium, with the Pull and Catch buttons",
                       "A strike blocked in front of the stand",
                       "The home screen in Irish"],
    "floorball-unleashed": ["Sweden v Finland in a floorball arena",
                            "The referee gives two minutes for hooking",
                            "Floorball in a sports hall",
                            "The World Finals group tables"],
    "pok-ta-pok-rivals": ["Ulama on a long earth court in a village, the crowd along the sides",
                          "The stone court, the crowd on the stone steps",
                          "A match at a festival, under strings of coloured flags",
                          "The home screen in Spanish"],
}

PAGE_SIZE_NOTE = "Screenshots from the Android beta. Tap one to see it full size."


def load_games():
    games = json.load(open(os.path.join(SITE, "content-src", "games.json")))
    games.sort(key=lambda g: ORDER.index(g["slug"]))
    for g in games:
        g.update(OVERRIDES.get(g["slug"], {}))
        g.setdefault("card_players", g["players"])
        rs = RELEASE_SLUG[g["slug"]]
        g["beta_url"] = "%s/releases/tag/%s-beta" % (REPO_URL, rs)
        g["media_tag"] = "%s-media" % rs
        g["url"] = "/games/%s/" % g["slug"]
        g["hd"] = g["slug"] == "hurling-heroes"
        g["web"] = "https://kabaddi-raid-beta.netlify.app" if g["slug"] == "kabaddi-raid" else None
    return games


def media_kits():
    """Media kit releases that exist (studio-website/content-src/media-kits.json, filled from the GitHub releases)."""
    p = os.path.join(SITE, "content-src", "media-kits.json")
    return json.load(open(p)) if os.path.exists(p) else {}


def langs_label(g):
    if g["slug"] == "hurling-heroes":
        return "English · Gaeilge"
    return "%d languages" % g["languages_count"]


# ------------------------------------------------------------------------------------------------------- shared bits

def game_card(g):
    regions = " ".join("gk-r-" + r.lower().replace(" ", "-") for r in g["regions"])
    tag = "Beta · HD pack" if g["hd"] else "Beta"
    art = group([
        image(g["slug"] + "-feature", "", size="large"),
        paragraph(tag, cls="gk-tag"),
    ], cls="gk-card__art")
    body = row([
        image(g["slug"] + "-icon", "", size="thumbnail", cls="gk-card__icon"),
        stack([
            heading(3, '<a href="%s">%s</a>' % (g["url"], esc(g["name"])), cls="gk-card__title"),
            paragraph(esc(g["card_blurb"]), cls="gk-card__blurb"),
            lst([esc(g["card_players"]), esc(langs_label(g)), esc(g["region_label"])], cls="gk-meta"),
        ], cls="gk-card__text"),
    ], cls="gk-card__body", wrap=False)
    return group([art, body], cls="gk-card " + regions)


def more_card():
    return group([
        paragraph("＋", cls="gk-card__plus"),
        heading(3, "More sports coming"),
        paragraph("Tell us which sport we should make next.", cls="gk-muted"),
        buttons([("Suggest a sport", "mailto:%s?subject=Sport%%20suggestion" % EMAIL, "outline")]),
    ], cls="gk-card gk-card--more")


def filter_chips():
    chips = ['<button type="button" class="gk-chip" aria-pressed="true" data-region="all">All</button>']
    for r in REGIONS:
        chips.append('<button type="button" class="gk-chip" aria-pressed="false" data-region="%s">%s</button>' % (
            r.lower().replace(" ", "-"), r))
    return raw_html('<div class="gk-filter" role="group" aria-label="Show games from a region" hidden>%s</div>\n'
                    '<p class="gk-filter__status screen-reader-text" aria-live="polite"></p>' % "".join(chips))


def games_grid(games, cls=None):
    return group([
        row([heading(2, "Our games", anchor="games"), filter_chips()], cls="gk-section-head", justify="space-between"),
        grid([game_card(g) for g in games] + [more_card()], cls="gk-grid", min_width="17rem", count=3),
    ], cls="gk-games " + (cls or ""), align="wide", layout={"type": "default"})


def play_band():
    return group([
        stack([
            heading(2, "Coming soon to Google Play", cls="gk-band__title"),
            paragraph("Every game is in beta on Android now. Try one and tell us what you think.", cls="gk-muted"),
        ]),
        row([
            raw_html('<p class="gk-play-badge"><span class="gk-play-badge__icon" aria-hidden="true">▶</span>'
                     '<span><small>Coming soon on</small> <strong>Google Play</strong></span></p>'),
            buttons([("Join the beta", "/games/#beta", "outline")]),
        ], cls="gk-band__actions"),
    ], cls="gk-band", align="wide", layout={"type": "flex", "flexWrap": "wrap", "justifyContent": "space-between"})


def why_tiles():
    tiles = [
        ("📐", "Real rules", "Each game plays its sport the way it is really played, with referees, umpires or judges "
                            "calling the game."),
        ("🎥", "Real movement", "Motion capture brings key moves to life, from the run to the serve, the jump and the "
                               "spike."),
        ("📱", "Made for every phone", "Low, Medium and High graphics, to suit a budget phone or the latest "
                                      "flagship."),
        ("🔒", "No ads. No data collected.", "No ads, no purchases and no account. The games collect no personal "
                                            "data, and they play offline."),
    ]
    return group([
        heading(2, "Why our games feel different"),
        grid([group([
            paragraph('<span aria-hidden="true">%s</span>' % icon, cls="gk-tile__icon"),
            heading(3, t),
            paragraph(esc(d), cls="gk-muted"),
        ], cls="gk-tile") for icon, t, d in tiles], cls="gk-tiles", min_width="13rem", count=4),
    ], cls="gk-why", align="wide", layout={"type": "default"})


def beta_section(games):
    items = []
    for g in games:
        extra = ""
        if g["web"]:
            extra = ' Or play it in a web browser on an iPhone, iPad or computer: <a href="%s">%s</a>.' % (
                g["web"], g["web"].replace("https://", ""))
        items.append('<a href="%s">%s beta</a> (Android).%s' % (g["beta_url"], esc(g["name"]), extra))
    return group([
        heading(2, "Try the betas", anchor="beta"),
        paragraph("The games are in beta on Android while they get ready for Google Play. Each beta is a free download "
                  "from the game's page on GitHub."),
        lst(items),
        heading(3, "How to install a beta"),
        lst([
            "On your Android phone, open the game's beta link above.",
            "Under <strong>Assets</strong>, tap the file ending in <code>.apk</code> to download it. On an older or "
            "Android Go phone, Hurling Heroes and Pok Ta Pok Rivals also have a file ending in <code>-32bit.apk</code>.",
            "Open the download. If your phone asks, allow your browser (or Files) to install unknown apps. If Play "
            "Protect warns you, tap <strong>More details</strong>, then <strong>Install anyway</strong>.",
        ], ordered=True),
        paragraph("A beta is a separate install from the Google Play version. When a game comes to Google Play you may "
                  "need to uninstall its beta first, and that deletes the beta's saves.", cls="gk-muted"),
    ], cls="gk-beta", layout={"type": "constrained"})


# ---------------------------------------------------------------------------------------------------------- pages

def page_home(games):
    hero_bg = group([image(s + "-feature", "", size="large") for s in
                     ("kabaddi-raid", "hurling-heroes", "sepak-takraw-unleashed", "pok-ta-pok-rivals")],
                    cls="gk-hero__bg")
    stats = row([
        paragraph("<strong>7</strong> Games", cls="gk-stat"),
        paragraph("<strong>54</strong> Languages across the games", cls="gk-stat"),
        paragraph("<strong>0</strong> Ads", cls="gk-stat"),
        paragraph("<strong>0</strong> Personal data collected", cls="gk-stat"),
    ], cls="gk-stats")
    hero = group([
        hero_bg,
        group([
            paragraph("Mobile sports games · Made for every phone", cls="gk-eyebrow"),
            heading(1, 'The sports the world <mark style="background-color:rgba(0, 0, 0, 0)" '
                       'class="has-inline-color has-accent-color">actually plays.</mark>', cls="gk-hero__title"),
            paragraph("Kabaddi, hurling, sepak takraw, kho kho, netball, floorball and the Mesoamerican ballgame, played "
                      "the way they are really played, on phones of every budget.", cls="gk-lead"),
            buttons([("Browse the games →", "/games/", None), ("Join the beta", "/games/#beta", "outline")]),
            stats,
        ], cls="gk-hero__content", align="wide", layout={"type": "default"}),
    ], cls="gk-hero", align="full", layout={"type": "constrained"})
    return "\n\n".join([hero, games_grid(games), why_tiles(), play_band()])


def page_games(games):
    intro = group([
        heading(1, "The games", cls="gk-page-title"),
        paragraph("Seven sports, each made for phones and played to its own rules. Every game is free to try in beta on "
                  "Android, plays offline, and has no ads.", cls="gk-lead"),
    ], align="wide", layout={"type": "default"})
    policies = group([
        heading(2, "Privacy and help"),
        paragraph("Each game has its own privacy policy and help page:"),
        lst(['<a href="%s">%s</a>: <a href="%sprivacy/">privacy policy</a> · <a href="%ssupport/">help</a>' % (
            g["url"], esc(g["name"]), g["url"], g["url"]) for g in games]),
    ], layout={"type": "constrained"})
    return "\n\n".join([intro, games_grid(games, cls="gk-games--page").replace(
        heading(2, "Our games", anchor="games"), heading(2, "All seven", anchor="games")),
        beta_section(games), policies, play_band()])


def page_game(g):
    s = g["slug"]
    pills = [g["card_players"], langs_label(g), "Offline", "No ads"] + (["HD pack"] if g["hd"] else [])
    actions = [("Join the beta", g["beta_url"], None)]
    if g["web"]:
        actions.append(("Play in your browser", g["web"], "outline"))
    offline = "Yes" if not g["hd"] else "Yes (the optional HD pack downloads over the internet)"
    perms = "Vibration" if not g["hd"] else "Vibration; internet, only to download the HD pack"
    facts = [
        ("Sport", esc(g["sport"])),
        ("Players", esc(g["players"])),
        ("Ways to play", esc(", ".join(g["modes"]))),
        ("Languages", esc("%d: %s" % (g["languages_count"], ", ".join(g["languages"])))),
        ("Graphics", esc(g["graphics"])),
        ("Plays offline", esc(offline)),
        ("Android", esc(g["min_android"].replace("+", " or later")) if g["min_android"] else "TBC"),
        ("Permissions", esc(perms)),
        ("Status", "Beta" + (" on Android and in the browser" if g["web"] else " on Android") + " · Google Play coming soon"),
    ]
    left = [
        group([
            image(s + "-feature", "%s title art" % g["name"], size="large"),
            paragraph("Trailer coming soon", cls="gk-trailer__badge"),
        ], cls="gk-trailer"),
        gallery([(s + "-screenshot-%d" % i, SHOTS[s][i - 1]) for i in range(1, 5)], cls="gk-shots"),
        paragraph(PAGE_SIZE_NOTE, cls="gk-caption"),
    ]
    right = [
        row([
            image(s + "-icon", "", size="thumbnail", cls="gk-game__icon"),
            stack([heading(1, esc(g["name"]), cls="gk-game__title"),
                   paragraph(esc(g["subtitle"]), cls="gk-muted gk-game__subtitle")]),
        ], cls="gk-game__head", wrap=False),
        lst([esc(p) for p in pills], cls="gk-pills"),
    ] + [paragraph(esc(d), cls="gk-desc") for d in g["description"]] + [
        buttons(actions, cls="gk-game__cta"),
        paragraph('<span aria-hidden="true">▶</span> Coming soon to Google Play', cls="gk-soon"),
        table(facts, cls="gk-facts gk-facts--grid"),
    ]
    features = group([
        heading(2, "Features"),
        grid([group([heading(3, esc(f["title"])), paragraph(esc(f["text"]), cls="gk-muted")], cls="gk-tile")
              for f in g["features"]], cls="gk-tiles", min_width="15rem", count=3),
    ], align="wide", layout={"type": "default"})
    sport = group([
        columns([
            (None, [heading(2, "About the sport"), paragraph(esc(g["about_sport"]))]),
            (None, [image(s + "-screenshot-3", SHOTS[s][2], size="large")]),
        ], cls="gk-sport__cols"),
    ], cls="gk-sport", align="wide", layout={"type": "default"})
    links = [
        '<a href="%sprivacy/">Privacy policy</a>' % g["url"],
        '<a href="%ssupport/">Help and support</a>' % g["url"],
        '<a href="/licences/">Licences</a>',
        '<a href="/press-kit/#%s">Press kit</a>' % s,
    ]
    footer = group([
        paragraph(" · ".join(links), cls="gk-game__links"),
    ] + ([paragraph(esc(g["disclaimer"]), cls="gk-small gk-muted")] if g["disclaimer"] else []),
        align="wide", layout={"type": "default"})
    top = columns([("57%", left), ("43%", right)], cls="gk-game__top", align="wide")
    return "\n\n".join([top, features, sport, footer])


def _blocks(blocks, h2_from=None):
    out = []
    for b in blocks:
        kind = b[0]
        if kind == "p":
            out.append(paragraph(b[1]))
        elif kind == "ul":
            out.append(lst(b[1]))
        elif kind in ("h2", "h3"):
            out.append(heading(int(kind[1]), esc(b[1])))
    return out


def page_privacy(g):
    p = sources.privacy(g["slug"])
    intro = p["intro"]
    if g["slug"] == "sepak-takraw-unleashed":
        # The source names a file beside it in the repository; on the web that clause means nothing.
        intro = [(k, v.replace(", and in <code>privacy.html</code> next to this file", "")) for k, v in intro]
    out = [paragraph("The same policy is in the game: Settings &gt; About &gt; Privacy policy. "
                     'Questions about the game itself: <a href="%ssupport/">%s help</a>.' % (g["url"], esc(g["name"])),
                     cls="gk-note")]
    out += _blocks(intro)
    for h, bs in p["sections"]:
        out.append(heading(2, esc(h)))
        out += _blocks(bs)
    return "\n\n".join(out), p


def page_support(g):
    sup = sources.support(g["slug"], g["name"])
    out = [paragraph("Help for %s. The same help is in the game: Settings &gt; About &gt; Help." % esc(g["name"]),
                     cls="gk-note")]
    out += _blocks(sup["blocks"])
    out.append(heading(2, "Beta downloads"))
    beta = 'The Android beta is on <a href="%s">the game\'s release page on GitHub</a>.' % g["beta_url"]
    out.append(paragraph(beta + ' <a href="/games/#beta">How to install a beta</a>.'))
    out.append(paragraph('<a href="%sprivacy/">Privacy policy</a> · <a href="%s">About the game</a>' % (g["url"], g["url"]),
                         cls="gk-game__links"))
    return "\n\n".join(out), sup


def page_studio_privacy(games):
    links = ['<a href="%sprivacy/">%s privacy policy</a>' % (g["url"], esc(g["name"])) for g in games]
    out = [
        paragraph("Last updated %s." % POLICY_DATE),
        paragraph("This page covers this website. Each game has its own privacy policy, which is also inside the game "
                  "(Settings &gt; About &gt; Privacy policy):"),
        lst(links),
        heading(2, "The games, in short"),
        paragraph("None of the games collects personal data. They have no account, no advertising, no analytics and no "
                  "in-app purchases. Six of them do not have Android's internet permission at all. Hurling Heroes uses the "
                  "internet for one thing only, and only if you ask it to: downloading its optional HD pack from GitHub. "
                  "The browser version of Kabaddi Raid is served by Netlify. Each game's policy has the details."),
        heading(2, "This website"),
        paragraph("This website has no advertising, no analytics and no tracking. It has no accounts for visitors, no "
                  "comments and no forms, and it sets no cookies when you read it. Its fonts and images are served from "
                  "this site, so reading it does not contact Google Fonts or any other third party."),
        paragraph("Like every website, the server that hosts it keeps standard logs of requests (such as your IP "
                  "address, browser type and the page asked for), which the hosting company uses to run and protect the "
                  "service."),
        paragraph("WordPress, the software that runs the site, sets cookies only for the people who log in to manage "
                  "it."),
        heading(2, "Links to other sites"),
        paragraph("Beta downloads and media kits are on GitHub; some pages link to Google Play, Netlify and other sites. "
                  "What those sites do is covered by their own privacy policies."),
        heading(2, "E-mail"),
        paragraph("If you e-mail us, we use your message and address only to answer you."),
        heading(2, "Children"),
        paragraph("The games and this website collect no personal information from anyone, children included."),
        heading(2, "Changes"),
        paragraph("If this policy changes, the new version will be posted on this page with a new date."),
        heading(2, "Contact"),
        paragraph('Questions: <a href="mailto:%s">%s</a>. The games are made by Josh Nason.' % (EMAIL, EMAIL)),
    ]
    return "\n\n".join(out)


def page_licences(games):
    out = [
        heading(2, "The games"),
        paragraph("Every game is made with the Godot Engine and with other works shared under open licences. Each game lists them all, with their full "
                  "licences, in the game itself: <strong>Settings &gt; About &gt; Licences</strong>. The licences are "
                  "shown in English, as they are written."),
        lst(['<a href="%s">%s</a>' % (g["url"], esc(g["name"])) for g in games]),
        heading(2, "This website"),
        lst([
            "<strong>WordPress</strong>, which runs the site: GNU General Public License, version 2 or later.",
            "<strong>The site's theme</strong>: GNU General Public License, version 2 or later.",
            "<strong>Oswald</strong> (headings), copyright 2016 The Oswald Project Authors, and <strong>Inter</strong> "
            "(text), copyright 2016 The Inter Project Authors: both under the SIL Open Font License, version 1.1. "
            "The fonts are served from this site.",
            "The games' icons, title art and screenshots belong to the games.",
        ]),
    ]
    return "\n\n".join(out)


def page_about(games):
    out = [
        paragraph("We make mobile games of the sports the world actually plays: kabaddi and kho kho from India, sepak "
                  "takraw from Southeast Asia, hurling from Ireland, netball, floorball, and the Mesoamerican ballgame "
                  "of Mexico.", cls="gk-lead"),
        paragraph("The games are made by Josh Nason, an independent developer, with the Godot Engine."),
        heading(2, "What we care about"),
        lst([
            "<strong>The real game.</strong> Each sport is played to its own rules, with the officials who call it, "
            "and its How to Play explains every rule.",
            "<strong>Every phone.</strong> Low, Medium and High graphics, so a budget phone can play as well as a "
            "flagship.",
            "<strong>The players' own languages.</strong> 54 languages across the seven games, from Hindi and Tamil to "
            "Irish, isiZulu and Te Reo Māori.",
            "<strong>Nothing about you.</strong> No ads, no purchases, no account and no personal data collected. The "
            "games play offline.",
        ]),
        heading(2, "Where the games are"),
        paragraph('All seven are in beta on Android, and they are coming to Google Play. <a href="/games/#beta">Try a '
                  'beta</a>, or read about <a href="/games/">the games</a>.'),
        heading(2, "Get in touch"),
        paragraph('E-mail <a href="mailto:%s">%s</a>. For press, see the <a href="/press-kit/">press kit</a>.' % (
            EMAIL, EMAIL)),
    ]
    return "\n\n".join(out)


def page_contact(games):
    rows = ['<a href="%s">%s</a>: <a href="%ssupport/">help</a> · <a href="%sprivacy/">privacy policy</a>' % (
        g["url"], esc(g["name"]), g["url"], g["url"]) for g in games]
    out = [
        paragraph("Stuck, found a bug, or have an idea? Each game's help page answers the common questions, and the "
                  "same help is in the game: Settings &gt; About &gt; Help.", cls="gk-lead"),
        lst(rows),
        heading(2, "E-mail us"),
        paragraph('Write to <a href="mailto:%s">%s</a>. For Kabaddi Raid, use the contact page the game names: '
                  '<a href="https://thekabaddipulse.com/contact/">thekabaddipulse.com/contact</a>.' % (EMAIL, EMAIL)),
        paragraph("For a bug, tell us:"),
        lst([
            "which game, and its version (Settings &gt; About);",
            "your phone's make and model, and its Android version;",
            "what happened, and what you were doing just before.",
        ]),
        paragraph("A screenshot helps. We read everything."),
        heading(2, "The betas"),
        paragraph('How to install a beta, and the download for each game: <a href="/games/#beta">Try the betas</a>.'),
        heading(2, "Suggest a sport", anchor="suggest"),
        paragraph('Which sport should we make next? <a href="mailto:%s?subject=Sport%%20suggestion">Tell us</a>.' % EMAIL),
        heading(2, "Press"),
        paragraph('Icons, title art and screenshots: the <a href="/press-kit/">press kit</a>.'),
    ]
    return "\n\n".join(out)


def page_press(games, kits):
    out = [
        paragraph("Everything you need to write about the games: icons, title art, screenshots and the facts. You are "
                  "welcome to use these images in articles and videos about the games.", cls="gk-lead"),
        paragraph('Press questions: <a href="mailto:%s?subject=Press">%s</a>.' % (EMAIL, EMAIL)),
        heading(2, "The studio"),
        table([
            ("Games", "7 mobile sports games"),
            ("Made by", "Josh Nason, an independent developer"),
            ("Engine", "Godot Engine"),
            ("Platform", "Android (beta now; Google Play coming soon). Kabaddi Raid also plays in a web browser."),
            ("Business model", "Free. No ads, no in-app purchases, no personal data collected."),
            ("Languages", "54 across the seven games"),
            ("Contact", '<a href="mailto:%s">%s</a>' % (EMAIL, EMAIL)),
        ], cls="gk-facts"),
    ]
    for g in games:
        s = g["slug"]
        kit = kits.get(g["media_tag"])
        if kit:
            kit_line = '<a href="%s"><strong>Media kit</strong> (zip)</a>: screenshots, menus, the 1024 px icon, the ' \
                       'trailer and the text.' % kit
        else:
            kit_line = "<strong>Media kit</strong> (zip, with screenshots, the 1024 px icon, the trailer and the text): " \
                       "coming soon."
        out += [
            separator(),
            row([
                image(s + "-icon", "%s icon" % g["name"], size="thumbnail", cls="gk-press__icon",
                      href="%%%%URL:%s-icon:full%%%%" % s),
                stack([heading(2, esc(g["name"]), anchor=s), paragraph(esc(g["short_description"]), cls="gk-muted")]),
            ], cls="gk-press__head", wrap=False),
            lst([
                kit_line,
                '<a href="%%%%URL:%s-icon:full%%%%">Icon</a> (512 × 512) · <a href="%%%%URL:%s-feature:full%%%%">Title '
                'art</a> (1024 × 500)' % (s, s),
                "Screenshots (1280 × 720): " + " · ".join(
                    '<a href="%%%%URL:%s-screenshot-%d:full%%%%">%d</a>' % (s, i, i) for i in range(1, 5)),
                '<a href="%s">Game page</a> · <a href="%s">Android beta</a>' % (g["url"], g["beta_url"]),
            ]),
            table([
                ("Sport", esc(g["sport"])),
                ("Android app ID", "<code>%s</code>" % g["app_id"]),
                ("Languages", str(g["languages_count"])),
                ("Short description", esc(g["short_description"])),
            ], cls="gk-facts"),
        ]
    return "\n\n".join(out)


# ---------------------------------------------------------------------------------------------------------- output

def excerpt(s, n=158):
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[: n - 1].rsplit(" ", 1)[0] + "…"


def build():
    games = load_games()
    kits = media_kits()
    pages = []

    def add(path, title, content, excerpt_text, template="", og=None, order=0):
        pages.append({"path": path, "title": title, "content": content, "excerpt": excerpt(excerpt_text),
                      "template": template, "og": og, "menu_order": order})

    add("home", "Home", page_home(games),
        "Mobile sports games of kabaddi, hurling, sepak takraw, kho kho, netball, floorball and the Mesoamerican "
        "ballgame. Real rules, every phone, no ads.", template="", order=0)
    add("games", "Games", page_games(games),
        "All seven games: Kabaddi Raid, Hurling Heroes, Sepak Takraw Unleashed, Netball Unleashed, Kho Kho Rush, "
        "Floorball Unleashed and Pok Ta Pok Rivals. Free betas on Android.", template="page-wide", order=1)
    for i, g in enumerate(games):
        add("games/" + g["slug"], g["name"], page_game(g), g["short_description"] + " Free beta on Android, no ads.",
            template="page-wide", og=g["slug"], order=i)
        content, p = page_privacy(g)
        add("games/%s/privacy" % g["slug"], "%s privacy policy" % g["name"], content,
            "%s collects no personal data: no account, no ads, no analytics. The full privacy policy." % g["name"],
            og=g["slug"], order=1)
        content, sup = page_support(g)
        add("games/%s/support" % g["slug"], "%s help and support" % g["name"], content,
            "How to play %s, what to do if something is wrong, and how to get in touch." % g["name"],
            og=g["slug"], order=2)
    add("about", "About", page_about(games),
        "Mobile games of the sports the world actually plays, made by an independent developer.", order=2)
    add("press-kit", "Press kit", page_press(games, kits),
        "Icons, title art, screenshots, media kits and facts for all seven games.", order=3)
    add("support", "Contact and support", page_contact(games),
        "Help for each game, how to report a bug, the betas, and how to get in touch.", order=4)
    add("privacy", "Privacy policy", page_studio_privacy(games),
        "The privacy policy for this website, with links to each game's own policy. No ads, no analytics, no tracking.",
        order=5)
    add("licences", "Licences", page_licences(games),
        "Where to find the licences of the works each game is made with, and the licences of this website.", order=6)

    assets = []
    for g in games:
        s = g["slug"]
        assets.append({"key": s + "-feature", "file": "games/%s-feature.webp" % s, "alt": "%s title art" % g["name"],
                       "title": "%s title art" % g["name"]})
        assets.append({"key": s + "-icon", "file": "games/%s-icon.webp" % s, "alt": "%s icon" % g["name"],
                       "title": "%s icon" % g["name"]})
        for i in range(1, 5):
            assets.append({"key": "%s-screenshot-%d" % (s, i), "file": "games/%s-screenshot-%d.webp" % (s, i),
                           "alt": SHOTS[s][i - 1], "title": "%s screenshot %d" % (g["name"], i)})

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "pages.json"), "w") as f:
        json.dump({"version": 1, "pages": pages, "assets": assets}, f, ensure_ascii=False, indent=1)
    # Unused tokens would show up as broken images; check every token names an asset.
    keys = {a["key"] for a in assets}
    for p in pages:
        for k in re.findall(r"%%(?:ID|URL):([a-z0-9-]+)", p["content"]):
            assert k in keys, (p["path"], k)
    print("pages: %d, assets: %d -> %s" % (len(pages), len(assets), os.path.relpath(OUT, SITE)))


if __name__ == "__main__":
    build()
